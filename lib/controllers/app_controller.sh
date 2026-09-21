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
        echo "${CONTROLLER_BASE_DIR}/modules.d"
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

    CONTROLLER_INITIALIZED=1
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
        if [[ "$act_prof" != "default" ]]; then
            local p_info
            p_info=$(profile_model_get "$act_prof" "${PROFILES_DIR:-${CONTROLLER_BASE_DIR}/profiles}" 2>/dev/null || true)
            local p_sub
            p_sub=$(echo "$p_info" | grep '^TARGET_SUBDIR=' | cut -d'=' -f2-)
            if [[ -n "$p_sub" ]]; then
                effective_subdir="$p_sub"
            fi
        fi
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
            local warn_msg="AVISO DE SEGURIDAD:\n\nEl módulo sensible '${mod_name}' se ha respaldado con éxito en el SSD,\npero sus ficheros aún permanecen en el almacenamiento local de este equipo.\n\n¿Desea eliminarlos de forma segura con shred ahora?"
            if whiptail_view_yesno "Seguridad y Privacidad" "$warn_msg"; then
                # Usuario aceptó purgar de forma interactiva
                local paths_raw
                paths_raw=$(echo "$mod_info" | grep '^PATHS=' | cut -d'=' -f2- || true)
                local paths=()
                IFS='|' read -r -a paths <<< "$paths_raw"
                for p in "${paths[@]}"; do
                    crypto_model_shred_path "${TARGET_USER_HOME}/${p}" 3 &>/dev/null || true
                done
                whiptail_view_msgbox "Purga Completada" "Los ficheros locales de '${mod_name}' han sido destruidos con shred -u."
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

    local backup_dir=""
    local ret=0

    backup_dir=$(_controller_get_backup_dir) || ret=$?
    if (( ret != 0 )); then
        local err_txt="No se detectó el SSD externo de backup o falta el archivo marcador .backup_storage_marker."
        if [[ "$is_tui" == "true" ]]; then
            whiptail_view_error "Error de Almacenamiento" "$err_txt"
        else
            ansi_view_error "$err_txt"
        fi
        return 2
    fi

    # Verificar si hay módulos sensibles en el perfil activo
    local has_sensitive="false"
    for m in $(_controller_list_modules); do
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
            passphrase=$(whiptail_view_password_confirm "Cifrado de Módulos Sensibles" "Introduzca la contraseña GPG AES-256 para proteger sus datos:") || return 1
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
        whiptail_view_msgbox "Respaldo Completo Finalizado" "El proceso de respaldo ha concluido.\n\n$report"
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
            tag=$(whiptail_view_radiolist "Seleccionar Etiqueta" "Elija la etiqueta a respaldar:" "${tag_items[@]}") || return 1
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
            passphrase=$(whiptail_view_password_confirm "Cifrado GPG" "La etiqueta '$tag' contiene módulos sensibles. Introduzca contraseña:") || return 1
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
        whiptail_view_msgbox "Respaldo por Etiqueta" "Respaldo de etiqueta '$tag' finalizado.\n\n$report"
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
            module_id=$(whiptail_view_radiolist "Seleccionar Módulo" "Elija el módulo individual a respaldar:" "${mod_items[@]}") || return 1
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
            passphrase=$(whiptail_view_password_confirm "Cifrado GPG" "Módulo sensible. Introduzca la contraseña GPG AES-256:") || return 1
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
        whiptail_view_msgbox "Respaldo de Módulo" "Respaldo del módulo '$module_id' concluido.\n\n$report"
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
        passphrase=$(whiptail_view_password "Restauración Exprés Sensible" "Introduzca la contraseña GPG para descifrar todos sus datos sensibles:") || return 1
    else
        passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la contraseña GPG para restaurar datos sensibles")}"
    fi

    local report
    report=$(restore_model_restore_sensitive_all "$backup_dir" "$TARGET_USER_HOME" "$passphrase")
    ret=$?

    if [[ "$is_tui" == "true" ]]; then
        whiptail_view_msgbox "Restauración Exprés Sensible" "Resultado de la restauración:\n\n$report"
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
            module_id=$(whiptail_view_radiolist "Seleccionar Módulo" "Elija el módulo a restaurar:" "${mod_items[@]}") || return 1
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
        timestamp=$(whiptail_view_menu "Histórico de Respaldos" "Seleccione la versión a restaurar:" "${ts_items[@]}") || return 1
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
            passphrase=$(whiptail_view_password "Módulo Cifrado" "Introduzca la clave GPG para descifrar '$module_id':") || return 1
        else
            passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la clave GPG para descifrar '$module_id'")}"
        fi
    fi

    local report
    report=$(restore_model_restore_module "$module_id" "$backup_dir" "$TARGET_USER_HOME" "$timestamp" "$passphrase" "$m_dir")
    ret=$?

    if [[ "$is_tui" == "true" ]]; then
        whiptail_view_msgbox "Restauración Concluida" "Resultado de la restauración:\n\n$report"
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
            return 1
        fi
    fi

    local passphrase=""
    # Comprobar si hay módulos sensibles en el SSD
    local sens_mods
    sens_mods=$(module_model_filter_by_sensitivity "true") || true
    if [[ -n "$sens_mods" ]]; then
        if [[ "$is_tui" == "true" ]]; then
            passphrase=$(whiptail_view_password "Clave Requerida" "Existen módulos cifrados. Introduzca la clave GPG global:") || return 1
        else
            passphrase="${PASSPHRASE:-$(ansi_view_password "Introduzca la clave GPG para módulos protegidos")}"
        fi
    fi

    local report
    report=$(restore_model_restore_all "$backup_dir" "$TARGET_USER_HOME" "$passphrase")
    ret=$?

    if [[ "$is_tui" == "true" ]]; then
        whiptail_view_msgbox "Restauración Total Finalizada" "Reporte de restauración global:\n\n$report"
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

    local id_type="${STORAGE_ID_TYPE:-LABEL}"
    local id_val="${STORAGE_ID_VALUE:-Desconocido}"

    if [[ "$is_tui" == "true" ]]; then
        local diag_txt="ESTADO DEL DISPOSITIVO / ALMACENAMIENTO:\n\n"
        diag_txt+="• Estado Global    : $status\n"
        diag_txt+="• Tipo de Búsqueda : $id_type\n"
        diag_txt+="• Identificador    : $id_val\n"
        diag_txt+="• Punto de Montaje : ${mount_point:-No encontrado}\n"
        diag_txt+="• Directorio Backup: ${backup_dir:-N/A}\n"
        diag_txt+="• Marcador SSD     : ${marker_path:-FALTA .backup_storage_marker}\n"
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
        ansi_view_key_value "TIPO DE ID" "$id_type"
        ansi_view_key_value "VALOR ID" "$id_val"
        ansi_view_key_value "PUNTO DE MONTAJE" "${mount_point:-No detectado}"
        ansi_view_key_value "DIRECTORIO BACKUP" "${backup_dir:-N/A}"
        ansi_view_key_value "MARCADOR SEGURIDAD" "${marker_path:-FALTA .backup_storage_marker}"
        ansi_view_key_value "ESPACIO DISPONIBLE" "${space_avail} de ${space_total}"
        ansi_view_key_value "USUARIO DESTINO" "$TARGET_USER_HOME"
    fi

    return "$ret"
}

