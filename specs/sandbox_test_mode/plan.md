# Plan Arquitectónico y Técnico: Modo Sandbox / Test Mode (--test-mode)

**Sub-Hito:** Herramientas de Desarrollo y Calidad (Hito 12 / Sub-Hito 12.5)  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Arquitectura de Aislamiento del Sandbox

```text
KeepMyConfig/
├── backup_manager.sh               <-- Parser de argumentos tempranos (--test-mode / --sandbox / --clean-sandbox)
├── lib/
│   ├── controllers/app_controller.sh <-- controller_enable_sandbox_mode() y controller_clean_sandbox()
│   ├── views/whiptail_view.sh      <-- whiptail_view_main_menu (soporte de prefijo [SANDBOX])
│   └── models/                     <-- Modelos operan de forma agnóstica recibiendo rutas del sandbox
└── user_data/
    └── sandbox/                    <-- EXCLUIDO EN .gitignore
        ├── config/config.conf      <-- Configuración aislada de prueba
        ├── modules.d/              <-- Módulos creados o activados en pruebas
        ├── profiles/               <-- Perfiles creados en pruebas (incluyendo default/)
        └── storage/                <-- BACKUP_DESTINATION local del sandbox (.backup_storage_marker)
```

---

## 2. Componentes y Modificaciones Técnicas

### 2.1 Entrypoint Principal (`backup_manager.sh`)
- Detección previa antes del análisis posicional:
  - Si el primer o cualquier argumento es `--clean-sandbox`, invocar directamente `controller_clean_sandbox` y salir con código 0.
  - Si se detecta `--test-mode`, `--sandbox` o `KEEP_MY_CONFIG_TEST_MODE=true`, activar la bandera de sandbox y filtrar dicho flag para no interferir con los comandos subsiguientes (`--backup-all`, etc.).

### 2.2 Controlador (`lib/controllers/app_controller.sh`)
- **Variable Global:** `IS_SANDBOX_MODE="false"`.
- **Función `controller_enable_sandbox_mode()`:**
  1. Fijar `IS_SANDBOX_MODE="true"`.
  2. Definir `SANDBOX_BASE="${CONTROLLER_BASE_DIR}/user_data/sandbox"`.
  3. Comprobar si `SANDBOX_BASE` existe. Si no existe:
     - `mkdir -p "$SANDBOX_BASE/config" "$SANDBOX_BASE/modules.d" "$SANDBOX_BASE/profiles/default" "$SANDBOX_BASE/storage/archives" "$SANDBOX_BASE/storage/logs"`
     - Copiar `config/config.conf` -> `$SANDBOX_BASE/config/config.conf` modificando `BACKUP_DESTINATION="$SANDBOX_BASE/storage"`, `INITIAL_SETUP_DONE="true"` y `ACTIVE_PROFILE="default"`.
     - Copiar `markers/.backup_storage_marker` -> `$SANDBOX_BASE/storage/.backup_storage_marker`.
     - Copiar `profiles/default/profile.conf` -> `$SANDBOX_BASE/profiles/default/profile.conf`.
  4. Redirigir variables operativas:
     - `CONTROLLER_CONFIG_FILE="$SANDBOX_BASE/config/config.conf"`
     - `MODULES_DIR="$SANDBOX_BASE/modules.d"`
     - `PROFILES_DIR="$SANDBOX_BASE/profiles"`
     - `TEMPLATES_DIR="${CONTROLLER_BASE_DIR}/templates.d"` (lectura global preservada)
- **Función `controller_clean_sandbox()`:**
  - Si existe `${CONTROLLER_BASE_DIR}/user_data/sandbox`, ejecutar `rm -rf "${CONTROLLER_BASE_DIR}/user_data/sandbox"`.
  - Imprimir confirmación ANSI y retornar 0.

### 2.3 Vista Whiptail (`lib/views/whiptail_view.sh`)
- Actualizar `whiptail_view_main_menu`:
  - Parámetro opcional `$3` (o inspección de entorno): si se pasa `is_sandbox="true"`, el título de la ventana se formatea como:
    `KeepMyConfig [SANDBOX] [Perfil: $active_profile]`

---

## 3. Plan de Pruebas Unitarias (`tests/test_sandbox_mode.sh`)

1. Verificación de inicialización de sandbox (`controller_enable_sandbox_mode` crea la jerarquía en `user_data/sandbox`).
2. Verificación de redirección de `CONTROLLER_CONFIG_FILE`, `MODULES_DIR` y `PROFILES_DIR`.
3. Verificación de que la creación de módulos en modo test escribe en `user_data/sandbox/modules.d/` y no toca `modules.d/`.
4. Verificación de que la activación de plantillas escribe en el sandbox.
5. Verificación de purga completa con `controller_clean_sandbox`.
6. Verificación de que `git status --porcelain` no reporta ningún archivo tras ejecutar en modo test.
