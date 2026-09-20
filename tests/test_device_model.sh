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

# Test 3: find_mount con el dispositivo real DISCO_BACKUP
EXPECTED_MOUNT=$(findmnt -rn -S LABEL="DISCO_BACKUP" -o TARGET 2>/dev/null || lsblk -rno MOUNTPOINT,LABEL 2>/dev/null | awk '$2 == "DISCO_BACKUP" {print $1; exit}')
REAL_MOUNT=$(device_model_find_mount "LABEL" "DISCO_BACKUP")
EXIT_CODE=$?
assert_exit_code "$DEV_OK" $EXIT_CODE "find_mount con LABEL 'DISCO_BACKUP' debe retornar 0"
assert_equals "$EXPECTED_MOUNT" "$REAL_MOUNT" "find_mount debe resolver la ruta de montaje exacta"

# Test 4: find_mount con UUID real
REAL_MOUNT_UUID=$(device_model_find_mount "UUID" "UUID")
assert_exit_code "$DEV_OK" $? "find_mount con UUID 'UUID' debe retornar 0"
assert_equals "$EXPECTED_MOUNT" "$REAL_MOUNT_UUID" "find_mount por UUID debe resolver la ruta exacta"

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

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE DEVICE_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LAS PRUEBAS."
    exit 1
fi
