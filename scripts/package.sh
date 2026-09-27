#!/usr/bin/env bash
# ==============================================================================
# KeepMyConfig - Script Reproducible de Empaquetado y Distribución Dual
#
# Genera paquetes oficiales reproducibles (.tar.gz y opcional .tar.zst) con
# estructura anti-tarbomb, normalización estricta de permisos UNIX, cálculo
# de sumas criptográficas SHA-256 y smoke test integrado de integridad.
#
# Soporta tanto la Edición Estándar (con instalador) como la Edición Portable
# (autónoma para dispositivos externos con marcador .portable y keepmyconfig.sh).
#
# Cumple con la especificación técnica SDD: specs/packaging_and_distribution/spec.md
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Detección de Rutas del Repositorio
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

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

# ------------------------------------------------------------------------------
# Ayuda de Uso y Documentación CLI
# ------------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
Uso: scripts/package.sh [OPCIONES]

Generador reproducible de archivos de distribución y sumas criptográficas SHA-256
para KeepMyConfig (Edición Estándar e Instalable y Edición Portable Autónoma).

Opciones:
  -v, --version <tag>     Especificar versión explícita (ej. v0.1.0-alpha.2)
  -o, --output-dir <dir>  Directorio destino de los artefactos (por defecto: dist/)
  -t, --type <tipo>       Tipo de paquete a generar: all, standard, portable (default: all)
  -c, --clean             Limpiar artefactos previos en el directorio de salida
  -s, --skip-tests        Omitir el smoke test posterior (no recomendado)
  -h, --help              Mostrar esta ayuda de uso y salir

Códigos de retorno:
  0  Empaquetado exitoso, sumas calculadas y smoke test superado
  1  Error en parámetros o argumentos inválidos
  2  Error de integridad (falta un archivo de la lista blanca en el repositorio)
  3  Fallo en la creación del archivo comprimido (tar)
  4  Fallo en el smoke test de validación del paquete
EOF
}

