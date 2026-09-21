# Plan Técnico y Arquitectónico: Sistema de Perfiles de Backup (`backup-profiles`)

**Módulo:** `lib/models/profile_model.sh`, `lib/models/module_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Arquitectura Técnica y Patrón MVC

El sistema de perfiles se implementa respetando la separación estricta de responsabilidades del patrón MVC en Bash:

```
┌─────────────────────────────────────────────────────────────┐
│                      app_controller.sh                      │
│   (Resuelve perfil activo, CLI flags, enrutamiento TUI/CLI) │
└──────────────┬───────────────────────────────┬──────────────┘
               │                               │
       ┌───────▼──────────────┐        ┌───────▼──────────────┐
       │   profile_model.sh   │        │   whiptail_view.sh   │
       │ (CRUD, cascada, paths)│        │   ansi_view.sh       │
       └───────┬──────────────┘        │ (Diálogos y menús)   │
               │                       └──────────────────────┘
       ┌───────▼──────────────┐
       │   module_model.sh    │
       │ (Parser y validación)│
       └──────────────────────┘
```

1. **Modelo `profile_model.sh`:**
   - Lógica pura de negocio para escaneo, validación y gestión de perfiles.
   - Sin dependencias de UI ni llamadas a `whiptail` o `echo` decorativos.
   - Comunica resultados mediante variables estructuradas `CLAVE=VALOR` por stdout y códigos numéricos de retorno.
2. **Modelo `module_model.sh`:**
   - Se adapta para permitir recibir una ruta de archivo `.conf` arbitraria o trabajar en conjunto con la resolución en cascada de `profile_model.sh`.
3. **Controlador `app_controller.sh`:**
   - Gestiona el estado de la sesión: `CONTROLLER_ACTIVE_PROFILE`.
   - Consulta `profile_model_list_modules` para poblar listas y menús.
   - Inyecta el `TARGET_SUBDIR` del perfil en la resolución de destino de almacenamiento.
4. **Vistas `whiptail_view.sh` y `ansi_view.sh`:**
   - Nuevos diálogos para visualización y selección de perfiles.
   - Formateo del contexto de perfil en la barra de estado y encabezados.

---

## 2. Definición Técnica de Funciones en `profile_model.sh`

```bash
# Códigos de retorno estandarizados
export PROFILE_OK=0
export PROFILE_ERR_PARAM=1
export PROFILE_ERR_NOT_FOUND=2
export PROFILE_ERR_ALREADY_EXISTS=3
export PROFILE_ERR_INVALID_ID=4
export PROFILE_ERR_IO=5

