#!/usr/bin/env bash
# ==============================================================================
# tests/test_backup_model.sh - Suite de Pruebas Unitarias para backup_model.sh
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
RECIPES_DIR="$PROJECT_ROOT/templates.d"

# Cargar el modelo
# shellcheck source=../lib/models/backup_model.sh
source "$PROJECT_ROOT/lib/models/backup_model.sh"

echo "=== Iniciando Tests Unitarios de lib/models/backup_model.sh ==="

SANDBOX_DIR=$(mktemp -d /tmp/test_backup_XXXXXX)
trap 'rm -rf "$SANDBOX_DIR"' EXIT

MOCK_STORAGE="$SANDBOX_DIR/storage"
MOCK_HOME="$SANDBOX_DIR/user_home"
mkdir -p "$MOCK_STORAGE" "$MOCK_HOME"

# ------------------------------------------------------------------------------
# Test 1: Generación de Timestamp
# ------------------------------------------------------------------------------
TS=$(backup_model_generate_timestamp)
[[ "$TS" =~ ^[0-9]{8}_[0-9]{6}$ ]]
assert_equals "0" "$?" "generate_timestamp debe coincidir con formato AAAAMMDD_HHMMSS"

# ------------------------------------------------------------------------------
# Test 2: Backup de módulo sin ficheros locales existentes
# ------------------------------------------------------------------------------
backup_model_run "vscode-standard" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$RECIPES_DIR" >/dev/null 2>&1
assert_exit_code "$BACKUP_ERR_NO_FILES" $? "backup_model_run sin ficheros locales debe retornar BACKUP_ERR_NO_FILES"

# ------------------------------------------------------------------------------
# Test 3: Backup de módulo estándar no sensible (vscode-standard)
# ------------------------------------------------------------------------------
mkdir -p "$MOCK_HOME/.config/Code/User/snippets"
echo '{"editor.tabSize": 4}' > "$MOCK_HOME/.config/Code/User/settings.json"
echo '{"key": "ctrl+shift+p"}' > "$MOCK_HOME/.config/Code/User/keybindings.json"
echo '// test snippet' > "$MOCK_HOME/.config/Code/User/snippets/html.json"

