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
5. [Capítulo 5: Creación de Módulos, Recetas y Perfiles](#capítulo-5-creación-de-módulos-recetas-y-perfiles)
   - [5.1 Estructura Declarativa de una Receta](#51-estructura-declarativa-de-una-receta)
   - [5.2 Directivas Soportadas](#52-directivas-soportadas)
   - [5.3 Ejemplos Oficiales de Producción](#53-ejemplos-oficiales-de-producción)
   - [5.4 Hooks Post-Restauración (`POST_RESTORE_HOOK`)](#54-hooks-post-restauración-post_restore_hook)
   - [5.5 Sistema de Perfiles de Backup y Scoped Modules](#55-sistema-de-perfiles-de-backup-y-scoped-modules)
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

### 2.2 Paso a Paso: Inicialización de la Unidad Externa

Supongamos que dispone de un disco SSD externo etiquetado como `DISCO_BACKUP`.

#### Paso 1: Localizar la unidad y su punto de montaje
Conecte su disco y ejecute:
```bash
lsblk -f
```
Identifique el identificador `LABEL` (ejemplo: `SSD_BACKUP`) o su `UUID` (ejemplo: `UUID`), así como el punto de montaje (ejemplo: `/media/$USER/SSD_BACKUP` o `/mnt/SSD_BACKUP`).

#### Paso 2: Crear la estructura de directorios y el marcador de seguridad

**Método Automático (Recomendado):**
Puede inicializar cualquier subdirectorio de destino en el almacenamiento con una sola orden CLI o mediante la **Opción 8** de la TUI:
```bash
# Inicializar la carpeta para un equipo específico y fijarla como activa
./backup_manager.sh --init-target "Backups/Personal_PC" --set-default
```
Esta orden crea automáticamente `archives/`, `logs/`, despliega `.backup_storage_marker` y actualiza `config/config.conf`.

**Método Manual Alternativo:**
Si prefiere crearlo manualmente en su disco externo:
```bash
mkdir -p /media/$USER/DISCO_BACKUP/Backups/Lliurex25/archives
mkdir -p /media/$USER/DISCO_BACKUP/Backups/Lliurex25/logs
cp markers/.backup_storage_marker /media/$USER/DISCO_BACKUP/Backups/Lliurex25/.backup_storage_marker
```

---

### 2.3 Configuración Central (`config/config.conf`)

Edite el archivo `config/config.conf` para vincular su método preferido de detección de la unidad o carpeta:

```bash
# Métodos de identificación soportados:
#   - LABEL       : Busca la etiqueta de partición mediante lsblk / blkid
#   - UUID        : Busca el identificador único universal de partición
#   - STATIC_PATH : Usa una ruta fija de punto de montaje
#   - LOCAL_PATH  : Usa cualquier carpeta o disco local del equipo (o montaje de red)
STORAGE_ID_TYPE="LABEL"

# Valor de búsqueda correspondiente al método anterior
STORAGE_ID_VALUE="DISCO_BACKUP"

# Subdirectorio activo dentro del almacenamiento donde residen las copias
STORAGE_SUBDIR="Backups/Lliurex25"

# Algoritmo de cifrado simétrico GPG (AES256 recomendado)
CIPHER_ALGO="AES256"

# Algoritmo de compresión (zstd o gzip)
COMPRESSION_ALGO="zstd"

# Días de retención de registros antes de purga automática
LOG_RETENTION_DAYS=90
```

> [!TIP]
> - **Para discos externos móviles:** Se recomienda **`STORAGE_ID_TYPE="LABEL"`** o **`"UUID"`**, ya que detectará automáticamente el punto de montaje sin importar la ruta asignada por el sistema.
> - **Para copias en carpetas locales o montajes de red (SSHFS / NFS / SMB):** Use **`STORAGE_ID_TYPE="LOCAL_PATH"`** y defina `STORAGE_ID_VALUE="/ruta/a/mi/carpeta"`. El sistema validará los permisos y el marcador sin exigir que sea una partición externa independiente.

---

## Capítulo 3: Guía de Uso - Interfaz Interactiva TUI (`whiptail`)

### 3.1 Inicio de la Interfaz Gráfica de Terminal

Para iniciar la aplicación interactiva, abra su terminal dentro del directorio del proyecto y ejecute:

```bash
./backup_manager.sh
```

El sistema verificará la presencia de `whiptail` y abrirá el menú principal de pantalla completa.

---

### 3.2 Esquema del Menú Principal

```text
┌────────────────────── KeepMyConfig [Perfil: default] ──────────────────────┐
│                                                                             │
│ Bienvenido al gestor integral de copias y recuperación modular en Bash.     │
│ Seleccione la operación que desea realizar:                                 │
│                                                                             │
│    1 [BACKUP]   Realizar Backup Completo                                    │
│    2 [BACKUP]   Realizar Backup por Etiquetas (Tags)                        │
│    3 [BACKUP]   Realizar Backup por Módulo Individual                       │
│    4 [RESTORE]  Restauración Rápida de Datos Sensibles                      │
│    5 [RESTORE]  Restauración Selectiva (Módulo / Histórico AAAAMMDD_HHMMSS) │
│    6 [RESTORE]  Restauración Total                                          │
│    7 [MODULES]  Administrar Módulos y Etiquetas                             │
│    8 [STORAGE]  Gestión de Almacenamiento y Diagnóstico                     │
│    9 [PROFILES] Gestión de Perfiles de Backup                               │
│    0 [SALIR]    Salir del gestor                                            │
│                                                                             │
│                             <Aceptar>      <Cancelar>                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.3 Recorrido Detallado por las 9 Opciones

#### Opción 1: `[BACKUP] Realizar Backup Completo`
- **¿Qué hace?:** Escanea todos los archivos de configuración registrados en `modules.d/*.conf`. Empaqueta, comprime y almacena cada módulo en la carpeta `archives/` del SSD externo.
- **Flujo de Seguridad:** Si detecta módulos con `IS_SENSITIVE=true`, solicita una única vez la contraseña GPG AES-256 (con confirmación de doble entrada).
- **Resultado:** Genera archivos individuales con marca de tiempo `AAAAMMDD_HHMMSS`, actualiza el historial en `logs/backup_history.log` y muestra un reporte detallado con el resumen de la operación.

#### Opción 2: `[BACKUP] Realizar Backup por Etiquetas (Tags)`
- **¿Qué hace?:** Despliega un menú de casillas de verificación (*Checklist*) con las etiquetas disponibles (por ejemplo: `dev`, `ide`, `auth`, `shell`).
- **Uso típico:** Si solo desea actualizar sus entornos de desarrollo antes de una clase práctica, marque `dev` e `ide` mediante la barra espaciadora.

#### Opción 3: `[BACKUP] Realizar Backup por Módulo Individual`
- **¿Qué hace?:** Lista todos los módulos mediante botones de selección única (*Radiolist*).
- **Uso típico:** Actualizar únicamente el módulo `ssh-keys` tras haber generado una nueva llave SSH sin necesidad de procesar el resto de módulos.

#### Opción 4: `[RESTORE] Restauración Rápida de Datos Sensibles`
- **¿Qué hace?:** Localiza el snapshot más reciente de **todos** los módulos clasificados como confidenciales (`IS_SENSITIVE=true`).
- **Flujo:** Solicita la contraseña GPG en una caja oculta (`Passwordbox`), descifra los datos directamente en memoria mediante una tubería segura sin escribir archivos temporales en disco y restaura los ficheros en `$HOME`.
- **Uso típico:** Al llegar por la mañana a una estación de trabajo recién reiniciada, esta opción recupera en un solo paso sus credenciales de VSCode y llaves SSH.

#### Opción 5: `[RESTORE] Restauración Selectiva (Histórico)`
- **¿Qué hace?:**
  1. Permite seleccionar el módulo deseado (ej. `bash-env`).
  2. Consulta el historial de copias archivadas y presenta un menú con las fechas y horas registradas (`AAAAMMDD_HHMMSS`).
  3. Desempaqueta y restaura la versión exacta seleccionada.

#### Opción 6: `[RESTORE] Restauración Total`
- **¿Qué hace?:** Reconstruye completamente el entorno del usuario, procesando secuencialmente el snapshot más reciente de todos los módulos registrados en el almacenamiento.

#### Opción 7: `[MODULES] Administrar Módulos y Etiquetas`
- **¿Qué hace?:** Abre un subasistente interactivo que permite:
  - **Inspeccionar módulos:** Ver las rutas, etiquetas y estado de purga de cualquier módulo.
  - **Crear un nuevo módulo:** Asistente paso a paso que pide el identificador, rutas a respaldar, etiquetas y nivel de seguridad, generando automáticamente el archivo `.conf` en `modules.d/`.
  - **Eliminar un módulo:** Da de baja un archivo de receta.
  - **Añadir etiquetas:** Enriquecer el catálogo `config/default_tags.conf`.

#### Opción 8: `[STORAGE] Gestión de Almacenamiento y Diagnóstico`
- **¿Qué hace?:** Abre un submenú para controlar el almacenamiento y los destinos:
  1. **Ver diagnóstico de almacenamiento y espacio libre:** Audita la conexión, valida el marcador `.backup_storage_marker` y muestra el espacio disponible.
  2. **Listar carpetas de equipo en el almacenamiento:** Muestra todas las carpetas con marcador identificando cuál es la activa actualmente.
  3. **Cambiar carpeta de equipo activa (`STORAGE_SUBDIR`):** Permite conmutar interactivamente el destino predeterminado en `config/config.conf`.
  4. **Inicializar nueva carpeta de equipo en el almacenamiento:** Asistente que crea la estructura completa (`archives/`, `logs/`) y el marcador de seguridad (sugiriendo `Backups/$(hostname)`).

#### Opción 9: `[PROFILES] Gestión de Perfiles de Backup`
- **¿Qué hace?:** Abre el gestor modular de perfiles (`profiles/`):
  1. **Ver detalles del perfil activo:** Inspecciona identificador, nombre, descripción y subdirectorio específico asignado.
  2. **Cambiar perfil activo:** Conmuta el perfil en `config/config.conf` de manera atómica mediante un selector interactivo.
  3. **Crear un nuevo perfil:** Asistente paso a paso para definir un nuevo entorno (`ID`, nombre, descripción y carpeta destino asociada).
  4. **Listar recetas y módulos del perfil activo:** Muestra la lista deduplicada de módulos indicando su alcance exacto: `[Global]`, `[Override]` o `[Exclusivo]`.
  5. **Eliminar un perfil:** Borrado seguro de un perfil y sus módulos específicos (con protección para impedir borrar `default` o el perfil en uso).

---

### 3.4 El Flujo "Vault & Shred" y Advertencias de Seguridad

> [!WARNING]
> **Destrucción Segura de Datos en el Aula:**
> Cuando un módulo está configurado con `IS_SENSITIVE=true` y `PURGE_AFTER_BACKUP=true` (como `ssh-keys` o `vscode-sensitive`), el sistema ejecuta `shred -u -z -n 3` sobre los ficheros originales del ordenador del aula **inmediatamente después de haber verificado con éxito el archivo cifrado en el SSD**.

Al finalizar un backup de módulos con purga activa, la TUI muestra una **alerta visual preventiva**:
```text
┌─────────────────────── ALERTA DE SEGURIDAD ────────────────────────┐
│                                                                    │
│ ATENCIÓN: Se han purgado datos sensibles locales mediante         │
│ 'shred -u' para el módulo 'ssh-keys'.                              │
│                                                                    │
│ Los archivos originales han sido borrados de forma segura del      │
│ equipo del aula. Recuerde restaurar sus datos cuando vuelva a      │
│ utilizarlos.                                                       │
│                                                                    │
│                              <Aceptar>                             │
└────────────────────────────────────────────────────────────────────┘
```

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
| `--backup-all` | *Ninguno* | Realiza el respaldo de todos los módulos registrados. |
| `--backup-tag` | `<tag>` | Respalda únicamente los módulos asociados a la etiqueta `<tag>`. |
| `--backup-module` | `<id>` | Respalda el módulo especificado por su `<id>`. |
| `--restore-sensitive`| *Ninguno* | Restaura todos los módulos sensibles del snapshot más reciente. |
| `--restore-all` | *Ninguno* | Restaura todos los módulos del snapshot más reciente. |
| `--restore-module` | `<id>` | Restaura un módulo específico. |
| `--timestamp` | `<TS>` | *(Opcional)* Especifica la marca de tiempo `AAAAMMDD_HHMMSS` a restaurar. |
| `--purge` | *Ninguno* | Fuerza la purga segura con `shred -u` tras el backup (ignora receta). |
| `--no-purge` | *Ninguno* | Desactiva la purga tras el backup aunque la receta lo tenga activo. |
| `--check-device` | *Ninguno* | Comprueba la detección del almacenamiento y el marcador de seguridad. |
| `--init-target` | `<subdir>` | Inicializa la subcarpeta en el almacenamiento (directorios y marcador). |
| `--set-default` | *Ninguno* | Flag modificador para `--init-target` que lo fija en `config/config.conf`. |
| `--list-targets`| *Ninguno* | Lista todos los destinos y subcarpetas con marcador en el soporte. |
| `--set-active-target` | `<subdir>` | Establece el subdirectorio activo en `config/config.conf`. |
| `--target-subdir` | `<subdir>` | Redirige temporalmente la operación actual a ese subdirectorio. |
| `--profile` | `<id>` | Aplica un perfil específico de forma temporal para la operación actual. |
| `--list-profiles` | *Ninguno* | Lista todos los perfiles de backup configurados en el sistema. |
| `--set-active-profile` | `<id>` | Establece el perfil activo de forma persistente en `config/config.conf`. |
| `--create-profile` | `<id>` | Crea un nuevo perfil de backup y su estructura de módulos. |
| `--list-modules` | *Ninguno* | Imprime en consola todos los módulos registrados y su confidencialidad/ámbito. |
| `--list-tags` | *Ninguno* | Imprime el catálogo de etiquetas disponibles. |
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
```

#### Resolución en Cascada de Módulos
Cuando se ejecuta una operación bajo un perfil activo:
1. **Sobrescritura (*Override*):** Si existe `profiles/<perfil>/modules.d/<modulo>.conf`, prevalece sobre la versión global `modules.d/<modulo>.conf`.
2. **Módulo Exclusivo:** Si un módulo solo existe dentro de `profiles/<perfil>/modules.d/`, solo será visible y ejecutable cuando ese perfil esté activo.
3. **Módulo Global:** Las recetas definidas en `modules.d/` están siempre disponibles como base para todos los perfiles salvo que sean sobrescritas.
4. **Deduplicación:** Las operaciones colectivas (`--backup-all`, `--list-modules`) presentan una vista unificada sin duplicados, indicando el ámbito `[Global]`, `[Override]` o `[Exclusivo]`.

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
- **Síntoma:** El sistema muestra: `No se detectó el SSD externo de backup o falta el marcador de seguridad.`
- **Causa:** El disco no está conectado, está montado bajo otra etiqueta, o no se ha creado el archivo testigo.
- **Solución:**
  1. Compruebe la conexión del disco con `lsblk -f`.
  2. Verifique que `config/config.conf` apunte a la etiqueta correcta.
  3. Asegúrese de que el archivo `.backup_storage_marker` exista dentro del subdirectorio configurado (`Backups/Lliurex25/.backup_storage_marker`).

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