# Inicialización de Destino de Almacenamiento
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

    if [[ -z "$subdir" ]]; then
        ansi_view_error "Debe especificar la subcarpeta a inicializar (ej: --init-target Backups/Personal_PC)."
        return 1
    fi

    local storage_root
    storage_root=$(device_model_find_mount "${STORAGE_ID_TYPE:-LABEL}" "${STORAGE_ID_VALUE:-DISCO_BACKUP}" "${STORAGE_STATIC_FALLBACK:-}") || true
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        local err_msg="No se pudo localizar el almacenamiento configurado (${STORAGE_ID_TYPE:-LABEL}=${STORAGE_ID_VALUE:-DISCO_BACKUP})."
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

    local storage_root
    storage_root=$(device_model_find_mount "${STORAGE_ID_TYPE:-LABEL}" "${STORAGE_ID_VALUE:-DISCO_BACKUP}" "${STORAGE_STATIC_FALLBACK:-}") || true
    if [[ -z "$storage_root" || ! -d "$storage_root" ]]; then
        local err_msg="No se pudo localizar el almacenamiento configurado (${STORAGE_ID_TYPE:-LABEL}=${STORAGE_ID_VALUE:-DISCO_BACKUP})."
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

    local storage_root
    storage_root=$(device_model_find_mount "${STORAGE_ID_TYPE:-LABEL}" "${STORAGE_ID_VALUE:-DISCO_BACKUP}" "${STORAGE_STATIC_FALLBACK:-}") || true

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
            "2" "Listar carpetas de equipo en el almacenamiento" \
            "3" "Cambiar carpeta de equipo activa (STORAGE_SUBDIR)" \
            "4" "Inicializar nueva carpeta de equipo en el almacenamiento" \
            "0" "Volver al Menú Principal") || return 0

        case "$choice" in
            1) _controller_show_device_diagnostics "true" ;;
            2) controller_handle_list_targets "true" ;;
            3) controller_handle_set_active_target "" "true" ;;
            4) controller_handle_init_target "" "false" "true" ;;
            0) return 0 ;;
        esac
    done
}

