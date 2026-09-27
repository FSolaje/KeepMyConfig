# Especificación Funcional: Sistema de Empaquetado y Distribución Automatizada (Sub-Hito 12.5)

> **Módulo:** Empaquetado, Instalación sin Privilegios y Distribución para Releases  
> **Rama GitFlow:** `dev/feature/packaging-distribution`  
> **Estado:** Borrador de Especificación Técnica  
> **Objetivo:** Definir la arquitectura, requerimientos, validaciones y procedimientos para generar artefactos de distribución reproducibles, instalables sin privilegios (`sudo`) e integrados en GitHub Releases para Lliurex 25 / Ubuntu 24.04 LTS.

---

## 1. Contexto y Objetivos de Negocio

KeepMyConfig ha consolidado su arquitectura interna (MVC en Bash), su sistema de perfiles y plantillas, su motor de cifrado y purga segura, su almacenamiento universal y su interfaz de usuario híbrida (TUI con temas y CLI Headless).

Para su adopción práctica en institutos de secundaria, centros educativos DAW de la Comunitat Valenciana y estaciones de trabajo personales, es imprescindible proporcionar un **sistema de entrega y distribución autónomo y estándar** que permita:

1. **Generación Reproducible de Paquetes (`scripts/package.sh`):** Empaquetar la aplicación oficial en archivos comprimidos (`.tar.gz` y opcional `.tar.zst`) con cálculo de sumas criptográficas `SHA256SUMS.txt`, excluyendo de forma terminante código de desarrollo, pruebas, cachés y secretos.
2. **Estructura Segura Anti-Tarbomb:** Garantizar que todo paquete distribuible se extraiga dentro de un directorio raíz unificado `KeepMyConfig-v<VERSION>/` para evitar la dispersión caótica de ficheros al descomprimir.
3. **Instalador sin Privilegios (`install.sh`):** Permitir la instalación desatendida o asistida por parte de cualquier usuario estándar sin necesidad de `sudo`, desplegando la aplicación en cumplimiento de los estándares XDG (`~/.local/share/KeepMyConfig`, enlace ejecutable en `~/.local/bin/keepmyconfig` y lanzador de escritorio en `~/.local/share/applications/keepmyconfig.desktop`).
4. **Desinstalador Limpio (`uninstall.sh`):** Facilitar la retirada completa de la aplicación, sus enlaces y su lanzador, con opción de salvaguarda o purga de configuraciones.
5. **Automatización de Releases en GitHub Actions (`.github/workflows/release.yml`):** Reutilizar el script de empaquetado oficial dentro del workflow de CI/CD para que cada nuevo tag SemVer adjunte de forma idéntica los artefactos comprimidos y sus sumas de verificación.
6. **Distribución Dual (Instalable vs. Portable):** Producir dos ediciones oficiales diferenciadas en cada Release:
   - **Edición Instalable (`KeepMyConfig-v<VERSION>.tar.gz`):** Diseñada para integración completa en el sistema operativo mediante `install.sh` (menú de aplicaciones, icono SVG, lanzador `.desktop` y binario en `~/.local/bin/keepmyconfig`).
   - **Edición Portable Autónoma (`KeepMyConfig-v<VERSION>-portable.tar.gz`):** Diseñada para ejecución directa e inmediata desde cualquier carpeta o almacenamiento extraíble (SSD, pendrive USB) sin requerir instalación, con lanzador de conveniencia `keepmyconfig.sh` y marcador `.portable`.

---

## 2. Requerimientos Funcionales (FR)

### 2.1. Lista Blanca de Distribución (FR-PKG-001)
El paquete de distribución debe incluir **exclusivamente** los archivos y carpetas esenciales de producción:

