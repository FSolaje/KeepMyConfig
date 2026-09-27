# Plan Técnico y Arquitectónico: Biblioteca de Plantillas y Exclusiones en Perfiles (`templates_and_profile_exclusions`)

**Sub-Hito:** 12.2  
**Módulos Afectados:** `templates.d/`, `lib/models/module_model.sh`, `lib/models/profile_model.sh`, `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Arquitectura de Componentes

### 1.1 Directorio de Plantillas (`templates.d/`)
- Se crea el directorio `templates.d/` en la raíz del proyecto.
- Se crean/trasladan las recetas estándar y la plantilla de referencia:
  1. `template-skeleton.conf`: Archivo canónico comentado que sirve como esqueleto y guía de desarrollo para nuevos módulos.
  2. `ssh-keys.conf`: Claves SSH (`.ssh/id_rsa`, `.ssh/id_ed25519`, `.ssh/config`) con `IS_SENSITIVE=true`, `PURGE_AFTER_BACKUP=false` y hook de permisos 700/600.
  3. `bash-env.conf`: `.bashrc`, `.bash_aliases`, `.profile` con `IS_SENSITIVE=false`.
  4. `firefox.conf`: `.mozilla/firefox` con `IS_SENSITIVE=false`, etiqueta `browser,web`.
  5. `vscode-standard.conf`: `.config/Code/User/settings.json`, `.config/Code/User/keybindings.json`.
  6. `vscode-sensitive.conf`: `.config/Code/User/globalStorage` con `IS_SENSITIVE=true`.
  7. `intellij.conf`: `.config/JetBrains` con `IS_SENSITIVE=false`, etiqueta `ide,dev`.
  8. `git-config.conf`: `.gitconfig`, `.config/git/ignore` con `IS_SENSITIVE=false`, etiqueta `git,dev`.
  9. `thunderbird.conf`: `.thunderbird` con `IS_SENSITIVE=false`, etiqueta `mail,office`.
  10. `libreoffice.conf`: `.config/libreoffice` con `IS_SENSITIVE=false`, etiqueta `office`.

### 1.2 Modelo de Módulos (`lib/models/module_model.sh`)
- **Constante:** `_MODULE_MODEL_DEFAULT_TEMPLATES_DIR` apuntando a `${PROJECT_ROOT}/templates.d`.
- **Nuevas Funciones:**
  - `module_model_list_templates [templates_dir]`:
    - Escanea `templates_dir/*.conf` ignorando `template-skeleton.conf` de la lista de módulos activables (o presentándolo como esqueleto) y devuelve los IDs disponibles.
  - `module_model_get_template <template_id> [templates_dir]`:
    - Invoca `module_model_get` pasando el directorio de plantillas.
  - `module_model_activate_template <template_id> <target_modules_dir> [templates_dir]`:
    - Valida que la plantilla exista en `templates_dir`.
    - Valida que en `target_modules_dir/<template_id>.conf` no exista ya una receta.
    - Copia el archivo `.conf` a `target_modules_dir/<template_id>.conf`.
  - `module_model_create_template <id> <name> <tags> <paths> <is_sens> <purge> <hook> [templates_dir]`:
    - Utiliza `module_model_save` especificando `templates_dir` como destino.
  - `module_model_export_to_template <source_module_file> <target_template_id> [templates_dir]`:
    - Valida que el fichero origen sea un módulo sintácticamente correcto.
    - Lo copia a `templates_dir/<target_template_id>.conf`.

### 1.3 Modelo de Perfiles (`lib/models/profile_model.sh`)
- **Soporte `DISABLED_MODULES` en `profile.conf`:**
  - En `profile_model_get`: parsear `DISABLED_MODULES` como array bash.
    ```bash
    local disabled_joined=""
    if [[ "$(declare -p DISABLED_MODULES 2>/dev/null)" =~ "declare -a" ]]; then
        disabled_joined=$(IFS=,; echo "${DISABLED_MODULES[*]}")
    fi
    echo "DISABLED_MODULES=$disabled_joined"
    ```
- **Filtrado en Cascada en `profile_model_list_modules <active_profile>`:**
  - Lee los módulos de `modules.d/`.
  - Si `active_profile != "default"`:
    - Lee `DISABLED_MODULES` de `profiles/<active_profile>/profile.conf`.
    - Filtra la lista global, descartando cualquier elemento que esté en la lista negra de exclusión del perfil.
    - Agrega los módulos de `profiles/<active_profile>/modules.d/`.
  - Retorna la lista deduplicada y ordenada.
- **Nuevas Funciones de Gestión de Exclusiones:**
  - `profile_model_get_disabled_modules <profile_id> [profiles_dir]`:
    - Retorna los IDs de módulos deshabilitados para el perfil.
  - `profile_model_disable_module <profile_id> <module_id> [profiles_dir]`:
    - Agrega de forma idempotente y atómica `module_id` al array `DISABLED_MODULES` en `profile.conf`.
  - `profile_model_enable_module <profile_id> <module_id> [profiles_dir]`:
    - Remueve `module_id` del array `DISABLED_MODULES` en `profile.conf`.

### 1.4 Controlador y Flujo de Interfaz (`lib/controllers/app_controller.sh`)
- **En `controller_handle_modules_admin` (Opción 7):**
  - Submenú enriquecido con acciones:
    1. *Listar y ver detalle de módulos activos*: Indica `[Global]` o `[Perfil: <id>]`.
    2. *Activar módulo desde plantilla*:
       - Lista plantillas con `module_model_list_templates`.
       - Pregunta si activar en Global o en Perfil Activo.
       - Invoca `module_model_activate_template`.
    3. *Crear un nuevo módulo activo*: Asistente habitual.
    4. *Crear una nueva plantilla en la biblioteca*: Asistente que guarda directamente en `templates.d/`.
    5. *Exportar módulo activo a la biblioteca de plantillas*: Copia una receta activa a `templates.d/`.
    6. *Eliminar un módulo activo*: Baja de receta.
    7. *Añadir etiqueta al catálogo*.
- **En `controller_handle_profiles_admin` (Opción 9):**
  - Si perfil activo != `default`:
    - Acción: *Gestionar exclusiones de módulos globales*:
      - Obtiene módulos globales activos (`modules.d/`).
      - Obtiene módulos excluidos actualmente con `profile_model_get_disabled_modules`.
      - Presenta `whiptail_view_checklist` con estado `ON` si está excluido, `OFF` si está activo.
      - Al aceptar, actualiza `DISABLED_MODULES` en `profile.conf`.
- **En CLI (`backup_manager.sh`):**
  - `--list-templates`: Muestra tabla formateada de plantillas disponibles.
  - `--enable-template <id> [--profile <perfil>]`: Activa la plantilla indicada.
  - `--export-template <mod_id> [--profile <perfil>]`: Promueve un módulo activo a plantilla.

---

## 2. Plan de Pruebas Unitarias y de Integración

1. **`tests/test_module_model.sh`:**
   - Test de `module_model_list_templates` en `templates.d/`.
   - Test de `module_model_activate_template` hacia directorio mock, comprobando que se preservan los campos.
   - Test de `module_model_create_template` y `module_model_export_to_template`.
   - Test de rechazo si el módulo ya existe en destino al activar.
2. **`tests/test_profile_model.sh`:**
   - Test de persistencia y lectura de `DISABLED_MODULES` en `profile.conf`.
   - Test de `profile_model_disable_module` y `profile_model_enable_module`.
   - Test de `profile_model_list_modules` verificando que un módulo global excluido **no** aparece en la lista del perfil hijo.
3. **`tests/test_controller.sh`:**
   - Test de ejecución CLI `--list-templates`.
   - Test de activación de plantilla vía comando.
   - Test de exportación de módulo a plantilla.
   - Test de `--backup-all` con un módulo excluido en el perfil activo, comprobando que no se respalda.
