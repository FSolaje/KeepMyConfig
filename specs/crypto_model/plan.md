# Plan Arquitectónico y Técnico: crypto_model

**Rama:** `dev/feature/crypto-shred`  
**Componente:** `lib/models/crypto_model.sh`  
**Objetivo:** Implementar los motores de cifrado/descifrado simétrico GPG (AES-256), hashing SHA-256 y purga segura multinivel con `shred`.

---

## 1. Diseño Arquitectónico de Funciones

Se implementará `lib/models/crypto_model.sh` con las siguientes funciones:

1. `crypto_model_check_deps`
   - Comprueba la disponibilidad en `$PATH` de `gpg`, `shred` y `sha256sum`.
   - Retorna `CRYPTO_OK` (0) o `CRYPTO_ERR_DEPS` (6).

2. `crypto_model_encrypt_file <input_file> <output_file> <passphrase> [cipher_algo]`
   - Cifra `$input_file` produciendo `$output_file`.
   - Utiliza `gpg --batch --yes --symmetric --cipher-algo "${cipher:-AES256}" --passphrase-fd 0 -o "$output_file" "$input_file" <<< "$passphrase"`.
   - Retorna `CRYPTO_OK` o código de error GPG.

3. `crypto_model_encrypt_pipe <output_file> <passphrase> [cipher_algo]`
   - Recibe datos desde `stdin` (tubería de empaquetado `tar/zstd`) y los cifra al vuelo hacia `$output_file`.
   - Retorna 0 en éxito.

4. `crypto_model_decrypt_file <input_gpg> <output_file> <passphrase>`
   - Descifra `$input_gpg` y guarda el resultado en `$output_file`.
   - Detecta si la contraseña es errónea (`CRYPTO_ERR_AUTH`).

5. `crypto_model_verify_passphrase <input_gpg> <passphrase>`
   - Valida la contraseña descifrando hacia `/dev/null` sin alterar el disco.
   - Retorna `CRYPTO_OK` si la contraseña es válida, `CRYPTO_ERR_AUTH` si es incorrecta, `CRYPTO_ERR_GPG` si el archivo está dañado.

6. `crypto_model_compute_sha256 <file_path>`
   - Ejecuta `sha256sum "$file_path"` y extrae exclusivamente el hash hexadecimal (64 caracteres) por `stdout`.

7. `crypto_model_shred_path <target_path> [iterations] [zero_pass]`
   - Si es un archivo regular:
     Ejecuta `shred -u -n "$iterations" ${zero_flag} "$target_path"`.
   - Si es un directorio:
     Localiza todos los ficheros regulares dentro de él y les aplica `shred -u`.
     Posteriormente poda directorios vacíos recursivamente (`find "$target_path" -type d -empty -delete`).
   - Parámetros por defecto: `iterations=3`, `zero_pass=true` (`-z`).

---

## 2. Walkthrough de Impacto

- **Seguridad y Memoria:** La contraseña solo viaja a través de descriptores de archivo en subshells efímeras (`<<< "$passphrase"` o `passphrase-fd 0`), impidiendo que sea leída mediante `ps aux`.
- **Integración con `backup_model` y `restore_model`:** Permitirá empaquetar y cifrar en un único paso sin crear archivos gigantes sin cifrar en disco temporal.
- **Entorno no-sudo:** Todas las operaciones de cifrado y `shred` se ejecutan en el espacio de usuario del host.

---

## 3. Plan de Pruebas Unitarias (`tests/test_crypto_model.sh`)

- Verificación de dependencias (`gpg`, `shred`, `sha256sum`).
- Cifrado y descifrado de archivo de prueba con texto conocido.
- Validación de contraseña correcta (`verify_passphrase` = 0).
- Detección de contraseña incorrecta (`verify_passphrase` = `CRYPTO_ERR_AUTH`).
- Cálculo exacto de suma SHA-256 comparado con `sha256sum` directo.
- Cifrado al vuelo mediante tubería (`stdin` -> GPG -> archivo).
- Prueba de purga con `shred`:
  - En un fichero individual: verificar que desaparece (`! -f`).
  - En un árbol de directorios con subcarpetas y ficheros: verificar que el árbol completo desaparece (`! -e`).
