# Lista de Tareas Atómicas: app_controller y backup_manager

**Rama:** `dev/feature/app-controller`  
**Componentes:** `lib/controllers/app_controller.sh` y `backup_manager.sh`  

---

## Tareas Secuenciales de Implementación:

- [x] **Fase 1: Especificación y Diseño (SDD)**
  - [x] Redacción de `specs/app_controller/spec.md`.
  - [x] Redacción de `specs/app_controller/plan.md`.
  - [x] Redacción de `specs/app_controller/tasks.md`.
  - [x] Aprobación de la especificación técnica por parte del usuario.

- [x] **Fase 2: Implementación del Orquestador y Punto de Entrada**
  - [x] Implementación de `lib/controllers/app_controller.sh` (inicialización, orquestación de backups, restores, administración de módulos y bucle TUI).
  - [x] Implementación de `backup_manager.sh` (entrypoint con router CLI y TUI).

- [x] **Fase 3: Suite de Pruebas Unitarias y Auditoría SAST**
  - [x] Creación de `tests/test_controller.sh`.
  - [x] Ejecución y validación del 100% de pruebas unitarias aprobadas.
  - [x] Ejecución del escáner SAST obligatorio (`bash user_data/security_check/scripts/security_check.sh`).
  - [x] Presentación del reporte de seguridad y solicitud de aprobación de commit.
