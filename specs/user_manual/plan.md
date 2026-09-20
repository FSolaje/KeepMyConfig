# Plan de Implementación: Manual de Usuario Final (MANUAL_USUARIO.md)

**Documento:** `specs/user_manual/plan.md`  
**Rama:** `dev/feature/user-manual`  
**Fecha:** 2026-09-20  
**Estado:** Propuesta de Planificación

---

## 1. Visión y Alcance Técnico

El presente plan establece la hoja de ruta para la redacción y verificación del **Manual de Usuario Final (`MANUAL_USUARIO.md`)**, documento central de documentación del proyecto **BackupConfig**.

El manual se redactará en Markdown enriquecido (con esquemas de cajas ASCII para los diálogos de `whiptail`, tablas de parámetros CLI, bloques de código Bash y llamadas de atención estilo GitHub Markdown `[!NOTE]`, `[!WARNING]`, `[!TIP]`, `[!IMPORTANT]`).

---

## 2. Estructura y Contenidos Detallados por Capítulo

### Capítulo 1: Introducción, Arquitectura y Requisitos
- **Contexto educativo y docente:** Por qué surge la necesidad (máquinas de aula con reinicio/congelación o reinstalaciones periódicas de Lliurex 25 / Ubuntu 24.04).
- **Ejecución sin privilegios (Non-Root):** Explicación de cómo y por qué opera al 100% en el espacio de usuario (`$HOME`) sin requerir permisos de superusuario (`sudo`).
- **Pila tecnológica y dependencias:**
  - `whiptail` (interfaz TUI).
  - `gpg` (cifrado simétrico AES-256).
  - `tar` y `zstd` (empaquetado y compresión ultrarrápida).
  - `coreutils` (`shred`, `sha256sum`, `awk`, `date`, `readlink`).
- **Verificación rápida de dependencias en el sistema del usuario:** Comando de una sola línea para comprobar que el entorno está listo.

### Capítulo 2: Preparación del Almacenamiento Externo (SSD / USB)
- **Concepto del Safety Marker (`.backup_storage_marker`):**
  - Riesgo de escritura fantasma en punto de montaje vacío.
  - Cómo el marcador previene la saturación del disco interno si el SSD no está conectado.
- **Paso a paso de inicialización del SSD:**
  1. Identificar la unidad (`lsblk -f`).
  2. Localizar el punto de montaje o crear la ruta destino (ej. `/media/$USER/DISCO_BACKUP/Backups/Lliurex25/`).
  3. Copiar o crear el archivo testigo `.backup_storage_marker`.
- **Configuración central en `config/config.conf`:**
  - Métodos de resolución: `LABEL`, `UUID` o `STATIC_PATH`.
  - Explicación de los parámetros clave (`BACKUP_SUBDIR`, `COMPRESSION_ALGO`, `CIPHER_ALGO`, `LOG_RETENTION_DAYS`).

### Capítulo 3: Guía de Uso - Interfaz Interactiva TUI (`whiptail`)
- **Puesta en marcha:** Invocación con `./backup_manager.sh`.
- **Diagrama ASCII del Menú Principal:** Representación visual de la interfaz.
- **Desglose de las 8 opciones del Menú:**
  1. `[BACKUP] Realizar Backup Completo`: Respaldo integral de todos los módulos activos.
  2. `[BACKUP] Realizar Backup por Etiquetas`: Selección múltiple mediante checklist (ej. `dev`, `ide`, `auth`).
  3. `[BACKUP] Realizar Backup por Módulo Individual`: Selección granular de un solo módulo.
  4. `[RESTORE] Restauración Rápida de Datos Sensibles`: Localización del backup más reciente con módulos marcados como `IS_SENSITIVE=true` e inyección inmediata.
  5. `[RESTORE] Restauración Selectiva (Histórico)`: Navegación por marcas temporales (`AAAAMMDD_HHMMSS`) y selección de qué módulo restaurar.
  6. `[RESTORE] Restauración Total`: Reinstalación en bloque de todas las configuraciones del snapshot seleccionado.
  7. `[MODULES] Administrar Módulos y Etiquetas`: Asistente interactivo para crear recetas `.conf` y explorar etiquetas disponibles.
  8. `[CONFIG] Diagnóstico de Disco Externo y Estado`: Chequeo de conexión, espacio libre/ocupado y estado del marcador.
