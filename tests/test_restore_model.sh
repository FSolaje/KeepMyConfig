#!/usr/bin/env bash
# ==============================================================================
# tests/test_restore_model.sh - Suite de Pruebas Unitarias para restore_model.sh
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

# Cargar modelos necesarios
# shellcheck source=../lib/models/backup_model.sh
source "$PROJECT_ROOT/lib/models/backup_model.sh"
# shellcheck source=../lib/models/restore_model.sh
source "$PROJECT_ROOT/lib/models/restore_model.sh"

echo "=== Iniciando Tests Unitarios de lib/models/restore_model.sh ==="

SANDBOX_DIR=$(mktemp -d /tmp/test_restore_XXXXXX)
trap 'rm -rf "$SANDBOX_DIR"' EXIT

MOCK_STORAGE="$SANDBOX_DIR/storage"
MOCK_HOME="$SANDBOX_DIR/user_home"
mkdir -p "$MOCK_STORAGE" "$MOCK_HOME"

# ------------------------------------------------------------------------------
# Test 1: Búsqueda de Archivo en Módulo Inexistente
# ------------------------------------------------------------------------------
restore_model_find_archive "modulo_inexistente" "$MOCK_STORAGE" >/dev/null 2>&1
assert_exit_code "$RESTORE_ERR_NO_ARCHIVE" $? "find_archive en módulo inexistente debe retornar RESTORE_ERR_NO_ARCHIVE"

