# Especificación Técnica (SDD): module_model

**Rama:** `dev/feature/module-model`  
**Componente:** `lib/models/module_model.sh`  
**Capa MVC:** Modelo de Negocio (Gestión de Recetas Modulares)  
**Entorno:** Lliurex 25 / Ubuntu 24.04 (Bash 5.0+, sin privilegios `sudo`)

---

## 1. Visión y Requerimientos Funcionales

El modelo `module_model.sh` es el responsable exclusivo de la lógica de negocio para la lectura, validación sintáctica, filtrado y manipulación (CRUD) de las recetas de respaldo almacenadas en `modules.d/*.conf`.

### Requerimientos Funcionales:
1. **Lectura y Parsing Seguro:**
   - Cargar recetas `.conf` de forma aislada en subshells para evitar contaminación de variables en el entorno principal.
   - Rechazar archivos malformados o con sintaxis inválida de Bash.
2. **Validación de Campos Obligatorios:**
   - `MODULE_ID`: Alfanumérico con guiones medios y bajos (`^[a-zA-Z0-9_-]+$`), sin espacios. Debe coincidir con el nombre de archivo `<MODULE_ID>.conf`.
   - `MODULE_NAME`: Cadena de texto no vacía descriptiva.
   - `MODULE_TAGS`: Array indexado con al menos una etiqueta.
   - `MODULE_PATHS`: Array indexado con al menos una ruta relativa.
   - `IS_SENSITIVE`: Booleano estricto (`true` o `false`).
   - `PURGE_AFTER_BACKUP`: Booleano estricto (`true` o `false`).
   - `POST_RESTORE_HOOK`: Cadena opcional.
3. **Consultas y Filtrado:**
   - Listar todos los IDs de módulos válidos disponibles.
   - Filtrar módulos por etiqueta (`tag`).
   - Filtrar módulos por clasificación de sensibilidad (`IS_SENSITIVE=true/false`).
   - Comprobación de rutas locales existentes vs inexistentes para un módulo en `$TARGET_USER_HOME`.
4. **CRUD de Módulos y Catálogo de Etiquetas:**
   - Creación atómica de archivos `.conf`.
   - Eliminación de módulos existentes.
   - Lectura y registro de nuevas etiquetas en `config/default_tags.conf`.
5. **Aislamiento MVC:**
   - Cero interfaces gráficas o diálogos `whiptail`.
   - Comunicación exclusiva vía códigos numéricos de retorno y salida estructurada en `stdout`.

---

## 2. Definición de Entradas, Salidas y Códigos de Error

### Códigos de Retorno Estandarizados:
- `MOD_OK=0`: Operación exitosa.
- `MOD_ERR_CONFIG=1`: Argumentos insuficientes o inválidos.
- `MOD_ERR_NOT_FOUND=2`: Módulo o archivo no encontrado.
- `MOD_ERR_INVALID_ID=3`: ID de módulo con formato no permitido o disconforme con el archivo.
- `MOD_ERR_SYNTAX=4`: Archivo `.conf` contiene errores de sintaxis Bash o ejecución inválida.
- `MOD_ERR_MISSING_FIELD=5`: Falta un campo obligatorio o formato de tipo incorrecto (ej. no es array o booleano).
- `MOD_ERR_ALREADY_EXISTS=6`: Intento de crear un módulo con un ID ya existente.
- `MOD_ERR_IO=7`: Error de lectura/escritura en el sistema de archivos.

---

## 3. Casos Borde (Edge Cases) y Mitigaciones

1. **Inyección de código en `.conf`:** El parseo de los archivos debe ejecutarse en una subshell con verificación previa de sintaxis (`bash -n "$file"`).
2. **Espacios y caracteres extraños en IDs:** Validación estricta con regex antes de cualquier operación sobre el disco.
3. **Módulo sin rutas existentes en el sistema local:** La función `module_model_check_paths` debe clasificar y retornar qué rutas existen y cuáles faltan, sin romper el flujo de backup para permitir respaldos parciales.
4. **Archivos ocultos o temporales en `modules.d/`:** Ignorar ficheros que no terminen estrictamente en `.conf` (ej. `.gitkeep`, `*~`, `*.bak`).
