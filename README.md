# KeepMyConfig - Gestor de Backup y Recuperación Modular en Terminal

[![Bash 5.0+](https://img.shields.io/badge/bash-5.0%2B-blue.svg)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/platform-linux-lightgrey.svg)](https://www.kernel.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![SemVer 2.0.0](https://img.shields.io/badge/semver-2.0.0-green.svg)](https://semver.org/)
[![Status: Early Alpha](https://img.shields.io/badge/status-early%20alpha%20(experimental)-red.svg)](https://github.com/FSolaje/KeepMyConfig)

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

**KeepMyConfig** es un gestor modular y desacoplado de copias de seguridad, cifrado y restauración en terminal bajo arquitectura **MVC en Bash puro**, diseñado específicamente para entornos educativos y corporativos con permisos restringidos (sin privilegios `sudo`) como **Lliurex 25 (Ubuntu 24.04 LTS)**.

Resuelve de forma definitiva el problema de la **congelación de discos y pérdidas de datos** en aulas de Formación Profesional y puestos compartidos, permitiendo respaldar entornos de desarrollo, credenciales temporales y dotar de persistencia a las configuraciones en discos externos (SSD/USB) o carpetas locales seguras.

---

## 1. Características Clave

- 🛡️ **100% Non-Root:** No requiere ni solicita permisos de superusuario (`sudo`). Todo opera en el espacio del usuario y sus puntos de montaje.
- 🔐 **Gestión Efímera "Vault & Shred":** Cifrado simétrico de datos sensibles con **GPG (AES-256)** y destrucción segura en el equipo local mediante **`shred -u -z -n 3`**.
- 🗂️ **Sistema de Perfiles & Convención Zero-Config:** Gestión multi-perfil (`docente`, `desarrollo`, `default`) con aislamiento automático de copias en subdirectorios `<DESTINO>/<perfil>`.
- 🧩 **Biblioteca de Plantillas (`templates.d/`):** Catálogo de recetas predefinidas listas para activar (`vscode`, `ssh-keys`, `bash-env`, `firefox`, `git-config`, etc.).
- 🛑 **Pre-Flight Safety Gate:** Matriz interactiva de impacto previo y alertas rojas ante borrados destructivos antes de autorizar cualquier respaldo.
- 🧪 **Modo Sandbox Aislado:** Entorno seguro en `user_data/sandbox/` con un **Home Virtual** completo para probar recetas y borrado seguro sin tocar datos reales.
- 📦 **Distribución Dual:** Disponible en versión instalable integrada en el escritorio (XDG) y versión portable autónoma para pendrives.

---

## 2. Instalación y Despliegue

KeepMyConfig se publica de forma oficial en [GitHub Releases](https://github.com/FSolaje/KeepMyConfig/releases) en dos modalidades:

### Requisitos Mínimos
- **Sistema Operativo:** Lliurex 25 / Ubuntu 24.04 LTS o cualquier distribución Linux moderna.
- **Intérprete y herramientas base:** `bash` (>= 5.0), `whiptail`, `tar`, `zstd` (o `gzip`), `gpg` y `coreutils` (`shred`, `sha256sum`). *(Incluidas por defecto en la inmensa mayoría de distribuciones).*

### Opción A: Edición Estándar (Instalable bajo XDG Freedesktop)
Recomendada para puestos de trabajo fijos o cuentas de usuario individuales:

```bash
# 1. Descargar y descomprimir el paquete oficial
tar -xzf KeepMyConfig-v0.1.0-alpha.2.tar.gz
cd KeepMyConfig-v0.1.0-alpha.2

# 2. Ejecutar el instalador asistido (sin sudo)
./install.sh
```
- **Integración Freedesktop:** Despliega en `~/.local/share/KeepMyConfig/`, genera el enlace ejecutable en `~/.local/bin/keepmyconfig`, instala el icono SVG oficial y añade el lanzador al menú de aplicaciones de GNOME, KDE, XFCE o MATE.
- **Endurecimiento UNIX (Read-Only):** Protege el código ejecutable y las librerías con permisos de solo lectura (`0555` / `0444`), evitando manipulaciones accidentales o inyecciones de código.
- **Instalación Desatendida:**
  ```bash
  ./install.sh --yes --backup-dest ~/Backups/KeepMyConfig --initial-profile trabajo
  ```
- **Desinstalación Limpia:**
  ```bash
  ~/.local/share/KeepMyConfig/uninstall.sh          # Preserva tus configuraciones y perfiles
  ~/.local/share/KeepMyConfig/uninstall.sh --purge  # Elimina la aplicación y todos sus datos
  ```

### Opción B: Edición Portable (Plug & Play para Unidades Externas)
Diseñada para transportar tu entorno en un pendrive o disco SSD externo y usarlo en cualquier equipo de aula:

```bash
# 1. Descomprimir directamente en la raíz de tu pendrive o disco externo
tar -xzf KeepMyConfig-v0.1.0-alpha.2-portable.tar.gz
cd KeepMyConfig-v0.1.0-alpha.2-portable

# 2. Ejecutar sin instalar nada en el sistema
./keepmyconfig.sh
```
*Compatible al 100% con sistemas de archivos FAT32, exFAT y NTFS sin depender de enlaces simbólicos UNIX.*

---

## 3. Modos de Uso Más Relevantes

Una vez instalado (o desde la versión portable), el sistema ofrece interfaz visual en terminal y órdenes directas por línea de comandos:

### A. Interfaz Interactiva TUI (Uso Diario Recomendado)
Inicia la interfaz gráfica de terminal con telemetría en tiempo real y navegación guiada:
```bash
keepmyconfig
```
*(En el primer arranque, lanza automáticamente el asistente de bienvenida para detectar discos y configurar tu ruta de copias).*

### B. Comandos CLI Esenciales
Para tareas inmediatas, secuencias de arranque o integración en scripts:

| Acción | Comando | Descripción |
| :--- | :--- | :--- |
| **Respaldo Completo** | `keepmyconfig --backup-all` | Respalda todos los módulos activos del perfil actual. |
| **Restauración Matinal** | `keepmyconfig --restore-sensitive` | Descifra y restaura inmediatamente credenciales y llaves SSH. |
| **Copia y Purga Segura** | `keepmyconfig --backup-tag sensitive --purge` | Respalda datos sensibles con GPG y los destruye localmente con `shred`. |
| **Modo Sandbox Seguro** | `keepmyconfig --test-mode` | Inicia la TUI en un entorno aislado con Home Virtual de prueba. |
| **Asistente de Almacenamiento** | `keepmyconfig --setup` | Reconfigura la ruta de backup y comprueba discos externos. |
| **Listar Módulos y Estado** | `keepmyconfig --list-modules` | Muestra qué recetas están activadas `[ON]` o inactivas `[OFF]`. |

> [!TIP]
> 📖 **¿Necesitas más opciones o automatización con `cron`?**  
> Para la guía exhaustiva de todas las banderas CLI, sintaxis de recetas personalizadas, gestión avanzada de perfiles y resolución de problemas, consulta el [Manual de Usuario y Administración](MANUAL_USUARIO.md).

---

## 4. El Flujo de Seguridad "Vault & Shred"

Para evitar que contraseñas, perfiles de navegador o llaves SSH (`id_rsa`) queden expuestas en ordenadores compartidos tras finalizar la clase o jornada, KeepMyConfig implementa un ciclo de vida efímero:

```text
[Archivos Locales en $HOME]
           │
           ▼  (keepmyconfig --backup-tag sensitive --purge)
 1. Cifrado GPG Simétrico (AES-256) hacia el SSD/USB
           │
           ▼
 2. Verificación de Integridad y Hash SHA-256 en Destino
           │
           ▼
 3. Destrucción Irreversible Local con 'shred -u -z -n 3'
           │
      [Equipo Limpio sin Rastro de Credenciales]
           │
           ▼  (Al día siguiente: keepmyconfig --restore-sensitive)
 4. Descifrado en Tubería y Restauración Instantánea de Permisos (600/700)
```

---

## 5. Arquitectura del Proyecto

Construido bajo el patrón **Modelo-Vista-Controlador (MVC)** estricto en Bash:

```text
KeepMyConfig/
├── backup_manager.sh        # Entrypoint principal (CLI/TUI) y resolución canónica
├── install.sh               # Instalador asistido sin privilegios (XDG & Hardening)
├── uninstall.sh             # Desinstalador limpio con soporte de purga (--purge)
├── config/                  # Configuración global (BACKUP_DESTINATION, perfil activo)
├── templates.d/             # Biblioteca de plantillas y recetas predefinidas (.conf)
├── modules.d/               # Catálogo de recetas activas globales
├── profiles/                # Perfiles de usuario (default, docente, etc.) y módulos exclusivos
├── lib/
│   ├── models/              # Lógica de negocio (device, profile, module, backup, restore, crypto)
│   ├── views/               # Vistas desacopladas en Whiptail (TUI) y ANSI
│   └── controllers/         # Enrutamiento, pre-flight safety gate y orquestación MVC
├── assets/                  # Icono vectorial oficial SVG y plantilla .desktop
├── scripts/                 # Herramientas de empaquetado y distribución (package.sh)
└── tests/                   # Suite de pruebas unitarias automatizadas (624 tests)
```

---

## 6. Empaquetado y Verificación Reproducible

Si deseas construir los paquetes oficiales estándar y portables a partir del código fuente:

```bash
# Compilar paquetes (.tar.gz y .tar.zst) con normalización de permisos y anti-tarbomb
./scripts/package.sh --type all --clean

# Validar firmas criptográficas generadas
sha256sum -c dist/SHA256SUMS.txt
```

---

## 7. Licencia y Ámbito

Este software se distribuye bajo licencia **MIT**. Diseñado y optimizado para su despliegue en ciclos formativos de Grado Superior de Desarrollo de Aplicaciones Web (DAW) y centros educativos de la Comunitat Valenciana.
