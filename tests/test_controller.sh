#!/usr/bin/env bash
# ==============================================================================
# Archivo: tests/test_controller.sh
# Descripción: Suite de pruebas unitarias para lib/controllers/app_controller.sh
#              y backup_manager.sh
# ==============================================================================

set -euo pipefail

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

echo "=== Iniciando Tests Unitarios de backup_manager.sh y app_controller.sh ==="

# Test 1: Invocación de --help
help_out=$("${PROJECT_ROOT}/backup_manager.sh" --help 2>&1)
assert_contains "$help_out" "GESTOR DE BACKUP Y RECUPERACIÓN" "--help debe mostrar encabezado descriptivo"
assert_contains "$help_out" "--backup-all" "--help debe documentar la opción --backup-all"
assert_contains "$help_out" "--restore-sensitive" "--help debe documentar la opción --restore-sensitive"
assert_contains "$help_out" "--profile" "--help debe documentar la opción --profile"
assert_contains "$help_out" "--list-profiles" "--help debe documentar la opción --list-profiles"
assert_contains "$help_out" "--set-active-profile" "--help debe documentar la opción --set-active-profile"
assert_contains "$help_out" "--create-profile" "--help debe documentar la opción --create-profile"

# Test 2: Invocación de --list-modules
list_mods_out=$("${PROJECT_ROOT}/backup_manager.sh" --list-modules 2>&1)
assert_contains "$list_mods_out" "vscode-standard" "--list-modules debe listar vscode-standard"
assert_contains "$list_mods_out" "vscode-sensitive" "--list-modules debe listar vscode-sensitive"

# Test 3: Invocación de --list-tags
list_tags_out=$("${PROJECT_ROOT}/backup_manager.sh" --list-tags 2>&1)
assert_contains "$list_tags_out" "dev" "--list-tags debe listar la etiqueta 'dev'"
assert_contains "$list_tags_out" "sensitive" "--list-tags debe listar la etiqueta 'sensitive'"

# Test 4: Invocación con opción inválida
set +e
invalid_out=$("${PROJECT_ROOT}/backup_manager.sh" --opcion-inexistente-123 2>&1)
invalid_status=$?
set -e
assert_eq "5" "$invalid_status" "Opción desconocida debe retornar código 5"
assert_contains "$invalid_out" "Opción no reconocida" "Debe avisar de opción no reconocida"

# Sandbox para pruebas aisladas de controller
SANDBOX_DIR=$(mktemp -d /tmp/backupconfig_ctrl_test_XXXXXX)
MOCK_STORAGE="${SANDBOX_DIR}/mock_ssd"
MOCK_HOME="${SANDBOX_DIR}/mock_home"
MOCK_CONFIG="${SANDBOX_DIR}/config.conf"
MOCK_MODULES_DIR="${SANDBOX_DIR}/modules.d"

