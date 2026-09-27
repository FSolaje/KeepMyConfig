# Especificación de Requerimientos: Modo Sandbox / Test Mode (--test-mode)

**Sub-Hito:** Herramientas de Desarrollo y Calidad (Hito 12 / Sub-Hito 12.5)  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Contexto y Justificación

Durante el desarrollo, pruebas manuales y validación de KeepMyConfig, la interacción interactiva (crear módulos en el asistente TUI, crear perfiles, activar recetas de plantillas o realizar copias) altera los directorios versionados del proyecto (`config/config.conf`, `modules.d/`, `profiles/`), generando archivos sin seguimiento (*untracked files*) que ensucian el entorno de trabajo y requieren limpieza manual antes de cada commit.

Para evitar interferencias en el control de versiones y posibilitar un entorno seguro de pruebas sin riesgo de alterar configuraciones reales, se define el **Modo Sandbox / Test Mode**.

---

## 2. Requerimientos Funcionales

### FR-TEST-001: Activación por Flag CLI y Variable de Entorno
- La aplicación debe soportar los flags `--test-mode` y `--sandbox` tanto para la interfaz interactiva TUI como para la CLI:
  ```bash
  ./backup_manager.sh --test-mode
  ./backup_manager.sh --sandbox
  ```
- Debe soportar la activación equivalente mediante la variable de entorno `KEEP_MY_CONFIG_TEST_MODE=true`:
  ```bash
  KEEP_MY_CONFIG_TEST_MODE=true ./backup_manager.sh
  ```

### FR-TEST-002: Aislamiento Completo de Rutas en `user_data/sandbox/`
- Cuando el modo test está activo, el sistema redirige automáticamente todas las rutas volátiles a `user_data/sandbox/` (directorio ignorado por Git):
  - **Configuración:** `user_data/sandbox/config/config.conf` (inicializado a partir de `config/config.conf`).
  - **Módulos Activos:** `user_data/sandbox/modules.d/` (inicia vacío o copia de trabajo).
  - **Perfiles:** `user_data/sandbox/profiles/` (incluyendo `profiles/default/profile.conf`).
  - **Almacenamiento de Backup:** `user_data/sandbox/storage/` (inicializado con su `.backup_storage_marker`).
- La biblioteca `templates.d/` se lee en modo lectura desde el proyecto, pero cualquier activación (`--enable-template`) escribe exclusivamente en el sandbox.
- Las carpetas reales del repositorio (`modules.d/`, `profiles/`, `config/`) quedan estrictamente intactas.

### FR-TEST-003: Auto-Inicialización Transparente del Sandbox
- Si `user_data/sandbox/` no existe al invocar `--test-mode`, el sistema debe inicializarlo automáticamente:
  1. Crear la jerarquía de carpetas necesaria (`config/`, `modules.d/`, `profiles/default/`, `storage/archives/`, `storage/logs/`).
  2. Desplegar una copia fresca de `config/config.conf` configurada con `BACKUP_DESTINATION="user_data/sandbox/storage"`.
  3. Desplegar el marcador `.backup_storage_marker` en el storage del sandbox.

### FR-TEST-004: Indicador Visual Explícito en TUI y Consola
- En modo TUI (Whiptail), el título del menú principal debe reflejar claramente el entorno de pruebas:
  ```text
  KeepMyConfig [SANDBOX / MODO TEST] [Perfil: default]
  ```
- En modo CLI, al arrancar cualquier comando con `--test-mode`, se emite una advertencia visual ANSI:
  ```text
  [AVISO] Ejecutando en MODO TEST / SANDBOX (Rutas aisladas en user_data/sandbox/)
  ```

### FR-TEST-005: Comando de Purga y Reseteo (`--clean-sandbox`)
- La aplicación debe incluir un comando de limpieza rápida:
  ```bash
  ./backup_manager.sh --clean-sandbox
  ```
  que elimine por completo el directorio `user_data/sandbox/` y confirme al usuario la limpieza del entorno de pruebas.

---

## 3. Requerimientos No Funcionales y de Seguridad

- **NFR-SEC-001 (Aislamiento Total de Git):** El directorio `user_data/` permanece bajo regla mandatoria en `.gitignore`. Ningún archivo creado dentro de `user_data/sandbox/` figurará jamás en `git status`.
- **NFR-SEC-002 (Cero Privilegios):** Todo el sandbox opera dentro de los permisos del usuario normal sin requerir `sudo`.
- **NFR-PERF-001 (Cero Sobrecarga):** Si `--test-mode` no está activo, la ejecución estándar de KeepMyConfig no experimenta ninguna degradación de rendimiento.
