#!/usr/bin/env bash
# ==============================================================================
# Archivo: lib/controllers/app_controller.sh
# Descripción: Controlador principal y orquestador MVC de KeepMyConfig.
# ==============================================================================

# Variables de entorno y contexto
CONTROLLER_BASE_DIR=""
CONTROLLER_INITIALIZED=0
TARGET_SUBDIR_OVERRIDE=""
ACTIVE_PROFILE_OVERRIDE=""
CONTROLLER_CONFIG_FILE=""
IS_SANDBOX_MODE="false"

_controller_get_config_file() {
    echo "${CONTROLLER_CONFIG_FILE:-${CONTROLLER_BASE_DIR}/config/config.conf}"
}

_controller_get_active_profile() {
    if [[ -n "$ACTIVE_PROFILE_OVERRIDE" ]]; then
        echo "$ACTIVE_PROFILE_OVERRIDE"
    else
        profile_model_get_active "$(_controller_get_config_file)"
    fi
}

_controller_get_module_dir() {
    local mod_id="$1"
    local act_prof
    act_prof=$(_controller_get_active_profile)
    local resolved_path
    if resolved_path=$(profile_model_resolve_module "$mod_id" "$act_prof" "$CONTROLLER_BASE_DIR" 2>/dev/null); then
        dirname "$resolved_path"
    else
        echo "${MODULES_DIR:-${CONTROLLER_BASE_DIR}/modules.d}"
    fi
}

_controller_get_module_info() {
    local mod_id="$1"
    local mod_dir
    mod_dir=$(_controller_get_module_dir "$mod_id")
    module_model_get "$mod_id" "$mod_dir"
}

_controller_list_modules() {
    local act_prof
    act_prof=$(_controller_get_active_profile)
    profile_model_list_modules "$act_prof" "$CONTROLLER_BASE_DIR"
}

# Inicialización del entorno, configuración, modelos y vistas
controller_init() {
    if (( CONTROLLER_INITIALIZED == 1 )); then
        return 0
    fi

    local base_dir="${1:-}"

    if [[ -z "$base_dir" ]]; then
        base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    CONTROLLER_BASE_DIR="$base_dir"

    # Verificar testigo de la aplicación
    if [[ ! -f "${CONTROLLER_BASE_DIR}/.backup_app_marker" ]]; then
        echo "[ERROR] No se encuentra el archivo marcador .backup_app_marker en ${CONTROLLER_BASE_DIR}" >&2
        return 1
    fi

    # Cargar configuraciones globales
    local cfg_file
    cfg_file=$(_controller_get_config_file)
    if [[ -f "$cfg_file" ]]; then
        # shellcheck disable=SC1090
        source "$cfg_file"
    fi

    # Cargar modelos
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/models/device_model.sh"
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/models/profile_model.sh"
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/models/module_model.sh"
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/models/crypto_model.sh"
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/models/backup_model.sh"
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/models/restore_model.sh"

    # Cargar vistas
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/views/whiptail_view.sh"
    # shellcheck disable=SC1091
    source "${CONTROLLER_BASE_DIR}/lib/views/ansi_view.sh"

    # Asegurar rutas por defecto si no vienen fijadas
    TARGET_USER_HOME="${TARGET_USER_HOME:-$HOME}"
    MODULES_DIR="${MODULES_DIR:-${CONTROLLER_BASE_DIR}/modules.d}"
    PROFILES_DIR="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}"
    TEMPLATES_DIR="${TEMPLATES_DIR:-${CONTROLLER_BASE_DIR}/templates.d}"

    CONTROLLER_INITIALIZED=1
    return 0
}

# ==============================================================================
# Modo Sandbox y Entorno Aislado de Pruebas (--test-mode / --clean-sandbox)
# ==============================================================================

# Inicializar fixtures y archivos de prueba en el home virtual de sandbox
_sandbox_seed_virtual_home() {
    local target_home="$1"
    local base_dir="${2:-${CONTROLLER_BASE_DIR:-}}"

    mkdir -p "$target_home"

    if [[ -d "${base_dir}/tests/fixtures/sandbox_home" ]]; then
        cp -r "${base_dir}/tests/fixtures/sandbox_home/." "$target_home/"
    else
        # Fallback de inicialización reproducible si la carpeta fixtures no está disponible
        mkdir -p "$target_home/.ssh" \
                 "$target_home/.config/Code/User/snippets" \
                 "$target_home/.config/Code/User/globalStorage" \
                 "$target_home/.config/Code/User/sync" \
                 "$target_home/.config/git" \
                 "$target_home/.config/JetBrains/IdeaIC2024.1/options" \
                 "$target_home/.config/libreoffice/4/user" \
                 "$target_home/.mozilla/firefox/testprofile.default" \
                 "$target_home/.thunderbird/testprofile.default"

        echo 'export EDITOR="nano"' > "$target_home/.bashrc"
        echo 'alias gs="git status"' > "$target_home/.bash_aliases"
        echo 'export PATH="$HOME/bin:$PATH"' > "$target_home/.profile"
        echo 'clear' > "$target_home/.bash_logout"
        echo 'mock-ssh-key' > "$target_home/.ssh/id_rsa"
        echo 'mock-ssh-pub' > "$target_home/.ssh/id_rsa.pub"
        echo '{"editor.fontSize": 14}' > "$target_home/.config/Code/User/settings.json"
        echo '[]' > "$target_home/.config/Code/User/keybindings.json"
        echo '{"version": 1}' > "$target_home/.config/Code/User/sync/sync_state.json"
        echo '[user]' > "$target_home/.gitconfig"
    fi

    # Asegurar permisos seguros para claves privadas y directorios sensibles
    chmod 700 "$target_home/.ssh" 2>/dev/null || true
    chmod 600 "$target_home/.ssh/id_rsa" 2>/dev/null || true
    chmod 600 "$target_home/.ssh/id_ed25519" 2>/dev/null || true

    return 0
}

