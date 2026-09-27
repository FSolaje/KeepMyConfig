# Plan Arquitectónico y Técnico: Home Virtual en Sandbox y Mejoras UX en TUI

**Sub-Hito:** Mejoras de Calidad, Seguridad de Testing y UX en TUI (Hito 12 / Sub-Hito 12.4.1)  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-27  

---

## 1. Arquitectura de Componentes

```text
KeepMyConfig/
├── fixtures/
│   └── sandbox_home/                <-- Semillas canónicas de prueba
│       ├── .bashrc
│       ├── .bash_aliases
│       ├── .ssh/id_rsa, id_rsa.pub, config
│       ├── .config/Code/User/settings.json, keybindings.json, auth.dat
│       └── .gitconfig
├── user_data/
│   └── sandbox/
│       ├── home/                    <-- TARGET_USER_HOME confinado en modo sandbox
│       ├── config/config.conf
│       ├── modules.d/
│       ├── profiles/
│       └── storage/
├── lib/
│   ├── views/whiptail_view.sh       <-- whiptail_view_input_paths (bucle interactivo por línea)
│   └── controllers/app_controller.sh<-- Manejo seguro de VIEW_CANCEL, despliegue de fixtures y reportes detallados
└── tests/
    └── test_sandbox_mode.sh         <-- Ampliación con tests de home virtual, shred seguro y cancelación
```

---

## 2. Modificaciones Técnicas Detalladas

### 2.1 Corrección de Cancelación en TUI (`lib/controllers/app_controller.sh`)
- En `controller_handle_backup_module`:
  ```bash
  module_id=$(whiptail_view_radiolist "Seleccionar Módulo" ... ) || {
      # Cancelación limpia por parte del usuario
      return 0
  }
  ```
- En `controller_handle_backup_tag`:
  ```bash
  tag=$(whiptail_view_radiolist "Seleccionar Etiqueta" ... ) || {
      return 0
  }
  ```
- En `controller_handle_restore_module`:
  ```bash
  module_id=$(whiptail_view_radiolist "Seleccionar Módulo" ... ) || {
      return 0
  }
  ```
- En `controller_run_tui`: Asegurar que cualquier retorno no crítico devuelva al bucle del menú principal en lugar de propagar códigos no cero a `set -e`.

### 2.2 Home Virtual de Sandbox y Semillas (`lib/controllers/app_controller.sh` y `fixtures/`)
- En `controller_enable_sandbox_mode()`:
  1. Definir `export TARGET_USER_HOME="${sandbox_base}/home"`.
  2. Crear función auxiliar `_sandbox_seed_virtual_home "$sandbox_base/home"`.
  3. Si `${sandbox_base}/home` no existe, invocar la inicialización para sembrar archivos de prueba con contenidos realistas no sensibles pero sintácticamente válidos.
  4. En `user_data/sandbox/config/config.conf`, fijar `TARGET_USER_HOME="${sandbox_base}/home"`.

### 2.3 Captura Interactiva de Rutas Línea a Línea (`lib/views/whiptail_view.sh`)
- Implementar `whiptail_view_input_paths(title, base_prompt)`:
  - Bucle `while true`:
    - Construye el mensaje mostrando:
      - Explicación de tratamiento: *"Las rutas se procesan respecto a \$HOME. Puede usar relativas (.config/app) o completas (\$HOME/.config/app)."*
      - Lista numerada de rutas acumuladas hasta el momento.
      - Indicación: *"Introduzca una ruta y pulse Aceptar/Enter para añadirla. Deje en blanco y pulse Aceptar para finalizar."*
    - Si el usuario introduce una ruta válida (no vacía), se añade al array `paths+=("$clean_path")`.
    - Si el campo está vacío y ya hay al menos una ruta en el array, se rompe el bucle con éxito y se retornan las rutas separadas por espacio o delimitador seguro.
    - Si el usuario pulsa Cancelar habiendo rutas, se pregunta si desea confirmar las rutas actuales o descartar.
    - Si cancela sin rutas, retorna `VIEW_CANCEL`.
- Integrar `whiptail_view_input_paths` en `controller_handle_modules_admin` tanto en la opción de crear nuevo módulo como en crear nueva plantilla.

### 2.4 Feedback Detallado con Rutas Completas en TUI
- Al finalizar `controller_handle_backup_module`, `controller_handle_backup_all`, `controller_handle_restore_*`:
  - Construir un reporte formateado que desglose:
    - **Origen:** `${TARGET_USER_HOME}/<ruta>` para cada archivo respaldado.
    - **Destino:** `${backup_dir}/archives/<archivo>`.
    - **Purga Local:** Listado explícito de cada ruta destruida con `shred -u` `${TARGET_USER_HOME}/<ruta>`.
  - Presentar este resumen en un diálogo `whiptail_view_msgbox` o `textbox` permitiendo al usuario revisar con exactitud las operaciones efectuadas.

---

## 3. Plan de Pruebas Unitarias

1. Test unitario de cancelación: comprobar que cancelar la selección de módulo individual no aborta el proceso y retorna código 0.
2. Test unitario de Home Virtual: comprobar que en modo sandbox `TARGET_USER_HOME` apunta a `user_data/sandbox/home`.
3. Test de existencia de datos de prueba: comprobar que `.bashrc`, `.ssh/id_rsa`, `.config/Code/User/settings.json` se crean en el home virtual.
4. Test de purga segura en Sandbox: comprobar que un backup con `--purge` en módulo sensible dentro del sandbox destruye el fichero `.ssh/id_rsa` del home virtual de pruebas sin tocar en ningún momento `~/.ssh/id_rsa` del usuario real.
5. Test de regeneración tras `--clean-sandbox`: comprobar que tras purgar el sandbox y volver a invocar `--test-mode`, el home virtual vuelve a estar intacto con sus datos iniciales.