| Archivo / Directorio | Permisos Requeridos | Propósito en Producción |
| :--- | :---: | :--- |
| `backup_manager.sh` | `0755` (`rwxr-xr-x`) | Entrypoint ejecutable principal (TUI / CLI). |
| `install.sh` | `0755` (`rwxr-xr-x`) | Script de instalación desatendida / asistida (solo en paquete estándar). |
| `uninstall.sh` | `0755` (`rwxr-xr-x`) | Script de desinstalación limpia (solo en paquete estándar). |
| `keepmyconfig.sh` | `0755` (`rwxr-xr-x`) | Lanzador de conveniencia portable (solo en paquete portable). |
| `.portable` | `0644` (`rw-r--r--`) | Marcador de entorno portable autónomo (solo en paquete portable). |
| `lib/` | `0755` (dirs) / `0644` (sh) | Modelos (`lib/models/`), Vistas (`lib/views/`) y Controlador (`lib/controllers/`). |
| `config/config.conf` | `0644` (`rw-r--r--`) | Configuración predeterminada de fábrica. |
| `config/default_tags.conf`| `0644` (`rw-r--r--`) | Catálogo oficial de etiquetas. |
| `templates.d/` | `0755` (dirs) / `0644` (conf) | Catálogo de recetas predefinidas y plantilla canónica `template-skeleton.conf`. |
| `modules.d/` | `0755` (`rwxr-xr-x`) | Directorio limpio para recetas activas (vacío de fábrica, preservado con `.gitkeep` si aplica). |
| `profiles/default/profile.conf` | `0644` (`rw-r--r--`) | Definición física del perfil predeterminado persistente con auto-healing. |
| `markers/.backup_storage_marker`| `0644` (`rw-r--r--`) | Archivo testigo de seguridad anti-escritura fantasma. |
| `.backup_app_marker` | `0644` (`rw-r--r--`) | Marcador de integridad de instalación de la aplicación. |
| `assets/keepmyconfig.svg` | `0644` (`rw-r--r--`) | Icono vectorial oficial de la aplicación. |
| `assets/keepmyconfig.desktop` | `0644` (`rw-r--r--`) | Plantilla de lanzador de escritorio Freedesktop. |
| `README.md` | `0644` (`rw-r--r--`) | Manual rápido e información del proyecto. |
| `MANUAL_USUARIO.md` | `0644` (`rw-r--r--`) | Manual exhaustivo de usuario y administración. |
| `CHANGELOG.md` | `0644` (`rw-r--r--`) | Registro histórico de versiones SemVer. |
| `LICENSE` | `0644` (`rw-r--r--`) | Licencia del proyecto. |

#### Lista Negra de Exclusión Terminante:
Queda estrictamente prohibida la inclusión de:
- Control de versiones: `.git/`, `.gitignore`, `.github/`.
- Reglas y agentes IA: `.agents/`.
- Especificaciones SDD: `specs/`.
- Suites de pruebas: `tests/`.
- Espacios privados y herramientas locales: `user_data/`.
- Artefactos temporales o cachés: `*.tmp`, `*~`, `*.bak`, `*.swp`, `build/`, `dist/`.

---

### 2.2. Garantía Anti-Tarbomb (FR-PKG-002)
- El archivo comprimido generado debe tener la estructura unificada:
  - Paquete estándar: `KeepMyConfig-v<VERSION>/`
  - Paquete portable: `KeepMyConfig-v<VERSION>-portable/`
- Al ejecutar `tar -xzf KeepMyConfig-v0.1.0-alpha.2.tar.gz` o `tar -xzf KeepMyConfig-v0.1.0-alpha.2-portable.tar.gz`, todos los archivos deben quedar confinados en su respectiva carpeta raíz, sin volcar ningún fichero suelto en el directorio de trabajo.

---

### 2.3. Script de Empaquetado `scripts/package.sh` (FR-PKG-003)
- **Sintaxis:**
  ```bash
  scripts/package.sh [--version <vX.Y.Z>] [--output-dir <ruta>] [--clean] [--type all|standard|portable] [--skip-tests]
  ```
