# Plan Técnico y Arquitectónico: Ámbito de Módulos y Sanitización (`scoped_modules_sanitization`)

**Sub-Hito:** 12.1  
**Módulos Afectados:** `lib/models/module_model.sh`, `lib/models/profile_model.sh`, `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Arquitectura de Cambios

### 1.1 Modelo `module_model.sh`
- **Nueva Función:** `module_model_sanitize_path "$raw_path"`
  - Entrada: Cadena de texto con ruta que puede contener `$HOME`, `~`, `/home/<user>/` o barras iniciales.
  - Procesamiento:
    ```bash
    local clean="$raw_path"
    clean=$(echo "$clean" | sed -E 's|^(\$HOME|\~|/home/[^/]+)/?||')
    clean=$(echo "$clean" | sed -E 's|^/+||')
    echo "$clean"
    ```
  - Salida: Ruta relativa limpia o código de error si queda vacía.
- **Integración en `module_model_save`:**
  - Antes de escribir `MODULE_PATHS`, invocar `module_model_sanitize_path` para cada ruta procesada.

### 1.2 Modelo `profile_model.sh`
- **Nueva Función:** `profile_model_sanitize_target_subdir "$raw_subdir"`
  - Elimina slashes iniciales (`sed -E 's|^/+||'`).
  - Si el usuario introdujo `$HOME/...`, advertir o convertir.
- **Integración en `profile_model_create`:**
  - Sanitizar `$target_subdir` antes de escribir en `profile.conf`.

### 1.3 Controlador `app_controller.sh`
- **En `controller_handle_modules_admin` (Opción 7 - Crear módulo):**
  - Resolver el perfil activo con `_controller_get_active_profile`.
  - Si `$act_prof != "default"`:
    - Desplegar `whiptail_view_menu` preguntando si el destino de guardado es:
      - `1` ➔ `${CONTROLLER_BASE_DIR}/modules.d` (Global).
      - `2` ➔ `${CONTROLLER_BASE_DIR}/profiles/${act_prof}/modules.d` (Exclusivo del perfil activo).
    - Asegurar que el directorio de destino exista con `mkdir -p`.
    - Pasar ese directorio como argumento `$target_dir` a `module_model_save`.
  - En la lista de módulos para eliminar/inspeccionar:
    - Indicar con etiquetas si el archivo reside en `modules.d/` o en `profiles/<perfil>/modules.d/`.

---

## 2. Plan de Pruebas Unitarias

1. **`tests/test_module_model.sh`:**
   - Test de `module_model_sanitize_path` con `$HOME/dir`, `~/dir`, `/home/usuario/dir`, `//dir/sub`, `dir`.
   - Test de guardado con `module_model_save` verificando que la receta contenga las rutas limpias.
2. **`tests/test_controller.sh`:**
   - Test de creación de módulo con destino en perfil específico.
   - Verificación de que el módulo solo se lista bajo ese perfil y no bajo `default`.
