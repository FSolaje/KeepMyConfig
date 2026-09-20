# Especificación de Requerimientos: `storage-target-init` y Almacenamiento Universal (`LOCAL_PATH`)

**Módulo:** `lib/models/device_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/storage-target-init`  
**Estado:** Aprobado para Implementación  
**Fecha:** 2026-09-20  

---

## 1. Propósito y Alcance

Esta especificación formaliza dos capacidades fundamentales para dotar a **BackupConfig** de máxima versatilidad:
1. **Soporte de Almacenamiento Universal (`LOCAL_PATH`)**: Capacidad de realizar respaldos en cualquier carpeta o disco del propio equipo (o carpetas de red montadas vía SSHFS/NFS/SMB), eliminando la restricción de exigir exclusivamente puntos de montaje de particiones externas de `lsblk`.
2. **Inicialización y Gestión de Perfiles de Destino (`storage-target-init`)**: Capacidad de crear, listar y seleccionar carpetas de backup por equipo (ej. `Backups/Personal_PC`, `Backups/Lliurex25`, `Backups/$(hostname)`), tanto desde la CLI como mediante asistente interactivo en la TUI, desplegando de forma transparente el marcador de seguridad y la estructura requerida.

---

## 2. Requerimientos Funcionales

### RF-1: Soporte de Almacenamiento Universal `LOCAL_PATH`
- **Configuración en `config/config.conf`:**
  ```bash
  STORAGE_ID_TYPE="LOCAL_PATH"
  STORAGE_ID_VALUE="/ruta/absoluta/a/carpeta"
  STORAGE_SUBDIR="Backups/MiEquipo" # (Opcional, puede ser vacío o subcarpeta)
  ```
- **Comportamiento en `device_model.sh`:**
  - `device_model_resolve_mountpoint`: Cuando `STORAGE_ID_TYPE="LOCAL_PATH"`, valida que `STORAGE_ID_VALUE` sea una ruta sintácticamente válida. Si la carpeta no existe, intenta crearla o verifica que su directorio padre sea escribible.
  - `device_model_validate_storage`: Si `STORAGE_ID_TYPE="LOCAL_PATH"`, **omite** la comprobación `device_model_is_mounted` (ya que no es una partición externa), pero **mantiene estrictamente**:
    1. Permisos de escritura (`device_model_check_writable`).
    2. Presencia del archivo testigo de seguridad (`device_model_check_marker`).
    3. Lectura de espacio total y disponible (`device_model_get_space`).

---

### RF-2: Función de Inicialización de Destino (`device_model_init_target_directory`)
- **Firma:**
  ```bash
  device_model_init_target_directory "$storage_root" "$subdir" ["$template_marker_path"]
  ```
- **Comportamiento:**
  1. Construye la ruta completa: si `subdir` no está vacío, `dest_dir="$storage_root/$subdir"`; de lo contrario, `dest_dir="$storage_root"`.
  2. Crea los directorios `archives/` y `logs/` dentro de `dest_dir`.
  3. Despliega el marcador de seguridad `.backup_storage_marker` llamando a `device_model_init_storage_marker`.
  4. Valida mediante `device_model_check_marker` que el archivo testigo esté operativo.
  5. Retorna `0` (`DEV_OK`) en éxito; código de error numérico si no hay permisos de escritura o falla la creación.

---

### RF-3: Función de Listado de Destinos (`device_model_list_targets`)
- **Firma:**
  ```bash
  device_model_list_targets "$storage_root"
  ```
- **Comportamiento:**
  1. Escanea el directorio `$storage_root` (hasta 3 niveles de profundidad) buscando archivos `.backup_storage_marker`.
  2. Emite por `stdout` las rutas relativas de las subcarpetas donde se encontraron marcadores válidos (ej. `Backups/Lliurex25`, `Backups/Personal_PC`).
  3. Si el marcador se encuentra en la propia raíz `$storage_root`, emite `.` (raíz).

---

### RF-4: Función de Actualización de Configuración (`device_model_update_config_subdir`)
- **Firma:**
  ```bash
  device_model_update_config_subdir "$config_file" "$new_subdir"
  ```
- **Comportamiento:**
  - Actualiza de forma atómica y segura el valor de `STORAGE_SUBDIR="..."` dentro de `config_file`.
  - Si la directiva no existía, la añade al final.

---

### RF-5: Opciones de Línea de Comandos (CLI)
- `--init-target <subdir>`: Inicializa la subcarpeta en el almacenamiento configurado (creando carpetas y marcador).
- `--set-default`: Flag modificador que fija el destino como activo en `config/config.conf`.
- `--target-subdir <subdir>`: Redirige temporalmente cualquier operación de backup o restore a esa subcarpeta para la invocación activa.
- `--list-targets`: Lista todos los perfiles de equipo y carpetas inicializadas con marcador en el soporte de almacenamiento.

---

### RF-6: Interfaz Gráfica TUI (`whiptail`)
En la **Opción 8 (`[CONFIG] Diagnóstico de Disco y Almacenamiento`)**:
- Presentar un submenú operativo con 4 opciones:
  1. `Ver diagnóstico de almacenamiento y espacio libre`
  2. `Listar carpetas/perfiles de equipo en el almacenamiento`
  3. `Cambiar carpeta de equipo activa (STORAGE_SUBDIR)`
  4. `Inicializar nueva carpeta de equipo en el almacenamiento` (asistente que sugiere `Backups/$(hostname)`).

---

## 3. Códigos de Retorno

| Código | Constante | Significado |
| :---: | :--- | :--- |
| `0` | `DEV_OK` | Destino inicializado o validado con éxito. |
| `1` | `DEV_ERR_CONFIG` | Parámetros inválidos o configuración corrupta. |
| `2` | `DEV_ERR_NOT_FOUND` | Almacenamiento o directorio base no encontrado. |
| `3` | `DEV_ERR_NOT_MOUNTED` | Dispositivo de partición no montado. |
| `4` | `DEV_ERR_NO_MARKER` | Marcador `.backup_storage_marker` ausente. |
| `5` | `DEV_ERR_NOT_WRITABLE`| Sin permisos de escritura en la ruta de destino. |
