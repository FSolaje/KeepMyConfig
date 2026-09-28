#!/usr/bin/env bash
# ==============================================================================
# tests/test_path_manager.sh - Suite Integral de Validación de Rutas y Seguridad
# ==============================================================================
# Valida de extremo a extremo:
# 1. Desacoplamiento de destinos absolutos vs subcarpetas relativas en perfiles.
# 2. Normalización canónica de rutas y detección de recursión/duplicación.
# 3. Despliegue asistido y desatendido de marcadores en perfiles.
# 4. Safe Destruction Gate previo a la purga shred en backup_model.
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar componentes del sistema
# shellcheck source=../lib/views/ansi_view.sh
source "$PROJECT_ROOT/lib/views/ansi_view.sh"
# shellcheck source=../lib/views/whiptail_view.sh
source "$PROJECT_ROOT/lib/views/whiptail_view.sh"
# shellcheck source=../lib/models/device_model.sh
source "$PROJECT_ROOT/lib/models/device_model.sh"
# shellcheck source=../lib/models/profile_model.sh
source "$PROJECT_ROOT/lib/models/profile_model.sh"
# shellcheck source=../lib/models/backup_model.sh
source "$PROJECT_ROOT/lib/models/backup_model.sh"
# shellcheck source=../lib/controllers/app_controller.sh
source "$PROJECT_ROOT/lib/controllers/app_controller.sh"

# Inicializar controlador
controller_init "$PROJECT_ROOT"

echo "=== Iniciando Suite Integral: Gestor Robusto de Rutas y Almacenamiento ==="

SANDBOX_DIR=$(mktemp -d /tmp/test_path_mgr_XXXXXX)
trap 'rm -rf "$SANDBOX_DIR"' EXIT

BASE_STORAGE="$SANDBOX_DIR/almacenamiento_base"
EXTERNAL_STORAGE="$SANDBOX_DIR/almacenamiento_externo"
PROFILES_DIR="$SANDBOX_DIR/profiles"
USER_HOME="$SANDBOX_DIR/home_usuario"

mkdir -p "$BASE_STORAGE" "$EXTERNAL_STORAGE" "$PROFILES_DIR" "$USER_HOME"
touch "$BASE_STORAGE/.backup_storage_marker"
touch "$EXTERNAL_STORAGE/.backup_storage_marker"

# ------------------------------------------------------------------------------
# Test 1: Desacoplamiento de Destino Absoluto en Perfil (Override Autónomo)
# ------------------------------------------------------------------------------
# Creamos un perfil cuyo TARGET_SUBDIR es una ruta absoluta externa
profile_model_create "perfil-externo" "Perfil Externo" "Prueba de override" "$EXTERNAL_STORAGE/MisBackups" "$PROFILES_DIR" >/dev/null
assert_exit_code "0" "$?" "profile_model_create con ruta absoluta debe retornar 0"

RES_EXT=$(profile_model_get_destination "perfil-externo" "$BASE_STORAGE" "$PROFILES_DIR")
assert_equals "$EXTERNAL_STORAGE/MisBackups" "$RES_EXT" "profile_model_get_destination con ruta absoluta debe devolver la ruta externa directa sin concatenar al base"

# ------------------------------------------------------------------------------
# Test 2: Subcarpeta Relativa en Perfil
# ------------------------------------------------------------------------------
profile_model_create "perfil-relativo" "Perfil Relativo" "Prueba relativa" "Subcarpeta/EquipoA" "$PROFILES_DIR" >/dev/null
assert_exit_code "0" "$?" "profile_model_create con subcarpeta relativa debe retornar 0"

RES_REL=$(profile_model_get_destination "perfil-relativo" "$BASE_STORAGE" "$PROFILES_DIR")
assert_equals "$BASE_STORAGE/Subcarpeta/EquipoA" "$RES_REL" "profile_model_get_destination con subcarpeta relativa debe concatenar al destino base"

# ------------------------------------------------------------------------------
# Test 3: Normalización de Destino con ~ y $HOME
# ------------------------------------------------------------------------------
SAN_TILDE=$(profile_model_sanitize_target_subdir "~/Backups/MiEquipo" "$USER_HOME")
assert_equals "Backups/MiEquipo" "$SAN_TILDE" "profile_model_sanitize_target_subdir debe sanitizar ~ a subcarpeta relativa limpia"

