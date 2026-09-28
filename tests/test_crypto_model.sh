#!/usr/bin/env bash
# ==============================================================================
# tests/test_crypto_model.sh - Suite de Pruebas Unitarias para crypto_model.sh
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
# shellcheck source=../lib/models/crypto_model.sh
source "$PROJECT_ROOT/lib/models/crypto_model.sh"

echo "=== Iniciando Tests Unitarios de lib/models/crypto_model.sh ==="

TEMP_DIR=$(mktemp -d /tmp/test_crypto_XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

# ------------------------------------------------------------------------------
# Test 1: Comprobación de Dependencias
# ------------------------------------------------------------------------------
crypto_model_check_deps
assert_exit_code "$CRYPTO_OK" $? "check_deps debe confirmar disponibilidad de gpg, shred y sha256sum"

# ------------------------------------------------------------------------------
# Test 2: Cálculo de Hash SHA-256
# ------------------------------------------------------------------------------
SAMPLE_FILE="$TEMP_DIR/sample_hash.txt"
echo "Contenido para verificar hash sha256" > "$SAMPLE_FILE"

HASH_COMPUTED=$(crypto_model_compute_sha256 "$SAMPLE_FILE")
assert_exit_code "$CRYPTO_OK" $? "compute_sha256 debe retornar 0 en archivo existente"
HASH_EXPECTED=$(sha256sum "$SAMPLE_FILE" | awk '{print $1}')
assert_equals "$HASH_EXPECTED" "$HASH_COMPUTED" "compute_sha256 debe coincidir con sha256sum del sistema"

crypto_model_compute_sha256 "$TEMP_DIR/archivo_fantasma.txt" >/dev/null 2>&1
assert_exit_code "$CRYPTO_ERR_NOT_FOUND" $? "compute_sha256 en archivo inexistente debe retornar CRYPTO_ERR_NOT_FOUND"

# ------------------------------------------------------------------------------
# Test 3: Cifrado y Descifrado de Archivos
# ------------------------------------------------------------------------------
SECRET_DATA="DatoUltraSecreto_2026_Test"
PLAIN_FILE="$TEMP_DIR/plain_secret.txt"
GPG_FILE="$TEMP_DIR/encrypted_secret.txt.gpg"
DECRYPTED_FILE="$TEMP_DIR/restored_secret.txt"
PASSPHRASE="MiContrasenaSegura_1234!"

echo "$SECRET_DATA" > "$PLAIN_FILE"

crypto_model_encrypt_file "$PLAIN_FILE" "$GPG_FILE" "$PASSPHRASE"
assert_exit_code "$CRYPTO_OK" $? "encrypt_file debe cifrar exitosamente con GPG"
[[ -f "$GPG_FILE" ]]
assert_equals "0" "$?" "El archivo cifrado .gpg debe existir en disco"

# Descifrado con contraseña correcta
crypto_model_decrypt_file "$GPG_FILE" "$DECRYPTED_FILE" "$PASSPHRASE"
assert_exit_code "$CRYPTO_OK" $? "decrypt_file con contraseña correcta debe retornar 0"
RESTORED_CONTENT=$(cat "$DECRYPTED_FILE")
assert_equals "$SECRET_DATA" "$RESTORED_CONTENT" "El contenido descifrado debe ser idéntico al original"

# Descifrado con contraseña errónea
BAD_DECRYPT_FILE="$TEMP_DIR/should_not_exist.txt"
crypto_model_decrypt_file "$GPG_FILE" "$BAD_DECRYPT_FILE" "ContrasenaEquivocada" >/dev/null 2>&1
assert_exit_code "$CRYPTO_ERR_AUTH" $? "decrypt_file con clave incorrecta debe retornar CRYPTO_ERR_AUTH"
[[ ! -f "$BAD_DECRYPT_FILE" ]]
assert_equals "0" "$?" "El archivo de destino no debe crearse si falla la autenticación"

# ------------------------------------------------------------------------------
# Test 4: Verificación Rápida de Contraseña (sin extracción a disco)
# ------------------------------------------------------------------------------
crypto_model_verify_passphrase "$GPG_FILE" "$PASSPHRASE"
assert_exit_code "$CRYPTO_OK" $? "verify_passphrase debe retornar CRYPTO_OK con clave correcta"

crypto_model_verify_passphrase "$GPG_FILE" "ClaveInvalida_999" >/dev/null 2>&1
assert_exit_code "$CRYPTO_ERR_AUTH" $? "verify_passphrase debe retornar CRYPTO_ERR_AUTH con clave errónea"

# ------------------------------------------------------------------------------
# Test 5: Cifrado desde Tubería (Pipe Stream)
# ------------------------------------------------------------------------------
PIPE_GPG_FILE="$TEMP_DIR/stream_output.gpg"
PIPE_RESTORED_FILE="$TEMP_DIR/stream_restored.txt"
PIPE_DATA="Flujo binario simulado a traves de tuberias"

echo "$PIPE_DATA" | crypto_model_encrypt_pipe "$PIPE_GPG_FILE" "$PASSPHRASE"
assert_exit_code "$CRYPTO_OK" $? "encrypt_pipe debe cifrar datos desde stdin"

crypto_model_decrypt_file "$PIPE_GPG_FILE" "$PIPE_RESTORED_FILE" "$PASSPHRASE"
assert_exit_code "$CRYPTO_OK" $? "decrypt_file debe descifrar el archivo generado por pipe"
PIPE_CONTENT=$(cat "$PIPE_RESTORED_FILE")
assert_equals "$PIPE_DATA" "$PIPE_CONTENT" "El contenido descifrado desde tubería debe ser idéntico"

# ------------------------------------------------------------------------------
# Test 6: Purga Segura (Shred) de Fichero Individual
# ------------------------------------------------------------------------------
FILE_TO_SHRED="$TEMP_DIR/sensitive_file_to_kill.txt"
echo "Informacion confidencial que debe ser borrada sin recuperacion" > "$FILE_TO_SHRED"

crypto_model_shred_path "$FILE_TO_SHRED" 3 "true"
assert_exit_code "$CRYPTO_OK" $? "shred_path en fichero individual debe retornar CRYPTO_OK"
[[ ! -e "$FILE_TO_SHRED" ]]
assert_equals "0" "$?" "El fichero destruido con shred no debe existir en el sistema"

# ------------------------------------------------------------------------------
# Test 7: Purga Segura (Shred) de Árbol Completo de Directorios
# ------------------------------------------------------------------------------
TREE_TO_SHRED="$TEMP_DIR/vault_dir"
mkdir -p "$TREE_TO_SHRED/nested1/nested2"
echo "token1" > "$TREE_TO_SHRED/root.txt"
echo "token2" > "$TREE_TO_SHRED/nested1/sub1.txt"
echo "token3" > "$TREE_TO_SHRED/nested1/nested2/deep.txt"

crypto_model_shred_path "$TREE_TO_SHRED" 3 "true"
assert_exit_code "$CRYPTO_OK" $? "shred_path en directorio recursivo debe retornar CRYPTO_OK"
[[ ! -e "$TREE_TO_SHRED" ]]
assert_equals "0" "$?" "El árbol completo de directorios debe desaparecer del sistema"

# ------------------------------------------------------------------------------
# Test 8: Control de Errores en Shred
# ------------------------------------------------------------------------------
crypto_model_shred_path "$TEMP_DIR/inexistente_999" >/dev/null 2>&1
assert_exit_code "$CRYPTO_ERR_NOT_FOUND" $? "shred_path en ruta inexistente debe retornar CRYPTO_ERR_NOT_FOUND"

echo "==============================================================="
echo "Resumen de pruebas: $TESTS_PASSED superadas, $TESTS_FAILED fallidas."
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo "RESULTADO: TODAS LAS PRUEBAS UNITARIAS DE CRYPTO_MODEL HAN PASADO."
    exit 0
else
    echo "RESULTADO: SE ENCONTRARON FALLOS EN LAS PRUEBAS."
    exit 1
fi
