# Plan Técnico: Corrección del Asistente de Creación de Módulos (TUI)

**Módulo:** `lib/controllers/app_controller.sh` & `lib/models/module_model.sh`  
**Rama:** `dev/fix/module-admin-wizard`  
**Fecha:** 2026-09-20  

---

## 1. Arquitectura de Cambios

### 1.1 Controlador (`lib/controllers/app_controller.sh`)
En la función `controller_handle_modules_admin`:
- Tras recopilar `mod_paths_str` y `sel_tags`:
  - Recorrer `paths_arr` y ensamblar `paths_joined` uniendo los elementos no vacíos con `|`.
  - Recorrer `tags_arr` y ensamblar `tags_joined` uniendo los elementos no vacíos con `,`. Si está vacío, asignar `"dev"`.
  - Reemplazar la llamada errónea:
    ```bash
    # Anterior (errónea):
    module_model_save "$mod_id" "$mod_name" "$is_sens" "$purge_val" "" paths_arr tags_arr

    # Corregida:
    module_model_save "$mod_id" "$mod_name" "$tags_joined" "$paths_joined" "$is_sens" "$purge_val" "" "$MODULES_DIR"
    ```

### 1.2 Modelo (`lib/models/module_model.sh`)
En `module_model_save`:
- Detectar delimitador de tags:
  ```bash
  local tags_delim=','
  [[ "$tags_str" =~ , ]] || tags_delim=' '
  IFS="$tags_delim" read -r -a tags_arr <<< "$tags_str"
  ```
  Esto asegura compatibilidad bidireccional si se invocan con tags separados por espacios o por comas.

---

## 2. Plan de Pruebas

1. Añadir prueba unitaria en `tests/test_controller.sh` que verifique la creación de un módulo llamando a `module_model_save` con los parámetros adecuados tal como los emite el controlador y validando que el archivo generado en `modules.d/` sea parseable por `module_model_get`.
2. Ejecutar la suite completa de pruebas (`tests/test_*.sh`).
3. Ejecutar escáner SAST de seguridad y privacidad (`user_data/security_check/scripts/security_check.sh --all`).
