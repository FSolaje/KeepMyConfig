#!/usr/bin/env bash
# ==============================================================================
# Archivo: tests/test_views.sh
# Descripción: Suite de pruebas unitarias para lib/views/whiptail_view.sh y ansi_view.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar las vistas
source "${BASE_DIR}/lib/views/ansi_view.sh"
source "${BASE_DIR}/lib/views/whiptail_view.sh"

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

echo "=== Iniciando Tests Unitarios de lib/views/ansi_view.sh ==="

# Test 1: ansi_view_header
output=$(ansi_view_header "Test Title" | tr -d '\r')
assert_contains "$output" "Test Title" "ansi_view_header debe imprimir el título"

# Test 2: ansi_view_info
output=$(ansi_view_info "Mensaje informativo" | tr -d '\r')
assert_contains "$output" "[INFO]" "ansi_view_info debe incluir la etiqueta [INFO]"
assert_contains "$output" "Mensaje informativo" "ansi_view_info debe incluir el texto"

# Test 3: ansi_view_success
output=$(ansi_view_success "Operación exitosa" | tr -d '\r')
assert_contains "$output" "[OK]" "ansi_view_success debe incluir la etiqueta [OK]"
assert_contains "$output" "Operación exitosa" "ansi_view_success debe incluir el texto"

# Test 4: ansi_view_warning
output=$(ansi_view_warning "Advertencia importante" | tr -d '\r')
assert_contains "$output" "[AVISO]" "ansi_view_warning debe incluir la etiqueta [AVISO]"

# Test 5: ansi_view_error
err_output=$(ansi_view_error "Fallo detectado" 2>&1 1>/dev/null | tr -d '\r')
assert_contains "$err_output" "[ERROR]" "ansi_view_error debe imprimir [ERROR] por stderr"
assert_contains "$err_output" "Fallo detectado" "ansi_view_error debe imprimir el mensaje de error por stderr"

# Test 6: ansi_view_key_value
kv_output=$(ansi_view_key_value "DISPOSITIVO" "SSD_EXT" | tr -d '\r')
assert_contains "$kv_output" "DISPOSITIVO" "ansi_view_key_value debe formatear la clave"
assert_contains "$kv_output" "SSD_EXT" "ansi_view_key_value debe mostrar el valor"

# Test 7: ansi_view_prompt con valor por defecto
prompt_res=$(echo "" | ansi_view_prompt "¿Host?" "localhost" 2>/dev/null)
assert_eq "localhost" "$prompt_res" "ansi_view_prompt debe tomar el valor por defecto si la entrada está vacía"

# Test 8: ansi_view_prompt con valor personalizado
prompt_custom=$(echo "mi-servidor" | ansi_view_prompt "¿Host?" "localhost" 2>/dev/null)
assert_eq "mi-servidor" "$prompt_custom" "ansi_view_prompt debe aceptar valor escrito por el usuario"

# Test 9: ansi_view_confirm con respuesta afirmativa (s)
set +e
echo "s" | ansi_view_confirm "¿Continuar?" "S" &>/dev/null
status=$?
set -e
assert_eq "0" "$status" "ansi_view_confirm debe retornar 0 con respuesta 's'"

# Test 10: ansi_view_confirm con respuesta negativa (n)
set +e
echo "n" | ansi_view_confirm "¿Continuar?" "S" &>/dev/null
status=$?
set -e
assert_eq "1" "$status" "ansi_view_confirm debe retornar 1 con respuesta 'n'"

# Test 11: ansi_view_confirm con ENTER (por defecto S)
set +e
echo "" | ansi_view_confirm "¿Continuar?" "S" &>/dev/null
status=$?
set -e
assert_eq "0" "$status" "ansi_view_confirm con ENTER debe adoptar default 'S' retornando 0"

# Test 12: ansi_view_confirm con ENTER (por defecto N)
set +e
echo "" | ansi_view_confirm "¿Continuar?" "N" &>/dev/null
status=$?
set -e
assert_eq "1" "$status" "ansi_view_confirm con ENTER debe adoptar default 'N' retornando 1"

echo "=== Iniciando Tests Unitarios de lib/views/whiptail_view.sh ==="

# Test 13: Comprobación de dependencia
whiptail_view_check_deps
assert_eq "0" "$?" "whiptail_view_check_deps debe retornar 0 cuando whiptail está disponible"

# Test 14: Cálculo de dimensiones
whiptail_view_calc_dimensions
if (( WT_HEIGHT >= 16 && WT_WIDTH >= 60 && WT_LIST_HEIGHT >= 5 )); then
    echo "  [PASS] whiptail_view_calc_dimensions establece proporciones seguras (H:$WT_HEIGHT, W:$WT_WIDTH, L:$WT_LIST_HEIGHT)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] whiptail_view_calc_dimensions fuera de límites seguros" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Sandbox de pruebas con mock aislado de whiptail
