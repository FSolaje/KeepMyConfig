# Plan Técnico de Implementación: Operaciones de Backup por Lotes (Batch Ops)

**Módulo:** `lib/models/backup_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-batch-ops`  
**Estado:** Propuesta de Planificación  
**Fecha:** 2026-09-20  

---

## 1. Arquitectura y Diseño Técnico

El diseño sigue el patrón ya establecido y probado en `lib/models/restore_model.sh` para operaciones colectivas:
- Las funciones de modelo operan sin interactividad de usuario (`whiptail` o `read`), recibiendo argumentos posicionales y emitiendo pares clave-valor por `stdout`.
- Se desacopla la obtención de la lista de módulos (`module_model_filter_by_tag` o `module_model_list`) de la ejecución individual de cada copia (`backup_model_run`).
- Se mantiene el principio de aislamiento en subshell o ejecución defensiva para que el fallo en un módulo no aborte prematuramente el procesamiento de los demás módulos del lote.

---

## 2. Modificaciones Propuestas

### 2.1 `lib/models/backup_model.sh`
- **Añadir `backup_model_run_by_tag()`:**
  - Argumentos: `tag`, `backup_dir`, `target_home`, `passphrase`, `purge_override`, `modules_dir`, `comp_level`, `cipher`.
  - Obtener lista de módulos con `module_model_filter_by_tag "$tag" "$modules_dir"`.
  - Validar lista vacía retornando `BACKUP_ERR_MODULE` (`3`).
  - Traducir `purge_override` a `force_purge` y `no_purge`.
  - Iterar y ejecutar `backup_model_run` para cada módulo.
  - Acumular reporte de salida (`BACKUP_SUCCESS` / `BACKUP_FAILED`) y retornar código de éxito o error compuesto.

- **Añadir `backup_model_run_all()`:**
  - Argumentos: `backup_dir`, `target_home`, `passphrase`, `purge_override`, `modules_dir`, `comp_level`, `cipher`.
  - Obtener lista con `module_model_list "$modules_dir"`.
  - Traducir `purge_override`.
  - Iterar y ejecutar `backup_model_run`.
  - Acumular reporte y retornar estado.

### 2.2 `lib/controllers/app_controller.sh`
- En `controller_handle_device_check`:
  - Al procesar `val_out`, buscar tanto `SPACE_AVAILABLE` como `SPACE_FREE_HUMAN` para `space_avail`.
  - Para `space_total`, si no viene directo como `SPACE_TOTAL`, calcularlo a partir de `SPACE_TOTAL_KB` dividiendo por $1024^2$ para obtener gigabytes con sufijo `G`.
  - Evitar que en pantallas TUI o CLI se muestren etiquetas de espacio vacías.

### 2.3 `tests/test_backup_model.sh`
- Añadir casos de prueba unitaria:
  - `backup_model_run_by_tag` en etiqueta inexistente (debe retornar `BACKUP_ERR_MODULE`).
  - `backup_model_run_by_tag` con etiqueta válida respaldando múltiples módulos.
  - `backup_model_run_all` procesando todos los módulos del sandbox de prueba.

---

## 3. Plan de Verificación

1. **Pruebas Unitarias de Modelos:**
   ```bash
   bash tests/test_backup_model.sh
   ```
2. **Pruebas de Toda la Suite:**
   Ejecutar los 8 suites de prueba para comprobar regresiones.
3. **Escáner SAST Pre-Commit:**
   ```bash
   bash user_data/security_check/scripts/security_check.sh --all
   ```
4. **Verificación en Vivo con SSD:**
   - Probar `./backup_manager.sh --backup-tag standard`
   - Probar `./backup_manager.sh --check-device`
