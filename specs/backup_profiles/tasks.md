# Lista Atómica de Tareas: Sistema de Perfiles de Backup (`backup-profiles`)

**Rama:** `dev/feature/backup-profiles`  
**Estado:** Completado y Verificado  
**Fecha:** 2026-09-21  

---

## Tareas de Implementación

### Fase 1: Especificación y Diseño Guiado por Requerimientos (SDD)
- [x] Crear rama de funcionalidad `dev/feature/backup-profiles` a partir de `develop`.
- [x] Redactar `specs/backup_profiles/spec.md`.
- [x] Redactar `specs/backup_profiles/plan.md`.
- [x] Redactar `specs/backup_profiles/tasks.md`.
- [x] Revisión y aprobación humana de los documentos de especificación.

---

### Fase 2: Implementación del Modelo `lib/models/profile_model.sh`
- [x] Definir constantes y códigos de error (`PROFILE_OK`, `PROFILE_ERR_*`).
- [x] Implementar `profile_model_validate_id`.
- [x] Implementar `profile_model_list`.
- [x] Implementar `profile_model_get` (con soporte para perfil `default`).
- [x] Implementar `profile_model_create`.
- [x] Implementar `profile_model_delete`.
- [x] Implementar `profile_model_resolve_module` (resolución en cascada).
- [x] Implementar `profile_model_list_modules` (deduplicación y ordenación).
- [x] Implementar `profile_model_get_active` y `profile_model_set_active`.

---

### Fase 3: Suite de Pruebas Unitarias del Modelo (`tests/test_profile_model.sh`)
- [x] Crear archivo `tests/test_profile_model.sh` con sandbox temporal.
- [x] Test 1: Validación sintáctica de IDs (válidos e inválidos).
- [x] Test 2: Metadatos del perfil por defecto `default`.
- [x] Test 3: Creación de perfil y lectura de `profile.conf`.
- [x] Test 4: Listado de múltiples perfiles.
- [x] Test 5: Resolución de módulo existente solo en global.
- [x] Test 6: Resolución de módulo sobrescrito (*override*) por el perfil activo.
- [x] Test 7: Resolución de módulo exclusivo del perfil activo.
- [x] Test 8: Aislamiento estricto de módulo exclusivo entre perfiles distintos.
- [x] Test 9: Deduplicación al listar módulos con *override*.
- [x] Test 10: Persistencia atómica de `ACTIVE_PROFILE` en `config.conf`.
- [x] Ejecutar y validar que todas las pruebas pasen al 100%.

---

### Fase 4: Integración en el Controlador y CLI (`lib/controllers/app_controller.sh`)
- [x] Cargar `profile_model.sh` en `controller_init`.
- [x] Soporte para flag CLI `--profile <id>`.
- [x] Soporte para flags CLI `--list-profiles`, `--set-active-profile <id>` y `--create-profile`.
- [x] Integrar resolución de destino (`TARGET_SUBDIR` del perfil activo) en `_controller_get_backup_dir`.
- [x] Integrar resolución de módulos en operaciones masivas y específicas de backup y restore.
- [x] Actualizar texto de ayuda `app_controller_help`.

---

### Fase 5: Integración en la Interfaz TUI (Whiptail)
- [x] Mostrar perfil activo en el título y banners del menú principal.
- [x] Añadir opción en menú principal: `9) Gestión de Perfiles de Backup`.
- [x] Implementar submenú interactivo de perfiles:
  - Ver información del perfil activo.
  - Cambiar perfil activo (radiolist).
  - Crear nuevo perfil (asistente interactivo).
  - Listar recetas del perfil activo indicando estado `[Global]`, `[Override]` o `[Exclusivo]`.

---

### Fase 6: Unificación de Identidad `KeepMyConfig`
- [x] Actualizar banners y títulos en `backup_manager.sh`.
- [x] Actualizar títulos por defecto en `lib/views/ansi_view.sh` y `lib/views/whiptail_view.sh`.
- [x] Actualizar cabecera de `config/config.conf` y `lib/controllers/app_controller.sh`.
- [ ] Actualizar referencias en `MANUAL_USUARIO.md` y `README.md`.

---

### Fase 7: Validación, Control de Calidad y Cierre de Hito
- [x] Ejecución de la suite completa de pruebas unitarias (`for t in tests/test_*.sh; do bash "$t"; done`).
- [x] Ejecución del escáner SAST obligatorio (`bash user_data/scripts/security_check/security_check.sh --all`).
- [ ] Actualizar `CHANGELOG.md` reflejando el Hito 12.
- [ ] Actualizar `PROXIMOS_PASOS.md`.
- [ ] Solicitar aprobación humana para el commit e integración en `develop`.
