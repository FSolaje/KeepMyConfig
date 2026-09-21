#!/usr/bin/env bash
# ==============================================================================
# lib/models/device_model.sh - Modelo MVC para Identificación y Seguridad de Disco
# ==============================================================================
# Principio MVC: Este modelo contiene exclusivamente lógica de negocio.
# NO realiza salidas interactivas (whiptail/dialog) ni solicita entradas.
# Comunica resultados mediante códigos de retorno y pares clave=valor en stdout.
# ==============================================================================

# Códigos de retorno estandarizados
export DEV_OK=0
export DEV_ERR_CONFIG=1
export DEV_ERR_NOT_FOUND=2
export DEV_ERR_NOT_MOUNTED=3
export DEV_ERR_NO_MARKER=4
export DEV_ERR_NOT_WRITABLE=5

# ------------------------------------------------------------------------------
# Función: device_model_find_mount
# Descripción: Resuelve el punto de montaje del dispositivo de almacenamiento.
# Parámetros:
#   $1 - Tipo de identificación (LABEL, UUID, STATIC_PATH)
#   $2 - Valor del identificador (ej: DISCO_BACKUP, UUID, /ruta)
#   $3 - (Opcional) Ruta de fallback estática
# Salida stdout:
#   Punto de montaje resuelto si tiene éxito.
# Retorno:
#   0 si se encuentra montado, >0 si falla.
# ------------------------------------------------------------------------------
device_model_find_mount() {
    local id_type="${1:-}"
    local id_value="${2:-}"
    local fallback_path="${3:-}"
    local mountpoint=""

    if [[ -z "$id_type" || -z "$id_value" ]]; then
        return "$DEV_ERR_CONFIG"
    fi

    case "$id_type" in
        LABEL)
            # Intentar primero con findmnt
            mountpoint=$(findmnt -rn -S LABEL="$id_value" -o TARGET 2>/dev/null | head -n 1)
            # Si findmnt no retorna, probar con lsblk
            if [[ -z "$mountpoint" ]]; then
                mountpoint=$(lsblk -rno MOUNTPOINT,LABEL 2>/dev/null | awk -v lbl="$id_value" '$2 == lbl {print $1; exit}')
            fi
            ;;
        UUID)
            mountpoint=$(findmnt -rn -S UUID="$id_value" -o TARGET 2>/dev/null | head -n 1)
            if [[ -z "$mountpoint" ]]; then
                mountpoint=$(lsblk -rno MOUNTPOINT,UUID 2>/dev/null | awk -v u="$id_value" '$2 == u {print $1; exit}')
            fi
            ;;
        STATIC_PATH|LOCAL_PATH)
            if [[ -d "$id_value" ]]; then
                mountpoint="$id_value"
            elif [[ "$id_type" == "LOCAL_PATH" && -n "$id_value" ]]; then
                mkdir -p "$id_value" 2>/dev/null || true
                if [[ -d "$id_value" ]]; then
                    mountpoint="$id_value"
                fi
            fi
            ;;
        *)
            return "$DEV_ERR_CONFIG"
            ;;
    esac

    # Comprobar si se obtuvo un punto de montaje válido
    if [[ -n "$mountpoint" && -d "$mountpoint" ]]; then
        echo "$mountpoint"
        return "$DEV_OK"
    fi

    # Probar fallback si se especificó
    if [[ -n "$fallback_path" && -d "$fallback_path" ]]; then
        if mountpoint -q "$fallback_path" 2>/dev/null || [[ -d "$fallback_path" ]]; then
            echo "$fallback_path"
            return "$DEV_OK"
        fi
    fi

    return "$DEV_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: device_model_is_mounted
# Descripción: Comprueba si un directorio corresponde a un punto de montaje activo.
# Parámetros:
#   $1 - Ruta del punto de montaje a comprobar
# Retorno:
#   0 si es un punto de montaje activo, >0 en caso contrario.
# ------------------------------------------------------------------------------
device_model_is_mounted() {
    local mnt="${1:-}"
    [[ -n "$mnt" && -d "$mnt" ]] || return "$DEV_ERR_NOT_MOUNTED"

    if mountpoint -q "$mnt" 2>/dev/null; then
        return "$DEV_OK"
    fi

    # Comprobación alternativa mediante /proc/mounts
    if grep -qs " $mnt " /proc/mounts; then
        return "$DEV_OK"
    fi

    return "$DEV_ERR_NOT_MOUNTED"
}