# ------------------------------------------------------------------------------
# Preparación de datos y respaldos previos
# ------------------------------------------------------------------------------
# 1. Preparar y respaldar vscode-standard
mkdir -p "$MOCK_HOME/.config/Code/User"
echo '{"theme": "dark_default"}' > "$MOCK_HOME/.config/Code/User/settings.json"
echo '{"key": "ctrl+k"}' > "$MOCK_HOME/.config/Code/User/keybindings.json"
RUN_STD=$(backup_model_run "vscode-standard" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$PROJECT_ROOT/modules.d")
STD_TS=$(echo "$RUN_STD" | awk -F'=' '$1 == "TIMESTAMP" {print $2}')

# 2. Preparar y respaldar vscode-sensitive
mkdir -p "$MOCK_HOME/.config/Code/User/sync"
echo "TOKEN_SESSION_4455" > "$MOCK_HOME/.config/Code/User/sync/auth.dat"
PASS_SECRET="ClaveSecreta_9876"
# Respaldamos sin purga para poder testear su contenido
backup_model_run "vscode-sensitive" "$MOCK_STORAGE" "$MOCK_HOME" "$PASS_SECRET" "false" "true" "$PROJECT_ROOT/modules.d" >/dev/null

# 3. Preparar y respaldar ssh-keys
mkdir -p "$MOCK_HOME/.ssh"
echo "MOCK_SSH_PRIVATE_KEY" > "$MOCK_HOME/.ssh/id_rsa"
backup_model_run "ssh-keys" "$MOCK_STORAGE" "$MOCK_HOME" "$PASS_SECRET" "false" "true" "$PROJECT_ROOT/modules.d" >/dev/null

# ------------------------------------------------------------------------------
# Test 2: find_archive en módulo existente
# ------------------------------------------------------------------------------
FIND_OUT=$(restore_model_find_archive "vscode-standard" "$MOCK_STORAGE")
assert_exit_code "$RESTORE_OK" $? "find_archive en módulo existente debe retornar RESTORE_OK"
[[ "$FIND_OUT" =~ TIMESTAMP=$STD_TS ]]
assert_equals "0" "$?" "find_archive debe resolver el timestamp correcto"
[[ "$FIND_OUT" =~ IS_ENCRYPTED=false ]]
assert_equals "0" "$?" "vscode-standard debe reportar IS_ENCRYPTED=false"

FIND_SENS=$(restore_model_find_archive "vscode-sensitive" "$MOCK_STORAGE")
assert_exit_code "$RESTORE_OK" $? "find_archive en módulo sensible debe retornar RESTORE_OK"
[[ "$FIND_SENS" =~ IS_ENCRYPTED=true ]]
assert_equals "0" "$?" "vscode-sensitive debe reportar IS_ENCRYPTED=true"

# ------------------------------------------------------------------------------
# Test 3: Restauración de Módulo Estándar
# ------------------------------------------------------------------------------
# Simulamos pérdida del archivo local
rm -rf "$MOCK_HOME/.config/Code/User/settings.json"
[[ ! -f "$MOCK_HOME/.config/Code/User/settings.json" ]]
assert_equals "0" "$?" "settings.json debe haber sido eliminado para probar recuperación"

RESTORE_STD_OUT=$(restore_model_restore_module "vscode-standard" "$MOCK_STORAGE" "$MOCK_HOME" "" "" "$PROJECT_ROOT/modules.d")
assert_exit_code "$RESTORE_OK" $? "restore_module en vscode-standard debe retornar RESTORE_OK"
[[ "$RESTORE_STD_OUT" =~ STATUS=SUCCESS ]]
assert_equals "0" "$?" "El reporte debe indicar STATUS=SUCCESS"

# Verificar contenido restituido
[[ -f "$MOCK_HOME/.config/Code/User/settings.json" ]]
assert_equals "0" "$?" "settings.json debe reaparecer en el HOME tras la restauración"
RESTORED_THEME=$(grep "dark_default" "$MOCK_HOME/.config/Code/User/settings.json" || true)
[[ -n "$RESTORED_THEME" ]]
assert_equals "0" "$?" "El contenido restituido debe ser idéntico al respaldado"

# ------------------------------------------------------------------------------
# Test 4: Restauración de Módulo Sensible Cifrado
# ------------------------------------------------------------------------------
# Borramos el token local
rm -rf "$MOCK_HOME/.config/Code/User/sync"

# Intento con contraseña errónea debe fallar
restore_model_restore_module "vscode-sensitive" "$MOCK_STORAGE" "$MOCK_HOME" "" "ContrasenaErronea" "$PROJECT_ROOT/modules.d" >/dev/null 2>&1
assert_exit_code "$RESTORE_ERR_PASSPHRASE" $? "restore_module sensible con clave incorrecta debe retornar RESTORE_ERR_PASSPHRASE"
[[ ! -f "$MOCK_HOME/.config/Code/User/sync/auth.dat" ]]
assert_equals "0" "$?" "El archivo sensible no debe restaurarse si la clave es incorrecta"

# Intento con contraseña correcta
RESTORE_SENS_OUT=$(restore_model_restore_module "vscode-sensitive" "$MOCK_STORAGE" "$MOCK_HOME" "" "$PASS_SECRET" "$PROJECT_ROOT/modules.d")
assert_exit_code "$RESTORE_OK" $? "restore_module sensible con clave correcta debe retornar RESTORE_OK"
[[ "$RESTORE_SENS_OUT" =~ STATUS=SUCCESS ]]
assert_equals "0" "$?" "El reporte sensible debe indicar STATUS=SUCCESS"
[[ -f "$MOCK_HOME/.config/Code/User/sync/auth.dat" ]]
assert_equals "0" "$?" "auth.dat debe reaparecer tras descifrado exitoso"
grep -qs "TOKEN_SESSION_4455" "$MOCK_HOME/.config/Code/User/sync/auth.dat"
assert_equals "0" "$?" "El contenido sensible descifrado debe coincidir exactamente"

# ------------------------------------------------------------------------------
# Test 5: Ejecución de POST_RESTORE_HOOK
# ------------------------------------------------------------------------------
HOOK_MOD_DIR="$SANDBOX_DIR/custom_modules"
mkdir -p "$HOOK_MOD_DIR"
module_model_save "hook-module" "Hook Test Module" "dev" ".bash_aliases" "false" "false" "touch hook_executed.marker" "$HOOK_MOD_DIR"

echo "alias ll='ls -la'" > "$MOCK_HOME/.bash_aliases"
backup_model_run "hook-module" "$MOCK_STORAGE" "$MOCK_HOME" "" "false" "false" "$HOOK_MOD_DIR" >/dev/null

rm -f "$MOCK_HOME/.bash_aliases" "$MOCK_HOME/hook_executed.marker"
restore_model_restore_module "hook-module" "$MOCK_STORAGE" "$MOCK_HOME" "" "" "$HOOK_MOD_DIR" >/dev/null
assert_exit_code "$RESTORE_OK" $? "restore_module con hook debe retornar RESTORE_OK"
[[ -f "$MOCK_HOME/hook_executed.marker" ]]
assert_equals "0" "$?" "El hook posterior debe haberse ejecutado creando hook_executed.marker"

# ------------------------------------------------------------------------------
# Test 6: Restauración por Etiqueta (restore_by_tag)
# ------------------------------------------------------------------------------
rm -rf "$MOCK_HOME/.config/Code/User/settings.json"
TAG_RESTORE_OUT=$(restore_model_restore_by_tag "editor" "$MOCK_STORAGE" "$MOCK_HOME" "" "$PROJECT_ROOT/modules.d")
assert_exit_code "$RESTORE_OK" $? "restore_by_tag 'editor' debe retornar RESTORE_OK"
[[ "$TAG_RESTORE_OUT" =~ RESTORED=vscode-standard ]]
assert_equals "0" "$?" "restore_by_tag debe reportar RESTORED=vscode-standard"
[[ -f "$MOCK_HOME/.config/Code/User/settings.json" ]]
assert_equals "0" "$?" "settings.json debe ser recuperado por la etiqueta 'editor'"

# ------------------------------------------------------------------------------
# Test 7: Restauración Express Sensible (restore_sensitive_all)
# ------------------------------------------------------------------------------
rm -rf "$MOCK_HOME/.config/Code/User/sync/auth.dat"
EXPRESS_OUT=$(restore_model_restore_sensitive_all "$MOCK_STORAGE" "$MOCK_HOME" "$PASS_SECRET" "$PROJECT_ROOT/modules.d")
assert_exit_code "$RESTORE_OK" $? "restore_sensitive_all con clave única debe retornar RESTORE_OK"
[[ "$EXPRESS_OUT" =~ RESTORED_SENSITIVE=vscode-sensitive ]]
assert_equals "0" "$?" "restore_sensitive_all debe procesar vscode-sensitive"
[[ -f "$MOCK_HOME/.config/Code/User/sync/auth.dat" ]]
assert_equals "0" "$?" "auth.dat debe reaparecer tras restauración express"

# ------------------------------------------------------------------------------
# Test 8: Restauración Total (restore_all)
# ------------------------------------------------------------------------------
rm -rf "$MOCK_HOME/.config/Code/User/settings.json" "$MOCK_HOME/.config/Code/User/sync/auth.dat"
ALL_OUT=$(restore_model_restore_all "$MOCK_STORAGE" "$MOCK_HOME" "$PASS_SECRET" "$PROJECT_ROOT/modules.d")
assert_exit_code "$RESTORE_OK" $? "restore_all debe retornar RESTORE_OK"
[[ "$ALL_OUT" =~ RESTORED=vscode-standard && "$ALL_OUT" =~ RESTORED=vscode-sensitive ]]
assert_equals "0" "$?" "restore_all debe haber restaurado tanto módulos estándar como sensibles"
[[ -f "$MOCK_HOME/.config/Code/User/settings.json" && -f "$MOCK_HOME/.config/Code/User/sync/auth.dat" ]]
assert_equals "0" "$?" "Todos los ficheros deben estar presentes tras restauración total"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE RESTORE_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LAS PRUEBAS."
    exit 1
fi
