#!/usr/bin/env bash
# ==============================================================================
# Archivo: tests/test_sample_modules.sh
# Descripción: Suite de pruebas para modules.d/bash-env.conf y modules.d/ssh-keys.conf
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar modelos requeridos
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/models/module_model.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/models/crypto_model.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/models/backup_model.sh"
# shellcheck disable=SC1091
source "${PROJECT_ROOT}/lib/models/restore_model.sh"

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

echo "=== Iniciando Tests de Módulos: bash-env.conf y ssh-keys.conf ==="

# Test 1: Parser de bash-env
bash_meta=$(module_model_get "bash-env")
assert_contains "$bash_meta" "ID=bash-env" "bash-env debe tener ID=bash-env"
assert_contains "$bash_meta" "IS_SENSITIVE=false" "bash-env debe ser no sensible"
assert_contains "$bash_meta" "PURGE_AFTER_BACKUP=false" "bash-env no debe purgar tras backup"
assert_contains "$bash_meta" "system" "bash-env debe incluir etiqueta 'system'"
assert_contains "$bash_meta" "dev" "bash-env debe incluir etiqueta 'dev'"

# Test 2: Parser de ssh-keys
ssh_meta=$(module_model_get "ssh-keys")
assert_contains "$ssh_meta" "ID=ssh-keys" "ssh-keys debe tener ID=ssh-keys"
assert_contains "$ssh_meta" "IS_SENSITIVE=true" "ssh-keys debe ser sensible (GPG)"
assert_contains "$ssh_meta" "PURGE_AFTER_BACKUP=true" "ssh-keys debe tener auto-purga activa"
assert_contains "$ssh_meta" "chmod 700" "ssh-keys debe definir hook de permisos 700"

# Test 3: Filtrado por etiquetas
sys_mods=$(module_model_filter_by_tag "system")
assert_contains "$sys_mods" "bash-env" "filter_by_tag 'system' debe incluir bash-env"
assert_contains "$sys_mods" "ssh-keys" "filter_by_tag 'system' debe incluir ssh-keys"

# Sandbox para ciclo de vida de backup y restore
SANDBOX_DIR=$(mktemp -d /tmp/backupconfig_sample_mods_XXXXXX)
MOCK_HOME="${SANDBOX_DIR}/home"
MOCK_BACKUP="${SANDBOX_DIR}/storage/Backups"

cleanup() {
    rm -rf "$SANDBOX_DIR"
}
trap cleanup EXIT

mkdir -p "$MOCK_HOME/.ssh" "$MOCK_BACKUP"

# Crear ficheros simulados en home
echo 'alias ll="ls -la"' > "$MOCK_HOME/.bash_aliases"
echo 'export PATH=$PATH:/opt/bin' > "$MOCK_HOME/.bashrc"
echo 'SIMULATED_PRIVATE_RSA_KEY_123456789' > "$MOCK_HOME/.ssh/id_rsa"
echo 'ssh-rsa AAAAB3NzaC1yc2E test@host' > "$MOCK_HOME/.ssh/id_rsa.pub"
echo 'Host * ServerAliveInterval 60' > "$MOCK_HOME/.ssh/config"
chmod 700 "$MOCK_HOME/.ssh"
chmod 600 "$MOCK_HOME/.ssh/id_rsa"

# Test 4: Backup de bash-env (estándar, sin purga)
b_env_res=$(backup_model_run "bash-env" "$MOCK_BACKUP" "$MOCK_HOME" "" "false" "false")
assert_contains "$b_env_res" "STATUS=SUCCESS" "Backup de bash-env debe ser exitoso"
assert_contains "$b_env_res" "PURGED=false" "bash-env no debe purgarse"

if [[ -f "$MOCK_HOME/.bash_aliases" && -f "$MOCK_HOME/.bashrc" ]]; then
    echo "  [PASS] Ficheros de bash-env permanecen intactos en origen"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] Ficheros de bash-env desaparecieron de origen" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Backup de ssh-keys (sensible, con purga shred -u)
TEST_KEY="clave-segura-ssh-123"
b_ssh_res=$(backup_model_run "ssh-keys" "$MOCK_BACKUP" "$MOCK_HOME" "$TEST_KEY" "auto" "false")
assert_contains "$b_ssh_res" "STATUS=SUCCESS" "Backup de ssh-keys debe ser exitoso"
assert_contains "$b_ssh_res" "IS_SENSITIVE=true" "ssh-keys debe registrarse como sensible"
assert_contains "$b_ssh_res" "PURGED=true" "ssh-keys debe haberse purgado con shred"

if [[ ! -f "$MOCK_HOME/.ssh/id_rsa" && ! -f "$MOCK_HOME/.ssh/config" ]]; then
    echo "  [PASS] Ficheros sensibles de SSH fueron eliminados con shred de origen tras el backup"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] Los ficheros de SSH aún existen en el home tras el backup" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Restauración de ssh-keys y ejecución del hook de permisos
r_ssh_res=$(restore_model_restore_module "ssh-keys" "$MOCK_BACKUP" "$MOCK_HOME" "" "$TEST_KEY")
assert_contains "$r_ssh_res" "STATUS=SUCCESS" "Restauración de ssh-keys debe ser exitosa"
assert_contains "$r_ssh_res" "HOOK_EXECUTED=true" "El hook de permisos de SSH debe haberse ejecutado"

if [[ -f "$MOCK_HOME/.ssh/id_rsa" ]]; then
    echo "  [PASS] Llave id_rsa restituida tras restauración"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo "  [FAIL] Llave id_rsa no encontrada tras restauración" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Comprobar permisos 600 en id_rsa
key_perm=$(stat -c "%a" "$MOCK_HOME/.ssh/id_rsa" 2>/dev/null || stat -f "%OLp" "$MOCK_HOME/.ssh/id_rsa" 2>/dev/null)
assert_eq "600" "$key_perm" "El hook debe restablecer permisos 600 en id_rsa"

# Comprobar permisos 700 en .ssh
ssh_dir_perm=$(stat -c "%a" "$MOCK_HOME/.ssh" 2>/dev/null || stat -f "%OLp" "$MOCK_HOME/.ssh" 2>/dev/null)
assert_eq "700" "$ssh_dir_perm" "El hook debe restablecer permisos 700 en .ssh"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."

if (( TESTS_FAILED > 0 )); then
    echo "ERROR: Pruebas de módulos fallidas." >&2
    exit 1
fi

echo "RESULTADO: TODAS LAS PRUEBAS DE MÓDULOS ADICIONALES HAN PASADO."
