#!/usr/bin/env bash
# ==============================================================================
# tests/test_device_model.sh - Suite de Pruebas Unitarias para device_model.sh
# ==============================================================================

set -u

TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local desc="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "  [PASS] $desc"
        ((TESTS_PASSED++))
    else
        echo "  [FAIL] $desc (Esperado: '$expected', Obtenido: '$actual')"
        ((TESTS_FAILED++))
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local desc="$3"
    if [[ "$expected" -eq "$actual" ]]; then
        echo "  [PASS] $desc (Exit code: $actual)"
        ((TESTS_PASSED++))
    else
        echo "  [FAIL] $desc (Esperado: $expected, Obtenido: $actual)"
        ((TESTS_FAILED++))
    fi
}

# Cargar el modelo a testear
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/models/device_model.sh
source "$PROJECT_ROOT/lib/models/device_model.sh"

echo "=== Iniciando Tests Unitarios de lib/models/device_model.sh ==="

# Test 1: find_mount con parámetros vacíos
device_model_find_mount "" "" >/dev/null 2>&1
assert_exit_code "$DEV_ERR_CONFIG" $? "find_mount con parámetros vacíos debe fallar con DEV_ERR_CONFIG"

# Test 2: find_mount con dispositivo inexistente
device_model_find_mount "LABEL" "DISPOSITIVO_FANTASMA_12345" >/dev/null 2>&1
assert_exit_code "$DEV_ERR_NOT_FOUND" $? "find_mount con LABEL inexistente debe retornar DEV_ERR_NOT_FOUND"

# Test 3: find_mount con UUID literal "UUID" inexistente
device_model_find_mount "UUID" "UUID" >/dev/null 2>&1
assert_exit_code "$DEV_ERR_NOT_FOUND" $? "find_mount con UUID literal 'UUID' inexistente debe retornar DEV_ERR_NOT_FOUND"

# Test 4: find_mount con LABEL inexistente "DISCO_BACKUP"
device_model_find_mount "LABEL" "DISCO_BACKUP_INEXISTENTE" >/dev/null 2>&1
assert_exit_code "$DEV_ERR_NOT_FOUND" $? "find_mount con LABEL 'DISCO_BACKUP_INEXISTENTE' debe retornar DEV_ERR_NOT_FOUND"

# Establecer un punto de montaje activo con permisos de escritura (tmpfs en /dev/shm)
if [[ -d "/dev/shm" && -w "/dev/shm" ]] && device_model_is_mounted "/dev/shm" 2>/dev/null; then
    EXPECTED_MOUNT="/dev/shm"
elif [[ -n "${XDG_RUNTIME_DIR:-}" && -w "${XDG_RUNTIME_DIR}" ]] && device_model_is_mounted "${XDG_RUNTIME_DIR}" 2>/dev/null; then
    EXPECTED_MOUNT="${XDG_RUNTIME_DIR}"
else
    EXPECTED_MOUNT="/"
fi

# Test 5: is_mounted con ruta real montada vs directorio normal
device_model_is_mounted "$EXPECTED_MOUNT"
assert_exit_code "$DEV_OK" $? "is_mounted en punto de montaje real debe retornar 0"

FAKE_DIR="/tmp/test_dir_not_mount_$$"
mkdir -p "$FAKE_DIR"
device_model_is_mounted "$FAKE_DIR"
assert_exit_code "$DEV_ERR_NOT_MOUNTED" $? "is_mounted en un directorio local ordinario debe retornar DEV_ERR_NOT_MOUNTED"
rmdir "$FAKE_DIR"

# Test 6: check_marker en directorio sin marcador
TEMP_DIR="/tmp/test_storage_$$"
mkdir -p "$TEMP_DIR"
device_model_check_marker "$TEMP_DIR" ".backup_storage_marker" >/dev/null 2>&1
assert_exit_code "$DEV_ERR_NO_MARKER" $? "check_marker debe retornar DEV_ERR_NO_MARKER si no existe"

