# Próximos Pasos: Gestor de Backup y Recuperación (MVC en Bash)

**Estado actual:** Fase de Especificación completada y aprobada conceptualmente. Especificación técnica volcada en `BackupConfig/ESPECIFICACION.md`.

## Tareas Inmediatas Pendientes:
1. **Validación del Documento de Especificación:**
   - [x] Revisión del archivo `ESPECIFICACION.md` completada y aprobada con la inclusión de `PURGE_AFTER_BACKUP=true/false` para control atómico de purga segura con `shred -u`.
2. **Creación de la Estructura Base de Directorios:**
   - [x] Creado el esqueleto de carpetas: `config/`, `modules.d/`, `lib/models/`, `lib/views/`, `lib/controllers/`, `markers/`.
   - [x] Configuración global `config/config.conf` y catálogo de etiquetas `config/default_tags.conf`.
   - [x] Archivos testigo de seguridad `.backup_app_marker` y `markers/.backup_storage_marker`.
3. **Implementación de los Modelos (Lógica de Negocio):**
   - [x] `lib/models/device_model.sh`: Identificación del SSD (UUID/LABEL/Path), comprobación de `.backup_storage_marker` y suite unitaria en `tests/test_device_model.sh`.
   - [x] `lib/models/module_model.sh`: Parser y CRUD de archivos en `modules.d/`, validación aislada en subshell y suite unitaria en `tests/test_module_model.sh`.
   - [x] `lib/models/crypto_model.sh`: Encriptación/Desencriptación GPG AES-256 simétrica, verificación en memoria, sha256 y borrado seguro recursivo con `shred -u` (test unitario en `tests/test_crypto_model.sh`).
   - [x] `lib/models/backup_model.sh`: Motor de empaquetado (tar/zstd), generación de marcas de tiempo `AAAAMMDD_HHMMSS`, manifest con inventario, cálculo de diffs y purga segura (test unitario en `tests/test_backup_model.sh`).
   - [x] `lib/models/restore_model.sh`: Desempaquetado selectivo, desencriptación en tubería GPG, hooks posteriores y suite unitaria en `tests/test_restore_model.sh`.
4. **Implementación de la Vista (Presentación Desacoplada):**
   - [x] `lib/views/whiptail_view.sh`: Funciones modulares de diálogo con `whiptail` (menús, checklists de etiquetas/módulos, passwordbox, progress gauge).
   - [x] `lib/views/ansi_view.sh`: Funciones de consola con formato ANSI, encabezados, captura segura de contraseñas y confirmaciones interactivas (suite unitaria en `tests/test_views.sh`).
5. **Implementación del Controlador y Entrypoint:**
   - `lib/controllers/app_controller.sh`: Orquestación MVC.
   - `backup_manager.sh`: Punto de entrada CLI y modo TUI interactivo.
6. **Módulos Iniciales de Prueba:**
   - [x] Creados `modules.d/vscode-standard.conf` y `modules.d/vscode-sensitive.conf`.
   - Crear `modules.d/bash-env.conf` y `modules.d/ssh-keys.conf`.
7. **Pruebas y Verificación:**
   - Pruebas unitarias de backup/restore de cada módulo sin permisos de administración.
   - Verificación de la purga segura con `shred -u`.
   - Prueba de detección y desconexión segura del SSD.