# ------------------------------------------------------------------------------
# Función: device_model_check_marker
# Descripción: Valida la presencia del archivo marcador de seguridad.
# Parámetros:
#   $1 - Directorio objetivo (raíz del SSD o subcarpeta de backup)
#   $2 - Nombre del archivo marcador (ej: .backup_storage_marker)
# Salida stdout:
#   Ruta completa del marcador si se localiza.
# Retorno:
#   0 si existe y es legible, DEV_ERR_NO_MARKER si no existe.
# ------------------------------------------------------------------------------
device_model_check_marker() {
    local target_dir="${1:-}"
    local marker_name="${2:-.backup_storage_marker}"

    [[ -n "$target_dir" ]] || return "$DEV_ERR_CONFIG"

    local candidate="$target_dir/$marker_name"
    if [[ -f "$candidate" && -r "$candidate" ]]; then
        echo "$candidate"
        return "$DEV_OK"
    fi

    return "$DEV_ERR_NO_MARKER"
}

# ------------------------------------------------------------------------------
# Función: device_model_check_writable
# Descripción: Verifica si se tienen permisos de escritura en la ruta de destino.
# Parámetros:
#   $1 - Directorio a comprobar
# Retorno:
#   0 si es escribible, DEV_ERR_NOT_WRITABLE si no lo es.
# ------------------------------------------------------------------------------
device_model_check_writable() {
    local target_dir="${1:-}"
    [[ -n "$target_dir" ]] || return "$DEV_ERR_CONFIG"

    # Si el directorio existe, probar escritura
    if [[ -d "$target_dir" ]]; then
        if [[ -w "$target_dir" ]]; then
            # Test activo creando y borrando un archivo temporal
            local test_file="$target_dir/.write_test_$$"
            if touch "$test_file" 2>/dev/null; then
                rm -f "$test_file" 2>/dev/null
                return "$DEV_OK"
            fi
        fi
        return "$DEV_ERR_NOT_WRITABLE"
    fi

    # Si no existe aún, probar si el directorio padre es escribible
    local parent_dir
    parent_dir="$(dirname "$target_dir")"
    if [[ -d "$parent_dir" && -w "$parent_dir" ]]; then
        return "$DEV_OK"
    fi

    return "$DEV_ERR_NOT_WRITABLE"
}

# ------------------------------------------------------------------------------
# Función: device_model_get_space
# Descripción: Obtiene el espacio total, usado y libre del punto de montaje.
# Parámetros:
#   $1 - Ruta del punto de montaje o directorio dentro de él
# Salida stdout:
#   Línea con pares clave=valor:
#   SPACE_TOTAL_KB=... SPACE_USED_KB=... SPACE_FREE_KB=... SPACE_FREE_HUMAN=...
# ------------------------------------------------------------------------------
device_model_get_space() {
    local target_path="${1:-}"
    [[ -n "$target_path" && -e "$target_path" ]] || return "$DEV_ERR_CONFIG"

    local df_output
    df_output=$(df -Pk "$target_path" 2>/dev/null | tail -n 1)
    if [[ -z "$df_output" ]]; then
        return "$DEV_ERR_NOT_FOUND"
    fi

    local total_kb used_kb free_kb pct
    total_kb=$(echo "$df_output" | awk '{print $2}')
    used_kb=$(echo "$df_output" | awk '{print $3}')
    free_kb=$(echo "$df_output" | awk '{print $4}')
    pct=$(echo "$df_output" | awk '{print $5}')

    local free_human
    free_human=$(df -Ph "$target_path" 2>/dev/null | tail -n 1 | awk '{print $4}')

    echo "SPACE_TOTAL_KB=$total_kb SPACE_USED_KB=$used_kb SPACE_FREE_KB=$free_kb SPACE_PERCENT_USED=$pct SPACE_FREE_HUMAN=$free_human"
    return "$DEV_OK"
}

