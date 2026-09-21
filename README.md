# KeepMyConfig - Gestor de Backup y Recuperación Modular en Terminal (MVC en Bash)

Sistema modular y desacoplado de copias de seguridad e histórico para terminal, diseñado específicamente para entornos educativos y corporativos con permisos restringidos (sin `sudo`) como **Lliurex 25 (Ubuntu 24.04 LTS)**.

Permite respaldar, cifrar, purgar y restaurar configuraciones del sistema y aplicaciones en almacenamiento externo o universal (SSD/USB/`LOCAL_PATH`) de forma atómica o por lotes, garantizando la persistencia de datos ante restauraciones periódicas del SAI o congelación de discos.

---

## Características Principales

- **Arquitectura MVC en Bash:**
  - **Modelos (`lib/models/`):** Lógica pura de empaquetado, sumas SHA-256, *diffs*, cifrado GPG, perfiles, plantillas y validaciones.
  - **Vistas (`lib/views/`):** Interfaz desacoplada basada en `whiptail` para menús, checklists, barras de progreso y formateo ANSI.
  - **Controlador (`lib/controllers/`):** Enrutador de eventos que orquesta la ejecución tanto en modo interactivo (TUI) como desatendido (CLI Headless).
- **Biblioteca de Plantillas Desacoplada (`templates.d/`):**
  - Catálogo de recetas predefinidas listas para activar (`ssh-keys`, `bash-env`, `firefox`, `vscode-standard`, `vscode-sensitive`, `intellij`, `git-config`, `thunderbird`, `libreoffice`) junto con un esqueleto canónico documentado (`template-skeleton.conf`).
  - **Estado inicial limpio de primera ejecución:** la instalación arranca con 0 módulos activos en `modules.d/`. Si se ejecuta `--backup-all`, el sistema ofrece una orientación amigable sugiriendo activar plantillas o crear módulos propios en lugar de emitir un fallo técnico.
  - **Activación selectiva de ámbito:** las plantillas se pueden instanciar en el catálogo global (`modules.d/`) o de forma exclusiva en el perfil activo (`profiles/<id>/modules.d/`).
  - **Exportación y creación ágil:** permite promover cualquier módulo activo a la biblioteca de plantillas o redactar nuevas plantillas desde TUI y CLI.
- **Sistema de Perfiles de Backup & Scoped Modules (`profiles/`):**
  - Soporte de múltiples perfiles de trabajo (ej. `docente`, `desarrollo`, `default`).
  - Resolución jerárquica en cascada: módulos específicos del perfil tienen precedencia (*override*) sobre módulos globales.
  - **Exclusión selectiva de módulos globales (`DISABLED_MODULES`):** los perfiles particulares pueden desactivar módulos globales específicos sin eliminarlos del catálogo general.
  - Selector de ámbito en el asistente TUI: permite crear módulos en el catálogo global o exclusivos del perfil activo.
  - Soporte para módulos exclusivos por perfil y deduplicación automática de listados.
  - Vinculación opcional de carpetas de destino por perfil (`TARGET_SUBDIR`).
- **Módulos Atómicos con Sanitización Automática de Rutas (`modules.d/`):**
  - Cada aplicación o configuración es una receta independiente (`.conf`).
  - Normalización inteligente de rutas en recetas (`$HOME/`, `~/`, `/home/<user>/` convertidos a rutas relativas).
  - Desacoplamiento de aplicaciones complejas en perfiles estándar y sensibles (ej. `vscode-standard` vs `vscode-sensitive`).
- **Sistema de Etiquetas Dinámicas:**
  - Agrupación de respaldos y restauraciones por etiquetas (`dev`, `sensitive`, `system`, etc.).
- **Gestión Efímera de Datos Sensibles (*Vault & Shred*):**
  - Cifrado simétrico robusto mediante **GPG (AES-256)**.
  - Purga segura en disco local mediante `shred -u -z -n 3` tras verificar el respaldo.
  - Restauración instantánea de datos sensibles con una única orden al inicio de la jornada de trabajo.