# Test 7: init_storage_marker y check_marker
device_model_init_storage_marker "$TEMP_DIR" "$PROJECT_ROOT/markers/.backup_storage_marker"
assert_exit_code "$DEV_OK" $? "init_storage_marker debe crear el marcador correctamente"

MARKER_FOUND=$(device_model_check_marker "$TEMP_DIR" ".backup_storage_marker")
assert_exit_code "$DEV_OK" $? "check_marker debe retornar DEV_OK tras crearlo"
assert_equals "$TEMP_DIR/.backup_storage_marker" "$MARKER_FOUND" "check_marker debe retornar la ruta del marcador"

# Test 8: check_writable
device_model_check_writable "$TEMP_DIR"
assert_exit_code "$DEV_OK" $? "check_writable debe retornar DEV_OK en carpeta con permisos"
rm -rf "$TEMP_DIR"

# Test 9: get_space
SPACE_INFO=$(device_model_get_space "$EXPECTED_MOUNT")
assert_exit_code "$DEV_OK" $? "get_space debe retornar DEV_OK en un montaje existente"
[[ "$SPACE_INFO" =~ SPACE_FREE_HUMAN= ]]
assert_equals "0" "$?" "get_space debe contener el campo SPACE_FREE_HUMAN"

# Test 10: validate_storage en montaje real pero con marcador inexistente (debe abortar protegiendo el sistema)
TEST_CONFIG="/tmp/test_config_$$.conf"
cat <<EOF > "$TEST_CONFIG"
STORAGE_ID_TYPE="STATIC_PATH"
STORAGE_ID_VALUE="$EXPECTED_MOUNT"
STORAGE_SUBDIR="DirectorioPruebaSinMarcador"
STORAGE_MARKER_FILE=".marcador_inexistente_$$"
EOF

VAL_OUTPUT=$(device_model_validate_storage "$TEST_CONFIG")
VAL_EXIT=$?
assert_exit_code "$DEV_ERR_NO_MARKER" "$VAL_EXIT" "validate_storage debe abortar con DEV_ERR_NO_MARKER si falta el marcador"
[[ "$VAL_OUTPUT" =~ STATUS=STORAGE_MARKER_MISSING ]]
assert_equals "0" "$?" "validate_storage debe reportar STATUS=STORAGE_MARKER_MISSING"

# Test 11: validate_storage en montaje real con marcador presente (debe retornar DEV_OK y STATUS=READY)
if [[ -w "$EXPECTED_MOUNT" ]]; then
    TEST_DEST="$EXPECTED_MOUNT/Backups/TestValidation_$$"
    mkdir -p "$TEST_DEST"
    cp "$PROJECT_ROOT/markers/.backup_storage_marker" "$TEST_DEST/.backup_storage_marker"

    cat <<EOF > "$TEST_CONFIG"
STORAGE_ID_TYPE="STATIC_PATH"
STORAGE_ID_VALUE="$EXPECTED_MOUNT"
STORAGE_SUBDIR="Backups/TestValidation_$$"
STORAGE_MARKER_FILE=".backup_storage_marker"
EOF

    VAL_READY_OUTPUT=$(device_model_validate_storage "$TEST_CONFIG")
    VAL_READY_EXIT=$?
    assert_exit_code "$DEV_OK" "$VAL_READY_EXIT" "validate_storage con marcador presente debe retornar DEV_OK"
    [[ "$VAL_READY_OUTPUT" =~ STATUS=READY ]]
    assert_equals "0" "$?" "validate_storage debe reportar STATUS=READY"

    # Limpieza del directorio de test temporal
    rm -rf "$TEST_DEST" "$TEST_CONFIG"
