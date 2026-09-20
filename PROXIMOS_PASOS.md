# Próximos Pasos: Gestor de Backup y Recuperación (MVC en Bash)

**Estado actual:** Fase de Especificación completada y aprobada conceptualmente. Especificación técnica volcada en `BackupConfig/ESPECIFICACION.md`.

## Tareas Inmediatas Pendientes:
1. **Validación del Documento de Especificación:**
   - [x] Revisión del archivo `ESPECIFICACION.md` completada y aprobada con la inclusión de `PURGE_AFTER_BACKUP=true/false` para control atómico de purga segura con `shred -u`.
2. **Creación de la Estructura Base de Directorios:**
   - Crear el esqueleto de carpetas: `BackupConfig/config/`, `BackupConfig/modules.d/`, `BackupConfig/lib/models/`, `BackupConfig/lib/views/`, `BackupConfig/lib/controllers/`, `BackupConfig/markers/`.
3. **Implementación de los Modelos (Lógica de Negocio):**
   - `lib/models/device_model.sh`: Identificación del SSD (UUID/LABEL/Path) y comprobación de `.backup_storage_marker`.
   - `lib/models/module_model.sh`: Parser y CRUD de archivos en `modules.d/`.
   - `lib/models/crypto_model.sh`: Encriptación/Desencriptación GPG AES-256 simétrica y borrado seguro con `shred -u`.
   - `lib/models/backup_model.sh`: Motor de empaquetado (tar/zstd), generación de marcas de tiempo `AAAAMMDD_HHMMSS`, manifest y diffs.
   - `lib/models/restore_model.sh`: Desempaquetado selectivo y hooks posteriores.
4. **Implementación de la Vista (Presentación Desacoplada):**
   - `lib/views/whiptail_view.sh`: Funciones modulares de diálogo con `whiptail` (menús, checklists de etiquetas/módulos, passwordbox, progress gauge).
5. **Implementación del Controlador y Entrypoint:**
   - `lib/controllers/app_controller.sh`: Orquestación MVC.
   - `backup_manager.sh`: Punto de entrada CLI y modo TUI interactivo.
6. **Módulos Iniciales de Prueba:**
   - Crear `modules.d/vscode-standard.conf` y `modules.d/vscode-sensitive.conf`.
   - Crear `modules.d/bash-env.conf` y `modules.d/ssh-keys.conf`.
7. **Pruebas y Verificación:**
   - Pruebas unitarias de backup/restore de cada módulo sin permisos de administración.
   - Verificación de la purga segura con `shred -u`.
   - Prueba de detección y desconexión segura del SSD.
