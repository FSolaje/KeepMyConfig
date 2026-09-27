# Especificación de Requerimientos: Ruta Universal de Backup, Destino por Perfil y Asistente de Onboarding

**Sub-Hito:** 12.3  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Contexto y Objetivos del Cambio

KeepMyConfig contaba con un esquema de configuración de almacenamiento fragmentado en múltiples directivas (`STORAGE_ID_TYPE`, `STORAGE_ID_VALUE`, `STORAGE_SUBDIR`, `STORAGE_STATIC_FALLBACK` y `TARGET_SUBDIR` en perfiles). Esta fragmentación causaba sobre-ingeniería, errores de concatenación (como la creación accidental de carpetas literales `'$HOME'`) y obligaba al usuario a realizar inicializaciones manuales de marcadores en cada nuevo perfil antes de poder realizar copias.

El objetivo del **Sub-Hito 12.3** es:
1. **Unificar el almacenamiento en una única directiva canónica:** `BACKUP_DESTINATION`, que soporte rutas locales y soportes externos sin distinción artificial.
2. **Establecer Convención sobre Configuración en Perfiles:** Cada perfil nuevo guarda automáticamente en `<BACKUP_DESTINATION>/<id_perfil>/` sin requerir pasos manuales de configuración ni inicialización.
3. **Persistencia Física de `profiles/default`:** Crear el directorio y archivo `profiles/default/profile.conf` con regeneración automática ante pérdidas accidentales (*auto-healing*).
4. **Asistente de Primera Ejecución (Onboarding Wizard en TUI):** Guiar amigablemente al usuario en su primer arranque (`INITIAL_SETUP_DONE="false"`), sugiriendo `$HOME/Backups/KeepMyConfig` para copias locales o detectando automáticamente discos externos montados.
5. **Control de Sesión (`REMEMBER_LAST_PROFILE`):** Permitir elegir si la aplicación arranca en el último perfil utilizado o siempre en `default`.

---

## 2. Requerimientos Funcionales (FR)

### FR-STO-001: Directiva de Ruta Universal (`BACKUP_DESTINATION`)
- `config/config.conf` adoptará la directiva unificada:
  ```ini
  BACKUP_DESTINATION="~/Backups/KeepMyConfig"
  ```
- La función de resolución `device_model_resolve_destination` en `lib/models/device_model.sh` normalizará la ruta:
  - Prefijos `~`, `$HOME`, `${HOME}` se expanden al `$TARGET_USER_HOME` o `$HOME` del usuario.
  - Rutas relativas sin barra inicial (ej. `Backups/KeepMyConfig`) se resuelven relativas a `$HOME`.
  - Rutas absolutas (ej. `/media/$USER/DISCO_BACKUP/Backups`) se utilizan directamente.
  - Soporte de etiqueta semántica opcional: `@media/<LABEL>/<subdir>` (ej. `@media/DISCO_BACKUP/Backups`), que consulta dinámicamente `device_model_find_mount "LABEL" "<LABEL>"` para tolerar variaciones en el punto de montaje.
- **Ruptura Limpia de Compatibilidad (Breaking Change / Clean Slate):** Dado el estado de pre-release privado, se eliminan completamente las directivas obsoletas `STORAGE_ID_TYPE`, `STORAGE_ID_VALUE`, `STORAGE_SUBDIR` y `STORAGE_STATIC_FALLBACK`. `BACKUP_DESTINATION` se establece como la única directiva canónica y mandatoria de almacenamiento.

### FR-STO-002: Convención Automática de Destinos por Perfil (Zero-Config)
- Cuando el perfil activo sea `default`, el destino efectivo será `BACKUP_DESTINATION`.
- Cuando el perfil activo sea específico (ej. `docente`, `desarrollo`, `PerfilPruebas`):
  - Si `profile.conf` NO define `TARGET_SUBDIR` (o está vacío), el sistema asigna automáticamente:
    `<BACKUP_DESTINATION>/<id_perfil>`
  - Si `profile.conf` define explícitamente `TARGET_SUBDIR="mi/ruta"`, se respeta como subdirectorio dentro de `BACKUP_DESTINATION`.