RES_TILDE=$(device_model_resolve_destination "~/Backups/MiEquipo" "$USER_HOME")
assert_equals "$USER_HOME/Backups/MiEquipo" "$RES_TILDE" "device_model_resolve_destination debe expandir ~ al home del usuario"

# ------------------------------------------------------------------------------
# Test 4: Normalización Canónica device_model_normalize_path
# ------------------------------------------------------------------------------
NORM_OUT=$(device_model_normalize_path "///media//usuario///DISCO_BACKUP///Subdir///")
assert_equals "/media/usuario/DISCO_BACKUP/Subdir" "$NORM_OUT" "normalize_path debe colapsar barras duplicadas y trailing slashes"

NORM_DOT=$(device_model_normalize_path "/media/usuario/./DISCO_BACKUP/./Subdir/.")
assert_equals "/media/usuario/DISCO_BACKUP/Subdir" "$NORM_DOT" "normalize_path debe resolver segmentos /./"

set +e
device_model_normalize_path "/media/usuario/../../escape" >/dev/null 2>&1
NORM_TRAV_EXIT=$?
set -e
assert_equals "1" "$NORM_TRAV_EXIT" "normalize_path debe rechazar directory traversal con '..'"

# ------------------------------------------------------------------------------
# Test 5: Detector Anti-Recursión device_model_detect_path_recursion
# ------------------------------------------------------------------------------
set +e
device_model_detect_path_recursion "/media/usuario/DISCO_BACKUP" "/media/usuario/DISCO_BACKUP/Backups/Perfil1"
REC_CLEAN_EXIT=$?
set -e
assert_equals "1" "$REC_CLEAN_EXIT" "detect_path_recursion debe aprobar ruta lineal sana (retornando 1)"

device_model_detect_path_recursion "/media/usuario/DISCO_BACKUP" "/media/usuario/DISCO_BACKUP/media/usuario/DISCO_BACKUP/Backups"
assert_exit_code "0" "$?" "detect_path_recursion debe detectar base duplicada en destino"

device_model_detect_path_recursion "" "/media/usuario/DISCO_BACKUP/Backups/Backups/Carpeta"
assert_exit_code "0" "$?" "detect_path_recursion debe detectar segmentos idénticos consecutivos repetidos"

# ------------------------------------------------------------------------------
# Test 6: Bloqueo en device_model_validate_storage ante recursión
# ------------------------------------------------------------------------------
REC_CFG="$SANDBOX_DIR/config_recursion.conf"
cat <<EOF > "$REC_CFG"
ACTIVE_PROFILE="default"
BACKUP_DESTINATION="$BASE_STORAGE"
EOF

set +e
VAL_REC_OUT=$(device_model_validate_storage "$REC_CFG" "$BASE_STORAGE/$BASE_STORAGE/Backups")
VAL_REC_EXIT=$?
set -e
assert_exit_code "$DEV_ERR_RECURSIVE_PATH" "$VAL_REC_EXIT" "validate_storage debe retornar DEV_ERR_RECURSIVE_PATH (12) ante ruta duplicada"
[[ "$VAL_REC_OUT" =~ STATUS=RECURSIVE_PATH_DETECTED ]]
assert_equals "0" "$?" "validate_storage debe emitir STATUS=RECURSIVE_PATH_DETECTED"

# ------------------------------------------------------------------------------
# Test 7: Despliegue asistido de marcador al crear perfil con init_storage=true
# ------------------------------------------------------------------------------
TARGET_NUEVO="$SANDBOX_DIR/nuevo_almacenamiento_sin_marcador"
mkdir -p "$TARGET_NUEVO"
rm -f "$TARGET_NUEVO/.backup_storage_marker"

controller_handle_create_profile "perfil-autoinit" "Auto Init" "Desc" "$TARGET_NUEVO" "false" "true" >/dev/null
assert_exit_code "0" "$?" "controller_handle_create_profile con init_storage=true debe retornar 0"
[[ -f "$TARGET_NUEVO/.backup_storage_marker" ]]
assert_equals "0" "$?" "El marcador .backup_storage_marker debe haberse desplegado en el destino del perfil"
[[ -d "$TARGET_NUEVO/archives" ]]
assert_equals "0" "$?" "La subcarpeta archives debe haberse creado en el destino"
[[ -d "$TARGET_NUEVO/logs" ]]
assert_equals "0" "$?" "La subcarpeta logs debe haberse creado en el destino"

