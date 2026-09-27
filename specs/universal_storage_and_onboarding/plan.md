# Plan Técnico y Arquitectónico: Ruta Universal de Backup, Destino por Perfil y Asistente de Onboarding

**Sub-Hito:** 12.3  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Arquitectura del Sistema

### 1.1 Modelo `device_model.sh`
- **Función `device_model_resolve_destination`:**
  - Resuelve la ruta canónica a partir de `BACKUP_DESTINATION`.
  - Interpreta prefijos `~`, `$HOME`, `${HOME}`, rutas relativas al `$HOME`, rutas absolutas y notación semántica `@media/<LABEL>/<subdir>`.
- **Función `device_model_detect_external_drives`:**
  - Audita puntos de montaje activos bajo `/media/$USER/` y `/run/media/$USER/`, devolviendo una lista formateada `LABEL|PUNTO_DE_MONTAJE|ESPACIO_LIBRE`.
- **Función `device_model_update_config_destination`:**
  - Actualiza atómicamente la variable `BACKUP_DESTINATION` en `config.conf`.
- **Adaptación de `device_model_validate_storage`:**
  - Valida directamente la ruta de destino resuelta mediante `device_model_resolve_destination` a partir de `BACKUP_DESTINATION`.
  - Comprueba el marcador `.backup_storage_marker` con soporte jerárquico y permisos de escritura.
  - Si la ruta es válida y escribible, auto-crea la carpeta y su marcador de seguridad si aún no existen.

### 1.2 Modelo `profile_model.sh`
- **Función `profile_model_init_default`:**
  - Asegura que `profiles/default/profile.conf` exista con su estructura canónica.
  - Implementa auto-reparación (*auto-healing*) invocada por `profile_model_get "default"`.
- **Resolución de Destino por Perfil (`profile_model_get_destination`):**
  - Si el perfil define `TARGET_SUBDIR`, lo concatena a la base: `<BACKUP_DESTINATION>/<TARGET_SUBDIR>`.
  - Si no define `TARGET_SUBDIR`, adopta por convención: `<BACKUP_DESTINATION>/<id_perfil>` (o la raíz si es `default`).

### 1.3 Controlador `app_controller.sh`
- **Función `controller_check_onboarding`:**
  - Al iniciar `controller_run_tui`: comprueba `INITIAL_SETUP_DONE`.
  - Si es `"false"`, lanza `controller_handle_onboarding_wizard`.
- **Función `controller_handle_onboarding_wizard`:**
  - Diálogos Whiptail: bienvenida, selector de destino (lista discos detectados, opción local `$HOME/Backups/KeepMyConfig` y entrada manual), inicialización de marcador y confirmación de `REMEMBER_LAST_PROFILE`.
  - Actualiza `config/config.conf` marcando `INITIAL_SETUP_DONE="true"`.
- **Control de Sesión al inicio:**
  - Si `REMEMBER_LAST_PROFILE=="false"`, fuerza `ACTIVE_PROFILE="default"` al arrancar la TUI.
- **Comando CLI `--setup`:**
  - Lanza el asistente interactivo de forma explícita.

### 1.4 Plantilla de Configuración (`config/config.conf`)
- Adopción de nuevas directivas:
  ```ini
  INITIAL_SETUP_DONE="false"
  BACKUP_DESTINATION="~/Backups/KeepMyConfig"
  REMEMBER_LAST_PROFILE="true"
  ```

---

## 2. Walkthrough de Impacto

- **Clean Slate (Sin deuda técnica):** Eliminación total de variables de almacenamiento fragmentadas (`STORAGE_ID_TYPE`, `STORAGE_ID_VALUE`, `STORAGE_SUBDIR`, `STORAGE_STATIC_FALLBACK`) a favor de una única directiva canónica `BACKUP_DESTINATION`.
- **Zero-Friction:** Crear un perfil ya no requiere ningún paso de `init-target`. El primer backup crea el directorio automáticamente con permisos de usuario.
- **Onboarding Guiado:** Un usuario que descarga KeepMyConfig por primera vez no necesita leer el manual para saber dónde se guardan sus copias; el asistente le ofrece un destino local inmediato o su pendrive en 3 clics.
