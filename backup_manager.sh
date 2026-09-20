#!/usr/bin/env bash
# ==============================================================================
# BackupConfig - Gestor de Respaldo y Recuperación Modular en Bash (MVC)
# Entorno objetivo: Lliurex 25 / Ubuntu 24.04 (Sin privilegios de root)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validar integridad del árbol de la aplicación
if [[ ! -f "${SCRIPT_DIR}/.backup_app_marker" ]]; then
    echo "ERROR: Directorio de aplicación inválido o incompleto (.backup_app_marker ausente)." >&2
    exit 1
fi

# Cargar el orquestador MVC
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/controllers/app_controller.sh"

# Inicializar controlador con el directorio base
controller_init "$SCRIPT_DIR"

# Enrutamiento de interfaz: TUI si no hay argumentos y hay terminal interactiva, CLI en caso contrario
if (( $# == 0 )); then
    if [[ -t 0 && -t 1 ]] && command -v whiptail &>/dev/null; then
        controller_run_tui
    else
        controller_run_cli --help
    fi
else
    controller_run_cli "$@"
fi
