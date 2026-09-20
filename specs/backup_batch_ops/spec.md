# Especificación de Requerimientos: Operaciones de Backup por Lotes (Batch Ops)

**Módulo:** `lib/models/backup_model.sh` & `lib/controllers/app_controller.sh`  
**Rama:** `dev/feature/backup-batch-ops`  
**Estado:** Propuesta / En Revisión  
**Fecha:** 2026-09-20  

---

## 1. Propósito y Contexto

Durante la verificación End-to-End con la unidad SSD externa real, se constató que la ejecución de respaldos grupales (`--backup-tag <tag>` y `--backup-all`) invocaba funciones orquestadoras en `backup_model.sh` que aún no estaban implementadas:
- `backup_model_run_by_tag`
- `backup_model_run_all`

El propósito de esta especificación es definir formalmente la lógica de negocio para estas dos funciones en `lib/models/backup_model.sh`, garantizando la orquestación atómica, el reporte estructurado de éxito/fallo por cada módulo procesado y la propagación de modificadores de purga (`--purge`, `--no-purge`, `auto`).

Asimismo, se especifica el ajuste en el parseo y formateo de espacio en disco en el controlador `lib/controllers/app_controller.sh` para presentar valores humanos legibles (`SPACE_AVAILABLE` / `SPACE_TOTAL`).

---

## 2. Requerimientos Funcionales

### RF-1: Función `backup_model_run_by_tag`
- **Firma:**
  ```bash
  backup_model_run_by_tag "$tag" "$backup_dir" ["$target_home"] ["$passphrase"] ["$purge_override"] ["$modules_dir"] ["$comp_level"] ["$cipher"]
  ```
- **Entradas:**
  1. `tag`: Nombre de la etiqueta a filtrar (obligatorio).
  2. `backup_dir`: Ruta absoluta al directorio de copias en el almacenamiento externo (obligatorio).
  3. `target_home`: Directorio de usuario a respaldar (opcional, default: `$HOME`).
  4. `passphrase`: Frase de paso GPG (opcional, requerida si algún módulo de la etiqueta es sensible).
  5. `purge_override`: Control de purga post-backup (`auto`, `true`, `false`).
  6. `modules_dir`: Directorio donde residen los archivos `.conf` (opcional, default: `modules.d`).
  7. `comp_level`: Nivel de compresión de `zstd` (opcional, default: `3`).
  8. `cipher`: Algoritmo de cifrado simétrico (opcional, default: `AES256`).
- **Comportamiento:**
  1. Validar que `tag` y `backup_dir` no estén vacíos. Si alguno falta, retornar `BACKUP_ERR_CONFIG` (`1`).
  2. Consultar los módulos que coinciden con la etiqueta mediante `module_model_filter_by_tag "$tag" "$modules_dir"`.
  3. Si no existe ningún módulo con esa etiqueta, retornar `BACKUP_ERR_MODULE` (`3`).
  4. Para cada módulo:
     - Resolver `force_purge` y `no_purge` a partir de `purge_override`.
     - Invocar `backup_model_run`.
     - Emitir por stdout la línea de estado: `BACKUP_SUCCESS=<id>` o `BACKUP_FAILED=<id>`.
  5. Retornar `0` (`BACKUP_OK`) si todos los módulos finalizaron con éxito; retornar `1` (`BACKUP_ERR_GENERAL`) si uno o más módulos fallaron.

---

### RF-2: Función `backup_model_run_all`
- **Firma:**
  ```bash
  backup_model_run_all "$backup_dir" ["$target_home"] ["$passphrase"] ["$purge_override"] ["$modules_dir"] ["$comp_level"] ["$cipher"]
  ```
- **Entradas:**
  1. `backup_dir`: Directorio destino en el SSD (obligatorio).
  2. `target_home`: Directorio base (opcional, default: `$HOME`).
  3. `passphrase`: Frase de paso GPG (opcional, requerida si hay módulos sensibles).
  4. `purge_override`: Control de purga (`auto`, `true`, `false`).
  5. `modules_dir`: Directorio de recetas (opcional, default: `modules.d`).
  6. `comp_level`: Nivel zstd (opcional, default: `3`).
  7. `cipher`: Cifrado GPG (opcional, default: `AES256`).
- **Comportamiento:**
  1. Validar que `backup_dir` esté presente. Si falta, retornar `BACKUP_ERR_CONFIG` (`1`).
  2. Obtener la lista completa de módulos registrados con `module_model_list "$modules_dir"`.
  3. Si no hay módulos registrados, retornar `BACKUP_ERR_MODULE` (`3`).
  4. Procesar secuencialmente cada módulo llamando a `backup_model_run`.
  5. Emitir el reporte acumulado con líneas `BACKUP_SUCCESS=<id>` o `BACKUP_FAILED=<id>`.
  6. Retornar `0` (`BACKUP_OK`) si todos tuvieron éxito, o `1` si alguno falló.

---

### RF-3: Refinamiento de Diagnóstico de Almacenamiento en `app_controller.sh`
- **Comportamiento:**
  - En `controller_handle_device_check`, al procesar la salida de `device_model_validate_storage`, extraer correctamente `SPACE_FREE_HUMAN` y calcular el tamaño total aproximado en gigabytes a partir de `SPACE_TOTAL_KB`.
  - Asegurar que tanto en la TUI (`whiptail`) como en la CLI (`ansi_view`), la línea `ESPACIO DISPONIBLE` muestre valores concretos (ej: `431G de 476G`), evitando campos vacíos.

---

## 3. Códigos de Retorno y Constantes

| Constante | Valor | Significado |
| :--- | :---: | :--- |
| `BACKUP_OK` | `0` | Operación de lote completada exitosamente sin errores. |
| `BACKUP_ERR_CONFIG` | `1` | Parámetros obligatorios ausentes o corruptos. |
| `BACKUP_ERR_MODULE` | `3` | Etiqueta no encontrada o catálogo de módulos vacío. |
| `BACKUP_ERR_PASSPHRASE` | `4` | Contraseña no suministrada para módulos sensibles. |
| `BACKUP_ERR_GENERAL` | `1` | Al menos uno de los módulos del lote falló. |

---

## 4. Casos Borde
- Etiqueta inexistente -> Retorna `3` sin crear carpetas ni procesar nada.
- Módulos mixtos (algunos con rutas existentes y otros sin rutas) -> Los que tengan rutas se respaldan con `BACKUP_SUCCESS`; los que no tengan rutas reportan `BACKUP_SKIPPED` o `BACKUP_FAILED`.
- Flag `--no-purge` en lote con módulos sensibles -> Se respeta la bandera y ninguno de los módulos se purga en origen.
