#!/usr/bin/env bash
# ==============================================================================
# lib/models/backup_model.sh - Motor de Empaquetado, Manifiestos y Diffs
# ==============================================================================
# Principio MVC: Lógica pura de negocio para empaquetado, integridad y auditoría.
# Sin dependencias interactivas (whiptail/dialog). Comunica vía stdout y $?.
# ==============================================================================

# Códigos de retorno estandarizados
export BACKUP_OK=0
export BACKUP_ERR_CONFIG=1
export BACKUP_ERR_MODULE=2
export BACKUP_ERR_NO_FILES=3
export BACKUP_ERR_PASSPHRASE=4
export BACKUP_ERR_ARCHIVE=5
export BACKUP_ERR_CORRUPT=6
export BACKUP_ERR_SHRED=7

# Cargar modelos colaboradores si no están ya en memoria
_BACKUP_MODEL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F module_model_get >/dev/null 2>&1; then
    # shellcheck source=./module_model.sh
    source "$_BACKUP_MODEL_DIR/module_model.sh"
fi
if ! declare -F crypto_model_encrypt_pipe >/dev/null 2>&1; then
    # shellcheck source=./crypto_model.sh
    source "$_BACKUP_MODEL_DIR/crypto_model.sh"
fi

# ------------------------------------------------------------------------------
# Función: backup_model_generate_timestamp
# Descripción: Genera una marca de tiempo uniforme AAAAMMDD_HHMMSS.
# ------------------------------------------------------------------------------
backup_model_generate_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# ------------------------------------------------------------------------------
# Función: backup_model_find_latest_manifest
# Descripción: Localiza el último archivo .manifest.log en el histórico de un módulo.
# Parámetros:
#   $1 - Directorio del módulo ($BACKUP_DIR/archives/$module_id)
# Salida stdout:
#   Ruta completa al archivo de manifiesto más reciente o vacío si no existe.
# ------------------------------------------------------------------------------
backup_model_find_latest_manifest() {
    local module_archive_dir="${1:-}"
    [[ -n "$module_archive_dir" && -d "$module_archive_dir" ]] || return 0

    local latest
    latest=$(find "$module_archive_dir" -maxdepth 1 -name "*.manifest.log" 2>/dev/null | sort | tail -n 1)
    echo "$latest"
}

