# Plan Técnico: Arquitectura Universal TUI, Asistente de Edición de Módulos, Pre-Flight Safety Gate y Personalización Visual

> **Rama:** `dev/feature/tui-ux-module-edit-and-safety`  
> **Ámbito:** `view`, `controller`, `model`, `tui`, `cli`, `security`  
> **Estado:** Borrador inicial para revisión y aprobación humana  

---

## 1. Arquitectura Técnica y Patrón MVC

La implementación se estructura respetando rigurosamente el patrón MVC desacoplado:

```text
               ┌────────────────────────────────────────────────────────┐
               │              Entrypoint: backup_manager.sh             │
               │         (--as-module, --yes, --theme, --test-mode)     │
               └───────────────────────────┬────────────────────────────┘
                                           │
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │        Controlador: lib/controllers/app_controller.sh   │
               │   • controller_handle_edit_module                      │
               │   • controller_handle_enable_template (colisiones)     │
               │   • controller_preflight_gate (TUI/CLI)                │
               │   • _sandbox_seed_modules                              │
               │   • Menús 1 a 7 (Arquitectura híbrida universal)       │
               └───────────────┬────────────────────────┬───────────────┘
                               │                        │
             ┌─────────────────┴────────┐      ┌────────┴─────────────────┐
             ▼                          ▼      ▼                          ▼
┌──────────────────────────┐ ┌────────────────────┐ ┌──────────────────────────┐
│  lib/models/module_model │ │ lib/models/profile │ │  lib/views/whiptail_view │
│  • activate_template_as  │ │ • can_delete       │ │  • apply_theme (NEWT)    │
│  • module_model_save     │ └────────────────────┘ │  • confirm_critical      │
└──────────────────────────┘                        │  • preflight_summary     │
                                                    └──────────────────────────┘
                                                               │
                                                    ┌──────────┴───────────────┐
                                                    ▼                          ▼
                                       ┌──────────────────────────┐ ┌─────────────────────┐
                                       │   lib/views/ansi_view    │ │  config/config.conf │
                                       │   • preflight_table      │ │  • TUI_THEME        │
                                       │   • confirm_critical     │ └─────────────────────┘
                                       └──────────────────────────┘
```

---

## 2. Modificaciones en Modelos (`lib/models/`)

### 2.1. `lib/models/module_model.sh`
- **`module_model_activate_template_as <template_id> <target_dir> <new_id> <new_name> [templates_dir]`:**
  - Lee la plantilla `<template_id>.conf`.
  - Reemplaza `MODULE_ID="<new_id>"` y `MODULE_NAME="<new_name>"`.
  - Persiste el archivo `<target_dir>/<new_id>.conf` validando sintaxis.
- **`module_model_update_field <module_id> <field_name> <field_val> <modules_dir>`:**
  - Modificador auxiliar para campos individuales si es necesario.

### 2.2. `lib/models/profile_model.sh`
- **`profile_model_can_delete <profile_id> <active_profile>`:**
  - Retorna error numérico si `profile_id == "default"` o `profile_id == active_profile`.

---

## 3. Modificaciones en Vistas (`lib/views/`)

### 3.1. `lib/views/whiptail_view.sh`
- **`whiptail_view_apply_theme <theme_id>`:**
  - Configura y exporta `NEWT_COLORS` según el catálogo:
    - `midnight`: `root=white,blue;window=white,blue;border=cyan,blue;title=brightcyan,blue;button=black,cyan;actbutton=white,red;checkbox=brightgreen,blue;actcheckbox=black,brightgreen;entry=white,black;label=white,blue;listbox=white,blue;actlistbox=black,cyan;textbox=white,blue;acttextbox=black,cyan;helpline=yellow,blue;roottext=brightcyan,blue`
    - `cyberdark`: `root=white,black;window=white,black;border=brightgreen,black;title=brightcyan,black;button=black,lightgray;actbutton=black,brightgreen;checkbox=brightgreen,black;actcheckbox=black,brightgreen;entry=white,gray;label=white,black;listbox=white,black;actlistbox=black,brightgreen;textbox=white,black;acttextbox=white,gray;helpline=brightcyan,black;roottext=brightgreen,black`
    - `aubergine`: `root=white,magenta;window=white,magenta;border=yellow,magenta;title=yellow,magenta;button=black,yellow;actbutton=white,red;checkbox=yellow,magenta;actcheckbox=black,yellow;entry=white,black;label=white,magenta;listbox=white,magenta;actlistbox=black,yellow;textbox=white,magenta;acttextbox=white,black;helpline=yellow,magenta;roottext=yellow,magenta`
    - `amber`: `root=brown,black;window=brown,black;border=yellow,black;title=brightyellow,black;button=black,brown;actbutton=black,yellow;checkbox=yellow,black;actcheckbox=black,yellow;entry=yellow,black;label=brown,black;listbox=brown,black;actlistbox=black,yellow;textbox=brown,black;acttextbox=yellow,black;helpline=yellow,black;roottext=yellow,black`
    - `default`: desactiva `NEWT_COLORS` dejando la paleta del sistema.
