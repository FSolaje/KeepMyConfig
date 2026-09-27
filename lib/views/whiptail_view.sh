#!/usr/bin/env bash
# ==============================================================================
# Archivo: lib/views/whiptail_view.sh
# Descripción: Vista interactiva TUI basada en diálogos whiptail.
# Arquitectura: Patrón MVC (Solo presentación, sin lógica de negocio).
# ==============================================================================

[[ -n "${_WHIPTAIL_VIEW_LOADED:-}" ]] && return 0
_WHIPTAIL_VIEW_LOADED=1

# Códigos de retorno estándar de la vista
readonly VIEW_OK=0
readonly VIEW_CANCEL=1
readonly VIEW_ESC=255
readonly VIEW_ERR_DEPENDENCY=10
readonly VIEW_ERR_PARAM=11

# Verificar disponibilidad de la utilidad whiptail
whiptail_view_check_deps() {
    if ! command -v whiptail &>/dev/null; then
        return "$VIEW_ERR_DEPENDENCY"
    fi
    return "$VIEW_OK"
}

# Calcular dimensiones de ventana adaptativas según la terminal
whiptail_view_calc_dimensions() {
    local lines
    local cols

    lines=$(tput lines 2>/dev/null || echo 24)
    cols=$(tput cols 2>/dev/null || echo 80)

    # Validar que sean enteros positivos
    [[ "$lines" =~ ^[0-9]+$ ]] || lines=24
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80

    # Dimensiones para la caja
    if (( lines < 24 )); then
        WT_HEIGHT=18
    else
        WT_HEIGHT=$(( lines - 4 ))
        if (( WT_HEIGHT > 26 )); then
            WT_HEIGHT=26
        fi
    fi

    if (( cols < 80 )); then
        WT_WIDTH=70
    else
        WT_WIDTH=$(( cols - 6 ))
        if (( WT_WIDTH > 90 )); then
            WT_WIDTH=90
        fi
    fi

    WT_LIST_HEIGHT=$(( WT_HEIGHT - 8 ))
    if (( WT_LIST_HEIGHT < 5 )); then
        WT_LIST_HEIGHT=5
    fi
    return "$VIEW_OK"
}

# Diálogo informativo estándar (--msgbox)
whiptail_view_msgbox() {
    local title="${1:-Información}"
    local message="${2:-}"

    whiptail_view_calc_dimensions
    whiptail --title "$title" --msgbox "$message" "$WT_HEIGHT" "$WT_WIDTH"
    return $?
}

# Diálogo de error (--msgbox con indicador visual de alerta)
whiptail_view_error() {
    local title="${1:-Error}"
    local message="${2:-Ha ocurrido un error inesperado.}"

    whiptail_view_calc_dimensions
    whiptail --title "⚠️  $title" --msgbox "$message" "$WT_HEIGHT" "$WT_WIDTH"
    return $?
}

# Diálogo de confirmación (--yesno)
# Retorna 0 para "Sí", 1 para "No" o Cancelar
whiptail_view_yesno() {
    local title="${1:-Confirmación}"
    local question="${2:-¿Desea continuar?}"

    whiptail_view_calc_dimensions
    whiptail --title "$title" --yesno "$question" "$WT_HEIGHT" "$WT_WIDTH"
    return $?
}

# Diálogo de confirmación crítica con foco predeterminado obligatorio en NO (--defaultno)
# Retorna 0 si el usuario pulsa deliberadamente "Sí", 1 si pulsa "No" o Cancelar
whiptail_view_confirm_critical() {
    local title="${1:-¡Alerta de Seguridad!}"
    local question="${2:-¿Está seguro de continuar?}"

    whiptail_view_calc_dimensions
    whiptail --title "⚠️  $title" --defaultno --yesno "$question" "$WT_HEIGHT" "$WT_WIDTH"
    return $?
}

# Diálogo Pre-Flight de Seguridad con resumen de módulos a procesar
whiptail_view_preflight_summary() {
    local title="${1:-Pre-Flight Safety Gate}"
    local summary_text="${2:-¿Desea continuar con la operación?}"

    whiptail_view_calc_dimensions
    whiptail --title "🛡️  $title" --yesno "$summary_text" "$WT_HEIGHT" "$WT_WIDTH"
    return $?
}

# Cuadro de entrada de texto simple (--inputbox)
whiptail_view_input() {
    local title="${1:-Entrada de datos}"
    local prompt="${2:-Introduzca el valor:}"
    local default_val="${3:-}"
    local result=""
    local status=0

    whiptail_view_calc_dimensions
    result=$(whiptail --title "$title" --inputbox "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$default_val" 3>&1 1>&2 2>&3)
    status=$?

    if (( status == 0 )); then
        echo "$result"
        return "$VIEW_OK"
    fi
    return "$VIEW_CANCEL"
}

