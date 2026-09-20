# Especificación de Requerimientos: Corrección del Asistente de Creación de Módulos (TUI)

**Módulo:** `lib/controllers/app_controller.sh` & `lib/models/module_model.sh`  
**Rama:** `dev/fix/module-admin-wizard`  
**Fecha:** 2026-09-20  
**Estado:** Propuesta para Aprobación  

---

## 1. Descripción del Problema

Al intentar crear un módulo nuevo desde la TUI (Opción 7: *Administrar Módulos y Etiquetas* -> Opción 2: *Crear un nuevo módulo*), el asistente solicita correctamente los datos del usuario:
1. ID único (ej: `test-cualquiera`)
2. Nombre descriptivo (ej: `cualquier módulo.`)
3. Rutas relativas a `$HOME` separadas por espacio (ej: `Documentos/Pruebas_Macros`)
4. Selección de etiquetas mediante checklist (ej: `sensitive`)
5. Indicador de datos sensibles (`true` o `false`)
6. Indicador de purga segura tras respaldo (`true` o `false`)

Sin embargo, la invocación de guardado fallaba inmediatamente con:
```text
"Fallo de Creación: No se pudo crear el archivo del módulo."
```

### Causa Raíz
En `lib/controllers/app_controller.sh` (línea 868), la llamada a la función del modelo era:
```bash
module_model_save "$mod_id" "$mod_name" "$is_sens" "$purge_val" "" paths_arr tags_arr
```
La signatura real de `module_model_save` en `lib/models/module_model.sh` es:
```bash
module_model_save "$mod_id" "$name" "$tags_str" "$paths_str" "$is_sensitive" "$purge_after" "$hook" "$modules_dir"
```
Debido a esta discrepancia:
1. El parámetro 3 (`$tags_str`) recibía el valor booleano `$is_sens` ("true").
2. El parámetro 4 (`$paths_str`) recibía el booleano `$purge_val` ("true").
3. El parámetro 5 (`$is_sensitive`) recibía la cadena vacía `""`.
4. La validación `[[ "$is_sensitive" =~ ^(true|false)$ ]]` fallaba retornando código de error 1 (`MOD_ERR_CONFIG`), abortando la creación.
5. Los nombres de los arrays `paths_arr` y `tags_arr` se pasaban como literales sin expandir ni unir con sus delimitadores correspondientes (`|` y `,`).

---

## 2. Requerimientos Funcionales

### RF-1: Alineación de Parámetros en el Controlador (`app_controller.sh`)
- En `controller_handle_modules_admin`:
  1. Convertir `paths_arr` a una cadena unida por pipes `|`, admitiendo múltiples rutas relativas introducidas por el usuario.
  2. Convertir `tags_arr` a una cadena unida por comas `,`. Si no se seleccionó ninguna etiqueta, asignar `dev` por defecto.
  3. Invocar a `module_model_save` con los 8 parámetros en el orden exacto:
     ```bash
     module_model_save "$mod_id" "$mod_name" "$tags_joined" "$paths_joined" "$is_sens" "$purge_val" "" "$MODULES_DIR"
     ```
  4. Si la creación tiene éxito, mostrar el mensaje informativo con la ruta del archivo generado `${MODULES_DIR}/${mod_id}.conf`.
  5. Si falla, emitir el diálogo de error correspondiente.

### RF-2: Robustez en `module_model_save` (`module_model.sh`)
- En `lib/models/module_model.sh`:
  - Permitir que `$tags_str` acepte etiquetas separadas por comas `,` o por espacios en blanco, permitiendo flexibilidad total entre entradas CLI y retornos de `whiptail --checklist`.

---

## 3. Criterios de Aceptación

1. Crear un módulo desde la TUI con ID `test-cualquiera`, descripción `cualquier módulo.`, rutas `Documentos/Pruebas_Macros`, etiqueta `sensitive`, sensible `true` y auto-purga `true` genera exitosamente el archivo `modules.d/test-cualquiera.conf`.
2. El archivo generado tiene sintaxis bash 100% válida y define correctamente todas las variables:
   - `MODULE_ID="test-cualquiera"`
   - `MODULE_NAME="cualquier módulo."`
   - `MODULE_TAGS=("sensitive")`
   - `MODULE_PATHS=("Documentos/Pruebas_Macros")`
   - `IS_SENSITIVE=true`
   - `PURGE_AFTER_BACKUP=true`
   - `POST_RESTORE_HOOK=""`
3. Todas las suites de pruebas pasan al 100% sin regresiones.
