#!/usr/bin/env bash
# ==============================================================================
# lib/models/restore_model.sh - Motor de Restauración Histórica y Hooks
# ==============================================================================
# Principio MVC: Lógica pura de extracción, resolución de histórico y hooks.
# Sin dependencias interactivas (whiptail/dialog). Comunica vía stdout y $?.
# ==============================================================================

# Códigos de retorno estandarizados
export RESTORE_OK=0
export RESTORE_ERR_CONFIG=1
export RESTORE_ERR_NOT_FOUND=2
export RESTORE_ERR_NO_ARCHIVE=3
export RESTORE_ERR_PASSPHRASE=4
export RESTORE_ERR_EXTRACTION=5
export RESTORE_ERR_HOOK=6

# Cargar modelos colaboradores si no están ya en memoria
_RESTORE_MODEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F module_model_get >/dev/null 2>&1; then
    # shellcheck source=./module_model.sh
    source "$_RESTORE_MODEL_DIR/module_model.sh"
fi
if ! declare -F crypto_model_verify_passphrase >/dev/null 2>&1; then
    # shellcheck source=./crypto_model.sh
    source "$_RESTORE_MODEL_DIR/crypto_model.sh"
fi

# ------------------------------------------------------------------------------
# Función: restore_model_find_archive
# Descripción: Localiza el archivo de copia exacto o más reciente para un módulo.
# Parámetros:
#   $1 - ID del módulo
#   $2 - Directorio de almacenamiento externo ($BACKUP_DIR)
#   $3 - (Opcional) Timestamp específico AAAAMMDD_HHMMSS
# Salida stdout:
#   Pares CLAVE=VALOR: ARCHIVE_FILE=... TIMESTAMP=... IS_ENCRYPTED=...
# Retorno:
#   0 si se localiza, RESTORE_ERR_NO_ARCHIVE si no existe.
# ------------------------------------------------------------------------------
restore_model_find_archive() {
    local mod_id="${1:-}"
    local backup_dir="${2:-}"
    local req_ts="${3:-}"

    [[ -n "$mod_id" && -n "$backup_dir" ]] || return "$RESTORE_ERR_CONFIG"
    local archive_dir="$backup_dir/archives/$mod_id"
    [[ -d "$archive_dir" ]] || return "$RESTORE_ERR_NO_ARCHIVE"

    local archive_file=""

    if [[ -n "$req_ts" ]]; then
        # Búsqueda de timestamp específico
        if [[ -f "$archive_dir/${req_ts}.tar.zst.gpg" ]]; then
            archive_file="$archive_dir/${req_ts}.tar.zst.gpg"
        elif [[ -f "$archive_dir/${req_ts}.tar.zst" ]]; then
            archive_file="$archive_dir/${req_ts}.tar.zst"
        fi
    else
        # Búsqueda del archivo más reciente (excluyendo temporales .tmp_)
        archive_file=$(find "$archive_dir" -maxdepth 1 \( -name "*.tar.zst" -o -name "*.tar.zst.gpg" \) \
                       -not -name ".tmp_*" 2>/dev/null | sort | tail -n 1)
    fi

    [[ -n "$archive_file" && -f "$archive_file" ]] || return "$RESTORE_ERR_NO_ARCHIVE"

    local filename is_enc="false" actual_ts
    filename=$(basename "$archive_file")
    if [[ "$filename" =~ \.gpg$ ]]; then
        is_enc="true"
        actual_ts=$(echo "$filename" | sed -E 's/\.tar\.zst\.gpg$//')
    else
        actual_ts=$(echo "$filename" | sed -E 's/\.tar\.zst$//')
    fi

    echo "ARCHIVE_FILE=$archive_file"
    echo "TIMESTAMP=$actual_ts"
    echo "IS_ENCRYPTED=$is_enc"
    return "$RESTORE_OK"
}

