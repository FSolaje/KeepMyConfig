# Manual de Usuario y Administración: KeepMyConfig

> **Versión:** 0.1.0-alpha.2 (Early Alpha)  
> **Sistema Operativo Objetivo:** Lliurex 25 / Ubuntu 24.04 LTS  
> **Privilegios:** Usuario estándar sin privilegios (`non-root`, sin `sudo`)  
> **Arquitectura:** Modelo-Vista-Controlador (MVC) en Bash 5+  

> [!CAUTION]
> ### ⚠️ AVISO CRÍTICO: VERSIÓN ALFA TEMPRANA — SOFTWARE EN DESARROLLO EXPERIMENTAL
> **KeepMyConfig se encuentra actualmente en fase ALFA de desarrollo activo (`v0.1.0-alpha.X`).**
>
> 🛑 **RIESGO REAL Y POTENCIAL DE PÉRDIDA IRREVERSIBLE DE DATOS:**
> - Esta versión **contiene errores conocidos y bugs activos**, especialmente en la resolución y validación de rutas de almacenamiento en unidades externas, anidamiento de subdirectorios y asignación de destinos en perfiles.
> - La aplicación incorpora rutinas de **purga segura destructiva e irrecuperable** mediante el comando `shred -u -z -n 3` (destinado a eliminar credenciales y claves locales tras el respaldo). Si se produce una anomalía en la ruta de destino, o si una copia se genera de forma anómala, **los archivos de origen locales pueden resultar destruidos permanentemente sin posibilidad de recuperación**.
>
> 📋 **DIRECTRICES OBLIGATORIAS DE USO:**
> 1. **NO UTILIZAR EN ENTORNOS DE PRODUCCIÓN:** Bajo ninguna circunstancia emplee esta versión con datos reales, críticos o de producción.
> 2. **COPIAS DE SEGURIDAD PREVIAS EXTERNAS:** No utilice este software con ningún archivo o directorio sin disponer previamente de una copia de seguridad externa independiente, aislada y verificada.
> 3. **PROBAR EXCLUSIVAMENTE EN MODO SANDBOX:** Para evaluar o probar el software, utilice siempre el modo aislado de pruebas:
>    ```bash
>    keepmyconfig --test-mode
>    ```
>    o configure rutas de prueba ficticias en entornos no críticos.
>
> ⚖️ **EXENCIÓN DE RESPONSABILIDAD:**
> El software se proporciona "tal cual", sin garantía de ningún tipo, expresa o implícita. Los autores y colaboradores no se hacen responsables de ninguna pérdida de datos, daños a sistemas de archivos, corrupción de información o interrupciones operativas derivadas de su uso.

---

## Tabla de Contenidos

