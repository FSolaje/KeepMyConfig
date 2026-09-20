# Plan Arquitectónico y Técnico: restore_model

**Rama:** `dev/feature/restore-model`  
**Componente:** `lib/models/restore_model.sh`  
**Objetivo:** Implementar la lógica del motor de restauración, resolución de histórico y hooks.

---

## 1. Diseño Arquitectónico de Funciones

Se implementará `lib/models/restore_model.sh` consumiendo `module_model.sh` y `crypto_model.sh`:

1. `restore_model_find_archive <module_id> <backup_dir> [timestamp]`
   - Si se especifica `timestamp`:
     Verifica `$backup_dir/archives/$module_id/$timestamp.tar.zst` o `.tar.zst.gpg`.
   - Si no se especifica:
     Busca el archivo más reciente (`*.tar.zst*`) ordenado por nombre.
   - Salida estructurada:
     ```text
     ARCHIVE_FILE=<ruta_absoluta>
     TIMESTAMP=<AAAAMMDD_HHMMSS>
     IS_ENCRYPTED=<true|false>
     ```
   - Retorna `RESTORE_OK` (0) o `RESTORE_ERR_NO_ARCHIVE` (3).

2. `restore_model_restore_module <module_id> <backup_dir> [target_home] [timestamp] [passphrase] [modules_dir]`
   - Orquesta la restauración de un módulo:
     1. Localiza el archivo con `restore_model_find_archive`.
     2. Si es cifrado, valida y canaliza `gpg | tar -I 'zstd' -xf - -C "$target_home"`.
     3. Si es estándar, ejecuta `tar -I 'zstd' -xf "$archive" -C "$target_home"`.
     4. Si el módulo define `POST_RESTORE_HOOK`, lo ejecuta en subshell:
        `(cd "$target_home" && eval "$hook")`.
     5. Registra la acción en `$backup_dir/logs/backup_history.log`.
     6. Emite resultado estructurado en `stdout` (`STATUS=SUCCESS`, `MODULE_ID=...`, `ARCHIVE=...`).

3. `restore_model_restore_by_tag <tag> <backup_dir> [target_home] [passphrase] [modules_dir]`
   - Obtiene lista de módulos con `module_model_filter_by_tag`.
   - Itera y restaura cada uno.
   - Emite resumen de éxitos y fallos.

4. `restore_model_restore_sensitive_all <backup_dir> [target_home] <passphrase> [modules_dir]`
   - Obtiene módulos con `module_model_filter_by_sensitivity "true"`.
   - Restaura el último backup de cada uno utilizando la misma clave.

5. `restore_model_restore_all <backup_dir> [target_home] [passphrase] [modules_dir]`
   - Escanea todos los directorios en `$backup_dir/archives/` y restaura la última copia de cada módulo encontrado.

---

## 2. Walkthrough de Impacto

- **Desacoplamiento MVC:** Proporciona bloques de construcción modulares que el controlador `app_controller.sh` podrá invocar directamente desde las opciones del menú de Whiptail o desde los flags CLI (`--restore-sensitive`, `--restore-all`, `--restore-module`, etc.).
- **Seguridad en Memoria:** Al igual que en `backup_model`, la tubería descifra al vuelo directamente hacia `tar`, evitando escribir ficheros planos en `/tmp/`.

---

## 3. Plan de Pruebas Unitarias (`tests/test_restore_model.sh`)

- Resolución de archivos más recientes vs resolución de marca de tiempo específica.
- Restauración de módulo estándar no sensible:
  - Verificar que los archivos reaparecen en el `$HOME` simulado con su contenido exacto.
- Restauración de módulo sensible con GPG:
  - Falla con clave incorrecta (`RESTORE_ERR_PASSPHRASE`).
  - Restaura exitosamente con la contraseña correcta.
- Ejecución correcta de `POST_RESTORE_HOOK` (verificar fichero creado por el hook).
- Restauración en bloque por etiquetas (`restore_by_tag`).
- Restauración express de todos los módulos sensibles (`restore_sensitive_all`).
