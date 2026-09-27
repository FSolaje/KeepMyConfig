# Especificación de Requerimientos: Home Virtual en Sandbox, Feedback Detallado y Mejoras UX en TUI

**Sub-Hito:** Mejoras de Calidad, Seguridad de Testing y UX en TUI (Hito 12 / Sub-Hito 12.4.1)  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-27  

---

## 1. Contexto y Justificación

Tras la consolidación del Modo Sandbox (`--test-mode` / `--clean-sandbox`), se han identificado necesidades críticas operativas y de usabilidad durante las pruebas en entorno interactivo:
1. **Riesgo en Pruebas de Purga Sensible (`shred -u`):** Si `TARGET_USER_HOME` apunta a `/home/$USER`, la prueba de purga de módulos sensibles (ej. `ssh-keys`) pondría en riesgo archivos reales del usuario en su equipo. Es indispensable un Home Virtual en Sandbox con datos de prueba precargados.
2. **Robustez ante Cancelaciones en TUI:** Al pulsar *Cancelar* en la selección individual de módulos o etiquetas en la TUI, el gestor finalizaba abruptamente con código de salida 1 debido a `set -e` al interpretar la cancelación del usuario como error no capturado.
3. **Claridad en el Tratamiento de Rutas:** En los asistentes de creación de recetas, el usuario no dispone de una explicación explícita sobre cómo se normalizan las rutas (relativas a `$HOME` vs absolutas con variables de entorno).
4. **Entrada Ergonómica de Rutas Múltiples:** La introducción de rutas separadas por espacios es propensa a errores y no admite rutas con espacios. Se requiere un flujo interactivo donde cada retorno de carro (Enter) confirme una ruta individual hasta finalizar.
5. **Transparencia y Feedback con Rutas Completas:** En todas las operaciones de copia, borrado seguro (`shred`) y restauración en la interfaz TUI, se debe informar con las rutas absolutas completas de origen y destino.

---

## 2. Requerimientos Funcionales

### FR-UX-001: Corrección de Cancelación Voluntaria en Menús TUI
- Cuando el usuario pulse *Cancelar* (o `ESC`) en cualquier diálogo de selección interactiva (módulos, etiquetas, contraseñas o submenús), el controlador debe atrapar el código `VIEW_CANCEL` (1) y retornar de forma segura al menú principal (`return 0`), evitando que `set -e` aborte el script.

### FR-UX-002: Home Virtual de Pruebas en Sandbox (`user_data/sandbox/home/`)
- En modo sandbox (`--test-mode` / `--sandbox` / `KEEP_MY_CONFIG_TEST_MODE=true`), el controlador debe fijar:
  ```bash
  TARGET_USER_HOME="${sandbox_base}/home"
  export TARGET_USER_HOME
  ```
- Si `user_data/sandbox/home/` no existe, se inicializa automáticamente desplegando datos de prueba (*mock fixtures*) para todas las plantillas estándar:
  - `bash-env`: `.bashrc`, `.bash_aliases`, `.config/bash/env.sh`
  - `ssh-keys`: `.ssh/id_rsa`, `.ssh/id_rsa.pub`, `.ssh/config`
  - `vscode-standard`: `.config/Code/User/settings.json`, `.config/Code/User/keybindings.json`
  - `vscode-sensitive`: `.config/Code/User/auth.dat`, `.config/Code/User/tokens.json`
  - `git-config`: `.gitconfig`
  - `firefox`: `.mozilla/firefox/testprofile/prefs.js`
  - `intellij`: `.config/JetBrains/IdeaIC/idea.properties`
  - `thunderbird`: `.thunderbird/testprofile/prefs.js`
  - `libreoffice`: `.config/libreoffice/4/user/registrymodifications.xcu`
- Los datos base se mantendrán respaldados en una estructura canónica de semillas (`tests/fixtures/sandbox_home/` o inicializador reproducible) para que ante un `--clean-sandbox` seguido de `--test-mode` se regeneren íntegros en su estado inicial.

### FR-UX-003: Captura Interactiva de Rutas Línea a Línea (Confirmación con Enter)
- Sustituir la petición de rutas separadas por espacios por una función interactiva en la vista (`whiptail_view_input_paths`):
  1. Presenta un cuadro de entrada para una sola ruta.
  2. Cada pulsación de Enter confirma y añade la ruta a una lista acumulada.
  3. La ventana se refresca mostrando la lista numerada de rutas ya añadidas.
  4. Si el usuario pulsa Enter con el campo en blanco o pulsa Cancelar habiendo al menos una ruta, finaliza la recogida.
  5. Si el usuario cancela sin haber introducido ninguna ruta, se cancela la operación de forma limpia.

### FR-UX-004: Orientación Explícita sobre Normalización de Rutas
- En todos los diálogos de petición de rutas (asistente de módulos y plantillas), incluir un texto orientativo claro:
  - Indicar que las rutas se procesan relativas al directorio personal (`$HOME`).
  - Indicar que se admiten rutas relativas (ej. `.config/app`) o rutas completas con variables de entorno (ej. `$HOME/.config/app`, `~/.config/app` o `/home/usuario/.config/app`).
  - Aclarar que el sistema las normaliza automáticamente para asegurar su portabilidad entre diferentes equipos.

### FR-UX-005: Feedback Detallado con Rutas Absolutas Completas en TUI
- Tras completar un backup, restauración o purga segura en modo TUI:
  - Mostrar en un diálogo descriptivo (`msgbox` o `textbox`) las rutas absolutas completas:
    - Ficheros de origen leídos/empaquetados.
    - Fichero de archivo destino generado (`.tar.zst` o `.gpg`).
    - Ficheros locales purgados con `shred -u -z -n 3` (si aplica).
    - Ficheros restituidos en el destino (en restauraciones).

---

## 3. Requerimientos No Funcionales

- **NFR-SEC-001 (Protección de Datos Reales):** En modo sandbox queda estrictamente prohibido realizar cualquier lectura, copia o borrado sobre `/home/$USER/`. Todas las operaciones deben ocurrir dentro de `user_data/sandbox/home/`.
- **NFR-ROB-001 (Tolerancia a Cancelación):** La interfaz TUI no debe terminar abruptamente ante ninguna cancelación de diálogo por parte del usuario.