# ------------------------------------------------------------------------------
# Test 8: Despliegue desatendido en CLI con --init-storage
# ------------------------------------------------------------------------------
TARGET_CLI="$SANDBOX_DIR/nuevo_storage_cli"
mkdir -p "$TARGET_CLI"

controller_run_cli --create-profile "perfil-cli" --target-subdir "$TARGET_CLI" --init-storage >/dev/null
assert_exit_code "0" "$?" "CLI --create-profile con --init-storage debe retornar 0"
[[ -f "$TARGET_CLI/.backup_storage_marker" ]]
assert_equals "0" "$?" "CLI --init-storage debe desplegar el marcador en el destino indicado"

# ------------------------------------------------------------------------------
# Test 9: Safe Destruction Gate bloquea la purga ante archivo inexistente o vacío
# ------------------------------------------------------------------------------
GATE_DIR="$SANDBOX_DIR/gate_test"
mkdir -p "$GATE_DIR"
ARCHIVE_VALIDO="$GATE_DIR/valido.tar.zst"
MANIFEST_VALIDO="$GATE_DIR/valido.manifest.log"
echo "DATOS" > "$ARCHIVE_VALIDO"
echo "MANIFEST" > "$MANIFEST_VALIDO"

backup_model_verify_purge_safety "$ARCHIVE_VALIDO" "$MANIFEST_VALIDO"
assert_exit_code "0" "$?" "verify_purge_safety debe retornar 0 con archivo y manifiesto íntegros"

# Archivo de 0 bytes
: > "$GATE_DIR/vacio.tar.zst"
set +e
backup_model_verify_purge_safety "$GATE_DIR/vacio.tar.zst" "$MANIFEST_VALIDO"
GATE_VACIO_EXIT=$?
set -e
assert_equals "1" "$GATE_VACIO_EXIT" "verify_purge_safety debe retornar 1 ante archivo de 0 bytes"

# Ruta con barras duplicadas //
set +e
backup_model_verify_purge_safety "$GATE_DIR//valido.tar.zst" "$MANIFEST_VALIDO"
GATE_SLASH_EXIT=$?
set -e
assert_equals "1" "$GATE_SLASH_EXIT" "verify_purge_safety debe retornar 1 ante ruta con //"

# ------------------------------------------------------------------------------
# Test 10: Safe Destruction Gate preserva archivos locales intactos en caso de fallo
# ------------------------------------------------------------------------------
mkdir -p "$USER_HOME/datos_sensibles"
echo "CLAVE_PRIVADA_IMPORTANTE" > "$USER_HOME/datos_sensibles/key.pem"

RECIPES_DIR="$SANDBOX_DIR/recetas"
mkdir -p "$RECIPES_DIR"
cat <<EOF > "$RECIPES_DIR/modulo-seguro.conf"
MODULE_ID="modulo-seguro"
MODULE_NAME="Modulo Seguro"
MODULE_DESCRIPTION="Prueba de proteccion"
MODULE_TAGS=("seguridad")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=true
MODULE_PATHS=("datos_sensibles/key.pem")
EOF

# Forzar fallo simulando que la salvaguarda detecta inconsistencia en destino
eval "$(echo 'backup_model_verify_purge_safety() { return 1; }')"

set +e
RUN_GATE_OUT=$(backup_model_run "modulo-seguro" "$BASE_STORAGE" "$USER_HOME" "" "false" "false" "$RECIPES_DIR" 2>/dev/null)
RUN_GATE_EXIT=$?
set -e

assert_exit_code "$BACKUP_ERR_SAFE_PURGE_GATE" "$RUN_GATE_EXIT" "backup_model_run debe retornar BACKUP_ERR_SAFE_PURGE_GATE si la salvaguarda falla"
[[ "$RUN_GATE_OUT" =~ STATUS=SAFE_PURGE_ABORTED ]]
assert_equals "0" "$?" "El reporte debe confirmar STATUS=SAFE_PURGE_ABORTED"
[[ -f "$USER_HOME/datos_sensibles/key.pem" ]]
assert_equals "0" "$?" "El archivo local del usuario DEBE permanecer intacto (shred cancelado por salvaguarda)"

# Restaurar función
# shellcheck source=../lib/models/backup_model.sh
source "$PROJECT_ROOT/lib/models/backup_model.sh"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS DE LA SUITE DE PATH MANAGER HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LA SUITE DE PATH MANAGER."
    exit 1
fi
