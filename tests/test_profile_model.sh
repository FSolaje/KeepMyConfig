#!/usr/bin/env bash
# ==============================================================================
# tests/test_profile_model.sh - Suite de Pruebas Unitarias para profile_model.sh
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

# shellcheck source=../lib/models/profile_model.sh
source "$PROJECT_ROOT/lib/models/profile_model.sh"

echo "=== Iniciando Tests Unitarios de lib/models/profile_model.sh ==="

# Sandbox temporal para pruebas aisladas
SANDBOX_DIR=$(mktemp -d /tmp/keepmyconfig_profile_test_XXXXXX)
trap 'rm -rf "$SANDBOX_DIR"' EXIT

SANDBOX_PROFILES="$SANDBOX_DIR/profiles"
SANDBOX_MODULES="$SANDBOX_DIR/modules.d"
SANDBOX_CONFIG="$SANDBOX_DIR/config.conf"
mkdir -p "$SANDBOX_PROFILES" "$SANDBOX_MODULES"

cat > "$SANDBOX_CONFIG" <<EOF
# Configuración de prueba
STORAGE_ID_TYPE="LOCAL_PATH"
STORAGE_ID_VALUE="/tmp"
STORAGE_SUBDIR="Backups/Default"
ACTIVE_PROFILE="default"
EOF

# ------------------------------------------------------------------------------
# Test 1: Validación sintáctica de IDs
# ------------------------------------------------------------------------------
profile_model_validate_id "personal"
assert_exit_code "$PROFILE_OK" $? "ID válido 'personal' debe retornar PROFILE_OK"

profile_model_validate_id "dev-pc_1"
assert_exit_code "$PROFILE_OK" $? "ID con guiones y números 'dev-pc_1' debe ser válido"

profile_model_validate_id "" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_INVALID_ID" $? "ID vacío debe fallar con PROFILE_ERR_INVALID_ID"

profile_model_validate_id "personal espacio" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_INVALID_ID" $? "ID con espacios debe fallar"

profile_model_validate_id "pc@work" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_INVALID_ID" $? "ID con caracteres especiales '@' debe fallar"

# ------------------------------------------------------------------------------
# Test 2: Metadatos del perfil 'default'
# ------------------------------------------------------------------------------
def_out=$(profile_model_get "default" "$SANDBOX_PROFILES")
assert_exit_code "$PROFILE_OK" $? "profile_model_get 'default' debe retornar PROFILE_OK"

def_id=$(echo "$def_out" | grep '^ID=' | cut -d'=' -f2)
def_name=$(echo "$def_out" | grep '^NAME=' | cut -d'=' -f2)
assert_equals "default" "$def_id" "El ID por defecto debe ser 'default'"
assert_equals "Perfil por Defecto" "$def_name" "El nombre por defecto debe coincidir"

# ------------------------------------------------------------------------------
# Test 3: Creación de perfiles (profile_model_create)
# ------------------------------------------------------------------------------
profile_model_create "work" "Entorno Profesional" "Ajustes de trabajo" "Backups/Workstation" "$SANDBOX_PROFILES"
assert_exit_code "$PROFILE_OK" $? "profile_model_create debe retornar PROFILE_OK"

assert_equals "1" "$([[ -f "$SANDBOX_PROFILES/work/profile.conf" ]] && echo 1 || echo 0)" "El archivo profile.conf debe crearse"
assert_equals "1" "$([[ -d "$SANDBOX_PROFILES/work/modules.d" ]] && echo 1 || echo 0)" "El directorio modules.d del perfil debe crearse"

work_out=$(profile_model_get "work" "$SANDBOX_PROFILES")
assert_exit_code "$PROFILE_OK" $? "profile_model_get 'work' debe retornar PROFILE_OK"
assert_equals "work" "$(echo "$work_out" | grep '^ID=' | cut -d'=' -f2)" "ID debe ser 'work'"
assert_equals "Entorno Profesional" "$(echo "$work_out" | grep '^NAME=' | cut -d'=' -f2)" "NAME debe ser 'Entorno Profesional'"
assert_equals "Backups/Workstation" "$(echo "$work_out" | grep '^TARGET_SUBDIR=' | cut -d'=' -f2)" "TARGET_SUBDIR debe coincidir"

# Intento de crear duplicado
profile_model_create "work" "Duplicado" "" "" "$SANDBOX_PROFILES" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_ALREADY_EXISTS" $? "Crear perfil ya existente debe retornar PROFILE_ERR_ALREADY_EXISTS"

# ------------------------------------------------------------------------------
# Test 4: Listado de perfiles (profile_model_list)
# ------------------------------------------------------------------------------
profile_model_create "home" "Casa" "" "Backups/Home" "$SANDBOX_PROFILES"