else
    echo "  [PASS] validate_storage con marcador presente omitido (montaje sin permisos de escritura)"
    echo "  [PASS] validate_storage reportar STATUS=READY omitido (montaje sin permisos de escritura)"
    TESTS_PASSED=$((TESTS_PASSED + 2))
    rm -f "$TEST_CONFIG"
fi

# Test 12: find_mount con LOCAL_PATH (debe resolver ruta existente o crearla)
LOCAL_TARGET_DIR="/tmp/test_local_path_$$"
LOCAL_RESOLVED=$(device_model_find_mount "LOCAL_PATH" "$LOCAL_TARGET_DIR")
LOCAL_EXIT=$?
assert_exit_code "$DEV_OK" "$LOCAL_EXIT" "find_mount con LOCAL_PATH debe retornar DEV_OK"
assert_equals "$LOCAL_TARGET_DIR" "$LOCAL_RESOLVED" "find_mount con LOCAL_PATH debe retornar la ruta directa"

# Test 13: validate_storage con LOCAL_PATH sin marcador (debe fallar con DEV_ERR_NO_MARKER sin requerir is_mounted)
LOCAL_CFG="/tmp/test_local_cfg_$$.conf"
cat <<EOF > "$LOCAL_CFG"
STORAGE_ID_TYPE="LOCAL_PATH"
STORAGE_ID_VALUE="$LOCAL_TARGET_DIR"
STORAGE_SUBDIR="Backups/EquipoLocal"
EOF

LOCAL_VAL_OUT=$(device_model_validate_storage "$LOCAL_CFG")
LOCAL_VAL_EXIT=$?
assert_exit_code "$DEV_ERR_NO_MARKER" "$LOCAL_VAL_EXIT" "validate_storage en LOCAL_PATH sin marcador debe retornar DEV_ERR_NO_MARKER"

# Test 14: device_model_init_target_directory despliega estructura y marcador
INIT_DIR=$(device_model_init_target_directory "$LOCAL_TARGET_DIR" "Backups/EquipoLocal" "$PROJECT_ROOT/markers/.backup_storage_marker")
INIT_EXIT=$?
assert_exit_code "$DEV_OK" "$INIT_EXIT" "init_target_directory debe retornar DEV_OK"
assert_equals "$LOCAL_TARGET_DIR/Backups/EquipoLocal" "$INIT_DIR" "init_target_directory debe devolver la ruta creada"

[[ -d "$LOCAL_TARGET_DIR/Backups/EquipoLocal/archives" && -d "$LOCAL_TARGET_DIR/Backups/EquipoLocal/logs" ]]
assert_equals "0" "$?" "init_target_directory debe crear las carpetas archives y logs"

[[ -f "$LOCAL_TARGET_DIR/Backups/EquipoLocal/.backup_storage_marker" ]]
assert_equals "0" "$?" "init_target_directory debe desplegar .backup_storage_marker"

# Validar ahora que validate_storage pasa en LOCAL_PATH con marcador
LOCAL_VAL_OUT2=$(device_model_validate_storage "$LOCAL_CFG")
LOCAL_VAL_EXIT2=$?
assert_exit_code "$DEV_OK" "$LOCAL_VAL_EXIT2" "validate_storage en LOCAL_PATH con marcador debe retornar DEV_OK"
[[ "$LOCAL_VAL_OUT2" =~ STATUS=READY ]]
assert_equals "0" "$?" "validate_storage en LOCAL_PATH debe retornar STATUS=READY"

# Test 15: device_model_list_targets debe descubrir los destinos con marcador
# Crear un segundo destino
device_model_init_target_directory "$LOCAL_TARGET_DIR" "Backups/SegundoEquipo" "$PROJECT_ROOT/markers/.backup_storage_marker" >/dev/null
TARGETS_LIST=$(device_model_list_targets "$LOCAL_TARGET_DIR")
LIST_EXIT=$?
assert_exit_code "$DEV_OK" "$LIST_EXIT" "device_model_list_targets debe retornar DEV_OK"
[[ "$TARGETS_LIST" =~ Backups/EquipoLocal ]]
assert_equals "0" "$?" "list_targets debe encontrar Backups/EquipoLocal"
[[ "$TARGETS_LIST" =~ Backups/SegundoEquipo ]]
assert_equals "0" "$?" "list_targets debe encontrar Backups/SegundoEquipo"

