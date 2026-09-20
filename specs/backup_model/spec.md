# Especificación Técnica (SDD): backup_model

**Rama:** `dev/feature/backup-model`  
**Componente:** `lib/models/backup_model.sh`  
**Capa MVC:** Modelo de Negocio (Motor de Empaquetado, Manifiestos, Diffs e Histórico)  
**Entorno:** Lliurex 25 / Ubuntu 24.04 (Bash 5.0+, sin privilegios `sudo`, herramientas: `tar`, `zstd`, `gpg`, `sha256sum`, `shred`)

---

## 1. Visión y Requerimientos Funcionales

El modelo `backup_model.sh` es el motor central de respaldo atómico y modular. Orquesta el empaquetado de las rutas declaradas por un módulo, la compresión con `zstd`, el cifrado opcional al vuelo con `crypto_model`, la generación del registro de auditoría (`manifest.log`), el cálculo de diferencias (*diffs*) respecto al histórico precedente y la purga segura condicional (*Vault & Shred*).

### Requerimientos Funcionales:
1. **Marcas de Tiempo Uniformes:**
   - Formato estricto: `AAAAMMDD_HHMMSS` (ej. `20260920_174500`).
2. **Estructura Jerárquica en Destino:**
   ```text
   <BACKUP_DIR>/
   ├── .backup_storage_marker
   ├── archives/
   │   └── <module_id>/
   │       ├── <TIMESTAMP>.tar.zst (si IS_SENSITIVE=false)
   │       ├── <TIMESTAMP>.tar.zst.gpg (si IS_SENSITIVE=true)
   │       └── <TIMESTAMP>.manifest.log
   └── logs/
       └── backup_history.log
   ```
3. **Flujo de Empaquetado Atómico:**
   - Si `IS_SENSITIVE=false`: genera directamente `<TIMESTAMP>.tar.zst`.
   - Si `IS_SENSITIVE=true`: canaliza el flujo `tar -I 'zstd -3' -cf - ...` directamente hacia `crypto_model_encrypt_pipe`, generando `<TIMESTAMP>.tar.zst.gpg` sin archivos intermedios desprotegidos en disco.
4. **Verificación Estricta Pre-Purga:**
   - Comprobación de integridad del archivo generado en el SSD (test `tar -tf` o test `crypto_model_verify_passphrase`).
   - Solo si el archivo generado es 100% íntegro y válido se autoriza la purga en origen.
5. **Auditoría e Inventario con Detección de Cambios (`manifest.log`):**
   - Cabecera con metadatos: Módulo, Timestamp, Usuario, Host, Cifrado, Tamaño total.
   - Inventario detallado: Cada archivo respaldado con su tamaño en bytes y suma SHA-256.
   - Diff respecto al backup inmediatamente anterior del mismo módulo:
     - `+ <fichero>`: Archivos nuevos.
     - `~ <fichero>`: Archivos modificados (mismo nombre, diferente SHA-256).
     - `- <fichero>`: Archivos eliminados respecto a la copia previa.
6. **Purga Segura en Origen (*Vault & Shred*):**
   - Ejecuta `crypto_model_shred_path` sobre las rutas locales respaldadas si:
     - El módulo tiene `PURGE_AFTER_BACKUP=true` y no se especificó `--no-purge`.
     - O se forzó explícitamente la purga (`force_purge=true`).
7. **Registro Global de Auditoría:**
   - Cada respaldo exitoso añade una entrada al archivo `<BACKUP_DIR>/logs/backup_history.log`.

---

## 2. Entradas, Salidas y Códigos de Error

### Códigos de Retorno Estandarizados:
- `BACKUP_OK=0`: Respaldo completado, verificado y auditado con éxito.
- `BACKUP_ERR_CONFIG=1`: Parámetros insuficientes o directorio de backup inválido.
- `BACKUP_ERR_MODULE=2`: Módulo no existe o no es válido.
- `BACKUP_ERR_NO_FILES=3`: Ninguna de las rutas del módulo existe en el equipo local.
- `BACKUP_ERR_PASSPHRASE=4`: Módulo sensible requiere contraseña y no se proporcionó.
- `BACKUP_ERR_ARCHIVE=5`: Fallo durante la compresión o creación del archivo tar.zst.
- `BACKUP_ERR_CORRUPT=6`: La verificación de integridad del archivo generado falló.
- `BACKUP_ERR_SHRED=7`: El archivo se respaldó correctamente pero falló la purga en origen.

---

## 3. Casos Borde y Mitigaciones

1. **Rutas inexistentes:** Si un módulo define 3 rutas y solo 1 existe en el equipo local, el backup se realiza con los archivos existentes sin abortar, dejando constancia en el manifiesto.
2. **Corte de energía / desconexión durante la copia:** Los archivos se generan con sufijo temporal `.tmp` y solo tras superar la verificación de integridad se renombran al nombre final definitivo.
3. **Primer backup del módulo (sin histórico previo):** El cálculo de diffs debe detectar la ausencia de manifiestos previos y marcar todos los archivos como añadidos (`+`), sin generar errores de lectura.
