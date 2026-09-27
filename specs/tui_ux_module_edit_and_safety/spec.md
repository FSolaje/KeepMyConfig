# Especificación Funcional: Arquitectura Universal TUI, Asistente de Edición de Módulos, Pre-Flight Safety Gate y Personalización Visual

> **Rama:** `dev/feature/tui-ux-module-edit-and-safety`  
> **Ámbito:** `view`, `controller`, `model`, `tui`, `cli`, `security`  
> **Estado:** Borrador inicial para revisión y aprobación humana  

---

## 1. Contexto y Objetivos

Durante la fase de pruebas del sistema en modo aislado (`--test-mode`), se han identificado necesidades clave de usabilidad, un bug sutil de aprovisionamiento en sandbox, carencias en la gestión del ciclo de vida de recetas y la necesidad crítica de blindar las operaciones destructivas (purga segura con `shred -u` y sobreescrituras en restauración).

Los objetivos fundamentales de esta especificación son:
1. **Corregir el aprovisionamiento del Sandbox:** Garantizar que el catálogo de módulos globales se clone en `user_data/sandbox/modules.d/` al inicializar el modo de pruebas.
2. **Clarificación Contextual de Rutas:** Enriquecer todos los diálogos de solicitud de rutas para orientar al usuario sobre la ruta base, comportamiento Zero-Config, rutas relativas y absolutas.
3. **Asistente de Edición de Módulos:** Permitir modificar interactivamente recetas existentes desde la TUI (nombre, rutas con captura guiada, etiquetas, sensible y purga).
4. **Resolución Inteligente de Colisiones en Plantillas:** Permitir clonar/derivar recetas con nuevos identificadores (`--as-module`) cuando colisionen con recetas preexistentes.
5. **Pre-Flight Safety Gate:** Implementar una pantalla previa de resumen y confirmación obligatoria en TUI y CLI antes de cualquier ejecución de backup, destacando en rojo intenso las operaciones con purga activa (`shred -u`).
6. **Arquitectura Universal de Menús TUI (Modelo Híbrido):** Homogeneizar el 100% de los menús del sistema (1 al 7) con cabecera de telemetría en vivo, badges de categoría semántica, iconografía Unicode y atajos numéricos directos.
7. **Personalización Visual (Temas TUI):** Implementar soporte para paletas temáticas (`midnight`, `cyberdark`, `aubergine`, `amber`, `default`) aprovechando `NEWT_COLORS` en `whiptail`.

---

## 2. Requerimientos Funcionales Detallados

### RF-01: Sembrado Automático de Módulos en Sandbox Mode (Bugfix)
- **RF-01.1:** En `controller_enable_sandbox_mode`, si el directorio `${sandbox_base}/modules.d/` no contiene archivos `.conf`, el sistema debe copiar automáticamente todas las recetas de `${base_dir}/modules.d/*.conf`.
- **RF-01.2:** En `controller_handle_backup_module` y demás selectores de módulos, si la lista de módulos para el perfil activo está vacía, debe mostrar un diálogo amigable de advertencia indicando cómo crear o activar módulos antes de intentar abrir un selector vacío.

### RF-02: Clarificación y Orientación Contextual en Diálogos de Rutas
- **RF-02.1:** Los diálogos de entrada de rutas (`controller_handle_create_profile`, `controller_handle_set_backup_dest`, `device_model_init_target_directory`) deben mostrar en su texto descriptivo:
  - El valor actual de `BACKUP_DESTINATION`.
  - La indicación de que dejar el campo vacío aplica la convención Zero-Config (`<DESTINO>/<id_perfil>`).
  - La regla de que rutas relativas (ej. `Trabajo/Docente`) se alojan dentro del destino base.
  - La regla de que rutas absolutas (`/...`) o con tilde (`~/...`) se tratan como destinos independientes.

### RF-03: Asistente de Edición de Módulos en TUI
- **RF-03.1:** Incorporar la opción `2) ✏️ [MÓDULOS] Modificar un Módulo Existente` en el menú de administración de módulos.
- **RF-03.2:** Mostrar selector de módulos activos indicando su ámbito (`[Global]` o `[Perfil: <id>]`).
- **RF-03.3:** Si el usuario selecciona un módulo global estando en un perfil específico (no `default`), preguntar si desea crear un *Override* exclusivo para su perfil o modificar la receta global compartida.
- **RF-03.4:** Precargar los valores actuales del módulo:
  - Nombre descriptivo (caja de texto).
  - Rutas asociadas (mediante `whiptail_view_input_paths`, mostrando rutas actuales y permitiendo reemplazarlas o ampliarlas).
  - Etiquetas asignadas (checklist con etiquetas actuales en `ON`).
  - Sensibilidad (`IS_SENSITIVE`): Sí/No.
  - Purga automática post-backup (`PURGE_AFTER_BACKUP`): Sí/No (solo si es sensible).
- **RF-03.5:** Persistencia atómica mediante `module_model_save`.

### RF-04: Resolución Inteligente de Colisiones en Plantillas
- **RF-04.1:** Al activar una plantilla (`controller_handle_enable_template`), si ya existe un módulo con ese ID en el destino:
  - Mostrar un menú de 3 opciones:
    1. *Clonar / Derivar con nuevo nombre:* Solicitar nuevo ID y nombre (sugiriendo `<id>-copia` o `<id>-<perfil>`).
    2. *Restablecer / Sobrescribir con la plantilla limpia:* Solicitar confirmación de seguridad.
    3. *Cancelar:* Retornar limpio código 0 sin cambios.
