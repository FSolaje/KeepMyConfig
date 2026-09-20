# Especificación Técnica (SDD): crypto_model

**Rama:** `dev/feature/crypto-shred`  
**Componente:** `lib/models/crypto_model.sh`  
**Capa MVC:** Modelo de Negocio (Criptografía GPG, Hashing SHA-256 y Purga Segura Shred)  
**Entorno:** Lliurex 25 / Ubuntu 24.04 (Bash 5.0+, sin privilegios `sudo`, herramientas: `gpg`, `shred`, `sha256sum`)

---

## 1. Visión y Requerimientos Funcionales

El modelo `crypto_model.sh` proporciona todos los servicios criptográficos y de borrado seguro (*Vault & Shred*) requeridos por el gestor de copias de seguridad.

### Requerimientos Funcionales:
1. **Cifrado Simétrico GPG (AES-256):**
   - Cifrar flujos de datos (tuberías `tar/zstd`) o archivos completos mediante GPG simétrico en modo desatendido (`--batch --yes`).
   - Algoritmo por defecto: `AES256`.
   - La contraseña nunca debe almacenarse en disco, temporales ni variables globales del sistema; se transmitirá de forma segura vía descriptores de archivo (`--passphrase-fd 0`).
2. **Descifrado y Validación de Contraseña:**
   - Descifrar archivos `.gpg` hacia destino o hacia un flujo estándar (`stdout`).
   - Comprobación previa de contraseña (`verify_passphrase`) sin extraer datos a disco para validar de forma instantánea si la clave introducida por el usuario es correcta antes de iniciar operaciones pesadas de descompresión.
3. **Cálculo de Huellas Digitales (SHA-256):**
   - Calcular sumas de comprobación SHA-256 tanto para archivos individuales como para streams, alimentando el inventario del `manifest.log`.
4. **Purga Segura con `shred` (*Vault & Shred*):**
   - Destrucción segura de archivos mediante `shred -u -z -n <iteraciones>`.
   - Capacidad de procesar tanto ficheros individuales como árboles completos de directorios (eliminando todos los ficheros con `shred` y luego limpiando las carpetas vacías con `find ... -delete` o `rmdir -p`).
   - Verificación de precondición: comprobar existencia y permisos de escritura antes de disparar el borrado.
5. **Cumplimiento MVC:**
   - Cero interfaces gráficas ni interacción con el usuario (sin `whiptail`). Códigos numéricos de retorno y datos limpios en `stdout`.

---

## 2. Definición de Entradas, Salidas y Códigos de Error

### Códigos de Retorno Estandarizados:
- `CRYPTO_OK=0`: Operación completada con éxito.
- `CRYPTO_ERR_CONFIG=1`: Parámetros insuficientes o inválidos.
- `CRYPTO_ERR_NOT_FOUND=2`: Archivo o ruta de origen no existe.
- `CRYPTO_ERR_AUTH=3`: Contraseña incorrecta o fallo de autenticación GPG.
- `CRYPTO_ERR_GPG=4`: Error general del motor GPG (archivo corrupto, fallo en pipe).
- `CRYPTO_ERR_SHRED=5`: Error al ejecutar borrado seguro o falta de permisos sobre el fichero.
- `CRYPTO_ERR_DEPS=6`: Utilidad de sistema no disponible (`gpg`, `shred` o `sha256sum`).

---

## 3. Casos Borde y Mitigaciones

1. **Contraseña errónea:** GPG debe reportar de forma determinista `CRYPTO_ERR_AUTH` capturando códigos de salida y mensajes sin volcar claves a `stderr` o logs.
2. **Intentar hacer `shred` sobre un directorio:** `shred` nativo de GNU coreutils falla en directorios. La función `crypto_model_shred_path` debe distinguir ficheros regulares de directorios, aplicando `shred` a cada fichero encontrado en el árbol y posteriormente podando los directorios vacíos.
3. **Ficheros de solo lectura o bloqueados:** Comprobar permisos con `chmod u+w` antes de invocar `shred` para evitar errores de permisos insuficientes dentro del entorno sin `sudo`.
4. **Archivos vacíos o de tamaño 0:** Soportar cifrado y hashing correcto de ficheros vacíos sin fallos de tubería.
