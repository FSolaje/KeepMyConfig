# Próximos Pasos: KeepMyConfig - Gestor de Backup y Recuperación (MVC en Bash)

> **Nombre Oficial de la Aplicación:** **KeepMyConfig**  
> **Estado actual:** **PARADA TÉCNICA Y BLINDAJE DE RUTAS**. Sub-Hito 12.6 aparcado preventivamente. Fase 1 completada al 100%: Incorporados avisos críticos de versión alfa experimental y disclaimer de pérdida de datos por purga y rutas en `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md`. Batería de 11 suites con **624/624 pruebas unitarias al 100%** y escáner SAST limpio sin alertas.
> **Paso inmediato:** 
> 1. Solicitar aprobación humana y realizar el commit atómico de documentación: `docs: incorporar advertencia critica de version alfa y disclaimer de perdida de datos en readme y manual`.
> 2. Crear rama GitFlow dedicada `dev/fix/path-manager-and-profile-storage-init` desde `develop`.
> 3. Iniciar el ciclo SDD de la Tarea 2: Rediseño del gestor de rutas, prevención de duplicación y despliegue automático del marcador de almacenamiento en la creación de perfiles.

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
    - [x] **Commit de Consolidación:** Registrado bajo Conventional Commits (`18ec12f`).
18. **Blindaje Normativo de Gobernanza Git y Atomicidad Documental:**
    - [x] Actualización de `.agents/rules/AGENT.md` con prohibición de commits híbridos (`fix` + `feat`), obligatoriedad de commits previos de especificación (`docs(spec)`), atomicidad por fases en `tasks.md`, desacoplamiento temprano de bugs y commits atómicos independientes para documentación pública (`docs:`).
    - [x] **Commit Atómico Dedicado:** Registrado bajo Conventional Commits (`3988e52`).

19. **Arquitectura Universal TUI, Asistente de Edición de Módulos, Pre-Flight Safety Gate y Personalización Visual (Sub-Hito 12.4.2):**
    - [x] Rama GitFlow dedicada `dev/feature/tui-ux-module-edit-and-safety`.
    - [x] Documentos SDD: `specs/tui_ux_module_edit_and_safety/` (`spec.md`, `plan.md`, `tasks.md`).
    - [x] Commit previo de especificación: `c69af43` (`docs(spec)`).
    - [x] **Fase 1 (Bugfix Sandbox):** Sembrado automático de recetas `.conf` en `user_data/sandbox/modules.d/` (`_sandbox_seed_modules`) y guardas defensivas ante listas vacías (`b2c6b7b`).
    - [x] **Fase 2 (UX Rutas):** Clarificación contextual de rutas relativas/absolutas y ruta base en asistentes TUI (`63af71a`).
    - [x] **Fase 3 (Edición de Módulos y Flag de Estado):** Asistente interactivo `controller_handle_edit_module`, sincronización inteligente de cifrado sensible, consentimiento activo obligatorio para purga (`shred -u`), selector de ámbito con opción *Override*, y conmutador de estado `MODULE_ENABLED` (`[ON]`/`[OFF]`) con flags CLI `--enable-module` y `--disable-module` (`19e7e21`).
    - [x] **Fase 4 (Resolución de Colisiones en Plantillas):** Ficha técnica previa a la activación, consentimiento sobre purga de fábrica, selector universal de ámbito (catálogo global vs perfil activo), resolución interactiva de colisiones (clonar con nuevo ID `--as-module`, sobrescribir `--force`, cancelar) (`7c7942a`).
    - [x] **Fase 5 (Pre-Flight Safety Gate):** Interceptor preventivo con matriz de módulos y destinos, alertas rojas irreversibles para `shred -u` (`\033[41;97;1m` / `--defaultno`), confirmación explícita con `SI` en CLI / flag `--yes`, y advertencias de sobreescritura previa en restauración (`5903fc8`).
    - [x] **Fase 6 (Arquitectura Universal de Menús y Temas TUI):** Menú Principal híbrido (Menú 1) y 6 submenús especializados con telemetría en tiempo real, iconografía uniforme y catálogo de temas `NEWT_COLORS` (`default`, `midnight`, `cyberdark`, `aubergine`, `amber`) (`77bb8d9`).
    - [x] **Fase 7 (Batería de Pruebas Unitarias):** 70 nuevas aserciones en `test_views.sh`, `test_module_model.sh` y `test_controller.sh` (totalizando 528 pruebas unitarias al 100% de éxito) (`9deb859`).
    - [x] **Fase 8 (Documentación Pública):** Sincronización mandatoria de `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md`.
20. **Empaquetado y Distribución - Fase 0 y Fase 1 (Sub-Hito 12.5 en curso):**
    - [x] Rama GitFlow dedicada `dev/feature/packaging-distribution` bifurcada desde `develop` actualizado (`v0.1.0-alpha.2`).
    - [x] **Fase 0 (SDD):** `specs/packaging_and_distribution/` (`spec.md`, `plan.md`, `tasks.md`) y commit previo obligatorio `702ff8a` (`docs(spec)`).
    - [x] **Subfase 1.1 (Aislamiento Git):** Inclusión de `dist/` en `.gitignore` y purga preventiva de caché de Git (`128df06`).
    - [x] **Subfase 1.2 (Icono Vectorial):** Diseño e incorporación del icono oficial W3C/Freedesktop `assets/keepmyconfig.svg` (`22245b4`).
    - [x] **Subfase 1.3 (Lanzador Freedesktop):** Creación del lanzador estándar XDG `assets/keepmyconfig.desktop` validado con `desktop-file-validate` (`9c82bd0`).
    - [x] **Calidad y Seguridad:** 10 suites unitarias superadas al 100% (528/528 tests) y escáner SAST limpio (0 alertas).

