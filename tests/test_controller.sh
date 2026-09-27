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
assert_contains "$help_out" "--list-templates" "--help debe documentar la opción --list-templates"
assert_contains "$help_out" "--enable-template" "--help debe documentar la opción --enable-template"
assert_contains "$help_out" "--export-template" "--help debe documentar la opción --export-template"
assert_contains "$help_out" "--setup" "--help debe documentar la opción --setup"
assert_contains "$help_out" "--test-mode" "--help debe documentar la opción --test-mode"
assert_contains "$help_out" "--clean-sandbox" "--help debe documentar la opción --clean-sandbox"

# Test 2: Invocación de --list-templates
list_tmpl_out=$("${PROJECT_ROOT}/backup_manager.sh" --list-templates 2>&1)
assert_contains "$list_tmpl_out" "BIBLIOTECA DE PLANTILLAS DISPONIBLES" "--list-templates debe mostrar cabecera"
assert_contains "$list_tmpl_out" "firefox" "--list-templates debe listar firefox"
assert_contains "$list_tmpl_out" "vscode-standard" "--list-templates debe listar vscode-standard"
assert_contains "$list_tmpl_out" "ssh-keys" "--list-templates debe listar ssh-keys"

# Test 2b: Invocación de --backup-all con 0 módulos activos de inicio (FR-TMPL-002)
tmp_empty_mods=$(mktemp -d)
backup_zero_out=$(MODULES_DIR="$tmp_empty_mods" "${PROJECT_ROOT}/backup_manager.sh" --profile default --backup-all 2>&1)
backup_zero_status=$?
rm -rf "$tmp_empty_mods"
assert_eq "0" "$backup_zero_status" "--backup-all con 0 módulos activos debe retornar 0"
assert_contains "$backup_zero_out" "No hay módulos configurados para respaldar" "--backup-all debe mostrar aviso descriptivo amigable"
assert_contains "$backup_zero_out" "--enable-template" "--backup-all debe sugerir usar --enable-template"

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
MOCK_TEMPLATES_DIR="${SANDBOX_DIR}/templates.d"

cleanup() {
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT

mkdir -p "$MOCK_STORAGE/Backups" "$MOCK_HOME/.config/Code/User" "$MOCK_MODULES_DIR" "$MOCK_TEMPLATES_DIR"
cp -r "${PROJECT_ROOT}/templates.d/"* "$MOCK_TEMPLATES_DIR/"

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
TEMPLATES_DIR="$MOCK_TEMPLATES_DIR"
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
export CLI_ASSUME_YES="true"
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

# Test 11b: controller_handle_deploy_marker despliega marcador en destino
mock_deploy_dest="$SANDBOX_DIR/DeployDestTest"
deploy_out=$(controller_handle_deploy_marker "$mock_deploy_dest" "false")
deploy_status=$?
assert_eq "0" "$deploy_status" "controller_handle_deploy_marker debe retornar 0"
if [[ -f "$mock_deploy_dest/.backup_storage_marker" && -d "$mock_deploy_dest/archives" && -d "$mock_deploy_dest/logs" ]]; then
    echo "  [PASS] controller_handle_deploy_marker desplegó correctamente estructura y marcador"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] controller_handle_deploy_marker no desplegó marcador o estructura" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

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

# Test 19: Guardado de módulo en ámbito de perfil con sanitización de rutas
mkdir -p "$MOCK_PROFILES_DIR/docente/modules.d"
module_model_save "docente-excl" "Exclusivo Docente" "doc" "\$HOME/Documentos/Planificaciones" "false" "false" "" "$MOCK_PROFILES_DIR/docente/modules.d"
assert_eq "0" "$?" "module_model_save en ámbito de perfil debe retornar 0"
grep -q '"Documentos/Planificaciones"' "$MOCK_PROFILES_DIR/docente/modules.d/docente-excl.conf"
assert_eq "0" "$?" "Módulo de perfil debe almacenar ruta sanitizada sin \$HOME"

res_docente=$(profile_model_resolve_module "docente-excl" "docente" "$SANDBOX_DIR")
assert_eq "$MOCK_PROFILES_DIR/docente/modules.d/docente-excl.conf" "$res_docente" "Debe resolver el módulo exclusivo en perfil docente"

res_default_status=0
profile_model_resolve_module "docente-excl" "default" "$SANDBOX_DIR" >/dev/null 2>&1 || res_default_status=$?
assert_eq "$PROFILE_ERR_NOT_FOUND" "$res_default_status" "Módulo exclusivo de perfil no debe ser visible en default"

