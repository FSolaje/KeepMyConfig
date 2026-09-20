# Plan Técnico y Arquitectónico: lib/controllers/app_controller.sh y backup_manager.sh

**Componentes:** `lib/controllers/app_controller.sh` y `backup_manager.sh`  
**Rama:** `dev/feature/app-controller`  
**Referencia Arquitectónica:** Patrón MVC Estricto en Bash  

---

## 1. Arquitectura y Flujo de Ejecución

```text
                                  [backup_manager.sh]
                                           │
                        ┌──────────────────┴──────────────────┐
                 (Sin argumentos)                      (Con argumentos)
                        │                                     │
                        ▼                                     ▼
             [controller_run_tui]                    [controller_run_cli]
                        │                                     │
                        ▼                                     ▼
              whiptail_view_main_menu                ansi_view_header / info
                        │                                     │
                        └───────────────┬─────────────────────┘
                                        ▼
                            [lib/models/ Orchestration]
                                  device_model.sh
                                  module_model.sh
                                  crypto_model.sh
                                  backup_model.sh
                                  restore_model.sh
```

---

## 2. Definición de Funciones de `lib/controllers/app_controller.sh`

### 2.1 Inicialización
- `controller_init(base_dir)`: Carga `config.conf`, modelos y vistas. Valida `.backup_app_marker`.

### 2.2 Controladores de Casos de Uso
- `controller_handle_backup_all(is_tui, purge_override)`:
  - Valida dispositivo.
  - Detecta módulos sensibles; si hay, solicita clave.
  - Ejecuta respaldo. Si `PURGE_AFTER_BACKUP=false` en módulo sensible, ofrece purga interactiva.
- `controller_handle_backup_tag(tag, is_tui, purge_override)`:
  - Valida dispositivo.
  - Respalda por etiqueta.
- `controller_handle_backup_module(module_id, is_tui, purge_override)`:
  - Valida dispositivo.
  - Respalda módulo individual.
- `controller_handle_restore_sensitive(is_tui)`:
  - Pide clave una sola vez.
  - Ejecuta restauración express.
- `controller_handle_restore_module(module_id, timestamp, is_tui)`:
  - Valida archivo y clave si procede.
  - Ejecuta restauración.
- `controller_handle_restore_all(is_tui)`:
  - Restaura todos los módulos.
- `controller_handle_device_check(is_tui)`:
  - Diagnostica disco externo y estado del marcador.
- `controller_handle_modules_admin(is_tui)`:
  - Submenú TUI para gestión de módulos (crear, listar, borrar, añadir tags).

### 2.3 Bucles Principales
- `controller_run_tui()`: Bucle interactivo con `whiptail`.
- `controller_run_cli("$@")`: Parser de opciones de línea de comandos `getopts` / flags largos.

---

## 3. Estructura de `backup_manager.sh`

- Shebang `#!/usr/bin/env bash` con `set -euo pipefail`.
- Resolución de `BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`.
- Carga de `app_controller.sh`.
- Detección de modo (TUI si no hay argumentos y terminal interactiva; CLI si hay flags).

---

## 4. Estrategia de Pruebas Unitarias (`tests/test_controller.sh`)

1. **Pruebas de CLI Headless:**
   - Invocación de `--help` retorna 0 y muestra opciones.
   - Invocación de `--list-modules` retorna 0 y muestra los módulos configurados.
   - Invocación de `--list-tags` retorna 0 y lista etiquetas.
   - Invocación con argumentos desconocidos retorna error (código > 0).
2. **Pruebas de Flujos de Backup y Restore en Sandbox:**
   - Ejecución de `controller_handle_backup_module` en sandbox temporal.
   - Verificación de creación de archivo y reporte.
   - Ejecución de `controller_handle_restore_module` y verificación de restitución de archivos.
