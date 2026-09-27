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
- **`module_model_is_enabled <file_path>`:**
  - Evalúa `MODULE_ENABLED` en subshell aislada; retorna 0 si es `true` (o ausente), 1 si es `false`.
- **`module_model_set_enabled <file_path> <true|false>`:**
  - Actualiza o inserta de forma atómica la directiva `MODULE_ENABLED="true/false"` en el archivo `.conf`.
- **`module_model_update_field <module_id> <field_name> <field_val> <modules_dir>`:**
  - Modificador auxiliar para campos individuales si es necesario.

### 2.2. `lib/models/profile_model.sh`
- **`profile_model_can_delete <profile_id> <active_profile>`:**
  - Retorna error numérico si `profile_id == "default"` o `profile_id == active_profile`.
- **Desbloqueo de exclusiones en perfil `default`:**
  - Levantar la guarda `if [[ "$profile_id" == "default" ]]; then return ...` en `profile_model_disable_module` y `profile_model_enable_module`.
  - En `profile_model_list_modules`, consultar `DISABLED_MODULES` también cuando `active_profile == "default"`.

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

### 4.2. Asistente de Creación y Edición de Módulos (`controller_handle_create_module` / `controller_handle_edit_module`)
- Permite seleccionar un módulo activo (o crear uno nuevo).
- Pregunta sobre *Override* si se edita un módulo global desde un perfil específico.
- **Sincronización inteligente de etiqueta `sensitive`:**
  - Si en el checklist de tags se marca `sensitive`: `IS_SENSITIVE="true"` directo sin preguntar.
  - Si NO se marca `sensitive`: no se pregunta si son datos sensibles, pero se ofrece directamente la opción de cifrado GPG (`IS_SENSITIVE=true/false`). Si acepta, se añade el tag `sensitive` a la receta; si no, queda sin cifrar (`IS_SENSITIVE="false"`).
- **Consentimiento activo y oferta universal para purga (`shred -u`):**
  - La opción de purga se consulta siempre para cualquier módulo, **tanto si es sensible/cifrado como si no lo es**.
  - Toda consulta sobre purga debe realizarse mediante `whiptail_view_confirm_critical` (o diálogo con `--defaultno`), requiriendo que el usuario se desplace activamente a `[SÍ]` para activarla.
- Permite conmutar la flag `MODULE_ENABLED="true/false"`.
- Carga valores previos y guía la edición interactiva (nombre, rutas con `whiptail_view_input_paths`, tags con checklist, sensible, purga y estado).
- Guarda atómicamente.

### 4.3. Activación Guiada de Plantillas y Resolución de Colisiones (`controller_handle_enable_template`)
- **Ficha Técnica de Previsualización:** Antes de activar, muestra un diálogo resumen con ID, Nombre, Descripción, Rutas a respaldar, Etiquetas, Cifrado y Purga, solicitando confirmación interactiva.
- **Consentimiento activo ante plantillas con purga de fábrica:** Si la plantilla define `PURGE_AFTER_BACKUP="true"` (ej. `ssh-keys`), se interroga al usuario con foco en `[NO]` si desea mantener la destrucción de archivos; si responde No, se activa con `PURGE_AFTER_BACKUP="false"`.
- **Selector Universal de Ámbito:** Ofrece siempre elegir si se activa en el *Catálogo Global* (`modules.d/`) o *Exclusivo del Perfil Activo* (`profiles/<perfil>/modules.d/`, tanto para `default` como para cualquier otro perfil).
- **Gestión de Colisiones:** Si `module_model_activate_template` detecta que ya existe:
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
