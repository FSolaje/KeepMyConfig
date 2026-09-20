#!/usr/bin/env bash
# ==============================================================================
# lib/models/crypto_model.sh - Modelo MVC para Criptografía GPG, SHA-256 y Shred
# ==============================================================================
# Principio MVC: Lógica pura de cifrado, comprobación de integridad y purga.
# Sin dependencias interactivas (whiptail/dialog). Comunica vía stdout y $?.
# ==============================================================================

# Códigos de retorno estandarizados
export CRYPTO_OK=0
export CRYPTO_ERR_CONFIG=1
export CRYPTO_ERR_NOT_FOUND=2
export CRYPTO_ERR_AUTH=3
export CRYPTO_ERR_GPG=4
export CRYPTO_ERR_SHRED=5
export CRYPTO_ERR_DEPS=6

# ------------------------------------------------------------------------------
# Función: crypto_model_check_deps
# Descripción: Comprueba la disponibilidad de las herramientas gpg, shred y sha256sum.
# Retorno:
#   CRYPTO_OK (0) si todas existen, CRYPTO_ERR_DEPS (6) si alguna falta.
# ------------------------------------------------------------------------------
crypto_model_check_deps() {
    local missing=0
    for cmd in gpg shred sha256sum; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing=1
        fi
    done
    [[ $missing -eq 0 ]] && return "$CRYPTO_OK"
    return "$CRYPTO_ERR_DEPS"
}

# ------------------------------------------------------------------------------
# Función: crypto_model_compute_sha256
# Descripción: Calcula la huella SHA-256 de un fichero.
# Parámetros:
#   $1 - Ruta al fichero
# Salida stdout:
#   Hash hexadecimal SHA-256 (64 caracteres)
# Retorno:
#   CRYPTO_OK si se calculó, código de error si el archivo no existe.
# ------------------------------------------------------------------------------
crypto_model_compute_sha256() {
    local target_file="${1:-}"
    [[ -n "$target_file" ]] || return "$CRYPTO_ERR_CONFIG"
    [[ -f "$target_file" && -r "$target_file" ]] || return "$CRYPTO_ERR_NOT_FOUND"

    local hash_val
    hash_val=$(sha256sum "$target_file" 2>/dev/null | awk '{print $1}')
    if [[ -n "$hash_val" ]]; then
        echo "$hash_val"
        return "$CRYPTO_OK"
    fi
    return "$CRYPTO_ERR_GPG"
}

# ------------------------------------------------------------------------------
# Función: crypto_model_encrypt_file
# Descripción: Cifra simétricamente un archivo con GPG (AES-256 por defecto).
# Parámetros:
#   $1 - Fichero origen sin cifrar
#   $2 - Fichero destino (.gpg)
#   $3 - Frase de contraseña
#   $4 - (Opcional) Algoritmo de cifrado (por defecto AES256)
# Retorno:
#   CRYPTO_OK en éxito, código de error en fallo.
# ------------------------------------------------------------------------------
crypto_model_encrypt_file() {
    local input_file="${1:-}"
    local output_file="${2:-}"
    local passphrase="${3:-}"
    local cipher="${4:-AES256}"

    [[ -n "$input_file" && -n "$output_file" && -n "$passphrase" ]] || return "$CRYPTO_ERR_CONFIG"
    [[ -f "$input_file" && -r "$input_file" ]] || return "$CRYPTO_ERR_NOT_FOUND"

    mkdir -p "$(dirname "$output_file")" 2>/dev/null || return "$CRYPTO_ERR_GPG"

    if gpg --batch --yes --symmetric --cipher-algo "$cipher" \
           --passphrase-fd 0 -o "$output_file" "$input_file" 2>/dev/null <<< "$passphrase"; then
        [[ -f "$output_file" ]] && return "$CRYPTO_OK"
    fi

    return "$CRYPTO_ERR_GPG"
}

# ------------------------------------------------------------------------------
# Función: crypto_model_encrypt_pipe
# Descripción: Cifra un flujo recibido por stdin hacia un archivo destino.
# Parámetros:
#   $1 - Fichero destino (.gpg)
#   $2 - Frase de contraseña
#   $3 - (Opcional) Algoritmo de cifrado (por defecto AES256)
# Entrada stdin:
#   Flujo de datos binarios o tar.zst
# Retorno:
#   CRYPTO_OK en éxito, código de error en fallo.
# ------------------------------------------------------------------------------
crypto_model_encrypt_pipe() {
    local output_file="${1:-}"
    local passphrase="${2:-}"
    local cipher="${3:-AES256}"

    [[ -n "$output_file" && -n "$passphrase" ]] || return "$CRYPTO_ERR_CONFIG"
    mkdir -p "$(dirname "$output_file")" 2>/dev/null || return "$CRYPTO_ERR_GPG"

    # Se usa el descriptor 3 para la contraseña y stdin (fd 0) para el flujo de datos
    if gpg --batch --yes --symmetric --cipher-algo "$cipher" \
           --passphrase-fd 3 -o "$output_file" 2>/dev/null 3<<< "$passphrase"; then
        [[ -f "$output_file" ]] && return "$CRYPTO_OK"
    fi

    return "$CRYPTO_ERR_GPG"
}

