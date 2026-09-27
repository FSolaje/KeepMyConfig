# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Breaking Changes
- **Ruta Universal de Almacenamiento (`BACKUP_DESTINATION`):**
  - Se eliminan de forma definitiva las directivas fragmentadas `STORAGE_ID_TYPE`, `STORAGE_ID_VALUE`, `STORAGE_SUBDIR` y `STORAGE_STATIC_FALLBACK` en `config/config.conf`.
  - La ubicación del almacenamiento se define ahora exclusivamente a través de la directiva `BACKUP_DESTINATION`.
  - **Convención Zero-Config por Perfil:** Todo perfil secundario guarda de forma automática sus copias en el subdirectorio `<BACKUP_DESTINATION>/<id_perfil>` sin necesidad de parametrización manual, mientras que el perfil `default` preserva la raíz de `<BACKUP_DESTINATION>`.

### Added
- **Modo Sandbox y Entorno Aislado de Pruebas (Sub-Hito 12.4):**
  - **Aislamiento Total (`user_data/sandbox/`):** Confinamiento de todas las rutas de trabajo volátiles (`config/`, `modules.d/`, `profiles/` y `storage/`) en un directorio aislado protegido por `.gitignore`, garantizando 0 archivos sin seguimiento (*untracked files*) en Git tras pruebas manuales o desarrollo.
  - **Auto-Inicialización Transparente (`controller_enable_sandbox_mode`):** Despliegue automático de la estructura del sandbox, copia adaptada de `config/config.conf` (`INITIAL_SETUP_DONE="true"`, `ACTIVE_PROFILE="default"`, `BACKUP_DESTINATION="<sandbox>/storage"`), marcador de seguridad `.backup_storage_marker` y perfil base `profiles/default/profile.conf`.
  - **Banderas CLI y Variable de Entorno:** Soporte para `--test-mode`, `--sandbox` y variable `KEEP_MY_CONFIG_TEST_MODE=true` tanto para interfaz interactiva TUI como CLI, con filtrado temprano de argumentos para encadenar cualquier comando.
  - **Indicadores Visuales Explícitos:** Prefijo visual `[SANDBOX]` en el título de la TUI (`whiptail_view_main_menu`) y avisos de advertencia ANSI en consola para operaciones CLI.
  - **Comando de Purga Rápida (`--clean-sandbox`):** Eliminación total del directorio `user_data/sandbox/` mediante `controller_clean_sandbox` con confirmación formateada.
  - **Nueva Suite de Pruebas Automatizadas:** 33 pruebas unitarias y de integración en `tests/test_sandbox_mode.sh`, verificando inicialización, redirección de variables, persistencia, aislamiento en Git y purga.
- **Ruta Universal de Almacenamiento y Notación Semántica (`device_model.sh`):**
  - Soporte unificado en `device_model_resolve_destination` para expansión de rutas locales (`~`, `$HOME`, `${HOME}`), rutas relativas y rutas externas montadas.
  - Soporte de notación semántica de conveniencia `@media/<LABEL>/...` para enlazar discos externos por su etiqueta sin depender de la ruta fija asignada por el entorno de escritorio.
  - Detección automática de soportes extraíbles en `device_model_detect_external_drives` escaneando `/media/$USER/*`, `/run/media/$USER/*` y particiones no del sistema en `lsblk`.
  - Actualización atómica de destino con `device_model_update_config_destination`.
- **Asistente de Configuración Inicial (Onboarding Wizard) y Flag `--setup` (`app_controller.sh`):**
  - Flujo de primera ejecución activado automáticamente si `INITIAL_SETUP_DONE="false"`.
  - Detección inteligente de discos externos montados y recomendación por defecto de ruta local segura (`~/Backups/KeepMyConfig`).
  - Creación automática de la estructura de carpetas y despliegue del marcador de seguridad `.backup_storage_marker`.
  - Pregunta de persistencia de sesión: selección de arranque recordando el último perfil activo (`REMEMBER_LAST_PROFILE="true"`) o iniciando siempre en `default` (`"false"`).
  - Nuevo parámetro de consola `--setup` para ejecutar o reconfigurar el almacenamiento y preferencias en cualquier momento.
  - Submenú de almacenamiento renovado en la Opción 8 de la TUI: cambio de ruta universal y relanzamiento del asistente de onboarding.