controller_enable_sandbox_mode() {
    IS_SANDBOX_MODE="true"
    local base_dir="${CONTROLLER_BASE_DIR:-}"
    if [[ -z "$base_dir" ]]; then
        base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        CONTROLLER_BASE_DIR="$base_dir"
    fi

    # Asegurar inicialización base del controlador y vistas
    controller_init "$base_dir"

    local sandbox_base="${base_dir}/user_data/sandbox"

    # 1. Crear estructura de carpetas aislada
    mkdir -p "$sandbox_base/config" \
             "$sandbox_base/modules.d" \
             "$sandbox_base/profiles/default" \
             "$sandbox_base/storage/archives" \
             "$sandbox_base/storage/logs" \
             "$sandbox_base/home"

    # 2. Desplegar Home Virtual de Pruebas con datos semilla
    if [[ ! -f "${sandbox_base}/home/.bashrc" ]]; then
        _sandbox_seed_virtual_home "${sandbox_base}/home" "$base_dir"
    fi

    # 3. Desplegar config/config.conf confinado en sandbox
    if [[ ! -f "${sandbox_base}/config/config.conf" ]]; then
        if [[ -f "${base_dir}/config/config.conf" ]]; then
            sed -e "s|^BACKUP_DESTINATION=.*|BACKUP_DESTINATION=\"${sandbox_base}/storage\"|" \
                -e 's|^INITIAL_SETUP_DONE=.*|INITIAL_SETUP_DONE="true"|' \
                -e 's|^ACTIVE_PROFILE=.*|ACTIVE_PROFILE="default"|' \
                -e "s|^TARGET_USER_HOME=.*|TARGET_USER_HOME=\"${sandbox_base}/home\"|" \
                "${base_dir}/config/config.conf" > "${sandbox_base}/config/config.conf"
        else
            cat <<EOF > "${sandbox_base}/config/config.conf"
INITIAL_SETUP_DONE="true"
REMEMBER_LAST_PROFILE="true"
ACTIVE_PROFILE="default"
TARGET_USER_HOME="${sandbox_base}/home"
BACKUP_DESTINATION="${sandbox_base}/storage"
APP_MARKER_FILE=".backup_app_marker"
STORAGE_MARKER_FILE=".backup_storage_marker"
COMPRESSION_ALGO="zstd"
COMPRESSION_LEVEL="3"
GPG_CIPHER="AES256"
SHRED_ITERATIONS=3
SHRED_ZERO_PASS=true
EOF
        fi
    fi

    # 4. Desplegar marcador de seguridad en storage del sandbox
    if [[ ! -f "${sandbox_base}/storage/.backup_storage_marker" ]]; then
        if [[ -f "${base_dir}/markers/.backup_storage_marker" ]]; then
            cp "${base_dir}/markers/.backup_storage_marker" "${sandbox_base}/storage/.backup_storage_marker"
        else
            touch "${sandbox_base}/storage/.backup_storage_marker"
        fi
    fi

    # 5. Desplegar perfil default canónico
    if [[ ! -f "${sandbox_base}/profiles/default/profile.conf" ]]; then
        if [[ -f "${base_dir}/profiles/default/profile.conf" ]]; then
            cp "${base_dir}/profiles/default/profile.conf" "${sandbox_base}/profiles/default/profile.conf"
        else
            cat <<'EOF' > "${sandbox_base}/profiles/default/profile.conf"
# ==============================================================================
# KeepMyConfig - Perfil Predeterminado (Sandbox)
# ==============================================================================
PROFILE_ID="default"
PROFILE_NAME="Perfil Global / Predeterminado"
PROFILE_DESCRIPTION="Entorno general base de pruebas"
TARGET_SUBDIR=""
DISABLED_MODULES=()
EOF
        fi
    fi

    # 6. Redirigir variables operativas hacia el entorno sandbox
    TARGET_USER_HOME="${sandbox_base}/home"
    CONTROLLER_CONFIG_FILE="${sandbox_base}/config/config.conf"
    export TARGET_USER_HOME
    export MODULES_DIR="${sandbox_base}/modules.d"
    export PROFILES_DIR="${sandbox_base}/profiles"
    export TEMPLATES_DIR="${base_dir}/templates.d"
    export CONTROLLER_CONFIG_FILE
    export IS_SANDBOX_MODE

    # 7. Recargar la configuración para reflejar variables del sandbox
    if [[ -f "$CONTROLLER_CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONTROLLER_CONFIG_FILE"
    fi

    return 0
}

controller_clean_sandbox() {
    local base_dir="${CONTROLLER_BASE_DIR:-}"
    if [[ -z "$base_dir" ]]; then
        base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        CONTROLLER_BASE_DIR="$base_dir"
    fi

    controller_init "$base_dir"

    local sandbox_base="${base_dir}/user_data/sandbox"
    if [[ -d "$sandbox_base" ]]; then
        rm -rf "$sandbox_base"
        ansi_view_success "Entorno de pruebas sandbox purgado correctamente (${sandbox_base})."
    else
        ansi_view_info "El entorno sandbox no existe o ya está limpio (${sandbox_base})."
    fi
    return 0
}

# Obtener y validar el punto de montaje y subcarpeta de backup en el SSD
_controller_get_backup_dir() {
    local val_out=""
    local status=0
    local effective_subdir="${TARGET_SUBDIR_OVERRIDE:-}"

    if [[ -z "$effective_subdir" ]]; then
        local act_prof
        act_prof=$(_controller_get_active_profile)
        effective_subdir=$(profile_model_get_destination "$act_prof" "" "${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}" 2>/dev/null || true)
    fi

    val_out=$(device_model_validate_storage "$(_controller_get_config_file)" "$effective_subdir") || status=$?
    if (( status != 0 )); then
        return "$status"
    fi
    local bdir
    bdir=$(echo "$val_out" | grep '^BACKUP_DIR=' | cut -d'=' -f2-)
    echo "$bdir"
    return 0
}

# Advertencia interactiva de seguridad post-backup si quedaron ficheros sensibles sin purgar
_controller_check_sensitive_purge_warning() {
    local module_id="$1"
    local is_tui="$2"

    local mod_info
    mod_info=$(module_model_get "$module_id") || return 0
    local is_sensitive="false"
    local purge_after="false"
    local mod_name="$module_id"

    while IFS='=' read -r key val; do
        case "$key" in
            IS_SENSITIVE) is_sensitive="$val" ;;
            PURGE_AFTER_BACKUP) purge_after="$val" ;;
            NAME) mod_name="$val" ;;
        esac
    done <<< "$mod_info"

    if [[ "$is_sensitive" == "true" && "$purge_after" == "false" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            local paths_raw
            paths_raw=$(echo "$mod_info" | grep '^PATHS=' | cut -d'=' -f2- || true)
            local paths=()
            IFS='|' read -r -a paths <<< "$paths_raw"
            local full_paths_txt=""
            for p in "${paths[@]}"; do
                [[ -n "$p" ]] || continue
                full_paths_txt+="  • ${TARGET_USER_HOME}/${p}\n"
            done

            local warn_msg="AVISO DE SEGURIDAD:\n\nEl módulo sensible '${mod_name}' se ha respaldado con éxito en el destino,\npero sus ficheros originales aún permanecen en el equipo local:\n\n${full_paths_txt}\n¿Desea destruirlos de forma segura con 'shred -u' ahora?"
            if whiptail_view_yesno "Seguridad y Privacidad" "$warn_msg"; then
                # Usuario aceptó purgar de forma interactiva
                local shredded_txt=""
                for p in "${paths[@]}"; do
                    [[ -n "$p" ]] || continue
                    crypto_model_shred_path "${TARGET_USER_HOME}/${p}" 3 &>/dev/null || true
                    shredded_txt+="  • ${TARGET_USER_HOME}/${p} [DESTRUIDO]\n"
                done
                whiptail_view_msgbox "Purga Segura Completada" "Rutas locales destruidas con shred -u (3 pasadas + sobrescritura cero):\n\n${shredded_txt}"
            fi
        else
            ansi_view_warning "AVISO DE SEGURIDAD: El módulo sensible '${mod_name}' fue respaldado, pero sus ficheros originales continúan presentes en el equipo local."
        fi
    fi
}

# ==============================================================================
# Manejadores de Casos de Uso (Handlers)
# ==============================================================================

# 1. Respaldo Completo (Todos los módulos)
controller_handle_backup_all() {
    local is_tui="${1:-false}"
    local purge_override="${2:-auto}"

    # Verificar módulos activos en el perfil
    local active_mods=()
    local m
    while IFS= read -r m; do
        [[ -n "$m" ]] && active_mods+=("$m")
    done < <(_controller_list_modules)

    if [[ ${#active_mods[@]} -eq 0 ]]; then
        local act_prof
        act_prof=$(_controller_get_active_profile)
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_msgbox "Sin Módulos Activos" "No hay módulos configurados para respaldar en el perfil '$act_prof'.\n\nPuede activar recetas estándar desde la biblioteca de plantillas en la opción '7) Administrar Módulos y Etiquetas'."
        else
            ansi_view_info "No hay módulos configurados para respaldar en el perfil '$act_prof'. Active módulos desde la biblioteca de plantillas con '--list-templates' y '--enable-template <id>'."
        fi
        return 0
    fi

    local backup_dir=""
    local ret=0

    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el destino de backup o falta el archivo marcador .backup_storage_marker."
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error de Almacenamiento" "$err_txt"
        else
            ansi_view_error "$err_txt"
        fi
        return 2
    fi

    # Verificar si hay módulos sensibles en el perfil activo
    local has_sensitive="false"
    for m in "${active_mods[@]}"; do
        local minfo
        minfo=$(_controller_get_module_info "$m") || continue
        if echo "$minfo" | grep -q 'IS_SENSITIVE=true'; then
            has_sensitive="true"
            break
        fi
    done

    local passphrase=""
    if [[ "$has_sensitive" == "true" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            passphrase=$(whiptail_view_password_confirm "Cifrado de Módulos Sensibles" "Introduzca la contraseña GPG AES-256 para proteger sus datos:") || return 0
            [[ -z "$passphrase" ]] && return 0
        else
            if [[ -z "${PASSPHRASE:-}" ]]; then
                passphrase=$(ansi_view_password "Introduzca la contraseña GPG para cifrar módulos sensibles")
            else
                passphrase="$PASSPHRASE"
            fi
        fi
    fi

    if [[ "$is_tui" == "false" ]]; then
        ansi_view_header "INICIANDO RESPALDO COMPLETO"
        ansi_view_info "Destino del respaldo: $backup_dir"
        ansi_view_info "Perfil activo: $(_controller_get_active_profile)"
    fi

    local act_prof
    act_prof=$(_controller_get_active_profile)
    local report=""

    if [[ "$act_prof" == "default" ]]; then
        report=$(backup_model_run_all "$backup_dir" "$TARGET_USER_HOME" "$passphrase" "$purge_override")
        ret=$?
    else
        local total_err=0
        local force_p="false"
        local no_p="false"
        [[ "$purge_override" == "true" ]] && force_p="true"
        [[ "$purge_override" == "false" ]] && no_p="true"
        for m in $(_controller_list_modules); do
            local m_dir
            m_dir=$(_controller_get_module_dir "$m")
            local m_out
            local m_ret=0
            m_out=$(backup_model_run "$m" "$backup_dir" "$TARGET_USER_HOME" "$passphrase" "$force_p" "$no_p" "$m_dir") || m_ret=$?
            report+="$m_out"$'\n'
            (( m_ret != 0 )) && ((total_err++))
        done
        (( total_err == 0 )) && ret=0 || ret=1
    fi

    # Analizar purga post-backup en módulos sensibles
    for m in $(_controller_list_modules); do
        _controller_check_sensitive_purge_warning "$m" "$is_tui"
    done

    if [[ "$is_tui" == "true" ]]; then
        local summary_msg="El proceso de respaldo completo ha concluido.\n\n"
        summary_msg+="• Perfil Activo: $act_prof\n"
        summary_msg+="• Directorio Destino: $backup_dir\n"
        summary_msg+="• Home de Origen: $TARGET_USER_HOME\n\n"
        summary_msg+="Detalle de los módulos respaldados:\n$report"
        whiptail_view_msgbox "Respaldo Completo Finalizado" "$summary_msg"
    else
        echo "$report"
        ansi_view_success "Proceso de respaldo global completado."
    fi

    return "$ret"
}

# 2. Respaldo por Etiqueta
controller_handle_backup_tag() {
    local tag="${1:-}"
    local is_tui="${2:-false}"
    local purge_override="${3:-auto}"

    if [[ -z "$tag" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            local all_tags
            all_tags=$(module_model_get_all_tags) || true
            local tag_items=()
            for t in $all_tags; do
                tag_items+=("$t" "Etiqueta: $t" "OFF")
            done
            tag=$(whiptail_view_radiolist "Seleccionar Etiqueta" "Elija la etiqueta a respaldar:" "${tag_items[@]}") || return 0
            [[ -z "$tag" ]] && return 0
        else
            ansi_view_error "Debe especificar una etiqueta para respaldar."
            return 5
        fi
    fi

    local backup_dir=""
    local ret=0
    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el SSD externo de backup o falta el marcador de seguridad."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Disco No Disponible" "$err_txt" || ansi_view_error "$err_txt"
        return 2
    fi

    # Identificar módulos de la etiqueta dentro del perfil activo
    local tag_mods=()
    local has_sensitive="false"
    for m in $(_controller_list_modules); do
        local minfo
        minfo=$(_controller_get_module_info "$m") || continue
        local tags_str
        tags_str=$(echo "$minfo" | grep '^TAGS=' | cut -d'=' -f2-)
        IFS=',' read -r -a t_arr <<< "$tags_str"
        for t in "${t_arr[@]}"; do
            if [[ "$t" == "$tag" ]]; then
                tag_mods+=("$m")
                if echo "$minfo" | grep -q 'IS_SENSITIVE=true'; then
                    has_sensitive="true"
                fi
                break
            fi
        done
    done

    if [[ ${#tag_mods[@]} -eq 0 ]]; then
        local err_txt="No se encontraron módulos asociados a la etiqueta '$tag' en el perfil activo."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Etiqueta Vacía" "$err_txt" || ansi_view_error "$err_txt"
        return 2
    fi

    local passphrase=""
    if [[ "$has_sensitive" == "true" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            passphrase=$(whiptail_view_password_confirm "Cifrado GPG" "La etiqueta '$tag' contiene módulos sensibles. Introduzca contraseña:") || return 0
            [[ -z "$passphrase" ]] && return 0
        else
            passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la contraseña GPG para módulos sensibles")}"
        fi
    fi

    local act_prof
    act_prof=$(_controller_get_active_profile)
    local report=""

    if [[ "$act_prof" == "default" ]]; then
        report=$(backup_model_run_by_tag "$tag" "$backup_dir" "$TARGET_USER_HOME" "$passphrase" "$purge_override")
        ret=$?
    else
        local total_err=0
        local force_p="false"
        local no_p="false"
        [[ "$purge_override" == "true" ]] && force_p="true"
        [[ "$purge_override" == "false" ]] && no_p="true"
        for m in "${tag_mods[@]}"; do
            local m_dir
            m_dir=$(_controller_get_module_dir "$m")
            local m_out
            local m_ret=0
            m_out=$(backup_model_run "$m" "$backup_dir" "$TARGET_USER_HOME" "$passphrase" "$force_p" "$no_p" "$m_dir") || m_ret=$?
            report+="$m_out"$'\n'
            (( m_ret != 0 )) && ((total_err++))
        done
        (( total_err == 0 )) && ret=0 || ret=1
    fi

    for m in "${tag_mods[@]}"; do
        _controller_check_sensitive_purge_warning "$m" "$is_tui"
    done

    if [[ "$is_tui" == "true" ]]; then
        local summary_msg="Respaldo de la etiqueta '$tag' finalizado.\n\n"
        summary_msg+="• Perfil Activo: $act_prof\n"
        summary_msg+="• Directorio Destino: $backup_dir\n"
        summary_msg+="• Home de Origen: $TARGET_USER_HOME\n\n"
        summary_msg+="Detalle de los módulos respaldados:\n$report"
        whiptail_view_msgbox "Respaldo por Etiqueta" "$summary_msg"
    else
        echo "$report"
        ansi_view_success "Respaldo de etiqueta '$tag' concluido."
    fi

    return "$ret"
}

# 3. Respaldo Individual de Módulo
controller_handle_backup_module() {
    local module_id="${1:-}"
    local is_tui="${2:-false}"
    local purge_override="${3:-auto}"

    if [[ -z "$module_id" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            local all_mods
            all_mods=$(_controller_list_modules) || true
            local mod_items=()
            for m in $all_mods; do
                local minfo
                minfo=$(_controller_get_module_info "$m") || continue
                local mname
                mname=$(echo "$minfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$m")
                mod_items+=("$m" "$mname" "OFF")
            done
            module_id=$(whiptail_view_radiolist "Seleccionar Módulo" "Elija el módulo individual a respaldar:" "${mod_items[@]}") || return 0
            [[ -z "$module_id" ]] && return 0
        else
            ansi_view_error "Debe especificar el identificador del módulo."
            return 5
        fi
    fi

    local backup_dir=""
    local ret=0
    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el SSD externo de backup o falta el marcador de seguridad."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Disco No Disponible" "$err_txt" || ansi_view_error "$err_txt"
        return 2
    fi

    local minfo
    minfo=$(_controller_get_module_info "$module_id") || {
        local err_txt="El módulo '$module_id' no existe o está corrupto."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Módulo Inválido" "$err_txt" || ansi_view_error "$err_txt"
        return 3
    }

    local passphrase=""
    if echo "$minfo" | grep -q 'IS_SENSITIVE=true'; then
        if [[ "$is_tui" == "true" ]]; then
            passphrase=$(whiptail_view_password_confirm "Cifrado GPG" "Módulo sensible. Introduzca la contraseña GPG AES-256:") || return 0
            [[ -z "$passphrase" ]] && return 0
        else
            passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la contraseña GPG para cifrar '$module_id'")}"
        fi
    fi

    local force_purge="false"
    local no_purge="false"
    if [[ "$purge_override" == "true" ]]; then
        force_purge="true"
    elif [[ "$purge_override" == "false" ]]; then
        no_purge="true"
    fi

    local m_dir
    m_dir=$(_controller_get_module_dir "$module_id")
    local report
    report=$(backup_model_run "$module_id" "$backup_dir" "$TARGET_USER_HOME" "$passphrase" "$force_purge" "$no_purge" "$m_dir")
    ret=$?

    _controller_check_sensitive_purge_warning "$module_id" "$is_tui"

    if [[ "$is_tui" == "true" ]]; then
        local archive_file=""
        local is_purged=""
        archive_file=$(echo "$report" | grep '^ARCHIVE_FILE=' | cut -d'=' -f2-)
        is_purged=$(echo "$report" | grep '^PURGED=' | cut -d'=' -f2-)

        local paths_raw
        paths_raw=$(echo "$minfo" | grep '^PATHS=' | cut -d'=' -f2- || true)
        local paths=()
        IFS='|' read -r -a paths <<< "$paths_raw"
        local full_sources=""
        for p in "${paths[@]}"; do
            [[ -n "$p" ]] || continue
            full_sources+="  • ${TARGET_USER_HOME}/${p}\n"
        done

        local summary_msg="Respaldo del módulo '$module_id' concluido con éxito.\n\n"
        summary_msg+="• Origen (Home Local):\n${full_sources}\n"
        if [[ -n "$archive_file" ]]; then
            summary_msg+="• Archivo de Destino:\n  $archive_file\n\n"
        else
            summary_msg+="• Directorio Destino:\n  ${backup_dir}/archives/${module_id}\n\n"
        fi
        if [[ "$is_purged" == "true" ]]; then
            summary_msg+="• Purga Segura (Vault & Shred):\n  Ficheros locales destruidos con shred -u.\n\n"
        fi
        summary_msg+="Detalle técnico de la operación:\n$report"
        whiptail_view_msgbox "Respaldo de Módulo Concluido" "$summary_msg"
    else
        echo "$report"
        ansi_view_success "Respaldo de '$module_id' completado."
    fi

    return "$ret"
}

# 4. Restauración Exprés de Datos Sensibles
controller_handle_restore_sensitive() {
    local is_tui="${1:-false}"

    local backup_dir=""
    local ret=0
    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el SSD externo de backup o falta el marcador de seguridad."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Disco No Disponible" "$err_txt" || ansi_view_error "$err_txt"
        return 2
    fi

    local passphrase=""
    if [[ "$is_tui" == "true" ]]; then
        passphrase=$(whiptail_view_password "Restauración Exprés Sensible" "Introduzca la contraseña GPG para descifrar todos sus datos sensibles:") || return 0
        [[ -z "$passphrase" ]] && return 0
    else
        passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la contraseña GPG para restaurar datos sensibles")}"
    fi

    local report
    report=$(restore_model_restore_sensitive_all "$backup_dir" "$TARGET_USER_HOME" "$passphrase")
    ret=$?

    if [[ "$is_tui" == "true" ]]; then
        local summary_msg="Restauración de Módulos Protegidos Concluida.\n\n"
        summary_msg+="• Directorio Fuente: ${backup_dir}/archives\n"
        summary_msg+="• Home Destino Restituido: $TARGET_USER_HOME\n\n"
        summary_msg+="Detalle de los módulos procesados:\n$report"
        whiptail_view_msgbox "Restauración Exprés Sensible" "$summary_msg"
    else
        echo "$report"
        ansi_view_success "Restauración de módulos protegidos completada."
    fi

    return "$ret"
}

# 5. Restauración Selectiva por Módulo e Histórico
controller_handle_restore_module() {
    local module_id="${1:-}"
    local timestamp="${2:-}"
    local is_tui="${3:-false}"

    local backup_dir=""
    local ret=0
    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el SSD externo de backup o falta el marcador de seguridad."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Disco No Disponible" "$err_txt" || ansi_view_error "$err_txt"
        return 2
    fi

    if [[ -z "$module_id" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            local all_mods
            all_mods=$(_controller_list_modules) || true
            local mod_items=()
            for m in $all_mods; do
                local minfo
                minfo=$(_controller_get_module_info "$m") || continue
                local mname
                mname=$(echo "$minfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$m")
                mod_items+=("$m" "$mname" "OFF")
            done
            module_id=$(whiptail_view_radiolist "Seleccionar Módulo" "Elija el módulo a restaurar:" "${mod_items[@]}") || return 0
            [[ -z "$module_id" ]] && return 0
        else
            ansi_view_error "Debe especificar el identificador del módulo a restaurar."
            return 5
        fi
    fi

    # Seleccionar timestamp si estamos en TUI y no se especificó
    if [[ -z "$timestamp" && "$is_tui" == "true" ]]; then
        local history
        history=$(backup_model_list_history "$module_id" "$backup_dir") || true
        if [[ -z "$history" ]]; then
            whiptail_view_error "Sin Histórico" "No se encontraron respaldos archivados para el módulo '$module_id'."
            return 3
        fi

        local ts_items=()
        for ts in $history; do
            ts_items+=("$ts" "Respaldo: $ts")
        done
        timestamp=$(whiptail_view_menu "Histórico de Respaldos" "Seleccione la versión a restaurar:" "${ts_items[@]}") || return 0
        [[ -z "$timestamp" ]] && return 0
    fi

    local m_dir
    m_dir=$(_controller_get_module_dir "$module_id")

    # Resolver si el archivo está cifrado
    local arch_info
    arch_info=$(restore_model_find_archive "$module_id" "$backup_dir" "$timestamp" "$m_dir") || {
        local err_txt="No se localizó el archivo de respaldo para '$module_id' en la fecha seleccionada."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Archivo Faltante" "$err_txt" || ansi_view_error "$err_txt"
        return 3
    }

    local is_enc="false"
    while IFS='=' read -r k v; do
        [[ "$k" == "IS_ENCRYPTED" ]] && is_enc="$v"
    done <<< "$arch_info"

    local passphrase=""
    if [[ "$is_enc" == "true" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            passphrase=$(whiptail_view_password "Módulo Cifrado" "Introduzca la clave GPG para descifrar '$module_id':") || return 0
            [[ -z "$passphrase" ]] && return 0
        else
            passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la clave GPG para descifrar '$module_id'")}"
        fi
    fi

    local report
    report=$(restore_model_restore_module "$module_id" "$backup_dir" "$TARGET_USER_HOME" "$timestamp" "$passphrase" "$m_dir")
    ret=$?

    if [[ "$is_tui" == "true" ]]; then
        local archive_file=""
        archive_file=$(echo "$report" | grep '^ARCHIVE_FILE=' | cut -d'=' -f2-)
        local minfo
        minfo=$(_controller_get_module_info "$module_id" 2>/dev/null || true)
        local paths_raw
        paths_raw=$(echo "$minfo" | grep '^PATHS=' | cut -d'=' -f2- || true)
        local paths=()
        IFS='|' read -r -a paths <<< "$paths_raw"
        local full_targets=""
        for p in "${paths[@]}"; do
            [[ -n "$p" ]] || continue
            full_targets+="  • ${TARGET_USER_HOME}/${p}\n"
        done

        local summary_msg="Restauración del módulo '$module_id' concluida con éxito.\n\n"
        if [[ -n "$archive_file" ]]; then
            summary_msg+="• Archivo Fuente Restaurado:\n  $archive_file\n\n"
        fi
        summary_msg+="• Destino Restituido (Home Local):\n${full_targets}\n"
        summary_msg+="Detalle técnico de la operación:\n$report"

        whiptail_view_msgbox "Restauración Concluida" "$summary_msg"
    else
        echo "$report"
        ansi_view_success "Restauración de '$module_id' finalizada con éxito."
    fi

    return "$ret"
}

# 6. Restauración Total
controller_handle_restore_all() {
    local is_tui="${1:-false}"

    local backup_dir=""
    local ret=0
    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el SSD externo de backup o falta el marcador de seguridad."
        [[ "$is_tui" == "true" ]] && whiptail_view_error "Disco No Disponible" "$err_txt" || ansi_view_error "$err_txt"
        return 2
    fi

    if [[ "$is_tui" == "true" ]]; then
        if ! whiptail_view_yesno "Restauración Total" "¿Está seguro de que desea restaurar TODOS los módulos respaldados en el SSD a su sistema local?"; then
            return 0
        fi
    fi

    local passphrase=""
    # Comprobar si hay módulos sensibles en el SSD
    local sens_mods
    sens_mods=$(module_model_filter_by_sensitivity "true") || true
    if [[ -n "$sens_mods" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            passphrase=$(whiptail_view_password "Clave Requerida" "Existen módulos cifrados. Introduzca la clave GPG global:") || return 0
            [[ -z "$passphrase" ]] && return 0
        else
            passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la clave GPG para módulos protegidos")}"
        fi
    fi

    local report
    report=$(restore_model_restore_all "$backup_dir" "$TARGET_USER_HOME" "$passphrase")
    ret=$?

    if [[ "$is_tui" == "true" ]]; then
        local summary_msg="Restauración Total Finalizada.\n\n"
        summary_msg+="• Directorio Fuente: ${backup_dir}/archives\n"
        summary_msg+="• Home Destino Restituido: $TARGET_USER_HOME\n\n"
        summary_msg+="Detalle de los módulos procesados:\n$report"
        whiptail_view_msgbox "Restauración Total Finalizada" "$summary_msg"
    else
        echo "$report"
        ansi_view_success "Restauración total completada."
    fi

    return "$ret"
}

# Diagnóstico detallado del almacenamiento (TUI y CLI)
_controller_show_device_diagnostics() {
    local is_tui="${1:-false}"
    local val_out=""
    local ret=0
    val_out=$(device_model_validate_storage "$(_controller_get_config_file)" "${TARGET_SUBDIR_OVERRIDE:-}") || ret=$?

    local status="UNKNOWN"
    local mount_point=""
    local backup_dir=""
    local marker_path=""
    local space_avail=""
    local space_total=""

    while IFS='=' read -r k v; do
        case "$k" in
            STATUS) status="$v" ;;
            MOUNTPOINT) mount_point="$v" ;;
            BACKUP_DIR) backup_dir="$v" ;;
            MARKER_PATH) marker_path="$v" ;;
            SPACE_AVAILABLE) space_avail="$v" ;;
            SPACE_TOTAL) space_total="$v" ;;
        esac
    done <<< "$val_out"

    # Si no se obtuvieron por clave directa, extraer de tokens espaciados (SPACE_FREE_HUMAN / SPACE_TOTAL_KB)
    if [[ -z "$space_avail" || -z "$space_total" ]]; then
        for token in $val_out; do
            case "$token" in
                SPACE_FREE_HUMAN=*)
                    [[ -z "$space_avail" ]] && space_avail="${token#*=}"
                    ;;
                SPACE_TOTAL_KB=*)
                    if [[ -z "$space_total" ]]; then
                        local tkb="${token#*=}"
                        if [[ "$tkb" =~ ^[0-9]+$ ]] && (( tkb > 0 )); then
                            local tgb=$(( tkb / 1024 / 1024 ))
                            space_total="${tgb}G"
                        fi
                    fi
                    ;;
            esac
        done
    fi
    space_avail="${space_avail:-Desconocido}"
    space_total="${space_total:-Desconocido}"

    local bdest="${BACKUP_DESTINATION:-~/Backups/KeepMyConfig}"

    if [[ "$is_tui" == "true" ]]; then
        local diag_txt="ESTADO DEL DISPOSITIVO / ALMACENAMIENTO:\n\n"
        diag_txt+="• Estado Global    : $status\n"
        diag_txt+="• Destino Config   : $bdest\n"
        diag_txt+="• Punto de Montaje : ${mount_point:-No encontrado}\n"
        diag_txt+="• Directorio Backup: ${backup_dir:-N/A}\n"
        diag_txt+="• Marcador Destino : ${marker_path:-FALTA .backup_storage_marker}\n"
        diag_txt+="• Espacio Libre    : ${space_avail} de ${space_total}\n"
        diag_txt+="• Home a Respaldar : $TARGET_USER_HOME"

        if (( ret == 0 )); then
            whiptail_view_msgbox "Diagnóstico de Almacenamiento" "$diag_txt"
        else
            whiptail_view_error "Alerta de Almacenamiento" "$diag_txt"
        fi
    else
        ansi_view_header "DIAGNÓSTICO DEL ALMACENAMIENTO DE BACKUP"
        ansi_view_key_value "ESTADO GLOBAL" "$status"
        ansi_view_key_value "DESTINO CONFIG" "$bdest"
        ansi_view_key_value "PUNTO DE MONTAJE" "${mount_point:-No detectado}"
        ansi_view_key_value "DIRECTORIO BACKUP" "${backup_dir:-N/A}"
        ansi_view_key_value "MARCADOR SEGURIDAD" "${marker_path:-FALTA .backup_storage_marker}"
        ansi_view_key_value "ESPACIO DISPONIBLE" "${space_avail} de ${space_total}"
        ansi_view_key_value "USUARIO DESTINO" "$TARGET_USER_HOME"
    fi

    return "$ret"
}

# Desplegar marcador de seguridad y estructura en el destino de backup
controller_handle_deploy_marker() {
    local target_dir="${1:-}"
    local is_tui="${2:-false}"
    local base_dir="${CONTROLLER_BASE_DIR:-}"

    if [[ -z "$target_dir" ]]; then
        local cfg_file="$(_controller_get_config_file)"
        # shellcheck disable=SC1090
        source "$cfg_file" 2>/dev/null || true
        target_dir=$(device_model_resolve_destination "${BACKUP_DESTINATION:-~/Backups/KeepMyConfig}")
    else
        target_dir=$(device_model_resolve_destination "$target_dir")
    fi

    local marker_src="${base_dir}/markers/.backup_storage_marker"
    if [[ ! -f "$marker_src" ]]; then
        local alt_marker
        alt_marker=$(find "$base_dir" -maxdepth 3 -name ".backup_storage_marker" 2>/dev/null | head -n 1)
        [[ -n "$alt_marker" && -f "$alt_marker" ]] && marker_src="$alt_marker"
    fi

    if mkdir -p "$target_dir/archives" "$target_dir/logs" 2>/dev/null && \
       cp -f "$marker_src" "$target_dir/.backup_storage_marker" 2>/dev/null; then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_msgbox "Marcador Desplegado" "Estructura y marcador .backup_storage_marker desplegados con éxito en:\n\n$target_dir"
        else
            ansi_view_success "Estructura y marcador desplegados con éxito en: $target_dir"
        fi
        return 0
    else
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error de Permisos" "No se pudo desplegar el marcador en '$target_dir'. Compruebe permisos de escritura."
        else
            ansi_view_error "No se pudo desplegar el marcador en '$target_dir'. Compruebe permisos de escritura."
        fi
        return 1
    fi
}

# Inicialización de Destino de Almacenamiento (compatibilidad CLI)
controller_handle_init_target() {
    local subdir="${1:-}"
    local set_default="${2:-false}"
    local is_tui="${3:-false}"

    if [[ "$is_tui" == "true" && -z "$subdir" ]]; then
        local def_sub="Backups/$(hostname)"
        subdir=$(whiptail_view_input "Inicializar Destino de Backup" \
            "Introduzca la ruta relativa de la subcarpeta para este equipo:" "$def_sub") || return 0
        [[ -z "$subdir" ]] && return 0

        if whiptail_view_yesno "Destino Predeterminado" "¿Desea establecer '$subdir' como la carpeta activa en config.conf?"; then
            set_default="true"
        fi
    fi

    local clean_sub
    clean_sub=$(device_model_sanitize_subdir "$subdir") || clean_sub=""
    subdir="$clean_sub"
    if [[ -z "$subdir" ]]; then
        ansi_view_error "Debe especificar una subcarpeta válida a inicializar (ej: --init-target Backups/Personal_PC)."
        return 1
    fi

    local storage_root=""
    if [[ -n "${STORAGE_ID_TYPE:-}" ]]; then
        storage_root=$(device_model_find_mount "${STORAGE_ID_TYPE}" "${STORAGE_ID_VALUE:-DISCO_BACKUP}" "${STORAGE_STATIC_FALLBACK:-}") || true
    fi
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        storage_root=$(device_model_resolve_destination "${BACKUP_DESTINATION:-~/Backups/KeepMyConfig}")
    fi
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        local err_msg="No se pudo localizar el almacenamiento configurado."
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Almacenamiento No Detectado" "$err_msg"
        else
            ansi_view_error "$err_msg"
        fi
        return "$DEV_ERR_NOT_FOUND"
    fi

    local marker_tmpl="${CONTROLLER_BASE_DIR}/markers/.backup_storage_marker"
    local init_res
    local ret=0
    init_res=$(device_model_init_target_directory "$storage_root" "$subdir" "$marker_tmpl") || ret=$?

    if (( ret == 0 )); then
        if [[ "$set_default" == "true" ]]; then
            device_model_update_config_subdir "$(_controller_get_config_file)" "$subdir"
            STORAGE_SUBDIR="$subdir"
        fi

        if [[ "$is_tui" == "true" ]]; then
            local msg="Carpeta de destino inicializada correctamente en:\n$init_res\n\nMarcador de seguridad y estructura listos."
            [[ "$set_default" == "true" ]] && msg+="\n\nEstablecida como carpeta activa (STORAGE_SUBDIR=\"$subdir\")."
            whiptail_view_msgbox "Destino Inicializado" "$msg"
        else
            ansi_view_success "Destino inicializado correctamente en: $init_res"
            [[ "$set_default" == "true" ]] && ansi_view_info "Configuración actualizada: STORAGE_SUBDIR=\"$subdir\""
        fi
        return 0
    else
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error de Inicialización" "No se pudo inicializar la carpeta '$subdir' en '$storage_root' (código: $ret)."
        else
            ansi_view_error "Fallo al inicializar '$subdir' en '$storage_root' (código: $ret)."
        fi
        return "$ret"
    fi
}

# Listado de Destinos Disponibles en el Almacenamiento
controller_handle_list_targets() {
    local is_tui="${1:-false}"

    local storage_root=""
    if [[ -n "${STORAGE_ID_TYPE:-}" ]]; then
        storage_root=$(device_model_find_mount "${STORAGE_ID_TYPE}" "${STORAGE_ID_VALUE:-DISCO_BACKUP}" "${STORAGE_STATIC_FALLBACK:-}") || true
    fi
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        storage_root=$(device_model_resolve_destination "${BACKUP_DESTINATION:-~/Backups/KeepMyConfig}")
    fi
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        local err_msg="No se pudo localizar el almacenamiento configurado."
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Almacenamiento No Detectado" "$err_msg"
        else
            ansi_view_error "$err_msg"
        fi
        return "$DEV_ERR_NOT_FOUND"
    fi

    local targets
    local ret=0
    targets=$(device_model_list_targets "$storage_root") || ret=$?

    if (( ret != 0 )) || [[ -z "$targets" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_msgbox "Destinos de Backup" "No se encontraron carpetas con marcador de seguridad en '$storage_root'."
        else
            ansi_view_warning "No se encontraron subdirectorios con marcador .backup_storage_marker en '$storage_root'."
        fi
        return 0
    fi

    if [[ "$is_tui" == "true" ]]; then
        local list_txt="Carpetas de backup detectadas en el almacenamiento:\n\n"
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            if [[ "$t" == "${STORAGE_SUBDIR:-}" ]]; then
                list_txt+=" • $t  [ACTIVO]\n"
            else
                list_txt+=" • $t\n"
            fi
        done <<< "$targets"
        whiptail_view_msgbox "Destinos de Backup" "$list_txt"
    else
        ansi_view_header "DESTINOS DE BACKUP DETECTADOS EN EL ALMACENAMIENTO"
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            if [[ "$t" == "${STORAGE_SUBDIR:-}" ]]; then
                echo -e "  \033[1;32m• $t [ACTIVO]\033[0m"
            else
                echo "  • $t"
            fi
        done <<< "$targets"
    fi
    return 0
}

# Conmutar Carpeta de Destino Activa en config.conf
controller_handle_set_active_target() {
    local target="${1:-}"
    local is_tui="${2:-false}"

    local storage_root=""
    if [[ -n "${STORAGE_ID_TYPE:-}" ]]; then
        storage_root=$(device_model_find_mount "${STORAGE_ID_TYPE}" "${STORAGE_ID_VALUE:-DISCO_BACKUP}" "${STORAGE_STATIC_FALLBACK:-}") || true
    fi
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        storage_root=$(device_model_resolve_destination "${BACKUP_DESTINATION:-~/Backups/KeepMyConfig}")
    fi

    if [[ "$is_tui" == "true" && -z "$target" ]]; then
        if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
            whiptail_view_error "Error" "No se detectó el soporte de almacenamiento para listar destinos."
            return "$DEV_ERR_NOT_FOUND"
        fi

        local targets
        targets=$(device_model_list_targets "$storage_root") || true
        if [[ -z "$targets" ]]; then
            whiptail_view_error "Destinos" "No se encontraron carpetas con marcador en el almacenamiento."
            return 1
        fi

        local t_items=()
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            local st="OFF"
            [[ "$t" == "${STORAGE_SUBDIR:-}" ]] && st="ON"
            t_items+=("$t" "Destino: $t" "$st")
        done <<< "$targets"

        target=$(whiptail_view_radiolist "Seleccionar Carpeta Activa" "Elija la carpeta de backup predeterminada:" "${t_items[@]}") || return 0
        [[ -z "$target" ]] && return 0
    fi

    if [[ -z "$target" ]]; then
        ansi_view_error "Debe especificar la subcarpeta a activar (ej: --set-active-target Backups/Personal_PC)."
        return 1
    fi

    # Verificar que el marcador exista en la ruta seleccionada si el soporte está accesible
    if [[ -n "$storage_root" && -d "$storage_root" ]]; then
        local check_path="$storage_root"
        [[ "$target" != "." && -n "$target" ]] && check_path="$storage_root/$target"
        if ! device_model_check_marker "$check_path" >/dev/null 2>&1; then
            local warn_txt="Aviso: La ruta '$check_path' no contiene el marcador .backup_storage_marker."
            if [[ "$is_tui" == "true" ]]; then
                if ! whiptail_view_yesno "Aviso de Marcador" "$warn_txt\n\n¿Desea establecerla como activa igualmente?"; then
                    return 1
                fi
            else
                ansi_view_warning "$warn_txt"
            fi
        fi
    fi

    device_model_update_config_subdir "$(_controller_get_config_file)" "$target"
    STORAGE_SUBDIR="$target"

    if [[ "$is_tui" == "true" ]]; then
        whiptail_view_msgbox "Configuración Actualizada" "La carpeta activa de backup se ha establecido en:\n$target"
    else
        ansi_view_success "Carpeta de backup activa actualizada en config.conf: STORAGE_SUBDIR=\"$target\""
    fi
    return 0
}

# Asistente interactivo de primera ejecución / onboarding
controller_handle_onboarding_wizard() {
    local is_tui="${1:-true}"
    local cfg_file="$(_controller_get_config_file)"

    if [[ "$is_tui" == "true" ]]; then
        local welcome_msg="¡Bienvenido a KeepMyConfig!\n\n"
        welcome_msg+="Un gestor modular de copias de seguridad y recuperación para Lliurex 25 / Ubuntu 24.04.\n\n"
        welcome_msg+="• 100% libre de privilegios 'root': opera con los permisos de su usuario.\n"
        welcome_msg+="• Cifrado robusto GPG AES-256 para módulos sensibles y purga segura con shred.\n"
        welcome_msg+="• Compatible con unidades USB/SSD extraíbles y carpetas locales.\n\n"
        welcome_msg+="A continuación configuraremos el destino de almacenamiento de sus copias de seguridad."
        whiptail_view_msgbox "Bienvenido a KeepMyConfig" "$welcome_msg" || return 1

        local detected
        detected=$(device_model_detect_external_drives 2>/dev/null || true)
        local menu_items=()
        menu_items+=("1" "Carpeta Local: ~/Backups/KeepMyConfig (Predeterminado)")

        local opt_idx=2
        local -a opt_paths=()
        opt_paths[1]="~/Backups/KeepMyConfig"

        while IFS='|' read -r lbl mnt free; do
            [[ -n "$lbl" && -n "$mnt" ]] || continue
            menu_items+=("$opt_idx" "Disco Externo: $lbl ($free libres) en $mnt")
            opt_paths["$opt_idx"]="$mnt/Backups/KeepMyConfig"
            ((opt_idx++))
        done <<< "$detected"

        menu_items+=("$opt_idx" "Ruta Personalizada (Ingresar ruta manual)")
        local manual_idx="$opt_idx"

        local sel
        sel=$(whiptail_view_menu "Configuración Inicial - Destino de Backup" "Seleccione dónde desea almacenar sus copias de seguridad:" "${menu_items[@]}") || return 1

        local chosen_dest=""
        if [[ "$sel" == "$manual_idx" ]]; then
            chosen_dest=$(whiptail_view_input "Ruta Personalizada de Backup" "Ingrese la ruta del directorio para las copias (ej: ~/Backups o /media/...):" "~/Backups/KeepMyConfig") || return 1
        else
            chosen_dest="${opt_paths[$sel]:-~/Backups/KeepMyConfig}"
        fi
        [[ -n "$chosen_dest" ]] || chosen_dest="~/Backups/KeepMyConfig"

        local resolved_dest
        resolved_dest=$(device_model_resolve_destination "$chosen_dest") || resolved_dest="$HOME/Backups/KeepMyConfig"
        mkdir -p "$resolved_dest" 2>/dev/null || true
        device_model_init_storage_marker "$resolved_dest" "${CONTROLLER_BASE_DIR}/markers/.backup_storage_marker" 2>/dev/null || true
        device_model_update_config_destination "$cfg_file" "$chosen_dest" 2>/dev/null || true

        local remember_pref="true"
        if whiptail_view_yesno "Preferencia de Perfil al Iniciar" "¿Desea que KeepMyConfig recuerde el último perfil utilizado en cada sesión?\n\n• Sí: Conserva el último perfil activo al volver a abrir la aplicación.\n• No: Inicia siempre en el perfil predeterminado 'default' (Recomendado para equipos compartidos o de aula)."; then
            remember_pref="true"
        else
            remember_pref="false"
        fi

        sed -i "s|^REMEMBER_LAST_PROFILE=.*|REMEMBER_LAST_PROFILE=\"$remember_pref\"|" "$cfg_file" 2>/dev/null || true
        sed -i "s|^INITIAL_SETUP_DONE=.*|INITIAL_SETUP_DONE=\"true\"|" "$cfg_file" 2>/dev/null || true

        whiptail_view_msgbox "Configuración Completada" "¡Configuración inicial completada con éxito!\n\n• Destino configurado: $chosen_dest\n• Ruta física resuelta: $resolved_dest\n• Marcador de seguridad: Desplegado y verificado.\n• Recordar último perfil: $remember_pref\n\nPresione Aceptar para continuar."
        return 0
    else
        ansi_view_header "ASISTENTE DE CONFIGURACIÓN INICIAL (CLI)"
        echo "KeepMyConfig requiere definir la ruta de destino para sus copias de seguridad."
        echo ""
        echo "Opciones detectadas:"
        echo "  [1] Carpeta Local: ~/Backups/KeepMyConfig (Predeterminado)"

        local detected
        detected=$(device_model_detect_external_drives 2>/dev/null || true)
        local opt_idx=2
        local -a opt_paths=()
        opt_paths[1]="~/Backups/KeepMyConfig"

        while IFS='|' read -r lbl mnt free; do
            [[ -n "$lbl" && -n "$mnt" ]] || continue
            echo "  [$opt_idx] Disco Externo: $lbl ($free libres) en $mnt"
            opt_paths["$opt_idx"]="$mnt/Backups/KeepMyConfig"
            ((opt_idx++))
        done <<< "$detected"
        echo "  [$opt_idx] Ingresar ruta personalizada manualmente"
        local manual_idx="$opt_idx"
        echo ""

        local sel
        read -r -p "Seleccione una opción [1]: " sel || true
        sel="${sel:-1}"

        local chosen_dest=""
        if [[ "$sel" == "$manual_idx" ]]; then
            read -r -p "Ingrese la ruta de destino: " chosen_dest || true
        else
            chosen_dest="${opt_paths[$sel]:-~/Backups/KeepMyConfig}"
        fi
        [[ -n "$chosen_dest" ]] || chosen_dest="~/Backups/KeepMyConfig"

        local resolved_dest
        resolved_dest=$(device_model_resolve_destination "$chosen_dest") || resolved_dest="$HOME/Backups/KeepMyConfig"
        mkdir -p "$resolved_dest" 2>/dev/null || true
        device_model_init_storage_marker "$resolved_dest" "${CONTROLLER_BASE_DIR}/markers/.backup_storage_marker" 2>/dev/null || true
        device_model_update_config_destination "$cfg_file" "$chosen_dest" 2>/dev/null || true

        echo ""
        local rem_ans
        read -r -p "¿Recordar el último perfil utilizado en cada sesión? (s/N): " rem_ans || true
        local remember_pref="false"
        if [[ "$rem_ans" =~ ^[sSyY] ]]; then
            remember_pref="true"
        fi

        sed -i "s|^REMEMBER_LAST_PROFILE=.*|REMEMBER_LAST_PROFILE=\"$remember_pref\"|" "$cfg_file" 2>/dev/null || true
        sed -i "s|^INITIAL_SETUP_DONE=.*|INITIAL_SETUP_DONE=\"true\"|" "$cfg_file" 2>/dev/null || true

        ansi_view_success "Configuración completada exitosamente."
        ansi_view_key_value "Destino Configurado" "$chosen_dest"
        ansi_view_key_value "Ruta Resuelta" "$resolved_dest"
        ansi_view_key_value "Recordar Perfil" "$remember_pref"
        return 0
    fi
}

controller_handle_set_backup_destination() {
    local new_dest="${1:-}"
    local is_tui="${2:-false}"
    local cfg_file="$(_controller_get_config_file)"

    if [[ "$is_tui" == "true" ]]; then
        local cur_dest="${BACKUP_DESTINATION:-~/Backups/KeepMyConfig}"
        new_dest=$(whiptail_view_input "Destino de Backup" "Introduzca la nueva ruta de destino para las copias:" "$cur_dest") || return 0
        [[ -n "$new_dest" ]] || return 0
        local resolved
        resolved=$(device_model_resolve_destination "$new_dest") || {
            whiptail_view_error "Error de Destino" "La ruta especificada no es válida o no está montada."
            return 1
        }
        mkdir -p "$resolved" 2>/dev/null || true
        device_model_init_storage_marker "$resolved" "${CONTROLLER_BASE_DIR}/markers/.backup_storage_marker" 2>/dev/null || true
        device_model_update_config_destination "$cfg_file" "$new_dest"
        BACKUP_DESTINATION="$new_dest"
        whiptail_view_msgbox "Destino Actualizado" "El destino de backup se ha actualizado a:\n$new_dest\n\nRuta física: $resolved"
        return 0
    else
        [[ -n "$new_dest" ]] || return 1
        device_model_update_config_destination "$cfg_file" "$new_dest"
        return $?
    fi
}

# 7. Diagnóstico y Gestión de Almacenamiento y Destinos
controller_handle_device_check() {
    local is_tui="${1:-false}"

    if [[ "$is_tui" != "true" ]]; then
        _controller_show_device_diagnostics "false"
        return $?
    fi

    while true; do
        local choice
        choice=$(whiptail_view_menu "Gestión y Diagnóstico de Almacenamiento" "Seleccione una operación:" \
            "1" "Ver diagnóstico de almacenamiento y espacio libre" \
            "2" "Cambiar ruta de destino de backup (BACKUP_DESTINATION)" \
            "3" "Asistente de configuración guiada (Onboarding)" \
            "4" "Desplegar marcador de seguridad en destino actual" \
            "0" "Volver al Menú Principal") || return 0

        case "$choice" in
            1) _controller_show_device_diagnostics "true" ;;
            2) controller_handle_set_backup_destination "" "true" ;;
            3) controller_handle_onboarding_wizard "true" ;;
            4) controller_handle_deploy_marker "" "true" ;;
            0) return 0 ;;
        esac
    done
}

# 8. Asistente de Administración de Módulos, Plantillas y Etiquetas (TUI)
controller_handle_list_templates() {
    local is_tui="${1:-false}"
    local tmpl_dir="${TEMPLATES_DIR:-${CONTROLLER_BASE_DIR}/templates.d}"
    local tmpls
    tmpls=$(module_model_list_templates "$tmpl_dir") || true

    if [[ "$is_tui" == "true" ]]; then
        local txt="Biblioteca de Plantillas Disponibles (templates.d/):\n\n"
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            local tinfo
            tinfo=$(module_model_get_template "$t" "$tmpl_dir" 2>/dev/null || true)
            local tname tsens tpurge
            tname=$(echo "$tinfo" | grep '^NAME=' | cut -d'=' -f2-)
            tsens=$(echo "$tinfo" | grep '^IS_SENSITIVE=' | cut -d'=' -f2-)
            tpurge=$(echo "$tinfo" | grep '^PURGE_AFTER_BACKUP=' | cut -d'=' -f2-)
            txt+="• $t: ${tname:-$t} (Sensible: $tsens, Purga: $tpurge)\n"
        done <<< "$tmpls"
        whiptail_view_msgbox "Biblioteca de Plantillas" "$txt"
    else
        ansi_view_header "BIBLIOTECA DE PLANTILLAS DISPONIBLES"
        while IFS= read -r t; do
            [[ -n "$t" ]] || continue
            local tinfo
            tinfo=$(module_model_get_template "$t" "$tmpl_dir" 2>/dev/null || true)
            local tname tsens tpurge
            tname=$(echo "$tinfo" | grep '^NAME=' | cut -d'=' -f2-)
            tsens=$(echo "$tinfo" | grep '^IS_SENSITIVE=' | cut -d'=' -f2-)
            tpurge=$(echo "$tinfo" | grep '^PURGE_AFTER_BACKUP=' | cut -d'=' -f2-)
            ansi_view_key_value "$t" "${tname:-$t} [Sensible: $tsens, Purga: $tpurge]"
        done <<< "$tmpls"
    fi
}

controller_handle_enable_template() {
    local tmpl_id="${1:-}"
    local is_tui="${2:-false}"
    local target_profile="${3:-}"
    local tmpl_dir="${TEMPLATES_DIR:-${CONTROLLER_BASE_DIR}/templates.d}"

    if [[ -z "$tmpl_id" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            local tmpls
            tmpls=$(module_model_list_templates "$tmpl_dir") || true
            if [[ -z "$tmpls" ]]; then
                whiptail_view_msgbox "Biblioteca Vacía" "No se encontraron plantillas disponibles en $tmpl_dir."
                return 0
            fi
            local t_items=()
            while IFS= read -r t; do
                [[ -n "$t" ]] || continue
                local tinfo
                tinfo=$(module_model_get_template "$t" "$tmpl_dir" 2>/dev/null || true)
                local tname
                tname=$(echo "$tinfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$t")
                t_items+=("$t" "$tname")
            done <<< "$tmpls"
            tmpl_id=$(whiptail_view_menu "Activar Plantilla" "Seleccione la plantilla que desea activar:" "${t_items[@]}") || return 0
        else
            ansi_view_error "Debe especificar el ID de la plantilla a activar. Use --list-templates para ver las disponibles."
            return 1
        fi
    fi

    [[ -n "$tmpl_id" ]] || return 0

    local act_prof="${target_profile:-$(_controller_get_active_profile)}"
    local target_dir="$MODULES_DIR"
    local scope_desc="Catálogo Global"

    if [[ "$is_tui" == "true" ]]; then
        if [[ "$act_prof" != "default" && -n "$act_prof" ]]; then
            local scope_choice
            scope_choice=$(whiptail_view_menu "Ámbito de Activación" "¿Dónde desea activar esta plantilla?" \
                "1" "Catálogo Global (modules.d/ - disponible para todos)" \
                "2" "Exclusivo del Perfil '$act_prof' (profiles/$act_prof/modules.d/)") || return 0
            if [[ "$scope_choice" == "2" ]]; then
                target_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}/${act_prof}/modules.d"
                scope_desc="Perfil '$act_prof'"
            fi
        fi
    else
        if [[ -n "$target_profile" && "$target_profile" != "default" ]]; then
            target_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}/${target_profile}/modules.d"
            scope_desc="Perfil '$target_profile'"
        fi
    fi

    local act_status=0
    module_model_activate_template "$tmpl_id" "$target_dir" "$tmpl_dir" || act_status=$?

    if (( act_status == 0 )); then
        if [[ "$scope_desc" == "Catálogo Global" && "$act_prof" != "default" ]]; then
            profile_model_enable_module "$act_prof" "$tmpl_id" "${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}" 2>/dev/null || true
        fi
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_msgbox "Plantilla Activada" "La plantilla '$tmpl_id' ha sido activada en ($scope_desc):\n${target_dir}/${tmpl_id}.conf\n\nYa forma parte de los módulos a respaldar."
        else
            ansi_view_success "Plantilla '$tmpl_id' activada en ($scope_desc): ${target_dir}/${tmpl_id}.conf"
        fi
        return 0
    elif (( act_status == MOD_ERR_ALREADY_EXISTS )); then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Módulo Existente" "Ya existe un módulo activo con ID '$tmpl_id' en ($scope_desc)."
        else
            ansi_view_error "El módulo '$tmpl_id' ya está activo en ($scope_desc)."
        fi
        return 1
    else
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error de Activación" "No se pudo activar la plantilla '$tmpl_id' (código: $act_status)."
        else
            ansi_view_error "Error al activar la plantilla '$tmpl_id' (código: $act_status)."
        fi
        return "$act_status"
    fi
}

controller_handle_export_template() {
    local mod_id="${1:-}"
    local is_tui="${2:-false}"
    local target_tmpl_id="${3:-}"
    local tmpl_dir="${TEMPLATES_DIR:-${CONTROLLER_BASE_DIR}/templates.d}"
    local act_prof
    act_prof=$(_controller_get_active_profile)

    if [[ "$is_tui" == "true" && -z "$mod_id" ]]; then
        local all_mods
        all_mods=$(_controller_list_modules) || true
        if [[ -z "$all_mods" ]]; then
            whiptail_view_msgbox "Sin Módulos" "No hay módulos activos en el perfil '$act_prof' para exportar."
            return 0
        fi
        local m_items=()
        for m in $all_mods; do
            local minfo
            minfo=$(_controller_get_module_info "$m") || continue
            local mname
            mname=$(echo "$minfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$m")
            m_items+=("$m" "$mname")
        done
        mod_id=$(whiptail_view_menu "Exportar a Plantilla" "Seleccione el módulo activo a promover como plantilla:" "${m_items[@]}") || return 0
    fi

    [[ -n "$mod_id" ]] || return 1

    local mod_path
    mod_path=$(profile_model_resolve_module "$mod_id" "$act_prof" "$CONTROLLER_BASE_DIR" 2>/dev/null || true)
    if [[ -z "$mod_path" || ! -f "$mod_path" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error" "No se pudo localizar el archivo del módulo '$mod_id'."
        else
            ansi_view_error "No se pudo localizar el archivo del módulo '$mod_id'."
        fi
        return 2
    fi

    if [[ "$is_tui" == "true" && -z "$target_tmpl_id" ]]; then
        target_tmpl_id=$(whiptail_view_input "ID de Plantilla" "Identificador para la plantilla en la biblioteca:" "$mod_id") || return 0
        [[ -z "$target_tmpl_id" ]] && return 0
    fi
    target_tmpl_id="${target_tmpl_id:-$mod_id}"

    if [[ -f "${tmpl_dir}/${target_tmpl_id}.conf" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            if ! whiptail_view_yesno "Plantilla Existente" "Ya existe una plantilla con ID '$target_tmpl_id' en la biblioteca.\n¿Desea sobrescribirla?"; then
                return 0
            fi
        fi
    fi

    local exp_status=0
    module_model_export_to_template "$mod_path" "$target_tmpl_id" "$tmpl_dir" || exp_status=$?

    if (( exp_status == 0 )); then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_msgbox "Exportación Exitosa" "El módulo '$mod_id' ha sido promovido y guardado como plantilla en:\n${tmpl_dir}/${target_tmpl_id}.conf"
        else
            ansi_view_success "Módulo '$mod_id' exportado a plantilla: ${tmpl_dir}/${target_tmpl_id}.conf"
        fi
        return 0
    else
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error de Exportación" "No se pudo exportar a plantilla (código: $exp_status)."
        else
            ansi_view_error "No se pudo exportar el módulo '$mod_id' a plantilla (código: $exp_status)."
        fi
        return "$exp_status"
    fi
}

controller_handle_modules_admin() {
    local is_tui="${1:-true}"

    if [[ "$is_tui" != "true" ]]; then
        ansi_view_info "Para administrar módulos use los subcomandos de línea de órdenes."
        return 0
    fi

    while true; do
        local admin_choice
        admin_choice=$(whiptail_view_menu "Administración de Módulos y Plantillas" "Seleccione una acción:" \
            "1" "Listar y ver detalle de módulos activos" \
            "2" "Activar módulo desde plantilla" \
            "3" "Crear un nuevo módulo activo" \
            "4" "Crear una nueva plantilla en la biblioteca" \
            "5" "Exportar módulo activo a la biblioteca de plantillas" \
            "6" "Eliminar un módulo activo" \
            "7" "Añadir etiqueta al catálogo" \
            "0" "Volver al Menú Principal") || return 0

        case "$admin_choice" in
            1)
                local act_prof
                act_prof=$(_controller_get_active_profile)
                local all_mods
                all_mods=$(profile_model_list_modules "$act_prof" "$CONTROLLER_BASE_DIR") || true
                if [[ -z "$all_mods" ]]; then
                    whiptail_view_msgbox "Módulos" "No hay módulos registrados para el perfil activo ($act_prof).\nPuede activar recetas desde la opción '2) Activar módulo desde plantilla'."
                    continue
                fi
                local m_items=()
                for m in $all_mods; do
                    local m_path
                    m_path=$(profile_model_resolve_module "$m" "$act_prof" "$CONTROLLER_BASE_DIR" 2>/dev/null || true)
                    local scope_tag="[Global]"
                    if [[ "$m_path" =~ /profiles/ ]]; then
                        scope_tag="[Perfil: $act_prof]"
                    fi
                    local minfo
                    minfo=$(module_model_get "$m" "$(dirname "$m_path")") || continue
                    local mname
                    mname=$(echo "$minfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$m")
                    m_items+=("$m" "$scope_tag $mname")
                done
                local sel_m
                sel_m=$(whiptail_view_menu "Módulos Registrados" "Seleccione un módulo para inspeccionar:" "${m_items[@]}") || continue
                local sel_path
                sel_path=$(profile_model_resolve_module "$sel_m" "$act_prof" "$CONTROLLER_BASE_DIR") || continue
                local detail
                detail=$(module_model_get "$sel_m" "$(dirname "$sel_path")") || continue
                whiptail_view_msgbox "Detalle del Módulo '$sel_m'" "$detail"
                ;;
            2)
                # Activar módulo desde plantilla
                controller_handle_enable_template "" "true"
                ;;
            3)
                # Asistente de creación de módulo activo
                local act_prof
                act_prof=$(_controller_get_active_profile)
                local target_modules_dir="$MODULES_DIR"
                local scope_desc="Catálogo Global"

                if [[ "$act_prof" != "default" && -n "$act_prof" ]]; then
                    local scope_choice
                    scope_choice=$(whiptail_view_menu "Ámbito del Módulo" "¿Dónde desea registrar este módulo?" \
                        "1" "Catálogo Global (modules.d/ - compartido)" \
                        "2" "Exclusivo del Perfil '$act_prof' (profiles/$act_prof/modules.d/)") || continue
                    if [[ "$scope_choice" == "2" ]]; then
                        target_modules_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}/${act_prof}/modules.d"
                        scope_desc="Perfil '$act_prof'"
                        mkdir -p "$target_modules_dir" 2>/dev/null || true
                    fi
                fi

                local mod_id
                mod_id=$(whiptail_view_input "Nuevo Módulo ($scope_desc)" "Introduzca el ID único (ej: mi-app):") || continue
                [[ -z "$mod_id" ]] && continue

                local mod_name
                mod_name=$(whiptail_view_input "Nuevo Módulo ($scope_desc)" "Nombre descriptivo (ej: Mi Aplicación):" "$mod_id") || continue

                local paths_joined
                paths_joined=$(whiptail_view_input_paths "Rutas del Módulo ($scope_desc)" "$mod_name") || continue
                [[ -z "$paths_joined" ]] && continue

                local all_tags
                all_tags=$(module_model_get_all_tags) || true
                local tag_checks=()
                for t in $all_tags; do
                    tag_checks+=("$t" "Etiqueta $t" "OFF")
                done
                local sel_tags
                sel_tags=$(whiptail_view_checklist "Etiquetas" "Seleccione las etiquetas para este módulo:" "${tag_checks[@]}") || sel_tags="dev"

                local is_sens="false"
                if whiptail_view_yesno "Seguridad" "¿Contiene este módulo datos sensibles o confidenciales? (Requiere GPG)"; then
                    is_sens="true"
                fi

                local purge_val="false"
                if [[ "$is_sens" == "true" ]]; then
                    if whiptail_view_yesno "Vault & Shred" "¿Desea activar purga automática (shred -u) tras el respaldo?"; then
                        purge_val="true"
                    fi
                fi

                local tags_arr=()
                read -r -a tags_arr <<< "$sel_tags"

                local tags_joined=""
                for t in "${tags_arr[@]}"; do
                    [[ -n "$t" ]] || continue
                    if [[ -n "$tags_joined" ]]; then
                        tags_joined+=",$t"
                    else
                        tags_joined="$t"
                    fi
                done
                [[ -z "$tags_joined" ]] && tags_joined="dev"

                if module_model_save "$mod_id" "$mod_name" "$tags_joined" "$paths_joined" "$is_sens" "$purge_val" "" "$target_modules_dir"; then
                    whiptail_view_msgbox "Módulo Creado" "El módulo '$mod_id' se ha registrado correctamente en:\n${target_modules_dir}/${mod_id}.conf"
                else
                    whiptail_view_error "Fallo de Creación" "No se pudo crear el archivo del módulo."
                fi
                ;;
            4)
                # Crear nueva plantilla en templates.d/
                local tmpl_dir="${TEMPLATES_DIR:-${CONTROLLER_BASE_DIR}/templates.d}"
                local tmpl_id
                tmpl_id=$(whiptail_view_input "Nueva Plantilla" "Introduzca el ID único de la plantilla (ej: custom-tool):") || continue
                [[ -z "$tmpl_id" ]] && continue

                local tmpl_name
                tmpl_name=$(whiptail_view_input "Nueva Plantilla" "Nombre descriptivo de la receta:" "$tmpl_id") || continue

                local paths_joined
                paths_joined=$(whiptail_view_input_paths "Rutas de la Plantilla" "$tmpl_name") || continue
                [[ -z "$paths_joined" ]] && continue

                local all_tags
                all_tags=$(module_model_get_all_tags) || true
                local tag_checks=()
                for t in $all_tags; do
                    tag_checks+=("$t" "Etiqueta $t" "OFF")
                done
                local sel_tags
                sel_tags=$(whiptail_view_checklist "Etiquetas" "Seleccione etiquetas para la plantilla:" "${tag_checks[@]}") || sel_tags="dev"

                local is_sens="false"
                if whiptail_view_yesno "Seguridad" "¿La plantilla maneja datos sensibles cifrados con GPG?"; then
                    is_sens="true"
                fi

                local purge_val="false"
                if [[ "$is_sens" == "true" ]]; then
                    if whiptail_view_yesno "Vault & Shred" "¿Desea activar purga automática (shred -u)?"; then
                        purge_val="true"
                    fi
                fi

                local tags_arr=()
                read -r -a tags_arr <<< "$sel_tags"

                local tags_joined=""
                for t in "${tags_arr[@]}"; do
                    [[ -n "$t" ]] || continue
                    if [[ -n "$tags_joined" ]]; then
                        tags_joined+=",$t"
                    else
                        tags_joined="$t"
                    fi
                done
                [[ -z "$tags_joined" ]] && tags_joined="dev"

                if module_model_create_template "$tmpl_id" "$tmpl_name" "$tags_joined" "$paths_joined" "$is_sens" "$purge_val" "" "$tmpl_dir"; then
                    whiptail_view_msgbox "Plantilla Creada" "La plantilla '$tmpl_id' se ha registrado en la biblioteca:\n${tmpl_dir}/${tmpl_id}.conf\n\nEstá lista para ser activada en cualquier perfil."
                else
                    whiptail_view_error "Error" "No se pudo registrar la plantilla en $tmpl_dir."
                fi
                ;;
            5)
                # Exportar módulo activo a la biblioteca de plantillas
                controller_handle_export_template "" "true" ""
                ;;
            6)
                local act_prof
                act_prof=$(_controller_get_active_profile)
                local all_mods
                all_mods=$(profile_model_list_modules "$act_prof" "$CONTROLLER_BASE_DIR") || true
                if [[ -z "$all_mods" ]]; then
                    whiptail_view_msgbox "Eliminación" "No hay módulos para eliminar."
                    continue
                fi
                local del_items=()
                for m in $all_mods; do
                    local m_path
                    m_path=$(profile_model_resolve_module "$m" "$act_prof" "$CONTROLLER_BASE_DIR" 2>/dev/null || true)
                    local scope_tag="[Global]"
                    if [[ "$m_path" =~ /profiles/ ]]; then
                        scope_tag="[Perfil: $act_prof]"
                    fi
                    del_items+=("$m" "$scope_tag Módulo: $m" "OFF")
                done
                local to_delete
                to_delete=$(whiptail_view_radiolist "Eliminar Módulo" "Seleccione el módulo a borrar permanentemente:" "${del_items[@]}") || continue

                local del_path
                del_path=$(profile_model_resolve_module "$to_delete" "$act_prof" "$CONTROLLER_BASE_DIR" 2>/dev/null || true)
                local del_dir="$MODULES_DIR"
                if [[ -n "$del_path" ]]; then
                    del_dir="$(dirname "$del_path")"
                fi

                if whiptail_view_yesno "Confirmación de Borrado" "¿Está completamente seguro de eliminar el módulo '$to_delete' localizado en:\n$del_path?\nEsta acción no se puede deshacer."; then
                    if module_model_delete "$to_delete" "$del_dir"; then
                        whiptail_view_msgbox "Borrado Exitoso" "El módulo '$to_delete' ha sido eliminado correctamente de:\n$del_dir."
                    else
                        whiptail_view_error "Error" "No se pudo eliminar el módulo '$to_delete'."
                    fi
                fi
                ;;
            7)
                local new_tag
                new_tag=$(whiptail_view_input "Nueva Etiqueta" "Introduzca el nombre de la nueva etiqueta (alfanumérico):") || continue
                if [[ -n "$new_tag" ]]; then
                    if module_model_add_tag_to_catalog "$new_tag"; then
                        whiptail_view_msgbox "Catálogo Actualizado" "La etiqueta '$new_tag' ha sido incorporada al catálogo global."
                    else
                        whiptail_view_error "Fallo" "No se pudo registrar la etiqueta."
                    fi
                fi
                ;;
            0)
                return 0
                ;;
        esac
    done
}


# ==============================================================================
# 9. Gestión de Perfiles de Backup
# ==============================================================================

controller_handle_list_profiles() {
    local is_tui="${1:-false}"
    local profiles_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}"
    local profiles
    profiles=$(profile_model_list "$profiles_dir") || true
    local act_prof
    act_prof=$(_controller_get_active_profile)

    if [[ "$is_tui" == "true" ]]; then
        local list_txt="Perfiles de Backup Registrados:\n\n"
        while IFS= read -r p; do
            [[ -n "$p" ]] || continue
            local p_info
            p_info=$(profile_model_get "$p" "$profiles_dir" 2>/dev/null || true)
            local p_name p_desc p_sub
            p_name=$(echo "$p_info" | grep '^NAME=' | cut -d'=' -f2-)
            p_desc=$(echo "$p_info" | grep '^DESCRIPTION=' | cut -d'=' -f2-)
            p_sub=$(echo "$p_info" | grep '^TARGET_SUBDIR=' | cut -d'=' -f2-)

            local marker=" "
            if [[ "$p" == "$act_prof" ]]; then
                marker="*"
            fi
            list_txt+="[$marker] $p - ${p_name:-$p}\n"
            [[ -n "$p_desc" ]] && list_txt+="    Descripción: $p_desc\n"
            [[ -n "$p_sub" ]] && list_txt+="    Destino específico: $p_sub\n"
            list_txt+="\n"
        done <<< "$profiles"
        whiptail_view_msgbox "Perfiles de Backup" "$list_txt"
    else
        ansi_view_header "PERFILES DE BACKUP CONFIGURADOS"
        while IFS= read -r p; do
            [[ -n "$p" ]] || continue
            local p_info
            p_info=$(profile_model_get "$p" "$profiles_dir" 2>/dev/null || true)
            local p_name p_desc p_sub
            p_name=$(echo "$p_info" | grep '^NAME=' | cut -d'=' -f2-)
            p_desc=$(echo "$p_info" | grep '^DESCRIPTION=' | cut -d'=' -f2-)
            p_sub=$(echo "$p_info" | grep '^TARGET_SUBDIR=' | cut -d'=' -f2-)

            local active_tag=""
            if [[ "$p" == "$act_prof" ]]; then
                active_tag=" [ACTIVO]"
            fi
            local details="${p_name:-$p}$active_tag"
            [[ -n "$p_sub" ]] && details+=" (Destino: $p_sub)"
            ansi_view_key_value "$p" "$details"
            if [[ -n "$p_desc" ]]; then
                echo "    Descripción: $p_desc"
            fi
        done <<< "$profiles"
    fi
    return 0
}

controller_handle_set_active_profile() {
    local profile_id="${1:-}"
    local is_tui="${2:-false}"
    local profiles_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}"

    if [[ "$is_tui" == "true" && -z "$profile_id" ]]; then
        local profiles
        profiles=$(profile_model_list "$profiles_dir") || true
        local act_prof
        act_prof=$(_controller_get_active_profile)

        local p_items=()
        while IFS= read -r p; do
            [[ -n "$p" ]] || continue
            local p_info
            p_info=$(profile_model_get "$p" "$profiles_dir" 2>/dev/null || true)
            local p_name
            p_name=$(echo "$p_info" | grep '^NAME=' | cut -d'=' -f2-)
            local st="OFF"
            [[ "$p" == "$act_prof" ]] && st="ON"
            p_items+=("$p" "${p_name:-$p}" "$st")
        done <<< "$profiles"

        profile_id=$(whiptail_view_radiolist "Seleccionar Perfil Activo" "Elija el perfil de backup predeterminado:" "${p_items[@]}") || return 0
        [[ -z "$profile_id" ]] && return 0
    fi

    if [[ -z "$profile_id" ]]; then
        ansi_view_error "Debe especificar el identificador de perfil (ej: --set-active-profile default)."
        return 1
    fi

    # Validar que el perfil exista
    if ! profile_model_get "$profile_id" "$profiles_dir" >/dev/null 2>&1; then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Perfil no encontrado" "El perfil '$profile_id' no existe o está corrupto."
        else
            ansi_view_error "El perfil '$profile_id' no existe o está corrupto."
        fi
        return "$PROFILE_ERR_NOT_FOUND"
    fi

    if profile_model_set_active "$profile_id" "$(_controller_get_config_file)"; then
        ACTIVE_PROFILE_OVERRIDE=""
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_msgbox "Perfil Actualizado" "El perfil activo se ha establecido en:\n$profile_id"
        else
            ansi_view_success "Perfil activo actualizado en config.conf: ACTIVE_PROFILE=\"$profile_id\""
        fi
        return 0
    else
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error" "No se pudo actualizar el perfil activo en config.conf."
        else
            ansi_view_error "No se pudo actualizar el perfil activo en config.conf."
        fi
        return "$PROFILE_ERR_IO"
    fi
}

controller_handle_create_profile() {
    local profile_id="${1:-}"
    local name="${2:-}"
    local desc="${3:-}"
    local target_subdir="${4:-}"
    local is_tui="${5:-false}"
    local profiles_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}"

    if [[ "$is_tui" == "true" && -z "$profile_id" ]]; then
        profile_id=$(whiptail_view_input "Nuevo Perfil" "Identificador único (alfanumérico, ej: docente, dev):") || return 0
        [[ -z "$profile_id" ]] && return 0

        name=$(whiptail_view_input "Nuevo Perfil" "Nombre descriptivo:" "$profile_id") || return 0
        desc=$(whiptail_view_input "Nuevo Perfil" "Descripción del perfil:" "") || return 0
        target_subdir=$(whiptail_view_input "Nuevo Perfil" "Subcarpeta de backup asociada (opcional, ej: Backups/Docente):" "") || return 0
    fi

    if [[ -z "$profile_id" ]]; then
        ansi_view_error "Debe especificar un ID para el nuevo perfil."
        return 1
    fi

    if ! profile_model_validate_id "$profile_id"; then
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "ID Inválido" "El identificador solo puede contener letras, números, guiones y guiones bajos."
        else
            ansi_view_error "El ID de perfil '$profile_id' no es válido (solo [a-zA-Z0-9_-])."
        fi
        return "$PROFILE_ERR_INVALID_ID"
    fi

    local status=0
    profile_model_create "$profile_id" "$name" "$desc" "$target_subdir" "$profiles_dir" || status=$?
    if (( status != 0 )); then
        local err_msg="No se pudo crear el perfil."
        if (( status == PROFILE_ERR_ALREADY_EXISTS )); then
            err_msg="El perfil '$profile_id' ya existe."
        fi
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error al crear perfil" "$err_msg"
        else
            ansi_view_error "$err_msg"
        fi
        return "$status"
    fi

    if [[ "$is_tui" == "true" ]]; then
        if whiptail_view_yesno "Perfil Creado" "El perfil '$profile_id' se ha creado correctamente.\n\n¿Desea establecerlo como perfil activo ahora?"; then
            controller_handle_set_active_profile "$profile_id" "true"
        fi
    else
        ansi_view_success "Perfil '$profile_id' creado correctamente en ${profiles_dir}/${profile_id}."
    fi
    return 0
}

controller_handle_profiles_admin() {
    local is_tui="${1:-true}"
    local profiles_dir="${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}"

    if [[ "$is_tui" != "true" ]]; then
        ansi_view_info "Para administrar perfiles use los subcomandos CLI: --list-profiles, --set-active-profile, --create-profile."
        return 0
    fi

    while true; do
        local act_prof
        act_prof=$(_controller_get_active_profile)

        local choice
        choice=$(whiptail_view_menu "Gestión de Perfiles [Activo: $act_prof]" "Seleccione una acción:" \
            "1" "Ver detalles del perfil activo" \
            "2" "Cambiar perfil activo" \
            "3" "Crear un nuevo perfil" \
            "4" "Listar recetas y módulos del perfil activo" \
            "5" "Gestionar exclusiones de módulos globales" \
            "6" "Eliminar un perfil" \
            "0" "Volver al Menú Principal") || return 0

        case "$choice" in
            1)
                local p_info
                p_info=$(profile_model_get "$act_prof" "$profiles_dir" 2>/dev/null || true)
                whiptail_view_msgbox "Detalles del Perfil '$act_prof'" "$p_info"
                ;;
            2)
                controller_handle_set_active_profile "" "true"
                ;;
            3)
                controller_handle_create_profile "" "" "" "" "true"
                ;;
            4)
                local mods
                mods=$(_controller_list_modules) || true
                local mod_list_txt="Módulos visibles para el perfil '$act_prof':\n\n"
                while IFS= read -r m; do
                    [[ -n "$m" ]] || continue
                    local scope="[Global]"
                    if [[ "$act_prof" != "default" ]]; then
                        if [[ -f "${profiles_dir}/${act_prof}/modules.d/${m}.conf" ]]; then
                            if [[ -f "${MODULES_DIR:-${CONTROLLER_BASE_DIR}/modules.d}/${m}.conf" ]]; then
                                scope="[Override]"
                            else
                                scope="[Exclusivo]"
                            fi
                        fi
                    fi
                    local minfo
                    minfo=$(_controller_get_module_info "$m" 2>/dev/null || true)
                    local mname
                    mname=$(echo "$minfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$m")
                    mod_list_txt+="• $m : $mname $scope\n"
                done <<< "$mods"
                whiptail_view_msgbox "Módulos del Perfil '$act_prof'" "$mod_list_txt"
                ;;
            5)
                if [[ "$act_prof" == "default" ]]; then
                    whiptail_view_msgbox "Perfil Global" "El perfil 'default' es la base global de KeepMyConfig y no admite exclusiones.\nPara desactivar módulos globales de forma selectiva, cree o active un perfil particular."
                    continue
                fi

                local global_mods
                global_mods=$(module_model_list "${MODULES_DIR:-${CONTROLLER_BASE_DIR}/modules.d}") || true
                if [[ -z "$global_mods" ]]; then
                    whiptail_view_msgbox "Sin Módulos Globales" "No hay módulos registrados en el catálogo global (modules.d/) para excluir."
                    continue
                fi

                local disabled_mods
                disabled_mods=$(profile_model_get_disabled_modules "$act_prof" "$profiles_dir" 2>/dev/null || true)
                local -A dis_map=()
                while IFS= read -r dm; do
                    [[ -n "$dm" ]] && dis_map["$dm"]=1
                done <<< "$disabled_mods"

                local chk_items=()
                while IFS= read -r gm; do
                    [[ -n "$gm" ]] || continue
                    local ginfo
                    ginfo=$(module_model_get "$gm" "${MODULES_DIR:-${CONTROLLER_BASE_DIR}/modules.d}" 2>/dev/null || true)
                    local gname
                    gname=$(echo "$ginfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$gm")
                    local state="OFF"
                    if [[ -n "${dis_map[$gm]:-}" ]]; then
                        state="ON"
                    fi
                    chk_items+=("$gm" "$gname" "$state")
                done <<< "$global_mods"

                local sel_disabled
                sel_disabled=$(whiptail_view_checklist "Exclusiones de Módulos Globales" \
                    "Marque [ON] los módulos globales que desea EXCLUIR del perfil '$act_prof':\n(Los módulos marcados NO se respaldarán en este perfil)" \
                    "${chk_items[@]}") || continue

                local -A new_dis_map=()
                for sel in $sel_disabled; do
                    sel="${sel%\"}"
                    sel="${sel#\"}"
                    [[ -n "$sel" ]] && new_dis_map["$sel"]=1
                done

                while IFS= read -r gm; do
                    [[ -n "$gm" ]] || continue
                    if [[ -n "${new_dis_map[$gm]:-}" ]]; then
                        profile_model_disable_module "$act_prof" "$gm" "$profiles_dir"
                    else
                        profile_model_enable_module "$act_prof" "$gm" "$profiles_dir"
                    fi
                done <<< "$global_mods"

                whiptail_view_msgbox "Exclusiones Actualizadas" "La lista de exclusiones para el perfil '$act_prof' ha sido actualizada correctamente en profile.conf."
                ;;
            6)
                local profiles
                profiles=$(profile_model_list "$profiles_dir") || true
                local del_items=()
                while IFS= read -r p; do
                    [[ -n "$p" ]] || continue
                    if [[ "$p" != "default" && "$p" != "$act_prof" ]]; then
                        del_items+=("$p" "Perfil: $p" "OFF")
                    fi
                done <<< "$profiles"

                if [[ ${#del_items[@]} -eq 0 ]]; then
                    whiptail_view_msgbox "Eliminar Perfil" "No hay otros perfiles disponibles para eliminar (no se puede eliminar 'default' ni el perfil actualmente activo)."
                    continue
                fi

                local to_delete
                to_delete=$(whiptail_view_radiolist "Eliminar Perfil" "Seleccione el perfil a borrar:" "${del_items[@]}") || continue
                [[ -z "$to_delete" ]] && continue

                if whiptail_view_yesno "Confirmar Eliminación" "¿Está completamente seguro de eliminar el perfil '$to_delete' y todas sus recetas específicas?\nEsta acción no se puede deshacer."; then
                    local del_status=0
                    profile_model_delete "$to_delete" "$profiles_dir" || del_status=$?
                    if (( del_status == 0 )); then
                        whiptail_view_msgbox "Perfil Eliminado" "El perfil '$to_delete' ha sido eliminado correctamente."
                    else
                        whiptail_view_error "Error" "No se pudo eliminar el perfil '$to_delete'."
                    fi
                fi
                ;;

            0)
                return 0
                ;;
        esac
    done
}

# ==============================================================================
# Bucles Principales (TUI y CLI)
# ==============================================================================

# Bucle principal TUI interactivo
controller_run_tui() {
    controller_init "${CONTROLLER_BASE_DIR:-}"

    if ! whiptail_view_check_deps; then
        ansi_view_error "La herramienta 'whiptail' no está instalada. Ejecute en modo CLI headless o instale whiptail."
        return 10
    fi

    # Política de arranque: si REMEMBER_LAST_PROFILE es "false", arrancar siempre en 'default'
    local rem_prof="${REMEMBER_LAST_PROFILE:-true}"
    if [[ "$rem_prof" == "false" ]]; then
        profile_model_set_active "default" "$(_controller_get_config_file)" 2>/dev/null || true
    fi

    # Comprobación de Onboarding Wizard en primera ejecución
    local setup_done="${INITIAL_SETUP_DONE:-false}"
    if [[ "$setup_done" == "false" ]]; then
        controller_handle_onboarding_wizard "true"
        # Recargar configuración tras el asistente
        # shellcheck disable=SC1090
        source "$(_controller_get_config_file)" 2>/dev/null || true
    fi

    while true; do
        local act_prof
        act_prof=$(_controller_get_active_profile)
        local choice
        choice=$(whiptail_view_main_menu "$act_prof" "$IS_SANDBOX_MODE") || break

        case "$choice" in
            1) controller_handle_backup_all "true" "auto" || true ;;
            2) controller_handle_backup_tag "" "true" "auto" || true ;;
            3) controller_handle_backup_module "" "true" "auto" || true ;;
            4) controller_handle_restore_sensitive "true" || true ;;
            5) controller_handle_restore_module "" "" "true" || true ;;
            6) controller_handle_restore_all "true" || true ;;
            7) controller_handle_modules_admin "true" || true ;;
            8) controller_handle_device_check "true" || true ;;
            9) controller_handle_profiles_admin "true" || true ;;
            0) break ;;
            *) whiptail_view_error "Opción no reconocida" "La opción seleccionada no es válida." || true ;;
        esac
    done

    clear
    ansi_view_info "Sesión finalizada. ¡Hasta pronto!"
    return 0
}

