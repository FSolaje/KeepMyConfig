#!/usr/bin/env bash
# ==============================================================================
# KeepMyConfig - Script de Instalación sin Privilegios (Non-Root)
#
# Despliega KeepMyConfig en el espacio de usuario cumpliendo los estándares XDG:
# - Directorio de aplicación : ~/.local/share/KeepMyConfig
# - Enlace ejecutable en PATH: ~/.local/bin/keepmyconfig
# - Lanzador de escritorio   : ~/.local/share/applications/keepmyconfig.desktop
# - Icono SVG escalable      : ~/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg
#
# Asistente de configuración inicial (OOBE):
# - Ruta de instalación personalizada (-t, --target-dir)
# - Destino global de backups (--backup-dest) con detección de unidades externas
# - Perfil inicial personalizado (--initial-profile)
#
# Cumple con la especificación técnica SDD: specs/packaging_and_distribution/spec.md
# ==============================================================================
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
Uso: ./install.sh [OPCIONES]

Instalador en espacio de usuario para KeepMyConfig (no requiere sudo).

Opciones:
  -y, --yes, --silent       Modo desatendido (no solicita confirmación interactiva)
  -f, --force               Sobrescribir configuraciones previas existentes
  -t, --target-dir <dir>    Directorio de instalación (por defecto: ~/.local/share/KeepMyConfig)
  -b, --bin-dir <dir>       Directorio de ejecutables (por defecto: ~/.local/bin)
  --backup-dest <dir>       Ruta de almacenamiento global para las copias de seguridad
  --initial-profile <name>  Nombre del perfil inicial a crear y activar (por defecto: default)
  -h, --help                Mostrar esta ayuda y salir

Códigos de salida:
  0  Instalación completada con éxito
  1  Error de permisos, directorios o cancelación por el usuario
  2  Dependencias faltantes del sistema no satisfechas
EOF
}

