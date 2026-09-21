#!/usr/bin/env bash
# ==============================================================================
# lib/models/profile_model.sh - Modelo MVC para Perfiles de Backup de KeepMyConfig
# ==============================================================================
# Principio MVC: Lógica pura de negocio para gestión de perfiles (CRUD),
# resolución en cascada de módulos (Override/Exclusivos) y vinculación a destinos.
# Sin dependencias interactivas (whiptail/dialog). Comunica vía stdout y $?.
# ==============================================================================

# Códigos de retorno estandarizados
export PROFILE_OK=0
export PROFILE_ERR_PARAM=1
export PROFILE_ERR_NOT_FOUND=2
export PROFILE_ERR_ALREADY_EXISTS=3
export PROFILE_ERR_INVALID_ID=4
export PROFILE_ERR_IO=5
export PROFILE_ERR_SYNTAX=6
export PROFILE_ERR_CANNOT_DELETE=7

# Directorio base de perfiles y configuración por defecto
_PROFILE_MODEL_DEFAULT_DIR="${PROFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/profiles}"
_PROFILE_MODEL_DEFAULT_CONFIG="${CONFIG_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/config.conf}"

# ------------------------------------------------------------------------------
# Función: profile_model_validate_id
# Descripción: Valida que un identificador de perfil sea alfanumérico seguro.
# Parámetros:
#   $1 - Identificador a comprobar
# Retorno:
#   PROFILE_OK si es válido, PROFILE_ERR_INVALID_ID si no lo es.
# ------------------------------------------------------------------------------
profile_model_validate_id() {
    local profile_id="${1:-}"
    if [[ -n "$profile_id" && "$profile_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return "$PROFILE_OK"
    fi
    return "$PROFILE_ERR_INVALID_ID"
}

# ------------------------------------------------------------------------------
# Función: profile_model_list
# Descripción: Lista todos los IDs de perfiles disponibles en disco.
# Parámetros:
#   $1 - (Opcional) Directorio de perfiles alternativo
# Salida stdout:
#   Lista de IDs válidos (uno por línea), siempre incluyendo 'default'
# Retorno:
#   PROFILE_OK
# ------------------------------------------------------------------------------
profile_model_list() {
    local profiles_dir="${1:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"
    local list=()
    local found_default=0

    if [[ -d "$profiles_dir" ]]; then
        for p_dir in "$profiles_dir"/*; do
            [[ -d "$p_dir" ]] || continue
            local p_id
            p_id="$(basename "$p_dir")"
            profile_model_validate_id "$p_id" || continue
            if [[ -f "$p_dir/profile.conf" ]]; then
                list+=("$p_id")
                [[ "$p_id" == "default" ]] && found_default=1
            fi
        done
    fi

    # El perfil 'default' siempre está disponible conceptualmente
    if [[ $found_default -eq 0 ]]; then
        list+=("default")
    fi

    printf "%s\n" "${list[@]}" | sort -u
    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_get
# Descripción: Parsea y valida los metadatos de un perfil en una subshell aislada.
# Parámetros:
#   $1 - ID del perfil
#   $2 - (Opcional) Directorio de perfiles alternativo
# Salida stdout:
#   Definición estructurada CLAVE=VALOR (ID, NAME, DESCRIPTION, TARGET_SUBDIR)
# Retorno:
#   PROFILE_OK si es válido, código de error en caso contrario.
# ------------------------------------------------------------------------------
profile_model_get() {
    local profile_id="${1:-}"
    local profiles_dir="${2:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"

    if [[ "$profile_id" == "default" ]]; then
        local def_conf="$profiles_dir/default/profile.conf"
        if [[ -f "$def_conf" && -r "$def_conf" ]]; then
            (
                unset PROFILE_ID PROFILE_NAME PROFILE_DESCRIPTION TARGET_SUBDIR
                # shellcheck disable=SC1090
                source "$def_conf" 2>/dev/null || exit "$PROFILE_ERR_SYNTAX"
                echo "ID=${PROFILE_ID:-default}"
                echo "NAME=${PROFILE_NAME:-Perfil por Defecto}"
                echo "DESCRIPTION=${PROFILE_DESCRIPTION:-Entorno base global de KeepMyConfig}"
                echo "TARGET_SUBDIR=${TARGET_SUBDIR:-}"
                exit "$PROFILE_OK"
            )
            return $?
        else
            echo "ID=default"
            echo "NAME=Perfil por Defecto"
            echo "DESCRIPTION=Entorno base global de KeepMyConfig"
            echo "TARGET_SUBDIR="
            return "$PROFILE_OK"
        fi
    fi

    local conf_file="$profiles_dir/$profile_id/profile.conf"
    [[ -f "$conf_file" && -r "$conf_file" ]] || return "$PROFILE_ERR_NOT_FOUND"

    # Verificación sintáctica estricta sin ejecutar
    if ! bash -n "$conf_file" >/dev/null 2>&1; then
        return "$PROFILE_ERR_SYNTAX"
    fi

    (
        unset PROFILE_ID PROFILE_NAME PROFILE_DESCRIPTION TARGET_SUBDIR
        # shellcheck disable=SC1090
        source "$conf_file" || exit "$PROFILE_ERR_SYNTAX"

        [[ -n "${PROFILE_ID:-}" ]] || PROFILE_ID="$profile_id"
        [[ "$PROFILE_ID" == "$profile_id" ]] || exit "$PROFILE_ERR_INVALID_ID"

        echo "ID=$PROFILE_ID"
        echo "NAME=${PROFILE_NAME:-$profile_id}"
        echo "DESCRIPTION=${PROFILE_DESCRIPTION:-}"
        echo "TARGET_SUBDIR=${TARGET_SUBDIR:-}"
        exit "$PROFILE_OK"
    )
}

# ------------------------------------------------------------------------------
# Función: profile_model_sanitize_target_subdir
# Descripción: Normaliza y sanea la subcarpeta de destino (TARGET_SUBDIR) de un
#              perfil para que sea siempre una ruta relativa dentro del medio de
#              almacenamiento, eliminando prefijos ($HOME, ~, /home/<user>/),
#              barras iniciales redundantes y bloqueando '..'.
# Parámetros:
#   $1 - Subcarpeta ingresada
# Salida stdout:
#   Subcarpeta relativa limpia (o cadena vacía si apunta a la raíz del volumen)
# Retorno:
#   PROFILE_OK si es válida, PROFILE_ERR_PARAM si contiene '..'
# ------------------------------------------------------------------------------
profile_model_sanitize_target_subdir() {
    local raw_subdir="${1:-}"
    if [[ -z "$raw_subdir" ]]; then
        echo ""
        return "$PROFILE_OK"
    fi

    local clean
    clean="$(echo "$raw_subdir" | xargs 2>/dev/null || echo "$raw_subdir")"
    if [[ -z "$clean" ]]; then
        echo ""
        return "$PROFILE_OK"
    fi

    # Bloquear intentos de navegación hacia directorios superiores (..)
    if [[ "$clean" =~ (^|/)\.\.(/|$) ]]; then
        return "$PROFILE_ERR_PARAM"
    fi

    # Eliminar prefijos de inicio: ${HOME}, $HOME, ~, /home/<usuario>
    clean=$(echo "$clean" | sed -E 's#^(\$\{HOME\}|\$HOME|~|/home/[^/]+)(/.*)?$#\2#')

    # Eliminar barras iniciales
    clean=$(echo "$clean" | sed -E 's#^/+##')

    # Eliminar barras finales
    clean=$(echo "$clean" | sed -E 's#/+$##')

    # Reducir secuencias de múltiples barras internas a una sola
    clean=$(echo "$clean" | sed -E 's#/{2,}#/#g')

    # Si tras limpiar es '.' o queda vacía, significa raíz del volumen
    if [[ "$clean" == "." ]]; then
        clean=""
    fi

    echo "$clean"
    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_create
# Descripción: Crea la estructura de un nuevo perfil en disco con profile.conf y modules.d/.
# Parámetros:
#   $1 - ID del perfil
#   $2 - (Opcional) Nombre amigable
#   $3 - (Opcional) Descripción
#   $4 - (Opcional) Carpeta de destino (TARGET_SUBDIR)
#   $5 - (Opcional) Directorio de perfiles alternativo
# Retorno:
#   PROFILE_OK en éxito, código de error numérico en fallo.
# ------------------------------------------------------------------------------
profile_model_create() {
    local profile_id="${1:-}"
    local name="${2:-}"
    local desc="${3:-}"
    local target_subdir="${4:-}"
    local profiles_dir="${5:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"

    local clean_subdir=""
    if [[ -n "$target_subdir" ]]; then
        clean_subdir=$(profile_model_sanitize_target_subdir "$target_subdir") || return "$PROFILE_ERR_PARAM"
    fi

    local p_dir="$profiles_dir/$profile_id"
    if [[ -d "$p_dir" && -f "$p_dir/profile.conf" ]]; then
        return "$PROFILE_ERR_ALREADY_EXISTS"
    fi

    mkdir -p "$p_dir/modules.d" || return "$PROFILE_ERR_IO"

    local conf_file="$p_dir/profile.conf"
    cat > "$conf_file" <<EOF
# ==============================================================================
# KeepMyConfig - Configuración del Perfil: $profile_id
# ==============================================================================
PROFILE_ID="$profile_id"
PROFILE_NAME="${name:-$profile_id}"
PROFILE_DESCRIPTION="${desc:-}"
TARGET_SUBDIR="${clean_subdir}"
EOF
    chmod 644 "$conf_file" 2>/dev/null || true
    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_delete
# Descripción: Elimina un perfil y sus módulos específicos del disco.
# Parámetros:
#   $1 - ID del perfil a eliminar
#   $2 - (Opcional) Directorio de perfiles alternativo
# Retorno:
#   PROFILE_OK en éxito, PROFILE_ERR_CANNOT_DELETE si es 'default', error si no existe.
# ------------------------------------------------------------------------------
profile_model_delete() {
    local profile_id="${1:-}"
    local profiles_dir="${2:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"

    if [[ "$profile_id" == "default" ]]; then
        return "$PROFILE_ERR_CANNOT_DELETE"
    fi

    local p_dir="$profiles_dir/$profile_id"
    [[ -d "$p_dir" ]] || return "$PROFILE_ERR_NOT_FOUND"

    rm -rf "$p_dir" || return "$PROFILE_ERR_IO"
    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_resolve_module
# Descripción: Resuelve la ruta efectiva al fichero .conf de un módulo aplicando la cascada:
#              1. profiles/<perfil>/modules.d/<modulo>.conf (Override o Exclusivo)
#              2. modules.d/<modulo>.conf (Global)
# Parámetros:
#   $1 - ID del módulo
#   $2 - ID del perfil activo (por defecto: 'default')
#   $3 - (Opcional) Directorio base de la aplicación (CONTROLLER_BASE_DIR)
# Salida stdout:
#   Ruta absoluta al fichero .conf correspondiente
# Retorno:
#   PROFILE_OK si se localizó, PROFILE_ERR_NOT_FOUND si no existe en ningún ámbito.
# ------------------------------------------------------------------------------
profile_model_resolve_module() {
    local mod_id="${1:-}"
    local active_profile="${2:-default}"
    local base_dir="${3:-${CONTROLLER_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)}}"
    local global_dir="${MODULES_DIR:-$base_dir/modules.d}"
    local profiles_base="${PROFILES_DIR:-$base_dir/profiles}"

    [[ -n "$mod_id" ]] || return "$PROFILE_ERR_PARAM"

    # 1. Comprobar si el perfil activo tiene un override o módulo exclusivo
    if [[ -n "$active_profile" && "$active_profile" != "default" ]]; then
        local profile_mod="$profiles_base/$active_profile/modules.d/$mod_id.conf"
        if [[ -f "$profile_mod" && -r "$profile_mod" ]]; then
            echo "$profile_mod"
            return "$PROFILE_OK"
        fi
    fi

    # 2. Comprobar módulo en el catálogo global
    local global_mod="$global_dir/$mod_id.conf"
    if [[ -f "$global_mod" && -r "$global_mod" ]]; then
        echo "$global_mod"
        return "$PROFILE_OK"
    fi

    return "$PROFILE_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: profile_model_list_modules
# Descripción: Lista todos los IDs de módulos visibles para el perfil activo (unión
#              deduplicada de módulos globales y módulos específicos del perfil).
# Parámetros:
#   $1 - ID del perfil activo (por defecto: 'default')
#   $2 - (Opcional) Directorio base de la aplicación
# Salida stdout:
#   Lista de IDs únicos de módulos, uno por línea, ordenados alfabéticamente.
# Retorno:
#   PROFILE_OK
# ------------------------------------------------------------------------------
profile_model_list_modules() {
    local active_profile="${1:-default}"
    local base_dir="${2:-${CONTROLLER_BASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)}}"
    local global_dir="${MODULES_DIR:-$base_dir/modules.d}"
    local profiles_base="${PROFILES_DIR:-$base_dir/profiles}"
    local modules=()

    # 1. Módulos globales
    if [[ -d "$global_dir" ]]; then
        for f in "$global_dir"/*.conf; do
            [[ -f "$f" ]] || continue
            local mid
            mid="$(basename "$f" .conf)"
            modules+=("$mid")
        done
    fi

    # 2. Módulos específicos del perfil activo
    if [[ -n "$active_profile" && "$active_profile" != "default" ]]; then
        local profile_dir="$profiles_base/$active_profile/modules.d"
        if [[ -d "$profile_dir" ]]; then
            for f in "$profile_dir"/*.conf; do
                [[ -f "$f" ]] || continue
                local mid
                mid="$(basename "$f" .conf)"
                modules+=("$mid")
            done
        fi
    fi

    if [[ ${#modules[@]} -eq 0 ]]; then
        return "$PROFILE_OK"
    fi

    printf "%s\n" "${modules[@]}" | sort -u
    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_get_active
# Descripción: Obtiene el perfil activo configurado en config.conf.
# Parámetros:
#   $1 - (Opcional) Ruta al archivo config.conf
# Salida stdout:
#   ID del perfil activo (por defecto 'default')
# Retorno:
#   PROFILE_OK
# ------------------------------------------------------------------------------
profile_model_get_active() {
    local cfg_file="${1:-${CONFIG_FILE:-$_PROFILE_MODEL_DEFAULT_CONFIG}}"
    if [[ -f "$cfg_file" && -r "$cfg_file" ]]; then
        local active
        active=$(grep -E '^[[:space:]]*ACTIVE_PROFILE=' "$cfg_file" | tail -n 1 | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]')
        if [[ -n "$active" ]]; then
            echo "$active"
            return "$PROFILE_OK"
        fi
    fi
    echo "default"
    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_set_active
# Descripción: Guarda de forma atómica el perfil activo en config.conf.
# Parámetros:
#   $1 - ID del perfil a fijar como activo
#   $2 - (Opcional) Ruta al archivo config.conf
# Retorno:
#   PROFILE_OK en éxito, código de error numérico en fallo.
# ------------------------------------------------------------------------------
profile_model_set_active() {
    local profile_id="${1:-}"
    local cfg_file="${2:-${CONFIG_FILE:-$_PROFILE_MODEL_DEFAULT_CONFIG}}"

    [[ -n "$profile_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"
    [[ -f "$cfg_file" && -w "$cfg_file" ]] || return "$PROFILE_ERR_IO"

    local tmp_file
    tmp_file="$(mktemp "${cfg_file}.tmp.XXXXXX")" || return "$PROFILE_ERR_IO"

    if grep -qE '^[[:space:]]*ACTIVE_PROFILE=' "$cfg_file"; then
        sed -E "s|^[[:space:]]*ACTIVE_PROFILE=.*|ACTIVE_PROFILE=\"$profile_id\"|" "$cfg_file" > "$tmp_file"
    else
        cp "$cfg_file" "$tmp_file"
        echo "" >> "$tmp_file"
        echo "# Perfil de backup activo" >> "$tmp_file"
        echo "ACTIVE_PROFILE=\"$profile_id\"" >> "$tmp_file"
    fi

    mv "$tmp_file" "$cfg_file" || { rm -f "$tmp_file"; return "$PROFILE_ERR_IO"; }
    return "$PROFILE_OK"
}
