# Especificación de Requerimientos: Gestor Robusto de Rutas, Prevención de Duplicación e Inicialización de Almacenamiento en Perfiles

> **Módulo:** Core / Device Model / Profile Model / App Controller  
> **Rama GitFlow:** `dev/fix/path-manager-and-profile-storage-init`  
> **Tipo:** Corrección Crítica de Arquitectura y Seguridad (Bugfix / Hardening)  
> **Fecha:** 2026-09-28  
> **Estado:** Propuesta Formal SDD  

---

## 1. Justificación y Análisis de Amenazas / Causa Raíz

En pruebas de campo en un equipo ajeno con unidad externa (`/media/usuario/SSD_BACKUP/Backups`), se han detectado dos fallos críticos en la experiencia de usuario y en la gestión de rutas de almacenamiento:

### 1.1 Causa Raíz 1: Duplicación Anidada de Rutas (`/media/usuario/...//media/usuario/...`)
- **Comportamiento anómalo observado:**  
  Al crear un nuevo perfil (`PC_Laboratorio`) y asignarle como destino `/media/usuario/SSD_BACKUP/Backups`, la ruta final calculada para el backup resultó ser:
  ```text
  /media/usuario/SSD_BACKUP/Backups//media/usuario/SSD_BACKUP/Backups
  ```
- **Origen técnico:**  
  1. El diálogo interactivo de creación de perfil en `lib/controllers/app_controller.sh` invita al usuario a introducir una ruta absoluta o `~`.
  2. La función `profile_model_sanitize_target_subdir` en `lib/models/profile_model.sh` elimina sistemáticamente la barra inicial (`sed -E 's#^/+##'`) bajo la asunción de que `TARGET_SUBDIR` siempre debe ser relativo a `BACKUP_DESTINATION`.
  3. Esto transformó `/media/usuario/SSD_BACKUP/Backups` en `media/usuario/SSD_BACKUP/Backups`.
  4. Durante la ejecución del backup, `device_model_validate_storage` y `_controller_get_backup_dir` concatenaron el destino base global (`/media/usuario/SSD_BACKUP/Backups`) con la subcarpeta saneada (`media/usuario/SSD_BACKUP/Backups`), duplicando el prefijo.
  5. La verificación jerárquica de `.backup_storage_marker` encontró el marcador en la carpeta padre `/media/usuario/SSD_BACKUP/Backups`, consideró válida la ruta anidada, auto-creó el directorio duplicado y ejecutó el backup y la purga con `shred -u`.
  6. La ruta duplicada impidió la navegación estándar desde el explorador de archivos gráfico.

### 1.2 Causa Raíz 2: Ausencia de Inicialización del Marcador al Crear el Perfil
- **Comportamiento anómalo observado:**  
  Al crear el perfil `PC_Laboratorio` hacia un directorio de backup, el sistema no verificó ni desplegó el archivo de seguridad `.backup_storage_marker`.
- **Consecuencia:**  
  En el primer intento de backup de un módulo (ej. `ssh-keys`), la operación fue abortada con el error `STORAGE_MARKER_MISSING`, obligando al usuario a navegar manualmente a través de menús secundarios para inicializar el almacenamiento.
- **Requisito:**  
  El proceso de creación y asignación de destino de un perfil debe comprobar proactivamente el marcador y ofrecer desplegarlo en ese mismo instante.

---

## 2. Requerimientos Funcionales (RF)

### RF-PATH-001: Desacoplamiento Estricto de Rutas en Perfiles (Ruta Absoluta vs. Subcarpeta Relativa)
- Al definir el destino de un perfil en `profile_model_create` o al editarlo:
  - **Caso A (Ruta Absoluta / Independiente):** Si el valor comienza por `/`, `~`, `$HOME` o `${HOME}`, se considerará un **Destino Absoluto Autónomo** (`PROFILE_BACKUP_DESTINATION`).
    - No se eliminará la barra inicial `/`.
    - No se concatenará jamás al `BACKUP_DESTINATION` global.
    - Se resolverá mediante `device_model_resolve_destination`.
  - **Caso B (Subcarpeta Relativa):** Si el valor no es absoluto ni contiene prefijos de usuario, se considerará una subcarpeta dentro del destino base (`TARGET_SUBDIR`).
    - Se saneará estrictamente eliminando barras iniciales redundantes y bloqueando `..`.
    - Se concatenará exactamente una vez: `<BACKUP_DESTINATION>/<TARGET_SUBDIR>`.
  - **Caso C (Zero-Config Vacío):** Si el usuario deja el campo vacío, se adoptará automáticamente la convención Zero-Config:
    - Perfil `default`: `<BACKUP_DESTINATION>` (raíz del almacenamiento).
    - Perfil secundario (`<id>`): `<BACKUP_DESTINATION>/<id>`.

