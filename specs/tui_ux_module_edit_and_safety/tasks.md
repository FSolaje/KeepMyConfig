# Desglose Atómico de Tareas: Sub-Hito 12.4.2

> **Rama:** `dev/feature/tui-ux-module-edit-and-safety`  
> **Metodología:** SDD estricto con commits atómicos por fase verificada  

---

## Fase 0: Especificación y Línea Base Arquitectónica
- [x] Crear especificación funcional detallada (`specs/tui_ux_module_edit_and_safety/spec.md`).
- [x] Crear plan técnico y arquitectura MVC (`specs/tui_ux_module_edit_and_safety/plan.md`).
- [x] Crear desglose atómico de tareas secuenciales (`specs/tui_ux_module_edit_and_safety/tasks.md`).
- [ ] **Hito de Commit 0 (docs):**
  ```bash
  docs(spec): definir arquitectura universal TUI, edicion de modulos, safety gate y temas
  ```

---

## Fase 1: Sembrado de Módulos en Sandbox Mode y Guardas Defensivas (Bugfix)
- [ ] Implementar función auxiliar `_sandbox_seed_modules` en `lib/controllers/app_controller.sh`.
- [ ] Invocar el sembrado en `controller_enable_sandbox_mode` para copiar `${base_dir}/modules.d/*.conf` a `${sandbox_base}/modules.d/`.
- [ ] Añadir guardas en `controller_handle_backup_module` y `controller_handle_restore_module` para avisar amigablemente si la lista de módulos está vacía en lugar de abrir un selector vacío.
- [ ] Verificar manualmente en `--test-mode` que el listado de módulos muestra las recetas.
- [ ] **Hito de Commit 1 (fix):**
  ```bash
  fix(sandbox): sembrar recetas base en user_data/sandbox/modules.d y añadir guardas ante listas vacías
  ```

---

## Fase 2: Clarificación Contextual en Diálogos de Rutas (UX)
- [ ] Actualizar el mensaje de `whiptail_view_input` en `controller_handle_create_profile` explicando la ruta base `BACKUP_DESTINATION` y la convención Zero-Config.
- [ ] Actualizar el mensaje de entrada en `controller_handle_set_backup_dest` explicando el tratamiento de rutas relativas y absolutas.
- [ ] Actualizar el mensaje de inicialización en `device_model_init_target_directory` en `lib/models/device_model.sh`.
- [ ] Verificar visualmente la claridad de los textos en la TUI.
- [ ] **Hito de Commit 2 (feat):**
  ```bash
  feat(view): añadir contexto de destino base y reglas de ruta en asistentes TUI
  ```

---

## Fase 3: Asistente de Edición de Módulos en la TUI
- [ ] Implementar `controller_handle_edit_module` en `lib/controllers/app_controller.sh`.
- [ ] Añadir selector de módulo activo con indicación de ámbito `[Global]` o `[Perfil: <id>]`.
- [ ] Implementar bifurcación de *Override* si se edita un módulo global desde un perfil específico.
- [ ] Precargar y permitir editar: nombre descriptivo, rutas (con `whiptail_view_input_paths`), etiquetas (checklist), sensible (GPG) y purga (`shred -u`).
- [ ] Integrar la opción `2) ✏️ [MÓDULOS] Modificar un Módulo Existente` en el menú de módulos.
- [ ] Verificar edición interactiva y persistencia correcta en el archivo `.conf`.
- [ ] **Hito de Commit 3 (feat):**
  ```bash
  feat(modules): implementar asistente de edicion interactiva de modulos en TUI
  ```

---

## Fase 4: Resolución de Colisiones en Plantillas y Clonación de Recetas
- [ ] Implementar `module_model_activate_template_as` en `lib/models/module_model.sh` para admitir nuevo ID y nombre.
- [ ] Modificar `controller_handle_enable_template` para abrir menú de 3 opciones ante colisión (Clonar con nuevo nombre, Sobrescribir, Cancelar).
- [ ] Añadir soporte en CLI para `--as-module <nuevo_id>` y `--force`.
- [ ] Aplicar la misma resolución simétrica al exportar módulos a la biblioteca de plantillas.
- [ ] **Hito de Commit 4 (feat):**
  ```bash
  feat(templates): incorporar clonacion con nuevo identificador y resolucion interactiva de colisiones
  ```