# ------------------------------------------------------------------------------
# Comprobación de Dependencias del Sistema (FR-PKG-004)
# ------------------------------------------------------------------------------
check_system_dependencies() {
    local missing_critical=()
    local missing_optional=()

    # Dependencias críticas indispensables
    local critical_deps=("bash" "tar" "gpg" "shred" "sha256sum")
    for dep in "${critical_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_critical+=("$dep")
        fi
    done

    if [[ ${#missing_critical[@]} -gt 0 ]]; then
        log_error "Dependencias críticas no encontradas en el sistema: ${missing_critical[*]}"
        log_error "Por favor, instala los paquetes requeridos antes de continuar."
        exit 2
    fi

    # Dependencias opcionales de alto rendimiento y TUI
    if ! command -v whiptail >/dev/null 2>&1; then
        missing_optional+=("whiptail (requerido para la interfaz gráfica de terminal TUI)")
    fi
    if ! command -v zstd >/dev/null 2>&1; then
        missing_optional+=("zstd (recomendado para compresión ultra-rápida)")
    fi

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warning "Componentes recomendados no detectados:"
        for opt in "${missing_optional[@]}"; do
            echo -e "  • ${COLOR_YELLOW}${opt}${COLOR_RESET}"
        done
        log_warning "La aplicación funcionará en modo consola CLI, pero se aconseja instalar las dependencias anteriores."
    fi
}

# ------------------------------------------------------------------------------
# Detección del Emulador de Terminal para el Lanzador .desktop (FR-PKG-005)
# ------------------------------------------------------------------------------
detect_terminal_emulator() {
    local term_exec="x-terminal-emulator -e keepmyconfig"

    if command -v x-terminal-emulator >/dev/null 2>&1; then
        term_exec="x-terminal-emulator -e keepmyconfig"
    elif command -v gnome-terminal >/dev/null 2>&1; then
        term_exec="gnome-terminal -- keepmyconfig"
    elif command -v ptyxis >/dev/null 2>&1; then
        term_exec="ptyxis -- keepmyconfig"
    elif command -v konsole >/dev/null 2>&1; then
        term_exec="konsole -e keepmyconfig"
    elif command -v xfce4-terminal >/dev/null 2>&1; then
        term_exec="xfce4-terminal -e keepmyconfig"
    elif command -v xterm >/dev/null 2>&1; then
        term_exec="xterm -e keepmyconfig"
    fi

    echo "$term_exec"
}

# ------------------------------------------------------------------------------
# Despliegue de Ficheros en el Directorio Destino
# ------------------------------------------------------------------------------
deploy_application_files() {
    local target_dir="$1"
    local force="$2"

    # Desbloquear permisos de escritura preventivamente por si se trata de una actualización
    chmod -R u+w "$target_dir" 2>/dev/null || true

    mkdir -p "$target_dir"
    mkdir -p "${target_dir}/config"
    mkdir -p "${target_dir}/modules.d"
    mkdir -p "${target_dir}/templates.d"
    mkdir -p "${target_dir}/profiles/default/modules.d"
    mkdir -p "${target_dir}/markers"
    mkdir -p "${target_dir}/assets"

    # 1. Entrypoint ejecutable y desinstalador
    cp "${SRC_DIR}/backup_manager.sh" "${target_dir}/backup_manager.sh"
    chmod 755 "${target_dir}/backup_manager.sh"

    if [[ -f "${SRC_DIR}/uninstall.sh" ]]; then
        cp "${SRC_DIR}/uninstall.sh" "${target_dir}/uninstall.sh"
        chmod 755 "${target_dir}/uninstall.sh"
    fi

    # 2. Librerías MVC
    cp -r "${SRC_DIR}/lib" "${target_dir}/"
    find "${target_dir}/lib" -type d -exec chmod 755 {} +
    find "${target_dir}/lib" -type f -exec chmod 644 {} +

    # 3. Configuración inicial (protección contra sobrescritura)
    if [[ ! -f "${target_dir}/config/config.conf" || "$force" == true ]]; then
        cp "${SRC_DIR}/config/config.conf" "${target_dir}/config/config.conf"
        chmod 644 "${target_dir}/config/config.conf"
    else
        log_info "Preservando configuración existente en: ${target_dir}/config/config.conf"
    fi

    if [[ ! -f "${target_dir}/config/default_tags.conf" || "$force" == true ]]; then
        cp "${SRC_DIR}/config/default_tags.conf" "${target_dir}/config/default_tags.conf"
        chmod 644 "${target_dir}/config/default_tags.conf"
    fi

    # 4. Catálogo de plantillas
    if [[ -d "${SRC_DIR}/templates.d" ]]; then
        cp -r "${SRC_DIR}/templates.d"/* "${target_dir}/templates.d/"
        find "${target_dir}/templates.d" -type f -exec chmod 644 {} +
    fi

    # 5. Perfil default canónico (preservando si existe)
    if [[ ! -f "${target_dir}/profiles/default/profile.conf" || "$force" == true ]]; then
        if [[ -f "${SRC_DIR}/profiles/default/profile.conf" ]]; then
            cp "${SRC_DIR}/profiles/default/profile.conf" "${target_dir}/profiles/default/profile.conf"
            chmod 644 "${target_dir}/profiles/default/profile.conf"
        fi
    fi

    # 6. Marcadores de seguridad e integridad
    if [[ -f "${SRC_DIR}/markers/.backup_storage_marker" ]]; then
        cp "${SRC_DIR}/markers/.backup_storage_marker" "${target_dir}/markers/.backup_storage_marker"
        chmod 644 "${target_dir}/markers/.backup_storage_marker"
    fi
    if [[ -f "${SRC_DIR}/.backup_app_marker" ]]; then
        cp "${SRC_DIR}/.backup_app_marker" "${target_dir}/.backup_app_marker"
        chmod 644 "${target_dir}/.backup_app_marker"
    fi

    # 7. Recursos gráficos
    if [[ -f "${SRC_DIR}/assets/keepmyconfig.svg" ]]; then
        cp "${SRC_DIR}/assets/keepmyconfig.svg" "${target_dir}/assets/"
        chmod 644 "${target_dir}/assets/keepmyconfig.svg"
    fi
    if [[ -f "${SRC_DIR}/assets/keepmyconfig.desktop" ]]; then
        cp "${SRC_DIR}/assets/keepmyconfig.desktop" "${target_dir}/assets/"
        chmod 644 "${target_dir}/assets/keepmyconfig.desktop"
    fi

    # 8. Documentación pública
    for doc in "README.md" "MANUAL_USUARIO.md" "CHANGELOG.md" "LICENSE"; do
        if [[ -f "${SRC_DIR}/${doc}" ]]; then
            cp "${SRC_DIR}/${doc}" "${target_dir}/${doc}"
            chmod 644 "${target_dir}/${doc}"
        fi
    done
}

# ------------------------------------------------------------------------------
# Configuración Inicial Personalizada (Destino de Backup y Perfil)
# ------------------------------------------------------------------------------
configure_initial_settings() {
    local target_dir="$1"
    local backup_dest="$2"
    local initial_profile="$3"

    local config_file="${target_dir}/config/config.conf"
    [[ -f "$config_file" ]] || return 0

    # 1. Configurar destino de backups si se especificó
    if [[ -n "$backup_dest" ]]; then
        # Expandir ~ si se utilizó
        backup_dest="${backup_dest/#\~/$HOME}"
        mkdir -p "$backup_dest"
        # Desplegar marcador de seguridad anti-escritura fantasma
        touch "${backup_dest}/.backup_storage_marker"
        chmod 644 "${backup_dest}/.backup_storage_marker"

        sed -i "s|^BACKUP_DESTINATION=.*|BACKUP_DESTINATION=\"${backup_dest}\"|" "$config_file"
        sed -i "s|^INITIAL_SETUP_DONE=.*|INITIAL_SETUP_DONE=\"true\"|" "$config_file"
        log_success "Destino de backups inicializado en: ${backup_dest}"
    fi

    # 2. Configurar perfil inicial si es distinto de default
    if [[ -n "$initial_profile" && "$initial_profile" != "default" ]]; then
        local prof_dir="${target_dir}/profiles/${initial_profile}"
        mkdir -p "${prof_dir}/modules.d"
        touch "${prof_dir}/modules.d/.gitkeep"

        cat << EOF > "${prof_dir}/profile.conf"
# ==============================================================================
# Configuración del Perfil: ${initial_profile}
# Creado durante la instalación inicial
# ==============================================================================
PROFILE_NAME="${initial_profile^}"
TARGET_SUBDIR=""
DISABLED_MODULES=()
EOF
        chmod 644 "${prof_dir}/profile.conf"

        sed -i "s|^ACTIVE_PROFILE=.*|ACTIVE_PROFILE=\"${initial_profile}\"|" "$config_file"
        log_success "Perfil inicial '${initial_profile}' creado y configurado como activo."
    fi
}

# ------------------------------------------------------------------------------
# Endurecimiento Preventivo de Permisos UNIX (Read-Only Hardening)
# ------------------------------------------------------------------------------
apply_security_hardening() {
    local target_dir="$1"
    log_info "Aplicando endurecimiento de permisos UNIX (solo lectura en código y librerías)..."

    # Ejecutables principales del core en solo lectura y ejecución
    chmod 0555 "${target_dir}/backup_manager.sh"
    if [[ -f "${target_dir}/uninstall.sh" ]]; then
        chmod 0555 "${target_dir}/uninstall.sh"
    fi

    # Librerías MVC en solo lectura
    find "${target_dir}/lib" -type d -exec chmod 0555 {} +
    find "${target_dir}/lib" -type f -exec chmod 0444 {} +

    # Catálogo de plantillas en solo lectura
    if [[ -d "${target_dir}/templates.d" ]]; then
        find "${target_dir}/templates.d" -type d -exec chmod 0555 {} +
        find "${target_dir}/templates.d" -type f -exec chmod 0444 {} +
    fi

    # Carpetas de datos mutables del usuario permanecen con permisos de escritura
    find "${target_dir}/config" -type d -exec chmod 0755 {} +
    find "${target_dir}/config" -type f -exec chmod 0644 {} +
    find "${target_dir}/modules.d" -type d -exec chmod 0755 {} +
    find "${target_dir}/modules.d" -type f -exec chmod 0644 {} +
    find "${target_dir}/profiles" -type d -exec chmod 0755 {} +
    find "${target_dir}/profiles" -type f -exec chmod 0644 {} +

    log_success "Blindaje de permisos UNIX completado."
}

# ------------------------------------------------------------------------------
# Configuración del Entorno XDG y Enlaces de Escritorio
# ------------------------------------------------------------------------------
setup_xdg_integration() {
    local target_dir="$1"
    local bin_dir="$2"
    local terminal_cmd="$3"

    # 1. Enlace en PATH (~/.local/bin/keepmyconfig)
    mkdir -p "$bin_dir"
    ln -sf "${target_dir}/backup_manager.sh" "${bin_dir}/keepmyconfig"
    log_success "Enlace ejecutable creado: ${bin_dir}/keepmyconfig -> ${target_dir}/backup_manager.sh"

    # 2. Instalación de Icono SVG escalable
    local icon_dir="${HOME}/.local/share/icons/hicolor/scalable/apps"
    mkdir -p "$icon_dir"
    if [[ -f "${target_dir}/assets/keepmyconfig.svg" ]]; then
        cp "${target_dir}/assets/keepmyconfig.svg" "${icon_dir}/keepmyconfig.svg"
        chmod 644 "${icon_dir}/keepmyconfig.svg"
        log_success "Icono de aplicación instalado en: ${icon_dir}/keepmyconfig.svg"
    fi

    # Actualizar caché de iconos si gtk-update-icon-cache está presente
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
    fi

    # 3. Instalación de Lanzador Freedesktop (.desktop)
    local app_dir="${HOME}/.local/share/applications"
    mkdir -p "$app_dir"
    local desktop_dest="${app_dir}/keepmyconfig.desktop"

    cat << EOF > "$desktop_dest"
[Desktop Entry]
Version=1.0
Type=Application
Name=KeepMyConfig
GenericName=Gestor de Backup y Recuperación
Comment=Copias de seguridad y recuperación modular para terminal
Exec=${terminal_cmd}
Icon=keepmyconfig
Terminal=true
Categories=Utility;Archiving;System;
Keywords=backup;copia;seguridad;lliurex;configuracion;
StartupNotify=false
EOF
    chmod 644 "$desktop_dest"
    log_success "Lanzador de escritorio instalado en: ${desktop_dest}"

    # Validar con desktop-file-validate si está presente
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$desktop_dest" >/dev/null 2>&1 || true
    fi

    # Actualizar base de datos de aplicaciones XDG si procede
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$app_dir" >/dev/null 2>&1 || true
    fi
}

# ------------------------------------------------------------------------------
# Comprobación de Variable $PATH y Asistencia al Usuario
# ------------------------------------------------------------------------------
audit_user_path() {
    local bin_dir="$1"

    # Comprobar si bin_dir forma parte de PATH
    case ":${PATH}:" in
        *":${bin_dir}:"*)
            log_success "El directorio '${bin_dir}' ya forma parte de tu \$PATH."
            ;;
        *)
            echo ""
            log_warning "El directorio '${bin_dir}' NO está incluido en tu variable \$PATH."
            echo -e "${COLOR_YELLOW}Para poder ejecutar 'keepmyconfig' directamente desde cualquier terminal, añade la siguiente línea a tu archivo ~/.bashrc:${COLOR_RESET}"
            echo -e "${COLOR_BOLD}  export PATH=\"${bin_dir}:\$PATH\"${COLOR_RESET}"
            echo ""
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Entrypoint Principal
# ------------------------------------------------------------------------------
main() {
    local TARGET_DIR="${HOME}/.local/share/KeepMyConfig"
    local BIN_DIR="${HOME}/.local/bin"
    local BACKUP_DEST=""
    local INITIAL_PROFILE="default"
    local UNATTENDED=false
    local FORCE=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes|--silent)
                UNATTENDED=true
                shift 1
                ;;
            -f|--force)
                FORCE=true
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
            --backup-dest)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --backup-dest"; exit 1; }
                BACKUP_DEST="$2"
                shift 2
                ;;
            --initial-profile|--profile)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --initial-profile"; exit 1; }
                INITIAL_PROFILE="$2"
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
    echo -e "${COLOR_BOLD}⚙️   KeepMyConfig - Instalador sin Privilegios (Non-Root)${COLOR_RESET}"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"

    # 1. Comprobar dependencias
    check_system_dependencies

    # 2. Asistente interactivo guiado (si no es modo desatendido)
    if [[ "$UNATTENDED" == false ]]; then
        echo ""
        read -r -p "¿Deseas proceder con la instalación en tu cuenta de usuario? [S/n]: " answer
        answer="${answer:-S}"
        if [[ ! "$answer" =~ ^[sS]$ ]]; then
            log_warning "Instalación cancelada por el usuario."
            exit 1
        fi

        # Paso 1: Ruta personalizada de la aplicación
        echo ""
        echo -e "${COLOR_BOLD}--- Paso 1: Ubicación de la Aplicación ---${COLOR_RESET}"
        read -r -p "Directorio de instalación [default: ${TARGET_DIR}]: " user_target
        if [[ -n "$user_target" ]]; then
            user_target="${user_target/#\~/$HOME}"
            TARGET_DIR="$user_target"
        fi

        # Paso 2: Destino global de las copias de seguridad
        if [[ -z "$BACKUP_DEST" ]]; then
            echo ""
            echo -e "${COLOR_BOLD}--- Paso 2: Destino Global de Copias de Seguridad ---${COLOR_RESET}"
            local ext_drives=()
            for d in /media/"$USER"/* /run/media/"$USER"/*; do
                [[ -d "$d" ]] && ext_drives+=("$d")
            done

            echo "Selecciona la ubicación predeterminada para tus respaldos:"
            echo "  [1] Ruta local estándar (~/Backups/KeepMyConfig)"
            local idx=2
            for d in "${ext_drives[@]}"; do
                echo "  [$idx] Unidad externa: $d/Backups/KeepMyConfig"
                ((idx++))
            done
            echo "  [p] Introducir otra ruta personalizada"
            echo "  [o] Omitir configuración (se solicitará al iniciar la aplicación)"
            read -r -p "Opción [1]: " dest_opt
            dest_opt="${dest_opt:-1}"

            case "$dest_opt" in
                1)
                    BACKUP_DEST="${HOME}/Backups/KeepMyConfig"
                    ;;
                [2-9]|[1-9][0-9])
                    local target_idx=$((dest_opt - 2))
                    if [[ $target_idx -ge 0 && $target_idx -lt ${#ext_drives[@]} ]]; then
                        BACKUP_DEST="${ext_drives[$target_idx]}/Backups/KeepMyConfig"
                    else
                        BACKUP_DEST="${HOME}/Backups/KeepMyConfig"
                    fi
                    ;;
                p|P)
                    read -r -p "Introduce la ruta para tus backups: " custom_dest
                    BACKUP_DEST="$custom_dest"
                    ;;
                o|O)
                    BACKUP_DEST=""
                    ;;
                *)
                    BACKUP_DEST="${HOME}/Backups/KeepMyConfig"
                    ;;
            esac
        fi

        # Paso 3: Perfil inicial
        if [[ "$INITIAL_PROFILE" == "default" ]]; then
            echo ""
            echo -e "${COLOR_BOLD}--- Paso 3: Perfil Inicial ---${COLOR_RESET}"
            echo "¿Deseas crear un perfil inicial específico (ej. 'docente', 'alumno', 'trabajo') o comenzar con 'default'?"
            read -r -p "Nombre del perfil inicial [default]: " user_prof
            user_prof="${user_prof:-default}"
            INITIAL_PROFILE="$user_prof"
        fi
    fi

    # Normalizar ruta de instalación
    TARGET_DIR="${TARGET_DIR/#\~/$HOME}"
    BIN_DIR="${BIN_DIR/#\~/$HOME}"

    # Validar identificador de perfil
    if [[ "$INITIAL_PROFILE" != "default" && ! "$INITIAL_PROFILE" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_warning "Identificador de perfil '$INITIAL_PROFILE' inválido. Usando 'default'."
        INITIAL_PROFILE="default"
    fi

    log_info "Ruta de instalación : ${COLOR_BOLD}${TARGET_DIR}${COLOR_RESET}"
    log_info "Directorio de binarios: ${COLOR_BOLD}${BIN_DIR}${COLOR_RESET}"
    if [[ -n "$BACKUP_DEST" ]]; then
        log_info "Destino de backups  : ${COLOR_BOLD}${BACKUP_DEST}${COLOR_RESET}"
    fi
    log_info "Perfil inicial      : ${COLOR_BOLD}${INITIAL_PROFILE}${COLOR_RESET}"

    # 3. Detectar comando de terminal
    local terminal_cmd
    terminal_cmd="$(detect_terminal_emulator)"
    log_info "Terminal detectada para escritorio: ${COLOR_BOLD}${terminal_cmd}${COLOR_RESET}"

    # 4. Desplegar ficheros de la aplicación
    log_info "Copiando componentes de KeepMyConfig..."
    deploy_application_files "$TARGET_DIR" "$FORCE"

    # 5. Configurar destino de backups y perfil inicial
    configure_initial_settings "$TARGET_DIR" "$BACKUP_DEST" "$INITIAL_PROFILE"

    # 6. Configurar integración XDG (PATH, icono y lanzador)
    log_info "Configurando integración con el escritorio..."
    setup_xdg_integration "$TARGET_DIR" "$BIN_DIR" "$terminal_cmd"

    # 7. Endurecimiento preventivo de permisos UNIX (Solo lectura en código)
    apply_security_hardening "$TARGET_DIR"

    # 8. Auditar PATH
    audit_user_path "$BIN_DIR"

    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    log_success "¡Instalación completada exitosamente!"
    echo -e "Puedes iniciar la aplicación ejecutando: ${COLOR_BOLD}keepmyconfig${COLOR_RESET}"
    echo -e "O abriendo 'KeepMyConfig' desde el menú de aplicaciones de tu escritorio."
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
}

main "$@"