# ------------------------------------------------------------------------------
# Función: backup_model_compute_diff
# Descripción: Compara inventarios entre un manifiesto anterior y el actual.
# Parámetros:
#   $1 - Ruta al manifiesto previo (puede estar vacío)
#   $2 - Archivo temporal que contiene el inventario actual (formato: HASH BYTES RUTA)
# Salida stdout:
#   Líneas con diferencias (+ para nuevo, ~ para modificado, - para eliminado)
# ------------------------------------------------------------------------------
backup_model_compute_diff() {
    local prev_manifest="${1:-}"
    local current_inv="${2:-}"

    if [[ -z "$prev_manifest" || ! -f "$prev_manifest" ]]; then
        echo "[DIFF_PREVIOUS_BACKUP=NONE]"
        while IFS=' ' read -r _ _ rel_path; do
            [[ -n "$rel_path" ]] && echo "+ $rel_path"
        done < "$current_inv"
        return 0
    fi

    local prev_ts
    prev_ts=$(basename "$prev_manifest" .manifest.log)
    echo "[DIFF_PREVIOUS_BACKUP=$prev_ts]"

    declare -A prev_hashes
    declare -A curr_hashes

    # Leer inventario anterior (filtrando líneas de cabecera y diff previo)
    local in_inv=0
    while IFS= read -r line; do
        if [[ "$line" == "[INVENTORY]" ]]; then
            in_inv=1
            continue
        elif [[ "$line" =~ ^\[DIFF ]]; then
            in_inv=0
            break
        fi
        if [[ $in_inv -eq 1 && -n "$line" ]]; then
            local h b p
            h=$(echo "$line" | awk '{print $1}')
            p=$(echo "$line" | awk '{$1=""; $2=""; print $0}' | sed 's/^[ \t]*//')
            [[ -n "$p" ]] && prev_hashes["$p"]="$h"
        fi
    done < "$prev_manifest"

    # Leer inventario actual
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local ch cb cp
        ch=$(echo "$line" | awk '{print $1}')
        cp=$(echo "$line" | awk '{$1=""; $2=""; print $0}' | sed 's/^[ \t]*//')
        [[ -n "$cp" ]] && curr_hashes["$cp"]="$ch"
    done < "$current_inv"

    # Detectar añadidos (+) y modificados (~)
    for path in "${!curr_hashes[@]}"; do
        if [[ -z "${prev_hashes[$path]:-}" ]]; then
            echo "+ $path"
        elif [[ "${prev_hashes[$path]}" != "${curr_hashes[$path]}" ]]; then
            echo "~ $path"
        fi
    done | sort

    # Detectar eliminados (-)
    for path in "${!prev_hashes[@]}"; do
        if [[ -z "${curr_hashes[$path]:-}" ]]; then
            echo "- $path"
        fi
    done | sort
}

# ------------------------------------------------------------------------------
# Función: backup_model_verify_archive
# Descripción: Verifica la integridad física del archivo de backup generado.
# Parámetros:
#   $1 - Ruta al archivo comprimido (.tar.zst o .tar.zst.gpg)
#   $2 - is_sensitive (true/false)
#   $3 - (Opcional) Contraseña si es sensible
# Retorno:
#   0 si el archivo es íntegro y legible, >0 si está corrupto.
# ------------------------------------------------------------------------------
backup_model_verify_archive() {
    local archive_path="${1:-}"
    local is_sensitive="${2:-false}"
    local passphrase="${3:-}"

    [[ -n "$archive_path" && -f "$archive_path" ]] || return "$BACKUP_ERR_CORRUPT"

    if [[ "$is_sensitive" == "true" ]]; then
        crypto_model_verify_passphrase "$archive_path" "$passphrase" || return "$BACKUP_ERR_CORRUPT"
    else
        tar -I 'zstd' -tf "$archive_path" >/dev/null 2>&1 || return "$BACKUP_ERR_CORRUPT"
    fi

    return "$BACKUP_OK"
}

# ------------------------------------------------------------------------------
# Función: backup_model_list_history
# Descripción: Lista las marcas de tiempo disponibles de un módulo ordenadas.
# Parámetros:
#   $1 - ID del módulo
#   $2 - Directorio de backups del almacenamiento externo
# Salida stdout:
#   Marcas de tiempo AAAAMMDD_HHMMSS una por línea
# ------------------------------------------------------------------------------
backup_model_list_history() {
    local mod_id="${1:-}"
    local backup_dir="${2:-}"

    [[ -n "$mod_id" && -n "$backup_dir" ]] || return "$BACKUP_ERR_CONFIG"
    local archive_dir="$backup_dir/archives/$mod_id"
    [[ -d "$archive_dir" ]] || return "$BACKUP_OK"

    find "$archive_dir" -maxdepth 1 -name "*.manifest.log" 2>/dev/null | \
        sed 's/.*\/[^\/]*\///; s/\.manifest\.log$//' | sort
}

# ------------------------------------------------------------------------------
# Función: backup_model_run
# Descripción: Ejecuta el respaldo integral atómico de un módulo concreto.
# Parámetros:
#   $1 - ID del módulo
#   $2 - Directorio destino en almacenamiento externo ($BACKUP_DIR)
#   $3 - (Opcional) Home del usuario origen (por defecto $HOME)
#   $4 - (Opcional) Contraseña GPG (obligatoria si IS_SENSITIVE=true)
#   $5 - (Opcional) force_purge (true/false)
#   $6 - (Opcional) no_purge (true/false)
#   $7 - (Opcional) Directorio de módulos alternativo
#   $8 - (Opcional) Nivel de compresión zstd (por defecto 3)
#   $9 - (Opcional) Algoritmo GPG (por defecto AES256)
# Salida stdout:
#   Pares CLAVE=VALOR informando el resultado detallado del respaldo.
# ------------------------------------------------------------------------------
backup_model_run() {
    local mod_id="${1:-}"
    local backup_dir="${2:-}"
    local target_home="${3:-${HOME}}"
    local passphrase="${4:-}"
    local force_purge="${5:-false}"
    local no_purge="${6:-false}"
    local modules_dir="${7:-}"
    local comp_level="${8:-3}"
    local cipher="${9:-AES256}"

    [[ -n "$mod_id" && -n "$backup_dir" ]] || return "$BACKUP_ERR_CONFIG"

    # 1. Obtener metadatos del módulo
    local mod_meta
    mod_meta=$(module_model_get "$mod_id" ${modules_dir:+"$modules_dir"}) || return "$BACKUP_ERR_MODULE"

    local mod_name is_sensitive purge_after_backup
    mod_name=$(echo "$mod_meta" | awk -F'=' '$1 == "NAME" {print $2}')
    is_sensitive=$(echo "$mod_meta" | awk -F'=' '$1 == "IS_SENSITIVE" {print $2}')
    purge_after_backup=$(echo "$mod_meta" | awk -F'=' '$1 == "PURGE_AFTER_BACKUP" {print $2}')

    # 2. Comprobar contraseña si es sensible
    if [[ "$is_sensitive" == "true" && -z "$passphrase" ]]; then
        return "$BACKUP_ERR_PASSPHRASE"
    fi

    # 3. Validar rutas existentes en el equipo local
    local paths_report
    paths_report=$(module_model_check_paths "$mod_id" "$target_home" ${modules_dir:+"$modules_dir"})
    local paths_status=$?

    if [[ $paths_status -ne 0 ]]; then
        return "$BACKUP_ERR_NO_FILES"
    fi

    # Extraer las rutas encontradas
    local existing_rel_paths=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^FOUND= ]]; then
            existing_rel_paths+=("${line#FOUND=}")
        fi
    done <<< "$paths_report"

    [[ ${#existing_rel_paths[@]} -gt 0 ]] || return "$BACKUP_ERR_NO_FILES"

    # 4. Preparar directorios de destino
    local archive_dir="$backup_dir/archives/$mod_id"
    mkdir -p "$archive_dir" "$backup_dir/logs" 2>/dev/null || return "$BACKUP_ERR_CONFIG"

    # Localizar manifiesto anterior antes de crear el actual
    local prev_manifest
    prev_manifest=$(backup_model_find_latest_manifest "$archive_dir")

    # 5. Generar marca de tiempo y nombres de archivo
    local timestamp
    timestamp=$(backup_model_generate_timestamp)

    local ext=".tar.zst"
    [[ "$is_sensitive" == "true" ]] && ext=".tar.zst.gpg"

    local temp_archive="$archive_dir/.tmp_${timestamp}${ext}"
    local final_archive="$archive_dir/${timestamp}${ext}"
    local final_manifest="$archive_dir/${timestamp}.manifest.log"
    local temp_inventory="$archive_dir/.tmp_inv_${timestamp}.txt"

    # 6. Empaquetar y comprimir (con cifrado al vuelo si es sensible)
    if [[ "$is_sensitive" == "true" ]]; then
        if ! tar -I "zstd -${comp_level}" -cf - -C "$target_home" "${existing_rel_paths[@]}" 2>/dev/null | \
             crypto_model_encrypt_pipe "$temp_archive" "$passphrase" "$cipher"; then
            rm -f "$temp_archive" 2>/dev/null
            return "$BACKUP_ERR_ARCHIVE"
        fi
    else
        if ! tar -I "zstd -${comp_level}" -cf "$temp_archive" -C "$target_home" "${existing_rel_paths[@]}" 2>/dev/null; then
            rm -f "$temp_archive" 2>/dev/null
            return "$BACKUP_ERR_ARCHIVE"
        fi
    fi

    # 7. Verificar integridad del archivo temporal antes de consolidar
    if ! backup_model_verify_archive "$temp_archive" "$is_sensitive" "$passphrase"; then
        rm -f "$temp_archive" 2>/dev/null
        return "$BACKUP_ERR_CORRUPT"
    fi

    mv "$temp_archive" "$final_archive" || return "$BACKUP_ERR_ARCHIVE"

    # 8. Generar inventario de archivos respaldados (SHA-256 y tamaño)
    local total_files=0
    local total_bytes=0
    : > "$temp_inventory"

    for rel_path in "${existing_rel_paths[@]}"; do
        local full_src="$target_home/$rel_path"
        if [[ -f "$full_src" ]]; then
            local file_sz file_hash
            file_sz=$(stat -c%s "$full_src" 2>/dev/null || wc -c < "$full_src")
            file_hash=$(crypto_model_compute_sha256 "$full_src")
            echo "$file_hash $file_sz $rel_path" >> "$temp_inventory"
            ((total_files++))
            ((total_bytes += file_sz))
        elif [[ -d "$full_src" ]]; then
            while IFS= read -r -d '' sub_file; do
                local sub_sz sub_hash sub_rel
                sub_sz=$(stat -c%s "$sub_file" 2>/dev/null || wc -c < "$sub_file")
                sub_hash=$(crypto_model_compute_sha256 "$sub_file")
                sub_rel="${sub_file#$target_home/}"
                echo "$sub_hash $sub_sz $sub_rel" >> "$temp_inventory"
                ((total_files++))
                ((total_bytes += sub_sz))
            done < <(find "$full_src" -type f -print0)
        fi
    done

    # 9. Construir y escribir el archivo de manifiesto (.manifest.log)
    local archive_size
    archive_size=$(stat -c%s "$final_archive" 2>/dev/null || wc -c < "$final_archive")

    cat <<EOF > "$final_manifest"
# ==============================================================================
# Backup Manifest: $mod_id
# ==============================================================================
MODULE_ID=$mod_id
MODULE_NAME=$mod_name
TIMESTAMP=$timestamp
DATE=$(date -u +"%Y-%m-%d %H:%M:%SZ")
USER=${USER:-$(whoami)}
HOSTNAME=${HOSTNAME:-$(hostname)}
COMPRESSION=zstd -$comp_level
ENCRYPTED=$is_sensitive
CIPHER=$cipher
ARCHIVE_FILENAME=$(basename "$final_archive")
ARCHIVE_BYTES=$archive_size
TOTAL_FILES=$total_files
TOTAL_UNCOMPRESSED_BYTES=$total_bytes

[INVENTORY]
$(cat "$temp_inventory")

[DIFF]
$(backup_model_compute_diff "$prev_manifest" "$temp_inventory")
EOF

    rm -f "$temp_inventory" 2>/dev/null

    # 10. Registrar en el historial general
    echo "[$timestamp] MODULE=$mod_id STATUS=SUCCESS ARCHIVE=$(basename "$final_archive") BYTES=$archive_size FILES=$total_files ENCRYPTED=$is_sensitive" >> "$backup_dir/logs/backup_history.log"

    # 11. Ejecución de purga segura en origen (Vault & Shred)
    local purged_status="false"
    local should_purge=0

    if [[ "$force_purge" == "true" ]]; then
        should_purge=1
    elif [[ "$purge_after_backup" == "true" && "$no_purge" != "true" ]]; then
        should_purge=1
    fi

    if [[ $should_purge -eq 1 ]]; then
        local shred_fail=0
        for rel_path in "${existing_rel_paths[@]}"; do
            local full_path="$target_home/$rel_path"
            if ! crypto_model_shred_path "$full_path" 3 "true"; then
                shred_fail=1
            fi
        done
        if [[ $shred_fail -eq 0 ]]; then
            purged_status="true"
        else
            purged_status="partial_error"
        fi
    fi

    # 12. Salida estructurada de confirmación
    echo "STATUS=SUCCESS"
    echo "TIMESTAMP=$timestamp"
    echo "MODULE_ID=$mod_id"
    echo "ARCHIVE_FILE=$final_archive"
    echo "MANIFEST_FILE=$final_manifest"
    echo "TOTAL_FILES=$total_files"
    echo "TOTAL_BYTES=$total_bytes"
    echo "ARCHIVE_BYTES=$archive_size"
    echo "IS_SENSITIVE=$is_sensitive"
    echo "PURGED=$purged_status"

    return "$BACKUP_OK"
}
