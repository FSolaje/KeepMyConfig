# Especificación de Requerimientos: Orquestador y Entrypoint (app_controller.sh y backup_manager.sh)

**Componentes:** `lib/controllers/app_controller.sh` y `backup_manager.sh`  
**Rama:** `dev/feature/app-controller`  
**Estado:** Propuesta / En Revisión  

---

## 1. Propósito y Filosofía Arquitectónica

`app_controller.sh` actúa como el director de orquesta en el patrón MVC:
1. **Separación de Responsabilidades:**
   - No implementa compresión, cifrado ni borrado directo (delega en `lib/models/`).
   - No emite diálogos directos en bruto (delega en `lib/views/whiptail_view.sh` y `lib/views/ansi_view.sh`).
   - Conecta las acciones del usuario (desde la TUI interactiva o desde argumentos CLI) con los modelos de negocio.
2. **Entrypoint Unificado (`backup_manager.sh`):**
   - Si se invoca sin argumentos en una TTY interactiva: inicia el bucle interactivo de la TUI (`whiptail`).
   - Si se invoca con argumentos/flags: ejecuta el comando en modo desatendido (CLI Headless) usando `ansi_view.sh` para reportar estados y códigos de salida UNIX estándar.

---

## 2. Requerimientos Funcionales

### 2.1 Modos de Operación

#### CTRL_01: Inicialización y Carga de Entorno
- Debe cargar de forma segura las configuraciones globales (`config/config.conf` y `config/default_tags.conf`).
- Debe verificar la existencia del marcador de aplicación local `.backup_app_marker`.
- Debe cargar todos los modelos (`device_model`, `module_model`, `crypto_model`, `backup_model`, `restore_model`) y vistas (`whiptail_view`, `ansi_view`).

#### CTRL_02: Modo TUI Interactivo (`whiptail`)
Implementa un bucle de control (`controller_tui_loop`) que evalúa la elección del usuario en `whiptail_view_main_menu`:
- **Opción 1 (`[BACKUP] Completo`):**
  - Verifica el almacenamiento externo con `device_model_check_marker`. Si falla, notifica y aborta.
  - Detecta si hay módulos sensibles; si los hay, solicita y confirma la contraseña GPG en memoria.
  - Ejecuta `backup_model_run_all`.
  - Si un módulo sensible tiene `PURGE_AFTER_BACKUP=false`, muestra la advertencia de seguridad interactiva con opción de purga inmediata mediante `whiptail_view_yesno`.
  - Muestra resumen de resultados.
- **Opción 2 (`[BACKUP] Por Etiquetas`):**
  - Obtiene el catálogo de etiquetas disponibles con `module_model_get_all_tags`.
  - Presenta un checklist interactivo al usuario.
  - Ejecuta `backup_model_run_by_tag` con las etiquetas seleccionadas.
- **Opción 3 (`[BACKUP] Individual`):**
  - Lista los módulos configurados y permite seleccionar uno.
  - Si es sensible, solicita contraseña GPG.
  - Ejecuta `backup_model_run`.
- **Opción 4 (`[RESTORE] Rápida Sensible`):**
  - Solicita la clave GPG una única vez (`whiptail_view_password`).
  - Ejecuta `restore_model_restore_sensitive_all`.
  - Muestra reporte con ficheros y estados restituidos.
- **Opción 5 (`[RESTORE] Selectiva / Histórico`):**
  - Muestra lista de módulos disponibles en el SSD.
  - Una vez seleccionado el módulo, consulta su histórico de marcas de tiempo (`backup_model_list_history`) y presenta un menú con las fechas disponibles.
  - Si está cifrado, solicita la clave GPG.
  - Ejecuta `restore_model_restore_module`.
- **Opción 6 (`[RESTORE] Total`):**
  - Solicita confirmación y clave si aplica, ejecutando `restore_model_restore_all`.
- **Opción 7 (`[MODULES] Administración`):**
  - Submenú interactivo para:
    - 7.1 Listar y ver detalles de módulos.
    - 7.2 Crear nuevo módulo mediante asistente guiado (ID, Nombre, Rutas, Selección de Tags, Sensibilidad, Purga).
    - 7.3 Eliminar módulo existente (con confirmación de seguridad).
    - 7.4 Añadir nueva etiqueta al catálogo global (`default_tags.conf`).
- **Opción 8 (`[CONFIG] Diagnóstico de Disco Externo`):**
  - Localiza el dispositivo por UUID/LABEL/STATIC_PATH.
  - Verifica punto de montaje, espacio libre (`df -h`) y presencia de `.backup_storage_marker`.
- **Opción 0 (`[SALIR]`):**
  - Cierra limpiamente la aplicación.

#### CTRL_03: Modo CLI Headless (`backup_manager.sh`)
Soporta los siguientes flags y argumentos:
- `--help` / `-h`: Muestra el manual de ayuda y sintaxis.
- `--check-device`: Diagnóstico del dispositivo externo.
- `--backup-all [--purge | --no-purge]`: Respaldo completo.
- `--backup-tag <tag> [--purge | --no-purge]`: Respaldo de módulos asociados a una etiqueta.
- `--backup-module <id> [--purge | --no-purge]`: Respaldo de un único módulo.
- `--restore-sensitive`: Restauración exprés de datos sensibles (solicita clave vía terminal o variable segura).
- `--restore-all`: Restauración completa.
- `--restore-module <id> [--timestamp <ts>]`: Restauración de un módulo (último o timestamp específico).
- `--list-modules`: Muestra en tabla ANSI todos los módulos y su estado.
- `--list-tags`: Muestra todas las etiquetas registradas.

---

## 3. Códigos de Retorno del Sistema

| Código | Significado |
|---|---|
| `0` | Operación completada con éxito (`EXIT_SUCCESS`). |
| `1` | Error general o cancelación por el usuario. |
| `2` | Almacenamiento externo no encontrado o marcador inválido. |
| `3` | Módulo o archivo no encontrado. |
| `4` | Error de autenticación/contraseña GPG. |
| `5` | Fallo de sintaxis o argumentos CLI inválidos. |