list_out=$(profile_model_list "$SANDBOX_PROFILES")
assert_exit_code "$PROFILE_OK" $? "profile_model_list debe retornar PROFILE_OK"
assert_equals "1" "$(echo "$list_out" | grep -qx 'default' && echo 1 || echo 0)" "list debe incluir 'default'"
assert_equals "1" "$(echo "$list_out" | grep -qx 'work' && echo 1 || echo 0)" "list debe incluir 'work'"
assert_equals "1" "$(echo "$list_out" | grep -qx 'home' && echo 1 || echo 0)" "list debe incluir 'home'"

# ------------------------------------------------------------------------------
# Test 5: Eliminación de perfiles (profile_model_delete)
# ------------------------------------------------------------------------------
profile_model_delete "default" "$SANDBOX_PROFILES" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_CANNOT_DELETE" $? "Borrar perfil 'default' debe estar terminantemente prohibido"

profile_model_delete "home" "$SANDBOX_PROFILES"
assert_exit_code "$PROFILE_OK" $? "profile_model_delete en perfil normal debe retornar PROFILE_OK"
assert_equals "0" "$([[ -d "$SANDBOX_PROFILES/home" ]] && echo 1 || echo 0)" "El directorio del perfil borrado debe eliminarse"

# ------------------------------------------------------------------------------
# Test 6: Cascada - Módulo solo global
# ------------------------------------------------------------------------------
# Crear módulo global en SANDBOX_MODULES
cat > "$SANDBOX_MODULES/global-app.conf" <<EOF
MODULE_ID="global-app"
MODULE_NAME="Global App"
MODULE_TAGS=("dev")
MODULE_PATHS=("/tmp/global")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=false
EOF

resolved_global=$(profile_model_resolve_module "global-app" "work" "$SANDBOX_DIR")
assert_exit_code "$PROFILE_OK" $? "resolve_module en módulo global debe retornar PROFILE_OK"
assert_equals "$SANDBOX_MODULES/global-app.conf" "$resolved_global" "Debe resolver a la ruta global en modules.d"

# ------------------------------------------------------------------------------
# Test 7: Cascada - Sobrescritura (Override) en el perfil
# ------------------------------------------------------------------------------
# Crear shared-app global
cat > "$SANDBOX_MODULES/shared-app.conf" <<EOF
MODULE_ID="shared-app"
MODULE_NAME="Shared Global"
MODULE_TAGS=("tools")
MODULE_PATHS=("/tmp/shared_global")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=false
EOF

# Crear shared-app en work con override
cat > "$SANDBOX_PROFILES/work/modules.d/shared-app.conf" <<EOF
MODULE_ID="shared-app"
MODULE_NAME="Shared Work Override"
MODULE_TAGS=("work")
MODULE_PATHS=("/tmp/shared_work")
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=false
EOF

# Cuando el perfil activo es 'work', debe resolver el del perfil
resolved_override=$(profile_model_resolve_module "shared-app" "work" "$SANDBOX_DIR")
assert_exit_code "$PROFILE_OK" $? "resolve_module en módulo sobrescrito debe retornar PROFILE_OK"
assert_equals "$SANDBOX_PROFILES/work/modules.d/shared-app.conf" "$resolved_override" "Debe prevalecer la versión de work/modules.d"

# Cuando el perfil activo es 'default', debe resolver la versión global
resolved_def=$(profile_model_resolve_module "shared-app" "default" "$SANDBOX_DIR")
assert_exit_code "$PROFILE_OK" $? "resolve_module con default debe retornar PROFILE_OK"
assert_equals "$SANDBOX_MODULES/shared-app.conf" "$resolved_def" "Con perfil default debe resolver la versión global"

# ------------------------------------------------------------------------------
# Test 8: Cascada - Módulo exclusivo del perfil
# ------------------------------------------------------------------------------
cat > "$SANDBOX_PROFILES/work/modules.d/work-vpn.conf" <<EOF
MODULE_ID="work-vpn"
MODULE_NAME="VPN Corporativa"
MODULE_TAGS=("net")
MODULE_PATHS=("/tmp/vpn")
IS_SENSITIVE=true
PURGE_AFTER_BACKUP=false
EOF

resolved_vpn=$(profile_model_resolve_module "work-vpn" "work" "$SANDBOX_DIR")
assert_exit_code "$PROFILE_OK" $? "resolve_module en módulo exclusivo debe retornar PROFILE_OK para su perfil"
assert_equals "$SANDBOX_PROFILES/work/modules.d/work-vpn.conf" "$resolved_vpn" "Debe resolver a work/modules.d/work-vpn.conf"

# Desde el perfil 'default', el módulo exclusivo NO debe ser visible
profile_model_resolve_module "work-vpn" "default" "$SANDBOX_DIR" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_NOT_FOUND" $? "Módulo exclusivo no debe resolverse bajo perfil 'default'"