# ------------------------------------------------------------------------------
# Resolución y Validación de Versión SemVer
# ------------------------------------------------------------------------------
resolve_version() {
    local candidate=""
    if [[ -n "${CLI_VERSION:-}" ]]; then
        candidate="${CLI_VERSION}"
    else
        # 1. Intentar tag exacto en HEAD
        candidate="$(git -C "$REPO_ROOT" describe --tags --exact-match 2>/dev/null || true)"
        # 2. Si no hay tag exacto, intentar tag más reciente
        if [[ -z "$candidate" ]]; then
            candidate="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
        fi
        # 3. Si no hay git o no hay tags, consultar CHANGELOG.md
        if [[ -z "$candidate" ]] && [[ -f "$REPO_ROOT/CHANGELOG.md" ]]; then
            candidate="$(grep -m 1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+' "$REPO_ROOT/CHANGELOG.md" | sed -E 's/^## \[([^]]+)\].*/\1/' || true)"
        fi
        # 4. Fallback por defecto
        if [[ -z "$candidate" ]]; then
            candidate="v0.1.0-dev"
        fi
    fi

    # Normalizar prefijo 'v' si no lo incluye
    if [[ "$candidate" != v* ]]; then
        candidate="v${candidate}"
    fi

    # Validar formato SemVer 2.0.0
    if [[ ! "$candidate" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
        log_error "Formato de versión inválido: '${candidate}'. Debe seguir SemVer (ej. v0.1.0-alpha.2 o v1.0.0)."
        exit 1
    fi

    echo "$candidate"
}

# ------------------------------------------------------------------------------
# Verificación de Integridad de la Lista Blanca Base (FR-PKG-001)
# ------------------------------------------------------------------------------
check_whitelist_integrity() {
    local missing=0
    local required_core_files=(
        "backup_manager.sh"
        "lib"
        "config/config.conf"
        "config/default_tags.conf"
        "templates.d"
        "profiles/default/profile.conf"
        "markers/.backup_storage_marker"
        ".backup_app_marker"
        "assets/keepmyconfig.svg"
        "assets/keepmyconfig.desktop"
        "README.md"
        "MANUAL_USUARIO.md"
        "CHANGELOG.md"
        "LICENSE"
    )

    for item in "${required_core_files[@]}"; do
        if [[ ! -e "$REPO_ROOT/$item" ]]; then
            log_error "Falta archivo o directorio obligatorio de la lista blanca: '$item'"
            missing=1
        fi
    done

    if [[ $missing -ne 0 ]]; then
        log_error "Fallo de integridad: Faltan elementos esenciales en el repositorio para empaquetar."
        exit 2
    fi
}

# ------------------------------------------------------------------------------
# Preparación del Núcleo Común en Staging
# ------------------------------------------------------------------------------
_populate_core() {
    local target="$1"
    mkdir -p "$target"

    # Copiar entrypoint ejecutable
    cp "$REPO_ROOT/backup_manager.sh" "$target/"

    # Copiar librerías (MVC)
    cp -r "$REPO_ROOT/lib" "$target/"

    # Copiar configuración inicial limpia de fábrica
    mkdir -p "$target/config"
    cp "$REPO_ROOT/config/config.conf" "$target/config/"
    cp "$REPO_ROOT/config/default_tags.conf" "$target/config/"

    # Copiar catálogo de plantillas
    cp -r "$REPO_ROOT/templates.d" "$target/"

    # Copiar directorio modules.d limpio (sin recetas privadas o locales)
    mkdir -p "$target/modules.d"
    if [[ -f "$REPO_ROOT/modules.d/.gitkeep" ]]; then
        cp "$REPO_ROOT/modules.d/.gitkeep" "$target/modules.d/"
    else
        touch "$target/modules.d/.gitkeep"
    fi

    # Copiar perfil default físico canónico
    mkdir -p "$target/profiles/default/modules.d"
    cp "$REPO_ROOT/profiles/default/profile.conf" "$target/profiles/default/"
    touch "$target/profiles/default/modules.d/.gitkeep"

    # Copiar marcadores de seguridad
    mkdir -p "$target/markers"
    cp "$REPO_ROOT/markers/.backup_storage_marker" "$target/markers/"
    cp "$REPO_ROOT/.backup_app_marker" "$target/"

    # Copiar recursos gráficos y lanzador Freedesktop
    mkdir -p "$target/assets"
    cp "$REPO_ROOT/assets/keepmyconfig.svg" "$target/assets/"
    cp "$REPO_ROOT/assets/keepmyconfig.desktop" "$target/assets/"

    # Copiar documentación pública y licencia
    cp "$REPO_ROOT/README.md" "$target/"
    cp "$REPO_ROOT/MANUAL_USUARIO.md" "$target/"
    cp "$REPO_ROOT/CHANGELOG.md" "$target/"
    cp "$REPO_ROOT/LICENSE" "$target/"

    # Normalización básica de permisos UNIX
    find "$target" -type d -exec chmod 755 {} +
    find "$target" -type f -exec chmod 644 {} +
    chmod 755 "$target/backup_manager.sh"
}

# ------------------------------------------------------------------------------
# Preparación de la Edición Estándar / Instalable
# ------------------------------------------------------------------------------
populate_staging_standard() {
    local target="$1"
    log_info "Poblando staging para edición estándar en: $(basename "$target")..."
    _populate_core "$target"

    # Copiar scripts de instalación y desinstalación si están presentes
    for inst_file in "install.sh" "uninstall.sh"; do
        if [[ -f "$REPO_ROOT/$inst_file" ]]; then
            cp "$REPO_ROOT/$inst_file" "$target/"
            chmod 755 "$target/$inst_file"
        fi
    done
}

# ------------------------------------------------------------------------------
# Preparación de la Edición Portable Autónoma (FR-PKG-008)
# ------------------------------------------------------------------------------
populate_staging_portable() {
    local target="$1"
    log_info "Poblando staging para edición portable en: $(basename "$target")..."
    _populate_core "$target"

    # Desplegar marcador de entorno portable
    touch "$target/.portable"
    chmod 644 "$target/.portable"

    # Crear lanzador directo portable keepmyconfig.sh (compatible con FAT32/exFAT/NTFS)
    cat << 'EOF' > "$target/keepmyconfig.sh"
#!/usr/bin/env bash
# ==============================================================================
# KeepMyConfig - Lanzador Directo de la Edición Portable
# Permite ejecución inmediata 'plug-and-play' desde dispositivos externos.
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/backup_manager.sh" "$@"
EOF
    chmod 755 "$target/keepmyconfig.sh"
}

# ------------------------------------------------------------------------------
# Generación de Archivos Comprimidos (.tar.gz y .tar.zst)
# ------------------------------------------------------------------------------
build_archive_for_pkg() {
    local staging_tmp="$1"
    local pkg_name="$2"
    local out_dir="$3"

    log_info "Generando archivo comprimido: ${pkg_name}.tar.gz..."
    if ! tar -czf "${out_dir}/${pkg_name}.tar.gz" -C "$staging_tmp" "$pkg_name"; then
        log_error "Error crítico al crear el archivo .tar.gz para '${pkg_name}'."
        exit 3
    fi

    # Generar .tar.zst si zstd está disponible en el entorno
    if command -v zstd >/dev/null 2>&1; then
        log_info "Generando archivo comprimido de alta eficiencia: ${pkg_name}.tar.zst..."
        if ! tar --zstd -cf "${out_dir}/${pkg_name}.tar.zst" -C "$staging_tmp" "$pkg_name"; then
            log_warning "No se pudo generar .tar.zst con el comando zstd disponible para '${pkg_name}'. Omitiendo."
        fi
    fi
}

# ------------------------------------------------------------------------------
# Generación Unificada de Sumas Criptográficas SHA-256
# ------------------------------------------------------------------------------
generate_checksums() {
    local out_dir="$1"
    shift
    local packages=("$@")

    log_info "Calculando sumas criptográficas SHA-256 para los paquetes generados..."
    (
        cd "$out_dir" || exit 1
        local first=true
        for pkg in "${packages[@]}"; do
            if [[ "$first" == true ]]; then
                sha256sum "${pkg}.tar.gz" > SHA256SUMS.txt
                first=false
            else
                sha256sum "${pkg}.tar.gz" >> SHA256SUMS.txt
            fi

            if [[ -f "${pkg}.tar.zst" ]]; then
                sha256sum "${pkg}.tar.zst" >> SHA256SUMS.txt
            fi
        done
    )
    log_success "Sumas registradas en: ${out_dir}/SHA256SUMS.txt"
}

# ------------------------------------------------------------------------------
# Smoke Test Automatizado de Validación
# ------------------------------------------------------------------------------
run_smoke_test_for_package() {
    local pkg_name="$1"
    local out_dir="$2"
    local is_portable="$3"

    log_info "Ejecutando smoke test integrado para: ${pkg_name}..."
    local smoke_tmp
    smoke_tmp="$(mktemp -d /tmp/kmc_smoke_XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '$smoke_tmp'" RETURN

    # 1. Descomprimir .tar.gz en carpeta aislada
    if ! tar -xzf "${out_dir}/${pkg_name}.tar.gz" -C "$smoke_tmp"; then
        log_error "Smoke test: Fallo al descomprimir '${pkg_name}.tar.gz'."
        exit 4
    fi

    # 2. Comprobación Anti-Tarbomb (debe haber exactamente un único directorio raíz)
    local entries=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && entries+=("$line")
    done < <(find "$smoke_tmp" -mindepth 1 -maxdepth 1)

    if [[ ${#entries[@]} -ne 1 ]] || [[ "$(basename "${entries[0]}")" != "$pkg_name" ]]; then
        log_error "Smoke test: Violación anti-tarbomb detectada en '${pkg_name}'."
        exit 4
    fi

    local extracted_root="$smoke_tmp/$pkg_name"

    # 3. Comprobación de ejecutable y comandos --help
    if ! "$extracted_root/backup_manager.sh" --help >/dev/null 2>&1; then
        log_error "Smoke test: 'backup_manager.sh --help' falló en '${pkg_name}'."
        exit 4
    fi

    if [[ "$is_portable" == true ]]; then
        if ! "$extracted_root/keepmyconfig.sh" --help >/dev/null 2>&1; then
            log_error "Smoke test: 'keepmyconfig.sh --help' falló en la edición portable."
            exit 4
        fi
        if [[ ! -f "$extracted_root/.portable" ]]; then
            log_error "Smoke test: Falta el marcador '.portable' en la edición portable."
            exit 4
        fi
        if [[ -f "$extracted_root/install.sh" ]] || [[ -f "$extracted_root/uninstall.sh" ]]; then
            log_error "Smoke test: La edición portable no debe contener scripts de instalación (install.sh/uninstall.sh)."
            exit 4
        fi
    else
        if [[ -f "$extracted_root/.portable" ]]; then
            log_error "Smoke test: La edición estándar no debe contener el marcador '.portable'."
            exit 4
        fi
    fi

    # 4. Comprobación de archivos críticos del núcleo
    local critical_files=(
        ".backup_app_marker"
        "profiles/default/profile.conf"
        "templates.d/template-skeleton.conf"
        "markers/.backup_storage_marker"
        "config/config.conf"
        "config/default_tags.conf"
        "assets/keepmyconfig.svg"
        "assets/keepmyconfig.desktop"
        "README.md"
        "MANUAL_USUARIO.md"
        "CHANGELOG.md"
        "LICENSE"
    )
    for c_file in "${critical_files[@]}"; do
        if [[ ! -e "$extracted_root/$c_file" ]]; then
            log_error "Smoke test: Archivo crítico ausente en '${pkg_name}': '$c_file'."
            exit 4
        fi
    done

    # 5. Comprobación de Lista Negra (ausencia total de desarrollo/pruebas/temporales)
    local forbidden_items=(
        ".git"
        ".gitignore"
        ".github"
        ".agents"
        "specs"
        "tests"
        "user_data"
    )
    for f_item in "${forbidden_items[@]}"; do
        if [[ -e "$extracted_root/$f_item" ]]; then
            log_error "Smoke test: Archivo o carpeta de lista negra detectado en '${pkg_name}': '$f_item'."
            exit 4
        fi
    done

    local temp_files
    temp_files="$(find "$extracted_root" -type f \( -name "*.tmp" -o -name "*~" -o -name "*.bak" -o -name "*.swp" \) 2>/dev/null || true)"
    if [[ -n "$temp_files" ]]; then
        log_error "Smoke test: Archivos temporales no deseados detectados en '${pkg_name}': $temp_files"
        exit 4
    fi

    log_success "Smoke test superado para: ${pkg_name}."
}

# ------------------------------------------------------------------------------
# Entrypoint Principal
# ------------------------------------------------------------------------------
main() {
    local CLI_VERSION=""
    local OUTPUT_DIR=""
    local PACKAGE_TYPE="all"
    local DO_CLEAN=false
    local SKIP_TESTS=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --version"; exit 1; }
                CLI_VERSION="$2"
                shift 2
                ;;
            -o|--output-dir)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --output-dir"; exit 1; }
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -t|--type)
                [[ $# -lt 2 ]] && { log_error "Falta el valor para --type"; exit 1; }
                PACKAGE_TYPE="$2"
                shift 2
                ;;
            -c|--clean)
                DO_CLEAN=true
                shift 1
                ;;
            -s|--skip-tests)
                SKIP_TESTS=true
                shift 1
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

    if [[ "$PACKAGE_TYPE" != "all" && "$PACKAGE_TYPE" != "standard" && "$PACKAGE_TYPE" != "portable" ]]; then
        log_error "Tipo de paquete inválido: '$PACKAGE_TYPE'. Debe ser 'all', 'standard' o 'portable'."
        exit 1
    fi

    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="${REPO_ROOT}/dist"
    fi
    mkdir -p "$OUTPUT_DIR"

    # Resolver versión final
    local version
    version="$(resolve_version)"

    local std_name="KeepMyConfig-${version}"
    local port_name="KeepMyConfig-${version}-portable"

    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}📦  KeepMyConfig - Empaquetado y Distribución Oficial${COLOR_RESET}"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    log_info "Versión objetivo : ${COLOR_BOLD}${version}${COLOR_RESET}"
    log_info "Tipo de paquete  : ${COLOR_BOLD}${PACKAGE_TYPE}${COLOR_RESET}"
    log_info "Directorio salida: ${COLOR_BOLD}${OUTPUT_DIR}${COLOR_RESET}"

    # Limpiar artefactos previos si se solicitó --clean
    if [[ "$DO_CLEAN" == true ]]; then
        log_info "Limpiando artefactos previos en el directorio de salida..."
        rm -f "${OUTPUT_DIR}/KeepMyConfig-"*.tar.* "${OUTPUT_DIR}/SHA256SUMS.txt"
    fi

    # Verificar integridad de la lista blanca antes de proceder
    check_whitelist_integrity

    # Crear entorno de preparación temporal (staging)
    local staging_tmp
    staging_tmp="$(mktemp -d /tmp/kmc_pkg_XXXXXX)"
    # shellcheck disable=SC2064
    trap "rm -rf '$staging_tmp'" EXIT

    local packages_to_build=()

    # 1. Edición Estándar
    if [[ "$PACKAGE_TYPE" == "all" || "$PACKAGE_TYPE" == "standard" ]]; then
        populate_staging_standard "${staging_tmp}/${std_name}"
        build_archive_for_pkg "$staging_tmp" "$std_name" "$OUTPUT_DIR"
        packages_to_build+=("$std_name")
    fi

    # 2. Edición Portable
    if [[ "$PACKAGE_TYPE" == "all" || "$PACKAGE_TYPE" == "portable" ]]; then
        populate_staging_portable "${staging_tmp}/${port_name}"
        build_archive_for_pkg "$staging_tmp" "$port_name" "$OUTPUT_DIR"
        packages_to_build+=("$port_name")
    fi

    # 3. Generar sumas SHA-256
    generate_checksums "$OUTPUT_DIR" "${packages_to_build[@]}"

    # 4. Smoke test automatizado
    if [[ "$SKIP_TESTS" == false ]]; then
        for pkg in "${packages_to_build[@]}"; do
            local is_port=false
            [[ "$pkg" == *"-portable" ]] && is_port=true
            run_smoke_test_for_package "$pkg" "$OUTPUT_DIR" "$is_port"
        done

        # Verificación criptográfica global de SHA256SUMS.txt
        log_info "Validando sumas criptográficas con sha256sum -c..."
        if ! (cd "$OUTPUT_DIR" && sha256sum -c --status SHA256SUMS.txt); then
            log_error "Smoke test: La verificación global con 'sha256sum -c SHA256SUMS.txt' falló."
            exit 4
        fi
        log_success "Verificación criptográfica de SHA256SUMS.txt completada con éxito."
    else
        log_warning "Smoke tests omitidos por indicación de flag --skip-tests."
    fi

    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
    log_success "Empaquetado dual completado exitosamente: ${packages_to_build[*]}"
    log_info "Artefactos generados en: ${OUTPUT_DIR}"
    echo -e "${COLOR_BOLD}======================================================${COLOR_RESET}"
}

main "$@"
