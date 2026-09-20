# Plan Técnico: Módulos Adicionales (bash-env y ssh-keys)

**Componentes:** `modules.d/bash-env.conf` y `modules.d/ssh-keys.conf`  
**Rama:** `dev/feature/sample-modules`  

---

## 1. Implementación de Archivos Declarativos

1. **`modules.d/bash-env.conf`**:
   - Declaración de variables de configuración estándar.
2. **`modules.d/ssh-keys.conf`**:
   - Declaración de variables de configuración sensibles con `IS_SENSITIVE=true` y `PURGE_AFTER_BACKUP=true`.
   - Inclusión de `POST_RESTORE_HOOK` para ajuste de permisos UNIX (`chmod 700 / 600`).

---

## 2. Estrategia de Pruebas Unitarias (`tests/test_sample_modules.sh`)

1. Validar la sintaxis y parser de ambos módulos mediante `module_model_get`.
2. Verificar la pertenencia a etiquetas (`system`, `dev`, `sensitive`).
3. Probar el ciclo completo de respaldo y restauración en sandbox:
   - Respaldo de `bash-env` en plano (`.tar.zst`).
   - Respaldo de `ssh-keys` cifrado con GPG (`.tar.zst.gpg`) comprobando purga con `shred -u`.
   - Restauración de `ssh-keys` verificando que el `POST_RESTORE_HOOK` restaura los permisos `700` y `600`.