- **Detección Automática de Versión:**
  1. Si se pasa `--version`, toma ese valor (validando formato `vX.Y.Z[-pre]`).
  2. Si no se pasa, intenta extraer el tag anotado actual de Git (`git describe --tags --exact-match 2>/dev/null`).
  3. Si no hay tag exacto, extrae la última versión documentada en `CHANGELOG.md` o el tag más reciente (`git describe --tags --abbrev=0`).
- **Proceso de Empaquetado Dual:**
  1. Limpia y crea directorios temporales de staging en un entorno seguro (`mktemp -d`).
  2. Si `--type all` (por defecto) o `--type standard`, construye el paquete estándar con `install.sh` y `uninstall.sh`.
  3. Si `--type all` (por defecto) o `--type portable`, construye el paquete portable con lanzador `keepmyconfig.sh`, marcador `.portable` y sin instalador.
  4. Normaliza permisos: `chmod 755` para ejecutables y directorios; `chmod 644` para configuraciones, plantillas y documentación.
  5. Genera los tarballs en `.tar.gz` y `.tar.zst` (si `zstd` está disponible).
  6. Calcula las sumas SHA-256 de todos los paquetes producidos y escribe `SHA256SUMS.txt` en el directorio de salida.
  7. **Smoke Test Automatizado:** Descomprime ambos paquetes en carpetas temporales aisladas y valida:
     - Ausencia de tarbomb.
     - Ejecución exitosa de `backup_manager.sh --help` y `keepmyconfig.sh --help`.
     - Presencia de archivos críticos correspondientes a cada edición.
     - Ausencia total de archivos de lista negra.
     - Verificación íntegra de `sha256sum -c SHA256SUMS.txt`.

---

### 2.4. Instalador sin Privilegios `install.sh` (FR-PKG-004)
- **Filosofía Non-Root:** Debe ejecutarse íntegramente como usuario estándar sin requerir jamás `sudo`.
- **Rutas de Instalación XDG:**
  - Directorio de la aplicación: `~/.local/share/KeepMyConfig`
  - Enlace simbólico en el PATH: `~/.local/bin/keepmyconfig -> ~/.local/share/KeepMyConfig/backup_manager.sh`
  - Lanzador de escritorio: `~/.local/share/applications/keepmyconfig.desktop`
  - Icono de la aplicación: `~/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg`
- **Comprobación y Asistencia de `$PATH`:**
  - Verifica si `~/.local/bin` forma parte del `$PATH` activo.
  - Si no está presente, informa amigablemente al usuario con las instrucciones exactas para añadirlo a su `~/.bashrc` (`export PATH="$HOME/.local/bin:$PATH"`).
- **Protección de Configuraciones Existentes:**
  - Si `~/.local/share/KeepMyConfig/config/config.conf` ya existe de una instalación previa, el instalador no lo destruye ni sobrescribe a menos que se invoque con `--force`.
- **Modos de Instalación:**
  - Asistido (por defecto): Muestra banners ANSI y solicita confirmación.
  - Desatendido (`-y`, `--yes`, `--silent`): Instala directamente sin pausas, ideal para scripts de automatización de aula.

---

### 2.5. Lanzador de Escritorio `.desktop` (FR-PKG-005)
- Archivo Freedesktop estándar para permitir abrir KeepMyConfig desde el menú de aplicaciones del entorno de escritorio (GNOME, XFCE de Lliurex, MATE, KDE):
  ```ini
  [Desktop Entry]
  Version=1.0
  Type=Application
  Name=KeepMyConfig
  GenericName=Gestor de Backup y Recuperación
  Comment=Copias de seguridad y recuperación modular para terminal
  Exec=x-terminal-emulator -e keepmyconfig
  Icon=keepmyconfig
  Terminal=true
  Categories=Utility;Archiving;System;
  Keywords=backup;copia;seguridad;lliurex;configuracion;
  StartupNotify=false
  ```