RUN_STD_OUT=$(backup_model_run "vscode-standard" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$RECIPES_DIR")
assert_exit_code "$BACKUP_OK" $? "backup_model_run de vscode-standard debe retornar BACKUP_OK"
[[ "$RUN_STD_OUT" =~ STATUS=SUCCESS ]]
assert_equals "0" "$?" "El reporte debe indicar STATUS=SUCCESS"
[[ "$RUN_STD_OUT" =~ IS_SENSITIVE=false ]]
assert_equals "0" "$?" "El reporte debe indicar IS_SENSITIVE=false"
[[ "$RUN_STD_OUT" =~ PURGED=false ]]
assert_equals "0" "$?" "No debe purgarse un módulo con PURGE_AFTER_BACKUP=false"

# Verificar ficheros creados en disco de almacenamiento
STD_ARCHIVE_DIR="$MOCK_STORAGE/archives/vscode-standard"
[[ -d "$STD_ARCHIVE_DIR" ]]
assert_equals "0" "$?" "El directorio de archivo del módulo debe crearse"

STD_TAR=$(find "$STD_ARCHIVE_DIR" -name "*.tar.zst")
[[ -f "$STD_TAR" ]]
assert_equals "0" "$?" "El archivo .tar.zst debe existir en destino"

STD_MANIFEST=$(find "$STD_ARCHIVE_DIR" -name "*.manifest.log")
[[ -f "$STD_MANIFEST" ]]
assert_equals "0" "$?" "El archivo .manifest.log debe existir en destino"

# Verificar que los ficheros locales siguen intactos
[[ -f "$MOCK_HOME/.config/Code/User/settings.json" ]]
assert_equals "0" "$?" "Los ficheros locales deben permanecer intactos en origen"

# Verificar registro en logs de historial
[[ -f "$MOCK_STORAGE/logs/backup_history.log" ]]
assert_equals "0" "$?" "El registro backup_history.log debe existir"
grep -qs "MODULE=vscode-standard STATUS=SUCCESS" "$MOCK_STORAGE/logs/backup_history.log"
assert_equals "0" "$?" "El log de auditoría debe contener la entrada del backup"

# ------------------------------------------------------------------------------
# Test 4: Backup de módulo sensible (vscode-sensitive)
# ------------------------------------------------------------------------------
mkdir -p "$MOCK_HOME/.config/Code/User/globalStorage" "$MOCK_HOME/.config/Code/User/sync"
echo "SECRET_DB_DATA_123" > "$MOCK_HOME/.config/Code/User/globalStorage/state.vscdb"
echo "SYNC_TOKEN_XYZ" > "$MOCK_HOME/.config/Code/User/sync/token.dat"

# Intento sin contraseña debe fallar
backup_model_run "vscode-sensitive" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$RECIPES_DIR" >/dev/null 2>&1
assert_exit_code "$BACKUP_ERR_PASSPHRASE" $? "backup de módulo sensible sin contraseña debe retornar BACKUP_ERR_PASSPHRASE"

# Respaldo con contraseña y purga automática (Vault & Shred)
SENS_PASS="PassphrasePrueba_2026!"
RUN_SENS_OUT=$(backup_model_run "vscode-sensitive" "$MOCK_STORAGE" "$MOCK_HOME" "$SENS_PASS" "false" "false" "$RECIPES_DIR")
assert_exit_code "$BACKUP_OK" $? "backup de módulo sensible con contraseña debe retornar BACKUP_OK"
[[ "$RUN_SENS_OUT" =~ IS_SENSITIVE=true ]]
assert_equals "0" "$?" "El reporte debe indicar IS_SENSITIVE=true"
[[ "$RUN_SENS_OUT" =~ PURGED=true ]]
assert_equals "0" "$?" "El reporte debe indicar PURGED=true (purga segura ejecutada)"

SENS_ARCHIVE_DIR="$MOCK_STORAGE/archives/vscode-sensitive"
SENS_GPG=$(find "$SENS_ARCHIVE_DIR" -name "*.tar.zst.gpg")
[[ -f "$SENS_GPG" ]]
assert_equals "0" "$?" "El archivo cifrado .tar.zst.gpg debe existir en el SSD"

# Verificar que los datos sensibles desaparecieron del equipo local por shred
[[ ! -e "$MOCK_HOME/.config/Code/User/globalStorage/state.vscdb" ]]
assert_equals "0" "$?" "El fichero sensible debe haber desaparecido de origen tras shred"
[[ ! -e "$MOCK_HOME/.config/Code/User/sync/token.dat" ]]
assert_equals "0" "$?" "El token sensible debe haber desaparecido de origen tras shred"

# ------------------------------------------------------------------------------
# Test 5: Cálculo de Diffs en segundo backup incremental
# ------------------------------------------------------------------------------
# Pausa breve para garantizar marca de tiempo posterior
sleep 1

# Modificamos un archivo y añadimos uno nuevo en vscode-standard
echo '{"editor.tabSize": 2, "modified": true}' > "$MOCK_HOME/.config/Code/User/settings.json"
echo '// nuevo snippet' > "$MOCK_HOME/.config/Code/User/snippets/css.json"

RUN_STD2_OUT=$(backup_model_run "vscode-standard" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$RECIPES_DIR")
assert_exit_code "$BACKUP_OK" $? "Segundo backup de vscode-standard debe retornar BACKUP_OK"

# Inspeccionar el segundo manifiesto
LATEST_MANIFEST=$(backup_model_find_latest_manifest "$STD_ARCHIVE_DIR")
[[ -f "$LATEST_MANIFEST" ]]
assert_equals "0" "$?" "Debe localizarse el último manifiesto generado"

grep -qs "\~ \.config/Code/User/settings.json" "$LATEST_MANIFEST"
assert_equals "0" "$?" "El manifiesto debe marcar settings.json como modificado (~)"

grep -qs "+ \.config/Code/User/snippets/css.json" "$LATEST_MANIFEST"
assert_equals "0" "$?" "El manifiesto debe marcar css.json como añadido (+)"

# ------------------------------------------------------------------------------
# Test 6: Listado de Histórico
# ------------------------------------------------------------------------------
HIST_LIST=$(backup_model_list_history "vscode-standard" "$MOCK_STORAGE")
HIST_COUNT=$(echo "$HIST_LIST" | wc -l)
assert_equals "2" "$HIST_COUNT" "backup_model_list_history debe retornar las 2 marcas de tiempo de vscode-standard"

# ------------------------------------------------------------------------------
# Test 7: backup_model_run_by_tag con etiqueta inexistente
# ------------------------------------------------------------------------------
backup_model_run_by_tag "etiqueta_inexistente" "$MOCK_STORAGE" "$MOCK_HOME" "" "auto" "$RECIPES_DIR" >/dev/null 2>&1
assert_exit_code "$BACKUP_ERR_MODULE" $? "run_by_tag en etiqueta inexistente debe retornar BACKUP_ERR_MODULE"

# ------------------------------------------------------------------------------
# Test 8: backup_model_run_by_tag con etiqueta válida
# ------------------------------------------------------------------------------
TAG_OUT=$(backup_model_run_by_tag "editor" "$MOCK_STORAGE" "$MOCK_HOME" "clave123" "false" "$RECIPES_DIR")
assert_exit_code "$BACKUP_OK" $? "run_by_tag con etiqueta válida debe retornar BACKUP_OK"
echo "$TAG_OUT" | grep -qs "BACKUP_SUCCESS=vscode-standard"
assert_equals "0" "$?" "run_by_tag debe reportar éxito para vscode-standard"

# ------------------------------------------------------------------------------
# Test 9: backup_model_run_all
# ------------------------------------------------------------------------------
mkdir -p "$MOCK_HOME/.ssh"
echo "ssh-rsa AAAA..." > "$MOCK_HOME/.ssh/id_rsa"
echo "export FOO=BAR" > "$MOCK_HOME/.bashrc"

ALL_OUT=$(backup_model_run_all "$MOCK_STORAGE" "$MOCK_HOME" "clave123" "false" "$RECIPES_DIR")
assert_exit_code "$BACKUP_OK" $? "backup_model_run_all debe retornar BACKUP_OK"
echo "$ALL_OUT" | grep -qs "BACKUP_SUCCESS=vscode-standard"
assert_equals "0" "$?" "run_all debe incluir vscode-standard"
echo "$ALL_OUT" | grep -qs "BACKUP_SUCCESS=bash-env"
assert_equals "0" "$?" "run_all debe incluir bash-env"


# ------------------------------------------------------------------------------
# Test 10: Validación directa de backup_model_verify_purge_safety
# ------------------------------------------------------------------------------
SAFE_TEST_DIR="$SANDBOX_DIR/safe_gate_test"
mkdir -p "$SAFE_TEST_DIR"
TEST_ARCHIVE="$SAFE_TEST_DIR/test_backup.tar.zst"
TEST_MANIFEST="$SAFE_TEST_DIR/test_backup.manifest.log"

echo "CONTENIDO_REAL_BACKUP" > "$TEST_ARCHIVE"
echo "MANIFEST_VALIDO" > "$TEST_MANIFEST"

backup_model_verify_purge_safety "$TEST_ARCHIVE" "$TEST_MANIFEST"
assert_exit_code "0" "$?" "verify_purge_safety debe retornar 0 cuando archivo y manifiesto son válidos y >0 bytes"

# Fichero inexistente
set +e
backup_model_verify_purge_safety "$SAFE_TEST_DIR/fantasma.tar.zst" "$TEST_MANIFEST"
gate_res_missing=$?
set -e
assert_exit_code "1" "$gate_res_missing" "verify_purge_safety debe retornar 1 si el archivo de backup no existe"

# Fichero vacío (0 bytes)
: > "$SAFE_TEST_DIR/empty.tar.zst"
set +e
backup_model_verify_purge_safety "$SAFE_TEST_DIR/empty.tar.zst" "$TEST_MANIFEST"
gate_res_empty=$?
set -e
assert_exit_code "1" "$gate_res_empty" "verify_purge_safety debe retornar 1 si el archivo de backup tiene 0 bytes"

# Ruta con barras duplicadas
set +e
backup_model_verify_purge_safety "$SAFE_TEST_DIR//test_backup.tar.zst" "$TEST_MANIFEST"
gate_res_slash=$?
set -e
assert_exit_code "1" "$gate_res_slash" "verify_purge_safety debe retornar 1 si la ruta contiene //"

# Ruta con recursión
set +e
backup_model_verify_purge_safety "$SAFE_TEST_DIR/$SAFE_TEST_DIR/test_backup.tar.zst" "$TEST_MANIFEST"
gate_res_rec=$?
set -e
assert_exit_code "1" "$gate_res_rec" "verify_purge_safety debe retornar 1 si la ruta contiene recursión"

# ------------------------------------------------------------------------------
# Test 11: Simulación de fallo en Safe Destruction Gate protegiendo archivos de origen
# ------------------------------------------------------------------------------
# Crear archivo sensible en origen
mkdir -p "$MOCK_HOME/sensitive_test"
echo "SECRET_LOCAL_CANNOT_BE_PURGED" > "$MOCK_HOME/sensitive_test/secret.txt"

# Crear una receta de prueba con PURGE_AFTER_BACKUP=true
TEST_RECIPES_DIR="$SANDBOX_DIR/test_recipes"
mkdir -p "$TEST_RECIPES_DIR"
cat <<EOF > "$TEST_RECIPES_DIR/safe-gate-mod.conf"
MODULE_ID="safe-gate-mod"
MODULE_NAME="Safe Gate Test Module"
MODULE_DESCRIPTION="Prueba de salvaguarda"
MODULE_TAGS=("test")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=true
MODULE_PATHS=("sensitive_test/secret.txt")
EOF

# Sobrescribir temporalmente backup_model_verify_purge_safety para forzar fallo
eval "$(echo 'backup_model_verify_purge_safety() { return 1; }')"

set +e
RUN_GATE_FAIL_OUT=$(backup_model_run "safe-gate-mod" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$TEST_RECIPES_DIR" 2>/dev/null)
gate_run_exit=$?
set -e

assert_exit_code "$BACKUP_ERR_SAFE_PURGE_GATE" "$gate_run_exit" "backup_model_run debe abortar con BACKUP_ERR_SAFE_PURGE_GATE si la salvaguarda falla"
[[ "$RUN_GATE_FAIL_OUT" =~ STATUS=SAFE_PURGE_ABORTED ]]
assert_equals "0" "$?" "El reporte debe indicar STATUS=SAFE_PURGE_ABORTED"
[[ -f "$MOCK_HOME/sensitive_test/secret.txt" ]]
assert_equals "0" "$?" "Los archivos originales del usuario NO deben haber sido borrados tras el bloqueo de la salvaguarda"

# Restaurar función real
# shellcheck source=../lib/models/backup_model.sh
source "$PROJECT_ROOT/lib/models/backup_model.sh"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE BACKUP_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LAS PRUEBAS."
    exit 1
fi
