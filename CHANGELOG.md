# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Planned
- Sistema de "Perfiles de Backup" (Hito 12: perfiles de máquina con resolución en cascada, override y módulos exclusivos).
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