- **Perfil Físico Predeterminado y Auto-Healing (`profile_model.sh`):**
  - Existencia permanente del archivo físico `profiles/default/profile.conf`.
  - Mecanismo de auto-recuperación transparente (*auto-healing*) en `profile_model_init_default` que recrea el archivo con valores canónicos ante borrados accidentales.
- **Automatización CI/CD con GitHub Actions:**
  - Workflow de CI (`.github/workflows/ci.yml`) con verificación sintáctica de Bash (`bash -n`) y ejecución de pruebas unitarias en `ubuntu-latest` para pushes y pull requests a `main` y `develop`.
  - Workflow de Release (`.github/workflows/release.yml`) para creación automática de Releases en GitHub ante pushes de tags (`v*`), con detección de pre-releases (`-alpha`, `-beta`, `-rc`), generación de notas de versión y empaquetado de distribución `.tar.gz`.
- **Sistema de Perfiles de Backup & Scoped Modules (Hito 12):**
  - **Modelo `profile_model.sh`:** Lógica pura de negocio para gestión CRUD de perfiles de backup (`profile_model_create`, `profile_model_get`, `profile_model_delete`, `profile_model_list`).
  - **Resolución en Cascada y Scoped Modules:** Resolución jerárquica de recetas (`profiles/<perfil>/modules.d/` prevalece sobre `modules.d/` global), permitiendo sobrescritura (*override*) y módulos exclusivos con aislamiento estricto.
  - **Deduplicación Automática:** Listado unificado de módulos (`profile_model_list_modules`) con deduplicación y ordenación alfabética.
  - **Vinculación Perfil-Destino:** Posibilidad de asociar un `TARGET_SUBDIR` específico a cada perfil (ej. `Backups/Docente` o `Backups/Desarrollo`).
  - **Persistencia Atómica de Perfil Activo:** Manejo de `ACTIVE_PROFILE` en `config/config.conf` vía `profile_model_set_active` y `profile_model_get_active`.
  - **Integración en Controlador y CLI:**
    - Flags `--profile <id>` para sobrescritura de sesión en cualquier comando.
    - Flags `--list-profiles`, `--set-active-profile <id>` y `--create-profile <id>`.
    - Indicador de ámbito (`[Global]`, `[Override]`, `[Exclusivo]`) en `--list-modules`.
  - **Integración TUI con Whiptail:**
    - Opción 9 en menú principal: *[PROFILES] Gestión de Perfiles de Backup*.
    - Visualización del perfil activo en el título del menú principal (`KeepMyConfig [Perfil: <id>]`).
    - Submenú completo para inspección, cambio de perfil activo, creación asistida, visualización de módulos con estado y borrado seguro de perfiles.
  - **Suite de Pruebas Unitarias:** 41 pruebas específicas en `tests/test_profile_model.sh` y 18 pruebas adicionales de integración en `tests/test_controller.sh`.
  - **Rebranding a KeepMyConfig:** Unificación de identidad y nombres en títulos de consola, diálogos de interfaz, cabeceras y scripts.
