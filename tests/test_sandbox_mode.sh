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

# Test 10: Activación de plantilla aislada en sandbox
enable_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --enable-template bash-env 2>&1)
assert_contains "$enable_out" "Plantilla 'bash-env' activada" "--enable-template debe confirmar activación en modo sandbox"
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/modules.d/bash-env.conf" "bash-env.conf debe existir en user_data/sandbox/modules.d"
assert_file_not_exists "${PROJECT_ROOT}/modules.d/bash-env.conf" "modules.d raíz de producción NO debe contener bash-env.conf"

# Test 11: Creación de perfil aislado en sandbox
create_prof_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --create-profile docente 2>&1)
assert_contains "$create_prof_out" "Perfil 'docente' creado correctamente" "--create-profile debe confirmar creación en sandbox"
assert_file_exists "${PROJECT_ROOT}/user_data/sandbox/profiles/docente/profile.conf" "docente/profile.conf debe existir en sandbox"
assert_file_not_exists "${PROJECT_ROOT}/profiles/docente" "profiles/ raíz de producción NO debe contener perfil docente"

# Test 12: Listado de módulos en sandbox refleja los módulos activados en sandbox
list_mods_out=$("${PROJECT_ROOT}/backup_manager.sh" --test-mode --list-modules 2>&1)
assert_contains "$list_mods_out" "bash-env" "--list-modules en sandbox debe listar bash-env"

# Test 13: Comprobación de que git status permanece completamente limpio (NFR-SEC-001)
git_status_porcelain=$(git -C "${PROJECT_ROOT}" status --porcelain user_data/sandbox 2>&1 || true)
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

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Fallaron $TESTS_FAILED pruebas en test_sandbox_mode.sh" >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS DEL MODO SANDBOX HAN PASADO."
exit 0