### RF-PATH-002: Detector y Bloqueo Anti-Duplicación de Rutas Recursivas
- Se implementará la función `device_model_detect_path_recursion(base_dir, target_dir)`.
- Si la ruta final resuelta contiene el prefijo base repetido de forma consecutiva o anidada (ej. `.../Backups/.../Backups` o segmentos idénticos repetidos en la jerarquía):
  - La validación en `device_model_validate_storage` **bloqueará inmediatamente la operación** con código de error `DEV_ERR_RECURSIVE_PATH` (`12`).
  - Emitirá un mensaje de error claro en pantalla alertando de ruta recursiva/duplicada antes de crear cualquier directorio o invocar `tar`/`shred`.

### RF-PATH-003: Normalización Canónica con `realpath`
- Toda ruta de destino resuelta debe pasar por normalización canónica (`realpath -m` o equivalente robusto) para eliminar:
  - Barras múltiples consecutivas (`//`).
  - Segmentos superfluos (`/./`).
  - Barras finales trailing (`/`).

### RF-PATH-004: Inicialización Guiada del Marcador al Crear un Perfil
- En el asistente interactivo de creación de perfiles (`controller_handle_create_profile`):
  1. Tras validar el identificador y capturar el destino, el controlador resolverá la ruta canónica efectiva del perfil.
  2. Comprobará de inmediato si existe `.backup_storage_marker` en dicha ruta o en su jerarquía directa.
  3. **Si el marcador NO existe:**
     - **En TUI (`whiptail`):** Desplegará un diálogo afirmativo/negativo:
       ```text
       El destino seleccionado para este perfil:
       <RUTA_RESUELTA>
       no está inicializado como almacenamiento de KeepMyConfig (.backup_storage_marker ausente).

       ¿Desea inicializar esta carpeta ahora mismo creando la estructura necesaria?
       ```
     - **En CLI:** Si se incluye el flag `--init-storage` o `--yes`, procederá a la inicialización automática. Si no, advertirá al usuario sobre la necesidad de inicializarlo.
  4. Si el usuario confirma, creará la estructura (`archives/`, `logs/`) y copiará `.backup_storage_marker` en el destino.
  5. Si el usuario rechaza, se creará el perfil pero se emitirá un aviso informativo de que el almacenamiento requerirá inicialización previa antes del primer backup.

### RF-PATH-005: Verificación Pre-Shred Reforzada (Safe Destruction Gate)
- En `lib/models/backup_model.sh`, antes de ejecutar cualquier llamada a `crypto_model_shred_files`:
  1. Verificar que el archivo comprimido/cifrado generado en `$dest_dir/archives/...` existe físicamente y su tamaño en bytes es estrictamente superior a 0 (`[[ -s "$archive_path" ]]`).
  2. Verificar que la ruta `$dest_dir` no contiene anomalías sintácticas (`//`) ni recursión de directorios.
  3. Si la verificación falla:
     - **ABORTAR INMEDIATAMENTE** la purga.
     - Preservar intactos los archivos originales locales en el equipo.
     - Registrar alerta de emergencia en los logs.

---

## 3. Requerimientos No Funcionales (RNF)

- **RNF-PATH-001 (Compatibilidad hacia atrás):** Los perfiles existentes que utilicen subcarpetas relativas estándar seguirán funcionando sin alteración.
- **RNF-PATH-002 (Cero Privilegios):** Todo el proceso de detección, creación de directorios y despliegue del marcador opera exclusivamente con permisos de usuario estándar sin `sudo`.
- **RNF-PATH-003 (Idempotencia):** La inicialización del marcador debe ser idempotente; si ya existe, no debe corromper ni sobrescribir archivos preexistentes.

---

## 4. Matriz de Casos Borde

| Caso Borde | Entrada del Usuario | Destino Base Global | Resultado Esperado |
| :--- | :--- | :--- | :--- |
| **Ruta Absoluta en SSD** | `/media/user/SSD/Backups` | `~/Backups/KeepMyConfig` | Destino efectivo: `/media/user/SSD/Backups` (Override autónomo, sin duplicar). |
| **Ruta con `~`** | `~/MisCopias/PC_Laboratorio` | `/media/user/SSD/Backups` | Destino efectivo: `/home/user/MisCopias/PC_Laboratorio`. |
| **Subcarpeta Simple** | `PC_Laboratorio` | `/media/user/SSD/Backups` | Destino efectivo: `/media/user/SSD/Backups/PC_Laboratorio`. |
| **Campo Vacío (Zero-Config)** | *(vacío)* | `/media/user/SSD/Backups` | Destino efectivo: `/media/user/SSD/Backups/PC_Laboratorio`. |
| **Ruta con barras redundantes** | `//media//user//SSD///Backups//` | `~/Backups` | Destino normalizado: `/media/user/SSD/Backups`. |
| **Intento de Duplicación Recursiva** | `/media/user/SSD/Backups/media/user/SSD/Backups` | `/media/user/SSD/Backups` | Detectado por `device_model_detect_path_recursion` -> Error `12` y bloqueo preventivo. |
| **Destino nuevo sin marcador** | `/media/user/SSD/Backups` | N/A | Pregunta interactiva "¿Desea inicializar ahora?" -> Despliega marcador y carpetas con éxito. |