- **`whiptail_view_confirm_critical <title> <message>`:**
  - Cuadro de confirmación especial con `--defaultno` enfocado obligatoriamente en **[NO]**.
- **`whiptail_view_preflight_summary <title> <summary_table> <has_purge>`:**
  - Presenta el desglose con tabla de módulos, resaltando visualmente si hay purga activa.

### 3.2. `lib/views/ansi_view.sh`
- **`ansi_view_preflight_table <matrix_lines>`:**
  - Imprime tabla en terminal con encabezados ANSI y filas resaltadas en rojo brillante `\033[41;97;1m` si `PURGE=true`.
- **`ansi_view_confirm_critical <prompt>`:**
  - Solicita confirmación textual exigiendo teclear `SI` (en mayúsculas) para proseguir.

---

## 4. Modificaciones en el Controlador (`lib/controllers/app_controller.sh`)

### 4.1. Sembrado de Módulos en Sandbox Mode
- En `controller_enable_sandbox_mode`:
  ```bash
  _sandbox_seed_modules() {
      local sandbox_mods="$1"
      local base_mods="$2"
      if [[ ! -f "$sandbox_mods/bash-env.conf" ]]; then
          cp "$base_mods"/*.conf "$sandbox_mods/" 2>/dev/null || true
      fi
  }
  ```

### 4.2. Asistente de Edición de Módulos (`controller_handle_edit_module`)
- Permite seleccionar un módulo activo.
- Pregunta sobre *Override* si es global en perfil específico.
- Carga valores previos y guía la edición interactiva (nombre, rutas con `whiptail_view_input_paths`, tags con checklist, sensible y purga).
- Guarda atómicamente.

### 4.3. Resolución de Colisiones en Plantillas (`controller_handle_enable_template`)
- Si `module_model_activate_template` detecta colisión:
  - En TUI: Diálogo con 3 opciones (Clonar con nuevo nombre, Sobrescribir, Cancelar).
  - En CLI: Admite flag `--as-module <id>` o `--force`.

### 4.4. Interceptor Pre-Flight Safety Gate
- Función `_controller_run_preflight_gate <operation_type> <modules_list> <is_tui> <purge_override>`:
  - Analiza cada módulo (`IS_SENSITIVE`, `PURGE_AFTER_BACKUP`, ámbito, destino).
  - Si el usuario cancela -> retorna 0 y detiene la ejecución inmediatamente.

### 4.5. Homogeneización de los 7 Menús TUI
- Reestructurar el bucle `controller_run_tui`:
  - Menú 1: Principal híbrido.
  - Submenú 2: Opciones de respaldo.
  - Submenú 3: Centro de recuperación.
  - Submenú 4: Gestión de perfiles.
  - Submenú 5: Administración de módulos.
  - Submenú 6: Destinos de almacenamiento.
  - Submenú 7: Preferencias y temas visuales.
- Cada menú con su cabecera de telemetría dinámica, badges e iconografía uniforme.

---

## 5. Walkthrough y Plan de Pruebas

1. **Test Unitario Sandbox:** Verificar que `_sandbox_seed_modules` popule `user_data/sandbox/modules.d/` y que backup individual liste módulos en modo test.
2. **Test Unitario Edición:** Crear módulo de prueba, modificar rutas y flags mediante `controller_handle_edit_module` en modo no interactivo o modelo, y certificar cambios en el fichero `.conf`.
3. **Test Unitario Clonación de Plantillas:** Activar plantilla con `--as-module custom-bash` y validar creación correcta.
4. **Test Unitario Pre-Flight Gate:** Simular cancelación en pre-flight y comprobar salida limpia con código 0.
5. **Test Unitario Temas:** Verificar que `whiptail_view_apply_theme` configure `NEWT_COLORS` con cadenas sintácticamente válidas para cada paleta.
