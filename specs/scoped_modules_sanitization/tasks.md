# Lista Atómica de Tareas: Ámbito de Módulos y Sanitización (`scoped_modules_sanitization`)

**Sub-Hito:** 12.1  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## Tareas de Implementación

### Fase 1: Especificación y Diseño Guiado por Requerimientos (SDD)
- [x] Redactar `specs/scoped_modules_sanitization/spec.md`.
- [x] Redactar `specs/scoped_modules_sanitization/plan.md`.
- [x] Redactar `specs/scoped_modules_sanitization/tasks.md`.
- [x] Aprobación humana de los documentos de especificación.

---

### Fase 2: Sanitización de Rutas en `lib/models/module_model.sh`
- [x] Implementar función `module_model_sanitize_path`.
- [x] Integrar llamada a `module_model_sanitize_path` en `module_model_save`.
- [x] Añadir pruebas unitarias de sanitización en `tests/test_module_model.sh`.

---

### Fase 3: Sanitización de `TARGET_SUBDIR` en `lib/models/profile_model.sh`
- [x] Implementar función `profile_model_sanitize_target_subdir`.
- [x] Integrar llamada a la sanitización en `profile_model_create`.
- [x] Añadir pruebas unitarias en `tests/test_profile_model.sh`.

---

### Fase 4: Selector de Ámbito en el Asistente TUI (`lib/controllers/app_controller.sh`)
- [x] Adaptar asistente de creación de módulos para consultar ámbito si hay perfil activo (`modules.d/` vs `profiles/<activo>/modules.d/`).
- [x] Adaptar opciones de inspección y eliminación de módulos para soportar visualización de recetas de perfil.
- [x] Añadir pruebas de integración en `tests/test_controller.sh`.

---

### Fase 5: Verificación, Control de Calidad y Commit
- [x] Ejecución de la suite completa de pruebas unitarias (`for t in tests/test_*.sh; do bash "$t"; done`).
- [x] Ejecución del escáner SAST obligatorio (`bash user_data/scripts/security_check/security_check.sh --all`).
- [ ] Actualizar `CHANGELOG.md` y `PROXIMOS_PASOS.md`.
- [ ] Solicitar aprobación humana y realizar el commit del Sub-Hito 12.1.
