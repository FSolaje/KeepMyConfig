#!/usr/bin/env bash
# ==============================================================================
# lib/models/module_model.sh - Modelo MVC para Catálogo y Recetas de Backup
# ==============================================================================
# Principio MVC: Lógica pura de negocio para módulos (*.conf) y etiquetas.
# Sin dependencias interactivas (whiptail/dialog). Comunica vía stdout y $?.
# ==============================================================================

# Códigos de retorno estandarizados
export MOD_OK=0
export MOD_ERR_CONFIG=1
export MOD_ERR_NOT_FOUND=2
export MOD_ERR_INVALID_ID=3
export MOD_ERR_SYNTAX=4
export MOD_ERR_MISSING_FIELD=5
export MOD_ERR_ALREADY_EXISTS=6
export MOD_ERR_IO=7

# Resolución del directorio base de módulos por defecto
_MODULE_MODEL_DEFAULT_DIR="${MODULES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../modules.d" 2>/dev/null && pwd)}"
_MODULE_MODEL_DEFAULT_TAGS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../config" 2>/dev/null && pwd)/default_tags.conf"

# ------------------------------------------------------------------------------
# Función: module_model_validate_id
# Descripción: Valida que un identificador cumpla el patrón seguro alfanumérico.
# Parámetros:
#   $1 - Identificador a comprobar
# Retorno:
#   MOD_OK si es válido, MOD_ERR_INVALID_ID si no lo es.
# ------------------------------------------------------------------------------
module_model_validate_id() {
    local mod_id="${1:-}"
    if [[ -n "$mod_id" && "$mod_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return "$MOD_OK"
    fi
    return "$MOD_ERR_INVALID_ID"
}

# ------------------------------------------------------------------------------
# Función: module_model_get
# Descripción: Parsea y valida un módulo en una subshell aislada.
# Parámetros:
#   $1 - ID del módulo (sin extensión .conf)
#   $2 - (Opcional) Directorio de módulos alternativo
# Salida stdout:
#   Definición estructurada CLAVE=VALOR del módulo
# Retorno:
#   0 si es válido, código de error en caso contrario.
# ------------------------------------------------------------------------------
module_model_get() {
    local mod_id="${1:-}"
    local modules_dir="${2:-${MODULES_DIR:-$_MODULE_MODEL_DEFAULT_DIR}}"

    [[ -n "$mod_id" ]] || return "$MOD_ERR_CONFIG"
    module_model_validate_id "$mod_id" || return "$MOD_ERR_INVALID_ID"

    local conf_file="$modules_dir/$mod_id.conf"
    [[ -f "$conf_file" && -r "$conf_file" ]] || return "$MOD_ERR_NOT_FOUND"

    # Verificación sintáctica estricta sin ejecutar
    if ! bash -n "$conf_file" >/dev/null 2>&1; then
        return "$MOD_ERR_SYNTAX"
    fi

    # Carga segura y validación de tipos en subshell aislada
    (
        unset MODULE_ID MODULE_NAME MODULE_TAGS MODULE_PATHS IS_SENSITIVE PURGE_AFTER_BACKUP POST_RESTORE_HOOK
        # shellcheck disable=SC1090
        source "$conf_file" || exit "$MOD_ERR_SYNTAX"

        # Validación de campos obligatorios
        [[ -n "${MODULE_ID:-}" ]] || exit "$MOD_ERR_MISSING_FIELD"
        [[ "$MODULE_ID" == "$mod_id" ]] || exit "$MOD_ERR_INVALID_ID"
        [[ -n "${MODULE_NAME:-}" ]] || exit "$MOD_ERR_MISSING_FIELD"

        # Comprobar que MODULE_TAGS es un array no vacío
        if [[ ! "$(declare -p MODULE_TAGS 2>/dev/null)" =~ "declare -a" ]] || [[ ${#MODULE_TAGS[@]} -eq 0 ]]; then
            exit "$MOD_ERR_MISSING_FIELD"
        fi

        # Comprobar que MODULE_PATHS es un array no vacío
        if [[ ! "$(declare -p MODULE_PATHS 2>/dev/null)" =~ "declare -a" ]] || [[ ${#MODULE_PATHS[@]} -eq 0 ]]; then
            exit "$MOD_ERR_MISSING_FIELD"
        fi

        # Comprobar booleanos
        [[ "${IS_SENSITIVE:-}" =~ ^(true|false)$ ]] || exit "$MOD_ERR_MISSING_FIELD"
        [[ "${PURGE_AFTER_BACKUP:-}" =~ ^(true|false)$ ]] || exit "$MOD_ERR_MISSING_FIELD"

        local tags_joined
        tags_joined=$(IFS=,; echo "${MODULE_TAGS[*]}")

        local paths_joined
        paths_joined=$(IFS='|'; echo "${MODULE_PATHS[*]}")

        echo "ID=$MODULE_ID"
        echo "NAME=$MODULE_NAME"
        echo "TAGS=$tags_joined"
        echo "PATHS=$paths_joined"
        echo "IS_SENSITIVE=$IS_SENSITIVE"
        echo "PURGE_AFTER_BACKUP=$PURGE_AFTER_BACKUP"
        echo "POST_RESTORE_HOOK=${POST_RESTORE_HOOK:-}"
        exit "$MOD_OK"
    )
}

# ------------------------------------------------------------------------------
# Función: module_model_list
# Descripción: Lista todos los IDs de módulos válidos disponibles.
# Parámetros:
#   $1 - (Opcional) Directorio de módulos alternativo
# Salida stdout:
#   Lista de IDs válidos (uno por línea)
# Retorno:
#   MOD_OK (incluso si la lista está vacía)
# ------------------------------------------------------------------------------
module_model_list() {
    local modules_dir="${1:-${MODULES_DIR:-$_MODULE_MODEL_DEFAULT_DIR}}"
    [[ -d "$modules_dir" ]] || return "$MOD_ERR_NOT_FOUND"

    local conf_file mod_id
    for conf_file in "$modules_dir"/*.conf; do
        [[ -f "$conf_file" ]] || continue
        mod_id="$(basename "$conf_file" .conf)"
        if module_model_get "$mod_id" "$modules_dir" >/dev/null 2>&1; then
            echo "$mod_id"
        fi
    done
    return "$MOD_OK"
}

# ------------------------------------------------------------------------------
# Función: module_model_filter_by_tag
# Descripción: Filtra módulos asociados a una etiqueta concreta.
# Parámetros:
#   $1 - Etiqueta a buscar (ej: dev, sensitive)
#   $2 - (Opcional) Directorio de módulos alternativo
# Salida stdout:
#   Lista de IDs de módulos que contienen la etiqueta
# Retorno:
#   0 si se encuentran módulos, 1 si ninguno coincide.
# ------------------------------------------------------------------------------
module_model_filter_by_tag() {
    local target_tag="${1:-}"
    local modules_dir="${2:-${MODULES_DIR:-$_MODULE_MODEL_DEFAULT_DIR}}"

    [[ -n "$target_tag" ]] || return "$MOD_ERR_CONFIG"

    local mod_id tags_str found=0
    while IFS= read -r mod_id; do
        [[ -n "$mod_id" ]] || continue
        tags_str=$(module_model_get "$mod_id" "$modules_dir" 2>/dev/null | awk -F'=' '$1 == "TAGS" {print $2}')
        IFS=',' read -r -a tags_arr <<< "$tags_str"
        for t in "${tags_arr[@]}"; do
            if [[ "$t" == "$target_tag" ]]; then
                echo "$mod_id"
                found=1
                break
            fi
        done
    done < <(module_model_list "$modules_dir")

    [[ $found -eq 1 ]] && return "$MOD_OK"
    return "$MOD_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: module_model_filter_by_sensitivity
# Descripción: Retorna módulos según el flag IS_SENSITIVE.
# Parámetros:
#   $1 - true o false
#   $2 - (Opcional) Directorio de módulos alternativo
# Salida stdout:
#   Lista de IDs de módulos coincidentes
# Retorno:
#   0 si se encuentra al menos uno, 1 si no.
# ------------------------------------------------------------------------------
module_model_filter_by_sensitivity() {
    local target_sens="${1:-}"
    local modules_dir="${2:-${MODULES_DIR:-$_MODULE_MODEL_DEFAULT_DIR}}"

    [[ "$target_sens" =~ ^(true|false)$ ]] || return "$MOD_ERR_CONFIG"

    local mod_id is_sens found=0
    while IFS= read -r mod_id; do
        [[ -n "$mod_id" ]] || continue
        is_sens=$(module_model_get "$mod_id" "$modules_dir" 2>/dev/null | awk -F'=' '$1 == "IS_SENSITIVE" {print $2}')
        if [[ "$is_sens" == "$target_sens" ]]; then
            echo "$mod_id"
            found=1
        fi
    done < <(module_model_list "$modules_dir")

    [[ $found -eq 1 ]] && return "$MOD_OK"
    return "$MOD_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: module_model_check_paths
# Descripción: Verifica la presencia de las rutas configuradas en un directorio base.
# Parámetros:
#   $1 - ID del módulo
#   $2 - (Opcional) Directorio base de usuario (por defecto $HOME)
#   $3 - (Opcional) Directorio de módulos
# Salida stdout:
#   Líneas FOUND=<ruta_relativa> o MISSING=<ruta_relativa>
# Retorno:
#   0 si existe al menos una ruta, 1 si no existe ninguna.
# ------------------------------------------------------------------------------
module_model_check_paths() {
    local mod_id="${1:-}"
    local target_home="${2:-${HOME}}"
    local modules_dir="${3:-$_MODULE_MODEL_DEFAULT_DIR}"

    [[ -n "$mod_id" ]] || return "$MOD_ERR_CONFIG"

    local paths_str
    paths_str=$(module_model_get "$mod_id" "$modules_dir" 2>/dev/null | awk -F'=' '$1 == "PATHS" {print $2}')
    [[ -n "$paths_str" ]] || return "$MOD_ERR_NOT_FOUND"

    local found_any=0
    IFS='|' read -r -a paths_arr <<< "$paths_str"
    for rel_path in "${paths_arr[@]}"; do
        local full_path="$target_home/$rel_path"
        if [[ -e "$full_path" ]]; then
            echo "FOUND=$rel_path"
            found_any=1
        else
            echo "MISSING=$rel_path"
        fi
    done

    [[ $found_any -eq 1 ]] && return "$MOD_OK"
    return "$MOD_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: module_model_save
# Descripción: Crea o sobrescribe un archivo .conf de módulo de forma atómica.
# Parámetros:
#   $1 - ID del módulo
#   $2 - Nombre descriptivo
#   $3 - Lista de etiquetas separadas por comas (ej: "dev,editor")
#   $4 - Lista de rutas separadas por pipes o comas (ej: ".config/Code/User/settings.json|.bashrc")
#   $5 - IS_SENSITIVE (true/false)
#   $6 - PURGE_AFTER_BACKUP (true/false)
#   $7 - POST_RESTORE_HOOK (comando opcional)
#   $8 - (Opcional) Directorio de módulos
# Retorno:
#   0 en éxito, código de error si parámetros inválidos o fallo de I/O.
# ------------------------------------------------------------------------------
module_model_save() {
    local mod_id="${1:-}"
    local name="${2:-}"
    local tags_str="${3:-}"
    local paths_str="${4:-}"
    local is_sensitive="${5:-false}"
    local purge_after="${6:-false}"
    local hook="${7:-}"
    local modules_dir="${8:-$_MODULE_MODEL_DEFAULT_DIR}"

    module_model_validate_id "$mod_id" || return "$MOD_ERR_INVALID_ID"
    [[ -n "$name" ]] || return "$MOD_ERR_CONFIG"
    [[ -n "$tags_str" ]] || return "$MOD_ERR_CONFIG"
    [[ -n "$paths_str" ]] || return "$MOD_ERR_CONFIG"
    [[ "$is_sensitive" =~ ^(true|false)$ ]] || return "$MOD_ERR_CONFIG"
    [[ "$purge_after" =~ ^(true|false)$ ]] || return "$MOD_ERR_CONFIG"

    mkdir -p "$modules_dir" 2>/dev/null || return "$MOD_ERR_IO"

    # Procesar etiquetas en formato array bash
    local tags_formatted=""
    IFS=',' read -r -a tags_arr <<< "$tags_str"
    for t in "${tags_arr[@]}"; do
        t=$(echo "$t" | xargs) # Limpiar espacios
        [[ -n "$t" ]] && tags_formatted+="\"$t\" "
    done

    # Procesar rutas (soportando separador pipe '|' o comas)
    local paths_formatted=""
    local delim='|'
    [[ "$paths_str" =~ \| ]] || delim=','
    IFS="$delim" read -r -a paths_raw <<< "$paths_str"
    for p in "${paths_raw[@]}"; do
        p=$(echo "$p" | xargs)
        [[ -n "$p" ]] && paths_formatted+="    \"$p\""$'\n'
    done

    local target_file="$modules_dir/$mod_id.conf"
    local temp_file="$modules_dir/.tmp_${mod_id}_$$"

    cat <<EOF > "$temp_file"
# ==============================================================================
# Receta de Backup: $name
# ==============================================================================

MODULE_ID="$mod_id"
MODULE_NAME="$name"
MODULE_TAGS=($tags_formatted)

MODULE_PATHS=(
$paths_formatted)

IS_SENSITIVE=$is_sensitive
PURGE_AFTER_BACKUP=$purge_after
POST_RESTORE_HOOK="$hook"
EOF

    # Validar sintaxis del archivo temporal antes de consolidarlo
    if bash -n "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$target_file" || return "$MOD_ERR_IO"
        return "$MOD_OK"
    else
        rm -f "$temp_file" 2>/dev/null
        return "$MOD_ERR_SYNTAX"
    fi
}

# ------------------------------------------------------------------------------
# Función: module_model_delete
# Descripción: Elimina una receta de módulo existente.
# Parámetros:
#   $1 - ID del módulo a eliminar
#   $2 - (Opcional) Directorio de módulos
# Retorno:
#   0 si se eliminó con éxito, código de error si no existía.
# ------------------------------------------------------------------------------
module_model_delete() {
    local mod_id="${1:-}"
    local modules_dir="${2:-$_MODULE_MODEL_DEFAULT_DIR}"

    [[ -n "$mod_id" ]] || return "$MOD_ERR_CONFIG"
    module_model_validate_id "$mod_id" || return "$MOD_ERR_INVALID_ID"

    local target_file="$modules_dir/$mod_id.conf"
    if [[ -f "$target_file" ]]; then
        rm -f "$target_file" || return "$MOD_ERR_IO"
        return "$MOD_OK"
    fi
    return "$MOD_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: module_model_get_all_tags
# Descripción: Retorna la lista única de etiquetas combinando catálogo y módulos.
# Parámetros:
#   $1 - (Opcional) Directorio de módulos
#   $2 - (Opcional) Archivo de catálogo default_tags.conf
# Salida stdout:
#   Lista ordenada de etiquetas únicas (una por línea)
# Retorno:
#   0 siempre.
# ------------------------------------------------------------------------------
module_model_get_all_tags() {
    local modules_dir="${1:-$_MODULE_MODEL_DEFAULT_DIR}"
    local tags_file="${2:-$_MODULE_MODEL_DEFAULT_TAGS}"

    local all_tags=()

    # 1. Leer del catálogo global
    if [[ -f "$tags_file" ]]; then
        while IFS=':' read -r tag_id _; do
            # Ignorar comentarios y líneas vacías
            [[ "$tag_id" =~ ^[[:space:]]*# || -z "$tag_id" ]] && continue
            tag_id=$(echo "$tag_id" | xargs)
            [[ -n "$tag_id" ]] && all_tags+=("$tag_id")
        done < "$tags_file"
    fi

    # 2. Leer de todos los módulos activos
    local mod_id tags_str
    while IFS= read -r mod_id; do
        [[ -n "$mod_id" ]] || continue
        tags_str=$(module_model_get "$mod_id" "$modules_dir" 2>/dev/null | awk -F'=' '$1 == "TAGS" {print $2}')
        IFS=',' read -r -a mod_tags <<< "$tags_str"
        for t in "${mod_tags[@]}"; do
            t=$(echo "$t" | xargs)
            [[ -n "$t" ]] && all_tags+=("$t")
        done
    done < <(module_model_list "$modules_dir" 2>/dev/null)

    # Ordenar y deduplicar
    if [[ ${#all_tags[@]} -gt 0 ]]; then
        printf "%s\n" "${all_tags[@]}" | sort -u
    fi
    return "$MOD_OK"
}

# ------------------------------------------------------------------------------
# Función: module_model_add_tag_to_catalog
# Descripción: Agrega una nueva etiqueta al catálogo si no existía.
# Parámetros:
#   $1 - ID de la etiqueta (alfanumérico)
#   $2 - Descripción descriptiva
#   $3 - (Opcional) Archivo default_tags.conf
# Retorno:
#   0 en éxito, código de error si inválida.
# ------------------------------------------------------------------------------
module_model_add_tag_to_catalog() {
    local tag_id="${1:-}"
    local desc="${2:-}"
    local tags_file="${3:-$_MODULE_MODEL_DEFAULT_TAGS}"

    module_model_validate_id "$tag_id" || return "$MOD_ERR_INVALID_ID"
    [[ -n "$desc" ]] || desc="Etiqueta personalizada"

    mkdir -p "$(dirname "$tags_file")" 2>/dev/null || return "$MOD_ERR_IO"
    touch "$tags_file" 2>/dev/null || return "$MOD_ERR_IO"

    # Verificar si ya existe en el archivo
    if grep -qs "^${tag_id}:" "$tags_file"; then
        return "$MOD_OK" # Ya existía
    fi

    echo "${tag_id}:${desc}" >> "$tags_file" || return "$MOD_ERR_IO"
    return "$MOD_OK"
}