# 8. Asistente de Administración de Módulos y Etiquetas (TUI)
controller_handle_modules_admin() {
    local is_tui="${1:-true}"

    if [[ "$is_tui" != "true" ]]; then
        ansi_view_info "Para administrar módulos use los subcomandos de línea de órdenes."
        return 0
    fi

    while true; do
        local admin_choice
        admin_choice=$(whiptail_view_menu "Administración de Módulos y Etiquetas" "Seleccione una acción:" \
            "1" "Listar y ver detalle de módulos" \
            "2" "Crear un nuevo módulo" \
            "3" "Eliminar un módulo existente" \
            "4" "Añadir etiqueta al catálogo" \
            "0" "Volver al Menú Principal") || return 0

        case "$admin_choice" in
            1)
                local act_prof
                act_prof=$(_controller_get_active_profile)
                local all_mods
                all_mods=$(profile_model_list_modules "$act_prof" "$CONTROLLER_BASE_DIR") || true
                if [[ -z "$all_mods" ]]; then
                    whiptail_view_msgbox "Módulos" "No hay módulos registrados para el perfil activo ($act_prof)."
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
                # Asistente de creación
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

                local mod_paths_str
                mod_paths_str=$(whiptail_view_input "Rutas ($scope_desc)" "Rutas relativas a \$HOME separadas por espacio (ej: .config/app .apprc):") || continue

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

                local paths_arr=()
                read -r -a paths_arr <<< "$mod_paths_str"
                local tags_arr=()
                read -r -a tags_arr <<< "$sel_tags"

                local paths_joined=""
                for p in "${paths_arr[@]}"; do
                    [[ -n "$p" ]] || continue
                    if [[ -n "$paths_joined" ]]; then
                        paths_joined+="|$p"
                    else
                        paths_joined="$p"
                    fi
                done

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
            3)
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
            4)
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
            "5" "Eliminar un perfil" \
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
                            if [[ -f "${CONTROLLER_BASE_DIR}/modules.d/${m}.conf" ]]; then
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

    while true; do
        local act_prof
        act_prof=$(_controller_get_active_profile)
        local choice
        choice=$(whiptail_view_main_menu "$act_prof") || break

        case "$choice" in
            1) controller_handle_backup_all "true" "auto" ;;
            2) controller_handle_backup_tag "" "true" "auto" ;;
            3) controller_handle_backup_module "" "true" "auto" ;;
            4) controller_handle_restore_sensitive "true" ;;
            5) controller_handle_restore_module "" "" "true" ;;
            6) controller_handle_restore_all "true" ;;
            7) controller_handle_modules_admin "true" ;;
            8) controller_handle_device_check "true" ;;
            9) controller_handle_profiles_admin "true" ;;
            0) break ;;
            *) whiptail_view_error "Opción no reconocida" "La opción seleccionada no es válida." ;;
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
            *)
                ansi_view_error "Opción no reconocida: $1"
                echo "Ejecute '$0 --help' para ver las opciones disponibles."
                return 5
                ;;
        esac
    done

    case "$action" in
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
                    if [[ -f "${CONTROLLER_BASE_DIR}/profiles/${act_prof}/modules.d/${m}.conf" ]]; then
                        if [[ -f "${CONTROLLER_BASE_DIR}/modules.d/${m}.conf" ]]; then
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
