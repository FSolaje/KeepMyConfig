# Especificación de Requerimientos: Sistema de Perfiles de Backup (`backup-profiles`)

**Módulo:** `lib/models/profile_model.sh`, `lib/models/module_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Propósito y Alcance

El objetivo de esta especificación es dotar a **KeepMyConfig** de un sistema modular de **Perfiles de Backup** (*Backup Profiles & Scoped Modules*). Esta funcionalidad resuelve la necesidad de adaptar el gestor a múltiples estaciones de trabajo, entornos de desarrollo, aulas docentes o máquinas personales mediante:
1. **Aislamiento y Selección de Entorno:** Capacidad de definir perfiles independientes (ej. `personal`, `docente-aula`, `dev-laptop`, `default`).
2. **Jerarquía y Resolución en Cascada de Recetas:**
   - Módulos globales en `modules.d/` compartidos por todos los entornos.
   - Módulos específicos en `profiles/<perfil>/modules.d/` con capacidad de:
     - **Sobrescritura (*Override*):** Si un perfil define un módulo con el mismo ID que uno global (ej. `vscode-standard.conf`), se ejecuta la versión del perfil.
     - **Módulos Exclusivos:** Módulos que solo tienen sentido en un perfil no son visibles ni ejecutados por perfiles ajenos.
3. **Vinculación Perfil-Destino:** Posibilidad de asociar a cada perfil su propia carpeta de almacenamiento (`TARGET_SUBDIR`), automatizando la separación de copias en el dispositivo de almacenamiento.
4. **Soporte Completo TUI y CLI:** Selección interactiva del perfil activo en menú Whiptail y conmutación ágil por parámetro `--profile <id>` en línea de comandos.
5. **Unificación de Identidad (`KeepMyConfig`):** Actualización homogénea de títulos, banners y cabeceras de la aplicación.

---

## 2. Requerimientos Funcionales

### RF-1: Estructura de Directorios de Perfiles
- Los perfiles se almacenan en el directorio `profiles/` dentro de la raíz de la aplicación (configurable mediante la variable `PROFILES_DIR`).
- Cada perfil es un directorio con la siguiente estructura:
  ```text
  profiles/
  └── <profile_id>/
      ├── profile.conf
      └── modules.d/
          ├── <modulo_exclusivo>.conf
          └── <modulo_override>.conf
  ```
- **Fichero de configuración `profile.conf`:**
  ```bash
  PROFILE_ID="personal"
  PROFILE_NAME="Portátil Personal"
  PROFILE_DESCRIPTION="Configuraciones específicas del entorno doméstico"
  TARGET_SUBDIR="Backups/Personal_PC"
  ```

---

### RF-2: Identificadores de Perfil Válidos
- Un identificador de perfil (`profile_id`) debe cumplir la expresión regular `^[a-zA-Z0-9_-]+$`.
- El identificador especial `default` representa el entorno estándar global (sin módulos específicos de perfil).

---

### RF-3: Persistencia del Perfil Activo
- En `config/config.conf` se almacena la directiva:
  ```bash
  ACTIVE_PROFILE="default"
  ```
- Si `ACTIVE_PROFILE` no está definido, está vacío o apunta a un perfil inexistente, el sistema opera en modo `default`.
- Precedencia en tiempo de ejecución:
  `Flag CLI (--profile <id>)` > `Variable de entorno ACTIVE_PROFILE` > `config/config.conf`.

---

### RF-4: Resolución en Cascada de Módulos (Cascade Resolution)
Dada una petición para obtener un módulo por su `module_id`:
1. Si el perfil activo es distinto de `default` y existe el archivo:
   `profiles/<perfil_activo>/modules.d/<module_id>.conf`
   se carga dicho archivo (caso de **Override** o **Módulo Exclusivo**).
2. En caso contrario, si existe:
   `modules.d/<module_id>.conf`
   se carga dicho archivo global.
3. Si no existe en ninguna de las dos ubicaciones, se retorna código de error `MOD_ERR_NOT_FOUND` (2).

---

### RF-5: Consolidación y Deduplicación del Catálogo de Módulos
Al listar los módulos disponibles para el perfil activo (`profile_model_list_modules`):
1. Se recopilan todos los IDs válidos en `modules.d/*.conf`.
2. Se recopilan todos los IDs válidos en `profiles/<perfil_activo>/modules.d/*.conf`.
3. Se unifican las listas eliminando duplicados (los módulos sobrescritos por el perfil aparecen una sola vez).
4. La salida se emite ordenada alfabéticamente por ID.
5. Los módulos exclusivos de otros perfiles permanecen estrictamente invisibles.

---

### RF-6: Vinculación Automática Perfil-Destino
- Al resolver el destino de respaldo en el dispositivo de almacenamiento:
  - Si el perfil activo define `TARGET_SUBDIR` (y no está vacío), se utilizará este valor como subcarpeta de destino.
  - Si el perfil no define `TARGET_SUBDIR` o está vacío, se recurre a `STORAGE_SUBDIR` de `config/config.conf`.
  - Si se pasa el flag `--target-subdir <ruta>` por CLI, este flag tiene **máxima prioridad** y sobrescribe cualquier valor previo.

---

### RF-7: Funciones del Modelo `profile_model.sh`

| Función | Parámetros | Salida / Retorno | Descripción |
| :--- | :--- | :--- | :--- |
| `profile_model_validate_id` | `$profile_id` | Retorna `0` o `PROFILE_ERR_INVALID_ID` | Valida alfanumérico seguro (`^[a-zA-Z0-9_-]+$`). |
| `profile_model_list` | `["$profiles_dir"]` | stdout: lista de IDs; Retorna `0` | Lista perfiles válidos detectados en `profiles/`. |
| `profile_model_get` | `$profile_id ["$profiles_dir"]` | stdout: `CLAVE=VALOR`; Retorna `0` / error | Parsea y valida `profile.conf` en subshell aislada. |
| `profile_model_create` | `$id $name $desc $target_subdir` | Retorna `0` / error | Crea carpeta del perfil, `profile.conf` y `modules.d/`. |
| `profile_model_delete` | `$profile_id` | Retorna `0` / error | Elimina un perfil (prohíbe eliminar `default` o el activo). |
| `profile_model_resolve_module` | `$mod_id $active_profile` | stdout: ruta al `.conf`; Retorna `0` / 2 | Aplica la jerarquía de cascada para ubicar el archivo. |
| `profile_model_list_modules` | `$active_profile` | stdout: lista de IDs unificada; Retorna `0` | Lista consolidada y deduplicada de módulos visibles. |
| `profile_model_get_active` | `["$config_file"]` | stdout: ID del perfil activo; Retorna `0` | Lee `ACTIVE_PROFILE` de configuración. |
| `profile_model_set_active` | `$profile_id ["$config_file"]` | Retorna `0` / error | Actualiza `ACTIVE_PROFILE` atómicamente en `config.conf`. |

---

### RF-8: Interfaz de Línea de Comandos (CLI Headless)
Nuevos flags en `backup_manager.sh`:
- `--profile <id>`: Ejecuta la acción actual bajo el contexto del perfil indicado (sin modificar la configuración permanente).
- `--list-profiles`: Lista los perfiles existentes e indica con un asterisco o marcador cuál es el activo.
- `--set-active-profile <id>`: Establece y persiste el perfil activo en `config/config.conf`.
- `--create-profile <id> [nombre] [descripcion] [target_subdir]`: Crea un nuevo perfil.

---

### RF-9: Interfaz Gráfica de Terminal (TUI Whiptail)
- **Visualización del Perfil Activo:** El banner superior de `whiptail` y el menú principal muestran de forma visible el perfil en uso:
  `KeepMyConfig v0.1.0-alpha.1 [Perfil: Personal]`
- **Submenú "Gestión de Perfiles" (Opción 9 en TUI):**
  1. `Ver perfil activo y detalles`: Muestra nombre, descripción, destino y módulos asociados.
  2. `Cambiar perfil activo`: Radiolist de perfiles disponibles.
  3. `Crear nuevo perfil`: Asistente paso a paso para definir ID, nombre, descripción y destino.
  4. `Listar recetas del perfil activo`: Muestra los módulos indicando procedencia `[Global]`, `[Override]` o `[Exclusivo]`.

---

### RF-10: Unificación de Identidad `KeepMyConfig`
- Sustitución exhaustiva de cadenas `BackupConfig` por `KeepMyConfig` en:
  - `backup_manager.sh`
  - `lib/views/ansi_view.sh` (título por defecto en cabeceras)
  - `lib/views/whiptail_view.sh` (títulos de diálogos)
  - `lib/controllers/app_controller.sh` (textos de ayuda y cabeceras)
  - `config/config.conf` (comentarios de encabezado)
  - `MANUAL_USUARIO.md` y `README.md`

---

## 3. Casos Borde y Manejo de Errores

1. **Perfil activo no existe:** Si `ACTIVE_PROFILE` en `config.conf` apunta a una carpeta que fue borrada o no existe, el sistema emite un aviso no bloqueante y conmuta automáticamente a `default`.
2. **Conflicto de módulos globales y de perfil:** Si un módulo tiene el mismo ID en `modules.d/` y en `profiles/<perfil>/modules.d/`, el perfil **siempre tiene prioridad**, permitiendo especializar paths, scripts post-restore o directivas de purga para ese equipo concreto.
3. **Módulos con errores sintácticos en el perfil:** Si el módulo de override contiene un error de sintaxis, se reporta `MOD_ERR_SYNTAX` y no se recurre silenciosamente al global para evitar comportamientos inesperados de respaldo.
4. **Destino vacío:** Si ni el perfil ni `config.conf` definen subcarpeta (`TARGET_SUBDIR=""` y `STORAGE_SUBDIR=""`), la copia se realiza directamente en la raíz de la unidad de almacenamiento tras validar el marcador.