- **RF-04.2:** Soporte CLI desatendido:
  - Flag `--as-module <nuevo_id>`: Asigna el identificador derivado directamente.
  - Flag `--force`: Sobrescribe sin confirmación interactiva.
- **RF-04.3:** Comportamiento simétrico al exportar un módulo activo a la biblioteca de plantillas si colisiona con una existente.

### RF-05: Pre-Flight Safety Gate y Matriz de Acciones Críticas
- **RF-05.1:** Antes de iniciar cualquier copia (`backup-all`, `backup-tag`, `backup-module`), generar la matriz pre-flight de módulos:
  - Nombre del módulo | Ámbito | Cifrado GPG | Purga Shred | Destino.
- **RF-05.2:** En **TUI**:
  - Diálogo de confirmación `whiptail_view_yesno` con la tabla resumen.
  - Si hay módulos con purga activa (`shred -u`), lanzar un segundo diálogo de alarma crítica:
    - Título: `¡PELIGRO: DESTRUCCIÓN IRREVERSIBLE DE ARCHIVOS!`
    - Desglose con viñetas de las rutas absolutas completas que serán destruidas.
    - Foco inicial obligatorio en **[NO]** para evitar ejecuciones accidentales.
- **RF-05.3:** En **CLI**:
  - Imprimir la tabla ANSI formateada.
  - Si hay purga activa, imprimir bloque de advertencia en fondo rojo brillante con texto blanco (`\033[41;97;1m`).
  - Solicitar confirmación interactiva `¿Desea continuar? [s/N]` (o exigir escribir `SI` para purgas), salvo si se especifica el flag `--yes` / `-y`.
- **RF-05.4:** En operaciones de **Restauración (`restore`)**:
  - Advertir sobre la sobreescritura de cambios locales en `$HOME` con listado de rutas afectadas antes de descomprimir.
- **RF-05.5:** En **Eliminación de Perfiles**:
  - Prohibición estricta de borrar `default`.
  - Prohibición estricta de borrar el perfil activo (exigir cambio previo).
  - Confirmación nominativa aclarando que las copias en disco quedan protegidas.

### RF-06: Arquitectura Universal de Menús TUI (Modelo Híbrido)
- **RF-06.1:** Todos los menús (1 al 7) deben presentar:
  - Encabezado dinámico en el área de texto superior con telemetría en vivo.
  - Badges semánticos alineados (`[BACKUP]`, `[RESTORE]`, `[PERFILES]`, `[MÓDULOS]`, `[DESTINO]`, `[TEMAS]`, `[SISTEMA]`).
  - Iconos Unicode representativos.
  - Atajos de teclado numéricos directos (`1..N`).
  - Opción de retorno homogénea `0) ↩️ [VOLVER]` (o `[SALIR]` en menú principal).
- **RF-06.2:** Menús a estructurar:
  - Menú 1: Principal (Acciones directas + Centros de administración).
  - Menú 2: Opciones de Respaldo (Por etiqueta / individual).
  - Menú 3: Centro de Recuperación (Todo / Sensible / Individual).
  - Menú 4: Gestión de Perfiles.
  - Menú 5: Administración de Módulos y Plantillas.
  - Menú 6: Destinos de Almacenamiento.
  - Menú 7: Preferencias del Sistema y Temas Visuales.

### RF-07: Personalización Visual y Temas en TUI
- **RF-07.1:** Soporte de paletas temáticas mediante la variable nativa `NEWT_COLORS` de `libnewt`:
  - `midnight`: Azul marino oscuro con bordes y títulos cian y texto blanco.
  - `cyberdark`: Modo oscuro en carbón con acentos verdes y cian.
  - `aubergine`: Tonos berenjena/púrpura suave con acentos cálidos tipo Ubuntu/Lliurex.
  - `amber`: Terminal clásica retro ámbar sobre negro.
  - `default`: Paleta gris clásica del sistema.
- **RF-07.2:** Persistencia de la preferencia en `config/config.conf` (`TUI_THEME="midnight"`).
- **RF-07.3:** Selector interactivo de temas con previsualización en caliente en el Menú 7.

---

## 3. Casos Borde y Reglas Defensivas

1. **Terminal sin soporte de color expandido:** Si `NEWT_COLORS` no es interpretada o la terminal carece de soporte ncurses color, degradación transparente a la paleta predeterminada.
2. **Cancelación en cualquier punto de edición:** Si el usuario pulsa Cancelar o `Esc` en cualquier pantalla de edición de módulo o resolución de plantilla, el sistema debe abortar sin tocar los archivos de configuración y retornar código 0.
3. **Módulo sin rutas al editar:** El validador debe rechazar guardar un módulo si se borran todas las rutas asociadas.
4. **Colisión de nombre en clonación:** Si el usuario introduce en la clonación otro nombre que también colisiona, volver a advertir y pedir un nombre válido.
5. **Modo no interactivo (Cron / Headless):** En ejecuciones con `--yes`, el Pre-Flight Gate debe emitir el reporte en stdout pero no bloquear la ejecución.
