#!/usr/bin/env bash
# ==============================================================================
# tests/test_module_model.sh - Suite de Pruebas Unitarias para module_model.sh
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

# Cargar el modelo
# shellcheck source=../lib/models/module_model.sh
source "$PROJECT_ROOT/lib/models/module_model.sh"

echo "=== Iniciando Tests Unitarios de lib/models/module_model.sh ==="

# ------------------------------------------------------------------------------
# Test 1: Validación de IDs
# ------------------------------------------------------------------------------
module_model_validate_id "valid-module_1"
assert_exit_code "$MOD_OK" $? "validate_id con ID válido alfanumérico debe retornar MOD_OK"

module_model_validate_id "invalid module"
assert_exit_code "$MOD_ERR_INVALID_ID" $? "validate_id con espacios debe retornar MOD_ERR_INVALID_ID"

module_model_validate_id "invalid!char"
assert_exit_code "$MOD_ERR_INVALID_ID" $? "validate_id con caracteres especiales debe retornar MOD_ERR_INVALID_ID"

module_model_validate_id ""
assert_exit_code "$MOD_ERR_INVALID_ID" $? "validate_id vacío debe retornar MOD_ERR_INVALID_ID"

# ------------------------------------------------------------------------------
# Test 2: module_model_get en módulos base
# ------------------------------------------------------------------------------
OUT_STD=$(module_model_get "vscode-standard" "$PROJECT_ROOT/modules.d")
assert_exit_code "$MOD_OK" $? "module_model_get 'vscode-standard' debe retornar 0"
[[ "$OUT_STD" =~ IS_SENSITIVE=false ]]
assert_equals "0" "$?" "vscode-standard debe tener IS_SENSITIVE=false"
[[ "$OUT_STD" =~ PURGE_AFTER_BACKUP=false ]]
assert_equals "0" "$?" "vscode-standard debe tener PURGE_AFTER_BACKUP=false"

OUT_SENS=$(module_model_get "vscode-sensitive" "$PROJECT_ROOT/modules.d")
assert_exit_code "$MOD_OK" $? "module_model_get 'vscode-sensitive' debe retornar 0"
[[ "$OUT_SENS" =~ IS_SENSITIVE=true ]]
assert_equals "0" "$?" "vscode-sensitive debe tener IS_SENSITIVE=true"
[[ "$OUT_SENS" =~ PURGE_AFTER_BACKUP=true ]]
assert_equals "0" "$?" "vscode-sensitive debe tener PURGE_AFTER_BACKUP=true"

# ------------------------------------------------------------------------------
# Test 3: module_model_get con errores y casos borde
# ------------------------------------------------------------------------------
module_model_get "inexistente_12345" "$PROJECT_ROOT/modules.d" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_NOT_FOUND" $? "module_model_get módulo inexistente debe retornar MOD_ERR_NOT_FOUND"

TEMP_TEST_DIR=$(mktemp -d /tmp/test_mod_dir_XXXXXX)

