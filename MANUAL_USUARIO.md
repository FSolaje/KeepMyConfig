# Manual de Usuario y Administración: KeepMyConfig

> **Versión:** 0.1.0-alpha.1  
> **Sistema Operativo Objetivo:** Lliurex 25 / Ubuntu 24.04 LTS  
> **Privilegios:** Usuario estándar sin privilegios (`non-root`, sin `sudo`)  
> **Arquitectura:** Modelo-Vista-Controlador (MVC) en Bash 5+  

---

## Tabla de Contenidos

1. [Capítulo 1: Introducción, Arquitectura y Requisitos](#capítulo-1-introducción-arquitectura-y-requisitos)
   - [1.1 Contexto y Propósito](#11-contexto-y-propósito)
   - [1.2 Principio de Ejecución sin Privilegios (Non-Root)](#12-principio-de-ejecución-sin-privilegios-non-root)
   - [1.3 Pila Tecnológica y Dependencias](#13-pila-tecnológica-y-dependencias)
   - [1.4 Verificación Rápida del Sistema](#14-verificación-rápida-del-sistema)
2. [Capítulo 2: Preparación del Almacenamiento Externo (SSD / USB)](#capítulo-2-preparación-del-almacenamiento-externo-ssd--usb)
   - [2.1 El Mecanismo de Seguridad Safety Marker](#21-el-mecanismo-de-seguridad-safety-marker)
   - [2.2 Paso a Paso: Inicialización de la Unidad Externa](#22-paso-a-paso-inicialización-de-la-unidad-externa)
   - [2.3 Configuración Central (`config/config.conf`)](#23-configuración-central-configconfigconf)
3. [Capítulo 3: Guía de Uso - Interfaz Interactiva TUI (`whiptail`)](#capítulo-3-guía-de-uso---interfaz-interactiva-tui-whiptail)
   - [3.1 Inicio de la Interfaz Gráfica de Terminal](#31-inicio-de-la-interfaz-gráfica-de-terminal)
   - [3.2 Esquema del Menú Principal](#32-esquema-del-menú-principal)
   - [3.3 Recorrido Detallado por las 9 Opciones](#33-recorrido-detallado-por-las-9-opciones)
   - [3.4 El Flujo "Vault & Shred" y Advertencias de Seguridad](#34-el-flujo-vault--shred-y-advertencias-de-seguridad)
4. [Capítulo 4: Guía de Uso - Interfaz de Comandos CLI (Headless / Cron)](#capítulo-4-guía-de-uso---interfaz-de-comandos-cli-headless--cron)
   - [4.1 Sintaxis General y Modos de Operación](#41-sintaxis-general-y-modos-de-operación)
   - [4.2 Tabla Exhaustiva de Opciones CLI](#42-tabla-exhaustiva-de-opciones-cli)
   - [4.3 Automatización Desatendida con `PASSPHRASE`](#43-automatización-desatendida-con-passphrase)
   - [4.4 Integración con Tareas Programadas (`cron`)](#44-integración-con-tareas-programadas-cron)
   - [4.5 Tabla de Códigos de Salida UNIX](#45-tabla-de-códigos-de-salida-unix)
   - [4.6 Entorno de Pruebas y Desarrollo (Modo Sandbox)](#46-entorno-de-pruebas-y-desarrollo-modo-sandbox)
5. [Capítulo 5: Creación de Módulos, Recetas y Perfiles](#capítulo-5-creación-de-módulos-recetas-y-perfiles)
   - [5.1 Estructura Declarativa de una Receta](#51-estructura-declarativa-de-una-receta)
   - [5.2 Directivas Soportadas](#52-directivas-soportadas)
   - [5.3 Ejemplos Oficiales de Producción](#53-ejemplos-oficiales-de-producción)
   - [5.4 Hooks Post-Restauración (`POST_RESTORE_HOOK`)](#54-hooks-post-restauración-post_restore_hook)
   - [5.5 Sistema de Perfiles de Backup y Scoped Modules](#55-sistema-de-perfiles-de-backup-y-scoped-modules)
   - [5.6 Biblioteca de Plantillas (`templates.d/`) y Exclusiones en Perfiles](#56-biblioteca-de-plantillas-templatesd-y-exclusiones-en-perfiles)
6. [Capítulo 6: Auditoría, Logs y Resolución de Problemas (Troubleshooting)](#capítulo-6-auditoría-logs-y-resolución-de-problemas-troubleshooting)
   - [6.1 Árbol de Directorios en la Unidad Externa](#61-árbol-de-directorios-en-la-unidad-externa)
   - [6.2 Registro Histórico y Manifiestos de Integridad](#62-registro-histórico-y-manifiestos-de-integridad)
   - [6.3 Matriz de Resolución de Incidencias](#63-matriz-de-resolución-de-incidencias)
7. [Apéndice A: Política de Versionado (SemVer), Tags y Publicación en GitHub](#apéndice-a-política-de-versionado-semver-tags-y-publicación-en-github)
   - [A.1 Estándar SemVer 2.0.0 y Reglas de Incremento](#a1-estándar-semver-200-y-reglas-de-incremento)
   - [A.2 Ciclo de Pre-Releases (Alfa, Beta, RC)](#a2-ciclo-de-pre-releases-alfa-beta-rc)
   - [A.3 Publicación de Releases en GitHub desde Tags de Git](#a3-publicación-de-releases-en-github-desde-tags-de-git)
   - [A.4 Registro de Cambios (`CHANGELOG.md`)](#a4-registro-de-cambios-changelogmd)


---

## Capítulo 1: Introducción, Arquitectura y Requisitos

### 1.1 Contexto y Propósito

En entornos educativos basados en **Lliurex 25 / Ubuntu 24.04 LTS** (como aulas informáticas de Formación Profesional o institutos de secundaria), los equipos suelen estar sujetos a congelación de disco (sistemas de restauración automática de aula) o reinstalaciones periódicas. Esto ocasiona la pérdida recurrente de:
- Entornos de desarrollo locales (configuración de VSCode, extensiones, perfiles de terminal).
- Credenciales temporales, claves SSH para repositorios Git y tokens de acceso.
- Configuraciones de shell (`.bashrc`, `.bash_aliases`, scripts personales en `~/bin`).

**KeepMyConfig** ha sido diseñado para resolver este problema permitiendo a docentes y alumnos:
1. Respaldar selectivamente sus herramientas y configuraciones a una unidad externa (SSD o pendrive USB).
2. Proteger con cifrado militar (GPG AES-256) cualquier dato privado o llave de seguridad.
3. Purgar del ordenador del aula los datos sensibles mediante borrado seguro irrecuperable (`shred -u`), eliminando el riesgo de que otros alumnos o usuarios accedan a sus credenciales.
4. Restaurar el entorno completo en cuestión de segundos al iniciar sesión en cualquier equipo.

---

### 1.2 Principio de Ejecución sin Privilegios (Non-Root)

> [!IMPORTANT]
> **BackupConfig no requiere ni debe ejecutarse con `sudo`**.
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
- **Controlador (`lib/controllers/`):** Orquestación, validación y enrutamiento de peticiones.

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

Para comprobar que su estación de trabajo dispone de todas las herramientas necesarias, ejecute en su terminal:

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

## Capítulo 2: Preparación del Almacenamiento Externo (SSD / USB)

### 2.1 El Mecanismo de Seguridad Safety Marker

> [!CAUTION]
> **Prevención de Escrituras Fantasma:** Si una unidad externa se desconecta inesperadamente, el punto de montaje `/media/$USER/MI_DISCO` puede quedar como una carpeta local vacía en el disco raíz del ordenador. Un script de backup tradicional escribiría en el disco interno, saturando la partición del sistema y dejando los datos expuestos localmente.

Para evitar esto, **BackupConfig** exige la presencia de un archivo testigo denominado **`.backup_storage_marker`** en la raíz de su carpeta de copias. Si dicho archivo no existe o no contiene la firma válida, el motor detiene de inmediato cualquier operación con código de salida `2`.

---

### 2.2 Inicialización del Almacenamiento y Asistente de Onboarding

KeepMyConfig incluye un **Asistente de Configuración Inicial (Onboarding Wizard)** diseñado para preparar el entorno de copias en menos de un minuto sin necesidad de comandos manuales.

#### Método 1: Asistente Automático de Primera Ejecución (Recomendado)
Al ejecutar por primera vez la aplicación sin haber completado la configuración (`INITIAL_SETUP_DONE="false"`):
```bash
./backup_manager.sh
```
El sistema detecta el primer arranque e inicia automáticamente el asistente en pantalla:
1. **Auditoría de hardware y medios montados:** Escanea particiones externas y unidades USB en `/media/$USER/` o `/run/media/$USER/`.
2. **Selección guiada de destino:**
   - **Almacenamiento Local (Por defecto):** Configura `~/Backups/KeepMyConfig`. Ideal para ordenadores personales o estaciones con almacenamiento persistente.
   - **Dispositivos Externos Detectados:** Muestra una lista con las memorias USB o discos SSD externos conectados para seleccionarlos directamente.
   - **Ruta Personalizada:** Permite ingresar manualmente cualquier ruta del sistema o montaje de red.
3. **Despliegue del Marcador de Seguridad:** Crea automáticamente las carpetas `archives/` y `logs/` e instala el archivo testigo `.backup_storage_marker` para prevenir escrituras accidentales.
4. **Preferencia de Sesión (`REMEMBER_LAST_PROFILE`):** Pregunta si desea que la aplicación recuerde el último perfil utilizado en cada sesión o si prefiere iniciar siempre en el perfil `default`.

> [!TIP]
> Puede relanzar este asistente de configuración guiada en cualquier momento mediante la opción de línea de comandos:
> ```bash
> ./backup_manager.sh --setup
> ```
> O desde la **Opción 8** del menú interactivo TUI.

#### Método 2: Inicialización Manual o de Rutas Personalizadas
Si desea inicializar manualmente un destino en un disco externo o carpeta específica:
```bash
mkdir -p "$HOME/Backups/KeepMyConfig/archives" "$HOME/Backups/KeepMyConfig/logs"
cp markers/.backup_storage_marker "$HOME/Backups/KeepMyConfig/.backup_storage_marker"
```

---

### 2.3 Configuración Central (`config/config.conf`)

La configuración central de **KeepMyConfig** se administra a través del archivo `config/config.conf`:

```bash
# Ruta universal de almacenamiento (carpeta local, disco externo o notación @media)
BACKUP_DESTINATION="~/Backups/KeepMyConfig"

# Algoritmo de cifrado simétrico GPG (AES256 recomendado)
CIPHER_ALGO="AES256"

# Algoritmo de compresión (zstd o gzip)
COMPRESSION_ALGO="zstd"

# Días de retención de registros antes de purga automática
LOG_RETENTION_DAYS=90

# Estado del asistente de configuración inicial
INITIAL_SETUP_DONE="true"

# Perfil de backup activo
ACTIVE_PROFILE="default"

# Memoria de sesión: recordar último perfil activo utilizado (true/false)
REMEMBER_LAST_PROFILE="true"
```

#### Formatos Soportados para `BACKUP_DESTINATION`
El sistema normaliza y resuelve de forma inteligente los siguientes formatos de ruta:
- **Ruta local con tilde o `$HOME`:** `~/Backups/KeepMyConfig` o `$HOME/Copias`.
- **Rutas de discos externos montados:** `/media/$USER/DISCO_BACKUP/Backups`.
- **Notación semántica de conveniencia:** `@media/<ETIQUETA>/...` (ej. `@media/DISCO_BACKUP/Backups`), que busca automáticamente la unidad cuya etiqueta coincida en `/media/$USER/` o `/run/media/$USER/`.
- **Rutas absolutas fijas o montajes de red (NFS/SMB/SSHFS):** `/mnt/servidor_backup/datos`.

#### Convención Zero-Config por Perfil
KeepMyConfig organiza las copias de seguridad de múltiples perfiles sin requerir configuraciones complejas:
- **Perfil Predeterminado (`default`):** Almacena sus archivos directamente en la raíz de `BACKUP_DESTINATION`.
- **Perfiles Secundarios (`docente`, `desarrollo`, etc.):** Por convención automática Zero-Config, almacenan sus copias en `<BACKUP_DESTINATION>/<id_perfil>`.
- **Validación Jerárquica del Marcador:** No es necesario copiar manualmente el marcador `.backup_storage_marker` en cada subcarpeta de perfil. El sistema valida la presencia del marcador en la raíz del destino o en cualquier carpeta ascendente y crea automáticamente la estructura necesaria.

---

## Capítulo 3: Guía de Uso - Interfaz Interactiva TUI (`whiptail`)

### 3.1 Inicio de la Interfaz Gráfica de Terminal

Para iniciar la aplicación interactiva, abra su terminal dentro del directorio del proyecto y ejecute:

```bash
./backup_manager.sh
```

El sistema verificará la presencia de `whiptail` y abrirá el menú principal de pantalla completa.

---

### 3.2 Esquema de la Arquitectura Universal TUI

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

### 3.3 Recorrido Detallado por los 7 Menús

#### Menú 1: Menú Principal Híbrido (Operaciones Inmediatas)
Diseñado para la máxima agilidad operativa diaria:
- **Opción 1 (`Ejecutar Respaldo Inmediato`):** Lanza el respaldo completo de todos los módulos activos del perfil actual, canalizado a través del *Pre-Flight Safety Gate*.
- **Opción 2 (`Restauración Rápida de Datos Sensibles`):** Al comenzar la jornada, descifra en memoria y restaura en un solo paso las credenciales y llaves confidenciales.
- **Opciones 3 a 8:** Navegan hacia los centros de gestión temática especializada.

#### Submenú 2: Centro de Operaciones de Respaldo
Agrupa todas las modalidades de empaquetado y salvaguarda:
- **1) [BACKUP] Realizar Respaldo Completo:** Procesa todos los módulos activos (`MODULE_ENABLED="true"`).
- **2) [TAG] Respaldo Filtrado por Etiquetas:** Checklist interactivo para seleccionar etiquetas (`dev`, `ide`, `shell`, etc.).
- **3) [MOD] Respaldo de Módulo Individual:** Selector único (*Radiolist*) para respaldar una sola receta.

#### Submenú 3: Centro de Recuperación y Restauración
- **1) [VAULT] Restauración Rápida de Datos Sensibles:** Recupera snapshots confidenciales descifrando mediante tubería segura GPG AES-256.
- **2) [HIST] Restauración Selectiva por Histórico:** Permite elegir un módulo y examinar todos sus puntos en el tiempo (`AAAAMMDD_HHMMSS`) para restaurar versiones exactas.
- **3) [FULL] Restauración Total:** Desempaqueta secuencialmente todas las configuraciones con advertencia previa de los archivos que serán sobrescritos.

#### Submenú 4: Gestión de Perfiles de Trabajo (`profiles/`)
- **1) [INFO] Ver Detalles del Perfil Activo:** Identificador, nombre, descripción y ruta Zero-Config (`<BACKUP_DESTINATION>/<id_perfil>`).
- **2) [SWITCH] Conmutar Perfil Activo:** Cambia el perfil en `config/config.conf` persistiendo la preferencia.
- **3) [NEW] Crear Nuevo Perfil de Backup:** Asistente guiado para nuevos entornos aislados.
- **4) [LIST] Listar Módulos del Perfil:** Muestra las recetas resolviendo la jerarquía con badges `[Global]`, `[Override]` o `[Exclusivo]`.
- **5) [EXCL] Gestionar Exclusiones de Módulos (`DISABLED_MODULES`):** Checklist para deshabilitar módulos globales en perfiles secundarios.
- **6) [DEL] Eliminar Perfil:** Purga segura de la definición de un perfil secundario con **salvaguarda de seguridad estricta** (impide eliminar `default` o el perfil actualmente activo).

#### Submenú 5: Administración de Módulos y Plantillas
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

#### Submenú 6: Destinos de Almacenamiento y Diagnóstico
- **1) [DIAG] Diagnóstico de Almacenamiento:** Valida la presencia del archivo marcador jerárquico `.backup_storage_marker`, permisos y espacio disponible en disco.
- **2) [DEST] Cambiar Destino Canónico (`BACKUP_DESTINATION`):** Actualización de la directiva universal (rutas locales, absolutas o notación `@media/<LABEL>/...`).
- **3) [WIZARD] Relanzar Asistente de Configuración (Onboarding):** Configuración asistida paso a paso.
- **4) [MARKER] Desplegar Marcador de Seguridad:** Instalación manual del archivo testigo y estructura de directorios.

#### Submenú 7: Preferencias y Personalización Visual
- **1) [THEME] 🎨 Selección de Tema Visual TUI (`NEWT_COLORS`):**
  - **`default` (Por Defecto):** Respeta los colores nativos de la terminal configurada por el usuario (tema de fábrica de KeepMyConfig).
  - **`midnight` (Medianoche):** Azul profundo de alto contraste nocturno.
  - **`cyberdark` (Cibernético):** Verde fluorescente sobre fondo negro estilo terminal de ciberseguridad.
  - **`aubergine` (Berenjena):** Tonos magenta y violeta inspirados en la estética moderna de Lliurex / Ubuntu.
  - **`amber` (Ámbar):** Resplandor fósforo ámbar clásico estilo monitor monocromático vintage.
- **2) [PROFILE] 🧠 Memoria de Sesión (`REMEMBER_LAST_PROFILE`):** Configura si la aplicación arranca en el último perfil utilizado o siempre en `default`.

---

### 3.4 El Flujo "Vault & Shred" y Pre-Flight Safety Gate

KeepMyConfig implementa un interceptor mandatorio denominado **Pre-Flight Safety Gate** que se ejecuta antes de cualquier operación de respaldo:

1. **Matriz de Impacto Previo:** Presenta una tabla con todos los módulos a procesar, su ámbito (`[Global]` o `[Perfil]`), si requieren cifrado GPG AES-256, si tienen purga activa y su carpeta destino final.
2. **Alerta Crítica ante Purga Irreversible (`shred -u`):**
   Si la operación incluye módulos con purga activa (como `ssh-keys`), el sistema suspende la ejecución y muestra una advertencia de seguridad destacada:
   - **En TUI (`whiptail`):** Diálogo de alerta con foco predeterminado obligatorio en **`[NO]`** (`--defaultno`), requiriendo que el usuario se desplace deliberadamente a `[SÍ]` para autorizar la destrucción.
   - **En CLI:** Mensaje de peligro enmarcado en fondo rojo `\033[41;97;1m` listando todas las rutas a destruir, requiriendo teclear **`SI`** en mayúsculas y pulsar Enter (salvo uso de `--yes` / `-y`).
3. **Advertencia de Sobreescritura en Restauración:** Antes de desempaquetar archivos en el `$HOME`, lista las rutas existentes que serán sustituidas para evitar pérdidas accidentales de configuraciones recientes.

---

## Capítulo 4: Guía de Uso - Interfaz de Comandos CLI (Headless / Cron)

### 4.1 Sintaxis General y Modos de Operación

La interfaz de línea de comandos está optimizada para scripts bash, tareas programadas en segundo plano o usuarios avanzados de terminal:

```bash
./backup_manager.sh [OPERACIÓN] [MODIFICADORES]
```

---

### 4.2 Tabla Exhaustiva de Opciones CLI

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
| `--create-profile` | `<id>` | Crea un nuevo perfil de backup y su estructura de módulos. |
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

### 4.3 Automatización Desatendida con `PASSPHRASE`

Para ejecutar backups o restauraciones de módulos sensibles sin intervención manual (sin que se pause pidiendo la clave por teclado), proporcione la contraseña a través de la variable de entorno `PASSPHRASE`:

```bash
# Backup completo desatendido
PASSPHRASE="MiClaveSegura2026" ./backup_manager.sh --backup-all

# Restauración exprés de llaves y credenciales desatendida
PASSPHRASE="MiClaveSegura2026" ./backup_manager.sh --restore-sensitive
```

---

### 4.4 Integración con Tareas Programadas (`cron`)

Puede programar la ejecución de una copia de seguridad automática al terminar cada jornada de clase.

Abra su crontab de usuario:
```bash
crontab -e
```

Añada una regla para ejecutar la copia de lunes a viernes a las 14:30:
```cron
# Respaldo automático de desarrollo y entorno shell a las 14:30
30 14 * * 1-5 /home/usuario/scripts/BackupConfig/backup_manager.sh --backup-tag dev >> /tmp/backup_cron.log 2>&1
```

---

### 4.5 Tabla de Códigos de Salida UNIX

Para facilitar el control de flujo en scripts o pipelines de integración continua, **BackupConfig** retorna códigos de salida estandarizados:

| Código | Significado | Causa Habitual |
| :---: | :--- | :--- |
| **`0`** | **Éxito (SUCCESS)** | Operación concluida satisfactoriamente. |
| **`1`** | **Error General / Cancelado** | Operación cancelada por el usuario en la TUI o fallo de sintaxis. |
| **`2`** | **Error de Almacenamiento** | SSD no conectado, punto de montaje inaccesible o `.backup_storage_marker` ausente. |
| **`3`** | **Error de Módulo** | El módulo solicitado no existe o el archivo de histórico no fue encontrado. |
| **`4`** | **Error Criptográfico** | Contraseña GPG incorrecta o archivo vault dañado/corrupto. |
| **`5`** | **Argumento Inválido** | Parámetros CLI faltantes o no reconocidos. |
| **`10`** | **Dependencia Faltante** | `whiptail` u otra herramienta indispensable no está instalada en el sistema. |

---

### 4.6 Entorno de Pruebas y Desarrollo (Modo Sandbox)

Para facilitar la verificación manual, desarrollo de nuevas recetas o pruebas de flujos completos sin alterar el repositorio Git ni contaminar los directorios de producción (`config/`, `modules.d/`, `profiles/`), **KeepMyConfig** incorpora el **Modo Sandbox / Test Mode**.

#### 4.6.1 Activación del Modo Sandbox
El modo sandbox puede activarse de tres formas equivalentes:
1. **Flag CLI explícito:**
   ```bash
   ./backup_manager.sh --test-mode
   # o bien:
   ./backup_manager.sh --sandbox
   ```
2. **Combinado con cualquier comando CLI:**
   ```bash
   ./backup_manager.sh --test-mode --backup-all
   ./backup_manager.sh --test-mode --enable-template firefox
   ./backup_manager.sh --test-mode --create-profile docente
   ./backup_manager.sh --test-mode --list-modules
   ```
3. **Variable de entorno:**
   ```bash
   KEEP_MY_CONFIG_TEST_MODE=true ./backup_manager.sh
   ```

#### 4.6.2 Arquitectura y Aislamiento de Rutas
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

#### 4.6.3 Indicadores Visuales y Trazabilidad de Rutas
- **Interfaz TUI (Whiptail):** El título del menú principal refleja explícitamente el entorno de pruebas:
  ```text
  KeepMyConfig [SANDBOX] [Perfil: default]
  ```
  Al completar operaciones de backup, restauración o purga, los cuadros de diálogo muestran **rutas absolutas completas** del home virtual (`user_data/sandbox/home/...`), del archivo generado en `storage/archives/` y de los ficheros eliminados con `shred -u`.
- **Línea de Comandos (CLI):** Cada ejecución emite una advertencia visual formateada:
  ```text
  [AVISO] Ejecutando en MODO TEST / SANDBOX (Rutas aisladas en user_data/sandbox/)
  ```

#### 4.6.4 Purga y Reseteo (`--clean-sandbox`)
Para eliminar por completo el entorno sandbox y liberar espacio:
```bash
./backup_manager.sh --clean-sandbox
```
Este comando elimina la carpeta `user_data/sandbox/` (incluyendo su home virtual y almacenamiento de prueba) y confirma la purga en la terminal.

---

## Capítulo 5: Creación de Módulos y Recetas (`modules.d/*.conf`)

### 5.1 Estructura Declarativa de una Receta

Cada elemento a respaldar se define en un archivo de configuración independiente ubicado en la carpeta `modules.d/` con extensión `.conf` (ejemplo: `modules.d/mi-herramienta.conf`).

Las recetas se procesan dentro de una subshell aislada para evitar la contaminación del entorno.

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

#### 1. `modules.d/vscode-standard.conf` (Configuración Abierta)
Respalda las extensiones y preferencias visuales de VSCode. No requiere cifrado ni purga:
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

#### 2. `modules.d/vscode-sensitive.conf` (Credenciales y Tokens)
Respalda el almacenamiento seguro de credenciales y sincronización de cuentas:
```bash
MODULE_ID="vscode-sensitive"
MODULE_NAME="Visual Studio Code - Credenciales y Tokens"
MODULE_TAGS=("dev" "ide" "auth" "vscode")
MODULE_PATHS=(
    ".config/Code/User/globalStorage/state.vscdb"
    ".config/Code/User/sync"
)
IS_SENSITIVE="true"
PURGE_AFTER_BACKUP="true"
```

#### 3. `modules.d/bash-env.conf` (Entorno de Consola)
Preserva los alias y scripts personales del usuario:
```bash
MODULE_ID="bash-env"
MODULE_NAME="Entorno Bash y Dotfiles"
MODULE_TAGS=("system" "shell" "dev")
MODULE_PATHS=(
    ".bashrc"
    ".bash_aliases"
    ".profile"
    "bin"
)
IS_SENSITIVE="false"
PURGE_AFTER_BACKUP="false"
```

#### 4. `modules.d/ssh-keys.conf` (Llaves Criptográficas con Hook)
Respalda las llaves SSH privadas/públicas y los hosts conocidos, asegurando los permisos correctos al restaurar:
```bash
MODULE_ID="ssh-keys"
MODULE_NAME="Claves SSH y Configuración Remota"
MODULE_TAGS=("security" "auth" "ssh")
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
> **Mantenimiento Automático de Permisos:**
> Ciertas aplicaciones (como el cliente OpenSSH o GnuPG) rechazan funcionar si los ficheros de configuración tienen permisos excesivos (ejemplo: lectura para grupo o terceros).
> 
> Use la función `POST_RESTORE_HOOK()` para aplicar automáticamente `chmod` o regenerar enlaces simbólicos tras la restauración. El hook recibe `$1` como la ruta base del `$HOME` de restauración.

---

### 5.5 Sistema de Perfiles de Backup y Scoped Modules

KeepMyConfig incluye un sistema de perfiles que permite aislar entornos de trabajo (por ejemplo: `docente`, `desarrollo`, `administracion`) adaptando qué recetas se procesan y a qué carpeta de almacenamiento se destinan.

#### Estructura de un Perfil (`profiles/<perfil_id>/`)
Cada perfil reside en un subdirectorio propio dentro de `profiles/`:
```text
profiles/
├── default/                  # Perfil base conceptual
└── docente/
    ├── profile.conf          # Metadatos y destino específico
    └── modules.d/            # Módulos propios del perfil
        ├── custom-eval.conf  # Módulo exclusivo (solo visible en 'docente')
        └── bash-env.conf     # Módulo sobrescrito (Override sobre el global)
```

#### Fichero de Metadatos (`profile.conf`)
```ini
PROFILE_ID="docente"
PROFILE_NAME="Perfil Docente"
PROFILE_DESCRIPTION="Entorno educativo para docencia de FP"
TARGET_SUBDIR="Backups/Docente"
# Módulos globales excluidos específicamente en este perfil:
DISABLED_MODULES=("firefox" "thunderbird")
```

#### Resolución en Cascada de Módulos
Cuando se ejecuta una operación bajo un perfil activo:
1. **Exclusión de Módulos Globales:** Si un módulo global está listado en `DISABLED_MODULES` dentro del `profile.conf` del perfil activo, es omitido automáticamente de los listados y de las operaciones de respaldo colectivas (`--backup-all`, `--backup-tag`).
2. **Sobrescritura (*Override*):** Si existe `profiles/<perfil>/modules.d/<modulo>.conf`, prevalece sobre la versión global `modules.d/<modulo>.conf`.
3. **Módulo Exclusivo:** Si un módulo solo existe dentro de `profiles/<perfil>/modules.d/`, solo será visible y ejecutable cuando ese perfil esté activo.
4. **Módulo Global:** Las recetas definidas en `modules.d/` están siempre disponibles como base para todos los perfiles salvo que sean sobrescritas o excluidas.
5. **Deduplicación:** Las operaciones colectivas (`--backup-all`, `--list-modules`) presentan una vista unificada sin duplicados, indicando el ámbito `[Global]`, `[Override]` o `[Exclusivo]`.

#### Uso desde CLI
```bash
# Crear un nuevo perfil
./backup_manager.sh --create-profile docente

# Establecerlo como predeterminado
./backup_manager.sh --set-active-profile docente

# Ejecutar una operación puntual bajo un perfil temporal
./backup_manager.sh --profile dev --backup-all
```

---

### 5.6 Biblioteca de Plantillas (`templates.d/`) y Exclusiones en Perfiles

#### Principio de Estado Inicial Limpio
Por diseño, una nueva instalación de **KeepMyConfig** arranca sin ningún módulo activo en `modules.d/`. Esto previene respaldos accidentales indeseados antes de que el usuario haya seleccionado conscientemente qué aplicaciones desea proteger. Si se invoca `--backup-all` sin módulos configurados, la herramienta no falla ni arroja un error crítico; en su lugar, despliega una guía amigable indicando cómo activar recetas desde la biblioteca de plantillas.

#### Catálogo Oficial de Recetas Predefinidas (`templates.d/`)
El directorio `templates.d/` incluye plantillas listas para su activación inmediata:

| Receta de Plantilla | ID | Descripción | Sensible / Purga | Etiquetas |
| :--- | :--- | :--- | :---: | :--- |
| `bash-env.conf` | `bash-env` | Entorno Bash (`.bashrc`, `.bash_aliases`, `~/.local/bin`) | No / No | `system`, `shell`, `dev` |
| `firefox.conf` | `firefox` | Marcadores y perfiles de Mozilla Firefox | No / No | `browser`, `web`, `user` |
| `git-config.conf` | `git-config` | Configuración global Git (`.gitconfig`, `.gitignore_global`) | No / No | `git`, `dev`, `tools` |
| `intellij.conf` | `intellij` | Preferencias y configuraciones de IDEs JetBrains / IntelliJ | No / No | `ide`, `dev`, `jetbrains` |
| `libreoffice.conf` | `libreoffice` | Perfiles de usuario y plantillas de LibreOffice | No / No | `office`, `desktop`, `docs` |
| `ssh-keys.conf` | `ssh-keys` | Llaves privadas/públicas SSH y config (`~/.ssh/`) | **Sí / Sí** | `security`, `ssh`, `keys`, `sensitive` |
| `thunderbird.conf` | `thunderbird` | Perfiles de correo de Mozilla Thunderbird | No / No | `mail`, `desktop`, `user` |
| `vscode-sensitive.conf` | `vscode-sensitive` | Credenciales, tokens y auth de Visual Studio Code | **Sí / Sí** | `editor`, `vscode`, `sensitive` |
| `vscode-standard.conf` | `vscode-standard` | Ajustes, atajos y snippets de Visual Studio Code | No / No | `editor`, `vscode`, `dev` |
| `template-skeleton.conf` | N/A | Esqueleto canónico exhaustivamente comentado para crear nuevas recetas | N/A | N/A |

#### Esqueleto Canónico (`template-skeleton.conf`)
Para desarrolladores o administradores de aula que deseen crear nuevas recetas, se incluye `templates.d/template-skeleton.conf`:
```bash
# Identificador único (minúsculas, números y guiones)
MODULE_ID="mi-herramienta"

# Nombre legible para interfaces TUI/CLI
MODULE_NAME="Mi Herramienta de Trabajo"

# Etiquetas para agrupación por lotes (--backup-tag)
MODULE_TAGS=("dev" "tools")

# Rutas relativas al $HOME del usuario (NUNCA incluir /home/<user> ni $HOME)
MODULE_PATHS=(
    ".config/mi-herramienta/config.json"
    ".mi-herramienta/plugins"
)

# Confidencialidad: true si requiere cifrado GPG AES-256
IS_SENSITIVE=false

# Purga segura: true si debe eliminarse con 'shred -u' del equipo de origen tras respaldar
PURGE_AFTER_BACKUP=false

# Hook opcional en Bash tras la restauración (ej. restablecer permisos)
POST_RESTORE_HOOK=""
```

#### Activación de Plantillas en TUI y CLI

**Desde la TUI (Interfaz Interactiva):**
1. Acceda a la **Opción 7: `[MODULES] Administrar Módulos, Plantillas y Etiquetas`**.
2. Seleccione la acción **`Activar módulo desde plantilla`**.
3. El sistema listará todas las plantillas disponibles con sus descripciones y nivel de seguridad.
4. Elija la plantilla deseada.
5. Si el perfil activo es distinto de `default`, el sistema le preguntará si desea activarla a nivel **Global** (visible para todos los perfiles) o **Exclusivo del Perfil Activo**.

**Desde la CLI (Línea de Comandos):**
```bash
# 1. Explorar el catálogo de plantillas
./backup_manager.sh --list-templates

# 2. Activar una plantilla en el catálogo global (cuando el perfil es default)
./backup_manager.sh --enable-template firefox

# 3. Activar una plantilla para un perfil específico (ej. docente)
./backup_manager.sh --profile docente --enable-template git-config

# 4. Promover un módulo activo personalizado a la biblioteca de plantillas
./backup_manager.sh --export-template mi-modulo-personal
```

#### Gestión de Exclusiones en Perfiles (`DISABLED_MODULES`)

Cuando un módulo global (como `firefox` o `thunderbird`) no sea necesario o no deba respaldarse en un perfil especializado (por ejemplo, en un perfil de sólo código o de administración):
1. Inicie la TUI y vaya a la **Opción 9: `[PROFILES] Gestión de Perfiles de Backup`**.
2. Seleccione la opción **`5) Gestionar exclusiones de módulos globales`**.
3. Marque en la checklist interactiva qué módulos globales deben quedar desactivados en el perfil actual.
4. El sistema guardará la directiva `DISABLED_MODULES=("...")` en el `profile.conf` del perfil.
5. Al invocar backups bajo ese perfil, los módulos excluidos serán ignorados de forma transparente.

---

## Capítulo 6: Auditoría, Logs y Resolución de Problemas (Troubleshooting)

### 6.1 Árbol de Directorios en la Unidad Externa

Una vez realizadas las primeras copias, la carpeta configurada en su unidad externa presentará la siguiente estructura:

```text
/media/$USER/SSD_BACKUP/Backups/Lliurex25/
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

- **`backup_history.log`:** Contiene una línea por cada operación realizada:
  ```text
  [2026-09-20 18:30:00] [BACKUP] [ssh-keys] SUCCESS Archive: ssh-keys_20260920_183000.tar.zst.gpg Status: ENCRYPTED Purged: TRUE
  ```
- **Manifiestos (`.manifest.log`):** Cada archivo de copia contiene un catálogo de todos los ficheros respaldados junto con su suma de verificación criptográfica `SHA-256`, garantizando la detección de corrupciones silenciosas.
- **Detección de Diffs (`.diff.log`):** Indica los cambios detectados respecto al snapshot previo:
  - `+` : Fichero nuevo añadido.
  - `~` : Fichero modificado (el hash difiere).
  - `-` : Fichero eliminado del sistema local.

---

### 6.3 Matriz de Resolución de Incidencias

#### Caso 1: Error `STORAGE_MARKER_MISSING` (Código de salida `2`)
- **Síntoma:** El sistema muestra: `No se detectó el almacenamiento de backup o falta el marcador de seguridad.`
- **Causa:** La ruta definida en `BACKUP_DESTINATION` no es accesible, el disco externo no está montado, o la carpeta no contiene el archivo testigo `.backup_storage_marker`.
- **Solución:**
  1. Ejecute `./backup_manager.sh --check-device` para auditar la ruta configurada.
  2. Si utiliza un disco externo, compruebe con `lsblk -f` que esté montado en `/media/$USER/` o `/run/media/$USER/`.
  3. Ejecute `./backup_manager.sh --setup` para inicializar automáticamente la carpeta y desplegar el marcador de seguridad.
  4. Desde el menú interactivo, acceda a la **Opción 8** y seleccione *Inicializar nueva subcarpeta en el almacenamiento*.

#### Caso 2: Error de Cifrado o Descifrado GPG (Código de salida `4`)
- **Síntoma:** `Fallo al descifrar el módulo. Compruebe la contraseña introducida.`
- **Causa:** La contraseña introducida no coincide con la utilizada al momento del empaquetado, o el archivo `.gpg` está incompleto.
- **Solución:**
  1. Vuelva a intentar la operación verificando que el bloqueo de mayúsculas esté desactivado.
  2. Si está automatizando con variable, asegúrese de exportar `export PASSPHRASE="su_clave"`.

#### Caso 3: Módulo no encontrado (Código de salida `3`)
- **Síntoma:** `El módulo 'xyz' no existe o está corrupto.`
- **Causa:** El archivo de receta `modules.d/xyz.conf` no existe o no tiene una estructura Bash válida.
- **Solución:**
  1. Ejecute `./backup_manager.sh --list-modules` para verificar la lista de recetas registradas.
  2. Si editó el archivo manualmente, verifique con `bash -n modules.d/xyz.conf` que no contenga errores de sintaxis.

#### Caso 4: Espacio insuficiente en el almacenamiento
- **Síntoma:** Error de compresión `zstd` o escritura en disco fallida.
- **Causa:** La unidad SSD/USB ha alcanzado su capacidad máxima.
- **Solución:**
  1. Utilice la opción 8 del menú TUI (`Diagnóstico de Disco Externo`) para comprobar el espacio libre.
  2. Purgue snapshots obsoletos de la carpeta `archives/`.

---

## Apéndice A: Política de Versionado (SemVer), Tags y Publicación en GitHub

### A.1 Estándar SemVer 2.0.0 y Reglas de Incremento

El proyecto implementa estrictamente la especificación [Semantic Versioning 2.0.0](https://semver.org/lang/es/) mediante el formato:

```text
v<MAJOR>.<MINOR>.<PATCH>[-<PRERELEASE>]
```

El prefijo `v` es obligatorio para todos los tags de Git y publicaciones de GitHub. Las reglas de incremento asociadas a los tipos de [Conventional Commits](https://www.conventionalcommits.org/) son:

1. **`MAJOR` (X.0.0):** Cambios que rompen la compatibilidad hacia atrás (*Breaking Changes*), identificados por `!` o pie `BREAKING CHANGE:`.
2. **`MINOR` (X.Y.0):** Nuevas funcionalidades o capacidades compatibles hacia atrás, identificadas por `feat(...)`. Reinicia el contador de `PATCH` a 0.
3. **`PATCH` (X.Y.Z):** Corrección de errores y bugs compatibles hacia atrás, identificadas por `fix(...)`.
4. **`<PRERELEASE>` (`-alpha.N`, `-beta.N`, `-rc.N`):** Versiones preliminares para pruebas, validación e iteración controlada.

---

### A.2 Ciclo de Pre-Releases (Alfa, Beta, RC)

Durante el ciclo de desarrollo activo:
- **Salto de Hito Funcional:** Al iniciar o planificar un conjunto de funcionalidades mayores (por ejemplo, el Sistema de Perfiles), se incrementa el número menor preparatorio (de `v0.1.0-alpha.X` a `v0.2.0-alpha.1`).
- **Iteraciones de Validación:** Correcciones, ajustes y pruebas dentro de la misma fase de desarrollo incrementan el sufijo de pre-release (`v0.1.0-alpha.1` ➔ `v0.1.0-alpha.2`).
- **Paso a Beta / RC:** Cuando las funcionalidades están completas y se entra en fase de congelación para pruebas intensivas de estabilidad, se transmuta a `-beta.1` y finalmente `-rc.1` (Release Candidate) antes de la versión final de producción (`v1.0.0`).

---

### A.3 Publicación de Releases en GitHub desde Tags de Git

GitHub integra soporte nativo para Semantic Versioning y pre-releases:

1. **Reconocimiento Automático de Pre-Release:**
   Cualquier tag que incluya un guion seguido de texto (como `-alpha.1` o `-beta.1`) es reconocido automáticamente por la plataforma y marcado con la insignia visual **`Pre-release`**, impidiendo que sustituya a la versión oficial de producción (`Latest`).
2. **Creación de Tags Anotados en Git:**
   Los tags deben crearse siempre de forma anotada para registrar autoría, firma y mensaje descriptivo:
   ```bash
   git tag -a v0.1.0-alpha.1 -m "release: versión alfa inicial (MVP funcional: MVC, GPG, Shred, TUI/CLI, Multi-target)"
   ```
3. **Publicación del Tag hacia GitHub:**
   Para subir la etiqueta al repositorio remoto (cuando se autorice expresamente):
   ```bash
   git push origin v0.1.0-alpha.1
   ```
4. **Generación de la Release en GitHub:**
   - Desde la interfaz web de GitHub: Acceder a **Releases** ➔ **Draft a new release** ➔ Seleccionar el tag existente `v0.1.0-alpha.1`.
   - GitHub activará automáticamente la casilla *"Set as a pre-release"*.
   - El cuerpo de la release se puede autocompletar haciendo clic en *"Generate release notes"* o pegando el extracto correspondiente de `CHANGELOG.md`.

---

### A.4 Registro de Cambios (`CHANGELOG.md`)

Todo cambio significativo debe documentarse de forma continua en `CHANGELOG.md` bajo las siguientes directivas:
- `### Added`: Nuevas características añadidas (`feat`).
- `### Fixed`: Errores o problemas solucionados (`fix`).
- `### Changed`: Modificaciones en el comportamiento de funcionalidades existentes.
- `### Security`: Mejoras de seguridad, algoritmos de cifrado o purga de datos.
- `### Documentation`: Actualizaciones sustanciales en guías, especificaciones y manuales.

