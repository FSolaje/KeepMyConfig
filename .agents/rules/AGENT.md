# Directrices y Parámetros del Agente (AGENT.md)

Este documento define las reglas de comportamiento, estándares de desarrollo y parámetros operativos para el agente de IA en el proyecto **BackupConfig**.

---

## 1. Regla Mandatoria: Conventional Commits

Todos los commits realizados en este repositorio deben seguir **estrictamente** la especificación de [Conventional Commits v1.0.0](https://www.conventionalcommits.org/):

### Formato Obligatorio
```text
<tipo>(<ámbito>): <descripción concisa en imperativo>

[cuerpo opcional detallando el motivo y contexto del cambio]

[pie opcional con notas de rotura o referencias a issues/tareas]
```

### Tipos Permitidos
- **`feat`**: Nueva característica o funcionalidad (ej. `feat(model): implementar verificación de marcador en device_model`).
- **`fix`**: Corrección de un error o bug en la lógica, rutas o permisos (ej. `fix(crypto): corregir tubería de descifrado en restore`).
- **`docs`**: Cambios exclusivos en documentación o especificaciones (ej. `docs(sdd): añadir especificación de módulos independientes`).
- **`refactor`**: Refactorización de código que no añade funcionalidades ni corrige bugs (ej. `refactor(views): separar wrappers de whiptail en funciones puras`).
- **`test`**: Creación o ajuste de scripts y suites de verificación (ej. `test(crypto): añadir prueba automatizada de shred y gpg`).
- **`chore`**: Tareas auxiliares, mantenimiento de configuración, `.gitignore`, setup de git, etc. (ej. `chore(git): inicializar repositorio y exclusiones`).
- **`style`**: Formateo de código, indentación o ajuste de espaciado sin alterar lógica.

### Ámbitos Sugeridos (`scope`)
- `model`, `view`, `controller`, `modules`, `crypto`, `tui`, `cli`, `storage`, `deps`.

---

## 2. Continuidad de Sesión y Estado

1. **Al iniciar cualquier sesión:**
   - Comprobar automáticamente la existencia del archivo `PROXIMOS_PASOS.md` en el espacio de trabajo.
   - Leer su contenido para retomar el contexto exacto antes de realizar cualquier acción.
2. **Al finalizar un hito o sesión:**
   - Actualizar `PROXIMOS_PASOS.md` reflejando las tareas completadas, el estado del código y los pasos inmediatos siguientes.

---

## 3. Principios de Arquitectura y Desarrollo

1. **Patrón MVC Estricto en Bash:**
   - **Modelos (`lib/models/`):** Contienen exclusivamente lógica de negocio (empaquetado, cálculo de hashes SHA-256, llamadas a `gpg`, borrado con `shred`, lectura de `.conf`). **Jamás** deben invocar `whiptail`, ni imprimir menús, ni pedir entradas directas al usuario. Comunican resultados mediante códigos de salida (`return 0` / `return 1`) y datos estructurados por `stdout`.
   - **Vistas (`lib/views/`):** Contienen únicamente la presentación en pantalla (diálogos `whiptail`, formatos ANSI, banners). **Jamás** realizan operaciones sobre el sistema de archivos de backup ni aplican lógica de negocio.
   - **Controlador (`lib/controllers/`):** Recibe las interacciones de la vista o los argumentos de la CLI, llama a los modelos correspondientes y decide qué vista presentar a continuación.
2. **Módulos Independientes (`modules.d/`):**
   - Cada aplicación o configuración es un archivo `.conf` independiente.
   - Las configuraciones sensibles y no sensibles de una misma herramienta deben poder desacoplarse en módulos separados (ej. `vscode-standard.conf` y `vscode-sensitive.conf`).
3. **Seguridad y Entorno sin Privilegios:**
   - Asumir siempre que se ejecuta en **Lliurex 25 / Ubuntu 24.04** como **usuario estándar sin privilegios `sudo`**.
   - No utilizar comandos que requieran privilegios de administrador.
   - Para la purga de datos sensibles en el equipo de origen, usar siempre `shred -u -z -n 3` en lugar de `rm`.
   - Validar obligatoriamente la presencia del archivo marcador `.backup_storage_marker` antes de cualquier escritura hacia el disco de backup para evitar escrituras fantasma en almacenamiento local.
4. **Interfaz Dual:**
   - La aplicación debe ser 100% funcional tanto desde la TUI interactiva (`whiptail`) como en modo desatendido por argumentos de línea de comandos (CLI Headless) para entornos remotos o TTY pura.