# Módulo con error de sintaxis bash
cat <<EOF > "$TEMP_TEST_DIR/syntax-err.conf"
MODULE_ID="syntax-err"
MODULE_NAME="Bad"
if [[ syntax error then
EOF
module_model_get "syntax-err" "$TEMP_TEST_DIR" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_SYNTAX" $? "module_model_get con sintaxis inválida debe retornar MOD_ERR_SYNTAX"

# Módulo con campo faltante
cat <<EOF > "$TEMP_TEST_DIR/missing-field.conf"
MODULE_ID="missing-field"
MODULE_NAME="Missing"
MODULE_TAGS=("dev")
# Falta MODULE_PATHS, IS_SENSITIVE, etc.
EOF
module_model_get "missing-field" "$TEMP_TEST_DIR" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_MISSING_FIELD" $? "module_model_get con campos faltantes debe retornar MOD_ERR_MISSING_FIELD"

# ------------------------------------------------------------------------------
# Test 4: module_model_list
# ------------------------------------------------------------------------------
LIST_OUT=$(module_model_list "$PROJECT_ROOT/modules.d")
assert_exit_code "$MOD_OK" $? "module_model_list debe retornar MOD_OK"
[[ "$LIST_OUT" =~ vscode-standard ]]
assert_equals "0" "$?" "module_model_list debe incluir vscode-standard"
[[ "$LIST_OUT" =~ vscode-sensitive ]]
assert_equals "0" "$?" "module_model_list debe incluir vscode-sensitive"

# ------------------------------------------------------------------------------
# Test 5: Filtrado por etiquetas
# ------------------------------------------------------------------------------
DEV_TAG=$(module_model_filter_by_tag "dev" "$PROJECT_ROOT/modules.d")
assert_exit_code "$MOD_OK" $? "filter_by_tag 'dev' debe retornar MOD_OK"
[[ "$DEV_TAG" =~ vscode-standard && "$DEV_TAG" =~ vscode-sensitive ]]
assert_equals "0" "$?" "filter_by_tag 'dev' debe encontrar ambos módulos"

SENS_TAG=$(module_model_filter_by_tag "sensitive" "$PROJECT_ROOT/modules.d")
assert_exit_code "$MOD_OK" $? "filter_by_tag 'sensitive' debe retornar MOD_OK"
[[ "$SENS_TAG" =~ vscode-sensitive && "$SENS_TAG" =~ ssh-keys ]]
assert_equals "0" "$?" "filter_by_tag 'sensitive' debe incluir módulos sensibles (vscode-sensitive y ssh-keys)"

module_model_filter_by_tag "etiqueta_no_existente" "$PROJECT_ROOT/modules.d" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_NOT_FOUND" $? "filter_by_tag inexistente debe retornar MOD_ERR_NOT_FOUND"

# ------------------------------------------------------------------------------
# Test 6: Filtrado por sensibilidad
# ------------------------------------------------------------------------------
SENS_TRUE=$(module_model_filter_by_sensitivity "true" "$PROJECT_ROOT/modules.d")
[[ "$SENS_TRUE" =~ vscode-sensitive && "$SENS_TRUE" =~ ssh-keys ]]
assert_equals "0" "$?" "filter_by_sensitivity 'true' debe incluir vscode-sensitive y ssh-keys"

SENS_FALSE=$(module_model_filter_by_sensitivity "false" "$PROJECT_ROOT/modules.d")
[[ "$SENS_FALSE" =~ vscode-standard && "$SENS_FALSE" =~ bash-env ]]
assert_equals "0" "$?" "filter_by_sensitivity 'false' debe incluir vscode-standard y bash-env"

# ------------------------------------------------------------------------------
# Test 7: Comprobación de rutas en entorno simulado
# ------------------------------------------------------------------------------
MOCK_HOME="$TEMP_TEST_DIR/mock_home"
mkdir -p "$MOCK_HOME/.config/Code/User"
touch "$MOCK_HOME/.config/Code/User/settings.json"

PATHS_CHECK=$(module_model_check_paths "vscode-standard" "$MOCK_HOME" "$PROJECT_ROOT/modules.d")
CHECK_EXIT=$?
assert_exit_code "$MOD_OK" $CHECK_EXIT "check_paths debe retornar 0 si al menos una ruta existe"
[[ "$PATHS_CHECK" =~ FOUND=.config/Code/User/settings.json ]]
assert_equals "0" "$?" "check_paths debe detectar la ruta existente"
[[ "$PATHS_CHECK" =~ MISSING=.config/Code/User/keybindings.json ]]
assert_equals "0" "$?" "check_paths debe detectar la ruta faltante"

# ------------------------------------------------------------------------------
# Test 8: CRUD Dinámico (save y delete)
# ------------------------------------------------------------------------------
module_model_save "custom-test" "Custom App Test" "dev,testing" "custom/path1|custom/path2" "true" "true" "echo restored" "$TEMP_TEST_DIR"
assert_exit_code "$MOD_OK" $? "module_model_save debe crear el archivo correctamente"

CUSTOM_GET=$(module_model_get "custom-test" "$TEMP_TEST_DIR")
assert_exit_code "$MOD_OK" $? "module_model_get debe parsear el módulo recién creado"
[[ "$CUSTOM_GET" =~ NAME=Custom\ App\ Test ]]
assert_equals "0" "$?" "El nombre del módulo creado debe coincidir"

module_model_delete "custom-test" "$TEMP_TEST_DIR"
assert_exit_code "$MOD_OK" $? "module_model_delete debe borrar el archivo existente"

module_model_get "custom-test" "$TEMP_TEST_DIR" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_NOT_FOUND" $? "module_model_get de módulo borrado debe retornar MOD_ERR_NOT_FOUND"

# ------------------------------------------------------------------------------
# Test 9: Gestión de catálogo de etiquetas
# ------------------------------------------------------------------------------
MOCK_TAGS_FILE="$TEMP_TEST_DIR/default_tags.conf"
cp "$PROJECT_ROOT/config/default_tags.conf" "$MOCK_TAGS_FILE"

TAGS_ALL=$(module_model_get_all_tags "$PROJECT_ROOT/modules.d" "$MOCK_TAGS_FILE")
[[ "$TAGS_ALL" =~ dev && "$TAGS_ALL" =~ sensitive && "$TAGS_ALL" =~ editor ]]
assert_equals "0" "$?" "get_all_tags debe listar las etiquetas combinadas"

module_model_add_tag_to_catalog "docker" "Entornos de contenedores Docker" "$MOCK_TAGS_FILE"
assert_exit_code "$MOD_OK" $? "add_tag_to_catalog debe registrar una nueva etiqueta"

grep -qs "^docker:Entornos de contenedores Docker" "$MOCK_TAGS_FILE"
assert_equals "0" "$?" "La nueva etiqueta debe estar registrada en default_tags.conf"

# Limpieza
rm -rf "$TEMP_TEST_DIR"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE MODULE_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LAS PRUEBAS."
    exit 1
fi
