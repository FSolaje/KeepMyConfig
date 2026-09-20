# Lista de Tareas Atómicas: Corrección del Asistente de Módulos (TUI)

**Módulo:** `lib/controllers/app_controller.sh` & `lib/models/module_model.sh`  
**Rama:** `dev/fix/module-admin-wizard`  
**Fecha:** 2026-09-20  

---

## Tareas de Especificación y Planificación (SDD)
- [x] Redactar especificación de requerimientos (`specs/module_admin_wizard/spec.md`).
- [x] Redactar plan técnico de implementación (`specs/module_admin_wizard/plan.md`).
- [x] Redactar lista de tareas atómicas (`specs/module_admin_wizard/tasks.md`).

---

## Tareas de Implementación en Código de Producción
- [x] **Controlador (`lib/controllers/app_controller.sh`):**
  - [x] En `controller_handle_modules_admin`, ensamblar `paths_joined` con delimitador `|`.
  - [x] Ensamblar `tags_joined` con delimitador `,`.
  - [x] Corregir la llamada a `module_model_save` con los 8 parámetros en el orden correcto.
- [x] **Modelo (`lib/models/module_model.sh`):**
  - [x] Soportar comas o espacios en el parseo de tags dentro de `module_model_save`.

---

## Tareas de Pruebas y Verificación
- [x] Añadir prueba unitaria de creación de módulo con los nuevos parámetros en `tests/test_controller.sh`.
- [x] Ejecutar la suite unitaria completa de pruebas (`tests/test_*.sh`).
- [x] Ejecutar el escáner SAST obligatorio (`user_data/security_check/scripts/security_check.sh --all`).
- [x] Validar manualmente o con reproducer la creación de `test-cualquiera`.

---

## Tareas de Gobernanza Git y Cierre
- [ ] Presentar informe de verificación al usuario y solicitar confirmación ("Procede con el commit").
- [ ] Realizar commit atómico bajo Conventional Commits (`fix(controller): corregir llamada a module_model_save en asistente TUI`).
- [ ] Integrar rama en `develop` mediante merge no rápido (`--no-ff`).