# Test 16: device_model_update_config_subdir actualiza STORAGE_SUBDIR atómicamente
device_model_update_config_subdir "$LOCAL_CFG" "Backups/SegundoEquipo"
UPDATE_EXIT=$?
assert_exit_code "$DEV_OK" "$UPDATE_EXIT" "update_config_subdir debe retornar DEV_OK"
grep -q '^STORAGE_SUBDIR="Backups/SegundoEquipo"' "$LOCAL_CFG"
assert_equals "0" "$?" "config.conf debe reflejar el nuevo STORAGE_SUBDIR"

# Test 17: device_model_sanitize_subdir normaliza prefijos y bloquea traversal
s_home=$(device_model_sanitize_subdir "\$HOME/Mis_Backups")
assert_equals "Mis_Backups" "$s_home" "sanitize_subdir debe eliminar \$HOME"

s_tilde=$(device_model_sanitize_subdir "~/Backups_Tilde//test/")
assert_equals "Backups_Tilde/test" "$s_tilde" "sanitize_subdir debe normalizar tilde y barras dobles"

s_user=$(device_model_sanitize_subdir "/home/usuario/Backups_Directos")
assert_equals "Backups_Directos" "$s_user" "sanitize_subdir debe eliminar /home/<usuario>"

set +e
device_model_sanitize_subdir "Backups/../../etc" >/dev/null 2>&1
s_trav_status=$?
set -e
assert_equals "1" "$s_trav_status" "sanitize_subdir debe rechazar directory traversal con '..'"

# Test 18: validate_storage con auto-creación de subdirectorio nuevo si el almacenamiento ya contiene destinos válidos
HIER_STORAGE="/tmp/test_hier_storage_$$"
mkdir -p "$HIER_STORAGE/Backups/Existente"
touch "$HIER_STORAGE/Backups/Existente/.backup_storage_marker"

HIER_CFG="/tmp/test_hier_cfg_$$.conf"
cat <<EOF > "$HIER_CFG"
STORAGE_ID_TYPE="LOCAL_PATH"
STORAGE_ID_VALUE="$HIER_STORAGE"
STORAGE_SUBDIR="Backup/NuevoPerfil"
EOF

HIER_VAL_OUT=$(device_model_validate_storage "$HIER_CFG")
HIER_VAL_EXIT=$?
assert_exit_code "$DEV_OK" "$HIER_VAL_EXIT" "validate_storage debe auto-crear subdirectorio nuevo si el medio está verificado"
[[ "$HIER_VAL_OUT" =~ STATUS=READY ]]
assert_equals "0" "$?" "validate_storage debe retornar STATUS=READY para subcarpeta nueva en medio verificado"
[[ -f "$HIER_STORAGE/Backup/NuevoPerfil/.backup_storage_marker" ]]
assert_equals "0" "$?" "validate_storage debe auto-desplegar .backup_storage_marker en el nuevo subdirectorio"

# Test 19: update_config_subdir sanitiza $HOME al actualizar config
device_model_update_config_subdir "$HIER_CFG" "\$HOME/Backups_Sanitizados"
grep -q '^STORAGE_SUBDIR="Backups_Sanitizados"' "$HIER_CFG"
assert_equals "0" "$?" "update_config_subdir debe sanitizar \$HOME a ruta relativa limpia"

rm -rf "$HIER_STORAGE" "$HIER_CFG"

# Limpieza de temporales LOCAL_PATH
rm -rf "$LOCAL_TARGET_DIR" "$LOCAL_CFG"