# ------------------------------------------------------------------------------
# Función: device_model_init_storage_marker
# Descripción: Inicializa el archivo testigo en el destino a partir de la plantilla.
# Parámetros:
#   $1 - Directorio destino donde colocar el marcador
#   $2 - Ruta de la plantilla (por defecto markers/.backup_storage_marker)
# Retorno:
#   0 si se creó con éxito, >0 si falló.
# ------------------------------------------------------------------------------
device_model_init_storage_marker() {
    local dest_dir="${1:-}"
    local template_path="${2:-}"

    [[ -n "$dest_dir" ]] || return "$DEV_ERR_CONFIG"
    mkdir -p "$dest_dir" 2>/dev/null || return "$DEV_ERR_NOT_WRITABLE"

    local dest_file="$dest_dir/.backup_storage_marker"
    if [[ -f "$dest_file" ]]; then
        return "$DEV_OK"
    fi

    if [[ -n "$template_path" && -f "$template_path" ]]; then
        cp "$template_path" "$dest_file" 2>/dev/null || return "$DEV_ERR_NOT_WRITABLE"
    else
        cat <<EOF > "$dest_file"
MARKER_TYPE="STORAGE_MARKER"
GENERATED_BY="device_model_init_storage_marker"
DATE="$(date -u +"%Y-%m-%d %H:%M:%SZ")"
EOF
    fi

    [[ -f "$dest_file" ]] && return "$DEV_OK"
    return "$DEV_ERR_NOT_WRITABLE"
}

# ------------------------------------------------------------------------------
# Función: device_model_sanitize_subdir
# Descripción: Sanitiza y normaliza un subdirectorio de almacenamiento eliminando
#              prefijos ($HOME, ~, /home/<usuario>), barras iniciales y bloqueando '..'.
# Parámetros:
#   $1 - Cadena de subdirectorio ingresada
# Salida stdout:
#   Subdirectorio relativo saneado (o cadena vacía si es raíz)
# Retorno:
#   0 en éxito, 1 si contiene '..' (inválido).
# ------------------------------------------------------------------------------
device_model_sanitize_subdir() {
    local raw_subdir="${1:-}"
    if [[ -z "$raw_subdir" ]]; then
        echo ""
        return 0
    fi

    local clean
    clean="$(echo "$raw_subdir" | xargs 2>/dev/null || echo "$raw_subdir")"
    if [[ -z "$clean" ]]; then
        echo ""
        return 0
    fi

    # Bloquear intentos de navegación hacia directorios superiores (..)
    if [[ "$clean" =~ (^|/)\.\.(/|$) ]]; then
        return 1
    fi

    # Eliminar prefijos de inicio: ${HOME}, $HOME, ~, /home/<usuario>
    clean=$(echo "$clean" | sed -E 's#^(\$\{HOME\}|\$HOME|~|/home/[^/]+)(/.*)?$#\2#')

    # Eliminar barras iniciales y finales
    clean=$(echo "$clean" | sed -E 's#^/+##')
    clean=$(echo "$clean" | sed -E 's#/+$##')

    # Reducir secuencias de múltiples barras internas a una sola
    clean=$(echo "$clean" | sed -E 's#/{2,}#/#g')

    if [[ "$clean" == "." ]]; then
        clean=""
    fi

    echo "$clean"
    return 0
}