# Parser y ejecutor CLI headless
controller_run_cli() {
    controller_init "${CONTROLLER_BASE_DIR:-}"

    local purge_flag="auto"
    local set_default_flag="false"
    local action=""
    local param_val=""
    local timestamp_val=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                ansi_view_header "GESTOR DE BACKUP Y RECUPERACIÓN (CLI HEADLESS)"
                echo "Uso: $0 [OPCIONES]"
                echo ""
                echo "Operaciones de Respaldo:"
                echo "  --backup-all [--purge | --no-purge]            Respaldo global de todos los módulos."
                echo "  --backup-tag <tag> [--purge | --no-purge]      Respaldo de módulos asociados a una etiqueta."
                echo "  --backup-module <id> [--purge | --no-purge]    Respaldo de un módulo individual."
                echo ""
                echo "Operaciones de Restauración:"
                echo "  --restore-sensitive                            Restauración rápida de datos sensibles (GPG)."
                echo "  --restore-all                                  Restauración completa de todos los módulos."
                echo "  --restore-module <id> [--timestamp <TS>]       Restauración de un módulo (o marca de tiempo)."
                echo ""
                echo "Diagnóstico y Gestión de Destinos:"
                echo "  --check-device                                 Verificar detección de almacenamiento y marcador."
                echo "  --setup                                        Asistente interactivo de configuración inicial."
                echo "  --init-target <subdir> [--set-default]         Inicializar carpeta de equipo en el almacenamiento."
                echo "  --list-targets                                 Listar destinos/carpetas con marcador en almacenamiento."
                echo "  --set-active-target <subdir>                   Fijar subdirectorio activo en config/config.conf."
                echo "  --target-subdir <subdir>                       Usar destino temporal para la operación actual."
                echo "  --list-modules                                 Listar módulos configurados y su estado."
                echo "  --list-tags                                    Listar catálogo de etiquetas activas."
                echo ""
                echo "Gestión de Perfiles de Backup:"
                echo "  --profile <id>                                 Usar perfil temporal para la operación actual."
                echo "  --list-profiles                                Listar todos los perfiles disponibles."
                echo "  --set-active-profile <id>                      Fijar perfil activo en config/config.conf."
                echo "  --create-profile <id>                          Crear un nuevo perfil de backup."
                echo ""
                echo "Biblioteca de Plantillas y Recetas:"
                echo "  --list-templates                               Listar plantillas disponibles en la biblioteca."
                echo "  --enable-template <id> [--profile <perfil>]    Activar una plantilla en global o en un perfil."
                echo "  --export-template <id>                         Exportar un módulo activo a la biblioteca de plantillas."
                echo ""
                echo "Entorno de Pruebas y Desarrollo (Sandbox):"
                echo "  --test-mode, --sandbox                         Activar entorno aislado en user_data/sandbox/."
                echo "  --clean-sandbox                                Purgar por completo el entorno user_data/sandbox/."
                echo ""
                echo "Ayuda:"
                echo "  -h, --help                                     Mostrar este menú de ayuda."
                return 0
                ;;
            --purge)
                purge_flag="true"
                shift
                ;;
            --no-purge)
                purge_flag="false"
                shift
                ;;
            --backup-all)
                action="backup-all"
                shift
                ;;
            --backup-tag)
                action="backup-tag"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --backup-module)
                action="backup-module"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --restore-sensitive)
                action="restore-sensitive"
                shift
                ;;
            --restore-all)
                action="restore-all"
                shift
                ;;
            --restore-module)
                action="restore-module"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --timestamp)
                timestamp_val="${2:-}"
                shift 2 || true
                ;;
            --check-device)
                action="check-device"
                shift
                ;;
            --setup)
                action="setup"
                shift
                ;;
            --init-target)
                action="init-target"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --set-default)
                set_default_flag="true"
                shift
                ;;
            --target-subdir)
                TARGET_SUBDIR_OVERRIDE="${2:-}"
                shift 2 || true
                ;;
            --list-targets)
                action="list-targets"
                shift
                ;;
            --set-active-target)
                action="set-active-target"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --profile)
                ACTIVE_PROFILE_OVERRIDE="${2:-}"
                shift 2 || true
                ;;
            --list-profiles)
                action="list-profiles"
                shift
                ;;
            --set-active-profile)
                action="set-active-profile"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --create-profile)
                action="create-profile"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --list-modules)
                action="list-modules"
                shift
                ;;
            --list-tags)
                action="list-tags"
                shift
                ;;
            --list-templates)
                action="list-templates"
                shift
                ;;
            --enable-template)
                action="enable-template"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --export-template)
                action="export-template"
                param_val="${2:-}"
                shift 2 || true
                ;;
            --test-mode|--sandbox)
                controller_enable_sandbox_mode
                shift
                ;;
            --clean-sandbox)
                action="clean-sandbox"
                shift
                ;;
            *)
                ansi_view_error "Opción no reconocida: $1"
                echo "Ejecute '$0 --help' para ver las opciones disponibles."
                return 5
                ;;
        esac
    done

    if [[ "$IS_SANDBOX_MODE" == "true" && -n "$action" && "$action" != "clean-sandbox" ]]; then
        ansi_view_warning "Ejecutando en MODO TEST / SANDBOX (Rutas aisladas en user_data/sandbox/)"
    fi

    case "$action" in
        clean-sandbox)
            controller_clean_sandbox
            ;;
        backup-all)
            controller_handle_backup_all "false" "$purge_flag"
            ;;
        backup-tag)
            controller_handle_backup_tag "$param_val" "false" "$purge_flag"
            ;;
        backup-module)
            controller_handle_backup_module "$param_val" "false" "$purge_flag"
            ;;
        restore-sensitive)
            controller_handle_restore_sensitive "false"
            ;;
        restore-all)
            controller_handle_restore_all "false"
            ;;
        restore-module)
            controller_handle_restore_module "$param_val" "$timestamp_val" "false"
            ;;
        check-device)
            controller_handle_device_check "false"
            ;;
        setup)
            controller_handle_onboarding_wizard "false"
            ;;
        init-target)
            local target_sub="${param_val:-${TARGET_SUBDIR_OVERRIDE:-}}"
            controller_handle_init_target "$target_sub" "$set_default_flag" "false"
            ;;
        list-targets)
            controller_handle_list_targets "false"
            ;;
        set-active-target)
            local target_sub="${param_val:-${TARGET_SUBDIR_OVERRIDE:-}}"
            controller_handle_set_active_target "$target_sub" "false"
            ;;
        list-profiles)
            controller_handle_list_profiles "false"
            ;;
        set-active-profile)
            controller_handle_set_active_profile "$param_val" "false"
            ;;
        create-profile)
            controller_handle_create_profile "$param_val" "$param_val" "Perfil creado desde CLI" "" "false"
            ;;
        list-templates)
            controller_handle_list_templates "false"
            ;;
        enable-template)
            controller_handle_enable_template "$param_val" "false" "$ACTIVE_PROFILE_OVERRIDE"
            ;;
        export-template)
            controller_handle_export_template "$param_val" "false" "$param_val"
            ;;
        list-modules)
            local act_prof
            act_prof=$(_controller_get_active_profile)
            ansi_view_header "MÓDULOS REGISTRADOS (Perfil: $act_prof)"
            local mods
            mods=$(_controller_list_modules) || true
            for m in $mods; do
                local minfo
                minfo=$(_controller_get_module_info "$m") || continue
                local mname
                mname=$(echo "$minfo" | grep '^NAME=' | cut -d'=' -f2- || echo "$m")
                local msens
                msens=$(echo "$minfo" | grep '^IS_SENSITIVE=' | cut -d'=' -f2- || echo "false")
                local scope="[Global]"
                if [[ "$act_prof" != "default" ]]; then
                    if [[ -f "${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}/${act_prof}/modules.d/${m}.conf" ]]; then
                        if [[ -f "${MODULES_DIR:-${CONTROLLER_BASE_DIR}/modules.d}/${m}.conf" ]]; then
                            scope="[Override]"
                        else
                            scope="[Exclusivo]"
                        fi
                    fi
                fi
                ansi_view_key_value "$m" "$mname $scope (Sensible: $msens)"
            done
            return 0
            ;;
        list-tags)
            ansi_view_header "CATÁLOGO DE ETIQUETAS"
            local tags
            tags=$(module_model_get_all_tags) || true
            for t in $tags; do
                echo "  • $t"
            done
            return 0
            ;;
        "")
            ansi_view_error "No se especificó ninguna acción. Use --help para consultar las opciones."
            return 5
            ;;
    esac

}
