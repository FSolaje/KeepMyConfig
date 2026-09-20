# Especificación de Requerimientos: Módulos Adicionales (bash-env y ssh-keys)

**Componentes:** `modules.d/bash-env.conf` y `modules.d/ssh-keys.conf`  
**Rama:** `dev/feature/sample-modules`  
**Estado:** Propuesta / En Revisión  

---

## 1. Propósito y Alcance

Complementar el catálogo inicial de recetas de **BackupConfig** para cubrir los dos casos fundamentales de administración y desarrollo de Lliurex 25 / Ubuntu 24.04:
1. **Entorno Shell (`bash-env.conf`):** Configuraciones del intérprete de comandos no sensibles, de uso público y persistente.
2. **Identidades Criptográficas SSH (`ssh-keys.conf`):** Llaves privadas y credenciales altamente confidenciales que deben protegerse con cifrado AES-256 simétrico y destruirse localmente en origen (*Vault & Shred*), restaurando los permisos UNIX estrictos (`chmod 700 / 600`) mediante un hook posterior.

---

## 2. Especificación de las Recetas

### 2.1 `modules.d/bash-env.conf`
- **ID:** `bash-env`
- **Nombre:** `Entorno Bash y Shell (.bashrc, .profile, aliases)`
- **Etiquetas:** `("system" "dev")`
- **Rutas Relativas:**
  - `.bashrc`
  - `.profile`
  - `.bash_aliases`
  - `.bash_logout`
- **Sensibilidad:** `IS_SENSITIVE=false`
- **Purga:** `PURGE_AFTER_BACKUP=false`
- **Hook Posterior:** `POST_RESTORE_HOOK=""`
- **Comportamiento:** Respaldo estándar en `.tar.zst`, sin requerimiento de contraseña GPG. Los ficheros en el host permanecen intactos.

### 2.2 `modules.d/ssh-keys.conf`
- **ID:** `ssh-keys`
- **Nombre:** `Claves SSH y Configuración de Conexiones (.ssh)`
- **Etiquetas:** `("system" "sensitive")`
- **Rutas Relativas:**
  - `.ssh/id_rsa`
  - `.ssh/id_rsa.pub`
  - `.ssh/id_ed25519`
  - `.ssh/id_ed25519.pub`
  - `.ssh/config`
  - `.ssh/known_hosts`
- **Sensibilidad:** `IS_SENSITIVE=true`
- **Purga:** `PURGE_AFTER_BACKUP=true`
- **Hook Posterior:**
  ```bash
  POST_RESTORE_HOOK="chmod 700 .ssh 2>/dev/null; chmod 600 .ssh/id_* 2>/dev/null; chmod 644 .ssh/*.pub .ssh/config .ssh/known_hosts 2>/dev/null || true"
  ```
- **Comportamiento:** Respaldo forzado con cifrado simétrico GPG AES-256 (`.tar.zst.gpg`). Tras verificar la integridad de la copia en el SSD, se purgan de forma segura los ficheros locales en origen con `shred -u -z -n 3`. Tras la restauración, se restablecen automáticamente los permisos de seguridad requeridos por OpenSSH (`700` en `.ssh`, `600` en llaves privadas).

---

## 3. Criterios de Aceptación
1. `module_model_get` debe validar la sintaxis declarativa Bash de ambos archivos sin errores.
2. `filter_by_tag "system"` debe listar tanto `bash-env` como `ssh-keys`.
3. `filter_by_sensitivity "true"` debe incluir `ssh-keys` y excluir `bash-env`.
4. El hook de `ssh-keys` debe ejecutarse correctamente en el home de destino fijando los permisos apropiados.
