# KeepMyConfig - Gestor de Backup y Recuperación Modular en Terminal (MVC en Bash)

Sistema modular y desacoplado de copias de seguridad e histórico para terminal, diseñado específicamente para entornos educativos y corporativos con permisos restringidos (sin `sudo`) como **Lliurex 25 (Ubuntu 24.04 LTS)**.

Permite respaldar, cifrar, purgar y restaurar configuraciones del sistema y aplicaciones en almacenamiento universal (carpeta local `~/Backups/KeepMyConfig`, disco externo SSD/USB o montajes de red mediante `BACKUP_DESTINATION`) de forma atómica o por lotes, garantizando la persistencia de datos ante restauraciones periódicas del SAI o congelación de discos.

---

## Características Principales

- **Arquitectura MVC en Bash:**
  - **Modelos (`lib/models/`):** Lógica pura de empaquetado, sumas SHA-256, *diffs*, cifrado GPG, perfiles, plantillas y validaciones.
  - **Vistas (`lib/views/`):** Interfaz desacoplada basada en `whiptail` para menús, checklists, barras de progreso y formateo ANSI.
  - **Controlador (`lib/controllers/`):** Enrutador de eventos que orquesta la ejecución tanto en modo interactivo (TUI) como desatendido (CLI Headless).
- **Ruta Universal de Almacenamiento & Asistente de Onboarding:**
  - **Destino Canónico Único (`BACKUP_DESTINATION`):** Flexibilidad total para definir destinos locales (`~/Backups/KeepMyConfig`), discos montados (`/media/$USER/...`), rutas de red o notación semántica de conveniencia (`@media/<LABEL>/...`).
  - **Asistente de Primera Ejecución (Onboarding Wizard):** Configuración inicial guiada paso a paso tanto en TUI como en CLI (`--setup`), con auditoría de discos conectados, recomendación de ruta local y auto-despliegue del marcador de seguridad `.backup_storage_marker`.
  - **Control de Persistencia de Sesión (`REMEMBER_LAST_PROFILE`):** Opción para recordar el perfil de la última sesión al iniciar o arrancar siempre en el perfil predeterminado.
- **Sistema de Perfiles de Backup & Convención Zero-Config (`profiles/`):**
  - Soporte de múltiples perfiles de trabajo (ej. `docente`, `desarrollo`, `default`).
  - **Convención Zero-Config por Perfil:** Las copias de perfiles secundarios se organizan de forma automática en `<BACKUP_DESTINATION>/<id_perfil>` sin necesidad de configuración adicional, preservando la raíz para el perfil `default`.
  - **Perfil Físico `default` Permanente & Auto-Healing:** Garantía de existencia física de `profiles/default/profile.conf` con recuperación automática si es eliminado.
  - Resolución jerárquica en cascada: módulos específicos del perfil tienen precedencia (*override*) sobre módulos globales.
  - **Exclusión selectiva de módulos globales (`DISABLED_MODULES`):** los perfiles particulares pueden desactivar módulos globales específicos sin eliminarlos del catálogo general.
  - Selector de ámbito en el asistente TUI: permite crear módulos en el catálogo global o exclusivos del perfil activo.
  - Soporte para módulos exclusivos por perfil y deduplicación automática de listados.
- **Biblioteca de Plantillas Desacoplada (`templates.d/`):**
  - Catálogo de recetas predefinidas listas para activar (`ssh-keys`, `bash-env`, `firefox`, `vscode-standard`, `vscode-sensitive`, `intellij`, `git-config`, `thunderbird`, `libreoffice`) junto con un esqueleto canónico documentado (`template-skeleton.conf`).
  - **Estado inicial limpio de primera ejecución:** la instalación arranca con 0 módulos activos en `modules.d/`. Si se ejecuta `--backup-all`, el sistema ofrece una orientación amigable sugiriendo activar plantillas o crear módulos propios en lugar de emitir un fallo técnico.
  - **Activación selectiva de ámbito:** las plantillas se pueden instanciar en el catálogo global (`modules.d/`) o de forma exclusiva en el perfil activo (`profiles/<id>/modules.d/`).
  - **Exportación y creación ágil:** permite promover cualquier módulo activo a la biblioteca de plantillas o redactar nuevas plantillas desde TUI y CLI.
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
- **Seguridad de Dispositivo Anti-Escritura Fantasma:**
  - Comprobación mandatoria del archivo testigo (`.backup_storage_marker`) con validación jerárquica y creación atómica de subcarpetas.
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
│   ├── config.conf          # Configuración general (BACKUP_DESTINATION, perfil activo, flags)
│   └── default_tags.conf    # Catálogo de etiquetas
├── templates.d/             # Biblioteca de plantillas y recetas preconfiguradas (.conf)
├── modules.d/               # Recetas activas globales de backup (.conf)
├── profiles/                # Perfiles de backup y módulos con ámbito (scoped modules)
│   └── default/             # Perfil predeterminado persistente con auto-healing
│       └── profile.conf     # Configuración canónica del perfil default
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
Ejecutar sin argumentos para desplegar la interfaz visual en terminal (en el primer arranque lanza automáticamente el asistente de Onboarding):
```bash
./backup_manager.sh
```

### 2. Modo Línea de Comandos (CLI / TTY Remota)
```bash
# Ejecutar o reconfigurar el Asistente de Configuración Inicial (Onboarding)
./backup_manager.sh --setup

# Comprobar estado y accesibilidad del almacenamiento universal configurado
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
