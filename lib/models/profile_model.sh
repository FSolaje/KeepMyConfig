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
# Función: profile_model_init_default
# Descripción: Asegura la existencia física de profiles/default/profile.conf
#              regenerándolo con valores canónicos si fue eliminado (auto-healing).
# Parámetros:
#   $1 - (Opcional) Directorio de perfiles alternativo
# Retorno:
#   PROFILE_OK en éxito, PROFILE_ERR_IO en fallo.
# ------------------------------------------------------------------------------
profile_model_init_default() {
    local profiles_dir="${1:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"
    local def_dir="$profiles_dir/default"
    local def_conf="$def_dir/profile.conf"

    if [[ ! -f "$def_conf" ]]; then
        mkdir -p "$def_dir" 2>/dev/null || return "$PROFILE_ERR_IO"
        cat <<'EOF' > "$def_conf"
# ==============================================================================
# KeepMyConfig - Perfil Predeterminado (Global)
# ==============================================================================
PROFILE_ID="default"
PROFILE_NAME="Perfil Global / Predeterminado"
PROFILE_DESCRIPTION="Entorno general base compartido por todos los perfiles"
TARGET_SUBDIR=""
DISABLED_MODULES=()
EOF
        chmod 644 "$def_conf" 2>/dev/null || true
    fi

    return "$PROFILE_OK"
}

# ------------------------------------------------------------------------------
# Función: profile_model_get
# Descripción: Parsea y valida los metadatos de un perfil en una subshell aislada.
#              Auto-regenera profiles/default/profile.conf si fue eliminado.
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
        # Auto-healing preventivo si falta en disco
        if [[ ! -f "$def_conf" ]]; then
            profile_model_init_default "$profiles_dir" 2>/dev/null || true
        fi

        if [[ -f "$def_conf" && -r "$def_conf" ]]; then
            (
                unset PROFILE_ID PROFILE_NAME PROFILE_DESCRIPTION TARGET_SUBDIR DISABLED_MODULES
                # shellcheck disable=SC1090
                source "$def_conf" 2>/dev/null || exit "$PROFILE_ERR_SYNTAX"
                echo "ID=${PROFILE_ID:-default}"
                echo "NAME=${PROFILE_NAME:-Perfil Global / Predeterminado}"
                echo "DESCRIPTION=${PROFILE_DESCRIPTION:-Entorno general base compartido por todos los perfiles}"
                echo "TARGET_SUBDIR=${TARGET_SUBDIR:-}"
                local disabled_joined=""
                if [[ "$(declare -p DISABLED_MODULES 2>/dev/null)" =~ "declare -a" ]]; then
                    disabled_joined=$(IFS=,; echo "${DISABLED_MODULES[*]}")
                fi
                echo "DISABLED_MODULES=$disabled_joined"
                exit "$PROFILE_OK"
            )
            return $?
        else
            echo "ID=default"
            echo "NAME=Perfil Global / Predeterminado"
            echo "DESCRIPTION=Entorno general base compartido por todos los perfiles"
            echo "TARGET_SUBDIR="
            echo "DISABLED_MODULES="
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
        unset PROFILE_ID PROFILE_NAME PROFILE_DESCRIPTION TARGET_SUBDIR DISABLED_MODULES
        # shellcheck disable=SC1090
        source "$conf_file" || exit "$PROFILE_ERR_SYNTAX"

        [[ -n "${PROFILE_ID:-}" ]] || PROFILE_ID="$profile_id"
        [[ "$PROFILE_ID" == "$profile_id" ]] || exit "$PROFILE_ERR_INVALID_ID"

        echo "ID=$PROFILE_ID"
        echo "NAME=${PROFILE_NAME:-$profile_id}"
        echo "DESCRIPTION=${PROFILE_DESCRIPTION:-}"
        echo "TARGET_SUBDIR=${TARGET_SUBDIR:-}"
        local disabled_joined=""
        if [[ "$(declare -p DISABLED_MODULES 2>/dev/null)" =~ "declare -a" ]]; then
            disabled_joined=$(IFS=,; echo "${DISABLED_MODULES[*]}")
        fi
        echo "DISABLED_MODULES=$disabled_joined"
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
# Función: profile_model_get_destination
# Descripción: Resuelve el subdirectorio o ruta efectiva de backup para un perfil
#              siguiendo el principio de convención sobre configuración (Zero-Config):
#              - Si perfil es 'default': destino base (o TARGET_SUBDIR si se define)
#              - Si perfil específico:
#                * Si TARGET_SUBDIR está definido: base / TARGET_SUBDIR
#                * Si TARGET_SUBDIR está vacío: base / <profile_id>
# Parámetros:
#   $1 - ID del perfil
#   $2 - (Opcional) BACKUP_DESTINATION base
#   $3 - (Opcional) Directorio de perfiles alternativo
# Salida stdout:
#   Ruta de destino o subdirectorio efectivo
# Retorno:
#   PROFILE_OK en éxito, código de error si el perfil es inválido
# ------------------------------------------------------------------------------
profile_model_get_destination() {
    local profile_id="${1:-}"
    local base_dest="${2:-}"
    local profiles_dir="${3:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"

    local p_info
    p_info=$(profile_model_get "$profile_id" "$profiles_dir") || return "$?"
    local p_sub
    p_sub=$(echo "$p_info" | grep '^TARGET_SUBDIR=' | cut -d'=' -f2-)
    p_sub=$(profile_model_sanitize_target_subdir "$p_sub") || p_sub=""

    local effective_sub=""
    if [[ "$profile_id" == "default" ]]; then
        if [[ -n "$p_sub" && "$p_sub" != "." ]]; then
            effective_sub="$p_sub"
        else
            effective_sub=""
        fi
    else
        if [[ -n "$p_sub" && "$p_sub" != "." ]]; then
            effective_sub="$p_sub"
        else
            effective_sub="$profile_id"
        fi
    fi

    if [[ -n "$base_dest" ]]; then
        local resolved_base
        resolved_base=$(device_model_resolve_destination "$base_dest" 2>/dev/null || echo "$base_dest")
        if [[ -n "$effective_sub" ]]; then
            echo "${resolved_base%/}/$effective_sub"
        else
            echo "${resolved_base%/}"
        fi
    else
        echo "$effective_sub"
    fi

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
# Función: profile_model_get_disabled_modules
# Descripción: Retorna los IDs de módulos globales excluidos para un perfil.
# Parámetros:
#   $1 - ID del perfil
#   $2 - (Opcional) Directorio de perfiles alternativo
# Salida stdout:
#   Lista de IDs excluidos (uno por línea)
# Retorno:
#   PROFILE_OK en éxito.
# ------------------------------------------------------------------------------
profile_model_get_disabled_modules() {
    local profile_id="${1:-}"
    local profiles_dir="${2:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" ]] || return "$PROFILE_ERR_PARAM"
    [[ "$profile_id" == "default" ]] && return "$PROFILE_OK"

    local conf_file="$profiles_dir/$profile_id/profile.conf"
    [[ -f "$conf_file" && -r "$conf_file" ]] || return "$PROFILE_ERR_NOT_FOUND"

    (
        unset DISABLED_MODULES
        # shellcheck disable=SC1090
        source "$conf_file" 2>/dev/null || exit "$PROFILE_ERR_SYNTAX"
        if [[ "$(declare -p DISABLED_MODULES 2>/dev/null)" =~ "declare -a" ]]; then
            for m in "${DISABLED_MODULES[@]}"; do
                [[ -n "$m" ]] && echo "$m"
            done
        fi
        exit "$PROFILE_OK"
    )
}