SANDBOX_DIR=$(mktemp -d /tmp/backupconfig_view_test_XXXXXX)
MOCK_BIN="${SANDBOX_DIR}/mock_whiptail"

cleanup() {
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT

# Test 15: whiptail_view_textbox con fichero inexistente
set +e
whiptail_view_textbox "Test" "${SANDBOX_DIR}/inexistente.txt" &>/dev/null
status=$?
set -e
assert_eq "$VIEW_ERR_PARAM" "$status" "whiptail_view_textbox con fichero inexistente debe retornar VIEW_ERR_PARAM"

# Mock directo de whiptail para pruebas automatizadas
whiptail() {
    local code="${MOCK_EXIT_CODE:-0}"
    local out="${MOCK_OUTPUT:-}"
    for arg in "$@"; do
        case "$arg" in
            --inputbox|--passwordbox|--menu|--checklist|--radiolist)
                echo -n "$out" >&2
                return "$code"
                ;;
            --msgbox|--yesno|--gauge|--textbox)
                return "$code"
                ;;
        esac
    done
    return "$code"
}

# Test 16: whiptail_view_msgbox
MOCK_EXIT_CODE=0
whiptail_view_msgbox "Titulo" "Mensaje"
assert_eq "0" "$?" "whiptail_view_msgbox debe retornar 0 con salida exitosa"

# Test 17: whiptail_view_error
MOCK_EXIT_CODE=0
whiptail_view_error "Alerta" "Fallo simulado"
assert_eq "0" "$?" "whiptail_view_error debe retornar 0 con salida exitosa"

# Test 18: whiptail_view_yesno respondiendo Sí
MOCK_EXIT_CODE=0
whiptail_view_yesno "Pregunta" "¿Seguro?"
assert_eq "0" "$?" "whiptail_view_yesno respondiendo Sí debe retornar 0"

# Test 19: whiptail_view_yesno respondiendo No
MOCK_EXIT_CODE=1
set +e
whiptail_view_yesno "Pregunta" "¿Seguro?"
status=$?
set -e
assert_eq "1" "$status" "whiptail_view_yesno respondiendo No debe retornar 1"

# Test 20: whiptail_view_input capturando texto
MOCK_EXIT_CODE=0
MOCK_OUTPUT="modulo-prueba"
input_res=$(whiptail_view_input "Titulo" "Prompt" "default")
assert_eq "modulo-prueba" "$input_res" "whiptail_view_input debe capturar el texto introducido"

# Test 21: whiptail_view_input cancelado por el usuario
MOCK_EXIT_CODE=1
MOCK_OUTPUT=""
set +e
input_res=$(whiptail_view_input "Titulo" "Prompt" "default")
status=$?
set -e
assert_eq "$VIEW_CANCEL" "$status" "whiptail_view_input cancelado debe retornar VIEW_CANCEL"

# Test 22: whiptail_view_password capturando contraseña
MOCK_EXIT_CODE=0
MOCK_OUTPUT="clave-secreta-123"
pass_res=$(whiptail_view_password "Titulo" "Prompt")
assert_eq "clave-secreta-123" "$pass_res" "whiptail_view_password debe capturar la contraseña por stdout"

# Test 23: whiptail_view_main_menu seleccionando opción 1
MOCK_EXIT_CODE=0
MOCK_OUTPUT="1"
menu_res=$(whiptail_view_main_menu)
assert_eq "1" "$menu_res" "whiptail_view_main_menu debe retornar la opción seleccionada"

# Test 24: whiptail_view_main_menu cancelado
MOCK_EXIT_CODE=1
MOCK_OUTPUT=""
set +e
menu_res=$(whiptail_view_main_menu)
status=$?
set -e
assert_eq "$VIEW_CANCEL" "$status" "whiptail_view_main_menu cancelado debe retornar VIEW_CANCEL"

# Test 25: whiptail_view_menu genérico
MOCK_EXIT_CODE=0
MOCK_OUTPUT="tag_dev"
gen_menu_res=$(whiptail_view_menu "Titulo" "Prompt" "tag_dev" "Desarrollo" "tag_sys" "Sistema")
assert_eq "tag_dev" "$gen_menu_res" "whiptail_view_menu debe retornar la clave elegida"

# Test 26: whiptail_view_checklist desparasitando comillas
MOCK_EXIT_CODE=0
MOCK_OUTPUT='"dev" "sensitive"'
check_res=$(whiptail_view_checklist "Tags" "Seleccione" "dev" "Dev" "ON" "sensitive" "Sens" "ON")
assert_eq "dev sensitive" "$check_res" "whiptail_view_checklist debe normalizar y desparasitar las comillas"

# Test 27: whiptail_view_radiolist
MOCK_EXIT_CODE=0
MOCK_OUTPUT='"vscode-standard"'
radio_res=$(whiptail_view_radiolist "Modulos" "Seleccione" "vscode-standard" "VSCode Standard" "ON")
assert_eq "vscode-standard" "$radio_res" "whiptail_view_radiolist debe retornar la opción limpia"

