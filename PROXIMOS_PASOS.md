# Próximos Pasos: KeepMyConfig - Gestor de Backup y Recuperación (MVC en Bash)

> **Nombre Oficial de la Aplicación:** **KeepMyConfig**  
> **Estado actual:** Repositorio publicado y sincronizado en GitHub (`git@github.com:FSolaje/KeepMyConfig.git`). Versión Alfa **`v0.1.0-alpha.1`** publicada en Releases. Hito 12 Base consolidado en commit `1ba2f20`, Sub-Hito 12.1 en `a5e5ea3`, Sub-Hito 12.3 en `7b34f9e`, Sub-Hito 12.4 en `264cc7c`, y **Sub-Hito 12.4.1 (Home Virtual en Sandbox, Captura Guiada de Rutas y Corrección de Cancelación TUI) completado y listo para commit** en la rama `dev/feature/backup-profiles`. Toda la suite de 10 baterías con **458/458 pruebas unitarias al 100%**, escáner SAST impecable y aislamiento total en Git.  
> **Paso inmediato para la próxima sesión:** Consolidar en Git el Sub-Hito 12.4.1 tras aprobación del usuario, y continuar con el **Sub-Hito 12.5: Sistema de Empaquetado y Distribución Automatizada para Releases** (`scripts/package.sh` e `install.sh`).

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
12. **Sistema de Perfiles de Backup Base (`dev/feature/backup-profiles`):**
    - [x] **Documentos SDD:** `spec.md`, `plan.md` y `tasks.md` en `specs/backup_profiles/`.
    - [x] **Modelo `profile_model.sh`:** CRUD de perfiles, validación de IDs, persistencia atómica de `ACTIVE_PROFILE` en `config.conf`.
    - [x] **Resolución en Cascada:** Módulos de perfil (`profiles/<perfil>/modules.d/`) prevalecen sobre módulos globales (`modules.d/`) y soporte de recetas exclusivas.
    - [x] **Deduplicación:** Listado unificado `profile_model_list_modules`.
    - [x] **Vinculación a Destinos:** Soporte de `TARGET_SUBDIR` específico por perfil.
    - [x] **Integración CLI y TUI:** Flags `--profile`, `--list-profiles`, `--set-active-profile`, `--create-profile`, y Opción 9 en menú TUI de `whiptail`.
    - [x] **Unificación de Identidad `KeepMyConfig`:** Actualización de banners, títulos, cabeceras, `README.md` y `MANUAL_USUARIO.md`.
    - [x] **Batería de Pruebas Unitarias:** 9 suites de pruebas unitarias al 100% de éxito (249 tests en verde).
    - [x] **Escáner SAST:** 0 alertas en 77 archivos auditados.
    - [x] **Commit de Consolidación:** Registrado bajo Conventional Commits (`1ba2f20`).
13. **Módulos con Ámbito y Sanitización de Rutas (Sub-Hito 12.1):**
    - [x] **Documentos SDD:** `specs/scoped_modules_sanitization/` (`spec.md`, `plan.md`, `tasks.md`).
    - [x] **Sanitización de Rutas en `module_model.sh`:** Función `module_model_sanitize_path` para eliminación de `$HOME`, `~`, `/home/<user>/`, barras redundantes y bloqueo de `..`.
    - [x] **Sanitización de Destinos en `profile_model.sh`:** Función `profile_model_sanitize_target_subdir` para prevención de rutas absolutas locales en `TARGET_SUBDIR`.
    - [x] **Selector de Ámbito en TUI (`app_controller.sh`):** Pregunta al usuario si el módulo es Global o Exclusivo del perfil activo al crearlo (Opción 7), y muestra etiquetas `[Global]` o `[Perfil: <id>]` en listados y borrados.
    - [x] **Ampliación de Pruebas Unitarias:** 49 nuevas pruebas añadidas (total: 298 pruebas al 100% de éxito).
    - [x] **Escáner SAST:** 0 alertas en 80 archivos auditados.
    - [x] **Commit de Consolidación:** Registrado bajo Conventional Commits (`a5e5ea3`).
