# Especificación de Requerimientos: Manual de Usuario Final (MANUAL_USUARIO.md)

**Documento:** `MANUAL_USUARIO.md`  
**Rama:** `dev/feature/user-manual`  
**Estado:** Propuesta / En Revisión  
**Audiencia:** Docentes, administradores de aula y estudiantes en entornos Lliurex 25 / Ubuntu 24.04  

---

## 1. Propósito y Filosofía del Manual

El objetivo del **Manual de Usuario Final** es proporcionar una guía operativa exhaustiva, didáctica y autosuficiente para el uso diario del gestor **BackupConfig**, cubriendo tanto la interfaz gráfica de terminal (**TUI interactiva** con `whiptail`) como la interfaz de línea de órdenes (**CLI headless** para scripts y tareas desatendidas).

A diferencia de las especificaciones técnicas internas de `specs/` (orientadas al desarrollo del código), este documento está enfocado en la experiencia del usuario final: qué hace cada opción, cómo proteger y recuperar los datos, y cómo resolver incidencias comunes.

---

## 2. Requerimientos de Contenido y Estructura

El documento `MANUAL_USUARIO.md` debe estructurarse en 6 capítulos esenciales:

### Capítulo 1: Introducción, Arquitectura y Requisitos
- Contexto: Preservación de configuraciones docentes y de desarrollo en estaciones de trabajo Lliurex 25 / Ubuntu 24.04 ante restauraciones del sistema de aula (SAI / congelación).
- Ejecución 100% como usuario estándar (**sin privilegios `sudo`**).
- Dependencias básicas del sistema y cómo comprobarlas (`whiptail`, `gpg`, `zstd`, `tar`).

### Capítulo 2: Preparación del Almacenamiento Externo (SSD / USB)
- Estructura de carpetas requerida en el soporte de almacenamiento (`Backups/`, `archives/`, `logs/`).
- El mecanismo de seguridad **Safety Marker** (`.backup_storage_marker`): qué es, por qué previene escrituras fantasma en el disco local y cómo inicializarlo en el SSD.
- Configuración en `config/config.conf` (`STORAGE_ID_TYPE=LABEL|UUID|STATIC_PATH`).

### Capítulo 3: Guía de Uso - Interfaz Interactiva TUI (`whiptail`)
- Invocación interactiva (`./backup_manager.sh`).
- Esquema visual ASCII del Menú Principal.
- Recorrido operativo detallado por las 8 opciones:
  1. `[BACKUP] Realizar Backup Completo`
  2. `[BACKUP] Realizar Backup por Etiquetas (Tags)`
  3. `[BACKUP] Realizar Backup por Módulo Individual`
  4. `[RESTORE] Restauración Rápida de Datos Sensibles`
  5. `[RESTORE] Restauración Selectiva (Módulo / Histórico AAAAMMDD_HHMMSS)`
  6. `[RESTORE] Restauración Total`
  7. `[MODULES] Administrar Módulos y Etiquetas (Asistente TUI)`
  8. `[CONFIG] Diagnóstico de Disco Externo y Estado`
- Explicación del ciclo de vida **Vault & Shred**: cuándo y por qué solicita la contraseña GPG, qué hace la purga segura con `shred -u` y cómo funciona la advertencia interactiva de seguridad post-backup.

### Capítulo 4: Guía de Uso - Interfaz de Comandos CLI (Headless / Cron)
- Sintaxis general y listado completo de opciones (`--backup-all`, `--backup-tag`, `--backup-module`, `--purge`, `--no-purge`, `--restore-sensitive`, `--restore-all`, `--restore-module`, `--timestamp`, `--check-device`, `--list-modules`, `--list-tags`, `--help`).
- Automatización desatendida mediante variable de entorno `PASSPHRASE`.
- Tabla de códigos de salida UNIX (`0`, `1`, `2`, `3`, `4`, `5`) para integración en scripts de shell o `cron`.

### Capítulo 5: Guía para Administradores: Creación de Nuevas Recetas (`modules.d/*.conf`)
- Estructura declarativa de un módulo Bash.
- Significado de cada directiva (`MODULE_ID`, `MODULE_NAME`, `MODULE_TAGS`, `MODULE_PATHS`, `IS_SENSITIVE`, `PURGE_AFTER_BACKUP`, `POST_RESTORE_HOOK`).
- Ejemplos prácticos comentados basados en las 4 recetas del sistema:
  - `vscode-standard.conf` (configuración abierta).
  - `vscode-sensitive.conf` (credenciales y tokens cifrados con purga).
  - `bash-env.conf` (entorno shell persistente).
  - `ssh-keys.conf` (llaves criptográficas con hook de permisos `chmod 700 / 600`).

### Capítulo 6: Auditoría, Logs y Resolución de Problemas (Troubleshooting)
- Localización y formato del historial `Backups/logs/backup_history.log`.
- Lectura e interpretación de manifiestos `.manifest.log` y diffs (`+`, `~`, `-`).
- Guía de resolución para errores típicos:
  - *Marcador no encontrado* (`STORAGE_MARKER_MISSING`).
  - *Error de contraseña GPG*.
  - *Fichero no encontrado o permisos locales insuficientes*.
