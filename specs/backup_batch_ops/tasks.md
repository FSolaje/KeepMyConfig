# Lista de Tareas Atómicas: Operaciones de Backup por Lotes (Batch Ops)

**Módulo:** `lib/models/backup_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-batch-ops`  
**Fecha:** 2026-09-20  

---

## Tareas de Especificación y Planificación (SDD)
- [x] Redactar especificación de requerimientos (`specs/backup_batch_ops/spec.md`).
- [x] Redactar plan técnico de implementación (`specs/backup_batch_ops/plan.md`).
- [x] Redactar lista de tareas atómicas (`specs/backup_batch_ops/tasks.md`).

---

## Tareas de Implementación en Código de Producción
- [x] Implementar `backup_model_run_by_tag` en `lib/models/backup_model.sh`.
- [x] Implementar `backup_model_run_all` en `lib/models/backup_model.sh`.
- [x] Refinar extracción y formato de espacio en disco en `lib/controllers/app_controller.sh`.

---

## Tareas de Pruebas y Verificación
- [x] Añadir pruebas unitarias para operaciones por lotes en `tests/test_backup_model.sh`.
- [x] Ejecutar la suite unitaria de `test_backup_model.sh` y validar 100% aprobado.
- [x] Ejecutar la suite completa de 8 pruebas unitarias y verificar cero regresiones (205 pruebas superadas).
- [x] Ejecutar el escáner SAST obligatorio (`user_data/security_check/scripts/security_check.sh --all`).
- [x] Validar en vivo en el SSD con el sandbox:
  - [x] Probar `--backup-tag standard`.
  - [x] Probar `--backup-all` con `--no-purge`.
  - [x] Probar `--check-device` y certificar espacio en disco visible.

---

## Tareas de Gobernanza Git y Cierre
- [ ] Presentar informe de verificación al usuario y solicitar confirmación ("Procede con el commit").
- [ ] Realizar commit atómico bajo Conventional Commits (`feat(backup): implementar operaciones de respaldo por lotes y etiquetas`).
- [ ] Integrar rama en `develop` mediante merge no rápido (`--no-ff`).
