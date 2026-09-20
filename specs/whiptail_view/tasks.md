# Lista de Tareas Atómicas: whiptail_view y ansi_view

**Rama:** `dev/feature/whiptail-views`  
**Componentes:** `lib/views/whiptail_view.sh` y `lib/views/ansi_view.sh`  

---

## Tareas Secuenciales de Implementación:

- [x] **Fase 1: Especificación y Diseño (SDD)**
  - [x] Redacción de `specs/whiptail_view/spec.md`.
  - [x] Redacción de `specs/whiptail_view/plan.md`.
  - [x] Redacción de `specs/whiptail_view/tasks.md`.
  - [x] Aprobación de la especificación técnica por parte del usuario.

- [x] **Fase 2: Implementación de la Capa de Vista**
  - [x] Implementación de `lib/views/ansi_view.sh` (colores, banners, prompts y confirmaciones).
  - [x] Implementación de `lib/views/whiptail_view.sh` (cálculo de dimensiones, menú principal, msgbox, yesno, passwordbox, checklist, textbox y gauge).

- [x] **Fase 3: Suite de Pruebas Unitarias y Auditoría SAST**
  - [x] Creación de `tests/test_views.sh`.
  - [x] Ejecución y validación del 100% de pruebas unitarias aprobadas.
  - [x] Ejecución del escáner SAST obligatorio (`bash user_data/security_check/scripts/security_check.sh`).
  - [x] Presentación del reporte de seguridad y solicitud de aprobación de commit.
