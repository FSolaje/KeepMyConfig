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
   - [x] Inicialización del marcador `.backup_storage_marker` en el SSD externo (`/media/$USER/DISCO_BACKUP/Backups/Lliurex25/`).
   - [x] Verificación de backup y restore de módulos estándar y por lotes (`--backup-tag`, `--backup-all`, `--restore-all`).
   - [x] Verificación de purga segura con `shred -u` y descifrado GPG AES-256 en módulos sensibles.
   - [x] Implementación y validación de operaciones colectivas en `dev/feature/backup-batch-ops`.
9. **Gestión de Destinos de Backup (`storage-target-init`) y Almacenamiento Universal (`LOCAL_PATH`):**
   - [x] Soporte para almacenamiento universal con `STORAGE_ID_TYPE="LOCAL_PATH"` (rutas directas, discos locales o carpetas de red montadas).
   - [x] Implementación en `lib/models/device_model.sh`: `device_model_init_target_directory`, `device_model_list_targets`, `device_model_update_config_subdir`.
   - [x] Implementación en `lib/controllers/app_controller.sh`: `--init-target`, `--set-default`, `--list-targets`, `--set-active-target`, `--target-subdir` y submenú interactivo en la Opción 8 de la TUI.
   - [x] Actualización de la documentación en `MANUAL_USUARIO.md`.
   - [x] Verificación completa con 8 suites de tests unitarios y prueba en vivo en SSD externo.
   - [x] Escáner SAST de seguridad y privacidad ejecutado y aprobado con 0 alertas.
10. **Corrección de Creación de Módulos en TUI (`dev/fix/module-admin-wizard`):**
    - [x] Corrección del ensamblado de rutas y etiquetas y orden de argumentos en la llamada a `module_model_save` desde `lib/controllers/app_controller.sh`.
    - [x] Flexibilización de parseo de tags en `lib/models/module_model.sh` (admite delimitador coma y espacio).
    - [x] Nueva prueba unitaria añadida en `tests/test_controller.sh` (Test 13).
    - [x] 8/8 suites de pruebas superadas y escáner SAST limpio.
    - [x] Integración en rama `develop` completada.

---

## Hoja de Ruta Inmediata y Futuras Funcionalidades (Roadmap):

### Hito 11: Política de Versionado SemVer y Lanzamiento Alfa (`v0.1.0-alpha.1`)
- [ ] **Definición de estándar SemVer:** Estructurar el versionado con prefijo `v` (`vMAJOR.MINOR.PATCH-PRERELEASE`) compatible con GitHub Releases.
- [ ] **Generación de Tag Anotado:** Creación del tag `v0.1.0-alpha.1` en Git para congelar el hito funcional del MVP base (MVC, GPG, Shred, TUI/CLI, Multi-target, Local Path).
- [ ] **Documentación de Publicación:** Registrar en `MANUAL_USUARIO.md` o documentación del repositorio el procedimiento de publicación de releases y pre-releases en GitHub.

### Hito 12: Sistema de "Perfiles de Backup" (Backup Profiles & Scoped Modules)
- [ ] **Modelo de Perfiles:** Definición del perfil activo (`ACTIVE_PROFILE` en configuración y flag CLI `--profile <nombre>`).
- [ ] **Jerarquía y Precedencia de Módulos:**
  - Módulos globales en `modules.d/` (disponibles para todos los entornos).
  - Módulos específicos en `profiles/<perfil>/modules.d/`:
    - *Sobrescritura (Override):* Si coincide el ID/nombre con uno global, se ejecuta la versión del perfil.
    - *Exclusivos:* Si un módulo sólo pertenece a un perfil, no aparece ni se ejecuta en perfiles ajenos.
- [ ] **Vinculación Perfil-Destino:** Cada perfil puede asociar su propio `TARGET_SUBDIR` (ej. `Backups/Lliurex25` vs `Backups/Personal_PC`).
- [ ] **Interfaz TUI/CLI:** Selector de perfil activo en TUI y soporte `--profile` en línea de comandos.
- [ ] **Pruebas Unitarias:** Suites de test para validar la resolución en cascada, precedencia y aislamiento de recetas.

### Hito 13: Almacenamiento Remoto (SSH, SFTP, Rsync)
- [ ] **Ampliación de `STORAGE_ID_TYPE`:** Añadir soportes `SSH`, `SFTP` y `RSYNC`.
- [ ] **Autenticación y Conectividad sin privilegios:** Integración de claves SSH y comprobación de puertos/hosts.
- [ ] **Validación Remota del Marcador:** Verificación de `.backup_storage_marker` en destino remoto mediante canal seguro.
- [ ] **Transferencia Eficiente:** Estrategia de sincronización o montaje (FUSE `sshfs` o canalización `rsync`/tuberías `ssh`).
- [ ] **Asociación con Perfiles:** Posibilidad de que cada perfil defina si su destino es un SSD físico, ruta local o servidor remoto.
