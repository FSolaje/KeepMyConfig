#!/usr/bin/env bash
# ==============================================================================
# Archivo: tests/test_sandbox_mode.sh
# Descripción: Suite de pruebas unitarias y de integración para el Modo Sandbox
#              (--test-mode, --sandbox, --clean-sandbox y KEEP_MY_CONFIG_TEST_MODE).
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Esperado: '$expected', Obtenido: '$actual')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg ('$needle' no encontrado en '$haystack')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [[ -f "$file" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Fichero no existe: '$file')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_not_exists() {
    local file="$1"
    local msg="$2"
    if [[ ! -e "$file" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Fichero existe cuando no debería: '$file')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="$2"
    if [[ -d "$dir" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Directorio no existe: '$dir')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== Iniciando Tests Unitarios de Modo Sandbox / Test Mode ==="

# Cargar controlador y vistas para pruebas funcionales
# shellcheck source=../lib/controllers/app_controller.sh
source "${PROJECT_ROOT}/lib/controllers/app_controller.sh"
controller_init "${PROJECT_ROOT}"

# Asegurar estado inicial limpio
"${PROJECT_ROOT}/backup_manager.sh" --clean-sandbox &>/dev/null || true

# Test 1: Limpieza inicial cuando el sandbox no existe
clean_out=$("${PROJECT_ROOT}/backup_manager.sh" --clean-sandbox 2>&1)
assert_contains "$clean_out" "sandbox no existe o ya está limpio" "--clean-sandbox debe avisar si ya está limpio"

# Test 2: Invocación de controller_enable_sandbox_mode y creación de jerarquía
controller_enable_sandbox_mode
assert_eq "true" "$IS_SANDBOX_MODE" "controller_enable_sandbox_mode debe fijar IS_SANDBOX_MODE='true'"
assert_dir_exists "${PROJECT_ROOT}/user_data/sandbox" "Directorio user_data/sandbox debe haber sido creado"
assert_dir_exists "${PROJECT_ROOT}/user_data/sandbox/config" "Directorio user_data/sandbox/config debe existir"
assert_dir_exists "${PROJECT_ROOT}/user_data/sandbox/modules.d" "Directorio user_data/sandbox/modules.d debe existir"
assert_dir_exists "${PROJECT_ROOT}/user_data/sandbox/profiles/default" "Directorio user_data/sandbox/profiles/default debe existir"
assert_dir_exists "${PROJECT_ROOT}/user_data/sandbox/storage/archives" "Directorio user_data/sandbox/storage/archives debe existir"
assert_dir_exists "${PROJECT_ROOT}/user_data/sandbox/storage/logs" "Directorio user_data/sandbox/storage/logs debe existir"

# Test 3: Archivo de configuración en sandbox adaptado
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/config/config.conf" "config.conf debe existir en sandbox"
sandbox_cfg=$(cat "${PROJECT_ROOT}/user_data/sandbox/config/config.conf")
assert_contains "$sandbox_cfg" 'INITIAL_SETUP_DONE="true"' "Sandbox config debe marcar INITIAL_SETUP_DONE=true"
assert_contains "$sandbox_cfg" 'ACTIVE_PROFILE="default"' "Sandbox config debe iniciar con ACTIVE_PROFILE=default"
assert_contains "$sandbox_cfg" 'BACKUP_DESTINATION="' "${PROJECT_ROOT}/user_data/sandbox/storage" "Sandbox config debe redirigir BACKUP_DESTINATION al storage aislado"

# Test 4: Marcador de seguridad en storage del sandbox
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/storage/.backup_storage_marker" "Marcador .backup_storage_marker debe estar desplegado en el storage del sandbox"

# Test 5: Perfil default en sandbox
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/profiles/default/profile.conf" "Perfil default/profile.conf debe existir en sandbox"

# Test 6: Redirección de variables operativas del controlador
assert_eq "${PROJECT_ROOT}/user_data/sandbox/config/config.conf" "$CONTROLLER_CONFIG_FILE" "CONTROLLER_CONFIG_FILE debe apuntar al sandbox"
assert_eq "${PROJECT_ROOT}/user_data/sandbox/modules.d" "$MODULES_DIR" "MODULES_DIR debe apuntar al sandbox"
assert_eq "${PROJECT_ROOT}/user_data/sandbox/profiles" "$PROFILES_DIR" "PROFILES_DIR debe apuntar al sandbox"

# Test 7: CLI con --test-mode emite aviso ANSI y mantiene aislamiento
cli_test_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --list-modules 2>&1)
assert_contains "$cli_test_out" "[AVISO] Ejecutando en MODO TEST / SANDBOX" "--test-mode debe emitir advertencia ANSI de sandbox"
assert_contains "$cli_test_out" "MÓDULOS REGISTRADOS" "--test-mode debe ejecutar el comando solicitado (--list-modules)"

# Test 8: CLI con flag alternativo --sandbox
cli_sandbox_out=$("${PROJECT_ROOT}/backup_manager.sh" --sandbox --list-modules 2>&1)
assert_contains "$cli_sandbox_out" "[AVISO] Ejecutando en MODO TEST / SANDBOX" "--sandbox debe emitir advertencia ANSI de sandbox"

# Test 9: Activación vía variable de entorno KEEP_MY_CONFIG_TEST_MODE
env_test_out=$(KEEP_MY_CONFIG_TEST_MODE=true "${PROJECT_ROOT}/backup_manager.sh" --list-modules 2>&1)
assert_contains "$env_test_out" "[AVISO] Ejecutando en MODO TEST / SANDBOX" "KEEP_MY_CONFIG_TEST_MODE=true debe activar el sandbox"

# Test 10: Activación de plantilla aislada en sandbox (usando firefox, no sembrada por defecto)
enable_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --enable-template firefox 2>&1)
assert_contains "$enable_out" "Plantilla 'firefox' activada" "--enable-template debe confirmar activación en modo sandbox"
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/modules.d/firefox.conf" "firefox.conf debe existir en user_data/sandbox/modules.d"
assert_file_not_exists "${PROJECT_ROOT}/modules.d/firefox.conf" "modules.d raíz de producción NO debe contener firefox.conf"

# Test 11: Creación de perfil aislado en sandbox
create_prof_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --create-profile docente 2>&1)
assert_contains "$create_prof_out" "Perfil 'docente' creado correctamente" "--create-profile debe confirmar creación en sandbox"
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/profiles/docente/profile.conf" "docente/profile.conf debe existir en sandbox"
assert_file_not_exists "${PROJECT_ROOT}/profiles/docente" "profiles/ raíz de producción NO debe contener perfil docente"

# Test 12: Listado de módulos en sandbox refleja los módulos activados en sandbox
list_mods_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --list-modules 2>&1)
assert_contains "$list_mods_out" "firefox" "--list-modules en sandbox debe listar firefox"
assert_contains "$list_mods_out" "bash-env" "--list-modules en sandbox debe listar bash-env (sembrado)"

