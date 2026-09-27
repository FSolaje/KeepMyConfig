# Especificación de Corrección: Validación Jerárquica de Marcador y Sanitización de Destinos (`storage_marker_hierarchy_fix`)

**Rama:** `dev/feature/backup-profiles`  
**Tipo:** Fix de Lógica y Rutas de Almacenamiento  
**Fecha:** 2026-09-21  

---

## 1. Descripción del Problema y Contexto

Al configurar perfiles de backup con destinos específicos (`TARGET_SUBDIR` en `profile.conf`) o modificar `STORAGE_SUBDIR` en `config.conf`, los usuarios experimentan bloqueos técnicos con el error:
```text
[ERROR] No se detectó el SSD externo de backup o falta el archivo marcador .backup_storage_marker.
```

### Causas Raíz Identificadas:
1. **Validación Rígida de Marcador:** `device_model_validate_storage` solo comprueba `$backup_dir/.backup_storage_marker` y `$mountpoint/.backup_storage_marker`. Si un perfil define un subdirectorio nuevo (ej. `Backup/test`), la carpeta no existe aún en el medio de almacenamiento y el sistema aborta antes de que el controlador pueda crearla. Si el medio de almacenamiento ya contiene marcadores válidos en otros subdirectorios (ej. `Backups/Lliurex25`), el medio es 100% legítimo pero es rechazado indebidamente.
2. **Falta de Sanitización en Rutas de Almacenamiento:** Cuando el usuario ingresa `$HOME/TEST_Backups` o `~/...` en `STORAGE_SUBDIR`, no se sanitizan los prefijos. Esto ocasiona que se creen carpetas físicas con el nombre literal `'$HOME'` dentro del punto de montaje del SSD o se generen rutas concatenadas inválidas (`/media/...//home/usuario/...`).

---

## 2. Requerimientos Funcionales (FR)

### FR-FIX-001: Validación Jerárquica de Marcador de Seguridad
- El modelo `device_model_validate_storage` debe considerar válido el almacenamiento si:
  1. Existe `.backup_storage_marker` dentro de `backup_dir`.
  2. O existe `.backup_storage_marker` en la raíz del punto de montaje (`mountpoint`).
  3. O existe al menos un marcador `.backup_storage_marker` en cualquier subdirectorio existente dentro de `mountpoint` (demostrando que el disco ya ha sido inicializado para KeepMyConfig).
- Si el medio es verificado mediante (2) o (3), y el medio es escribible:
  - El sistema debe auto-crear la subcarpeta `backup_dir` (`mkdir -p "$backup_dir"`).
  - El sistema debe desplegar el marcador `.backup_storage_marker` en `backup_dir` y asegurar que exista en `mountpoint` para validar futuras operaciones.

### FR-FIX-002: Auto-Creación Transparente de Carpetas de Perfil
- Cuando se ejecuta una operación de respaldo bajo un perfil que define un `TARGET_SUBDIR` no creado físicamente en el SSD, el sistema no debe fallar con error de marcador faltante si el disco base está validado.
- Debe crear la carpeta de destino de forma atómica y transparente, permitiendo que el backup continúe con éxito.

### FR-FIX-003: Sanitización Obligatoria de `STORAGE_SUBDIR`
- Incorporar `device_model_sanitize_subdir` en `lib/models/device_model.sh`.
- Normalizar cualquier valor de subdirectorio ingresado en `STORAGE_SUBDIR` o `TARGET_SUBDIR`, eliminando:
  - Prefijos `$HOME`, `${HOME}`, `~`, `/home/<user>/`.
  - Barras iniciales (`/`) y finales redundantes.
  - Bloquear intentos de navegación (`..`).
- Aplicar esta sanitización en `device_model_validate_storage`, `device_model_update_config_subdir` y en los asistentes de controlador (`controller_handle_init_target`).

---

## 3. Criterios de Aceptación

1. Crear un perfil con un `TARGET_SUBDIR` nuevo (ej. `Backup/test`) y ejecutar `--backup-all` debe auto-crear el subdirectorio en el SSD y completar el backup exitosamente sin error de marcador.
2. Configurar `STORAGE_SUBDIR="$HOME/TEST_Backups"` debe ser sanitizado a `TEST_Backups` sin crear carpetas físicas literales con el símbolo dólar `'$HOME'`.
3. Todas las suites de pruebas unitarias existentes (318 tests) deben continuar pasando al 100%.
4. Pruebas unitarias nuevas deben verificar la validación jerárquica y la auto-creación de carpetas de perfil.
