#!/usr/bin/env bash
# ==============================================================================
# Archivo: lib/views/ansi_view.sh
# Descripción: Vista de consola con formateo ANSI para CLI y modo desatendido.
# Arquitectura: Patrón MVC (Solo presentación, sin lógica de negocio).
# ==============================================================================

# Detección de colores según TTY y variables de entorno
ansi_view_colors_enabled() {
    if [[ -n "${NO_COLOR:-}" ]]; then
        return 1
    fi
    if [[ -t 1 ]] || [[ "${FORCE_COLOR:-0}" == "1" ]]; then
        return 0
    fi
    return 1
}

# Inicializar paleta ANSI
_ansi_view_init_palette() {
    if ansi_view_colors_enabled; then
        ANSI_RESET="\033[0m"
        ANSI_BOLD="\033[1m"
        ANSI_DIM="\033[2m"
        ANSI_RED="\033[0;31m"
        ANSI_GREEN="\033[0;32m"
        ANSI_YELLOW="\033[1;33m"
        ANSI_BLUE="\033[0;34m"
        ANSI_MAGENTA="\033[0;35m"
        ANSI_CYAN="\033[0;36m"
        ANSI_WHITE="\033[1;37m"
    else
        ANSI_RESET=""
        ANSI_BOLD=""
        ANSI_DIM=""
        ANSI_RED=""
        ANSI_GREEN=""
        ANSI_YELLOW=""
        ANSI_BLUE=""
        ANSI_MAGENTA=""
        ANSI_CYAN=""
        ANSI_WHITE=""
    fi
}

_ansi_view_init_palette

# Encabezado visual de sección o aplicación
ansi_view_header() {
    local title="${1:-KeepMyConfig}"
    _ansi_view_init_palette
    echo -e "${ANSI_CYAN}${ANSI_BOLD}======================================================================${ANSI_RESET}"
    echo -e "${ANSI_WHITE}${ANSI_BOLD}  ${title}${ANSI_RESET}"
    echo -e "${ANSI_CYAN}${ANSI_BOLD}======================================================================${ANSI_RESET}"
}

# Mensajes informativos y de estado
ansi_view_info() {
    local msg="${1:-}"
    _ansi_view_init_palette
    echo -e "${ANSI_BLUE}${ANSI_BOLD}[INFO]${ANSI_RESET} ${msg}"
}

ansi_view_success() {
    local msg="${1:-}"
    _ansi_view_init_palette
    echo -e "${ANSI_GREEN}${ANSI_BOLD}[OK]${ANSI_RESET} ${msg}"
}

ansi_view_warning() {
    local msg="${1:-}"
    _ansi_view_init_palette
    echo -e "${ANSI_YELLOW}${ANSI_BOLD}[AVISO]${ANSI_RESET} ${msg}"
}

ansi_view_error() {
    local msg="${1:-}"
    _ansi_view_init_palette
    echo -e "${ANSI_RED}${ANSI_BOLD}[ERROR]${ANSI_RESET} ${msg}" >&2
}

# Formateo clave - valor
ansi_view_key_value() {
    local key="${1:-}"
    local value="${2:-}"
    _ansi_view_init_palette
    printf "%b%-22s%b : %s\n" "${ANSI_BOLD}" "$key" "${ANSI_RESET}" "$value"
}

# Captura interactiva de entrada de texto
ansi_view_prompt() {
    local prompt_text="${1:-Introduce un valor}"
    local default_value="${2:-}"
    local answer=""
    _ansi_view_init_palette

    if [[ -n "$default_value" ]]; then
        echo -ne "${ANSI_WHITE}${ANSI_BOLD}[?] ${prompt_text}${ANSI_RESET} [${ANSI_YELLOW}${default_value}${ANSI_RESET}]: " >&2
    else
        echo -ne "${ANSI_WHITE}${ANSI_BOLD}[?] ${prompt_text}${ANSI_RESET}: " >&2
    fi

    read -r answer
    if [[ -z "$answer" && -n "$default_value" ]]; then
        echo "$default_value"
    else
        echo "$answer"
    fi
}

# Captura silenciosa de contraseña
ansi_view_password() {
    local prompt_text="${1:-Introduce la contraseña}"
    local password=""
    _ansi_view_init_palette

    echo -ne "${ANSI_YELLOW}${ANSI_BOLD}[🔒] ${prompt_text}${ANSI_RESET}: " >&2
    read -r -s password
    echo "" >&2

    echo "$password"
}

