# Lista Atómica de Tareas: Modo Sandbox / Test Mode (--test-mode)

**Sub-Hito:** Herramientas de Desarrollo y Calidad (Hito 12 / Sub-Hito 12.5)  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## Tareas

### Fase 1: Especificación y Diseño (SDD)
- [x] Redactar `specs/sandbox_test_mode/spec.md`.
- [x] Redactar `specs/sandbox_test_mode/plan.md`.
- [x] Redactar `specs/sandbox_test_mode/tasks.md`.
- [x] Aprobación humana de la especificación técnica.

---

### Fase 2: Implementación en el Controlador (`app_controller.sh`)
- [x] Implementar `controller_enable_sandbox_mode` (creación de `user_data/sandbox`, copia inicial de config, marcador y redirección de rutas).
- [x] Implementar `controller_clean_sandbox` (eliminación segura de `user_data/sandbox/`).
- [x] Adaptar `controller_run_tui` y funciones de vista para mostrar indicador visual `[SANDBOX]` en menús.
- [x] Adaptar avisos en modo CLI cuando `IS_SANDBOX_MODE="true"`.

---

### Fase 3: Integración en el Entrypoint (`backup_manager.sh`)
- [x] Parsear flags tempranos `--test-mode`, `--sandbox` y variable `KEEP_MY_CONFIG_TEST_MODE`.
- [x] Parsear flag `--clean-sandbox` e invocar `controller_clean_sandbox`.
- [x] Filtrar flags de sandbox de la lista de argumentos para permitir su combinación con cualquier subcomando (ej: `./backup_manager.sh --test-mode --backup-all`).
- [x] Documentar nuevas banderas en la ayuda CLI (`--help`).

---

### Fase 4: Suites de Pruebas Automatizadas (`tests/test_sandbox_mode.sh`)
- [x] Crear suite `tests/test_sandbox_mode.sh` con tests de inicialización, aislamiento, persistencia en sandbox y limpieza.
- [x] Verificar que `git status --porcelain` se mantiene completamente limpio tras ejecutar operaciones en sandbox.
- [x] Integrar la suite en la ejecución general de pruebas.

---

### Fase 5: Documentación y Calidad
- [x] Actualizar `README.md` con la sección de herramientas de desarrollo (`--test-mode`, `--clean-sandbox`).
- [x] Actualizar `MANUAL_USUARIO.md` con el apartado de pruebas y desarrollo.
- [x] Actualizar `CHANGELOG.md` registrando la nueva funcionalidad.
- [x] Actualizar `PROXIMOS_PASOS.md`.

---

### Fase 6: Verificación y Commit
- [ ] Ejecutar suite completa de pruebas unitarias.
- [ ] Ejecutar escáner SAST obligatorio.
- [ ] Solicitar aprobación humana y realizar el commit:
  `feat(dev): incorporar modo sandbox y flag --test-mode para pruebas aisladas`.
