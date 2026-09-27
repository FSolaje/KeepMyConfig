#!/usr/bin/env bash
# ==============================================================================
# KeepMyConfig - Script de Desinstalación Limpia sin Privilegios (Non-Root)
#
# Retira los componentes instalados en el espacio de usuario:
# - Enlace ejecutable : ~/.local/bin/keepmyconfig
# - Lanzador XDG      : ~/.local/share/applications/keepmyconfig.desktop
# - Icono de escritorio: ~/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg
# - Directorio de app : ~/.local/share/KeepMyConfig (opcional / con --purge)
#
# Cumple con la especificación técnica SDD: specs/packaging_and_distribution/spec.md
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Paleta de Colores ANSI (Respetando NO_COLOR)
# ------------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    COLOR_RESET="\033[0m"
    COLOR_BOLD="\033[1m"
    COLOR_GREEN="\033[32m"
    COLOR_RED="\033[31m"
    COLOR_YELLOW="\033[33m"
    COLOR_CYAN="\033[36m"
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_GREEN=""
    COLOR_RED=""
    COLOR_YELLOW=""
    COLOR_CYAN=""
fi

log_info() {
    echo -e "${COLOR_CYAN}[INFO]${COLOR_RESET} $*"
}

log_success() {
    echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"
}

log_warning() {
    echo -e "${COLOR_YELLOW}[AVISO]${COLOR_RESET} $*"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

show_help() {
    cat << 'EOF'
Uso: ./uninstall.sh [OPCIONES]

Desinstalador para KeepMyConfig en el espacio de usuario (no requiere sudo).

Opciones:
  -y, --yes, --silent     Modo desatendido (no solicita confirmación interactiva)
  -p, --purge             Eliminar también la carpeta de aplicación y configuraciones
  -t, --target-dir <dir>  Directorio de instalación (por defecto: ~/.local/share/KeepMyConfig)
  -b, --bin-dir <dir>     Directorio de ejecutables (por defecto: ~/.local/bin)
  -h, --help              Mostrar esta ayuda y salir

Códigos de salida:
  0  Desinstalación completada con éxito
  1  Cancelación por el usuario o error
EOF
}

# ------------------------------------------------------------------------------
# Entrypoint Principal
# ------------------------------------------------------------------------------
main() {
    local TARGET_DIR="${HOME}/.local/share/KeepMyConfig"
    local BIN_DIR="${HOME}/.local/bin"
    local ICON_FILE="${HOME}/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg"
    local DESKTOP_FILE="${HOME}/.local/share/applications/keepmyconfig.desktop"
    local UNATTENDED=false
    local PURGE=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--silent)
                UNATTENDED=true
                shift 1
                ;;
            -p|--purge)
                PURGE=true
                shift 1
                ;;
            -t|--target-dir)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --target-dir"; exit 1; }
                TARGET_DIR="$2"
                shift 2
                ;;
            -b|--bin-dir)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --bin-dir"; exit 1; }
                BIN_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Opción desconocida: '$1'"
                show_help
                exit 1
                ;;
        esac
    done

    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}🗑️   KeepMyConfig - Desinstalador sin Privilegios${COLOR_RESET}"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"

    # Confirmación interactiva si no es modo desatendido
    if [[ "$UNATTENDED" == false ]]; then
        echo -e "¿Estás seguro de que deseas desinstalar KeepMyConfig?"
        read -r -p "Confirmar desinstalación [s/N]: " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            log_warning "Desinstalación cancelada por el usuario."
            exit 1
        fi

        if [[ "$PURGE" == false ]]; then
            echo ""
            echo -e "¿Deseas eliminar también las configuraciones y perfiles locales en '${TARGET_DIR}'?"
            read -r -p "Eliminar datos de aplicación (--purge) [s/N]: " purge_answer
            if [[ "$purge_answer" =~ ^[sS]$ ]]; then
                PURGE=true
            fi
        fi
    fi

    # 1. Retirar enlace en PATH
    local bin_link="${BIN_DIR}/keepmyconfig"
    if [[ -L "$bin_link" || -f "$bin_link" ]]; then
        rm -f "$bin_link"
        log_success "Enlace ejecutable eliminado: ${bin_link}"
    else
        log_info "No se encontró enlace ejecutable en: ${bin_link}"
    fi

    # 2. Retirar lanzador .desktop
    if [[ -f "$DESKTOP_FILE" ]]; then
        rm -f "$DESKTOP_FILE"
        log_success "Lanzador de escritorio eliminado: ${DESKTOP_FILE}"
        if command -v update-desktop-database >/dev/null 2>&1; then
            update-desktop-database "$(dirname "$DESKTOP_FILE")" >/dev/null 2>&1 || true
        fi
    else
        log_info "No se encontró lanzador de escritorio en: ${DESKTOP_FILE}"
    fi

    # 3. Retirar icono SVG
    if [[ -f "$ICON_FILE" ]]; then
        rm -f "$ICON_FILE"
        log_success "Icono de aplicación eliminado: ${ICON_FILE}"
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
        fi
    else
        log_info "No se encontró icono en: ${ICON_FILE}"
    fi

    # 4. Gestión del directorio de la aplicación
    if [[ "$PURGE" == true ]]; then
        if [[ -d "$TARGET_DIR" ]]; then
            chmod -R u+w "$TARGET_DIR" 2>/dev/null || true
            rm -rf "$TARGET_DIR"
            log_success "Directorio de aplicación y datos purgado completamente: ${TARGET_DIR}"
        fi
    else
        log_info "Directorio de aplicación preservado en: ${TARGET_DIR}"
        log_info "(Puedes eliminarlo manualmente o ejecutar './uninstall.sh --purge' si deseas borrar perfiles y configuraciones)."
    fi

    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    log_success "¡Desinstalación finalizada con éxito!"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
}

main "$@"
