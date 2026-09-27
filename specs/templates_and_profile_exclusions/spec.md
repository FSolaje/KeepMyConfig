# Especificación Técnica (SDD): Biblioteca de Plantillas y Exclusiones en Perfiles (`templates_and_profile_exclusions`)

**Sub-Hito:** 12.2  
**Módulo:** `templates.d/`, `lib/models/module_model.sh`, `lib/models/profile_model.sh`, `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Justificación y Objetivos

Actualmente, las recetas de respaldo residen en `modules.d/` y se ejecutan automáticamente de forma global ante cualquier operación `--backup-all`. Esta arquitectura genera limitaciones operativas:
1. **Falta de biblioteca desacoplada:** Un usuario nuevo que ejecuta la aplicación por primera vez se encuentra con módulos precargados que se ejecutan sin su consentimiento explícito, en lugar de disponer de un catálogo de plantillas estándar para activar selectivamente las que necesite.
2. **Inflexibilidad en perfiles particulares:** Un perfil particular hereda ciegamente todos los módulos globales sin posibilidad de excluir o apagar aquellos que no tienen sentido en dicho contexto (ejemplo: un perfil de trabajo que no requiere respaldar el navegador web personal o las llaves SSH personales).
3. **Falta de extensibilidad de plantillas desde la interfaz:** No existe un mecanismo para que un docente o usuario cree plantillas nuevas desde la TUI o exporte un módulo propio a la biblioteca compartida, ni un esqueleto oficial documentado para crear recetas a mano.

### Objetivos:
- **FR-TMPL-001 (Biblioteca de Plantillas `templates.d/`):** Crear un catálogo desacoplado e inmutable de plantillas para aplicaciones comunes en entornos educativos y de desarrollo (Firefox, VSCode, SSH, Bash, IntelliJ, Git, LibreOffice, Thunderbird).
- **FR-TMPL-002 (Estado Inicial Limpio):** Garantizar que en una instalación limpia el sistema arranque con 0 módulos activos de inicio, ofreciendo una experiencia amigable y guiada para que el usuario active únicamente lo que desee.
- **FR-TMPL-003 (Activación Selectiva de Módulos):** Permitir activar recetas desde la biblioteca de plantillas hacia el catálogo global (`modules.d/`) o de forma exclusiva hacia un perfil particular (`profiles/<activo>/modules.d/`).
- **FR-TMPL-004 (Directiva `DISABLED_MODULES` en Perfiles Particulares):** Permitir que un perfil particular declare en su archivo de configuración `DISABLED_MODULES=("mod1" "mod2")`, excluyendo esos módulos globales de su ejecución en cascada.
- **FR-TMPL-005 (Gestión Visual e Interactiva en TUI y CLI):** Proporcionar opciones claras en el menú de módulos y en el menú de perfiles para activar plantillas y gestionar exclusiones mediante checklists.
- **FR-TMPL-006 (Plantilla Esqueleto de Referencia):** Incluir `templates.d/template-skeleton.conf` profusamente comentado para facilitar el desarrollo manual de recetas.
- **FR-TMPL-007 (Creación de Plantillas en Asistente TUI):** Asistente interactivo en la TUI para diseñar y guardar nuevas plantillas directamente en `templates.d/`.
- **FR-TMPL-008 (Exportación de Módulos a Plantillas):** Permitir promover cualquier módulo activo existente (sea global o de un perfil) a la biblioteca permanente `templates.d/`.

---

## 2. Requerimientos Funcionales Detallados

### FR-TMPL-001: Biblioteca de Plantillas (`templates.d/`)
1. El directorio `templates.d/` residirá en la raíz del repositorio y contendrá recetas estándar completas con comentarios de ayuda:
   - `ssh-keys.conf`: Respaldo sensible de claves SSH con purga opcional.
   - `bash-env.conf`: Configuración del shell `.bashrc`, `.profile`, `.bash_aliases`.
   - `firefox.conf`: Perfiles y marcadores de Mozilla Firefox (`.mozilla/firefox`).
   - `vscode-standard.conf`: Configuración de extensiones y settings de VSCode.
   - `vscode-sensitive.conf`: Credenciales y almacenamiento global de VSCode.
   - `intellij.conf`: Configuración de IDEs JetBrains (`.config/JetBrains`).
   - `git-config.conf`: Configuración global de Git (`.gitconfig`).
   - `thunderbird.conf`: Perfiles de correo Mozilla Thunderbird (`.thunderbird`).
   - `libreoffice.conf`: Configuraciones y estilos de LibreOffice (`.config/libreoffice`).
2. Las recetas en `templates.d/` no son ejecutadas directamente por operaciones de respaldo; sirven exclusivamente como modelo para ser activadas.

### FR-TMPL-002: Estado Inicial Limpio
1. El catálogo de módulos activos de inicio (`modules.d/`) estará vacío por defecto en una instalación limpia (solo contendrá `.gitkeep`).
2. Si se ejecuta `./backup_manager.sh --backup-all` o la opción de respaldo total en la TUI sin módulos activos:
   - El sistema no fallará con error crítico; mostrará un mensaje descriptivo indicando que no hay módulos activos y orientando al usuario hacia la activación desde plantillas.

### FR-TMPL-003: Activación de Módulos desde Plantilla
1. **En la capa de Modelo (`module_model.sh`):**
   - `module_model_list_templates [dir]`: Lista los IDs disponibles en `templates.d/`.
   - `module_model_get_template <id> [dir]`: Obtiene la metadata de una plantilla.
   - `module_model_activate_template <template_id> <target_dir>`: Copia la plantilla al directorio destino (`modules.d/` o `profiles/<perfil>/modules.d/`), verificando que no exista previamente.
2. **En TUI (`app_controller.sh` - Opción 7):**
   - Nueva acción: *Activar módulo desde plantilla*:
     - Presenta la lista de plantillas disponibles con sus nombres amigables.
     - Si el perfil activo != `default`, pregunta el ámbito: `[1] Catálogo Global` o `[2] Exclusivo del Perfil Activo`.
     - Copia la plantilla y confirma la activación.
3. **En CLI:**
   - `--list-templates`: Muestra tabla con plantillas disponibles.
   - `--enable-template <id> [--profile <perfil>]`: Activa una plantilla directamente.

### FR-TMPL-004: Desactivación Selectiva en Perfiles (`DISABLED_MODULES`)
1. **Formato en `profiles/<perfil>/profile.conf`:**
   ```bash
   PROFILE_ID="trabajo"
   PROFILE_NAME="Perfil de Trabajo"
   PROFILE_DESCRIPTION="Entorno laboral de desarrollo"
   TARGET_SUBDIR="Backups/Trabajo"
   DISABLED_MODULES=("firefox" "ssh-keys")
   ```
2. **Lógica de Cascada en `profile_model_list_modules "$active_profile"`:**
   - Paso 1: Obtener la lista de módulos globales activos (`modules.d/*.conf`).
   - Paso 2: Si `$active_profile != "default"`, leer `DISABLED_MODULES` de `profile.conf`.
   - Paso 3: Filtrar y eliminar de la lista global cualquier módulo incluido en `DISABLED_MODULES`.
   - Paso 4: Añadir los módulos exclusivos y overrides presentes en `profiles/<active_profile>/modules.d/*.conf`.
   - Paso 5: Devolver la lista ordenada alfabéticamente y deduplicada.
3. **Funciones del Modelo (`profile_model.sh`):**
   - `profile_model_get_disabled_modules <profile_id>`: Retorna la lista de IDs excluidos.
   - `profile_model_disable_module <profile_id> <module_id>`: Añade un ID a `DISABLED_MODULES` de forma atómica y sin duplicados.
   - `profile_model_enable_module <profile_id> <module_id>`: Remueve un ID de `DISABLED_MODULES`.

### FR-TMPL-005: Gestión de Exclusiones en TUI
1. En la **Opción 9 (Gestión de Perfiles)**:
   - Si el perfil activo es distinto de `default`:
     - Se añade una acción: *Gestionar exclusiones de módulos globales*:
       - Muestra un checklist con todos los módulos activos del catálogo global.
       - Los módulos ya excluidos aparecen marcados como `ON` (desactivados).
       - El usuario puede marcar/desmarcar para actualizar `DISABLED_MODULES` en `profile.conf`.

### FR-TMPL-006: Plantilla Esqueleto de Referencia (`templates.d/template-skeleton.conf`)
1. Archivo canónico comentado en `templates.d/template-skeleton.conf`:
   - Documenta sintaxis de arrays bash (`MODULE_TAGS`, `MODULE_PATHS`).
   - Documenta directivas booleanas (`IS_SENSITIVE`, `PURGE_AFTER_BACKUP`).
   - Explica el uso de rutas relativas al `$HOME` sin prefijos absolutos.
   - Detalla la variable opcional `POST_RESTORE_HOOK`.

### FR-TMPL-007: Creación de Plantillas en Asistente TUI
1. En la **Opción 7 (Administrar Módulos y Plantillas)**:
   - Nueva acción: *Crear nueva plantilla en la biblioteca*:
     - Asistente interactivo idéntico al de creación de módulos (ID, nombre descriptivo, rutas, etiquetas, sensibilidad, purga y hooks).
     - Persiste la receta directamente en `templates.d/<id>.conf` previa sanitización de rutas.
     - Pasa a estar disponible de inmediato en la biblioteca para ser activada en cualquier perfil.

### FR-TMPL-008: Exportación de Módulos Activos a Plantillas
1. En la **Opción 7 (Administrar Módulos y Plantillas)**:
   - Nueva acción: *Exportar módulo activo a la biblioteca de plantillas*:
     - Presenta la lista de módulos actualmente activos.
     - Al seleccionar uno, solicita confirmación del ID de plantilla (por defecto el mismo ID del módulo).
     - Si ya existe una plantilla con ese ID en `templates.d/`, solicita confirmación para sobrescribir.
     - Copia la receta a `templates.d/<id>.conf`.

---

## 3. Criterios de Aceptación

- [ ] Las 9 plantillas estándar más `template-skeleton.conf` existen en `templates.d/` y pasan la verificación sintáctica `bash -n`.
- [ ] En un entorno sin módulos activos, `backup-all` avisa de la ausencia de módulos sin generar errores de ejecución.
- [ ] La activación de una plantilla desde TUI/CLI crea la receta en el destino seleccionado preservando los campos.
- [ ] Se pueden crear plantillas nuevas desde la TUI y guardarlas en `templates.d/`.
- [ ] Se puede exportar cualquier módulo activo a la biblioteca de plantillas `templates.d/`.
- [ ] Un perfil con `DISABLED_MODULES=("firefox")` no incluye `firefox` al ejecutar `profile_model_list_modules` ni al lanzar `--backup-all`.
- [ ] La suite completa de pruebas unitarias supera el 100% de aserciones.
- [ ] Escáner SAST de seguridad y privacidad ejecutado y limpio (código 0).
- [ ] Cumplimiento mandatorio de la Sección 10 de `AGENT.md`: `README.md` y `MANUAL_USUARIO.md` actualizados previo al commit.