- La creación física de la carpeta del perfil y su archivo testigo `.backup_storage_marker` ocurre de forma automática y transparente (`mkdir -p`) en el primer respaldo si el almacenamiento base está verificado.

### FR-STO-003: Directorio Físico Permanente y Auto-reparación de `profiles/default`
- Se creará físicamente en el repositorio el archivo `profiles/default/profile.conf`:
  ```ini
  PROFILE_ID="default"
  PROFILE_NAME="Perfil Global / Predeterminado"
  PROFILE_DESCRIPTION="Entorno general base compartido por todos los perfiles"
  TARGET_SUBDIR=""
  DISABLED_MODULES=()
  ```
- Si `profiles/default/profile.conf` es eliminado accidentalmente, el modelo `profile_model` lo regenerará automáticamente con sus valores canónicos.
- Se mantiene el bloqueo estricto en `profile_model_delete` impidiendo eliminar el perfil `default`.

### FR-STO-004: Asistente Interactivo de Primera Ejecución (Onboarding Wizard)
- Se incorpora la bandera `INITIAL_SETUP_DONE="false"` en la configuración inicial de `config.conf`.
- Al iniciar `backup_manager.sh` en modo TUI (interactivo):
  - Si `INITIAL_SETUP_DONE="false"`, antes de mostrar el menú principal se invoca el **Asistente de Bienvenida**:
    1. **Pantalla de Bienvenida:** Explica el funcionamiento de KeepMyConfig, la ausencia de privilegios `root` y la protección de datos en entornos de aula o trabajo.
    2. **Detección y Selección de Destino:**
       - El sistema audita `/media/$USER/*` y `lsblk` buscando unidades externas conectadas.
       - Si encuentra unidades externas (ej. `DISCO_BACKUP`), las ofrece como opción seleccionable.
       - Ofrece la opción por defecto para almacenamiento local: `$HOME/Backups/KeepMyConfig`.
       - Permite ingresar una ruta libre personalizada.
    3. **Inicialización Transparente:** Crea la carpeta seleccionada y despliega `.backup_storage_marker`.
    4. **Preferencia de Arranque:** Pregunta si desea recordar el último perfil de trabajo (`REMEMBER_LAST_PROFILE=true/false`).
    5. **Finalización:** Guarda las preferencias en `config/config.conf`, cambia `INITIAL_SETUP_DONE="true"` y abre el menú principal.
- Se añade el comando CLI `backup_manager.sh --setup` para poder re-ejecutar el asistente en cualquier momento.

### FR-STO-005: Política de Persistencia de Perfil (`REMEMBER_LAST_PROFILE`)
- Directiva en `config/config.conf`: `REMEMBER_LAST_PROFILE="true"` o `"false"`.
- Al arrancar la aplicación:
  - Si `REMEMBER_LAST_PROFILE="false"`, el perfil activo se reasigna a `default` al inicio de cada sesión (ideal para ordenadores de aula compartidos).
  - Si `REMEMBER_LAST_PROFILE="true"`, se preserva el último perfil utilizado en `ACTIVE_PROFILE`.

### FR-STO-006: Actualización de Diagnóstico y Comandos CLI
- `--check-device`: Muestra el diagnóstico actualizado evaluando `BACKUP_DESTINATION`, tipo de soporte (Local vs Externo montado), ruta del marcador y espacio libre.
- `--setup`: Lanza el asistente interactivo de configuración.

---

## 3. Criterios de Aceptación

1. Una instalación limpia con `INITIAL_SETUP_DONE="false"` lanza el Onboarding Wizard al ejecutar `./backup_manager.sh`.
2. Al seleccionar la opción local por defecto, se crea `$HOME/Backups/KeepMyConfig` con `.backup_storage_marker` y `INITIAL_SETUP_DONE` pasa a `"true"`.
3. Al crear un nuevo perfil sin especificar subdirectorio, el primer backup se guarda exitosamente en `<BACKUP_DESTINATION>/<id_perfil>` de forma transparente.
4. El archivo `profiles/default/profile.conf` existe físicamente y se auto-repara si se elimina.
5. Si `REMEMBER_LAST_PROFILE="false"`, la sesión arranca siempre en `default`.
6. Todas las suites de pruebas unitarias (más de 320 tests) pasan al 100% de éxito.