# Test 13: Comprobación de que git status permanece completamente limpio (NFR-SEC-001)
git_status_porcelain=$(git -C "${PROJECT_ROOT}" status --porcelain user_data/sandbox 2>/dev/null || true)
assert_eq "" "$git_status_porcelain" "git status --porcelain user_data/sandbox debe estar completamente vacío (aislamiento Git)"

# Test 14: Indicador visual en whiptail_view_main_menu (FR-TEST-004)
TITLE_TMP="${PROJECT_ROOT}/user_data/title_test.tmp"
mkdir -p "${PROJECT_ROOT}/user_data"

whiptail() {
    local i=1
    while [[ $i -le $# ]]; do
        if [[ "${!i}" == "--title" ]]; then
            local next_i=$((i + 1))
            echo "${!next_i}" > "$TITLE_TMP"
        fi
        i=$((i + 1))
    done
    echo "1" >&2
    return 0
}

whiptail_view_main_menu "default" "true" &>/dev/null
captured_sandbox_title=$(cat "$TITLE_TMP" 2>/dev/null || true)
assert_contains "$captured_sandbox_title" "KeepMyConfig [SANDBOX] [Perfil: default]" "whiptail_view_main_menu debe formatear título con [SANDBOX]"

whiptail_view_main_menu "default" "false" &>/dev/null
captured_normal_title=$(cat "$TITLE_TMP" 2>/dev/null || true)
assert_contains "$captured_normal_title" "KeepMyConfig [Perfil: default]" "whiptail_view_main_menu normal no debe tener [SANDBOX]"

rm -f "$TITLE_TMP"

# Test 15: Purga completa del sandbox con --clean-sandbox (FR-TEST-005)
clean_purge_out=$("${PROJECT_ROOT}/backup_manager.sh" --clean-sandbox 2>&1)
assert_contains "$clean_purge_out" "purgado correctamente" "--clean-sandbox debe confirmar purga exitosa"
assert_file_not_exists "${PROJECT_ROOT}/user_data/sandbox" "user_data/sandbox debe haber sido eliminado completamente"

# Test 16: Home virtual de pruebas y semillas canónicas (FR-UX-002)
controller_enable_sandbox_mode
assert_eq "${PROJECT_ROOT}/user_data/sandbox/home" "$TARGET_USER_HOME" "TARGET_USER_HOME debe apuntar al home virtual de sandbox"
assert_file_exists "${TARGET_USER_HOME}/.bashrc" ".bashrc debe existir en el home virtual"
assert_file_exists "${TARGET_USER_HOME}/.bash_aliases" ".bash_aliases debe existir en el home virtual"
assert_file_exists "${TARGET_USER_HOME}/.profile" ".profile debe existir en el home virtual"
assert_file_exists "${TARGET_USER_HOME}/.ssh/id_rsa" ".ssh/id_rsa debe existir en el home virtual"
assert_file_exists "${TARGET_USER_HOME}/.config/Code/User/settings.json" "settings.json debe existir en el home virtual"
assert_file_exists "${TARGET_USER_HOME}/.gitconfig" ".gitconfig debe existir en el home virtual"
assert_file_exists "${TARGET_USER_HOME}/.mozilla/firefox/testprofile.default/prefs.js" "Firefox prefs.js debe existir en home virtual"

# Test 17: Regeneración fiel del home virtual tras --clean-sandbox
"${PROJECT_ROOT}/backup_manager.sh" --clean-sandbox &>/dev/null
assert_file_not_exists "${PROJECT_ROOT}/user_data/sandbox/home" "El home virtual debe eliminarse con --clean-sandbox"
controller_enable_sandbox_mode
assert_file_exists "${TARGET_USER_HOME}/.bashrc" ".bashrc debe regenerarse automáticamente al reactivar el sandbox"
assert_file_exists "${TARGET_USER_HOME}/.ssh/id_rsa" ".ssh/id_rsa debe regenerarse automáticamente al reactivar el sandbox"

# Test 18: Purga segura aislada con shred -u en Sandbox
"${PROJECT_ROOT}/backup_manager.sh" --test-mode --enable-template ssh-keys &>/dev/null
test_key_file="${TARGET_USER_HOME}/.ssh/id_rsa"
echo "CLAVE_MOCK_SANDBOX_TEST" > "$test_key_file"
chmod 600 "$test_key_file"

# Ejecutar backup de ssh-keys con purge forzado en sandbox
PASSPHRASE="TestPass123" "${PROJECT_ROOT}/backup_manager.sh" --test-mode --backup-module ssh-keys --purge &>/dev/null || true

# Comprobar que el archivo del sandbox fue destruido
assert_file_not_exists "$test_key_file" "El archivo .ssh/id_rsa en el sandbox debe haber sido destruido con shred -u"

# Test 19: Comprobación de que la cancelación en TUI no arroja código 1 (FR-UX-001)
# Mock de whiptail para simular que el usuario pulsa Cancelar (exit code 1)
whiptail() {
    return 1
}

cancel_mod_ret=0
controller_handle_backup_module "" "true" "auto" || cancel_mod_ret=$?
assert_eq "0" "$cancel_mod_ret" "Cancelar la selección de módulo individual en TUI debe retornar código 0"

cancel_tag_ret=0
controller_handle_backup_tag "" "true" "auto" || cancel_tag_ret=$?
assert_eq "0" "$cancel_tag_ret" "Cancelar la selección de etiqueta en TUI debe retornar código 0"

cancel_restore_ret=0
controller_handle_restore_module "" "" "true" || cancel_restore_ret=$?
assert_eq "0" "$cancel_restore_ret" "Cancelar la selección de módulo a restaurar en TUI debe retornar código 0"

# Test 20: whiptail_view_input_paths con cancelación inmediata
whiptail() {
    return 1
}
cancel_paths_ret=0
whiptail_view_input_paths "Test" "Desc" &>/dev/null || cancel_paths_ret=$?
assert_eq "1" "$cancel_paths_ret" "whiptail_view_input_paths debe retornar 1 (VIEW_CANCEL) si se cancela sin rutas"

# Test 21: whiptail_view_input_paths con captura acumulada línea a línea (FR-UX-003)
INPUT_SIM_FILE="${PROJECT_ROOT}/user_data/sim_input.tmp"
echo ".config/app" > "$INPUT_SIM_FILE"
echo ".apprc" >> "$INPUT_SIM_FILE"
echo "" >> "$INPUT_SIM_FILE"

whiptail() {
    local i=1
    local next_input=""
    if [[ -s "$INPUT_SIM_FILE" ]]; then
        next_input=$(head -n 1 "$INPUT_SIM_FILE")
        sed -i '1d' "$INPUT_SIM_FILE"
    fi
    echo "$next_input" >&2
    return 0
}

captured_paths=$(whiptail_view_input_paths "Test Entrada" "Módulo Mock" 2>/dev/null)
assert_eq ".config/app|.apprc" "$captured_paths" "whiptail_view_input_paths debe retornar las rutas acumuladas unidas por pipe"
rm -f "$INPUT_SIM_FILE"

# Test 22: Sembrado automático de módulos canónicos en user_data/sandbox/modules.d (RF-01)
"${PROJECT_ROOT}/backup_manager.sh" --test-mode --list-modules &>/dev/null
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/modules.d/bash-env.conf" "Sandbox debe sembrar automáticamente bash-env.conf en modules.d"
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/modules.d/ssh-keys.conf" "Sandbox debe sembrar automáticamente ssh-keys.conf en modules.d"

# Purga final del sandbox para dejar el espacio limpio
"${PROJECT_ROOT}/backup_manager.sh" --clean-sandbox &>/dev/null || true

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Fallaron $TESTS_FAILED pruebas en test_sandbox_mode.sh" >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS DEL MODO SANDBOX HAN PASADO."
exit 0