- **Módulos con Ámbito y Sanitización de Rutas (Sub-Hito 12.1):**
  - **Sanitización de Rutas en `module_model.sh`:** Función `module_model_sanitize_path` para normalización automática de rutas de recetas (`MODULE_PATHS`), suprimiendo prefijos `$HOME/`, `${HOME}/`, `~/` o `/home/<user>/`, eliminando barras redundantes y bloqueando intentos de directory traversal (`..`).
  - **Sanitización de Destinos en `profile_model.sh`:** Función `profile_model_sanitize_target_subdir` que garantiza que `TARGET_SUBDIR` sea una ruta relativa al medio de almacenamiento, limpiando barras iniciales redundantes y previniendo colisiones con el punto de montaje.
  - **Selector de Ámbito en Asistente TUI (`app_controller.sh`):** Al crear un módulo con un perfil activo distinto de `default`, se ofrece la opción de asignarlo al catálogo global (`modules.d/`) o exclusivamente al perfil activo (`profiles/<activo>/modules.d/`).
  - **Visualización de Ámbito en TUI:** Etiquetas visuales `[Global]` o `[Perfil: <id>]` al listar, inspeccionar o eliminar recetas en la Opción 7.
  - **Ampliación de Cobertura:** 49 nuevas aserciones en pruebas unitarias (`test_module_model.sh`, `test_profile_model.sh` y `test_controller.sh`), alcanzando 298 tests al 100% de éxito.
- **Biblioteca de Plantillas, Activación Selectiva y Exclusión en Perfiles (Sub-Hito 12.2):**
  - **Biblioteca de Plantillas (`templates.d/`):** Desacoplamiento del catálogo de recetas predefinidas en `templates.d/` con 9 recetas oficiales (`bash-env`, `firefox`, `git-config`, `intellij`, `libreoffice`, `ssh-keys`, `thunderbird`, `vscode-sensitive`, `vscode-standard`) y una plantilla de referencia canónica documentada (`template-skeleton.conf`).
  - **Estado Inicial Limpio (FR-TMPL-002):** Primera ejecución con 0 módulos activos en `modules.d/`. Al invocar `--backup-all` sin módulos activos, se muestra un mensaje explicativo y amigable sugiriendo la activación de plantillas, retornando código `0` en vez de error.
  - **Lógica de Plantillas en `module_model.sh`:** Funciones `module_model_list_templates`, `module_model_get_template`, `module_model_activate_template`, `module_model_create_template` y `module_model_export_to_template`.
  - **Exclusión de Módulos Globales en Perfiles (`profile_model.sh`):**
    - Soporte de directiva `DISABLED_MODULES=("mod1" "mod2")` en `profile.conf`.
    - Funciones `profile_model_get_disabled_modules`, `profile_model_disable_module` y `profile_model_enable_module`.
    - Filtrado en cascada en `profile_model_list_modules` y `profile_model_resolve_module` para excluir módulos globales deshabilitados en el perfil activo.
  - **Integración TUI y CLI (`app_controller.sh` y `backup_manager.sh`):**
    - Opción 7: Nuevas acciones para *Activar módulo desde plantilla*, *Crear nueva plantilla en la biblioteca* y *Exportar módulo activo a la biblioteca*.
    - Opción 9: Nueva acción para *Gestionar exclusiones de módulos globales* mediante checklist interactiva para perfiles no predeterminados.
    - Nuevas banderas CLI: `--list-templates`, `--enable-template <id>` y `--export-template <mod_id>`.
  - **Suites de Pruebas Actualizadas:** Cobertura ampliada en `tests/test_module_model.sh`, `tests/test_profile_model.sh` y `tests/test_controller.sh`, superando 318 pruebas unitarias al 100% de éxito.

### Fixed
- **Validación Jerárquica de Marcador y Sanitización de Destinos (`fix(storage)`):**
  - **Validación Jerárquica:** `device_model_validate_storage` ahora reconoce como válidas unidades de almacenamiento que tengan el marcador de seguridad en la raíz o en cualquier subdirectorio previo, auto-creando de forma atómica y transparente las nuevas subcarpetas de perfil (`mkdir -p`) sin obligar al usuario a ejecutar una inicialización manual previa.
  - **Sanitización de `STORAGE_SUBDIR`:** Implementada la función `device_model_sanitize_subdir` para depurar prefijos `$HOME`, `~` o `/home/<usuario>` antes de concatenar rutas, evitando la creación de carpetas físicas literales con el nombre `'$HOME'` dentro del almacenamiento.

