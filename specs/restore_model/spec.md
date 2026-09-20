# Especificación Técnica (SDD): restore_model

**Rama:** `dev/feature/restore-model`  
**Componente:** `lib/models/restore_model.sh`  
**Capa MVC:** Modelo de Negocio (Motor de Desempaquetado, Restauración Histórica y Hooks)  
**Entorno:** Lliurex 25 / Ubuntu 24.04 (Bash 5.0+, sin privilegios `sudo`, herramientas: `tar`, `zstd`, `gpg`)

---

## 1. Visión y Requerimientos Funcionales

El modelo `restore_model.sh` es el responsable de la restitución íntegra de archivos y configuraciones desde el almacenamiento externo hacia el equipo local (`$TARGET_USER_HOME`).

### Requerimientos Funcionales:
1. **Resolución de Archivos Históricos:**
   - Si no se especifica marca de tiempo: localiza automáticamente la copia más reciente disponible en `$BACKUP_DIR/archives/<module_id>/`.
   - Si se especifica una marca de tiempo `AAAAMMDD_HHMMSS`: localiza el archivo exacto correspondiente.
   - Detecta si el archivo es estándar (`.tar.zst`) o cifrado (`.tar.zst.gpg`).
2. **Desempaquetado Seguro y Atómico:**
   - Archivo estándar: extracción directa con `tar -I 'zstd' -xf "$archive" -C "$TARGET_USER_HOME"`.
   - Archivo cifrado: canalización directa en memoria `gpg --decrypt --passphrase-fd 3 ... | tar -I 'zstd' -xf - -C "$TARGET_USER_HOME"` sin almacenar copias intermedias descifradas en `/tmp/`.
3. **Validación Previa de Contraseña:**
   - Antes de iniciar la extracción de archivos cifrados, comprueba la contraseña con `crypto_model_verify_passphrase`.
4. **Modalidades de Restauración:**
   - **Atómica por Módulo:** Restaura un módulo individual (último o histórico).
   - **Por Etiqueta (`tag`):** Restaura todos los módulos asociados a una etiqueta.
   - **Express Sensible:** Restaura todos los módulos sensibles (`IS_SENSITIVE=true`) reutilizando una única contraseña introducida por el usuario al iniciar la sesión.
   - **Total:** Restaura secuencialmente todos los módulos archivados en el SSD.
5. **Ejecución de Hooks posteriores (`POST_RESTORE_HOOK`):**
   - Si el módulo define `POST_RESTORE_HOOK`, tras la extracción se ejecuta en una subshell aislada dentro de `$TARGET_USER_HOME`.
6. **Auditoría:**
   - Registro de cada restauración en `<BACKUP_DIR>/logs/backup_history.log`.
7. **Cumplimiento MVC:**
   - Lógica pura sin diálogos interactivos ni `whiptail`. Comunica vía `stdout` y códigos de salida.

---

## 2. Definición de Entradas, Salidas y Códigos de Error

### Códigos de Retorno Estandarizados:
- `RESTORE_OK=0`: Restauración y hooks completados con éxito.
- `RESTORE_ERR_CONFIG=1`: Parámetros insuficientes o directorio de backup inválido.
- `RESTORE_ERR_NOT_FOUND=2`: Módulo no reconocido.
- `RESTORE_ERR_NO_ARCHIVE=3`: No se encontraron archivos de copia para el módulo (o timestamp inexistente).
- `RESTORE_ERR_PASSPHRASE=4`: Archivo cifrado requiere contraseña y no se suministró o es errónea.
- `RESTORE_ERR_EXTRACTION=5`: Fallo durante la descompresión o extracción tar.zst.
- `RESTORE_ERR_HOOK=6`: Fallo en la ejecución del `POST_RESTORE_HOOK`.

---

## 3. Casos Borde y Mitigaciones

1. **Permisos locales de escritura:** Si un archivo local a sobreescribir no tiene permisos de escritura, la extracción tar puede fallar; el script debe reportar `RESTORE_ERR_EXTRACTION` limpiamente.
2. **Directorios padre inexistentes:** `tar -C "$TARGET_USER_HOME"` recrea la jerarquía relativa de directorios automáticamente.
3. **Hook con error:** Si el hook posterior falla con código != 0, los archivos ya fueron restaurados pero se notifica explícitamente `RESTORE_ERR_HOOK` para alertar al usuario o controlador.
