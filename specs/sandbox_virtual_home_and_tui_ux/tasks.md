# Lista Atómica de Tareas: Home Virtual en Sandbox y Mejoras UX en TUI

**Sub-Hito:** Mejoras de Calidad, Seguridad de Testing y UX en TUI (Hito 12 / Sub-Hito 12.4.1)  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-27  

---

## Tareas

### Fase 1: Especificación y Diseño (SDD)
- [x] Redactar `specs/sandbox_virtual_home_and_tui_ux/spec.md`.
- [x] Redactar `specs/sandbox_virtual_home_and_tui_ux/plan.md`.
- [x] Redactar `specs/sandbox_virtual_home_and_tui_ux/tasks.md`.
- [x] Aprobación humana de la especificación técnica.

---

### Fase 2: Corrección del Bug de Cancelación en TUI
- [x] Manejar limpiamente `VIEW_CANCEL` en `controller_handle_backup_module` al cancelar la lista de módulos.
- [x] Manejar limpiamente `VIEW_CANCEL` en `controller_handle_backup_tag` al cancelar la lista de etiquetas.
- [x] Manejar limpiamente `VIEW_CANCEL` en `controller_handle_restore_module` al cancelar la lista de módulos.
- [x] Proteger el bucle principal de `controller_run_tui` para evitar que salidas canceladas provoquen abortos bajo `set -e`.

---

### Fase 3: Home Virtual de Pruebas y Semillas de Sandbox
- [x] Crear función `_sandbox_seed_virtual_home` para desplegar fixtures realistas en `user_data/sandbox/home/`.
- [x] Actualizar `controller_enable_sandbox_mode` para redirigir `TARGET_USER_HOME="${sandbox_base}/home"`.
- [x] Asegurar que `user_data/sandbox/config/config.conf` registre `TARGET_USER_HOME` confinado.
- [x] Verificar que `--clean-sandbox` elimine el home virtual y que se regenere intacto en la siguiente invocación.

---

### Fase 4: Captura Interactiva de Rutas Línea a Línea y Textos Explicativos
- [x] Implementar `whiptail_view_input_paths` en `lib/views/whiptail_view.sh` con confirmación por Enter y visualización de rutas acumuladas.
- [x] Añadir explicaciones detalladas en los cuadros de entrada indicando que las rutas son relativas a `$HOME` y admiten `$HOME` o `~`.
- [x] Integrar `whiptail_view_input_paths` en el asistente de creación de módulos de `app_controller.sh`.
- [x] Integrar `whiptail_view_input_paths` en el asistente de creación de plantillas de `app_controller.sh`.

---

### Fase 5: Feedback Detallado con Rutas Completas en Operaciones TUI
- [x] Detallar rutas absolutas completas de origen y destino en el cuadro de confirmación de backup exitoso.
- [x] Detallar rutas absolutas completas en el aviso de purga segura con `shred -u` antes y después de su ejecución.
- [x] Detallar rutas absolutas restituidas en el reporte de restauración exitosa.

---

### Fase 6: Pruebas Unitarias y Automatizadas
- [x] Crear tests unitarios en `tests/test_sandbox_mode.sh` para verificar que `TARGET_USER_HOME` apunta a `user_data/sandbox/home`.
- [x] Crear test de purga segura (`shred -u`) verificando que se destruye el fichero del sandbox sin tocar el fichero real de `/home/$USER`.
- [x] Crear test de cancelación en TUI verificando que no arroja error 1.
- [x] Ejecutar la suite completa de pruebas unitarias (10 baterías).

---

### Fase 7: Documentación y Commit
- [x] Actualizar `MANUAL_USUARIO.md` reflejando el nuevo flujo interactivo de entrada de rutas línea a línea y el home virtual.
- [x] Actualizar `README.md` y `CHANGELOG.md`.
- [x] Actualizar `PROXIMOS_PASOS.md`.
- [ ] Ejecutar escáner SAST obligatorio.
- [ ] Solicitar aprobación humana y realizar el commit:
  `feat(sandbox): incorporar home virtual con datos de prueba, entrada guiada de rutas y corrección de cancelación en TUI`.