# Confirmación Sí/No interactiva
# Retorna 0 para Sí, 1 para No
ansi_view_confirm() {
    local question="${1:-¿Desea continuar?}"
    local default_yn="${2:-S}"
    local response=""
    _ansi_view_init_palette

    local prompt_suffix="[S/n]"
    if [[ "${default_yn^^}" == "N" ]]; then
        prompt_suffix="[s/N]"
    fi

    while true; do
        echo -ne "${ANSI_WHITE}${ANSI_BOLD}[?] ${question}${ANSI_RESET} ${ANSI_YELLOW}${prompt_suffix}${ANSI_RESET}: " >&2
        read -r response
        response="${response:-$default_yn}"
        case "${response,,}" in
            s|si|sí|y|yes)
                return 0
                ;;
            n|no)
                return 1
                ;;
            *)
                echo -e "${ANSI_RED}Respuesta no válida. Por favor responda 's' o 'n'.${ANSI_RESET}" >&2
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Función: ansi_view_preflight_table
# Descripción: Imprime la tabla resumen Pre-Flight en consola ANSI.
# Parámetros:
#   Líneas estructuradas: "ID|NOMBRE|AMBITO|SENS|PURGE|DESTINO"
# ------------------------------------------------------------------------------
ansi_view_preflight_table() {
    _ansi_view_init_palette
    echo -e "${ANSI_CYAN}${ANSI_BOLD}========================================================================================${ANSI_RESET}"
    echo -e "${ANSI_WHITE}${ANSI_BOLD}  MATRIZ PRE-FLIGHT DE SEGURIDAD (KeepMyConfig)${ANSI_RESET}"
    echo -e "${ANSI_CYAN}${ANSI_BOLD}========================================================================================${ANSI_RESET}"
    printf "${ANSI_BOLD}%-18s %-12s %-16s %-22s %s${ANSI_RESET}\n" "MÓDULO" "ÁMBITO" "CIFRADO GPG" "PURGA (SHRED -U)" "DESTINO"
    echo -e "${ANSI_DIM}----------------------------------------------------------------------------------------${ANSI_RESET}"

    for row in "$@"; do
        [[ -n "$row" ]] || continue
        local r_id r_name r_scope r_sens r_purge r_dest
        IFS='|' read -r r_id r_name r_scope r_sens r_purge r_dest <<< "$row"

        local purge_fmt="$r_purge"
        if [[ "$r_purge" =~ SÍ|SI|true|Activa ]]; then
            purge_fmt="\033[41;97;1m ¡PURGA ACTIVA! \033[0m"
        else
            purge_fmt="${ANSI_DIM}No${ANSI_RESET}"
        fi

        local sens_fmt="$r_sens"
        if [[ "$r_sens" =~ SÍ|SI|true ]]; then
            sens_fmt="${ANSI_YELLOW}SÍ (AES-256)${ANSI_RESET}"
        else
            sens_fmt="${ANSI_DIM}No${ANSI_RESET}"
        fi

        printf "%-18s %-12s %-26b %-32b %s\n" "$r_id" "$r_scope" "$sens_fmt" "$purge_fmt" "$r_dest"
    done
    echo -e "${ANSI_CYAN}${ANSI_BOLD}========================================================================================${ANSI_RESET}"
}

# ------------------------------------------------------------------------------
# Función: ansi_view_confirm_critical
# Descripción: Solicita confirmación explícita requiriendo teclear 'SI' en mayúsculas
# Parámetros:
#   $1 - Mensaje o pregunta de advertencia
# Retorno:
#   0 si escribe SI / SÍ, 1 en cualquier otro caso
# ------------------------------------------------------------------------------
ansi_view_confirm_critical() {
    local prompt_msg="${1:-Para autorizar esta acción destructiva, escriba 'SI' en mayúsculas y pulse ENTER}"
    _ansi_view_init_palette
    echo -ne "\033[41;97;1m [ATENCIÓN REQUERIDA] \033[0m ${ANSI_BOLD}${prompt_msg}:${ANSI_RESET} " >&2
    local answer=""
    read -r answer
    if [[ "$answer" == "SI" || "$answer" == "SÍ" ]]; then
        return 0
    else
        return 1
    fi
}