- **El Ciclo de Vida "Vault & Shred" en la TUI:**
  - Solicitud interactiva y enmascarada de la contraseña GPG.
  - Purga segura: diálogo de confirmación previo al `shred -u` para prevenir borrados accidentales de credenciales en el equipo de origen.

### Capítulo 4: Guía de Uso - Interfaz de Comandos CLI (Headless / Cron)
- **Sintaxis y tabla de argumentos:**
  - Flags de Backup: `--backup-all`, `--backup-tag <tag>`, `--backup-module <id>`, `--purge`, `--no-purge`.
  - Flags de Restauración: `--restore-sensitive`, `--restore-all`, `--restore-module <id>`, `--timestamp <YYYYMMDD_HHMMSS>`.
  - Flags de Utilidad: `--check-device`, `--list-modules`, `--list-tags`, `--help`.
- **Automatización Headless y Tareas Programadas (`cron`):**
  - Uso de la variable de entorno `PASSPHRASE="mi_clave"` para ejecución no interactiva.
  - Ejemplos de integración en crontab de usuario (`crontab -e`).
- **Tabla de códigos de salida UNIX:**
  - `0`: Operación completada con éxito.
  - `1`: Error general / sintaxis / cancelación.
  - `2`: Error de almacenamiento (disco desconectado o sin marcador).
  - `3`: Error de módulo (receta inválida o archivo ausente).
  - `4`: Error criptográfico (contraseña errónea o corrupción GPG).
  - `5`: Error de dependencias del sistema.

### Capítulo 5: Creación de Módulos y Recetas (`modules.d/*.conf`)
- **Estructura estándar de una receta:**
  - `MODULE_ID`: Identificador alfanumérico único.
  - `MODULE_NAME`: Nombre legible para menús y logs.
  - `MODULE_TAGS`: Array Bash de etiquetas asociadas.
  - `MODULE_PATHS`: Array Bash de rutas absolutas o relativas al `$HOME`.
  - `IS_SENSITIVE`: Booleano (`true`/`false`) para cifrado GPG obligatorio.
  - `PURGE_AFTER_BACKUP`: Booleano (`true`/`false`) para activar la purga `shred -u`.
  - `POST_RESTORE_HOOK`: Función Bash para restaurar permisos o ejecutar ajustes.
- **Estudio de las 4 recetas oficiales del sistema:**
  - `vscode-standard.conf`: Configuración abierta de extensiones y preferencias.
  - `vscode-sensitive.conf`: Credenciales y almacenamiento seguro con purga.
  - `bash-env.conf`: Entorno y dotfiles de consola.
  - `ssh-keys.conf`: Llaves SSH con gancho de seguridad `chmod 700 / 600`.

### Capítulo 6: Auditoría, Logs y Resolución de Problemas
- **Estructura del árbol de almacenamiento:**
  - `Backups/archives/`: Archivos comprimidos `.tar.zst` y vaults `.tar.zst.gpg`.
  - `Backups/logs/`: `backup_history.log`, `.manifest.log` y `.diff.log`.
- **Interpretación del sistema de manifiestos:**
  - Símbolos de estado: `+` (nuevo), `~` (modificado), `-` (eliminado).
- **Matriz de Troubleshooting (Problema -> Diagnóstico -> Solución):**
  - Almacenamiento no detectado o marcador ausente.
  - Error en frase de paso GPG (firma corrupta o clave incorrecta).
  - Permisos insuficientes al restaurar en carpetas locales.
  - Fallo de espacio en disco en la unidad externa.

---

## 3. Plan de Verificación y Calidad

1. **Revisión de consistencia técnica:** Contrastar cada comando CLI y código de salida con `backup_manager.sh` y los tests existentes.
2. **Revisión de enlaces y rutas:** Comprobar que todas las rutas relativas referenciadas (`config/config.conf`, `modules.d/`, `markers/.backup_storage_marker`) existen en el repositorio.
3. **Escáner SAST obligatorio:**
   ```bash
   bash user_data/security_check/scripts/security_check.sh --all
   ```
4. **Presentación al usuario:** Solicitar la confirmación explícita previa a cualquier operación de commit.