14. **Biblioteca de Plantillas y Exclusiones en Perfiles (Sub-Hito 12.2):**
    - [x] **Documentos SDD:** `specs/templates_and_profile_exclusions/` (`spec.md`, `plan.md`, `tasks.md`).
    - [x] **Biblioteca `templates.d/`:** Desacoplamiento de recetas predefinidas (9 recetas base + esqueleto canónico `template-skeleton.conf`).
    - [x] **Estado Inicial Limpio:** 0 módulos activos en `modules.d/` de inicio; orientación amigable en `--backup-all` sin error.
    - [x] **Modelo `module_model.sh`:** Funciones de listado, lectura, activación, creación y exportación de plantillas.
    - [x] **Modelo `profile_model.sh`:** Directiva `DISABLED_MODULES`, soporte de exclusión selectiva en perfiles y resolución en cascada con filtrado.
    - [x] **Controlador y Vistas (`app_controller.sh` y `backup_manager.sh`):**
      - Opciones en TUI 7 y 9 para activar plantillas, crear plantillas, exportar módulos y gestionar exclusiones en perfiles.
      - Flags CLI `--list-templates`, `--enable-template` y `--export-template`.
    - [x] **Documentación Actualizada:** `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md` actualizados según Regla Mandatoria 10 de `AGENT.md`.
    - [x] **Batería de Pruebas:** 318 pruebas unitarias superadas al 100% (72 pruebas de controlador).
15. **Ruta Universal de Backup, Destino por Perfil y Onboarding (Sub-Hito 12.3):**
    - [x] **Documentos SDD:** `specs/universal_storage_and_onboarding/` (`spec.md`, `plan.md`, `tasks.md`).
    - [x] **Modelo de Dispositivo y Almacenamiento Universal (`device_model.sh`):** Función `device_model_resolve_destination` (soporte `~`, `$HOME`, `${HOME}`, rutas relativas y absolutas, y `@media/<LABEL>/...`), detección de soportes externos `device_model_detect_external_drives`, actualización atómica `device_model_update_config_destination` y validación jerárquica sin fuga de variables en `device_model_validate_storage`.
    - [x] **Perfil Default Físico y Convención Zero-Config (`profile_model.sh`):** Creación física de `profiles/default/profile.conf`, auto-reparación preventiva (*auto-healing*) en `profile_model_init_default` y resolución de destino Zero-Config por perfil `<BACKUP_DESTINATION>/<id_perfil>`.
    - [x] **Onboarding Wizard y Control de Sesión (`app_controller.sh`):** Configuración inicial con `INITIAL_SETUP_DONE="false"`, detección de discos y opción local `$HOME/Backups/KeepMyConfig`, despliegue automático del marcador de seguridad `.backup_storage_marker`, preferencia de persistencia de sesión `REMEMBER_LAST_PROFILE=true/false` y flag CLI `--setup`.
    - [x] **Limpieza Arquitectónica del Submenú de Almacenamiento:** Depuración de remanentes obsoletos en la Opción 8 (retirados listing/targets de Hito 9) y nueva acción directa `controller_handle_deploy_marker`.
    - [x] **Documentación Actualizada:** Sincronización mandatoria de `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md` (con registro de `### Breaking Changes`).
    - [x] **Batería de Pruebas Unitarias:** 370 pruebas unitarias al 100% de éxito (53 device, 78 profile, 80 controller).
    - [x] **Auditoría de Seguridad SAST:** Escáner limpio con 0 alertas en 97 archivos.
    - [x] **Commit de Consolidación:** Registrado bajo Conventional Commits (`7b34f9e`).
16. **Modo Sandbox y Entorno Aislado de Pruebas (Sub-Hito 12.4):**
    - [x] **Documentos SDD:** `specs/sandbox_test_mode/` (`spec.md`, `plan.md`, `tasks.md`) completados y aprobados.
    - [x] **Aislamiento en `user_data/sandbox/`:** Confinamiento completo de `config/config.conf`, `modules.d/`, `profiles/` y `storage/` en un directorio excluido en `.gitignore`.
    - [x] **Auto-Inicialización Transparente (`controller_enable_sandbox_mode`):** Despliegue de estructura de directorios, configuración con `BACKUP_DESTINATION` local a sandbox, perfil `default` canónico y marcador de seguridad `.backup_storage_marker`.
    - [x] **Purga Segura (`controller_clean_sandbox`):** Eliminación total del sandbox con `--clean-sandbox` y reporte ANSI formateado.
    - [x] **Integración CLI y TUI (`backup_manager.sh` y `app_controller.sh`):** Flags `--test-mode`, `--sandbox`, variable `KEEP_MY_CONFIG_TEST_MODE=true`, banner `[SANDBOX]` en título de Whiptail y avisos de seguridad en consola.
    - [x] **Documentación Actualizada:** `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md` sincronizados rigurosamente.
    - [x] **Commit de Consolidación:** Registrado bajo Conventional Commits (`264cc7c`).