# ------------------------------------------------------------------------------
# Test 9: Listado consolidado y deduplicado de módulos (profile_model_list_modules)
# ------------------------------------------------------------------------------
mod_list_work=$(profile_model_list_modules "work" "$SANDBOX_DIR")
assert_exit_code "$PROFILE_OK" $? "list_modules 'work' debe retornar PROFILE_OK"

assert_equals "1" "$(echo "$mod_list_work" | grep -qx 'global-app' && echo 1 || echo 0)" "list_modules debe incluir global-app"
assert_equals "1" "$(echo "$mod_list_work" | grep -qx 'shared-app' && echo 1 || echo 0)" "list_modules debe incluir shared-app"
assert_equals "1" "$(echo "$mod_list_work" | grep -qx 'work-vpn' && echo 1 || echo 0)" "list_modules debe incluir work-vpn"

# Comprobar que shared-app aparece una sola vez (deduplicado)
shared_count=$(echo "$mod_list_work" | grep -cx 'shared-app')
assert_equals "1" "$shared_count" "shared-app debe aparecer exactamente una vez (deduplicado)"

# Comprobar que en perfil 'default', work-vpn NO aparece
mod_list_def=$(profile_model_list_modules "default" "$SANDBOX_DIR")
assert_equals "0" "$(echo "$mod_list_def" | grep -qx 'work-vpn' && echo 1 || echo 0)" "work-vpn NO debe aparecer en el listado de 'default'"

# ------------------------------------------------------------------------------
# Test 10: Persistencia de perfil activo (profile_model_get_active / set_active)
# ------------------------------------------------------------------------------
curr_active=$(profile_model_get_active "$SANDBOX_CONFIG")
assert_equals "default" "$curr_active" "El perfil activo inicial debe ser 'default'"

profile_model_set_active "work" "$SANDBOX_CONFIG"
assert_exit_code "$PROFILE_OK" $? "set_active 'work' debe retornar PROFILE_OK"

new_active=$(profile_model_get_active "$SANDBOX_CONFIG")
assert_equals "work" "$new_active" "Tras set_active, get_active debe retornar 'work'"

# ------------------------------------------------------------------------------
# Test 11: Sanitización de TARGET_SUBDIR (profile_model_sanitize_target_subdir)
# ------------------------------------------------------------------------------
SAN_SUB1=$(profile_model_sanitize_target_subdir "/Backups/Docente")
assert_exit_code "$PROFILE_OK" $? "sanitize_target_subdir con barra inicial debe retornar PROFILE_OK"
assert_equals "Backups/Docente" "$SAN_SUB1" "Debe eliminar la barra inicial de /Backups/Docente"

SAN_SUB2=$(profile_model_sanitize_target_subdir "///Backups///Docente///")
assert_exit_code "$PROFILE_OK" $? "sanitize_target_subdir con barras redundantes debe retornar PROFILE_OK"
assert_equals "Backups/Docente" "$SAN_SUB2" "Debe normalizar barras múltiples a Backups/Docente"

SAN_SUB3=$(profile_model_sanitize_target_subdir "\$HOME/TEST_Backups")
assert_exit_code "$PROFILE_OK" $? "sanitize_target_subdir con \$HOME/ debe retornar PROFILE_OK"
assert_equals "TEST_Backups" "$SAN_SUB3" "Debe convertir \$HOME/TEST_Backups a ruta relativa TEST_Backups"

SAN_SUB4=$(profile_model_sanitize_target_subdir "~/Mis_Backups")
assert_exit_code "$PROFILE_OK" $? "sanitize_target_subdir con ~/ debe retornar PROFILE_OK"
assert_equals "Mis_Backups" "$SAN_SUB4" "Debe convertir ~/Mis_Backups a Mis_Backups"

SAN_SUB5=$(profile_model_sanitize_target_subdir "/home/usuario/Backups_USB")
assert_exit_code "$PROFILE_OK" $? "sanitize_target_subdir con /home/<user>/ debe retornar PROFILE_OK"
assert_equals "Backups_USB" "$SAN_SUB5" "Debe convertir /home/usuario/Backups_USB a Backups_USB"

SAN_SUB_EMPTY=$(profile_model_sanitize_target_subdir "")
assert_exit_code "$PROFILE_OK" $? "sanitize_target_subdir con cadena vacía debe retornar PROFILE_OK"
assert_equals "" "$SAN_SUB_EMPTY" "Cadena vacía debe mantenerse vacía (raíz de almacenamiento)"

profile_model_sanitize_target_subdir "../hack_dir" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_PARAM" $? "sanitize_target_subdir con '..' debe retornar PROFILE_ERR_PARAM"