# ------------------------------------------------------------------------------
# Función: device_model_validate_storage
# Descripción: Ejecuta la validación completa según un archivo de configuración.
# Parámetros:
#   $1 - Ruta al archivo config.conf (o usa variables de entorno ya cargadas)
# Salida stdout:
#   Salida estructurada clave=valor con el diagnóstico completo.
# Códigos de retorno:
#   0 - Disco verificado y listo
#   1 - Error de configuración
#   2 - Dispositivo no encontrado
#   3 - Dispositivo no montado
#   4 - Falta marcador de seguridad .backup_storage_marker
#   5 - Destino no escribible
# ------------------------------------------------------------------------------
device_model_validate_storage() {
    local config_file="${1:-}"
    local subdir_override="${2:-}"

    # Si se pasa un archivo de configuración existente, cargarlo
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
    fi

    local id_type="${STORAGE_ID_TYPE:-LABEL}"
    local id_value="${STORAGE_ID_VALUE:-DISCO_BACKUP}"
    local fallback="${STORAGE_STATIC_FALLBACK:-}"
    local raw_subdir="${subdir_override:-${STORAGE_SUBDIR:-Backups/Lliurex25}}"
    local subdir
    subdir=$(device_model_sanitize_subdir "$raw_subdir") || subdir=""
    local marker_name="${STORAGE_MARKER_FILE:-.backup_storage_marker}"

    # 1. Encontrar punto de montaje
    local mountpoint
    mountpoint=$(device_model_find_mount "$id_type" "$id_value" "$fallback")
    local find_status=$?

    if [[ $find_status -ne 0 || -z "$mountpoint" ]]; then
        echo "STATUS=DEVICE_NOT_FOUND"
        echo "ERROR_CODE=$DEV_ERR_NOT_FOUND"
        echo "MESSAGE=Dispositivo '$id_value' ($id_type) no encontrado en el sistema."
        return "$DEV_ERR_NOT_FOUND"
    fi

    # 2. Verificar que el punto de montaje está activo (salvo para LOCAL_PATH)
    if [[ "$id_type" != "LOCAL_PATH" ]]; then
        if ! device_model_is_mounted "$mountpoint"; then
            echo "STATUS=DEVICE_NOT_MOUNTED"
            echo "ERROR_CODE=$DEV_ERR_NOT_MOUNTED"
            echo "MOUNTPOINT=$mountpoint"
            echo "MESSAGE=La ruta '$mountpoint' no corresponde a un punto de montaje activo."
            return "$DEV_ERR_NOT_MOUNTED"
        fi
    fi

    # 3. Construir ruta de backup completa
    local backup_dir="$mountpoint"
    if [[ -n "$subdir" && "$subdir" != "." ]]; then
        backup_dir="$mountpoint/$subdir"
    fi

    # 4. Verificar marcador de seguridad con resolución jerárquica
    local marker_path=""
    local storage_verified=false

    if marker_path=$(device_model_check_marker "$backup_dir" "$marker_name"); then
        storage_verified=true
    elif marker_path=$(device_model_check_marker "$mountpoint" "$marker_name"); then
        storage_verified=true
        # Si el almacenamiento base es válido y backup_dir no tiene marcador pero el medio es escribible, auto-crear e inicializar
        if [[ ! -f "$backup_dir/$marker_name" && -w "$mountpoint" ]]; then
            mkdir -p "$backup_dir" 2>/dev/null || true
            device_model_init_storage_marker "$backup_dir" "$marker_path" 2>/dev/null || true
        fi
    elif device_model_list_targets "$mountpoint" "$marker_name" >/dev/null 2>&1; then
        # Hay al menos un destino previo en este almacenamiento: el medio es legítimo
        storage_verified=true
        if [[ -w "$mountpoint" ]]; then
            device_model_init_storage_marker "$mountpoint" "" 2>/dev/null || true
            mkdir -p "$backup_dir" 2>/dev/null || true
            device_model_init_storage_marker "$backup_dir" "$mountpoint/$marker_name" 2>/dev/null || true
        fi
    fi

    if [[ "$storage_verified" != "true" ]]; then
        echo "STATUS=STORAGE_MARKER_MISSING"
        echo "ERROR_CODE=$DEV_ERR_NO_MARKER"
        echo "MOUNTPOINT=$mountpoint"
        echo "BACKUP_DIR=$backup_dir"
        echo "MESSAGE=Marcador de seguridad '$marker_name' no encontrado en '$backup_dir' ni en '$mountpoint'."
        return "$DEV_ERR_NO_MARKER"
    fi

    # 5. Comprobar permisos de escritura
    if ! device_model_check_writable "$backup_dir"; then
        if [[ ! -d "$backup_dir" && -w "$mountpoint" ]]; then
            mkdir -p "$backup_dir" 2>/dev/null || true
            device_model_init_storage_marker "$backup_dir" "" 2>/dev/null || true
        fi
    fi

    if ! device_model_check_writable "$backup_dir"; then
        echo "STATUS=DESTINATION_NOT_WRITABLE"
        echo "ERROR_CODE=$DEV_ERR_NOT_WRITABLE"
        echo "MOUNTPOINT=$mountpoint"
        echo "BACKUP_DIR=$backup_dir"
        echo "MESSAGE=No hay permisos de escritura en '$backup_dir'."
        return "$DEV_ERR_NOT_WRITABLE"
    fi

    # 6. Obtener espacio disponible
    local space_info
    space_info=$(device_model_get_space "$mountpoint")

    # 7. Diagnóstico satisfactorio
    echo "STATUS=READY"
    echo "ERROR_CODE=$DEV_OK"
    echo "MOUNTPOINT=$mountpoint"
    echo "BACKUP_DIR=$backup_dir"
    echo "MARKER_PATH=$marker_path"
    echo "$space_info"
    echo "MESSAGE=Dispositivo verificado y listo para operaciones de respaldo/restauración."
    return "$DEV_OK"
}

