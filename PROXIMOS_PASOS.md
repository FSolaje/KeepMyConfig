# Próximos Pasos: KeepMyConfig - Gestor de Backup y Recuperación (MVC en Bash)

> **Nombre Oficial de la Aplicación:** **KeepMyConfig**  
> **Estado actual:** Repositorio publicado y sincronizado en GitHub (`git@github.com:FSolaje/KeepMyConfig.git`). Versión Alfa **`v0.1.0-alpha.1`** publicada en Releases. Hook pre-commit de 5 fases activo localmente y Workflows de GitHub Actions (`ci.yml` y `release.yml`) desplegados en `develop`.  
> **Paso inmediato:** Validar y realizar commit en `dev/feature/backup-profiles` para consolidar el **Hito 12**, integrar en `develop` e iniciar el **Hito 13** (Almacenamiento Remoto SSH/SFTP/Rsync).

---

## Hitos Completados:

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
11. **Política de Versionado SemVer y Lanzamiento Alfa (`v0.1.0-alpha.1`):**
    - [x] Definición de estándar SemVer compatible con GitHub Releases.
    - [x] Generación de Tag Anotado `v0.1.0-alpha.1` en Git.
    - [x] Sincronización con GitHub: Repositorio remoto `FSolaje/KeepMyConfig`, subida de ramas `main`, `develop` y tag `v0.1.0-alpha.1`. Release publicada en GitHub.
    - [x] Hook de Calidad Pre-Commit de 5 barreras en `.git/hooks/pre-commit`.
    - [x] Automatización GitHub Actions: Workflows `ci.yml` y `release.yml`.
12. **Sistema de Perfiles de Backup & Scoped Modules (`dev/feature/backup-profiles`):**
    - [x] **Documentos SDD:** `spec.md`, `plan.md` y `tasks.md` aprobados en `specs/backup_profiles/`.
    - [x] **Modelo `profile_model.sh`:** CRUD de perfiles, validación de IDs, persistencia atómica de `ACTIVE_PROFILE` en `config.conf`.
    - [x] **Resolución en Cascada:** Módulos de perfil (`profiles/<perfil>/modules.d/`) prevalecen sobre módulos globales (`modules.d/`) y soporte de recetas exclusivas.
    - [x] **Deduplicación:** Listado unificado `profile_model_list_modules`.
    - [x] **Vinculación a Destinos:** Soporte de `TARGET_SUBDIR` específico por perfil.
    - [x] **Integración CLI y TUI:** Flags `--profile`, `--list-profiles`, `--set-active-profile`, `--create-profile`, y Opción 9 en menú TUI de `whiptail`.
    - [x] **Unificación de Identidad `KeepMyConfig`:** Actualización de banners, títulos, cabeceras, `README.md` y `MANUAL_USUARIO.md`.
    - [x] **Batería de Pruebas Unitarias:** 9 suites de pruebas unitarias al 100% de éxito (incluyendo 41 tests de `profile_model` y 48 de `controller`).
    - [x] **Escáner SAST:** 0 alertas en 77 archivos auditados.

---

## Hoja de Ruta Inmediata y Futuras Funcionalidades (Roadmap):

### Hito 13: Almacenamiento Remoto (SSH, SFTP, Rsync)
- [ ] **Ampliación de `STORAGE_ID_TYPE`:** Añadir soportes `SSH`, `SFTP` y `RSYNC`.
- [ ] **Autenticación y Conectividad sin privilegios:** Integración de claves SSH y comprobación de puertos/hosts.
- [ ] **Validación Remota del Marcador:** Verificación de `.backup_storage_marker` en destino remoto mediante canal seguro.
- [ ] **Transferencia Eficiente:** Estrategia de sincronización o montaje (FUSE `sshfs` o canalización `rsync`/tuberías `ssh`).
- [ ] **Asociación con Perfiles:** Posibilidad de que cada perfil defina si su destino es un SSD físico, ruta local o servidor remoto.