# Verificación de integración en profile_model_create
profile_model_create "sanitized-prof" "Sanitized Profile" "Test" "\$HOME/Backups_Sanitized" "$SANDBOX_PROFILES"
assert_exit_code "$PROFILE_OK" $? "profile_model_create con \$HOME en target_subdir debe retornar PROFILE_OK"
PROF_DATA=$(profile_model_get "sanitized-prof" "$SANDBOX_PROFILES")
[[ "$PROF_DATA" =~ TARGET_SUBDIR=Backups_Sanitized ]]
assert_equals "0" "$?" "profile_model_create debe almacenar TARGET_SUBDIR saneado"

# ------------------------------------------------------------------------------
# Test 12: Exclusiones de Módulos Globales (DISABLED_MODULES - FR-TMPL-004)
# ------------------------------------------------------------------------------
# Comprobar que inicialmente no tiene módulos excluidos
init_disabled=$(profile_model_get_disabled_modules "work" "$SANDBOX_PROFILES")
assert_equals "" "$init_disabled" "Inicialmente work no debe tener módulos excluidos"

# Excluir 'global-app' en el perfil 'work'
profile_model_disable_module "work" "global-app" "$SANDBOX_PROFILES"
assert_exit_code "$PROFILE_OK" $? "disable_module 'global-app' debe retornar PROFILE_OK"

work_disabled=$(profile_model_get_disabled_modules "work" "$SANDBOX_PROFILES")
assert_equals "1" "$(echo "$work_disabled" | grep -qx 'global-app' && echo 1 || echo 0)" "global-app debe figurar en get_disabled_modules"

# profile_model_get debe reflejar DISABLED_MODULES
work_meta_dis=$(profile_model_get "work" "$SANDBOX_PROFILES")
[[ "$work_meta_dis" =~ DISABLED_MODULES=global-app ]]
assert_equals "0" "$?" "profile_model_get debe incluir DISABLED_MODULES=global-app"

# list_modules en 'work' NO debe incluir 'global-app' ahora
mod_list_work_filtered=$(profile_model_list_modules "work" "$SANDBOX_DIR")
assert_equals "0" "$(echo "$mod_list_work_filtered" | grep -qx 'global-app' && echo 1 || echo 0)" "list_modules 'work' no debe incluir el módulo excluido global-app"
# Pero debe seguir incluyendo shared-app y work-vpn
assert_equals "1" "$(echo "$mod_list_work_filtered" | grep -qx 'shared-app' && echo 1 || echo 0)" "list_modules 'work' debe mantener shared-app"
assert_equals "1" "$(echo "$mod_list_work_filtered" | grep -qx 'work-vpn' && echo 1 || echo 0)" "list_modules 'work' debe mantener work-vpn"

# resolve_module en 'global-app' para 'work' debe fallar
profile_model_resolve_module "global-app" "work" "$SANDBOX_DIR" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_NOT_FOUND" $? "resolve_module en módulo excluido debe retornar PROFILE_ERR_NOT_FOUND"

# En perfil 'default', 'global-app' debe seguir estando visible y resoluble
mod_list_def_check=$(profile_model_list_modules "default" "$SANDBOX_DIR")
assert_equals "1" "$(echo "$mod_list_def_check" | grep -qx 'global-app' && echo 1 || echo 0)" "global-app debe seguir en default"
res_def_check=$(profile_model_resolve_module "global-app" "default" "$SANDBOX_DIR")
assert_exit_code "$PROFILE_OK" $? "resolve_module 'global-app' en default debe retornar PROFILE_OK"

# Intentar deshabilitar en 'default' debe fallar
profile_model_disable_module "default" "global-app" "$SANDBOX_PROFILES" >/dev/null 2>&1
assert_exit_code "$PROFILE_ERR_CANNOT_DELETE" $? "disable_module en default debe retornar PROFILE_ERR_CANNOT_DELETE"

# Re-habilitar 'global-app' en 'work'
profile_model_enable_module "work" "global-app" "$SANDBOX_PROFILES"
assert_exit_code "$PROFILE_OK" $? "enable_module debe retornar PROFILE_OK"

work_disabled_after=$(profile_model_get_disabled_modules "work" "$SANDBOX_PROFILES")
assert_equals "0" "$(echo "$work_disabled_after" | grep -qx 'global-app' && echo 1 || echo 0)" "global-app no debe figurar tras ser rehabilitado"

mod_list_work_restored=$(profile_model_list_modules "work" "$SANDBOX_DIR")
assert_equals "1" "$(echo "$mod_list_work_restored" | grep -qx 'global-app' && echo 1 || echo 0)" "list_modules 'work' vuelve a incluir global-app"

# ==============================================================================
# Resumen
# ==============================================================================

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE PROFILE_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: EXISTEN PRUEBAS FALLIDAS EN PROFILE_MODEL."
    exit 1
fi