# ------------------------------------------------------------------------------
# Función: device_model_init_target_directory
# Descripción: Inicializa la estructura completa de un destino de backup y su marcador.
# Parámetros:
#   $1 - Directorio base / punto de montaje ($storage_root)
#   $2 - (Opcional) Subdirectorio de destino (ej: Backups/Personal_PC)
#   $3 - (Opcional) Ruta de la plantilla del marcador
# Retorno:
#   0 en éxito, >0 si falló la creación o permisos.
# Salida stdout:
#   Ruta completa del directorio inicializado
# ------------------------------------------------------------------------------
device_model_init_target_directory() {
    local storage_root="${1:-}"
    local subdir="${2:-}"
    local template_path="${3:-}"

    [[ -n "$storage_root" ]] || return "$DEV_ERR_CONFIG"

    local target_dir="$storage_root"
    if [[ -n "$subdir" ]]; then
        target_dir="$storage_root/$subdir"
    fi

    mkdir -p "$target_dir/archives" "$target_dir/logs" 2>/dev/null || return "$DEV_ERR_NOT_WRITABLE"

    if ! device_model_init_storage_marker "$target_dir" "$template_path"; then
        return "$DEV_ERR_NOT_WRITABLE"
    fi

    if ! device_model_check_marker "$target_dir" >/dev/null 2>&1; then
        return "$DEV_ERR_NO_MARKER"
    fi

    echo "$target_dir"
    return "$DEV_OK"
}

# ------------------------------------------------------------------------------
# Función: device_model_list_targets
# Descripción: Busca y lista los subdirectorios que contienen un marcador válido.
# Parámetros:
#   $1 - Directorio base / punto de montaje ($storage_root)
# Salida stdout:
#   Una línea por cada subdirectorio encontrado (ruta relativa respecto a storage_root)
# Retorno:
#   0 si se listó con éxito, >0 si storage_root no existe.
# ------------------------------------------------------------------------------
device_model_list_targets() {
    local storage_root="${1:-}"
    local marker_name="${2:-.backup_storage_marker}"
    [[ -n "$storage_root" && -d "$storage_root" ]] || return "$DEV_ERR_CONFIG"

    local found=0

    # Comprobar la propia raíz
    if [[ -f "$storage_root/$marker_name" ]]; then
        echo "."
        found=1
    fi

    # Buscar en subdirectorios hasta profundidad 3
    while IFS= read -r marker_file; do
        [[ -n "$marker_file" ]] || continue
        local dir
        dir=$(dirname "$marker_file")
        [[ "$dir" == "$storage_root" ]] && continue
        # Obtener ruta relativa respecto a storage_root
        local rel_dir="${dir#$storage_root/}"
        echo "$rel_dir"
        found=1
    done < <(find "$storage_root" -maxdepth 3 -name "$marker_name" 2>/dev/null | sort -u)

    [[ $found -eq 1 ]] && return "$DEV_OK"
    return "$DEV_ERR_NOT_FOUND"
}

# ------------------------------------------------------------------------------
# Función: device_model_update_config_subdir
# Descripción: Actualiza atómicamente la variable STORAGE_SUBDIR en el config.
# Parámetros:
#   $1 - Ruta al archivo config.conf
#   $2 - Nuevo valor de subdirectorio (ej: Backups/Personal_PC)
# Retorno:
#   0 en éxito, >0 en caso de fallo.
# ------------------------------------------------------------------------------
device_model_update_config_subdir() {
    local config_file="${1:-}"
    local new_subdir="${2:-}"

    [[ -n "$config_file" && -f "$config_file" ]] || return "$DEV_ERR_CONFIG"

    local clean_sub
    clean_sub=$(device_model_sanitize_subdir "$new_subdir") || return "$DEV_ERR_CONFIG"
    new_subdir="$clean_sub"

    local temp_cfg="${config_file}.tmp.$$"
    if grep -q '^STORAGE_SUBDIR=' "$config_file"; then
        sed "s|^STORAGE_SUBDIR=.*|STORAGE_SUBDIR=\"$new_subdir\"|" "$config_file" > "$temp_cfg"
    else
        cp "$config_file" "$temp_cfg"
        echo "STORAGE_SUBDIR=\"$new_subdir\"" >> "$temp_cfg"
    fi

    mv -f "$temp_cfg" "$config_file"
    return "$DEV_OK"
}

