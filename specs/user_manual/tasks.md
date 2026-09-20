# Lista de Tareas Atómicas: Manual de Usuario Final (MANUAL_USUARIO.md)

**Documento:** `specs/user_manual/tasks.md`  
**Rama:** `dev/feature/user-manual`  
**Fecha:** 2026-09-20  

---

## Tareas de Especificación y Planificación (SDD)
- [x] Redactar especificación de requerimientos (`specs/user_manual/spec.md`).
- [x] Redactar plan técnico de implementación (`specs/user_manual/plan.md`).
- [x] Redactar lista de tareas atómicas (`specs/user_manual/tasks.md`).
- [ ] Presentar el paquete SDD (`spec.md`, `plan.md`, `tasks.md`) al usuario y obtener aprobación.

---

## Tareas de Redacción del Manual (`MANUAL_USUARIO.md`)
- [x] **Capítulo 1: Introducción, Arquitectura y Requisitos**
  - [x] Contexto en Lliurex 25 / Ubuntu 24.04 ante congelación o restauración de aulas.
  - [x] Principio de ejecución como usuario estándar sin privilegios (`sudo`).
  - [x] Verificación de dependencias (`whiptail`, `gpg`, `zstd`, `tar`, `coreutils`).
- [x] **Capítulo 2: Preparación del Almacenamiento Externo (SSD / USB)**
  - [x] Explicación del mecanismo de seguridad Safety Marker (`.backup_storage_marker`).
  - [x] Guía paso a paso de inicialización en la unidad externa.
  - [x] Configuración de resolución de unidad en `config/config.conf` (`LABEL`, `UUID`, `STATIC_PATH`).
- [x] **Capítulo 3: Guía de Uso - Interfaz Interactiva TUI (`whiptail`)**
  - [x] Invocación y esquema ASCII del Menú Principal.
  - [x] Documentación detallada de las 8 opciones de menú.
  - [x] Flujo operativo y advertencias del ciclo "Vault & Shred".
- [x] **Capítulo 4: Guía de Uso - Interfaz de Comandos CLI (Headless / Cron)**
  - [x] Tabla exhaustiva de argumentos de línea de comandos.
  - [x] Automatización no interactiva mediante `PASSPHRASE`.
  - [x] Ejemplos de uso diario y programación en `crontab`.
  - [x] Tabla de códigos de salida UNIX (`0` a `5`).
- [x] **Capítulo 5: Creación de Módulos y Recetas (`modules.d/*.conf`)**
  - [x] Formato y directivas requeridas en una receta de backup.
  - [x] Detalle comentado de las 4 recetas oficiales (`vscode-standard`, `vscode-sensitive`, `bash-env`, `ssh-keys`).
  - [x] Implementación y consideraciones de los hooks post-restauración (`POST_RESTORE_HOOK`).
- [x] **Capítulo 6: Auditoría, Logs y Resolución de Problemas (Troubleshooting)**
  - [x] Estructura de logs en el disco externo (`backup_history.log`).
  - [x] Lectura de manifiestos `.manifest.log` y detección de diffs (`+`, `~`, `-`).
  - [x] Matriz de incidencias comunes, diagnóstico y soluciones paso a paso.

---

## Tareas de Verificación, Calidad y Gobernanza Git
- [ ] Ejecutar escáner SAST obligatorio (`user_data/security_check/scripts/security_check.sh --all`).
- [ ] Comprobar que no existen rutas privadas ni credenciales filtradas.
- [ ] Solicitar aprobación explícita al usuario para el commit ("Procede con el commit").
- [ ] Realizar commit atómico bajo Conventional Commits (`docs(manual): redactar manual de usuario final TUI y CLI`).
- [ ] Integrar la rama `dev/feature/user-manual` en `develop` preservando el historial (`--no-ff`).