cleanup() {
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT

mkdir -p "$MOCK_STORAGE/Backups" "$MOCK_HOME/.config/Code/User" "$MOCK_MODULES_DIR"

# Ficheros de prueba en mock home
echo '{"theme": "dark"}' > "$MOCK_HOME/.config/Code/User/settings.json"

# Crear configuración de prueba
cat << EOF > "$MOCK_CONFIG"
TARGET_USER_HOME="$MOCK_HOME"
STORAGE_ID_TYPE="LOCAL_PATH"
STORAGE_ID_VALUE="$MOCK_STORAGE"
STORAGE_STATIC_FALLBACK="$MOCK_STORAGE"
STORAGE_SUBDIR="Backups"
STORAGE_MARKER_FILE=".backup_storage_marker"
EOF

# Crear módulo de prueba en sandbox
cat << 'EOF' > "$MOCK_MODULES_DIR/test-app.conf"
MODULE_ID="test-app"
MODULE_NAME="Aplicación de Prueba"
MODULE_TAGS=("dev" "test")
MODULE_PATHS=(".config/Code/User/settings.json")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=false
POST_RESTORE_HOOK=""
EOF

# Cargar app_controller en el proceso de prueba
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/controllers/app_controller.sh"
controller_init "$PROJECT_ROOT"

# Sobrescribir variables de entorno para usar el sandbox
TARGET_USER_HOME="$MOCK_HOME"
MODULES_DIR="$MOCK_MODULES_DIR"
CONTROLLER_CONFIG_FILE="$MOCK_CONFIG"
# shellcheck disable=SC1090
source "$MOCK_CONFIG"

# Test 5: Diagnóstico con marcador ausente
set +e
check_fail_out=$(controller_handle_device_check "false")
check_fail_status=$?
set -e
assert_eq "4" "$check_fail_status" "device_check sin marcador debe retornar 4"

# Inicializar marcador en el storage mock
touch "${MOCK_STORAGE}/.backup_storage_marker"

# Test 6: Diagnóstico con marcador presente
# Sobrescribir temporalmente la llamada a config.conf
device_model_validate_storage() {
    echo "STATUS=STORAGE_READY"
    echo "MOUNTPOINT=$MOCK_STORAGE"
    echo "BACKUP_DIR=$MOCK_STORAGE/Backups"
    echo "MARKER_PATH=$MOCK_STORAGE/.backup_storage_marker"
    echo "SPACE_AVAILABLE=10G"
    echo "SPACE_TOTAL=20G"
    return 0
}

check_ok_out=$(controller_handle_device_check "false")
check_ok_status=$?
assert_eq "0" "$check_ok_status" "device_check con marcador debe retornar 0"
assert_contains "$check_ok_out" "STORAGE_READY" "El reporte debe indicar STORAGE_READY"

# Test 7: Respaldo individual de módulo vía controller
ctrl_backup_out=$(controller_handle_backup_module "test-app" "false" "auto")
ctrl_backup_status=$?
assert_eq "0" "$ctrl_backup_status" "controller_handle_backup_module debe retornar 0"
assert_contains "$ctrl_backup_out" "STATUS=SUCCESS" "El reporte debe indicar STATUS=SUCCESS"

# Test 8: Restauración de módulo vía controller
# Borrar fichero local primero para verificar restauración
rm -f "$MOCK_HOME/.config/Code/User/settings.json"
ctrl_restore_out=$(controller_handle_restore_module "test-app" "" "false")
ctrl_restore_status=$?
assert_eq "0" "$ctrl_restore_status" "controller_handle_restore_module debe retornar 0"
assert_contains "$ctrl_restore_out" "STATUS=SUCCESS" "La restauración debe indicar STATUS=SUCCESS"

if [[ -f "$MOCK_HOME/.config/Code/User/settings.json" ]]; then
    echo "  [PASS] El archivo settings.json fue restituido correctamente en el HOME por el controlador"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] El archivo settings.json no reapareció tras la restauración" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Restaurar implementación real de device_model_validate_storage
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/models/device_model.sh"

# Test 9: controller_handle_init_target crea destino y estructura
init_tgt_out=$(controller_handle_init_target "Backups/Personal_PC" "true" "false")
init_tgt_status=$?
assert_eq "0" "$init_tgt_status" "controller_handle_init_target debe retornar 0"
assert_contains "$init_tgt_out" "Backups/Personal_PC" "init_target debe confirmar la ruta creada"

if [[ -f "$MOCK_STORAGE/Backups/Personal_PC/.backup_storage_marker" && -d "$MOCK_STORAGE/Backups/Personal_PC/archives" ]]; then
    echo "  [PASS] Estructura y marcador de target desplegados en mock storage"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] No se creó el marcador o directorios en el nuevo target" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 10: controller_handle_list_targets lista los destinos disponibles
list_tgt_out=$(controller_handle_list_targets "false")
list_tgt_status=$?
assert_eq "0" "$list_tgt_status" "controller_handle_list_targets debe retornar 0"
assert_contains "$list_tgt_out" "Backups/Personal_PC" "list_targets debe incluir Backups/Personal_PC"

# Test 11: controller_handle_set_active_target conmuta la carpeta activa en config
device_model_init_target_directory "$MOCK_STORAGE" "Backups/Servidor_DAW" "$PROJECT_ROOT/markers/.backup_storage_marker" >/dev/null
set_active_out=$(controller_handle_set_active_target "Backups/Servidor_DAW" "false")
set_active_status=$?
assert_eq "0" "$set_active_status" "controller_handle_set_active_target debe retornar 0"
assert_contains "$set_active_out" "Backups/Servidor_DAW" "set_active_target debe confirmar el nuevo subdirectorio"
grep -q '^STORAGE_SUBDIR="Backups/Servidor_DAW"' "$MOCK_CONFIG"
assert_eq "0" "$?" "MOCK_CONFIG debe contener el nuevo STORAGE_SUBDIR"

