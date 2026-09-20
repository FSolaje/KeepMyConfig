# Plan Técnico y Arquitectónico: lib/views/whiptail_view.sh y ansi_view.sh

**Componente:** `lib/views/whiptail_view.sh` y `lib/views/ansi_view.sh`  
**Rama:** `dev/feature/whiptail-views`  
**Referencia de Diseño:** MVC Desacoplado / Sin Lógica de Negocio  

---

## 1. Arquitectura de Módulos de Vista

```text
BackupConfig/lib/views/
├── whiptail_view.sh    # Interfaz TUI con diálogos interactivos whiptail
└── ansi_view.sh        # Interfaz CLI con formato enriquecido ANSI y prompts
```

### 1.1 Responsabilidades de Cada Archivo

- **`whiptail_view.sh`:**
  - Encapsula todas las llamadas a la utilidad `whiptail`.
  - Maneja la captura de entrada (`stderr` -> variable mediante `3>&1 1>&2 2>&3`).
  - Gestiona el redimensionamiento dinámico (`WT_HEIGHT`, `WT_WIDTH`, `WT_LIST_HEIGHT`).
  - Limpia el output de `--checklist` (elimina comillas escapadas).
- **`ansi_view.sh`:**
  - Proporciona utilidades para la CLI desatendida y modo consola directa.
  - Formatea encabezados, tablas y mensajes estructurados.
  - Implementa entrada por teclado interactiva (`read -r` y `read -s -r`).

---

## 2. Definición de Funciones y Firmas

### 2.1 `lib/views/whiptail_view.sh`

```bash
# Variables y códigos de salida
readonly VIEW_OK=0
readonly VIEW_CANCEL=1
readonly VIEW_ESC=255
readonly VIEW_ERR_DEPENDENCY=10
readonly VIEW_ERR_PARAM=11

# Verificación de dependencia
whiptail_view_check_deps() -> 0 | 10

# Dimensionado adaptativo
whiptail_view_calc_dimensions() -> define WT_HEIGHT, WT_WIDTH, WT_LIST_HEIGHT

# Diálogos informativos
whiptail_view_msgbox(title, text) -> VIEW_OK | VIEW_CANCEL
whiptail_view_error(title, text) -> VIEW_OK | VIEW_CANCEL
whiptail_view_yesno(title, text) -> VIEW_OK(0: Sí) | VIEW_CANCEL(1: No)

# Captura de datos
whiptail_view_input(title, prompt, [default_val]) -> echo "$input" && VIEW_OK | VIEW_CANCEL
whiptail_view_password(title, prompt) -> echo "$password" && VIEW_OK | VIEW_CANCEL
whiptail_view_password_confirm(title, prompt) -> echo "$password" && VIEW_OK | VIEW_CANCEL

# Menús y Listas
whiptail_view_main_menu() -> echo "$choice" && VIEW_OK | VIEW_CANCEL
whiptail_view_menu(title, prompt, tag1, item1, [tag2, item2, ...]) -> echo "$tag" && VIEW_OK | VIEW_CANCEL
whiptail_view_checklist(title, prompt, tag1, item1, status1, [...]) -> echo "$tags" && VIEW_OK | VIEW_CANCEL
whiptail_view_radiolist(title, prompt, tag1, item1, status1, [...]) -> echo "$tag" && VIEW_OK | VIEW_CANCEL

# Archivos y Progreso
whiptail_view_textbox(title, filepath) -> VIEW_OK | VIEW_CANCEL
whiptail_view_gauge(title, prompt, initial_percent) -> lee enteros por stdin
```

### 2.2 `lib/views/ansi_view.sh`

```bash
# Detección de soporte de color
ansi_view_colors_enabled() -> 0 | 1

# Banners y salidas
ansi_view_header(title) -> stdout banner
ansi_view_info(msg) -> stdout [INFO] msg
ansi_view_success(msg) -> stdout [OK] msg
ansi_view_warning(msg) -> stdout [AVISO] msg
ansi_view_error(msg) -> stderr [ERROR] msg

# Entradas CLI
ansi_view_prompt(question, default_value) -> echo "$answer"
ansi_view_password(prompt) -> echo "$secret"
ansi_view_confirm(question, default_yn) -> 0 (Sí) | 1 (No)
```

---

## 3. Estrategia de Pruebas Unitarias (`tests/test_views.sh`)

Dado que las pruebas deben ejecutarse en entornos automatizados (CI/CD o ejecución desatendida sin TTY interactiva abierta):
1. **Mocking Controlado de `whiptail`:**
   - Se creará un envoltorio o mock temporal de `whiptail` en el entorno de pruebas para verificar que se le pasan las banderas correctas (`--menu`, `--checklist`, `--passwordbox`, etc.), las dimensiones apropiadas y que se parsea adecuadamente el código de salida y `stderr`.
2. **Pruebas de Funciones Puras:**
   - Detección de dimensiones y cálculo con fallbacks.
   - Limpieza de comillas en checklist.
   - Códigos de retorno de `whiptail_view_yesno` (0 con mock de éxito, 1 con mock de cancelación).
3. **Pruebas de Formato ANSI:**
   - Comprobación de que `ansi_view_info`, `ansi_view_success`, `ansi_view_error` emiten las etiquetas y códigos de color esperados.
   - Comprobación de que `ansi_view_confirm` interpreta correctamente respuestas afirmativas (`s`, `S`, `y`, `Y`, ENTER con default) y negativas (`n`, `N`).
