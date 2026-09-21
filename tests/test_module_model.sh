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
TEMPLATES_DIR="$PROJECT_ROOT/templates.d"

OUT_STD=$(module_model_get "vscode-standard" "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "module_model_get 'vscode-standard' debe retornar 0"
[[ "$OUT_STD" =~ IS_SENSITIVE=false ]]
assert_equals "0" "$?" "vscode-standard debe tener IS_SENSITIVE=false"
[[ "$OUT_STD" =~ PURGE_AFTER_BACKUP=false ]]
assert_equals "0" "$?" "vscode-standard debe tener PURGE_AFTER_BACKUP=false"

OUT_SENS=$(module_model_get "vscode-sensitive" "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "module_model_get 'vscode-sensitive' debe retornar 0"
[[ "$OUT_SENS" =~ IS_SENSITIVE=true ]]
assert_equals "0" "$?" "vscode-sensitive debe tener IS_SENSITIVE=true"
[[ "$OUT_SENS" =~ PURGE_AFTER_BACKUP=true ]]
assert_equals "0" "$?" "vscode-sensitive debe tener PURGE_AFTER_BACKUP=true"

# ------------------------------------------------------------------------------
# Test 3: module_model_get con errores y casos borde
# ------------------------------------------------------------------------------
module_model_get "inexistente_12345" "$TEMPLATES_DIR" >/dev/null 2>&1
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
LIST_OUT=$(module_model_list "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "module_model_list debe retornar MOD_OK"
[[ "$LIST_OUT" =~ vscode-standard ]]
assert_equals "0" "$?" "module_model_list debe incluir vscode-standard"
[[ "$LIST_OUT" =~ vscode-sensitive ]]
assert_equals "0" "$?" "module_model_list debe incluir vscode-sensitive"

# ------------------------------------------------------------------------------
# Test 5: Filtrado por etiquetas
# ------------------------------------------------------------------------------
DEV_TAG=$(module_model_filter_by_tag "dev" "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "filter_by_tag 'dev' debe retornar MOD_OK"
[[ "$DEV_TAG" =~ vscode-standard && "$DEV_TAG" =~ vscode-sensitive ]]
assert_equals "0" "$?" "filter_by_tag 'dev' debe encontrar ambos módulos"

SENS_TAG=$(module_model_filter_by_tag "sensitive" "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "filter_by_tag 'sensitive' debe retornar MOD_OK"
[[ "$SENS_TAG" =~ vscode-sensitive && "$SENS_TAG" =~ ssh-keys ]]
assert_equals "0" "$?" "filter_by_tag 'sensitive' debe incluir módulos sensibles (vscode-sensitive y ssh-keys)"

module_model_filter_by_tag "etiqueta_no_existente" "$TEMPLATES_DIR" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_NOT_FOUND" $? "filter_by_tag inexistente debe retornar MOD_ERR_NOT_FOUND"

# ------------------------------------------------------------------------------
# Test 6: Filtrado por sensibilidad
# ------------------------------------------------------------------------------
SENS_TRUE=$(module_model_filter_by_sensitivity "true" "$TEMPLATES_DIR")
[[ "$SENS_TRUE" =~ vscode-sensitive && "$SENS_TRUE" =~ ssh-keys ]]
assert_equals "0" "$?" "filter_by_sensitivity 'true' debe incluir vscode-sensitive y ssh-keys"

SENS_FALSE=$(module_model_filter_by_sensitivity "false" "$TEMPLATES_DIR")
[[ "$SENS_FALSE" =~ vscode-standard && "$SENS_FALSE" =~ bash-env ]]
assert_equals "0" "$?" "filter_by_sensitivity 'false' debe incluir vscode-standard y bash-env"

# ------------------------------------------------------------------------------
# Test 7: Comprobación de rutas en entorno simulado
# ------------------------------------------------------------------------------
MOCK_HOME="$TEMP_TEST_DIR/mock_home"
mkdir -p "$MOCK_HOME/.config/Code/User"
touch "$MOCK_HOME/.config/Code/User/settings.json"

PATHS_CHECK=$(module_model_check_paths "vscode-standard" "$MOCK_HOME" "$TEMPLATES_DIR")
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

TAGS_ALL=$(module_model_get_all_tags "$TEMPLATES_DIR" "$MOCK_TAGS_FILE")

[[ "$TAGS_ALL" =~ dev && "$TAGS_ALL" =~ sensitive && "$TAGS_ALL" =~ editor ]]
assert_equals "0" "$?" "get_all_tags debe listar las etiquetas combinadas"

module_model_add_tag_to_catalog "docker" "Entornos de contenedores Docker" "$MOCK_TAGS_FILE"
assert_exit_code "$MOD_OK" $? "add_tag_to_catalog debe registrar una nueva etiqueta"

grep -qs "^docker:Entornos de contenedores Docker" "$MOCK_TAGS_FILE"
assert_equals "0" "$?" "La nueva etiqueta debe estar registrada en default_tags.conf"

# ------------------------------------------------------------------------------
# Test 10: Sanitización de Rutas (module_model_sanitize_path)
# ------------------------------------------------------------------------------
SAN_HOME=$(module_model_sanitize_path "\$HOME/Documentos/Pruebas_Macros")
assert_exit_code "$MOD_OK" $? "sanitize_path con \$HOME/ debe retornar MOD_OK"
assert_equals "Documentos/Pruebas_Macros" "$SAN_HOME" "sanitize_path debe limpiar el prefijo \$HOME/"

SAN_BRACES=$(module_model_sanitize_path "\${HOME}/.config/app/settings.json")
assert_exit_code "$MOD_OK" $? "sanitize_path con \${HOME}/ debe retornar MOD_OK"
assert_equals ".config/app/settings.json" "$SAN_BRACES" "sanitize_path debe limpiar el prefijo \${HOME}/"

SAN_TILDE=$(module_model_sanitize_path "~/Descargas/ficheros/")
assert_exit_code "$MOD_OK" $? "sanitize_path con ~/ y barra final debe retornar MOD_OK"
assert_equals "Descargas/ficheros" "$SAN_TILDE" "sanitize_path debe limpiar ~/ y barra final"

SAN_USER_HOME=$(module_model_sanitize_path "/home/usuario/workspace/proyectos")
assert_exit_code "$MOD_OK" $? "sanitize_path con /home/<user>/ debe retornar MOD_OK"
assert_equals "workspace/proyectos" "$SAN_USER_HOME" "sanitize_path debe limpiar /home/<user>/"

SAN_SLASHES=$(module_model_sanitize_path "///rutas//con///barras///")
assert_exit_code "$MOD_OK" $? "sanitize_path con múltiples barras debe retornar MOD_OK"
assert_equals "rutas/con/barras" "$SAN_SLASHES" "sanitize_path debe normalizar barras múltiples"

SAN_CLEAN=$(module_model_sanitize_path ".config/Code/User/settings.json")
assert_exit_code "$MOD_OK" $? "sanitize_path con ruta relativa limpia debe retornar MOD_OK"
assert_equals ".config/Code/User/settings.json" "$SAN_CLEAN" "sanitize_path debe preservar rutas relativas limpias"

module_model_sanitize_path "../etc/passwd" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_CONFIG" $? "sanitize_path con subida de directorio (..) debe retornar MOD_ERR_CONFIG"

module_model_sanitize_path "datos/../privado" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_CONFIG" $? "sanitize_path con salto intermedio /../ debe retornar MOD_ERR_CONFIG"

module_model_sanitize_path "\$HOME" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_CONFIG" $? "sanitize_path con solo \$HOME debe retornar MOD_ERR_CONFIG"

module_model_sanitize_path "~" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_CONFIG" $? "sanitize_path con solo ~ debe retornar MOD_ERR_CONFIG"

module_model_sanitize_path "/" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_CONFIG" $? "sanitize_path con raíz / debe retornar MOD_ERR_CONFIG"

module_model_sanitize_path "" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_CONFIG" $? "sanitize_path con cadena vacía debe retornar MOD_ERR_CONFIG"

# ------------------------------------------------------------------------------
# Test 11: Guardado con Sanitización Automática en module_model_save
# ------------------------------------------------------------------------------
RAW_PATHS="\$HOME/Documentos/Prueba1|~/Descargas/Prueba2|/home/user/.local/share"
module_model_save "sanitized-mod" "Sanitized Module" "test" "$RAW_PATHS" "false" "false" "" "$TEMP_TEST_DIR"
assert_exit_code "$MOD_OK" $? "module_model_save con rutas a sanear debe retornar MOD_OK"

MOD_CONF_CONTENT=$(cat "$TEMP_TEST_DIR/sanitized-mod.conf")
[[ "$MOD_CONF_CONTENT" =~ \"Documentos/Prueba1\" ]]
assert_equals "0" "$?" "module_model_save debe almacenar Documentos/Prueba1 sanitizado"
[[ "$MOD_CONF_CONTENT" =~ \"Descargas/Prueba2\" ]]
assert_equals "0" "$?" "module_model_save debe almacenar Descargas/Prueba2 sanitizado"
[[ "$MOD_CONF_CONTENT" =~ \".local/share\" ]]
assert_equals "0" "$?" "module_model_save debe almacenar .local/share sanitizado"

# ------------------------------------------------------------------------------
# Test 12: Gestión de Plantillas (FR-TMPL-001, FR-TMPL-003, FR-TMPL-007, FR-TMPL-008)
# ------------------------------------------------------------------------------
TMPL_LIST=$(module_model_list_templates "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "module_model_list_templates debe retornar MOD_OK"
[[ "$TMPL_LIST" =~ firefox ]]
assert_equals "0" "$?" "list_templates debe incluir 'firefox'"
[[ "$TMPL_LIST" =~ ssh-keys ]]
assert_equals "0" "$?" "list_templates debe incluir 'ssh-keys'"
[[ ! "$TMPL_LIST" =~ template-skeleton ]]
assert_equals "0" "$?" "list_templates debe omitir 'template-skeleton'"

# get_template
TMPL_FX=$(module_model_get_template "firefox" "$TEMPLATES_DIR")
assert_exit_code "$MOD_OK" $? "module_model_get_template 'firefox' debe retornar 0"
[[ "$TMPL_FX" =~ ID=firefox ]]
assert_equals "0" "$?" "get_template 'firefox' debe contener ID=firefox"

# activate_template hacia directorio destino
ACTIVATED_DIR="$TEMP_TEST_DIR/activated_modules"
module_model_activate_template "firefox" "$ACTIVATED_DIR" "$TEMPLATES_DIR"
assert_exit_code "$MOD_OK" $? "module_model_activate_template debe retornar MOD_OK en la primera activación"
assert_equals "1" "$([[ -f "$ACTIVATED_DIR/firefox.conf" ]] && echo 1 || echo 0)" "El fichero firefox.conf debe existir en el directorio destino"

# Segunda activación debe fallar con MOD_ERR_ALREADY_EXISTS
module_model_activate_template "firefox" "$ACTIVATED_DIR" "$TEMPLATES_DIR" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_ALREADY_EXISTS" $? "module_model_activate_template duplicada debe retornar MOD_ERR_ALREADY_EXISTS"

# Activación de plantilla inexistente
module_model_activate_template "plantilla_fantasma_999" "$ACTIVATED_DIR" "$TEMPLATES_DIR" >/dev/null 2>&1
assert_exit_code "$MOD_ERR_NOT_FOUND" $? "module_model_activate_template con ID inexistente debe retornar MOD_ERR_NOT_FOUND"

# create_template en biblioteca personalizada
MOCK_TMPL_LIB="$TEMP_TEST_DIR/my_templates"
module_model_create_template "custom-tool" "Herramienta Propia" "tools,dev" ".config/mytool" "false" "false" "" "$MOCK_TMPL_LIB"
assert_exit_code "$MOD_OK" $? "module_model_create_template debe retornar MOD_OK"
assert_equals "1" "$([[ -f "$MOCK_TMPL_LIB/custom-tool.conf" ]] && echo 1 || echo 0)" "El fichero de plantilla custom-tool.conf debe haberse creado"

# export_to_template: promover módulo activo a plantilla
module_model_export_to_template "$ACTIVATED_DIR/firefox.conf" "firefox-exportada" "$MOCK_TMPL_LIB"
assert_exit_code "$MOD_OK" $? "module_model_export_to_template debe retornar MOD_OK"
assert_equals "1" "$([[ -f "$MOCK_TMPL_LIB/firefox-exportada.conf" ]] && echo 1 || echo 0)" "La plantilla exportada firefox-exportada.conf debe existir"
EXP_META=$(module_model_get "firefox-exportada" "$MOCK_TMPL_LIB")
[[ "$EXP_META" =~ ID=firefox-exportada ]]
assert_equals "0" "$?" "La plantilla exportada debe tener ID actualizado 'firefox-exportada'"

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