17. **Home Virtual en Sandbox, Captura Guiada de Rutas y Corrección TUI (Sub-Hito 12.4.1):**
    - [x] **Documentos SDD:** `specs/sandbox_virtual_home_and_tui_ux/` (`spec.md`, `plan.md`, `tasks.md`).
    - [x] **Home Virtual de Pruebas (`user_data/sandbox/home/`):** Confinamiento estricto de `TARGET_USER_HOME`, semillas canónicas en `tests/fixtures/sandbox_home/` para todas las recetas base y verificación segura de purga con `shred -u` sin tocar el `$HOME` real.
    - [x] **Captura Interactiva de Rutas Línea a Línea (`whiptail_view_input_paths`):** Cuadro dinámico con confirmación por Enter, visualización acumulada y orientación sobre rutas relativas/$HOME.
    - [x] **Feedback Detallado con Rutas Absolutas en TUI:** Desglose de rutas completas de origen, destino y ficheros destruidos en diálogos informativos.
    - [x] **Corrección de Cancelación en TUI:** Retorno limpio `0` en cancelación voluntaria de selección de módulos, etiquetas, menús y contraseñas (evitando abortos bajo `set -e`).
    - [x] **Batería de Pruebas Unitarias:** 50 pruebas en `tests/test_sandbox_mode.sh` (total: 458/458 pruebas superadas al 100%).

---

## Hoja de Ruta Inmediata y Futuras Funcionalidades (Roadmap):

### Sub-Hito 12.4.1: Home Virtual de Sandbox y Mejoras TUI (Completado y Listo para Commit)
- [x] Documentos SDD completados en `specs/sandbox_virtual_home_and_tui_ux/`.
- [x] Bugfix de cancelación voluntaria en TUI (código 0).
- [x] Home virtual de pruebas con semillas canónicas en `tests/fixtures/sandbox_home/`.
- [x] Función interactiva de captura de rutas `whiptail_view_input_paths`.
- [x] Feedback detallado con rutas absolutas completas en cuadros de diálogo de la TUI.
- [x] 10 suites de pruebas unitarias superadas al 100% (458 tests).
- [x] Sincronización mandatoria de `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md`.
- [ ] Autorización y Commit independiente del Sub-Hito 12.4.1.

### Sub-Hito 12.5 (Siguiente Tarea): Sistema de Empaquetado y Distribución Automatizada para Releases
- [ ] Definición de Manifiesto de Distribución con Lista Blanca estricta (exclusión de `.agents/`, `specs/`, `tests/`, `user_data/`, etc.).
- [ ] Script reproducible de empaquetado `scripts/package.sh` para generar `KeepMyConfig-vX.Y.Z.tar.gz` (sin tarbomb) y `SHA256SUMS.txt`.
- [ ] Script de instalación opcional sin sudo `install.sh` (`~/.local/bin` y lanzador desktop para Lliurex 25 / Ubuntu 24.04).
- [ ] Actualización del workflow `.github/workflows/release.yml` para adjuntar los artefactos empaquetados oficiales en cada release de GitHub.
- [ ] Commit independiente del Sub-Hito 12.5.

### Hito 13: Almacenamiento Remoto (SSH, SFTP, Rsync)
- [ ] **Ampliación de `BACKUP_DESTINATION`:** Añadir soporte para destinos remotos (`ssh://user@host/path`, `sftp://`, `rsync://`).
- [ ] **Autenticación y Conectividad sin privilegios:** Integración de claves SSH y comprobación de puertos/hosts.
- [ ] **Validación Remota del Marcador:** Verificación de `.backup_storage_marker` en destino remoto mediante canal seguro.
- [ ] **Transferencia Eficiente:** Estrategia de sincronización o montaje (FUSE `sshfs` o canalización `rsync`/tuberías `ssh`).
- [ ] **Asociación con Perfiles:** Posibilidad de que cada perfil defina si su destino es un SSD físico, ruta local o servidor remoto.