---

## Hoja de Ruta Inmediata y Futuras Funcionalidades (Roadmap):

### Sub-Hito 12.5: Sistema de Empaquetado y Distribución Automatizada para Releases (Completado)
- [x] Integración de `dev/feature/tui-ux-module-edit-and-safety` en `develop` y tag `v0.1.0-alpha.2`.
- [x] Creación de rama GitFlow dedicada: `dev/feature/packaging-distribution`.
- [x] Documentos SDD en `specs/packaging_and_distribution/` (`spec.md`, `plan.md`, `tasks.md`).
- [x] Commit previo obligatorio de especificación: `docs(spec): definir sistema de empaquetado y distribucion para releases` (`702ff8a`).
- [x] Subfase 1.1: Aislamiento del directorio `dist/` en `.gitignore` (`128df06`).
- [x] Subfase 1.2: Diseño e incorporación del icono vectorial SVG `assets/keepmyconfig.svg` (`22245b4`).
- [x] Subfase 1.3: Creación de la plantilla de lanzador de escritorio Freedesktop `assets/keepmyconfig.desktop` validada con `desktop-file-validate` (`9c82bd0`).
- [x] **Fase 2:** Script reproducible de empaquetado dual `scripts/package.sh` para generar `KeepMyConfig-vX.Y.Z.tar.gz` (edición estándar con instalador) y `KeepMyConfig-vX.Y.Z-portable.tar.gz` (edición portable plug-and-play con `.portable` y `keepmyconfig.sh`), sin tarbomb, permisos normalizados `0755`/`0644`, lista blanca estricta y `SHA256SUMS.txt` (`e67aabb`).
- [x] **Fase 3:** Script de instalación y desinstalación sin sudo `install.sh` y `uninstall.sh`:
  - [x] Subfase 3.1: Scripts base e invocación canónica mediante symlinks en `$PATH` (`513bd5e`).
  - [x] Subfase 3.2: Asistente interactivo OOBE de destino de backups, marcador y perfiles (`8fe5d3f`).
  - [x] Subfase 3.3: Endurecimiento preventivo de permisos UNIX (`0555`/`0444`) en core/lib/templates (`16b84f8`).
- [x] **Fase 4:** Suite de pruebas unitarias automatizadas `tests/test_packaging_and_distribution.sh` con 96 aserciones de integración (total: 624/624 pruebas al 100%) (`2b6957c`).
- [x] **Fase 5:** Actualización del workflow `.github/workflows/release.yml` para invocar `scripts/package.sh` y adjuntar artefactos duales y checksums (`fb8ac1e`).
- [x] **Fase 6:** Sincronización mandatoria de documentación pública (`README.md`, `MANUAL_USUARIO.md`, `CHANGELOG.md`, `PROXIMOS_PASOS.md`).

### Sub-Hito 12.6: Blindaje Criptográfico de Integridad y Protección de Código Bash ante Manipulación (Aparcado Temporalmente)
> **Motivación y Análisis de Vulnerabilidad:** Al tratarse de un software completamente escrito en Bash, el código fuente reside en texto plano interpretado en `$HOME/.local/share/KeepMyConfig/lib/`. Cualquier script o proceso en el espacio de usuario podría alterar, corromper o inyectar código malicioso en las librerías del core (ej. captura de claves GPG o alteración de la purga segura con `shred`).  
> **Nota de Estado:** Aparcado temporalmente para priorizar la resolución del incidente crítico de duplicación de rutas y flujo de inicialización del marcador de almacenamiento.
- [x] **Fase 0 (Documentos SDD):** Creados y aprobados `specs/codebase_integrity_and_security/` (`spec.md`, `plan.md`, `tasks.md`). *Aparcado para retomar tras corregir el gestor de rutas*.

### Corrección Crítica: Rediseño del Gestor de Rutas, Prevención de Duplicación y Marcador en Perfiles (En Curso)
- [x] **Fase 1 (Avisos de Versión Alfa):** Incorporación de advertencias destacadas (`> [!CAUTION]`) y descargos de responsabilidad en `README.md`, `MANUAL_USUARIO.md` y `CHANGELOG.md`.
- [ ] **Fase 2 (SDD Gestor de Rutas y Perfiles):** Especificación técnica `specs/robust_path_manager_and_profile_storage/` con soporte para rutas absolutas completas sin despojar `/`, validación anti-duplicación y despliegue interactivo del marcador `.backup_storage_marker` al crear un perfil.
- [ ] **Fase 3 (Implementación y Pruebas Unitarias):** Ajuste de `profile_model.sh`, `device_model.sh`, `app_controller.sh` y suite de tests.

### Hito 13: Almacenamiento Remoto (SSH, SFTP, Rsync)
- [ ] **Ampliación de `BACKUP_DESTINATION`:** Añadir soporte para destinos remotos (`ssh://user@host/path`, `sftp://`, `rsync://`).
- [ ] **Autenticación y Conectividad sin privilegios:** Integración de claves SSH y comprobación de puertos/hosts.
- [ ] **Validación Remota del Marcador:** Verificación de `.backup_storage_marker` en destino remoto mediante canal seguro.
- [ ] **Transferencia Eficiente:** Estrategia de sincronización o montaje (FUSE `sshfs` o canalización `rsync`/tuberías `ssh`).
- [ ] **Asociación con Perfiles:** Posibilidad de que cada perfil defina si su destino es un SSD físico, ruta local o servidor remoto.