# ------------------------------------------------------------------------------
# Función interna: _profile_model_save_disabled_modules
# Descripción: Escribe de forma atómica el array DISABLED_MODULES en profile.conf.
# ------------------------------------------------------------------------------
_profile_model_save_disabled_modules() {
    local profile_id="$1"
    local profiles_dir="$2"
    shift 2
    local new_disabled=("$@")

    local conf_file="$profiles_dir/$profile_id/profile.conf"
    [[ -f "$conf_file" && -w "$conf_file" ]] || return "$PROFILE_ERR_IO"

    local meta
    meta=$(profile_model_get "$profile_id" "$profiles_dir") || return "$?"
    local p_name p_desc p_subdir
    p_name=$(echo "$meta" | awk -F'=' '$1 == "NAME" {print $2}')
    p_desc=$(echo "$meta" | awk -F'=' '$1 == "DESCRIPTION" {print $2}')
    p_subdir=$(echo "$meta" | awk -F'=' '$1 == "TARGET_SUBDIR" {print $2}')

    local disabled_formatted=""
    for d in "${new_disabled[@]}"; do
        [[ -n "$d" ]] && disabled_formatted+="\"$d\" "
    done

    local tmp_file
    tmp_file="$(mktemp "${conf_file}.tmp.XXXXXX")" || return "$PROFILE_ERR_IO"

    cat > "$tmp_file" <<EOF
# ==============================================================================
# KeepMyConfig - Configuración del Perfil: $profile_id
# ==============================================================================
PROFILE_ID="$profile_id"
PROFILE_NAME="$p_name"
PROFILE_DESCRIPTION="$p_desc"
TARGET_SUBDIR="$p_subdir"
DISABLED_MODULES=($disabled_formatted)
EOF

    if bash -n "$tmp_file" 2>/dev/null; then
        chmod 644 "$tmp_file" 2>/dev/null || true
        mv "$tmp_file" "$conf_file" || { rm -f "$tmp_file"; return "$PROFILE_ERR_IO"; }
        return "$PROFILE_OK"
    else
        rm -f "$tmp_file"
        return "$PROFILE_ERR_SYNTAX"
    fi
}