- **Seguridad de Dispositivo y Almacenamiento Universal:**
  - Soporte para discos externos (`UUID`, `LABEL`) y almacenamiento local/red (`LOCAL_PATH`).
  - Comprobación mandatoria de archivos testigo (`.backup_storage_marker`) contra escrituras fantasma.
- **Histórico con Marcas de Tiempo y Auditoría:**
  - Nomenclatura uniforme: `AAAAMMDD_HHMMSS`.
  - Generación de `manifest.log` con inventario de ficheros, hashes SHA-256 y bitácora `backup_history.log`.
- **100% Nativo en Linux:**
  - Sin dependencias de compilación ni librerías de terceros (`bash`, `whiptail`, `tar`, `zstd`, `gpg`, `shred`).

---

## Estructura del Proyecto

```text
KeepMyConfig/
├── backup_manager.sh        # Ejecutable principal (TUI / CLI)
├── config/
│   ├── config.conf          # Configuración general (dispositivo, rutas, perfil activo)
│   └── default_tags.conf    # Catálogo de etiquetas
├── templates.d/             # Biblioteca de plantillas y recetas preconfiguradas (.conf)
├── modules.d/               # Recetas activas globales de backup (.conf)
├── profiles/                # Perfiles específicos y módulos con ámbito (scoped modules)
├── lib/
│   ├── models/              # Lógica de negocio (device, profile, module, backup, restore, crypto)
│   ├── views/               # Interfaz TUI (whiptail) y formateo ANSI
│   └── controllers/         # Controlador de aplicación y enrutador CLI
├── markers/                 # Archivos testigo (.backup_storage_marker)
├── specs/                   # Especificaciones guiadas por requerimientos (SDD)
├── tests/                   # Suites de pruebas unitarias automatizadas
├── MANUAL_USUARIO.md        # Manual exhaustivo de usuario y administración
├── CHANGELOG.md             # Registro de cambios siguiendo SemVer
├── README.md                # Documentación del proyecto
└── .gitignore               # Exclusiones de control de versiones
```

---

## Requisitos del Sistema

- **Sistema Operativo:** Lliurex 25 / Ubuntu 24.04 LTS o cualquier distribución Linux moderna.
- **Intérprete:** Bash 5.0 o superior.
- **Herramientas base (incluidas de serie):** `whiptail`, `tar`, `zstd` (o `gzip`), `gpg`, `coreutils` (`shred`, `sha256sum`, `lsblk`).
- **Permisos:** Usuario estándar (no requiere privilegios `sudo`).

---

## Modos de Uso

### 1. Modo Interactivo (TUI)
Ejecutar sin argumentos para desplegar la interfaz visual en terminal:
```bash
./backup_manager.sh
```

### 2. Modo Línea de Comandos (CLI / TTY Remota)
```bash
# Comprobar estado y montaje del disco externo
./backup_manager.sh --check-device

# Listar las plantillas predefinidas en la biblioteca
./backup_manager.sh --list-templates

# Activar una plantilla en el perfil activo (o global si es default)
./backup_manager.sh --enable-template firefox
./backup_manager.sh --profile docente --enable-template git-config

# Exportar un módulo activo a la biblioteca de plantillas
./backup_manager.sh --export-template mi-modulo

# Realizar backup completo de todos los módulos
./backup_manager.sh --backup-all

# Realizar backup de una etiqueta específica (ej. desarrollo)
./backup_manager.sh --backup-tag dev

# Realizar backup de datos sensibles y purgarlos del equipo local
./backup_manager.sh --backup-tag sensitive --purge

# Restaurar rápidamente todos los datos sensibles al iniciar sesión
./backup_manager.sh --restore-sensitive

# Restaurar un módulo concreto a un punto histórico
./backup_manager.sh --restore-module vscode-standard --timestamp 20260918_130000
```

---

## Licencia y Ámbito
Desarrollado para su uso en entornos docentes y estaciones de trabajo DAW en centros educativos de la Comunitat Valenciana.
