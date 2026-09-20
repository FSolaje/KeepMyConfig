# Especificación de Requerimientos: lib/views/whiptail_view.sh y ansi_view.sh

**Componente:** `lib/views/whiptail_view.sh` y `lib/views/ansi_view.sh`  
**Rama:** `dev/feature/whiptail-views`  
**Estado:** Propuesta / En Revisión  

---

## 1. Propósito y Filosofía de Diseño

El subsistema de vistas en la arquitectura MVC de **BackupConfig** es estrictamente declarativo y desacoplado:
1. **Cero Lógica de Negocio:** Las vistas no leen configuraciones del disco, no invocan `tar`, `gpg`, `shred` ni manipulan variables de estado de los modelos.
2. **Interfaz Dual:**
   - **TUI Interactiva (`whiptail_view.sh`):** Experiencia de usuario en terminal basada en cuadros de diálogo `whiptail` (Lliurex 25 / Ubuntu 24.04).
   - **CLI / Consola ANSI (`ansi_view.sh`):** Formateo enriquecido con colores ANSI y captura interactiva en terminal plano o modo desatendido (headless).
3. **Comunicación Estándar:**
   - Entradas: Parámetros posicionales (títulos, mensajes, arrays de opciones).
   - Salidas: Las elecciones o textos del usuario se emiten por `stdout`; el código de salida numérico indica la acción del usuario (`0` = Aceptar/OK, `1` = Cancelar/Atrás, `255` = Escape/Cierre).

---

## 2. Requerimientos Funcionales

### 2.1 Vista TUI (`lib/views/whiptail_view.sh`)

#### V_WHP_01: Detección de Dimensiones de Terminal
- Debe calcular dinámicamente el alto (`WT_HEIGHT`) y ancho (`WT_WIDTH`) disponibles usando `tput lines` y `tput cols`, estableciendo dimensiones seguras por defecto si la terminal es reducida (mínimo recomendado: `LINES=22`, `COLS=76`).

#### V_WHP_02: Menú Principal
- `whiptail_view_main_menu`:
  - Presenta las 8 opciones funcionales del sistema y la opción 0 para salir:
    - `1`: [BACKUP] Realizar Backup Completo
    - `2`: [BACKUP] Realizar Backup por Etiquetas (Tags)
    - `3`: [BACKUP] Realizar Backup por Módulo Individual
    - `4`: [RESTORE] Restauración Rápida de Datos Sensibles
    - `5`: [RESTORE] Restauración Selectiva (Módulo / Histórico)
    - `6`: [RESTORE] Restauración Total
    - `7`: [MODULES] Administrar Módulos y Etiquetas
    - `8`: [CONFIG] Verificar Disco Externo y Estado
    - `0`: [SALIR] Salir del gestor
  - Retorna en `stdout` el número de opción elegida. Código de salida `0` al elegir, `1` al pulsar Cancelar o Salir.

#### V_WHP_03: Mensajes y Alertas
- `whiptail_view_msgbox(title, message)`: Muestra cuadro informativo `--msgbox`.
- `whiptail_view_error(title, message)`: Muestra cuadro de error con prefijo de advertencia y retorno visual claro.
- `whiptail_view_yesno(title, question)`: Muestra cuadro de confirmación `--yesno`. Retorna `0` para "Sí", `1` para "No" o Cancelar.

#### V_WHP_04: Captura Segura de Contraseñas
- `whiptail_view_password(title, prompt)`:
  - Invoca `whiptail --passwordbox`.
  - No muestra caracteres en claro en pantalla.
  - Captura el valor a través de la redirección de descriptores `3>&1 1>&2 2>&3`.
  - Retorna `0` y la clave en `stdout` si se pulsa OK; retorna `1` si se cancela.
- `whiptail_view_password_confirm(title, prompt)`:
  - Solicita la contraseña y una segunda confirmación.
  - Compara internamente ambas entradas en memoria sin guardarlas en disco; si no coinciden, muestra alerta de error y retorna código de discrepancia.

