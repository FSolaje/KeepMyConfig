# Plan Arquitectónico y Técnico: backup_model

**Rama:** `dev/feature/backup-model`  
**Componente:** `lib/models/backup_model.sh`  
**Objetivo:** Implementar el motor de creación de respaldos, cálculo de diferencias históricas y auditoría.

---

## 1. Diseño Arquitectónico de Funciones

Se implementará `lib/models/backup_model.sh` consumiendo `module_model.sh` y `crypto_model.sh`:

1. `backup_model_generate_timestamp`
   - Salida: `AAAAMMDD_HHMMSS` (ej. `20260920_174530`).

2. `backup_model_find_latest_manifest <module_archive_dir>`
   - Busca el archivo `*.manifest.log` con la marca de tiempo más reciente dentro del directorio del módulo.
   - Retorna la ruta completa o vacío si no hay respaldos previos.

3. `backup_model_compute_diff <previous_manifest> <current_manifest>`
   - Extrae los pares `HASH RUTA` de ambos manifiestos.
   - Determina:
     - `+ <ruta>`: presente en el actual y ausente en el previo.
     - `~ <ruta>`: presente en ambos pero con distinto SHA-256.
     - `- <ruta>`: presente en el previo y ausente en el actual.
   - Emite el bloque de diferencias formateado por `stdout`.

4. `backup_model_verify_archive <archive_path> <is_sensitive> [passphrase]`
   - Si `is_sensitive=false`:
     Ejecuta `tar -I 'zstd' -tf "$archive_path" >/dev/null 2>&1`.
   - Si `is_sensitive=true`:
     Invoca `crypto_model_verify_passphrase "$archive_path" "$passphrase"`.
   - Retorna 0 si el archivo es válido y legible.

5. `backup_model_run <module_id> <backup_dir> [target_home] [passphrase] [force_purge] [no_purge] [modules_dir] [compression_level]`
   - Orquestador del modelo:
     1. Obtiene metadatos del módulo (`module_model_get`).
     2. Resuelve rutas presentes con `module_model_check_paths`. Si no hay ninguna, retorna `BACKUP_ERR_NO_FILES`.
     3. Prepara `$backup_dir/archives/$module_id`.
     4. Genera nombre base `<TIMESTAMP>.tar.zst[.gpg]`.
     5. Empaqueta hacia archivo temporal `.tmp`.
     6. Valida integridad del archivo temporal. Si falla, limpia y retorna `BACKUP_ERR_CORRUPT`.
     7. Renombra al archivo definitivo.
     8. Genera el `<TIMESTAMP>.manifest.log` con sumas SHA-256 e inventario.
     9. Computa diffs con el manifiesto previo.
     10. Registra entrada en `$backup_dir/logs/backup_history.log`.
     11. Evalúa política de purga: si `PURGE_AFTER_BACKUP=true` (y no `--no-purge`) o `force_purge=true`, ejecuta `crypto_model_shred_path` en las rutas locales.
     12. Emite diagnóstico estructurado en `stdout` (`STATUS=SUCCESS`, `ARCHIVE=...`, `MANIFEST=...`, `PURGED=true/false`).

6. `backup_model_list_history <module_id> <backup_dir>`
   - Lista todas las marcas de tiempo disponibles para un módulo ordenadas cronológicamente.

---

## 2. Walkthrough de Impacto

- **Uso de memoria y disco:** El cifrado al vuelo mediante descriptor evita escribir un `tar.zst` sin cifrar en `/tmp/`, protegiendo datos sensibles en todo momento.
- **Rendimiento:** `zstd -3` ofrece un balance óptimo entre velocidad y compresión para configuraciones de desarrollo y bases de datos ligeras (`state.vscdb`).
- **Resiliencia:** El uso de archivos temporales `.tmp` garantiza que ante un corte de suministro o desconexión del SSD no queden archivos corruptos marcados como válidos.

---

## 3. Plan de Pruebas Unitarias (`tests/test_backup_model.sh`)

- Generación uniforme de timestamps (`^[0-9]{8}_[0-9]{6}$`).
- Respaldo completo de módulo estándar (`vscode-standard` simulado con archivos reales):
  - Verifica generación de `.tar.zst` y `.manifest.log`.
  - Verifica que el archivo no está cifrado.
  - Verifica que los ficheros locales no se purgan.
- Respaldo de módulo sensible (`vscode-sensitive` simulado):
  - Requiere contraseña. Falla limpiamente si no se suministra.
  - Genera `.tar.zst.gpg` verificable.
  - Verifica que se ejecuta la purga en local con `shred` si `PURGE_AFTER_BACKUP=true`.
- Cálculo de diffs:
  - Segundo backup tras modificar un archivo y agregar otro: verifica que el nuevo manifiesto contiene `+ <nuevo>` y `~ <modificado>`.
- Manejo de módulo sin ficheros locales existentes (`BACKUP_ERR_NO_FILES`).
