# Plan Técnico Arquitectónico: Validación Jerárquica de Marcador y Sanitización de Destinos (`storage_marker_hierarchy_fix`)

**Rama:** `dev/feature/backup-profiles`  
**Tipo:** Fix Técnico Arquitectónico  
**Fecha:** 2026-09-21  

---

## 1. Arquitectura de Cambios

### 1.1 Modelo `device_model.sh`
- **Nueva función `device_model_sanitize_subdir`:**
  - Limpia prefijos `$HOME`, `~`, `/home/<usuario>`.
  - Normaliza barras iniciales y finales.
  - Bloquea traversal (`..`).
- **Modificación de `device_model_validate_storage`:**
  - Sanitiza el parámetro `subdir` antes de resolver `backup_dir`.
  - Comprobación jerárquica de marcador:
    1. Si `backup_dir` tiene marcador -> válido.
    2. Si `mountpoint` tiene marcador -> válido; auto-crea `backup_dir` y le copia el marcador si es escribible.
    3. Si `device_model_list_targets "$mountpoint"` encuentra al menos un destino con marcador -> el medio está verificado como unidad de backup. Se auto-despliega el marcador en `mountpoint` y se auto-crea `backup_dir` con su marcador.
- **Modificación de `device_model_update_config_subdir`:**
  - Aplica `device_model_sanitize_subdir` antes de escribir en `config.conf`.

### 1.2 Controlador `app_controller.sh`
- **Modificación de `controller_handle_init_target`:**
  - Sanitiza la subcarpeta ingresada antes de inicializarla.

### 1.3 Suite de Pruebas
- Añadir pruebas unitarias en `tests/test_device_model.sh`:
  - `device_model_sanitize_subdir` con `$HOME`, `~`, barras y `..`.
  - `device_model_validate_storage` auto-creando `backup_dir` cuando el medio contiene marcadores en otros subdirectorios.

---

## 2. Walkthrough de Impacto

- **Compatibilidad hacia atrás:** 100% compatible con los destinos existentes (`Backups/Lliurex25`, `Backups/Personal_PC`).
- **Seguridad:** Mantiene la protección estricta contra unidades no montadas o desconectadas (si el disco no está montado, la validación falla inmediatamente).
- **Experiencia de Usuario:** Elimina la necesidad de ejecutar `--init-target` manual al crear un nuevo perfil de backup.