#### V_WHP_05: Cuadros de Entrada y Selección
- `whiptail_view_input(title, prompt, default_value)`: Captura texto simple (`--inputbox`).
- `whiptail_view_menu(title, prompt, tag1, item1, tag2, item2, ...)`: Menú genérico de selección única (`--menu`).
- `whiptail_view_checklist(title, prompt, tag1, item1, status1, ...)`: Lista de casillas de verificación múltiple (`--checklist`). Retorna las etiquetas seleccionadas limpias (sin comillas escapadas innecesarias).
- `whiptail_view_radiolist(title, prompt, tag1, item1, status1, ...)`: Selección única entre opciones excluyentes (`--radiolist`).

#### V_WHP_06: Visor de Archivos y Auditoría
- `whiptail_view_textbox(title, filepath)`: Despliega el contenido de un archivo (manifiestos `.manifest.log` o auditoría) en cuadro `--textbox` con navegación mediante teclado.

#### V_WHP_07: Barra de Progreso
- `whiptail_view_gauge(title, prompt, initial_pct)`: Inicializa o ejecuta `--gauge` recibiendo porcentajes por stdin.

---

### 2.2 Vista CLI ANSI (`lib/views/ansi_view.sh`)

#### V_CLI_01: Paleta de Colores y Formateo
- Soporta colores ANSI estándar:
  - Éxito / Info: Verde (`\033[0;32m`), Azul (`\033[0;34m`), Cian (`\033[0;36m`).
  - Advertencias / Errores: Amarillo (`\033[1;33m`), Rojo (`\033[0;31m`).
  - Títulos y Resaltados: Negrita (`\033[1m`), Reset (`\033[0m`).
- Desactiva colores automáticamente si `stdout` no es una terminal interactiva (p. ej. redirigido a archivo o pipe).

#### V_CLI_02: Funciones Informativas y Formato
- `ansi_view_header(title)`: Banner superior estructurado.
- `ansi_view_info(msg)`: Mensaje prefijado con `[INFO]`.
- `ansi_view_success(msg)`: Mensaje prefijado con `[OK]`.
- `ansi_view_warning(msg)`: Mensaje prefijado con `[AVISO]`.
- `ansi_view_error(msg)`: Mensaje prefijado con `[ERROR]`.

#### V_CLI_03: Interacción por Consola
- `ansi_view_prompt(question, default_value)`: Pregunta con valor por defecto.
- `ansi_view_confirm(question, default_yn)`: Pregunta [S/n] o [s/N] retornando `0` para sí y `1` para no.
- `ansi_view_password(prompt)`: Captura silenciosa usando `read -s -r`.

---

## 3. Manejo de Errores y Códigos de Salida

| Constante | Valor | Significado |
|---|---|---|
| `VIEW_OK` | `0` | Operación aceptada por el usuario (Aceptar, Sí, Selección válida). |
| `VIEW_CANCEL` | `1` | Cancelación por el usuario (Cancelar, No, Atrás). |
| `VIEW_ESC` | `255` | Tecla Escape o cierre forzado del diálogo. |
| `VIEW_ERR_DEPENDENCY` | `10` | La herramienta requerida (`whiptail`) no está instalada en el sistema. |
| `VIEW_ERR_PARAM` | `11` | Argumentos obligatorios faltantes o inválidos para la función de vista. |

---

## 4. Casos Borde y Consideraciones de Seguridad

1. **Aislamiento de Contraseñas:**
   - La contraseña capturada en `whiptail_view_password` viaja únicamente por descriptor de archivo en memoria y se asigna directamente a la variable receptora en el subshell o llamada del controlador.
   - Jamás se escribe en archivos temporales en `/tmp/` ni en disco.
2. **Redirección de Descriptores de Whiptail:**
   - Dado que `whiptail` envía el output interactivo de la TUI a `stderr` (fd 2) o a la terminal para pintar la interfaz, el resultado textual de la elección del usuario debe aislarse con:
     ```bash
     result=$(whiptail ... 3>&1 1>&2 2>&3)
     ```
   - Esto evita mezclar la salida de dibujo con la cadena de resultado capturada.
3. **Manejo de Comillas en Checklist:**
   - `whiptail --checklist` devuelve las opciones seleccionadas entre comillas dobles (ej. `"dev" "sensitive"`). La función de vista debe normalizar y despojar las comillas para retornar cadenas limpias o arrays directamente consumibles por los modelos y controladores.
4. **Comprobación de Dependencia:**
   - Ambas vistas deben incluir una función `*_check_deps` que verifique si `whiptail` y `tput` están presentes.
