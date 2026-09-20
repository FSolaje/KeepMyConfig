# Lista de Tareas Atómicas: crypto_model

**Rama:** `dev/feature/crypto-shred`  
**Componente:** `lib/models/crypto_model.sh`  

---

## Tareas Secuenciales de Implementación:

- [x] **Fase 1: Especificación y Diseño (SDD)**
  - [x] Redacción de `specs/crypto_model/spec.md`.
  - [x] Redacción de `specs/crypto_model/plan.md`.
  - [x] Redacción de `specs/crypto_model/tasks.md`.
  - [x] Aprobación de la especificación técnica por parte del usuario.

- [x] **Fase 2: Implementación de la Lógica de Negocio (`lib/models/crypto_model.sh`)**
  - [x] Declaración de códigos de error (`CRYPTO_OK`, `CRYPTO_ERR_*`).
  - [x] Implementación de `crypto_model_check_deps`.
  - [x] Implementación de `crypto_model_compute_sha256`.
  - [x] Implementación de `crypto_model_encrypt_file` y `crypto_model_encrypt_pipe`.
  - [x] Implementación de `crypto_model_decrypt_file` y `crypto_model_verify_passphrase`.
  - [x] Implementación de `crypto_model_shred_path` (soporte de fichero y árbol recursivo de directorios).

- [x] **Fase 3: Suite de Pruebas Unitarias y Auditoría SAST**
  - [x] Creación de `tests/test_crypto_model.sh`.
  - [x] Ejecución y validación del 100% de tests unitarios aprobados.
  - [x] Ejecución del escáner SAST obligatorio (`bash user_data/security_check/scripts/security_check.sh`).
  - [x] Presentación del reporte de seguridad y solicitud de aprobación de commit.
