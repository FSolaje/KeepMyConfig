#!/usr/bin/env bash
# ==============================================================================
# Archivo: tests/test_packaging_and_distribution.sh
# Descripción: Suite de pruebas unitarias y de integración para el sistema de
#              empaquetado dual (scripts/package.sh), instalador y desinstalador
#              sin privilegios (install.sh y uninstall.sh), y endurecimiento UNIX.
# Cumple con: specs/packaging_and_distribution/spec.md
# ==============================================================================

set -uo pipefail

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

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [[ -f "$file" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Fichero no existe: '$file')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_file_not_exists() {
    local file="$1"
    local msg="$2"
    if [[ ! -e "$file" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Fichero existe cuando no debería: '$file')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="$2"
    if [[ -d "$dir" ]]; then
        echo "  [PASS] $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  [FAIL] $msg (Directorio no existe: '$dir')" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "=== Iniciando Tests Unitarios de Empaquetado y Distribución ==="

# Preparar directorio de pruebas aislado
TEST_DIR="$(mktemp -d /tmp/kmc_test_pkg_dist_XXXXXX)"
DIST_TEST_DIR="${TEST_DIR}/dist"
FAKE_HOME="${TEST_DIR}/home"
mkdir -p "$DIST_TEST_DIR" "$FAKE_HOME"

cleanup() {
    chmod -R u+w "$TEST_DIR" 2>/dev/null || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

TEST_VERSION="v9.9.9-test"

# ------------------------------------------------------------------------------
# Test 1: Ejecución de scripts/package.sh para generar paquetes duales
# ------------------------------------------------------------------------------
echo "--- Test 1: Empaquetado dual con scripts/package.sh ---"
pkg_out=$("${PROJECT_ROOT}/scripts/package.sh" \
    --version "$TEST_VERSION" \
    --output-dir "$DIST_TEST_DIR" \
    --clean \
    --type all 2>&1)
pkg_code=$?

assert_eq "0" "$pkg_code" "package.sh debe finalizar con código de salida 0"
assert_file_exists "${DIST_TEST_DIR}/KeepMyConfig-${TEST_VERSION}.tar.gz" "Debe generar paquete estándar .tar.gz"
assert_file_exists "${DIST_TEST_DIR}/KeepMyConfig-${TEST_VERSION}-portable.tar.gz" "Debe generar paquete portable .tar.gz"
assert_file_exists "${DIST_TEST_DIR}/SHA256SUMS.txt" "Debe generar SHA256SUMS.txt"

# ------------------------------------------------------------------------------
# Test 2: Verificación Anti-Tarbomb en ambas ediciones
# ------------------------------------------------------------------------------
echo "--- Test 2: Verificación Anti-Tarbomb ---"
STD_EXTRACT="${TEST_DIR}/extract_standard"
PORT_EXTRACT="${TEST_DIR}/extract_portable"
mkdir -p "$STD_EXTRACT" "$PORT_EXTRACT"

tar -xzf "${DIST_TEST_DIR}/KeepMyConfig-${TEST_VERSION}.tar.gz" -C "$STD_EXTRACT"
std_entries=()
while IFS= read -r entry; do
    [[ -n "$entry" ]] && std_entries+=("$entry")
done < <(find "$STD_EXTRACT" -mindepth 1 -maxdepth 1)

assert_eq "1" "${#std_entries[@]}" "Edición estándar debe contener un único directorio raíz (anti-tarbomb)"
assert_eq "KeepMyConfig-${TEST_VERSION}" "$(basename "${std_entries[0]}")" "Directorio raíz estándar debe coincidir con nombre del paquete"

tar -xzf "${DIST_TEST_DIR}/KeepMyConfig-${TEST_VERSION}-portable.tar.gz" -C "$PORT_EXTRACT"
port_entries=()
while IFS= read -r entry; do
    [[ -n "$entry" ]] && port_entries+=("$entry")
done < <(find "$PORT_EXTRACT" -mindepth 1 -maxdepth 1)

assert_eq "1" "${#port_entries[@]}" "Edición portable debe contener un único directorio raíz (anti-tarbomb)"
assert_eq "KeepMyConfig-${TEST_VERSION}-portable" "$(basename "${port_entries[0]}")" "Directorio raíz portable debe coincidir con nombre del paquete"

# ------------------------------------------------------------------------------
# Test 3: Verificación de Lista Blanca y Lista Negra
# ------------------------------------------------------------------------------
echo "--- Test 3: Lista Blanca y Lista Negra ---"
STD_ROOT="${STD_EXTRACT}/KeepMyConfig-${TEST_VERSION}"
PORT_ROOT="${PORT_EXTRACT}/KeepMyConfig-${TEST_VERSION}-portable"

# Lista Blanca Común (Ficheros)
for item in "backup_manager.sh" "config/config.conf" "config/default_tags.conf" \
            "templates.d/template-skeleton.conf" "profiles/default/profile.conf" \
            ".backup_app_marker" "markers/.backup_storage_marker" \
            "assets/keepmyconfig.svg" "assets/keepmyconfig.desktop" \
            "README.md" "MANUAL_USUARIO.md" "CHANGELOG.md" "LICENSE"; do
    assert_file_exists "${STD_ROOT}/${item}" "Estándar debe incluir: $item"
    assert_file_exists "${PORT_ROOT}/${item}" "Portable debe incluir: $item"
done

# Lista Blanca Común (Directorios)
for dir_item in "lib" "config" "templates.d" "profiles/default" "markers" "assets"; do
    assert_dir_exists "${STD_ROOT}/${dir_item}" "Estándar debe incluir directorio: $dir_item"
    assert_dir_exists "${PORT_ROOT}/${dir_item}" "Portable debe incluir directorio: $dir_item"
done

# Diferencias específicas entre ediciones
assert_file_exists "${STD_ROOT}/install.sh" "Edición estándar debe incluir install.sh"
assert_file_exists "${STD_ROOT}/uninstall.sh" "Edición estándar debe incluir uninstall.sh"
assert_file_not_exists "${STD_ROOT}/.portable" "Edición estándar NO debe incluir marcador .portable"

assert_file_exists "${PORT_ROOT}/.portable" "Edición portable debe incluir marcador .portable"
assert_file_exists "${PORT_ROOT}/keepmyconfig.sh" "Edición portable debe incluir lanzador keepmyconfig.sh"
assert_file_not_exists "${PORT_ROOT}/install.sh" "Edición portable NO debe incluir install.sh"
assert_file_not_exists "${PORT_ROOT}/uninstall.sh" "Edición portable NO debe incluir uninstall.sh"

# Lista Negra (exclusión estricta)
for forbidden in ".git" ".gitignore" ".github" ".agents" "specs" "tests" "user_data"; do
    assert_file_not_exists "${STD_ROOT}/${forbidden}" "Estándar NO debe contener: $forbidden"
    assert_file_not_exists "${PORT_ROOT}/${forbidden}" "Portable NO debe contener: $forbidden"
done

# ------------------------------------------------------------------------------
# Test 4: Verificación Criptográfica con SHA256SUMS.txt
# ------------------------------------------------------------------------------
echo "--- Test 4: Verificación criptográfica de SHA256SUMS.txt ---"
(
    cd "$DIST_TEST_DIR"
    sha256sum -c --status SHA256SUMS.txt
)
assert_eq "0" "$?" "sha256sum -c SHA256SUMS.txt debe validar todas las firmas criptográficas"

# ------------------------------------------------------------------------------
# Test 5: Instalación aislada sin sudo con install.sh
# ------------------------------------------------------------------------------
echo "--- Test 5: Instalación desatendida aislada ---"
APP_TARGET="${FAKE_HOME}/.local/share/KeepMyConfig"
BIN_TARGET="${FAKE_HOME}/.local/bin"
BACKUP_DEST="${FAKE_HOME}/Backups"

HOME="$FAKE_HOME" "${STD_ROOT}/install.sh" --yes \
    --target-dir "$APP_TARGET" \
    --bin-dir "$BIN_TARGET" \
    --backup-dest "$BACKUP_DEST" \
    --initial-profile "desarrollo" >/dev/null 2>&1
install_code=$?

assert_eq "0" "$install_code" "install.sh debe instalar con éxito retornando código 0"
assert_file_exists "${BIN_TARGET}/keepmyconfig" "Enlace ejecutable keepmyconfig debe existir en BIN_DIR"
assert_file_exists "${FAKE_HOME}/.local/share/applications/keepmyconfig.desktop" "Lanzador .desktop debe instalarse en aplicaciones"
assert_file_exists "${FAKE_HOME}/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg" "Icono SVG debe instalarse en icons"
assert_dir_exists "${APP_TARGET}/lib" "Directorio lib debe desplegarse en TARGET_DIR"
assert_file_exists "${APP_TARGET}/config/config.conf" "config.conf debe desplegarse en TARGET_DIR"
assert_dir_exists "${APP_TARGET}/profiles/desarrollo" "Perfil inicial 'desarrollo' debe crearse"
assert_file_exists "${BACKUP_DEST}/.backup_storage_marker" "Marcador .backup_storage_marker debe inicializarse en destino"

# Verificar ejecución mediante el enlace en PATH
bin_run_out=$(PATH="${BIN_TARGET}:${PATH}" "${BIN_TARGET}/keepmyconfig" --help 2>&1)
assert_contains "$bin_run_out" "GESTOR DE BACKUP Y RECUPERACIÓN" "Invocación a través del enlace keepmyconfig debe funcionar correctamente"

# ------------------------------------------------------------------------------
# Test 6: Endurecimiento de permisos UNIX en la instalación
# ------------------------------------------------------------------------------
echo "--- Test 6: Endurecimiento de permisos UNIX (Read-Only) ---"
bm_perm=$(stat -c "%a" "${APP_TARGET}/backup_manager.sh")
un_perm=$(stat -c "%a" "${APP_TARGET}/uninstall.sh")
lib_dir_perm=$(stat -c "%a" "${APP_TARGET}/lib")
lib_file_perm=$(stat -c "%a" "${APP_TARGET}/lib/models/device_model.sh")
tmpl_dir_perm=$(stat -c "%a" "${APP_TARGET}/templates.d")
tmpl_file_perm=$(stat -c "%a" "${APP_TARGET}/templates.d/template-skeleton.conf")

assert_eq "555" "$bm_perm" "backup_manager.sh debe tener permisos 0555"
assert_eq "555" "$un_perm" "uninstall.sh debe tener permisos 0555"
assert_eq "555" "$lib_dir_perm" "Directorio lib/ debe tener permisos 0555"
assert_eq "444" "$lib_file_perm" "Ficheros en lib/ deben tener permisos 0444"
assert_eq "555" "$tmpl_dir_perm" "Directorio templates.d/ debe tener permisos 0555"
assert_eq "444" "$tmpl_file_perm" "Ficheros en templates.d/ deben tener permisos 0444"

# Comprobar bloqueo contra inyección
if ( echo "# inyeccion" >> "${APP_TARGET}/lib/models/device_model.sh" ) 2>/dev/null; then
    echo "  [FAIL] Inyección de código en lib/ debería estar bloqueada" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo "  [PASS] Modificación de ficheros en lib/ bloqueada por permisos de solo lectura"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Comprobar que directorios de datos son escribibles
touch "${APP_TARGET}/modules.d/custom-test.conf" 2>/dev/null
assert_file_exists "${APP_TARGET}/modules.d/custom-test.conf" "modules.d/ debe permitir crear módulos de usuario"

# ------------------------------------------------------------------------------
# Test 7: Idempotencia y preservación en re-instalación
# ------------------------------------------------------------------------------
echo "--- Test 7: Idempotencia en actualización/reinstalación ---"
# Modificar un parámetro en config.conf
sed -i 's/ACTIVE_PROFILE="desarrollo"/ACTIVE_PROFILE="personalizado"/' "${APP_TARGET}/config/config.conf"

HOME="$FAKE_HOME" "${STD_ROOT}/install.sh" --yes \
    --target-dir "$APP_TARGET" \
    --bin-dir "$BIN_TARGET" \
    --backup-dest "$BACKUP_DEST" >/dev/null 2>&1
reinstall_code=$?

assert_eq "0" "$reinstall_code" "Reinstalación con permisos endurecidos debe completarse sin error"
cfg_content=$(cat "${APP_TARGET}/config/config.conf")
assert_contains "$cfg_content" 'ACTIVE_PROFILE="personalizado"' "Reinstalación debe preservar configuración existente"
assert_file_exists "${APP_TARGET}/modules.d/custom-test.conf" "Reinstalación debe preservar módulos de usuario preexistentes"

# ------------------------------------------------------------------------------
# Test 8: Ejecución autónoma de la Edición Portable
# ------------------------------------------------------------------------------
echo "--- Test 8: Lanzador y ejecución de la Edición Portable ---"
port_run_out=$("${PORT_ROOT}/keepmyconfig.sh" --help 2>&1)
assert_contains "$port_run_out" "GESTOR DE BACKUP Y RECUPERACIÓN" "Lanzador portable keepmyconfig.sh --help debe funcionar directamente"

# ------------------------------------------------------------------------------
# Test 9: Desinstalación limpia preservando datos (sin --purge)
# ------------------------------------------------------------------------------
echo "--- Test 9: Desinstalador sin --purge ---"
HOME="$FAKE_HOME" "${APP_TARGET}/uninstall.sh" --yes \
    --target-dir "$APP_TARGET" \
    --bin-dir "$BIN_TARGET" >/dev/null 2>&1
uninst_code=$?

assert_eq "0" "$uninst_code" "uninstall.sh sin --purge debe finalizar con código 0"
assert_file_not_exists "${BIN_TARGET}/keepmyconfig" "Enlace en bin/ debe eliminarse"
assert_file_not_exists "${FAKE_HOME}/.local/share/applications/keepmyconfig.desktop" "Lanzador .desktop debe eliminarse"
assert_file_not_exists "${FAKE_HOME}/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg" "Icono SVG debe eliminarse"
assert_dir_exists "$APP_TARGET" "Directorio de aplicación debe preservarse si no se indica --purge"

# ------------------------------------------------------------------------------
# Test 10: Desinstalación con --purge (eliminación completa con permisos 0555)
# ------------------------------------------------------------------------------
echo "--- Test 10: Desinstalador con --purge ---"
HOME="$FAKE_HOME" "${APP_TARGET}/uninstall.sh" --yes --purge \
    --target-dir "$APP_TARGET" \
    --bin-dir "$BIN_TARGET" >/dev/null 2>&1
purge_code=$?

assert_eq "0" "$purge_code" "uninstall.sh --purge debe finalizar con código 0"
assert_file_not_exists "$APP_TARGET" "Directorio de aplicación debe eliminarse por completo tras --purge"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Fallaron $TESTS_FAILED pruebas en test_packaging_and_distribution.sh" >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS DE EMPAQUETADO Y DISTRIBUCIÓN HAN PASADO."
exit 0