# Test 28: whiptail_view_textbox con fichero existente
MOCK_EXIT_CODE=0
dummy_file="${SANDBOX_DIR}/test_doc.txt"
echo "Contenido de prueba" > "$dummy_file"
whiptail_view_textbox "Documento" "$dummy_file"
assert_eq "0" "$?" "whiptail_view_textbox debe mostrar fichero existente exitosamente"

# Test 30: whiptail_view_password_confirm coincidente
MOCK_EXIT_CODE=0
MOCK_OUTPUT="mi_password_segura"
pass_conf_res=$(whiptail_view_password_confirm "Clave" "Intro")
assert_eq "mi_password_segura" "$pass_conf_res" "whiptail_view_password_confirm debe retornar la clave cuando coinciden"

# Test 31: whiptail_view_gauge
MOCK_EXIT_CODE=0
echo "50" | whiptail_view_gauge "Progreso" "Cargando..." 0
assert_eq "0" "$?" "whiptail_view_gauge debe procesar el flujo sin error"

# Test 32: whiptail_view_apply_theme con midnight
whiptail_view_apply_theme "midnight"
assert_contains "${NEWT_COLORS:-}" "root=blue,black" "whiptail_view_apply_theme midnight debe configurar NEWT_COLORS"

# Test 33: whiptail_view_apply_theme con cyberdark
whiptail_view_apply_theme "cyberdark"
assert_contains "${NEWT_COLORS:-}" "title=brightgreen,black" "whiptail_view_apply_theme cyberdark debe configurar NEWT_COLORS"

# Test 34: whiptail_view_apply_theme con aubergine
whiptail_view_apply_theme "aubergine"
assert_contains "${NEWT_COLORS:-}" "border=magenta,black" "whiptail_view_apply_theme aubergine debe configurar NEWT_COLORS"

# Test 35: whiptail_view_apply_theme con amber
whiptail_view_apply_theme "amber"
assert_contains "${NEWT_COLORS:-}" "actbutton=black,yellow" "whiptail_view_apply_theme amber debe configurar NEWT_COLORS"

# Test 36: whiptail_view_apply_theme con default desactiva NEWT_COLORS
whiptail_view_apply_theme "default"
if [[ -z "${NEWT_COLORS:-}" ]]; then
    echo "  [PASS] whiptail_view_apply_theme default debe desunsetear NEWT_COLORS"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] NEWT_COLORS debería estar vacía con tema default" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 37: whiptail_view_confirm_critical aceptando o rechazando
MOCK_EXIT_CODE=0
whiptail_view_confirm_critical "Destrucción" "¿Continuar con shred?"
assert_eq "0" "$?" "whiptail_view_confirm_critical debe retornar 0 si el usuario confirma"

MOCK_EXIT_CODE=1
set +e
whiptail_view_confirm_critical "Destrucción" "¿Continuar con shred?"
crit_status=$?
set -e
assert_eq "1" "$crit_status" "whiptail_view_confirm_critical debe retornar 1 si el usuario cancela"

# Test 38: whiptail_view_preflight_summary
MOCK_EXIT_CODE=0
whiptail_view_preflight_summary "Resumen" "Matriz de módulos..."
assert_eq "0" "$?" "whiptail_view_preflight_summary debe retornar 0 si se aprueba"

# Test 39: ansi_view_preflight_table formateo de matriz
preflight_out=$(ansi_view_preflight_table "ssh-keys|Llaves SSH|Global|SÍ|SÍ|/media/SSD" "bash-env|Entorno Bash|Perfil|No|No|/media/SSD")
assert_contains "$preflight_out" "MATRIZ PRE-FLIGHT DE SEGURIDAD" "ansi_view_preflight_table debe incluir título de cabecera"
assert_contains "$preflight_out" "¡PURGA ACTIVA!" "ansi_view_preflight_table debe resaltar purga activa"
assert_contains "$preflight_out" "SÍ (AES-256)" "ansi_view_preflight_table debe indicar cifrado GPG"

# Test 40: ansi_view_confirm_critical validando palabra clave 'SI'
set +e
echo "SI" | ansi_view_confirm_critical "Confirmar purga irreversible" >/dev/null 2>&1
ansi_crit_yes=$?
echo "no" | ansi_view_confirm_critical "Confirmar purga irreversible" >/dev/null 2>&1
ansi_crit_no=$?
set -e
assert_eq "0" "$ansi_crit_yes" "ansi_view_confirm_critical con 'SI' debe retornar 0"
assert_eq "1" "$ansi_crit_no" "ansi_view_confirm_critical con 'no' debe retornar 1"


echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Algunas pruebas de vistas han fallado." >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE VISTAS HAN PASADO."
