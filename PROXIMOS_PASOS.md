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
   - [x] `lib/controllers/app_controller.sh`: Orquestación MVC.
   - [x] `backup_manager.sh`: Punto de entrada CLI y modo TUI interactivo (suite unitaria en `tests/test_controller.sh`).
6. **Módulos de Recetas Implementados:**
   - [x] VSCode: `modules.d/vscode-standard.conf` y `modules.d/vscode-sensitive.conf`.
   - [x] Sistema y Shell: `modules.d/bash-env.conf` (entorno) y `modules.d/ssh-keys.conf` (llaves y credenciales con Vault & Shred) con suite en `tests/test_sample_modules.sh`.
7. **Manual de Usuario Final (`MANUAL_USUARIO.md`):**
   - [x] Redacción integral en rama dedicada `dev/feature/user-manual`:
     - Guía paso a paso TUI (Whiptail) con diagramas de menús y flujos de copia/restauración.
     - Guía de uso CLI Headless con tabla de flags, automatización en cron y códigos de salida.
     - Guía para docentes/administradores: formato de recetas `.conf` y directivas de purga/hooks.
     - Guía de inicialización del SSD y resolución de incidencias (Troubleshooting).
8. **Pruebas y Verificación End-to-End con SSD:**
   - [ ] Inicialización del marcador `.backup_storage_marker` en el SSD externo.
   - [ ] Verificación de backup y restore de todos los módulos sin privilegios root.
   - [ ] Verificación de purga segura con `shred -u` en módulos sensibles.