# ------------------------------------------------------------------------------
# Función: restore_model_restore_module
# Descripción: Restaura un módulo concreto hacia el directorio de usuario.
# Parámetros:
#   $1 - ID del módulo
#   $2 - Directorio de almacenamiento externo ($BACKUP_DIR)
#   $3 - (Opcional) Home del usuario destino (por defecto $HOME)
#   $4 - (Opcional) Timestamp específico (si vacío, restaura el último)
#   $5 - (Opcional) Contraseña GPG (requerida si el archivo es .gpg)
#   $6 - (Opcional) Directorio de módulos alternativo
# Retorno:
#   0 en éxito, código de error correspondiente en fallo.
# ------------------------------------------------------------------------------
restore_model_restore_module() {
    local mod_id="${1:-}"
    local backup_dir="${2:-}"
    local target_home="${3:-${HOME}}"
    local req_ts="${4:-}"
    local passphrase="${5:-}"
    local modules_dir="${6:-}"

    [[ -n "$mod_id" && -n "$backup_dir" ]] || return "$RESTORE_ERR_CONFIG"

    # 1. Localizar archivo de respaldo
    local archive_meta
    archive_meta=$(restore_model_find_archive "$mod_id" "$backup_dir" "$req_ts") || return "$RESTORE_ERR_NO_ARCHIVE"

    local archive_file actual_ts is_enc
    archive_file=$(echo "$archive_meta" | awk -F'=' '$1 == "ARCHIVE_FILE" {print $2}')
    actual_ts=$(echo "$archive_meta" | awk -F'=' '$1 == "TIMESTAMP" {print $2}')
    is_enc=$(echo "$archive_meta" | awk -F'=' '$1 == "IS_ENCRYPTED" {print $2}')

    mkdir -p "$target_home" 2>/dev/null || return "$RESTORE_ERR_EXTRACTION"

    # 2. Desempaquetado (con o sin descifrado GPG)
    if [[ "$is_enc" == "true" ]]; then
        [[ -n "$passphrase" ]] || return "$RESTORE_ERR_PASSPHRASE"

        # Verificar contraseña antes de iniciar el pipe
        crypto_model_verify_passphrase "$archive_file" "$passphrase" || return "$RESTORE_ERR_PASSPHRASE"

        # Canalización directa en memoria: GPG decrypt | tar extract
        if ! gpg --batch --yes --decrypt --passphrase-fd 3 "$archive_file" 2>/dev/null 3<<< "$passphrase" | \
             tar -I 'zstd' -xf - -C "$target_home" 2>/dev/null; then
            return "$RESTORE_ERR_EXTRACTION"
        fi
    else
        if ! tar -I 'zstd' -xf "$archive_file" -C "$target_home" 2>/dev/null; then
            return "$RESTORE_ERR_EXTRACTION"
        fi
    fi

    # 3. Ejecutar POST_RESTORE_HOOK si está definido en la receta
    local mod_meta hook=""
    if mod_meta=$(module_model_get "$mod_id" ${modules_dir:+"$modules_dir"} 2>/dev/null); then
        hook=$(echo "$mod_meta" | awk -F'=' '$1 == "POST_RESTORE_HOOK" {print $2}')
    fi

    if [[ -n "$hook" ]]; then
        if ! (cd "$target_home" && eval "$hook" >/dev/null 2>&1); then
            return "$RESTORE_ERR_HOOK"
        fi
    fi

    # 4. Registrar en el historial de operaciones
    mkdir -p "$backup_dir/logs" 2>/dev/null || true
    echo "[$(date +"%Y%m%d_%H%M%S")] RESTORE MODULE=$mod_id ARCHIVE=$(basename "$archive_file") TIMESTAMP=$actual_ts STATUS=SUCCESS" >> "$backup_dir/logs/backup_history.log"

    # 5. Salida estructurada de confirmación
    echo "STATUS=SUCCESS"
    echo "MODULE_ID=$mod_id"
    echo "TIMESTAMP=$actual_ts"
    echo "ARCHIVE_FILE=$archive_file"
    echo "IS_ENCRYPTED=$is_enc"
    echo "HOOK_EXECUTED=$([[ -n "$hook" ]] && echo "true" || echo "false")"

    return "$RESTORE_OK"
}