---

## Fase 5: Pre-Flight Safety Gate y Matriz de Acciones Críticas
- [ ] Implementar función auxiliar `_controller_build_preflight_matrix` en `lib/controllers/app_controller.sh`.
- [ ] Implementar `whiptail_view_confirm_critical` (con `--defaultno`) y diálogo pre-flight en `lib/views/whiptail_view.sh`.
- [ ] Implementar `ansi_view_preflight_table` (con fondos rojos `\033[41;97;1m` para purga) en `lib/views/ansi_view.sh`.
- [ ] Interceptar las llamadas a `backup_all`, `backup_tag` y `backup_module` con el Pre-Flight Gate.
- [ ] Añadir advertencia previa de sobreescritura con listado de rutas en `controller_handle_restore_*`.
- [ ] Incorporar salvaguardas en eliminación de perfiles (bloqueo de `default` y perfil activo).
- [ ] **Hito de Commit 5 (feat):**
  ```bash
  feat(security): implementar pre-flight safety gate y salvaguardas para acciones destructivas
  ```

---

## Fase 6: Arquitectura Universal de Menús TUI y Paletas de Color
- [ ] Implementar `whiptail_view_apply_theme` en `lib/views/whiptail_view.sh` con el catálogo `NEWT_COLORS` (`midnight`, `cyberdark`, `aubergine`, `amber`, `default`).
- [ ] Cargar `TUI_THEME` desde `config/config.conf` e inicializar tema al arranque de la TUI.
- [ ] Reestructurar `controller_run_tui` aplicando el Menú Principal híbrido (Menú 1).
- [ ] Implementar los Submenús 2 (Opciones de Respaldo), 3 (Recuperación) y 7 (Ajustes y Temas).
- [ ] Homogeneizar los Submenús 4 (Perfiles), 5 (Módulos) y 6 (Almacenamiento) con badges alineados, iconografía Unicode y atajos numéricos homogéneos.
- [ ] **Hito de Commit 6 (feat):**
  ```bash
  feat(tui): aplicar arquitectura universal de menus con badges y paletas de color NEWT_COLORS
  ```

---

## Fase 7: Batería de Pruebas Unitarias Automatizadas
- [ ] Crear / ampliar pruebas en `tests/test_sandbox_mode.sh` para verificar sembrado de módulos.
- [ ] Ampliar `tests/test_module_model.sh` con pruebas de activación con nuevo nombre (`activate_template_as`).
- [ ] Ampliar `tests/test_controller.sh` con pruebas para el Pre-Flight Gate (cancelación limpia código 0, flags `--yes` y `--as-module`).
- [ ] Ampliar `tests/test_views.sh` con verificación sintáctica de temas `NEWT_COLORS`.
- [ ] Ejecutar la suite completa y certificar 100% de tests en verde.
- [ ] **Hito de Commit 7 (test):**
  ```bash
  test: incorporar baterias de pruebas para edicion de modulos, clonacion, safety gate y temas
  ```

---

## Fase 8: Sincronización Mandatoria de Documentación Pública
- [ ] Actualizar [`README.md`](../../README.md) reflejando el menú híbrido, temas visuales y asistente de edición.
- [ ] Actualizar [`MANUAL_USUARIO.md`](../../MANUAL_USUARIO.md) con los nuevos diagramas de flujo TUI, temas de color y pre-flight gate.
- [ ] Actualizar [`CHANGELOG.md`](../../CHANGELOG.md) bajo la sección `[Unreleased]`.
- [ ] Actualizar [`PROXIMOS_PASOS.md`](../../PROXIMOS_PASOS.md).
- [ ] Ejecutar escáner SAST obligatorio.
- [ ] **Hito de Commit 8 (docs - aislado):**
  ```bash
  docs: documentar menu universal, edicion de modulos, safety gate y temas TUI en manual y changelog
  ```