- Soporte para emuladores de terminal comunes (`x-terminal-emulator`, `gnome-terminal`, `ptyxis`, `konsole`, `xterm`).

---

### 2.6. Desinstalador Limpio `uninstall.sh` (FR-PKG-006)
- Permite retirar la aplicación desplegada:
  - Elimina el binario `~/.local/bin/keepmyconfig`.
  - Elimina el lanzador `~/.local/share/applications/keepmyconfig.desktop`.
  - Elimina el icono instalado.
  - Pregunta al usuario si desea eliminar también la carpeta de aplicación `~/.local/share/KeepMyConfig/` (con opción de conservar perfiles locales o purgarlo todo con `--purge`).

---

### 2.7. Integración en CI/CD con GitHub Actions (FR-PKG-007)
- El workflow `.github/workflows/release.yml` debe invocar directamente `scripts/package.sh --version "${TAG}"`.
- Debe adjuntar como artefactos oficiales de la Release:
  - `KeepMyConfig-${TAG}.tar.gz` (y `.tar.zst` si aplica)
  - `KeepMyConfig-${TAG}-portable.tar.gz` (y `.tar.zst` si aplica)
  - `SHA256SUMS.txt`

---

### 2.8. Edición Portable Autónoma (FR-PKG-008)
- **Propósito:** Permitir al usuario ejecutar KeepMyConfig inmediatamente tras descomprimir en cualquier carpeta o soporte extraíble (pendrive USB, disco duro externo, carpeta compartida) sin requerir instalación en el sistema operativo ni permisos de superusuario.
- **Estructura Interna:**
  - Archivo marcador `.portable` en la raíz de la carpeta de la aplicación.
  - Script lanzador `keepmyconfig.sh` (ejecutable `0755`) que redirige de forma transparente la ejecución a `./backup_manager.sh "$@"`.
  - No contiene scripts de instalación del sistema (`install.sh` ni `uninstall.sh`).
- **Comportamiento en Modo Portable:**
  - Si `.portable` está presente, KeepMyConfig reconoce que se está ejecutando desde un medio autónomo.
  - Puede sugerir o preconfigurar el almacenamiento dentro de la propia carpeta o dispositivo portador (`./storage` o `../Backups`), garantizando que las copias viajen con la propia unidad sin contaminar el `$HOME` del equipo anfitrión.

---

## 3. Matriz de Entradas, Salidas y Códigos de Retorno

### Códigos de Salida de `scripts/package.sh`:
- `0`: Empaquetado exitoso, sumas calculadas y smoke test superado.
- `1`: Error en parámetros o argumentos inválidos.
- `2`: Error de integridad (falta un archivo de la lista blanca en el repositorio).
- `3`: Fallo en la creación del archivo comprimido (`tar`).
- `4`: Fallo en el smoke test de validación del paquete.

### Códigos de Salida de `install.sh`:
- `0`: Instalación completada con éxito.
- `1`: Error de permisos, directorios o cancelación por el usuario.
- `2`: Dependencias faltantes del sistema no satisfechas.

---

## 4. Casos Borde y Criterios de Aceptación

1. **Sin git instalado o sin conexión:** `scripts/package.sh` debe ser capaz de empaquetar si se le proporciona la versión por argumento `--version v0.1.0-alpha.2`.
2. **Espacios en rutas:** Tanto `package.sh` como `install.sh` deben soportar rutas que contengan espacios o caracteres especiales en `$HOME` o en el directorio temporal.
3. **Ausencia de `x-terminal-emulator`:** Si no existe el enlace alternativo de Debian/Ubuntu para terminales, el instalador detectará `gnome-terminal`, `ptyxis`, `konsole`, `xfce4-terminal` o `xterm` para ajustar la directiva `Exec=` del `.desktop`.
4. **Instalación idempotente:** Ejecutar `install.sh` múltiples veces debe actualizar los binarios y librerías sin corromper ni borrar las recetas del usuario.
