# Plan Arquitectónico y Técnico: module_model

**Rama:** `dev/feature/module-model`  
**Componente:** `lib/models/module_model.sh`  
**Objetivo:** Implementar la lógica del modelo para el catálogo de módulos y recetas de configuración.

---

## 1. Diseño Arquitectónico y Modular

El modelo se organizará como una biblioteca de funciones puras en Bash, exportando constantes de error y sin efectos secundarios en el estado global:

### Funciones a Implementar en `lib/models/module_model.sh`:

1. `module_model_list [modules_dir]`
   - Busca archivos `*.conf` en `modules.d/`.
   - Valida cada uno con `module_model_validate`.
   - Emite la lista de IDs válidos por `stdout` (uno por línea).

2. `module_model_get <module_id> [modules_dir]`
   - Resuelve `$modules_dir/$module_id.conf`.
   - Ejecuta validación de sintaxis (`bash -n`).
   - Carga el archivo en una subshell aislada y emite la definición estructurada:
     ```text
     ID=<MODULE_ID>
     NAME=<MODULE_NAME>
     TAGS=<tag1,tag2,...>
     PATHS=<path1|path2|...>
     IS_SENSITIVE=<true|false>
     PURGE_AFTER_BACKUP=<true|false>
     POST_RESTORE_HOOK=<comando>
     ```

3. `module_model_filter_by_tag <tag> [modules_dir]`
   - Itera por los módulos y retorna los IDs de aquellos que contengan la etiqueta especificada en `MODULE_TAGS`.

4. `module_model_filter_by_sensitivity <true|false> [modules_dir]`
   - Retorna los IDs de módulos coincidentes con el flag `IS_SENSITIVE`.

5. `module_model_check_paths <module_id> [target_home] [modules_dir]`
   - Evalúa cada elemento de `MODULE_PATHS` concatenado con `$target_home`.
   - Emite:
     ```text
     FOUND=<ruta_relativa>
     MISSING=<ruta_relativa>
     ```
   - Retorna 0 si al menos una ruta existe; retorna código de aviso si ninguna ruta existe en el equipo anfitrión.

6. `module_model_save <module_id> <name> <tags_csv> <paths_csv_or_pipe> <is_sensitive> <purge_after> <hook> [modules_dir]`
   - Valida que `module_id` cumpla el regex `^[a-zA-Z0-9_-]+$`.
   - Genera atómicamente el archivo `.conf` con sangrado y formato declarativo estándar.

7. `module_model_delete <module_id> [modules_dir]`
   - Elimina de forma segura el archivo `$modules_dir/$module_id.conf`.

8. `module_model_get_all_tags [modules_dir] [tags_file]`
   - Combina las etiquetas registradas en `config/default_tags.conf` con las etiquetas dinámicas utilizadas en las recetas `modules.d/*.conf`.
   - Emite lista única ordenada.

9. `module_model_add_tag_to_catalog <tag_id> <description> [tags_file]`
   - Agrega una nueva definición `TAG:DESCRIPCIÓN` al catálogo global si no existía previamente.

---

## 2. Walkthrough de Impacto

- **Dependencias:** No añade herramientas externas (utiliza utilidades estándar de Bash, `grep`, `sed`, `awk`).
- **Compatibilidad MVC:** No invoca `whiptail` ni realiza impresiones con formato ANSI decorativo. Los controladores consumirán las funciones capturando su salida o evaluando `$?`.
- **Estructura del Proyecto:** No altera directorios existentes, crea el componente `lib/models/module_model.sh` y sus pruebas en `tests/test_module_model.sh`.

---

## 3. Estrategia de Verificación y Pruebas Unitarias

La suite `tests/test_module_model.sh` verificará:
- Parseo y carga de módulos válidos (ej. `vscode-standard.conf` y `vscode-sensitive.conf`).
- Rechazo de módulos corruptos (sintaxis errónea, IDs con espacios o caracteres no permitidos).
- Detección de omisión de campos obligatorios (`MODULE_NAME`, `MODULE_TAGS`, `MODULE_PATHS`, etc.).
- Filtrado correcto por etiquetas simples y múltiples.
- Filtrado por `IS_SENSITIVE=true` e `IS_SENSITIVE=false`.
- Detección de rutas existentes vs inexistentes en una jerarquía simulada en `/tmp/`.
- Creación y posterior eliminación de un módulo dinámico.
- Consulta y ampliación del catálogo de etiquetas.