# ------------------------------------------------------------------------------
# Función: restore_model_restore_by_tag
# Descripción: Restaura todos los módulos pertenecientes a una etiqueta.
# Parámetros:
#   $1 - Etiqueta (ej: dev, sensitive)
#   $2 - Directorio de backups ($BACKUP_DIR)
#   $3 - (Opcional) Home destino
#   $4 - (Opcional) Contraseña para módulos sensibles
#   $5 - (Opcional) Directorio de módulos alternativo
# Salida stdout:
#   Líneas RESTORED=<module_id> o FAILED=<module_id>:<error_code>
# Retorno:
#   0 si todos tuvieron éxito, 1 si alguno falló.
# ------------------------------------------------------------------------------
restore_model_restore_by_tag() {
    local tag="${1:-}"
    local backup_dir="${2:-}"
    local target_home="${3:-${HOME}}"
    local passphrase="${4:-}"
    local modules_dir="${5:-}"

    [[ -n "$tag" && -n "$backup_dir" ]] || return "$RESTORE_ERR_CONFIG"

    local modules_list
    modules_list=$(module_model_filter_by_tag "$tag" ${modules_dir:+"$modules_dir"}) || return "$RESTORE_ERR_NOT_FOUND"

    local total_errors=0
    while IFS= read -r mod_id; do
        [[ -n "$mod_id" ]] || continue
        if restore_model_restore_module "$mod_id" "$backup_dir" "$target_home" "" "$passphrase" ${modules_dir:+"$modules_dir"} >/dev/null 2>&1; then
            echo "RESTORED=$mod_id"
        else
            echo "FAILED=$mod_id"
            ((total_errors++))
        fi
    done <<< "$modules_list"

    [[ $total_errors -eq 0 ]] && return "$RESTORE_OK"
    return "$RESTORE_ERR_EXTRACTION"
}

# ------------------------------------------------------------------------------
# Función: restore_model_restore_sensitive_all
# Descripción: Restaura todos los módulos sensibles con una única contraseña.
# Parámetros:
#   $1 - Directorio de backups ($BACKUP_DIR)
#   $2 - (Opcional) Home destino
#   $3 - Contraseña GPG
#   $4 - (Opcional) Directorio de módulos alternativo
# Retorno:
#   0 si todos tuvieron éxito, >0 si falló alguno.
# ------------------------------------------------------------------------------
restore_model_restore_sensitive_all() {
    local backup_dir="${1:-}"
    local target_home="${2:-${HOME}}"
    local passphrase="${3:-}"
    local modules_dir="${4:-}"

    [[ -n "$backup_dir" && -n "$passphrase" ]] || return "$RESTORE_ERR_CONFIG"

    local sensitive_modules
    sensitive_modules=$(module_model_filter_by_sensitivity "true" ${modules_dir:+"$modules_dir"}) || return "$RESTORE_OK"

    local total_errors=0
    while IFS= read -r mod_id; do
        [[ -n "$mod_id" ]] || continue
        if restore_model_restore_module "$mod_id" "$backup_dir" "$target_home" "" "$passphrase" ${modules_dir:+"$modules_dir"} >/dev/null 2>&1; then
            echo "RESTORED_SENSITIVE=$mod_id"
        else
            echo "FAILED_SENSITIVE=$mod_id"
            ((total_errors++))
        fi
    done <<< "$sensitive_modules"

    [[ $total_errors -eq 0 ]] && return "$RESTORE_OK"
    return "$RESTORE_ERR_EXTRACTION"
}

# ------------------------------------------------------------------------------
# Función: restore_model_restore_all
# Descripción: Restaura el último backup de todos los módulos presentes en el SSD.
# Parámetros:
#   $1 - Directorio de backups ($BACKUP_DIR)
#   $2 - (Opcional) Home destino
#   $3 - (Opcional) Contraseña GPG para módulos sensibles
#   $4 - (Opcional) Directorio de módulos alternativo
# Retorno:
#   0 si todos tuvieron éxito, >0 si falló alguno.
# ------------------------------------------------------------------------------
restore_model_restore_all() {
    local backup_dir="${1:-}"
    local target_home="${2:-${HOME}}"
    local passphrase="${3:-}"
    local modules_dir="${4:-}"

    [[ -n "$backup_dir" && -d "$backup_dir/archives" ]] || return "$RESTORE_ERR_CONFIG"

    local total_errors=0
    for mod_dir in "$backup_dir/archives"/*; do
        [[ -d "$mod_dir" ]] || continue
        local mod_id
        mod_id=$(basename "$mod_dir")
        if restore_model_restore_module "$mod_id" "$backup_dir" "$target_home" "" "$passphrase" ${modules_dir:+"$modules_dir"} >/dev/null 2>&1; then
            echo "RESTORED=$mod_id"
        else
            echo "FAILED=$mod_id"
            ((total_errors++))
        fi
    done

    [[ $total_errors -eq 0 ]] && return "$RESTORE_OK"
    return "$RESTORE_ERR_EXTRACTION"
}