### Planned
- Soporte para almacenamiento remoto (Hito 13: SSH, SFTP y Rsync sin privilegios root).

## [0.1.0-alpha.1] - 2026-09-20

### Added
- **Arquitectura MVC en Bash:** Separación estricta entre modelos de negocio (`lib/models/`), vistas desacopladas (`lib/views/`) y controlador orquestador (`lib/controllers/app_controller.sh`) para Lliurex 25 / Ubuntu 24.04 LTS sin privilegios de superusuario (`sudo`).
- **Almacenamiento Universal (`LOCAL_PATH`):** Soporte en `device_model.sh` para almacenamiento en cualquier carpeta local, segundo disco montado o recurso compartido sin depender de identificadores `lsblk`.
- **Mecanismo de Seguridad Anti-Escritura Fantasma:** Verificación mandatoria del archivo testigo `.backup_storage_marker` antes de cualquier operación de escritura en el destino.
- **Gestión Multi-Destino (`storage-target-init`):** Inicialización y conmutación de subdirectorios de máquina (`Backups/Lliurex25`, `Backups/Personal_PC`) tanto por CLI (`--init-target`, `--list-targets`, `--set-active-target`, `--target-subdir`) como mediante submenú interactivo en la TUI (Opción 8).
- **Criptografía de Grado Militar:** Cifrado y descifrado simétrico GPG con algoritmo AES-256 (`crypto_model.sh`), verificación en memoria y tuberías sin archivos intermedios descifrados en disco.
- **Purga Segura (Shred):** Sobrescritura destructiva multipaso (`shred -u -z -n 3`) en el equipo de origen para módulos confidenciales (`PURGE_AFTER_BACKUP=true`).
- **Motor de Empaquetado y Manifiesto:** Generación de copias comprimidas (`tar.zst` / `tar.gz`) con marcas de tiempo `AAAAMMDD_HHMMSS`, cálculo de hashes SHA-256 e inventario `manifest.txt`.
- **Motor de Restauración y Hooks:** Desempaquetado selectivo con descifrado al vuelo y ejecución de comandos posteriores (`POST_RESTORE_HOOK`).
- **Operaciones en Lote:** Opciones para respaldo y recuperación masiva por etiqueta o total (`--backup-all`, `--backup-tag`, `--restore-all`).
- **Interfaz Dual:** Modo TUI completo con `whiptail` y modo Headless no interactivo para automatización y scripts de consola.
- **Recetas de Módulos Base:** Configuraciones listas para VSCode (`vscode-standard`, `vscode-sensitive`), entorno Bash (`bash-env`) y credenciales SSH con purga (`ssh-keys`).
- **Suite de Pruebas Unitarias:** 8 suites de test con más de 100 aserciones automatizadas en `tests/`.
- **Escáner SAST de Privacidad:** Script pre-commit para prevención de fugas de contraseñas, rutas privadas locales o correos.

### Fixed
- **Asistente TUI de Módulos (`dev/fix/module-admin-wizard`):** Corrección en el paso y formateo de argumentos (`paths` delimitados por `|` y `tags` delimitados por `,`) en la llamada a `module_model_save` desde el controlador.

### Documentation
- **Manual de Usuario (`MANUAL_USUARIO.md`):** Documentación completa para usuario y administrador con diagramas de menús TUI, tablas CLI, recetas `.conf` y guía de resolución de problemas.
- **Especificación Técnica (`ESPECIFICACION.md`):** Arquitectura MVC, flujos de datos y diseño técnico.
- **Reglamento del Agente (`AGENT.md`):** Directrices de desarrollo, Conventional Commits, GitFlow, regla No-Spec-No-Code y gobernanza SemVer.