# Captura de contraseña (--passwordbox) sin exponer caracteres
whiptail_view_password() {
    local title="${1:-Autenticación Requerida}"
    local prompt="${2:-Introduzca la contraseña GPG para cifrar/descifrar:}"
    local password=""
    local status=0

    whiptail_view_calc_dimensions
    password=$(whiptail --title "$title" --passwordbox "$prompt" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    status=$?

    if (( status == 0 )); then
        echo "$password"
        return "$VIEW_OK"
    fi
    return "$VIEW_CANCEL"
}

# Captura de contraseña con doble confirmación (útil al crear o cifrar)
whiptail_view_password_confirm() {
    local title="${1:-Definir Contraseña GPG}"
    local prompt="${2:-Introduzca la contraseña:}"
    local pass1=""
    local pass2=""

    pass1=$(whiptail_view_password "$title" "$prompt") || return "$VIEW_CANCEL"

    if [[ -z "$pass1" ]]; then
        whiptail_view_error "$title" "La contraseña no puede estar vacía."
        return "$VIEW_CANCEL"
    fi

    pass2=$(whiptail_view_password "$title" "Confirme la contraseña:") || return "$VIEW_CANCEL"

    if [[ "$pass1" != "$pass2" ]]; then
        whiptail_view_error "$title" "Las contraseñas introducidas no coinciden."
        return "$VIEW_CANCEL"
    fi

    echo "$pass1"
    return "$VIEW_OK"
}

# Menú Principal del Gestor de Backup y Recuperación
whiptail_view_main_menu() {
    local profile_name="${1:-}"
    local is_sandbox="${2:-${IS_SANDBOX_MODE:-false}}"
    local title="KeepMyConfig - Gestor de Backup y Recuperación"
    if [[ "$is_sandbox" == "true" ]]; then
        if [[ -n "$profile_name" ]]; then
            title="KeepMyConfig [SANDBOX] [Perfil: $profile_name]"
        else
            title="KeepMyConfig [SANDBOX]"
        fi
    elif [[ -n "$profile_name" ]]; then
        title="KeepMyConfig [Perfil: $profile_name]"
    fi
    local prompt="Seleccione la operación que desea realizar:"
    local choice=""
    local status=0

    whiptail_view_calc_dimensions

    choice=$(whiptail --title "$title" --menu "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" \
        "1" "[BACKUP]   Realizar Backup Completo" \
        "2" "[BACKUP]   Realizar Backup por Etiquetas (Tags)" \
        "3" "[BACKUP]   Realizar Backup por Módulo Individual" \
        "4" "[RESTORE]  Restauración Rápida de Datos Sensibles" \
        "5" "[RESTORE]  Restauración Selectiva (Módulo / Histórico)" \
        "6" "[RESTORE]  Restauración Total" \
        "7" "[MODULES]  Administrar Módulos y Etiquetas" \
        "8" "[STORAGE]  Gestión de Almacenamiento y Diagnóstico" \
        "9" "[PROFILES] Gestión de Perfiles de Backup" \
        "0" "[SALIR]    Salir del gestor" \
        3>&1 1>&2 2>&3)
    status=$?

    if (( status == 0 )); then
        echo "$choice"
        return "$VIEW_OK"
    fi
    return "$VIEW_CANCEL"
}

# Menú genérico de selección única (--menu)
whiptail_view_menu() {
    local title="${1:-Selección}"
    local prompt="${2:-Elija una opción:}"
    shift 2
    local choice=""
    local status=0

    whiptail_view_calc_dimensions
    choice=$(whiptail --title "$title" --menu "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" "$@" 3>&1 1>&2 2>&3)
    status=$?

    if (( status == 0 )); then
        echo "$choice"
        return "$VIEW_OK"
    fi
    return "$VIEW_CANCEL"
}

# Lista de casillas de verificación múltiple (--checklist)
# Recibe: title, prompt, tag1, item1, status1, [tag2, item2, status2, ...]
# Retorna en stdout las etiquetas seleccionadas limpias (sin comillas escapadas)
whiptail_view_checklist() {
    local title="${1:-Selección múltiple}"
    local prompt="${2:-Marque con espacio las opciones y pulse Aceptar:}"
    shift 2
    local raw_selection=""
    local status=0

    whiptail_view_calc_dimensions
    raw_selection=$(whiptail --title "$title" --checklist "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" "$@" 3>&1 1>&2 2>&3)
    status=$?

    if (( status == 0 )); then
        # Normalizar salida eliminando comillas dobles y espacios redundantes
        local clean_selection
        clean_selection=$(echo "$raw_selection" | tr -d '"' | xargs)
        echo "$clean_selection"
        return "$VIEW_OK"
    fi
    return "$VIEW_CANCEL"
}

# Selección única excluyente (--radiolist)
whiptail_view_radiolist() {
    local title="${1:-Selección}"
    local prompt="${2:-Seleccione una opción:}"
    shift 2
    local raw_selection=""
    local status=0

    whiptail_view_calc_dimensions
    raw_selection=$(whiptail --title "$title" --radiolist "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$WT_LIST_HEIGHT" "$@" 3>&1 1>&2 2>&3)
    status=$?

    if (( status == 0 )); then
        local clean_selection
        clean_selection=$(echo "$raw_selection" | tr -d '"' | xargs)
        echo "$clean_selection"
        return "$VIEW_OK"
    fi
    return "$VIEW_CANCEL"
}

# Visor de archivos con scroll (--textbox)
whiptail_view_textbox() {
    local title="${1:-Visor de Documentos}"
    local filepath="${2:-}"

    if [[ ! -f "$filepath" ]]; then
        whiptail_view_error "$title" "El archivo especificado no existe:\n$filepath"
        return "$VIEW_ERR_PARAM"
    fi

    whiptail_view_calc_dimensions
    whiptail --title "$title" --textbox "$filepath" "$WT_HEIGHT" "$WT_WIDTH" --scrolltext
    return $?
}

# Barra de progreso basada en pipe (--gauge)
# Ejemplo de uso:
#   whiptail_view_gauge "Copiando" "Progreso de la operación..." 0 < <(for i in 25 50 75 100; do echo $i; sleep 1; done)
whiptail_view_gauge() {
    local title="${1:-Operación en Curso}"
    local prompt="${2:-Por favor espere...}"
    local initial_pct="${3:-0}"

    whiptail_view_calc_dimensions
    whiptail --title "$title" --gauge "$prompt" "$WT_HEIGHT" "$WT_WIDTH" "$initial_pct"
    return $?
}

# Captura interactiva de rutas línea a línea (Enter confirma y añade a la lista)
# Retorna en stdout las rutas acumuladas separadas por '|'
whiptail_view_input_paths() {
    local title="${1:-Definir Rutas del Módulo}"
    local context_desc="${2:-}"
    local accumulated_paths=()

    whiptail_view_calc_dimensions

    while true; do
        local count=${#accumulated_paths[@]}
        local msg="Orientación sobre rutas de respaldo:\n"
        msg+="• Las rutas se procesan relativas al directorio personal (\$HOME).\n"
        msg+="• Se admiten relativas (ej: .config/app) o completas (\$HOME/.config/app, ~/.config/app).\n"
        msg+="• El sistema las normaliza automáticamente para asegurar su portabilidad.\n\n"

        if [[ -n "$context_desc" ]]; then
            msg+="Receta: $context_desc\n\n"
        fi

        if (( count > 0 )); then
            msg+="Rutas añadidas ($count):\n"
            local max_display=6
            local start_idx=0
            if (( count > max_display )); then
                start_idx=$(( count - max_display ))
                msg+="  [... $start_idx rutas previas omitidas en vista ...]\n"
            fi
            for (( i=start_idx; i<count; i++ )); do
                msg+="  $(( i + 1 )). ${accumulated_paths[i]}\n"
            done
            msg+="\n"
            msg+="• Escriba otra ruta y pulse Enter / Aceptar para añadirla.\n"
            msg+="• Deje en blanco y pulse Enter / Aceptar para FINALIZAR la lista.\n"
            msg+="• Pulse Cancelar para finalizar o descartar."
        else
            msg+="(Aún no se ha añadido ninguna ruta)\n\n"
            msg+="• Escriba la primera ruta y pulse Enter / Aceptar para añadirla.\n"
            msg+="• Pulse Cancelar para cancelar el asistente."
        fi

        local current_input=""
        local status=0
        current_input=$(whiptail --title "$title" --inputbox "$msg" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
        status=$?

        if (( status == 0 )); then
            local clean_input
            clean_input=$(echo "$current_input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [[ -n "$clean_input" ]]; then
                accumulated_paths+=("$clean_input")
            else
                if (( count > 0 )); then
                    break
                else
                    whiptail_view_error "$title" "Debe introducir al menos una ruta para continuar."
                fi
            fi
        else
            if (( count > 0 )); then
                if whiptail_view_yesno "$title" "Ha introducido $count ruta(s). ¿Desea guardarlas y continuar? (Seleccione 'No' para descartar y cancelar)."; then
                    break
                else
                    return "$VIEW_CANCEL"
                fi
            else
                return "$VIEW_CANCEL"
            fi
        fi
    done

    local joined=""
    for p in "${accumulated_paths[@]}"; do
        if [[ -n "$joined" ]]; then
            joined+="|$p"
        else
            joined="$p"
        fi
    done

    echo "$joined"
    return "$VIEW_OK"
}