# Test 12: TARGET_SUBDIR_OVERRIDE con backup
TARGET_SUBDIR_OVERRIDE="Backups/Personal_PC"
ctrl_override_bdir=$(_controller_get_backup_dir)
assert_eq "$MOCK_STORAGE/Backups/Personal_PC" "$ctrl_override_bdir" "_controller_get_backup_dir debe respetar TARGET_SUBDIR_OVERRIDE"
TARGET_SUBDIR_OVERRIDE=""

# Test 13: Creación de módulo con formato del asistente TUI
wizard_paths="Documentos/Pruebas_Macros"
wizard_tags="sensitive"
module_model_save "test-cualquiera" "cualquier módulo." "$wizard_tags" "$wizard_paths" "true" "true" "" "$MOCK_MODULES_DIR"
mod_save_status=$?
assert_eq "0" "$mod_save_status" "Creación de módulo tipo asistente debe retornar 0"

saved_mod_info=$(module_model_get "test-cualquiera" "$MOCK_MODULES_DIR")
assert_contains "$saved_mod_info" "NAME=cualquier módulo." "El nombre del módulo debe preservarse"
assert_contains "$saved_mod_info" "IS_SENSITIVE=true" "IS_SENSITIVE debe ser true"
assert_contains "$saved_mod_info" "PURGE_AFTER_BACKUP=true" "PURGE_AFTER_BACKUP debe ser true"
assert_contains "$saved_mod_info" "PATHS=Documentos/Pruebas_Macros" "La ruta debe registrarse correctamente"

# Test 14: controller_handle_create_profile crea perfil en sandbox
MOCK_PROFILES_DIR="${SANDBOX_DIR}/profiles"
mkdir -p "$MOCK_PROFILES_DIR"
PROFILES_DIR="$MOCK_PROFILES_DIR"
create_prof_out=$(controller_handle_create_profile "docente" "Perfil Docente" "Entorno educativo" "Backups/Docente" "false")
create_prof_status=$?
assert_eq "0" "$create_prof_status" "controller_handle_create_profile debe retornar 0"
assert_contains "$create_prof_out" "docente" "Debe confirmar creación de docente"

if [[ -f "$MOCK_PROFILES_DIR/docente/profile.conf" && -d "$MOCK_PROFILES_DIR/docente/modules.d" ]]; then
    echo "  [PASS] Directorio y profile.conf creados en el sandbox"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] No se creó el archivo profile.conf del nuevo perfil" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 15: controller_handle_list_profiles lista default y docente
list_prof_out=$(controller_handle_list_profiles "false")
list_prof_status=$?
assert_eq "0" "$list_prof_status" "controller_handle_list_profiles debe retornar 0"
assert_contains "$list_prof_out" "default" "Listado debe contener perfil default"
assert_contains "$list_prof_out" "docente" "Listado debe contener perfil docente"

# Test 16: controller_handle_set_active_profile actualiza ACTIVE_PROFILE
set_prof_out=$(controller_handle_set_active_profile "docente" "false")
set_prof_status=$?
assert_eq "0" "$set_prof_status" "controller_handle_set_active_profile debe retornar 0"
assert_contains "$set_prof_out" "docente" "Debe confirmar activación de docente"
grep -q '^ACTIVE_PROFILE="docente"' "$MOCK_CONFIG"
assert_eq "0" "$?" "MOCK_CONFIG debe reflejar ACTIVE_PROFILE=docente"

# Test 17: Módulo exclusivo del perfil docente resuelto en cascada
cat << 'EOF' > "$MOCK_PROFILES_DIR/docente/modules.d/custom-eval.conf"
MODULE_ID="custom-eval"
MODULE_NAME="Plantillas de Evaluación"
MODULE_TAGS=("docente" "eval")
MODULE_PATHS=(".config/eval_templates")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=false
POST_RESTORE_HOOK=""
EOF

active_mods=$(_controller_list_modules)
assert_contains "$active_mods" "custom-eval" "_controller_list_modules debe incluir módulo exclusivo custom-eval"
assert_contains "$active_mods" "test-app" "_controller_list_modules debe mantener visible el módulo global test-app"

# Test 18: Invocación CLI backup_manager.sh --list-profiles
cli_list_prof=$("${PROJECT_ROOT}/backup_manager.sh" --list-profiles 2>&1)
assert_contains "$cli_list_prof" "PERFILES DE BACKUP CONFIGURADOS" "backup_manager.sh --list-profiles debe mostrar encabezado"
assert_contains "$cli_list_prof" "default" "backup_manager.sh --list-profiles debe listar default"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Pruebas del controlador fallidas." >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DEL CONTROLADOR HAN PASADO."

