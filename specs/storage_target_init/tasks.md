# Lista de Tareas Atómicas: `storage-target-init` y Almacenamiento Universal (`LOCAL_PATH`)

**Módulo:** `lib/models/device_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/storage-target-init`  
**Fecha:** 2026-09-20  

---

## Tareas de Especificación y Planificación (SDD)
- [x] Redactar especificación de requerimientos (`specs/storage_target_init/spec.md`).
- [x] Redactar plan técnico de implementación (`specs/storage_target_init/plan.md`).
- [x] Redactar lista de tareas atómicas (`specs/storage_target_init/tasks.md`).

---

## Tareas de Implementación en Código de Producción
- [x] **Modelo de Almacenamiento (`lib/models/device_model.sh`):**
  - [x] Añadir resolución y validación de `LOCAL_PATH`.
  - [x] Implementar `device_model_init_target_directory`.
  - [x] Implementar `device_model_list_targets`.
  - [x] Implementar `device_model_update_config_subdir`.
- [x] **Configuración (`config/config.conf`):**
  - [x] Documentar directiva `LOCAL_PATH` y ejemplos de uso.
- [x] **Controlador y CLI (`lib/controllers/app_controller.sh`):**
  - [x] Añadir soporte para `--init-target <subdir>`.
  - [x] Añadir soporte para `--set-default`.
  - [x] Añadir soporte para `--target-subdir <subdir>` (modificador de sesión activa).
  - [x] Añadir soporte para `--list-targets`.
  - [x] Mejorar la Opción 8 de la TUI con submenú interactivo para gestión de destinos.

---

## Tareas de Pruebas y Verificación
- [x] Añadir pruebas unitarias en `tests/test_device_model.sh`.
- [x] Añadir pruebas de integración CLI en `tests/test_controller.sh`.
- [x] Ejecutar la suite unitaria completa (todas las pruebas deben pasar sin fallos).
- [x] Actualizar `MANUAL_USUARIO.md` con las nuevas capacidades.
- [x] Ejecutar el escáner SAST obligatorio (`user_data/security_check/scripts/security_check.sh --all`).
- [x] Realizar prueba en vivo en el SSD (`DISCO_BACKUP`).

---

## Tareas de Gobernanza Git y Cierre
- [ ] Presentar informe de verificación al usuario y solicitar confirmación ("Procede con el commit").
- [ ] Realizar commit atómico bajo Conventional Commits (`feat(storage): implementar storage-target-init y soporte LOCAL_PATH`).
- [ ] Integrar rama en `develop` mediante merge no rápido (`--no-ff`).