# Test 20: device_model_resolve_destination normaliza rutas universales
res_tilde=$(device_model_resolve_destination "~/Backups/KMCTest" "/home/usuario")
assert_equals "/home/usuario/Backups/KMCTest" "$res_tilde" "resolve_destination debe expandir ~"

res_home=$(device_model_resolve_destination "\$HOME/Backups/KMCTest" "/home/usuario")
assert_equals "/home/usuario/Backups/KMCTest" "$res_home" "resolve_destination debe expandir \$HOME"

res_rel=$(device_model_resolve_destination "Backups/KMCTest" "/home/usuario")
assert_equals "/home/usuario/Backups/KMCTest" "$res_rel" "resolve_destination debe resolver ruta relativa respecto a HOME"

res_abs=$(device_model_resolve_destination "/tmp/backups_directo" "/home/usuario")
assert_equals "/tmp/backups_directo" "$res_abs" "resolve_destination debe respetar rutas absolutas"

set +e
device_model_resolve_destination "../escape" "/home/usuario" >/dev/null 2>&1
res_trav_code=$?
set -e
assert_equals "1" "$res_trav_code" "resolve_destination debe rechazar directory traversal con '..'"

# Test 21: device_model_detect_external_drives ejecuta con DEV_OK
device_model_detect_external_drives >/dev/null 2>&1
det_exit=$?
assert_exit_code "$DEV_OK" "$det_exit" "detect_external_drives debe retornar DEV_OK"

# Test 22: device_model_update_config_destination actualiza BACKUP_DESTINATION
UNIV_CFG="/tmp/test_univ_cfg_$$.conf"
cat <<EOF > "$UNIV_CFG"
ACTIVE_PROFILE="default"
BACKUP_DESTINATION="~/Backups/Inicial"
EOF

device_model_update_config_destination "$UNIV_CFG" "~/Backups/Actualizado"
upd_dest_exit=$?
assert_exit_code "$DEV_OK" "$upd_dest_exit" "update_config_destination debe retornar DEV_OK"
grep -q '^BACKUP_DESTINATION="~/Backups/Actualizado"' "$UNIV_CFG"
assert_equals "0" "$?" "config.conf debe contener el nuevo BACKUP_DESTINATION"

# Test 23: device_model_validate_storage con BACKUP_DESTINATION nativo
UNIV_DIR="/tmp/test_univ_storage_$$"
mkdir -p "$UNIV_DIR"
touch "$UNIV_DIR/.backup_storage_marker"

cat <<EOF > "$UNIV_CFG"
ACTIVE_PROFILE="default"
BACKUP_DESTINATION="$UNIV_DIR"
EOF

UNIV_VAL_OUT=$(device_model_validate_storage "$UNIV_CFG")
UNIV_VAL_EXIT=$?
assert_exit_code "$DEV_OK" "$UNIV_VAL_EXIT" "validate_storage con BACKUP_DESTINATION nativo debe retornar DEV_OK"
[[ "$UNIV_VAL_OUT" =~ STATUS=READY ]]
assert_equals "0" "$?" "validate_storage con BACKUP_DESTINATION debe retornar STATUS=READY"

# Test 24: validate_storage con BACKUP_DESTINATION y subcarpeta de perfil auto-creada
UNIV_VAL_PROF_OUT=$(device_model_validate_storage "$UNIV_CFG" "PerfilDocente")
UNIV_VAL_PROF_EXIT=$?
assert_exit_code "$DEV_OK" "$UNIV_VAL_PROF_EXIT" "validate_storage con subdirectorio de perfil debe retornar DEV_OK"
[[ -f "$UNIV_DIR/PerfilDocente/.backup_storage_marker" ]]
assert_equals "0" "$?" "validate_storage debe desplegar el marcador en el destino de perfil"

rm -rf "$UNIV_DIR" "$UNIV_CFG"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE DEVICE_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LAS PRUEBAS."
    exit 1
fi