# Test 20: Creación de perfil con sanitización de TARGET_SUBDIR vía controlador
controller_handle_create_profile "investigador" "Perfil Investigador" "Lab" "\$HOME/TEST_Lab" "false" >/dev/null
assert_eq "0" "$?" "controller_handle_create_profile con \$HOME debe retornar 0"
grep -q '^TARGET_SUBDIR="TEST_Lab"' "$MOCK_PROFILES_DIR/investigador/profile.conf"
assert_eq "0" "$?" "TARGET_SUBDIR debe haberse sanitizado a ruta relativa en profile.conf"

# Test 21: controller_handle_list_templates en CLI
tmpl_cli_out=$(controller_handle_list_templates "false")
assert_contains "$tmpl_cli_out" "BIBLIOTECA DE PLANTILLAS DISPONIBLES" "list_templates debe incluir cabecera"
assert_contains "$tmpl_cli_out" "firefox" "list_templates debe mostrar firefox"
assert_contains "$tmpl_cli_out" "ssh-keys" "list_templates debe mostrar ssh-keys"

# Test 22: controller_handle_enable_template activando en catálogo global (sandbox)
enable_out=$(controller_handle_enable_template "git-config" "false" "default")
enable_status=$?
assert_eq "0" "$enable_status" "enable_template git-config debe retornar 0"
assert_contains "$enable_out" "activada" "Debe confirmar activación"
assert_eq "1" "$([[ -f "$MOCK_MODULES_DIR/git-config.conf" ]] && echo 1 || echo 0)" "git-config.conf debe existir en sandbox modules.d"

# Test 23: controller_handle_enable_template duplicado debe fallar
set +e
dup_enable_out=$(controller_handle_enable_template "git-config" "false" "default" 2>&1)
dup_enable_status=$?
set -e
assert_eq "1" "$dup_enable_status" "enable_template duplicado debe retornar 1"
assert_contains "$dup_enable_out" "ya está activo" "Debe avisar que ya está activo"

# Test 24: controller_handle_enable_template en perfil específico (docente)
enable_doc_out=$(controller_handle_enable_template "firefox" "false" "docente")
assert_eq "0" "$?" "enable_template en perfil docente debe retornar 0"
assert_eq "1" "$([[ -f "$MOCK_PROFILES_DIR/docente/modules.d/firefox.conf" ]] && echo 1 || echo 0)" "firefox.conf debe existir en docente/modules.d"

# Test 25: controller_handle_export_template promoviendo módulo activo a biblioteca
export_out=$(controller_handle_export_template "docente-excl" "false" "plantilla-docente")
assert_eq "0" "$?" "export_template de docente-excl debe retornar 0"
assert_eq "1" "$([[ -f "$SANDBOX_DIR/templates.d/plantilla-docente.conf" ]] && echo 1 || echo 0)" "plantilla-docente.conf debe existir en templates.d"

# Test 26: controller_handle_set_backup_destination actualiza BACKUP_DESTINATION
set_dest_status=0
controller_handle_set_backup_destination "$MOCK_STORAGE/NuevosBackups" "false" || set_dest_status=$?
assert_eq "0" "$set_dest_status" "set_backup_destination debe retornar 0"
grep -q '^BACKUP_DESTINATION="'"$MOCK_STORAGE"'/NuevosBackups"' "$MOCK_CONFIG"
assert_eq "0" "$?" "MOCK_CONFIG debe reflejar el nuevo BACKUP_DESTINATION"

# Test 27: Asistente Onboarding en modo CLI inicializa destino, marcador y preferencias
ONBOARD_CONFIG="${SANDBOX_DIR}/onboard_config.conf"
cat << EOF > "$ONBOARD_CONFIG"
INITIAL_SETUP_DONE="false"
REMEMBER_LAST_PROFILE="true"
ACTIVE_PROFILE="default"
BACKUP_DESTINATION="~/Backups/KeepMyConfig"
EOF

CONTROLLER_CONFIG_FILE="$ONBOARD_CONFIG"
# Simular entradas de usuario: '1' para opción por defecto y 's' para recordar perfil
printf "1\ns\n" | controller_handle_onboarding_wizard "false" >/dev/null 2>&1
onboard_exit=$?
assert_eq "0" "$onboard_exit" "controller_handle_onboarding_wizard en CLI debe retornar 0"
grep -q '^INITIAL_SETUP_DONE="true"' "$ONBOARD_CONFIG"
assert_eq "0" "$?" "Onboarding debe marcar INITIAL_SETUP_DONE=true"
grep -q '^REMEMBER_LAST_PROFILE="true"' "$ONBOARD_CONFIG"
assert_eq "0" "$?" "Onboarding debe registrar REMEMBER_LAST_PROFILE=true"

# Restaurar configuración de prueba
CONTROLLER_CONFIG_FILE="$MOCK_CONFIG"


echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Pruebas del controlador fallidas." >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DEL CONTROLADOR HAN PASADO."