# ------------------------------------------------------------------------------
# Función: profile_model_disable_module
# Descripción: Agrega de forma atómica e idempotente un módulo a la lista
#              DISABLED_MODULES del perfil activo.
# Parámetros:
#   $1 - ID del perfil
#   $2 - ID del módulo a desactivar
#   $3 - (Opcional) Directorio de perfiles alternativo
# Retorno:
#   PROFILE_OK en éxito, código de error si el perfil es default o inválido.
# ------------------------------------------------------------------------------
profile_model_disable_module() {
    local profile_id="${1:-}"
    local mod_id="${2:-}"
    local profiles_dir="${3:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" && -n "$mod_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"
    if [[ "$profile_id" == "default" ]]; then
        return "$PROFILE_ERR_CANNOT_DELETE"
    fi

    local current_disabled=()
    local d
    while IFS= read -r d; do
        [[ -n "$d" ]] || continue
        if [[ "$d" == "$mod_id" ]]; then
            return "$PROFILE_OK" # Ya está deshabilitado
        fi
        current_disabled+=("$d")
    done < <(profile_model_get_disabled_modules "$profile_id" "$profiles_dir")

    current_disabled+=("$mod_id")
    _profile_model_save_disabled_modules "$profile_id" "$profiles_dir" "${current_disabled[@]}"
}

# ------------------------------------------------------------------------------
# Función: profile_model_enable_module
# Descripción: Elimina un módulo de la lista DISABLED_MODULES del perfil activo,
#              volviendo a habilitar su herencia del catálogo global.
# Parámetros:
#   $1 - ID del perfil
#   $2 - ID del módulo a habilitar
#   $3 - (Opcional) Directorio de perfiles alternativo
# Retorno:
#   PROFILE_OK en éxito.
# ------------------------------------------------------------------------------
profile_model_enable_module() {
    local profile_id="${1:-}"
    local mod_id="${2:-}"
    local profiles_dir="${3:-${PROFILES_DIR:-$_PROFILE_MODEL_DEFAULT_DIR}}"

    [[ -n "$profile_id" && -n "$mod_id" ]] || return "$PROFILE_ERR_PARAM"
    profile_model_validate_id "$profile_id" || return "$PROFILE_ERR_INVALID_ID"
    if [[ "$profile_id" == "default" ]]; then
        return "$PROFILE_ERR_PARAM"
    fi

    local current_disabled=()
    local found=0
    local d
    while IFS= read -r d; do
        [[ -n "$d" ]] || continue
        if [[ "$d" == "$mod_id" ]]; then
            found=1
            continue
        fi
        current_disabled+=("$d")
    done < <(profile_model_get_disabled_modules "$profile_id" "$profiles_dir")

    if [[ $found -eq 0 ]]; then
        return "$PROFILE_OK" # Ya estaba habilitado
    fi

    _profile_model_save_disabled_modules "$profile_id" "$profiles_dir" "${current_disabled[@]}"
}

# ------------------------------------------------------------------------------
# Función: profile_model_resolve_module
# Descripción: Resuelve la ruta efectiva al fichero .conf de un módulo aplicando la cascada:
#              1. profiles/<perfil>/modules.d/<modulo>.conf (Override o Exclusivo)
#              2. Comprueba si está en DISABLED_MODULES del perfil (si es así, no resuelve)
#              3. modules.d/<modulo>.conf (Global)
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

        # Si el módulo no tiene override local, verificar si está excluido en este perfil
        local disabled_list
        disabled_list=$(profile_model_get_disabled_modules "$active_profile" "$profiles_base" 2>/dev/null)
        while IFS= read -r dis_id; do
            [[ -n "$dis_id" ]] || continue
            if [[ "$dis_id" == "$mod_id" ]]; then
                # Módulo explícitamente excluido en este perfil
                return "$PROFILE_ERR_NOT_FOUND"
            fi
        done <<< "$disabled_list"
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
#              deduplicada de módulos globales no excluidos y módulos específicos del perfil).
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

    # 1. Obtener exclusiones si el perfil activo no es 'default'
    local -A disabled_map=()
    if [[ -n "$active_profile" && "$active_profile" != "default" ]]; then
        local dis_id
        while IFS= read -r dis_id; do
            [[ -n "$dis_id" ]] || continue
            disabled_map["$dis_id"]=1
        done < <(profile_model_get_disabled_modules "$active_profile" "$profiles_base" 2>/dev/null)
    fi

    # 2. Módulos globales (filtrando excluidos)
    if [[ -d "$global_dir" ]]; then
        for f in "$global_dir"/*.conf; do
            [[ -f "$f" ]] || continue
            local mid
            mid="$(basename "$f" .conf)"
            if [[ -z "${disabled_map[$mid]:-}" ]]; then
                modules+=("$mid")
            fi
        done
    fi

    # 3. Módulos específicos del perfil activo
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