1. [Capítulo 1: Introducción, Arquitectura y Requisitos](#capítulo-1-introducción-arquitectura-y-requisitos)
   - [1.1 Contexto y Propósito](#11-contexto-y-propósito)
   - [1.2 Principio de Ejecución sin Privilegios (Non-Root)](#12-principio-de-ejecución-sin-privilegios-non-root)
   - [1.3 Pila Tecnológica y Dependencias](#13-pila-tecnológica-y-dependencias)
   - [1.4 Verificación Rápida del Sistema](#14-verificación-rápida-del-sistema)
2. [Capítulo 2: Instalación, Integración Freedesktop y Modalidades de Despliegue](#capítulo-2-instalación-integración-freedesktop-y-modalidades-de-despliegue)
   - [2.1 Modalidades Oficiales de Distribución](#21-modalidades-oficiales-de-distribución)
   - [2.2 Instalador sin Privilegios (`install.sh`) e Integración en el Escritorio](#22-instalador-sin-privilegios-installsh-e-integración-en-el-escritorio)
   - [2.3 Parámetros CLI para Instalación Desatendida](#23-parámetros-cli-para-instalación-desatendida)
   - [2.4 Endurecimiento Preventivo de Permisos UNIX (Read-Only Hardening)](#24-endurecimiento-preventivo-de-permisos-unix-read-only-hardening)
   - [2.5 Edición Portable Plug & Play para Unidades Externas](#25-edición-portable-plug--play-para-unidades-externas)
   - [2.6 Desinstalador Limpio y Purga de Datos (`uninstall.sh`)](#26-desinstalador-limpio-y-purga-de-datos-uninstallsh)
3. [Capítulo 3: Modos de Uso - Interfaz Interactiva TUI y Línea de Comandos CLI](#capítulo-3-modos-de-uso---interfaz-interactiva-tui-y-línea-de-comandos-cli)
   - [3.1 Interfaz Interactiva TUI (`whiptail`)](#31-interfaz-interactiva-tui-whiptail)
     - [3.1.1 Inicio de la Interfaz Gráfica de Terminal](#311-inicio-de-la-interfaz-gráfica-de-terminal)
     - [3.1.2 Esquema de la Arquitectura Universal TUI](#312-esquema-de-la-arquitectura-universal-tui)
     - [3.1.3 Recorrido Detallado por los 7 Menús](#313-recorrido-detallado-por-los-7-menús)
     - [3.1.4 Preferencias y Personalización Visual (Temas `NEWT_COLORS`)](#314-preferencias-y-personalización-visual-temas-newt_colors)
     - [3.1.5 El Flujo "Vault & Shred" y Pre-Flight Safety Gate](#315-el-flujo-vault--shred-y-pre-flight-safety-gate)
   - [3.2 Interfaz de Comandos CLI (Headless y Automatización)](#32-interfaz-de-comandos-cli-headless-y-automatización)
     - [3.2.1 Sintaxis General y Operaciones Inmediatas](#321-sintaxis-general-y-operaciones-inmediatas)
     - [3.2.2 Tabla Exhaustiva de Opciones CLI](#322-tabla-exhaustiva-de-opciones-cli)
     - [3.2.3 Automatización Desatendida con `PASSPHRASE`](#323-automatización-desatendida-con-passphrase)
     - [3.2.4 Integración con Tareas Programadas (`cron`)](#324-integración-con-tareas-programadas-cron)
     - [3.2.5 Tabla de Códigos de Salida UNIX](#325-tabla-de-códigos-de-salida-unix)
   - [3.3 Entorno de Pruebas y Desarrollo (Modo Sandbox)](#33-entorno-de-pruebas-y-desarrollo-modo-sandbox)
     - [3.3.1 Activación del Modo Sandbox](#331-activación-del-modo-sandbox)
     - [3.3.2 Home Virtual de Pruebas y Aislamiento de Rutas](#332-home-virtual-de-pruebas-y-aislamiento-de-rutas)
     - [3.3.3 Indicadores Visuales y Trazabilidad](#333-indicadores-visuales-y-trazabilidad)
     - [3.3.4 Purga y Reseteo (`--clean-sandbox`)](#334-purga-y-reseteo---clean-sandbox)
4. [Capítulo 4: Preparación y Gestión del Almacenamiento (`BACKUP_DESTINATION`)](#capítulo-4-preparación-y-gestión-del-almacenamiento-backup_destination)
   - [4.1 El Mecanismo de Seguridad Safety Marker](#41-el-mecanismo-de-seguridad-safety-marker)
   - [4.2 Inicialización del Almacenamiento y Asistente de Onboarding](#42-inicialización-del-almacenamiento-y-asistente-de-onboarding)
   - [4.3 Detección de Discos Externos, Rutas Locales y Notación `@media/...`](#43-detección-de-discos-externos-rutas-locales-y-notación-medialabel)
   - [4.4 Convención Zero-Config por Perfil](#44-convención-zero-config-por-perfil)
   - [4.5 Configuración Central (`config/config.conf`)](#45-configuración-central-configconfigconf)
5. [Capítulo 5: Catálogo de Recetas, Plantillas y Perfiles](#capítulo-5-catálogo-de-recetas-plantillas-y-perfiles)
   - [5.1 Estructura Declarativa de una Receta](#51-estructura-declarativa-de-una-receta)
   - [5.2 Directivas Soportadas](#52-directivas-soportadas)
   - [5.3 Ejemplos Oficiales de Producción](#53-ejemplos-oficiales-de-producción)
   - [5.4 Hooks Post-Restauración (`POST_RESTORE_HOOK`)](#54-hooks-post-restauración-post_restore_hook)
   - [5.5 Asistente Interactivo de Edición y Conmutación de Estado (`[ON]` / `[OFF]`)](#55-asistente-interactivo-de-edición-y-conmutación-de-estado-on--off)
   - [5.6 Sistema de Perfiles de Backup y Scoped Modules](#56-sistema-de-perfiles-de-backup-y-scoped-modules)
   - [5.7 Biblioteca de Plantillas (`templates.d/`), Ficha Técnica y Resolución de Colisiones](#57-biblioteca-de-plantillas-templatesd-ficha-técnica-y-resolución-de-colisiones)
   - [5.8 Gestión de Exclusiones en Perfiles (`DISABLED_MODULES`)](#58-gestión-de-exclusiones-en-perfiles-disabled_modules)
6. [Capítulo 6: Auditoría, Logs y Resolución de Problemas (Troubleshooting)](#capítulo-6-auditoría-logs-y-resolución-de-problemas-troubleshooting)
   - [6.1 Árbol de Directorios en la Unidad Externa](#61-árbol-de-directorios-en-la-unidad-externa)
   - [6.2 Registro Histórico y Manifiestos de Integridad](#62-registro-histórico-y-manifiestos-de-integridad)
   - [6.3 Matriz de Resolución de Incidencias](#63-matriz-de-resolución-de-incidencias)
7. [Apéndice A: Política de Versionado (SemVer), Tags y Publicación en GitHub](#apéndice-a-política-de-versionado-semver-tags-y-publicación-en-github)
   - [A.1 Estándar SemVer 2.0.0 y Reglas de Incremento](#a1-estándar-semver-200-y-reglas-de-incremento)
   - [A.2 Ciclo de Pre-Releases (Alfa, Beta, RC)](#a2-ciclo-de-pre-releases-alfa-beta-rc)
   - [A.3 Publicación de Releases en GitHub desde Tags de Git](#a3-publicación-de-releases-en-github-desde-tags-de-git)
   - [A.4 Registro de Cambios (`CHANGELOG.md`)](#a4-registro-de-cambios-changelogmd)
8. [Apéndice B: Script Reproducible de Empaquetado (`scripts/package.sh`) y Checksums](#apéndice-b-script-reproducible-de-empaquetado-scriptspackagesh-y-checksums)
   - [B.1 Modos de Compilación y Flags CLI](#b1-modos-de-compilación-y-flags-cli)
   - [B.2 Garantías Anti-Tarbomb y Lista Blanca Estricta](#b2-garantías-anti-tarbomb-y-lista-blanca-estricta)
   - [B.3 Normalización de Permisos UNIX y Firmas SHA-256](#b3-normalización-de-permisos-unix-y-firmas-sha-256)

---

## Capítulo 1: Introducción, Arquitectura y Requisitos

### 1.1 Contexto y Propósito

En entornos educativos basados en **Lliurex 25 / Ubuntu 24.04 LTS** (como aulas informáticas de Formación Profesional o institutos de secundaria), los equipos suelen estar sujetos a congelación de disco (sistemas de restauración automática de aula) o reinstalaciones periódicas. Esto ocasiona la pérdida recurrente de:
- Entornos de desarrollo locales (configuración de VSCode, extensiones, perfiles de terminal).
- Credenciales temporales, claves SSH para repositorios Git y tokens de acceso.
- Configuraciones de shell (`.bashrc`, `.bash_aliases`, scripts personales en `~/bin`).

**KeepMyConfig** ha sido diseñado para resolver este problema permitiendo a docentes y alumnos:
1. Respaldar selectivamente sus herramientas y configuraciones a una unidad externa (SSD o pendrive USB) o carpeta local persistente.
2. Proteger con cifrado militar (GPG AES-256) cualquier dato privado o llave de seguridad.
3. Purgar del ordenador del aula los datos sensibles mediante borrado seguro irrecuperable (`shred -u`), eliminando el riesgo de que otros alumnos o usuarios accedan a sus credenciales.
4. Restaurar el entorno completo en cuestión de segundos al iniciar sesión en cualquier equipo.

> [!WARNING]
> **ADVERTENCIA DE SEGURIDAD DURANTE LA FASE ALFA:**
> Al estar en fase alfa, se recomienda enfáticamente desactivar la purga automática (`PURGE_AFTER_BACKUP=false`) en las recetas de módulos sensibles hasta verificar que la ruta de almacenamiento en su unidad externa resuelve de forma exacta y sin duplicidades. Nunca opere sobre credenciales o llaves SSH únicas sin un respaldo externo preexistente.

---

### 1.2 Principio de Ejecución sin Privilegios (Non-Root)

> [!IMPORTANT]
> **KeepMyConfig no requiere ni debe ejecutarse con `sudo`**.
> Todas las operaciones se realizan exclusivamente dentro del espacio de usuario (`$HOME`) y en los puntos de montaje externos del usuario (`/media/$USER/...`).

Esto garantiza:
- **Seguridad del aula:** No altera ficheros del sistema operativo ni requiere contraseñas de administración.
- **Portabilidad:** Funciona idénticamente en cualquier estación de trabajo del aula o en el portátil personal del docente.
- **Preservación de permisos:** Los ficheros restaurados conservan la propiedad exacta del usuario sin riesgos de corrupción por permisos de `root`.

---

### 1.3 Pila Tecnológica y Dependencias

La aplicación está construida en **Bash puro** bajo un diseño desacoplado **MVC**:
- **Modelos (`lib/models/`):** Lógica de negocio (detección de discos, empaquetado, cifrado GPG, análisis de recetas).
- **Vistas (`lib/views/`):** Presentación TUI (`whiptail`) y CLI formateado (`ansi_view.sh`).
- **Controlador (`lib/controllers/`):** Orquestación, validación, Pre-Flight Safety Gate y enrutamiento de peticiones.

Las herramientas requeridas son utilidades estándar del sistema:

| Utilidad | Paquete Ubuntu/Lliurex | Propósito |
| :--- | :--- | :--- |
| `whiptail` | `whiptail` | Interfaz gráfica conversacional en terminal (TUI) |
| `gpg` | `gnupg` | Cifrado simétrico AES-256 de módulos sensibles |
| `tar` | `tar` | Empaquetado conservando rutas y permisos |
| `zstd` | `zstd` | Compresión de alta velocidad y rendimiento |
| `coreutils` | `coreutils` | `shred` (purga segura), `sha256sum`, `lsblk` |

---

### 1.4 Verificación Rápida del Sistema

Para comprobar la presencia de las herramientas necesarias antes de la instalación, puede ejecutar:

```bash
for cmd in whiptail gpg tar zstd shred lsblk sha256sum; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "[\e[32mOK\e[0m] Herramienta '$cmd' disponible."
    else
        echo -e "[\e[31mFALLO\e[0m] Herramienta '$cmd' NO encontrada."
    fi
done
```

Si falta alguna dependencia en Ubuntu o Lliurex (por ejemplo `zstd` o `whiptail`), instálela con:
```bash
sudo apt update && sudo apt install -y whiptail gnupg tar zstd
```

---

## Capítulo 2: Instalación, Integración Freedesktop y Modalidades de Despliegue

### 2.1 Modalidades Oficiales de Distribución

KeepMyConfig se publica en [GitHub Releases](https://github.com/FSolaje/KeepMyConfig/releases) en dos modalidades complementarias:

1. **Edición Estándar (`KeepMyConfig-vX.Y.Z.tar.gz` o `.tar.zst`):**
   - Paquete de instalación para cuentas de usuario en estaciones de trabajo y portátiles.
   - Incluye el instalador automatizado `install.sh`, desinstalador `uninstall.sh`, icono vectorial y lanzador de escritorio.
2. **Edición Portable Autónoma (`KeepMyConfig-vX.Y.Z-portable.tar.gz` o `.tar.zst`):**
   - Paquete autónomo *plug-and-play* diseñado para ejecutarse directamente desde unidades externas (pendrives o discos SSD) formateadas en FAT32, exFAT o NTFS.
   - Incluye el marcador `.portable` y el lanzador directo ejecutable `keepmyconfig.sh`.

---

### 2.2 Instalador sin Privilegios (`install.sh`) e Integración en el Escritorio

El script `install.sh` despliega la aplicación de forma limpia en el espacio del usuario sin requerir permisos de superusuario (`sudo`).

#### Flujo Interactivo con Asistente de Primera Instalación (OOBE)
Al ejecutar `./install.sh` sin argumentos, el instalador presenta un asistente interactivo:
1. **Detección y confirmación de rutas:** Propone por defecto `~/.local/share/KeepMyConfig` para la aplicación y `~/.local/bin` para el enlace ejecutable.
2. **Selección interactiva del destino de backups:** Detecta automáticamente unidades externas conectadas y ofrece fijar una ruta local (`~/Backups/KeepMyConfig`) o un disco externo, desplegando de inmediato el marcador de seguridad `.backup_storage_marker`.
3. **Definición del perfil inicial:** Permite seleccionar el perfil canónico `default` o crear un perfil personalizado con su estructura canónica de configuración.
4. **Detección inteligente de la terminal gráfica:** Detecta emuladores instalados (`ptyxis`, `gnome-terminal`, `konsole`, `xfce4-terminal`, `x-terminal-emulator`) para que el lanzador de escritorio abra una ventana de terminal interactiva con `whiptail`.
5. **Instalación de artefactos de escritorio:**
   - Enlace ejecutable: `~/.local/bin/keepmyconfig` apuntando a `~/.local/share/KeepMyConfig/backup_manager.sh`.
   - Icono vectorial SVG oficial: `~/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg`.
   - Lanzador Freedesktop: `~/.local/share/applications/keepmyconfig.desktop` (permitiendo abrir la aplicación desde el menú de inicio de GNOME, KDE, XFCE o MATE).

---

### 2.3 Parámetros CLI para Instalación Desatendida

Para entornos de despliegue automatizado o scripts de aprovisionamiento de aulas:

```bash
./install.sh [OPCIONES]

Opciones:
  -y, --yes, --silent        Modo desatendido (no solicita confirmación interactiva)
  -t, --target-dir <dir>     Directorio de instalación (por defecto: ~/.local/share/KeepMyConfig)
  -b, --bin-dir <dir>        Directorio para el enlace ejecutable (por defecto: ~/.local/bin)
  -d, --backup-dest <dir>    Ruta de almacenamiento de backups (inicializa con marcador)
  -p, --initial-profile <id> Perfil inicial a configurar como activo (por defecto: default)
  -f, --force                Sobrescribir archivos del núcleo sin confirmación
  -h, --help                 Mostrar ayuda de instalación y salir
```

Ejemplo de instalación desatendida completa:
```bash
./install.sh --yes \
  --backup-dest "/media/$USER/DISCO_BACKUP/Backups/KeepMyConfig" \
  --initial-profile "docente"
```

---

### 2.4 Endurecimiento Preventivo de Permisos UNIX (Read-Only Hardening)

Dado que KeepMyConfig está íntegramente desarrollado en Bash y reside en el espacio de usuario, el instalador aplica automáticamente un endurecimiento preventivo de permisos sobre el directorio instalado:

- **Ejecutables del core:** `backup_manager.sh` y `uninstall.sh` se configuran con permisos `0555` (`r-xr-xr-x`).
- **Librerías del motor (MVC):** El directorio `lib/` y sus subcarpetas se fijan en `0555`, y todos los ficheros `.sh` internos en `0444` (`r--r--r--`).
- **Biblioteca de plantillas:** `templates.d/` se fija en `0555` (directorios) y `0444` (ficheros).
- **Directorios de datos mutables del usuario:** `config/`, `modules.d/` y `profiles/` mantienen permisos estándar de lectura y escritura (`0755` para carpetas y `0644` para ficheros), permitiendo crear o editar módulos y perfiles normalmente.

> [!NOTE]
> **Actualizaciones y Reinstalaciones:** `install.sh` y `uninstall.sh` incorporan mecanismos defensivos de desbloqueo (`chmod -R u+w`) que permiten actualizar versiones o reinstalar sin colisiones ni errores de permisos denegados.

---

### 2.5 Edición Portable Plug & Play para Unidades Externas

La Edición Portable está concebida para usuarios que transportan su entorno en un pendrive o disco externo entre distintos ordenadores de aula o departamentos:

1. Descomprima el archivo `KeepMyConfig-vX.Y.Z-portable.tar.gz` en su unidad USB o SSD externo.
2. La carpeta contendrá el marcador `.portable` y el lanzador ejecutable `keepmyconfig.sh`.
3. Ejecute directamente:
   ```bash
   cd /media/$USER/MI_PENDIVE/KeepMyConfig-v0.1.0-alpha.2-portable
   ./keepmyconfig.sh
   ```
4. **Compatibilidad total con sistemas de archivos externos:** El lanzador `keepmyconfig.sh` es un script wrapper directo (no un enlace simbólico UNIX), lo que garantiza su funcionamiento sin errores en unidades formateadas con FAT32, exFAT o NTFS.

---

### 2.6 Desinstalador Limpio y Purga de Datos (`uninstall.sh`)

La aplicación incluye un desinstalador sin privilegios que revierte de forma limpia todas las modificaciones en el sistema:

```bash
~/.local/share/KeepMyConfig/uninstall.sh [OPCIONES]

Opciones:
  -y, --yes, --silent     Modo desatendido (no solicita confirmación interactiva)
  -p, --purge             Eliminar también la carpeta de aplicación, perfiles y configuraciones
  -t, --target-dir <dir>  Directorio de instalación (por defecto: ~/.local/share/KeepMyConfig)
  -b, --bin-dir <dir>     Directorio de ejecutables (por defecto: ~/.local/bin)
  -h, --help              Mostrar ayuda y salir
```

- **Desinstalación estándar (sin `--purge`):** Retira el enlace `~/.local/bin/keepmyconfig`, el lanzador `.desktop` y el icono SVG, pero preserva el directorio `~/.local/share/KeepMyConfig` (con perfiles, recetas y configuraciones intactas para una futura reinstalación).
- **Desinstalación completa con purga (`--purge`):** Desbloquea los permisos y elimina íntegramente `~/.local/share/KeepMyConfig` sin dejar rastros en el equipo.

---

## Capítulo 3: Modos de Uso - Interfaz Interactiva TUI y Línea de Comandos CLI

### 3.1 Interfaz Interactiva TUI (`whiptail`)

#### 3.1.1 Inicio de la Interfaz Gráfica de Terminal

Para iniciar la aplicación interactiva, abra su terminal y ejecute:

```bash
keepmyconfig
```
*(Si no ha realizado la instalación en `$PATH`, puede invocar directamente `./backup_manager.sh` desde el directorio del proyecto).*

---

#### 3.1.2 Esquema de la Arquitectura Universal TUI

KeepMyConfig implementa un modelo de interfaz híbrido estructurado en **un Menú Principal de Acceso Inmediato y 6 Submenús Temáticos Especializados**:

```text
┌────────────────────── KeepMyConfig [Perfil: default] ──────────────────────┐
│                                                                             │
│ [PERFIL: default] | [DESTINO: ~/Backups/KeepMyConfig]                       │
│ [MÓDULOS ACTIVOS: 4/4] | [ESPACIO LIBRE: 124G de 500G]                      │
│                                                                             │
│ Bienvenido al gestor integral de copias y recuperación modular en Bash.     │
│ Seleccione la operación que desea realizar:                                 │
│                                                                             │
│    1) 🚀 [BACKUP]  Ejecutar Respaldo Inmediato (Completo)                   │
│    2) 🔑 [RESTORE] Restauración Rápida de Datos Sensibles (Vault)           │
│    3) 📦 [BACKUP]  Centro de Operaciones de Respaldo...                     │
│    4) ♻️  [RESTORE] Centro de Recuperación y Restauración...                 │
│    5) 🧩 [MODS]    Administración de Módulos y Plantillas...                │
│    6) 👤 [PROFILE] Gestión de Perfiles de Trabajo...                        │
│    7) 💾 [STORAGE] Destinos de Almacenamiento y Diagnóstico...              │
│    8) 🎨 [THEMES]  Preferencias y Personalización Visual...                 │
│    0) 🚪 [SALIR]   Cerrar KeepMyConfig                                      │
│                                                                             │
│                             <Aceptar>      <Cancelar>                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

#### 3.1.3 Recorrido Detallado por los 7 Menús

##### Menú 1: Menú Principal Híbrido (Operaciones Inmediatas)
Diseñado para la máxima agilidad operativa diaria:
- **Opción 1 (`Ejecutar Respaldo Inmediato`):** Lanza el respaldo completo de todos los módulos activos del perfil actual, canalizado a través del *Pre-Flight Safety Gate*.
- **Opción 2 (`Restauración Rápida de Datos Sensibles`):** Al comenzar la jornada, descifra en memoria y restaura en un solo paso las credenciales y llaves confidenciales.
- **Opciones 3 a 8:** Navegan hacia los centros de gestión temática especializada.

##### Submenú 2: Centro de Operaciones de Respaldo
Agrupa todas las modalidades de empaquetado y salvaguarda:
- **1) [BACKUP] Realizar Respaldo Completo:** Procesa todos los módulos activos (`MODULE_ENABLED="true"`).
- **2) [TAG] Respaldo Filtrado por Etiquetas:** Checklist interactivo para seleccionar etiquetas (`dev`, `ide`, `shell`, etc.).
- **3) [MOD] Respaldo de Módulo Individual:** Selector único (*Radiolist*) para respaldar una sola receta.

##### Submenú 3: Centro de Recuperación y Restauración
- **1) [VAULT] Restauración Rápida de Datos Sensibles:** Recupera snapshots confidenciales descifrando mediante tubería segura GPG AES-256.
- **2) [HIST] Restauración Selectiva por Histórico:** Permite elegir un módulo y examinar todos sus puntos en el tiempo (`AAAAMMDD_HHMMSS`) para restaurar versiones exactas.
- **3) [FULL] Restauración Total:** Desempaqueta secuencialmente todas las configuraciones con advertencia previa de los archivos que serán sobrescritos.

##### Submenú 4: Gestión de Perfiles de Trabajo (`profiles/`)
- **1) [INFO] Ver Detalles del Perfil Activo:** Identificador, nombre, descripción y ruta Zero-Config (`<BACKUP_DESTINATION>/<id_perfil>`).
- **2) [SWITCH] Conmutar Perfil Activo:** Cambia el perfil en `config/config.conf` persistiendo la preferencia.
- **3) [NEW] Crear Nuevo Perfil de Backup:** Asistente guiado para nuevos entornos aislados.
- **4) [LIST] Listar Módulos del Perfil:** Muestra las recetas resolviendo la jerarquía con badges `[Global]`, `[Override]` o `[Exclusivo]`.
- **5) [EXCL] Gestionar Exclusiones de Módulos (`DISABLED_MODULES`):** Checklist para deshabilitar módulos globales en perfiles secundarios.
- **6) [DEL] Eliminar Perfil:** Purga segura de la definición de un perfil secundario con **salvaguarda de seguridad estricta** (impide eliminar `default` o el perfil actualmente activo).

##### Submenú 5: Administración de Módulos y Plantillas
- **1) [VIEW] Inspeccionar Módulos:** Muestra rutas, etiquetas, cifrado, purga, ámbito y estado `[ON]` / `[OFF]`.
- **2) [EDIT] ✏️ Modificar un Módulo Existente (Asistente de Edición):**
  - **Bifurcación de Ámbito (*Override*):** Si se edita un módulo global desde un perfil secundario, el asistente consulta si desea modificar la receta global o crear una derivación exclusiva (*override*) en el perfil activo.
  - **Edición Guiada:** Permite actualizar nombre descriptivo, rutas (con captura guiada `whiptail_view_input_paths`), etiquetas (checklist interactivo) y estado.
  - **Sincronización Inteligente de Cifrado:** Si en el checklist se marca `sensitive`, se activa directamente GPG AES-256; si no se marca, se consulta si se desea cifrar y, si se acepta, se incorpora automáticamente la etiqueta `sensitive`.
  - **Consentimiento Activo Obligatorio para Purga:** La opción de purga irreversible con `shred -u` se oferta universalmente tanto para módulos sensibles como no sensibles, requiriendo confirmación activa con foco en `[NO]`.
- **3) [TOGGLE] 🔄 Conmutador Rápido de Estado:** Activa (`[ON]`) o desactiva (`[OFF]`) instantáneamente cualquier módulo sin abrir el editor.
- **4) [ENABLE] 📦 Activar Módulo desde Plantilla:**
  - **Ficha Técnica Previa:** Muestra un resumen técnico detallado antes de confirmar la activación.
  - **Consentimiento de Purga de Fábrica:** Si la plantilla incluye purga (ej. `ssh-keys`), se interroga con foco en `[NO]` si desea mantenerla activa o desactivarla por defecto.
  - **Selector Universal de Ámbito:** Permite elegir entre Catálogo Global (`modules.d/`) o Exclusivo del Perfil Activo (`profiles/<id>/modules.d/`).
  - **Resolución Interactiva de Colisiones:** Si la receta ya existe, abre un menú de 3 opciones: Clonar con nuevo identificador, Sobrescribir restableciendo a la plantilla limpia, o Cancelar.
- **5) [CREATE] Crear Nuevo Módulo:** Asistente interactivo con captura de rutas línea a línea.
- **6) [TMPL-NEW] Redactar Nueva Plantilla:** Diseña recetas directamente en la biblioteca `templates.d/`.
- **7) [EXPORT] Exportar Módulo Activo a Plantilla:** Promueve una receta validada al catálogo reutilizable.
- **8) [DEL] Eliminar Módulo:** Baja definitiva del archivo `.conf` en su carpeta correspondiente.
- **9) [TAG] Registrar Nueva Etiqueta:** Incorporación al catálogo `config/default_tags.conf`.

##### Submenú 6: Gestión de Perfiles de Trabajo
- **1) [INFO] Ver Detalles del Perfil Activo:** Muestra el ID, nombre, descripción, subdirectorio o ruta configurada y módulos activos.
- **2) [SWITCH] Cambiar Perfil Activo:** Selector interactivo para alternar el perfil activo del sistema.
- **3) [CREATE] Crear un Nuevo Perfil:**
  Asistente guiado que solicita identificador, nombre, descripción y destino. Permite tres modalidades de almacenamiento:
  - **Zero-Config (Dejar en blanco):** Asigna automáticamente la convención `<BACKUP_DESTINATION>/<id_perfil>`.
  - **Subcarpeta Relativa (ej: `Trabajo/Docente`):** Se anida limpiamente dentro del almacenamiento base.
  - **Ruta Absoluta Independiente (ej: `/media/usuario/OTRO_DISCO/Backups` o `~/MisBackups`):** Define un destino autónomo fuera del almacenamiento base.
  - **Despliegue Asistido de Marcador:** Si la ruta elegida no contiene `.backup_storage_marker`, el sistema consulta si desea inicializar la carpeta y desplegar el marcador y subdirectorios (`archives/`, `logs/`) en ese mismo instante.
- **4) [LIST] Listar Recetas del Perfil:** Inventario de módulos visibles distinguiendo `[Global]`, `[Exclusivo]` o `[Override]`.
- **5) [EXCL] Gestionar Exclusiones:** Desactiva recetas globales específicamente para el perfil activo (`DISABLED_MODULES`).
- **6) [DEL] Eliminar Perfil:** Borrado definitivo de perfiles secundarios (el perfil `default` está protegido).

##### Submenú 7: Destinos de Almacenamiento y Diagnóstico
- **1) [DIAG] Diagnóstico de Almacenamiento:** Valida la presencia del archivo marcador jerárquico `.backup_storage_marker`, permisos y espacio disponible en disco.
- **2) [DEST] Cambiar Destino Canónico (`BACKUP_DESTINATION`):** Actualización de la directiva universal (rutas locales, absolutas o notación `@media/<LABEL>/...`).
- **3) [WIZARD] Relanzar Asistente de Configuración (Onboarding):** Configuración asistida paso a paso.
- **4) [MARKER] Desplegar Marcador de Seguridad:** Instalación manual del archivo testigo y estructura de directorios.

##### Submenú 8: Preferencias y Personalización Visual
- **1) [THEME] 🎨 Selección de Tema Visual TUI (`NEWT_COLORS`):** Selección de paletas cromáticas.
- **2) [PROFILE] 🧠 Memoria de Sesión (`REMEMBER_LAST_PROFILE`):** Configura si la aplicación arranca en el último perfil utilizado o siempre en `default`.

---

#### 3.1.4 Preferencias y Personalización Visual (Temas `NEWT_COLORS`)

KeepMyConfig permite seleccionar entre 5 temas cromáticos persistidos en `config/config.conf`:
- **`default` (Por Defecto):** Respeta los colores nativos de la terminal configurada por el usuario (tema de fábrica de KeepMyConfig).
- **`midnight` (Medianoche):** Azul profundo de alto contraste nocturno.
- **`cyberdark` (Cibernético):** Verde fluorescente sobre fondo negro estilo terminal de ciberseguridad.
- **`aubergine` (Berenjena):** Tonos magenta y violeta inspirados en la estética moderna de Lliurex / Ubuntu.
- **`amber` (Ámbar):** Resplandor fósforo ámbar clásico estilo monitor monocromático vintage.

---

#### 3.1.5 El Flujo "Vault & Shred" y Pre-Flight Safety Gate

KeepMyConfig implementa un interceptor mandatorio denominado **Pre-Flight Safety Gate** que se ejecuta antes de cualquier operación de respaldo:

1. **Matriz de Impacto Previo:** Presenta una tabla con todos los módulos a procesar, su ámbito (`[Global]` o `[Perfil]`), si requieren cifrado GPG AES-256, si tienen purga activa y su carpeta destino final.
2. **Alerta Crítica ante Purga Irreversible (`shred -u`):**
   Si la operación incluye módulos con purga activa (como `ssh-keys`), el sistema suspende la ejecución y muestra una advertencia de seguridad destacada:
   - **En TUI (`whiptail`):** Diálogo de alerta con foco predeterminado obligatorio en **`[NO]`** (`--defaultno`), requiriendo que el usuario se desplace deliberadamente a `[SÍ]` para autorizar la destrucción.
   - **En CLI:** Mensaje de peligro enmarcado en fondo rojo `\033[41;97;1m` listando todas las rutas a destruir, requiriendo teclear **`SI`** en mayúsculas y pulsar Enter (salvo uso de `--yes` / `-y`).
3. **Advertencia de Sobreescritura en Restauración:** Antes de desempaquetar archivos en el `$HOME`, lista las rutas existentes que serán sustituidas para evitar pérdidas accidentales de configuraciones recientes.

> [!CAUTION]
> **RESTRICCIÓN EN FASE ALFA PARA PURGA CON SHRED:**
> La purga segura (`shred -u`) destruye físicamente los archivos locales en el equipo. Durante la fase alfa, ante cualquier duda o comportamiento imprevisto en la ruta de copia, **aborte la operación seleccionando `[NO]`** y compruebe previamente el archivo comprimido generado en el disco de respaldo antes de autorizar cualquier eliminación local.

---

### 3.2 Interfaz de Comandos CLI (Headless y Automatización)

#### 3.2.1 Sintaxis General y Operaciones Inmediatas

La interfaz de línea de comandos está optimizada para scripts bash, tareas programadas en segundo plano o usuarios avanzados de terminal:

```bash
keepmyconfig [OPERACIÓN] [MODIFICADORES]
```

Operaciones de uso frecuente:
```bash
# Respaldo completo
keepmyconfig --backup-all

# Respaldo por etiqueta con confirmación desatendida
keepmyconfig --backup-tag dev -y

# Restauración de credenciales matinal
keepmyconfig --restore-sensitive

# Conmutar módulos activos/inactivos
keepmyconfig --disable-module firefox
keepmyconfig --enable-module firefox
```

---

#### 3.2.2 Tabla Exhaustiva de Opciones CLI

| Parámetro | Argumento | Descripción |
| :--- | :--- | :--- |
| `--setup` | *Ninguno* | Inicia el asistente interactivo de configuración inicial (Onboarding Wizard). |
| `--backup-all` | *Ninguno* | Realiza el respaldo de todos los módulos activos del perfil actual. |
| `--backup-tag` | `<tag>` | Respalda únicamente los módulos asociados a la etiqueta `<tag>`. |
| `--backup-module` | `<id>` | Respalda el módulo especificado por su `<id>`. |
| `-y, --yes` | *Ninguno* | Asume confirmación afirmativa en el Pre-Flight Safety Gate (modo desatendido/cron). |
| `--purge` | *Ninguno* | Fuerza la purga segura con `shred -u` tras el backup (ignora directiva de receta). |
| `--no-purge` | *Ninguno* | Desactiva la purga tras el backup aunque la receta la tenga activa. |
| `--restore-sensitive`| *Ninguno* | Restaura todos los módulos sensibles del snapshot más reciente. |
| `--restore-all` | *Ninguno* | Restaura todos los módulos del snapshot más reciente. |
| `--restore-module` | `<id>` | Restaura un módulo específico. |
| `--timestamp` | `<TS>` | *(Opcional)* Especifica la marca de tiempo `AAAAMMDD_HHMMSS` a restaurar. |
| `--check-device` | *Ninguno* | Comprueba la accesibilidad del almacenamiento y el marcador de seguridad en `BACKUP_DESTINATION`. |
| `--profile` | `<id>` | Aplica un perfil específico de forma temporal para la operación actual. |
| `--list-profiles` | *Ninguno* | Lista todos los perfiles de backup configurados en el sistema. |
| `--set-active-profile` | `<id>` | Establece el perfil activo de forma persistente en `config/config.conf`. |
| `--create-profile` | `<id>` | Crea un nuevo perfil de backup (admite `--target-subdir` e `--init-storage`). |
| `--init-storage` | *Ninguno* | Inicializa la carpeta y despliega `.backup_storage_marker` y subcarpetas al crear un perfil. |
| `--list-templates` | *Ninguno* | Lista todas las recetas predefinidas en la biblioteca de plantillas (`templates.d/`). |
| `--enable-template` | `<id>` | Activa la plantilla indicada en el perfil activo (o global si es default). |
| `--as-module` | `<nuevo_id>` | *(Modificador de plantilla)* Instancia la plantilla con un nuevo identificador (clonación). |
| `--force` | *Ninguno* | *(Modificador de plantilla/exportación)* Sobrescribe el módulo destino si ya existe. |
| `--export-template` | `<id>` | Exporta y promueve un módulo activo como nueva plantilla en la biblioteca. |
| `--enable-module` | `<id>` | Activa el estado de un módulo (`[ON]`). |
| `--disable-module` | `<id>` | Desactiva el estado de un módulo (`[OFF]`) excluyéndolo de los respaldos. |
| `--list-modules` | *Ninguno* | Imprime en consola todos los módulos registrados, estado `[ON]`/`[OFF]` y ámbito. |
| `--list-tags` | *Ninguno* | Imprime el catálogo de etiquetas disponibles. |
| `--test-mode, --sandbox` | *Ninguno* | Activa el entorno aislado de pruebas Sandbox (rutas confinadas en `user_data/sandbox/`). |
| `--clean-sandbox` | *Ninguno* | Purga y elimina por completo el entorno aislado `user_data/sandbox/`. |
| `-h, --help` | *Ninguno* | Muestra la ayuda rápida de sintaxis CLI. |

---

#### 3.2.3 Automatización Desatendida con `PASSPHRASE`

Para ejecutar backups o restauraciones de módulos sensibles sin intervención manual:

```bash
# Backup completo desatendido
PASSPHRASE="MiClaveSegura2026" keepmyconfig --backup-all -y

# Restauración exprés de llaves y credenciales desatendida
PASSPHRASE="MiClaveSegura2026" keepmyconfig --restore-sensitive
```

---

#### 3.2.4 Integración con Tareas Programadas (`cron`)

Puede programar la ejecución de una copia de seguridad automática al terminar cada jornada de clase. Abra su crontab:
```bash
crontab -e
```
Añada una regla para ejecutar la copia de lunes a viernes a las 14:30:
```cron
30 14 * * 1-5 ~/.local/bin/keepmyconfig --backup-all -y >> ~/.local/share/KeepMyConfig/storage/logs/backup_cron.log 2>&1
```

---

#### 3.2.5 Tabla de Códigos de Salida UNIX

| Código | Significado | Causa Habitual |
| :---: | :--- | :--- |
| **`0`** | **Éxito (SUCCESS)** | Operación concluida satisfactoriamente. |
| **`1`** | **Error General / Cancelado** | Operación cancelada por el usuario en la TUI o fallo de sintaxis. |
| **`2`** | **Error de Almacenamiento** | SSD no conectado, punto de montaje inaccesible o `.backup_storage_marker` ausente. |
| **`3`** | **Error de Módulo** | El módulo solicitado no existe o el archivo de histórico no fue encontrado. |
| **`4`** | **Error Criptográfico** | Contraseña GPG incorrecta o archivo vault dañado/corrupto. |
| **`5`** | **Argumento Inválido** | Parámetros CLI faltantes o no reconocidos. |
| **`10`** | **Dependencia Faltante** | `whiptail` u otra herramienta indispensable no está instalada en el sistema. |
| **`12`** | **Ruta Recursiva / Duplicada** | Detección de duplicación de base o recursión anómala en la ruta destino. |
| **`14`** | **Salvaguarda Pre-Shred Abortada** | Safe Destruction Gate canceló la purga con shred: archivo ausente, vacío o ruta anómala. |

---

### 3.3 Entorno de Pruebas y Desarrollo (Modo Sandbox)

Para facilitar la verificación manual, desarrollo de nuevas recetas o pruebas de flujos completos sin alterar el repositorio Git ni contaminar los directorios de producción (`config/`, `modules.d/`, `profiles/`), **KeepMyConfig** incorpora el **Modo Sandbox / Test Mode**.

#### 3.3.1 Activación del Modo Sandbox
El modo sandbox puede activarse de tres formas equivalentes:
1. **Flag CLI explícito:**
   ```bash
   keepmyconfig --test-mode
   # o bien:
   keepmyconfig --sandbox
   ```
2. **Combinado con cualquier comando CLI:**
   ```bash
   keepmyconfig --test-mode --backup-all
   keepmyconfig --test-mode --enable-template firefox
   keepmyconfig --test-mode --create-profile docente
   keepmyconfig --test-mode --list-modules
   ```
3. **Variable de entorno:**
   ```bash
   KEEP_MY_CONFIG_TEST_MODE=true keepmyconfig
   ```

#### 3.3.2 Home Virtual de Pruebas y Aislamiento de Rutas
Al activarse, el sistema inicializa de forma transparente una réplica completa del entorno confinado bajo `user_data/sandbox/`:
- **Home Virtual de Pruebas (`user_data/sandbox/home/`):**
  - Confinamiento estricto de `TARGET_USER_HOME="${sandbox_base}/home"`.
  - El sistema siembra automáticamente datos de prueba sintéticos para todas las recetas base:
    - **Bash y Entorno:** `.bashrc`, `.bash_aliases`, `.profile`, `.bash_logout`.
    - **SSH (Vault & Shred):** `.ssh/id_rsa`, `.ssh/id_rsa.pub`, `.ssh/id_ed25519`, `.ssh/id_ed25519.pub`, `.ssh/config`, `.ssh/known_hosts`.
    - **VSCode:** `.config/Code/User/settings.json`, `keybindings.json`, `snippets/bash.json`, `globalStorage/state.vscdb`, `sync/sync_state.json`.
    - **Desarrollo y Navegación:** `.gitconfig`, `.config/git/ignore`, `.mozilla/firefox/testprofile.default/prefs.js`, `.config/JetBrains/IdeaIC2024.1/idea.properties`, `.thunderbird/testprofile.default/prefs.js`, `.config/libreoffice/4/user/registrymodifications.xcu`.
  - **Pruebas Seguras de Purga Sensible (`shred -u`):** Permite verificar en vivo la destrucción irrecuperable de claves y archivos confidenciales sin poner en riesgo jamás los datos reales de `/home/$USER`.
  - **Regeneración Idempotente:** Ante una purga con `--clean-sandbox`, la siguiente invocación con `--test-mode` vuelve a reconstruir el home virtual íntegro con sus archivos semilla originales.
- **Configuración Aislada:** `user_data/sandbox/config/config.conf` (con `INITIAL_SETUP_DONE="true"` y `BACKUP_DESTINATION` apuntando a `user_data/sandbox/storage`).
- **Módulos Aislados:** `user_data/sandbox/modules.d/` (inicia limpio; cualquier plantilla activada o receta creada se escribe aquí sin tocar las carpetas raíz del proyecto).
- **Perfiles Aislados:** `user_data/sandbox/profiles/` (incluye perfil base `profiles/default/profile.conf`).
- **Almacenamiento Aislado:** `user_data/sandbox/storage/` (con su propio marcador `.backup_storage_marker` y subcarpetas `archives/` y `logs/`).

> [!NOTE]
> La carpeta `user_data/` está excluida permanentemente en el archivo `.gitignore`. Ningún archivo generado durante las pruebas en sandbox figurará jamás en `git status`, evitando ensuciar el árbol de trabajo.

#### 3.3.3 Indicadores Visuales y Trazabilidad
- **Interfaz TUI (Whiptail):** El título del menú principal refleja explícitamente el entorno de pruebas:
  ```text
  KeepMyConfig [SANDBOX] [Perfil: default]
  ```
- **Línea de Comandos (CLI):** Cada ejecución emite una advertencia visual formateada:
  ```text
  [AVISO] Ejecutando en MODO TEST / SANDBOX (Rutas aisladas en user_data/sandbox/)
  ```

#### 3.3.4 Purga y Reseteo (`--clean-sandbox`)
Para eliminar por completo el entorno sandbox y liberar espacio:
```bash
keepmyconfig --clean-sandbox
```

---

## Capítulo 4: Preparación y Gestión del Almacenamiento (`BACKUP_DESTINATION`)

### 4.1 El Mecanismo de Seguridad Safety Marker

> [!CAUTION]
> **Prevención de Escrituras Fantasma:** Si una unidad externa se desconecta inesperadamente, el punto de montaje `/media/$USER/MI_DISCO` puede quedar como una carpeta local vacía en el disco raíz del ordenador. Un script de backup tradicional escribiría en el disco interno, saturando la partición del sistema y dejando los datos expuestos localmente.

Para evitar esto, **KeepMyConfig** exige la presencia de un archivo testigo denominado **`.backup_storage_marker`** en la raíz de su carpeta de copias. Si dicho archivo no existe o no contiene la firma válida, el motor detiene de inmediato cualquier operación con código de salida `2`.

---

### 4.2 Inicialización del Almacenamiento y Asistente de Onboarding

KeepMyConfig incluye un **Asistente de Configuración Inicial (Onboarding Wizard)** diseñado para preparar el entorno de copias en menos de un minuto sin necesidad de comandos manuales:

Al ejecutar por primera vez la aplicación (`INITIAL_SETUP_DONE="false"`):
```bash
keepmyconfig
```
El sistema detecta el primer arranque e inicia automáticamente el asistente en pantalla:
1. **Auditoría de hardware y medios montados:** Escanea particiones externas y unidades USB en `/media/$USER/` o `/run/media/$USER/`.
2. **Selección guiada de destino:**
   - **Almacenamiento Local (Por defecto):** Configura `~/Backups/KeepMyConfig`.
   - **Dispositivos Externos Detectados:** Muestra una lista con las memorias USB o discos SSD externos conectados.
   - **Ruta Personalizada:** Permite ingresar manualmente cualquier ruta del sistema o montaje de red.
3. **Despliegue del Marcador de Seguridad:** Crea automáticamente las carpetas `archives/` y `logs/` e instala el archivo testigo `.backup_storage_marker`.
4. **Preferencia de Sesión (`REMEMBER_LAST_PROFILE`):** Pregunta si desea recordar el último perfil utilizado o arrancar siempre en `default`.

---

### 4.3 Detección de Discos Externos, Rutas Locales y Notación `@media/...`

El motor de almacenamiento resuelve rutas relativas, absolutas y semánticas de conveniencia:
- **Ruta relativa a `$HOME`:** `~/Backups/KeepMyConfig` o `$HOME/Copias`.
- **Ruta absoluta:** `/mnt/compartido/backups`.
- **Notación semántica `@media`:** `@media/MI_SSD/Backups` se resuelve automáticamente al punto de montaje activo `/media/$USER/MI_SSD/Backups` o `/run/media/$USER/MI_SSD/Backups`.

---

### 4.4 Convención Zero-Config por Perfil

Todo perfil secundario organiza sus copias de forma transparente en un subdirectorio aislado:
```text
<BACKUP_DESTINATION>/
├── .backup_storage_marker
├── archives/                 # Copias del perfil default
├── logs/
├── docente/                  # Subdirectorio automático para perfil 'docente'
│   ├── archives/
│   └── logs/
└── desarrollo/               # Subdirectorio automático para perfil 'desarrollo'
    ├── archives/
    └── logs/
```
No se requiere configurar rutas adicionales por cada nuevo perfil.

---

### 4.5 Configuración Central (`config/config.conf`)

El archivo de configuración principal se ubica en `config/config.conf` (o en `~/.local/share/KeepMyConfig/config/config.conf` si está instalado):

```ini
# Ubicación universal del repositorio de respaldos
BACKUP_DESTINATION="/media/usuario/SSD_BACKUP/Backups/KeepMyConfig"

# Perfil activo actual
ACTIVE_PROFILE="default"

# Memoria de perfil de la última sesión (true/false)
REMEMBER_LAST_PROFILE="false"

# Tema visual TUI (default, midnight, cyberdark, aubergine, amber)
TUI_THEME="default"

# Estado de inicialización inicial
INITIAL_SETUP_DONE="true"
```

---

## Capítulo 5: Catálogo de Recetas, Plantillas y Perfiles

### 5.1 Estructura Declarativa de una Receta

Cada elemento a respaldar se define en un archivo `.conf` independiente en `modules.d/`:

```bash
MODULE_ID="mi-herramienta"
MODULE_NAME="Mi Herramienta de Trabajo"
MODULE_TAGS=("dev" "tools")
MODULE_PATHS=(
    ".config/mi-herramienta/config.json"
    ".mi-herramienta/plugins"
)
IS_SENSITIVE=false
PURGE_AFTER_BACKUP=false
MODULE_ENABLED=true
POST_RESTORE_HOOK=""
```

---

### 5.2 Directivas Soportadas

| Directiva | Tipo | Obligatorio | Descripción |
| :--- | :---: | :---: | :--- |
| `MODULE_ID` | String | Sí | Identificador alfanumérico único (sin espacios). |
| `MODULE_NAME` | String | Sí | Nombre amigable mostrado en menús y reportes. |
| `MODULE_TAGS` | Array | Sí | Lista de etiquetas para categorización: `("dev" "auth")`. |
| `MODULE_PATHS` | Array | Sí | Rutas de ficheros o carpetas (relativas a `$HOME` o absolutas). |
| `IS_SENSITIVE` | Booleano | Sí | `true` para aplicar cifrado GPG AES-256; `false` para plano. |
| `PURGE_AFTER_BACKUP` | Booleano | No | `true` para activar purga `shred -u` en origen tras el respaldo. |
| `MODULE_ENABLED` | Booleano | No | `true` por defecto. `false` desactiva el módulo (`[OFF]`), excluyéndolo de respaldos automáticos. |
| `POST_RESTORE_HOOK` | Función | No | Bloque Bash ejecutado inmediatamente tras desempaquetar. |

---

### 5.3 Ejemplos Oficiales de Producción

#### 1. Configuración Abierta: `vscode-standard.conf`
```bash
MODULE_ID="vscode-standard"
MODULE_NAME="Visual Studio Code - Configuración y Extensiones"
MODULE_TAGS=("dev" "ide" "vscode")
MODULE_PATHS=(
    ".config/Code/User/settings.json"
    ".config/Code/User/keybindings.json"
    ".config/Code/User/snippets"
    ".vscode/extensions"
)
IS_SENSITIVE="false"
PURGE_AFTER_BACKUP="false"
```

#### 2. Credenciales y Vault con Purga: `ssh-keys.conf`
```bash
MODULE_ID="ssh-keys"
MODULE_NAME="Claves SSH y Configuración Remota"
MODULE_TAGS=("security" "auth" "ssh" "sensitive")
MODULE_PATHS=(
    ".ssh"
)
IS_SENSITIVE="true"
PURGE_AFTER_BACKUP="true"

POST_RESTORE_HOOK() {
    local target_home="${1:-$HOME}"
    if [[ -d "${target_home}/.ssh" ]]; then
        chmod 700 "${target_home}/.ssh"
        chmod 600 "${target_home}/.ssh/id_"* 2>/dev/null || true
        chmod 644 "${target_home}/.ssh/"*.pub 2>/dev/null || true
        chmod 644 "${target_home}/.ssh/known_hosts"* 2>/dev/null || true
    fi
}
```

---

### 5.4 Hooks Post-Restauración (`POST_RESTORE_HOOK`)

> [!TIP]
> Use `POST_RESTORE_HOOK()` para aplicar automáticamente permisos restrictivos (`chmod 600`, `chmod 700`) o recrear enlaces simbólicos tras la restauración de archivos confidenciales. El hook recibe `$1` como la ruta base del `$HOME` de destino.

---

### 5.5 Asistente Interactivo de Edición y Conmutación de Estado (`[ON]` / `[OFF]`)

Desde la TUI (Submenú 5, Opción 2), el Asistente de Edición permite modificar cualquier receta:
- **Bifurcación (*Override*):** Si edita un módulo global desde un perfil secundario, puede elegir entre modificar el original global o crear una versión exclusiva para su perfil.
- **Conmutador Rápido (`[ON]`/`[OFF]`):** Permite activar o desactivar módulos puntualmente sin borrar la receta. En CLI:
  ```bash
  keepmyconfig --enable-module vscode-standard
  keepmyconfig --disable-module firefox
  ```

---

### 5.6 Sistema de Perfiles de Backup y Scoped Modules

Cada perfil reside en `profiles/<perfil_id>/`:
```text
profiles/
├── default/                  # Perfil base permanente con auto-healing
│   └── profile.conf
└── docente/
    ├── profile.conf          # Metadatos del perfil
    └── modules.d/            # Módulos exclusivos o sobrescritos
```

#### Resolución Jerárquica en Cascada
1. **Exclusiones:** Si un módulo global figura en `DISABLED_MODULES`, se omite.
2. **Override:** Si existe en `profiles/<perfil>/modules.d/`, prevalece sobre la versión global.
3. **Exclusivo:** Módulos que solo existen en la carpeta del perfil.
4. **Global:** Recetas en `modules.d/` disponibles para todos los perfiles.

---

### 5.7 Biblioteca de Plantillas (`templates.d/`), Ficha Técnica y Resolución de Colisiones

KeepMyConfig arranca por diseño con **0 módulos activos de inicio** para evitar copias no deseadas.

Catálogo disponible en `templates.d/`: `bash-env.conf`, `firefox.conf`, `git-config.conf`, `intellij.conf`, `libreoffice.conf`, `ssh-keys.conf`, `thunderbird.conf`, `vscode-sensitive.conf`, `vscode-standard.conf` y `template-skeleton.conf`.

#### Activación Asistida:
- Muestra una **Ficha Técnica** con rutas y advertencia de purga.
- Permite seleccionar el ámbito: **Global** (`modules.d/`) o **Perfil Activo** (`profiles/<id>/modules.d/`).
- **Resolución de Colisiones:** Si la receta ya existe, ofrece: Clonar con nuevo nombre (`--as-module <nuevo_id>`), Sobrescribir forzando a la plantilla limpia (`--force`), o Cancelar.

---

### 5.8 Gestión de Exclusiones en Perfiles (`DISABLED_MODULES`)

Para omitir módulos globales en perfiles secundarios sin eliminarlos del sistema, defina en `profile.conf`:
```ini
DISABLED_MODULES=("firefox" "thunderbird")
```
Esto puede gestionarse interactivamente desde la TUI (Submenú 4, Opción 5).

---

## Capítulo 6: Auditoría, Logs y Resolución de Problemas (Troubleshooting)

### 6.1 Árbol de Directorios en la Unidad Externa

```text
<BACKUP_DESTINATION>/
├── .backup_storage_marker                   # Marcador de seguridad obligatorio
├── archives/
│   ├── bash-env_20260920_183000.tar.zst     # Archivo abierto comprimido con zstd
│   ├── ssh-keys_20260920_183000.tar.zst.gpg # Archivo confidencial cifrado con GPG
│   └── vscode-sensitive_20260920_183000.tar.zst.gpg
└── logs/
    ├── backup_history.log                   # Bitácora histórica global
    ├── bash-env_20260920_183000.manifest.log# Manifiesto con hashes SHA-256
    └── bash-env_20260920_183000.diff.log    # Diferencias frente al backup anterior
```

---

### 6.2 Registro Histórico y Manifiestos de Integridad

- **`backup_history.log`:** Registro línea a línea con fecha, módulo, estado y archivo resultante.
- **Manifiesto (`.manifest.log`):** Inventario completo de cada archivo respaldado y su suma SHA-256.
- **Diff (`.diff.log`):** Registro de altas (`+`), modificaciones (`~`) y bajas (`-`) respecto a la copia previa.

---

### 6.3 Matriz de Resolución de Incidencias

#### Caso 1: Error `STORAGE_MARKER_MISSING` (Código de salida `2`)
- **Causa:** La ruta en `BACKUP_DESTINATION` no es accesible, el disco no está montado, o falta `.backup_storage_marker`.
- **Solución:**
  1. Ejecute `keepmyconfig --check-device` para auditar la ruta.
  2. Ejecute `keepmyconfig --setup` para inicializar automáticamente la carpeta y crear el marcador.

#### Caso 2: Error de Cifrado o Descifrado GPG (Código de salida `4`)
- **Causa:** Contraseña incorrecta o snapshot corrupto.
- **Solución:** Compruebe mayúsculas/minúsculas. Si usa automatización, exporte `export PASSPHRASE="su_clave"`.

#### Caso 3: Módulo no encontrado (Código de salida `3`)
- **Causa:** La receta no existe o contiene errores de sintaxis Bash.
- **Solución:** Compruebe con `keepmyconfig --list-modules` o valide la sintaxis con `bash -n modules.d/receta.conf`.

#### Caso 4: Espacio insuficiente en el almacenamiento
- **Solución:** Compruebe el espacio libre en el Submenú 6 (Diagnóstico) y purgue snapshots antiguos en `archives/`.

---

## Apéndice A: Política de Versionado (SemVer), Tags y Publicación en GitHub

### A.1 Estándar SemVer 2.0.0 y Reglas de Incremento

El proyecto implementa estrictamente [Semantic Versioning 2.0.0](https://semver.org/lang/es/):
```text
v<MAJOR>.<MINOR>.<PATCH>[-<PRERELEASE>]
```
- **`MAJOR`:** Rompimiento de compatibilidad (*Breaking Changes*).
- **`MINOR`:** Nuevas funcionalidades compatibles (`feat`).
- **`PATCH`:** Corrección de errores (`fix`).
- **`<PRERELEASE>`:** Iteraciones alfa, beta o rc (`-alpha.1`, `-alpha.2`).

---

### A.2 Ciclo de Pre-Releases (Alfa, Beta, RC)
Las fases intermedias incrementan el sufijo pre-release (`v0.1.0-alpha.1` ➔ `v0.1.0-alpha.2`). Tras congelar funcionalidades y estabilizar, se transiciona a `-beta.1`, `-rc.1` y versión final `v1.0.0`.

---

### A.3 Publicación de Releases en GitHub desde Tags de Git
Los tags se crean de forma anotada:
```bash
git tag -a v0.1.0-alpha.2 -m "release: versión alfa con empaquetado dual e instalador"
```
GitHub reconoce automáticamente el sufijo `-alpha` y lo publica con la insignia **`Pre-release`**.

---

### A.4 Registro de Cambios (`CHANGELOG.md`)
Todo cambio significativo se clasifica de forma mandatoria en `CHANGELOG.md` bajo `### Added`, `### Fixed`, `### Changed` y `### Security`.

---

## Apéndice B: Script Reproducible de Empaquetado (`scripts/package.sh`) y Checksums

Para administradores, empaquetadores y contribuidores que deseen compilar y empaquetar KeepMyConfig desde el repositorio de código fuente:

```bash
scripts/package.sh [OPCIONES]

Opciones:
  -v, --version <tag>     Especificar versión explícita (ej. v0.1.0-alpha.2)
  -o, --output-dir <dir>  Directorio destino de los artefactos (por defecto: dist/)
  -t, --type <tipo>       Tipo de paquete a generar: all, standard, portable (default: all)
  -c, --clean             Limpiar artefactos previos en el directorio de salida
  -s, --skip-tests        Omitir el smoke test posterior (no recomendado)
  -h, --help              Mostrar esta ayuda de uso y salir
```

### B.1 Modos de Compilación y Flags CLI
- **`--type all` (por defecto):** Genera la Edición Estándar (`KeepMyConfig-${VERSION}.tar.gz` y `.tar.zst`) y la Edición Portable (`KeepMyConfig-${VERSION}-portable.tar.gz` y `.tar.zst`).
- **`--type standard`:** Genera exclusivamente la versión con instalador y artefactos Freedesktop.
- **`--type portable`:** Genera exclusivamente la versión plug-and-play con marcador `.portable` y lanzador `keepmyconfig.sh`.
- **`--clean`:** Purga artefactos previos y sumas SHA-256 en el directorio de salida antes de iniciar el empaquetado.

### B.2 Garantías Anti-Tarbomb y Lista Blanca Estricta
- **Anti-Tarbomb:** Todo archivo comprimido se descomprime dentro de un único subdirectorio contenedor con el nombre del paquete, evitando la dispersión de archivos en la carpeta del usuario.
- **Lista Blanca Estricta:** El empaquetador utiliza un directorio temporal de preparación (*staging*) y copia únicamente los componentes de producción necesarios, excluyendo de forma garantizada `.git/`, `.github/`, `.agents/`, `specs/`, `tests/` y `user_data/`.

### B.3 Normalización de Permisos UNIX y Firmas SHA-256
- **Normalización de Permisos:** Antes del empaquetado, todos los directorios y ejecutables se fijan a `0755` y los ficheros regulares a `0644`.
- **Sumas Criptográficas SHA-256:** El script genera automáticamente `dist/SHA256SUMS.txt` con las sumas de todos los archivos generados y valida su correspondencia mediante `sha256sum -c`.
- **Smoke Tests Integrados:** Cada paquete generado se descomprime temporalmente en un entorno aislado y se valida la respuesta de sus binarios antes de declarar el empaquetado como exitoso.