# Directorio base de perfiles por defecto
_PROFILE_MODEL_DEFAULT_DIR="${PROFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../profiles" 2>/dev/null && pwd)}"
```

### Funciones Principales:

1. **`profile_model_validate_id "$profile_id"`:**
   - Comprueba que `$profile_id` no esté vacío y cumpla `^[a-zA-Z0-9_-]+$`.
2. **`profile_model_list ["$profiles_dir"]`:**
   - Itera sobre los subdirectorios de `$profiles_dir`.
   - Verifica si contienen `profile.conf`.
   - Siempre incluye `default` en la lista si no existe aún en disco.
3. **`profile_model_get "$profile_id" ["$profiles_dir"]`:**
   - Si `$profile_id == "default"`, emite metadatos por defecto (`ID=default`, `NAME="Perfil por Defecto"`, `DESCRIPTION="Módulos globales sin personalización"`, `TARGET_SUBDIR=""`).
   - Para otros perfiles, comprueba que exista `$profiles_dir/$profile_id/profile.conf`.
   - Parsea en subshell segura y emite: `ID`, `NAME`, `DESCRIPTION`, `TARGET_SUBDIR`.
4. **`profile_model_create "$profile_id" "$name" "$description" "$target_subdir" ["$profiles_dir"]`:**
   - Valida el ID.
   - Crea `$profiles_dir/$profile_id/modules.d/`.
   - Genera `$profiles_dir/$profile_id/profile.conf` con permisos adecuados.
5. **`profile_model_delete "$profile_id" ["$profiles_dir"]`:**
   - Prohíbe borrar `default`.
   - Elimina recursivamente el directorio del perfil.
6. **`profile_model_resolve_module "$module_id" "$active_profile" ["$base_dir"]`:**
   - Verifica en cascada:
     1. Si `$active_profile` no es `default` y existe `$base_dir/profiles/$active_profile/modules.d/$module_id.conf` ➔ Retorna esa ruta.
     2. Si existe `$base_dir/modules.d/$module_id.conf` ➔ Retorna esa ruta.
     3. Si no ➔ Retorna código `2` (`PROFILE_ERR_NOT_FOUND`).
7. **`profile_model_list_modules "$active_profile" ["$base_dir"]`:**
   - Recopila nombres base de `.conf` de `modules.d/` y de `profiles/$active_profile/modules.d/`.
   - Deduplica y ordena alfabéticamente.
8. **`profile_model_get_active ["$config_file"]`:**
   - Lee `ACTIVE_PROFILE` de `config/config.conf` (default: `default`).
9. **`profile_model_set_active "$profile_id" ["$config_file"]`:**
   - Reemplaza o añade `ACTIVE_PROFILE="<profile_id>"` en `config/config.conf` mediante escritura atómica (fichero temporal + `mv`).

---

## 3. Integración en el Controlador (`app_controller.sh`)

1. **Ciclo de Inicialización (`controller_init`):**
   - Importar `lib/models/profile_model.sh`.
   - Resolver el perfil activo:
     - Si se pasó `--profile <id>` por CLI, tiene prioridad absoluta para la sesión.
     - Si no, leer de `config/config.conf` vía `profile_model_get_active`.
2. **Resolución de Destino de Almacenamiento:**
   - En `_controller_get_backup_dir`:
     - Si no se indicó `--target-subdir` explícito, consultar si el perfil activo define `TARGET_SUBDIR`.
     - Si lo define, aplicar como subcarpeta de copia.
3. **Operaciones de Backup y Restauración:**
   - Usar `profile_model_list_modules` para operaciones `--backup-all` y `--restore-all`.
   - Usar `profile_model_resolve_module` antes de invocar `module_model_get` para garantizar que se carga el `.conf` correcto (perfil vs global).
4. **Nuevos Flags CLI:**
   - `--profile <id>`
   - `--list-profiles`
   - `--set-active-profile <id>`
   - `--create-profile <id> [nombre] [descripcion] [target_subdir]`
5. **Submenú TUI (Opción 9):**
   - Menú de gestión de perfiles desacoplado con diálogos de confirmación y selección.

---

## 4. Plan de Pruebas Unitarias (`tests/test_profile_model.sh`)

Se diseñará una suite exhaustiva en sandbox aislado en `/tmp/`:
1. `test_validate_id`: Validación de sintaxis de identificadores válidos e inválidos.
2. `test_default_profile`: Comprobación de metadatos del perfil por defecto `default`.
3. `test_create_and_get_profile`: Creación de un perfil con `profile.conf` y lectura de variables.
4. `test_list_profiles`: Detección correcta de múltiples perfiles.
5. `test_cascade_resolution_global_only`: Módulo que solo existe en `modules.d/`.
6. `test_cascade_resolution_override`: Módulo global sobrescrito por el perfil activo.
7. `test_cascade_resolution_exclusive`: Módulo exclusivo del perfil que no existe en global.
8. `test_cascade_isolation`: Módulo exclusivo del Perfil A no debe ser visible cuando el Perfil B está activo.
9. `test_list_modules_dedup`: Comprobación de que los módulos sobrescritos aparecen exactamente una vez en la lista unificada.
10. `test_set_and_get_active_profile`: Persistencia atómica de `ACTIVE_PROFILE` en `config.conf`.

---

## 5. Walkthrough de Impacto

1. **Retrocompatibilidad 100%:** Si no se crea ningún perfil, `KeepMyConfig` funciona exactamente igual que antes (`ACTIVE_PROFILE="default"` utiliza los módulos globales y el `STORAGE_SUBDIR` de siempre).
2. **Ningún cambio en recetas existentes:** Los módulos existentes en `modules.d/` no requieren modificación.
3. **Aislamiento en entornos de prueba:** Las pruebas unitarias se ejecutan en un sandbox temporal sin modificar el directorio real `profiles/`.
