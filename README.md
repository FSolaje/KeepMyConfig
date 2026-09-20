# Gestor de Backup y Recuperación Modular en Terminal (MVC en Bash)

Sistema modular y desacoplado de copias de seguridad e histórico para terminal, diseñado específicamente para entornos educativos y corporativos con permisos restringidos (sin `sudo`) como **Lliurex 25 (Ubuntu 24.04 LTS)**.

Permite respaldar, cifrar, purgar y restaurar configuraciones del sistema y aplicaciones en un disco externo (SSD/USB) de forma atómica o por lotes, garantizando la persistencia de datos ante restauraciones periódicas del SAI.

---

## Características Principales

- **Arquitectura MVC en Bash:**
  - **Modelos (`lib/models/`):** Lógica pura de empaquetado, cálculo de sumas SHA-256, *diffs*, cifrado y validaciones.
  - **Vistas (`lib/views/`):** Interfaz desacoplada basada en `whiptail` para menús, checklists, barras de progreso y peticiones de contraseñas.
  - **Controlador (`lib/controllers/`):** Enrutador de eventos que orquesta la ejecución tanto en modo interactivo (TUI) como desatendido (CLI Headless).
- **Módulos Atómicos e Independientes (`modules.d/`):**
  - Cada aplicación o configuración es una receta independiente (`.conf`).
  - Soporta separar aplicaciones complejas en perfiles no sensibles y sensibles (ej. `vscode-standard` vs `vscode-sensitive`).
- **Sistema de Etiquetas Dinámicas:**
  - Permite agrupar respaldos y restauraciones por etiquetas predefinidas (`dev`, `sensitive`, `system`, `office`) o personalizadas.
- **Gestión Efímera de Datos Sensibles (*Vault & Shred*):**
  - Cifrado simétrico robusto mediante **GPG (AES-256)**.
  - Purga segura en disco local mediante `shred -u -z -n 3` tras verificar el respaldo en el SSD.
  - Restauración instantánea de datos sensibles con una única orden al inicio de la jornada de trabajo.
- **Seguridad de Dispositivo y Marcadores:**
  - Validación de montaje del disco externo mediante `UUID`, `LABEL` o ruta estática.
  - Comprobación de archivos testigo (`.backup_storage_marker`) para evitar escrituras en carpetas locales si el SSD no está montado.
- **Histórico con Marcas de Tiempo y Auditoría:**
  - Nomenclatura uniforme: `AAAAMMDD_HHMMSS`.
  - Generación de `manifest.log` con inventario de ficheros, hashes SHA-256 y detección de diferencias (*añadidos, modificados, eliminados*) respecto al respaldo precedente.
- **100% Nativo en Linux:**
  - Sin dependencias de compilación ni librerías de terceros (`bash`, `whiptail`, `tar`, `zstd`, `gpg`, `shred`, `rsync`).

---

## Estructura del Proyecto

```text
BackupConfig/
├── backup_manager.sh        # Ejecutable principal (TUI / CLI)
├── config/
│   ├── config.conf          # Configuración general (dispositivo, rutas)
│   └── default_tags.conf    # Catálogo de etiquetas
├── modules.d/               # Recetas individuales de backup (.conf)
├── lib/
│   ├── models/              # Lógica de negocio (device, module, backup, restore, crypto)
│   ├── views/               # Interfaz TUI (whiptail) y formateo ANSI
│   └── controllers/         # Controlador de aplicación y enrutador CLI
├── markers/                 # Archivos testigo (.backup_storage_marker)
├── ESPECIFICACION.md        # Documento formal de especificación técnica (SDD)
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