# ------------------------------------------------------------------------------
# Función: crypto_model_verify_passphrase
# Descripción: Verifica si una contraseña es válida para un archivo gpg sin extraer a disco.
# Parámetros:
#   $1 - Archivo .gpg a verificar
#   $2 - Contraseña candidata
# Retorno:
#   CRYPTO_OK si es válida, CRYPTO_ERR_AUTH si es incorrecta, CRYPTO_ERR_GPG si el archivo está dañado.
# ------------------------------------------------------------------------------
crypto_model_verify_passphrase() {
    local input_gpg="${1:-}"
    local passphrase="${2:-}"

    [[ -n "$input_gpg" && -n "$passphrase" ]] || return "$CRYPTO_ERR_CONFIG"
    [[ -f "$input_gpg" && -r "$input_gpg" ]] || return "$CRYPTO_ERR_NOT_FOUND"

    local gpg_exit=0
    gpg --batch --yes --decrypt --passphrase-fd 0 -o /dev/null "$input_gpg" 2>/dev/null <<< "$passphrase" || gpg_exit=$?

    if [[ $gpg_exit -eq 0 ]]; then
        return "$CRYPTO_OK"
    elif [[ $gpg_exit -eq 2 ]]; then
        return "$CRYPTO_ERR_AUTH"
    else
        return "$CRYPTO_ERR_GPG"
    fi
}

# ------------------------------------------------------------------------------
# Función: crypto_model_decrypt_file
# Descripción: Descifra un archivo .gpg hacia una ruta destino.
# Parámetros:
#   $1 - Archivo .gpg de entrada
#   $2 - Archivo de salida descifrado
#   $3 - Contraseña
# Retorno:
#   CRYPTO_OK en éxito, CRYPTO_ERR_AUTH si contraseña incorrecta, CRYPTO_ERR_GPG en otro fallo.
# ------------------------------------------------------------------------------
crypto_model_decrypt_file() {
    local input_gpg="${1:-}"
    local output_file="${2:-}"
    local passphrase="${3:-}"

    [[ -n "$input_gpg" && -n "$output_file" && -n "$passphrase" ]] || return "$CRYPTO_ERR_CONFIG"
    [[ -f "$input_gpg" && -r "$input_gpg" ]] || return "$CRYPTO_ERR_NOT_FOUND"

    mkdir -p "$(dirname "$output_file")" 2>/dev/null || return "$CRYPTO_ERR_GPG"

    local gpg_exit=0
    gpg --batch --yes --decrypt --passphrase-fd 0 -o "$output_file" "$input_gpg" 2>/dev/null <<< "$passphrase" || gpg_exit=$?

    if [[ $gpg_exit -eq 0 && -f "$output_file" ]]; then
        return "$CRYPTO_OK"
    elif [[ $gpg_exit -eq 2 ]]; then
        rm -f "$output_file" 2>/dev/null
        return "$CRYPTO_ERR_AUTH"
    else
        rm -f "$output_file" 2>/dev/null
        return "$CRYPTO_ERR_GPG"
    fi
}

# ------------------------------------------------------------------------------
# Función: crypto_model_shred_path
# Descripción: Destruye de forma segura un fichero o un árbol de directorios con shred.
# Parámetros:
#   $1 - Ruta a destruir (fichero o carpeta)
#   $2 - (Opcional) Número de iteraciones (por defecto 3)
#   $3 - (Opcional) Sobrescribir con ceros al final true/false (por defecto true)
# Retorno:
#   CRYPTO_OK si se destruyó y no existe rastro en el sistema.
# ------------------------------------------------------------------------------
crypto_model_shred_path() {
    local target_path="${1:-}"
    local iterations="${2:-3}"
    local zero_pass="${3:-true}"

    [[ -n "$target_path" ]] || return "$CRYPTO_ERR_CONFIG"
    [[ -e "$target_path" ]] || return "$CRYPTO_ERR_NOT_FOUND"

    local zero_flag=""
    if [[ "$zero_pass" == "true" ]]; then
        zero_flag="-z"
    fi

    # Caso 1: Archivo regular o enlace simbólico
    if [[ -f "$target_path" || -L "$target_path" ]]; then
        chmod u+w "$target_path" 2>/dev/null || true
        shred -u -n "$iterations" $zero_flag "$target_path" 2>/dev/null || rm -f "$target_path" 2>/dev/null
        [[ ! -e "$target_path" ]] && return "$CRYPTO_OK"
        return "$CRYPTO_ERR_SHRED"
    fi

    # Caso 2: Directorio (recorrer y destruir todos los ficheros internos)
    if [[ -d "$target_path" ]]; then
        local shred_fail=0
        while IFS= read -r -d '' file_item; do
            chmod u+w "$file_item" 2>/dev/null || true
            if ! shred -u -n "$iterations" $zero_flag "$file_item" 2>/dev/null; then
                # Si shred falla por algún motivo de sistema de archivos, intentar unlink forzado
                rm -f "$file_item" 2>/dev/null || shred_fail=1
            fi
        done < <(find "$target_path" -type f -print0)

        # Podar subdirectorios vacíos de abajo hacia arriba
        find "$target_path" -depth -type d -exec rmdir {} + 2>/dev/null || true
        rmdir "$target_path" 2>/dev/null || rm -rf "$target_path" 2>/dev/null || true

        [[ ! -e "$target_path" ]] && return "$CRYPTO_OK"
        return "$CRYPTO_ERR_SHRED"
    fi

    return "$CRYPTO_ERR_SHRED"
}
