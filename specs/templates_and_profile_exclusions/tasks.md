# Lista Atómica de Tareas: Biblioteca de Plantillas y Exclusiones en Perfiles (`templates_and_profile_exclusions`)

**Sub-Hito:** 12.2  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## Tareas de Implementación

### Fase 1: Especificación y Diseño Guiado por Requerimientos (SDD)
- [x] Redactar `specs/templates_and_profile_exclusions/spec.md`.
- [x] Redactar `specs/templates_and_profile_exclusions/plan.md`.
- [x] Redactar `specs/templates_and_profile_exclusions/tasks.md`.
- [x] Aprobación humana de los documentos de especificación.

---

### Fase 2: Catálogo `templates.d/` y Modelo de Módulos (`module_model.sh`)
- [x] Crear plantilla de referencia canónica:
  - `templates.d/template-skeleton.conf`
- [x] Crear directorio `templates.d/` con recetas estandarizadas:
  - `templates.d/ssh-keys.conf`
  - `templates.d/bash-env.conf`
  - `templates.d/firefox.conf`
  - `templates.d/vscode-standard.conf`
  - `templates.d/vscode-sensitive.conf`
  - `templates.d/intellij.conf`
  - `templates.d/git-config.conf`
  - `templates.d/thunderbird.conf`
  - `templates.d/libreoffice.conf`
- [x] Asegurar catálogo inicial limpio (`modules.d/` vacío excepto `.gitkeep`).
- [x] Implementar `module_model_list_templates` en `lib/models/module_model.sh`.
- [x] Implementar `module_model_get_template` en `lib/models/module_model.sh`.
- [x] Implementar `module_model_activate_template` en `lib/models/module_model.sh`.
- [x] Implementar `module_model_create_template` en `lib/models/module_model.sh`.
- [x] Implementar `module_model_export_to_template` en `lib/models/module_model.sh`.
- [x] Añadir pruebas unitarias de plantillas en `tests/test_module_model.sh`.

---

### Fase 3: Soporte `DISABLED_MODULES` en Perfiles (`profile_model.sh`)
- [x] Adaptar `profile_model_get` para parsear y devolver `DISABLED_MODULES`.
- [x] Adaptar `profile_model_list_modules` para filtrar y excluir módulos globales listados en `DISABLED_MODULES`.
- [x] Implementar `profile_model_get_disabled_modules`.
- [x] Implementar `profile_model_disable_module` (añadir módulo a la lista de exclusión en `profile.conf`).
- [x] Implementar `profile_model_enable_module` (quitar módulo de la lista de exclusión en `profile.conf`).
- [x] Añadir pruebas unitarias de exclusiones en `tests/test_profile_model.sh`.

---

### Fase 4: Integración en Asistentes TUI y CLI (`app_controller.sh` y `backup_manager.sh`)
- [x] Integrar acciones en `controller_handle_modules_admin` (Opción 7 de la TUI):
  - *Activar módulo desde plantilla*
  - *Crear nueva plantilla en la biblioteca*
  - *Exportar módulo activo a la biblioteca de plantillas*
- [x] Integrar acción *Gestionar exclusiones de módulos globales* en `controller_handle_profiles_admin` (Opción 9 de la TUI).
- [x] Añadir comandos CLI:
  - `--list-templates`
  - `--enable-template <id>`
  - `--export-template <mod_id>`
- [x] Adaptar `--backup-all` para mostrar mensaje amigable si no hay módulos activos de inicio.
- [x] Añadir pruebas de integración en `tests/test_controller.sh`.

---

### Fase 5: Actualización Mandatoria de Documentación (Regla Sección 10 AGENT.md)
- [x] Actualizar `README.md` documentando la biblioteca de plantillas y el mecanismo de activación y exclusión por perfil.
- [x] Actualizar `MANUAL_USUARIO.md` con capturas de flujo TUI y comandos CLI para gestión de plantillas y exclusiones.
- [x] Actualizar `CHANGELOG.md` bajo `[Unreleased]`.
- [x] Actualizar `PROXIMOS_PASOS.md`.

---

### Fase 6: Calidad, Verificación y Commit
- [x] Ejecutar suite completa de pruebas unitarias (`for t in tests/test_*.sh; do bash "$t"; done`).
- [ ] Ejecutar escáner SAST obligatorio (`bash user_data/scripts/security_check/security_check.sh --all`).
- [ ] Solicitar aprobación humana y realizar el commit independiente del Sub-Hito 12.2.
