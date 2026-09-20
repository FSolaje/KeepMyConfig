# Plan Técnico de Implementación: `storage-target-init` y Almacenamiento Universal (`LOCAL_PATH`)

**Módulo:** `lib/models/device_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/storage-target-init`  
**Fecha:** 2026-09-20  

---

## 1. Arquitectura y Componentes

### 1.1 Modelo de Almacenamiento (`lib/models/device_model.sh`)
- Extender la resolución de puntos de montaje para admitir `STORAGE_ID_TYPE="LOCAL_PATH"`.
- Condicionar la verificación de partición montada (`device_model_is_mounted`) a que el tipo no sea `LOCAL_PATH`.
- Implementar la lógica de negocio para:
  - Inicializar destinos de equipo (`device_model_init_target_directory`).
  - Buscar y listar destinos con marcador (`device_model_list_targets`).
  - Modificar atómicamente la directiva `STORAGE_SUBDIR` en `config.conf` (`device_model_update_config_subdir`).

### 1.2 Controlador y CLI (`lib/controllers/app_controller.sh`)
- Gestión de variable `TARGET_SUBDIR_OVERRIDE`: Si se pasa `--target-subdir <subdir>`, `_controller_get_backup_dir` reescribe la ruta de destino al vuelo sin tocar el archivo de configuración.
- Implementación de los manejadores:
  - `controller_handle_init_target()`
  - `controller_handle_list_targets()`
  - `controller_handle_device_check()` renovado con menú conversacional en TUI.

---

## 2. Plan de Modificaciones Detallado

### En `lib/models/device_model.sh`:
```bash
# Resolución de LOCAL_PATH
"LOCAL_PATH")
    if [[ -n "$id_value" ]]; then
        mkdir -p "$id_value" 2>/dev/null || true
        if [[ -d "$id_value" ]]; then
            echo "$id_value"
            return "$DEV_OK"
        fi
    fi
    return "$DEV_ERR_NOT_FOUND"
    ;;
```

```bash
# En device_model_validate_storage:
if [[ "$id_type" != "LOCAL_PATH" ]]; then
    if ! device_model_is_mounted "$mountpoint"; then
        ...
        return "$DEV_ERR_NOT_MOUNTED"
    fi
fi
```

### En `lib/controllers/app_controller.sh`:
- Soporte para argumentos `--init-target`, `--set-default`, `--target-subdir`, `--list-targets`.
- En TUI Opción 8: Diálogo `whiptail_view_menu` con:
  - `1`: Ver estado y espacio libre.
  - `2`: Listar carpetas de equipo.
  - `3`: Conmutar carpeta activa.
  - `4`: Inicializar nuevo equipo / subcarpeta.

---

## 3. Plan de Verificación y Pruebas

1. **Pruebas Unitarias de `device_model.sh`:**
   - Test de inicialización de directorio de destino y despliegue del marcador.
   - Test de listado de destinos (`device_model_list_targets`).
   - Test de validación con `LOCAL_PATH`.
   - Test de actualización atómica de `STORAGE_SUBDIR`.
2. **Pruebas de Controlador:**
   - Test de argumentos CLI `--init-target` y `--list-targets`.
3. **Escáner SAST Pre-Commit:**
   - `bash user_data/security_check/scripts/security_check.sh --all`
4. **Prueba en Vivo sobre SSD:**
   - Inicializar `Backups/Personal_PC`.
   - Listar destinos y verificar que `Backups/Lliurex25` y `Backups/Personal_PC` coexisten.
