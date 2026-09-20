# Documento de Especificación Técnica (SDD): Sistema de Backup Modular en Terminal

**Proyecto:** Gestor de Copias de Seguridad Atómicas, Efímeras y Sensibles en Terminal  
**Arquitectura:** MVC (Modelo - Vista - Controlador) en Bash  
**Entorno Objetivo:** Lliurex 25 (Ubuntu 24.04 LTS), ejecución de usuario sin privilegios `sudo`, terminal pura (TTY / SSH).  
**Almacenamiento:** Unidad Externa (SSD/USB) con verificación de dispositivo.  

---

## 1. Visión y Objetivos del Proyecto

El sistema tiene por objeto proporcionar una solución de respaldo y restauración en terminal para puestos de trabajo con permisos restringidos y sujetos a políticas de restauración periódica (SAI). Sus pilares fundamentales son:

1. **Arquitectura desacoplada (MVC):** Separación estricta entre la lógica de negocio (Modelos), la presentación interactiva (Vistas en `whiptail`) y la coordinación (Controlador), permitiendo sustituir la TUI en el futuro sin modificar el motor de backup.
2. **Modularidad atómica:** Cada aplicación o conjunto de configuraciones constituye una unidad autónoma con su propio ciclo de vida e histórico.
3. **Manejo de datos sensibles y ciclo de vida efímero (*Vault & Shred*):** Capacidad de cifrar datos críticos y destruirlos de forma segura en el equipo anfitrión (`shred -u`), restaurándolos bajo demanda con un único comando.
4. **Validación estricta de destino:** Mecanismo contra desastres que comprueba marcadores y UUID/Etiqueta para evitar escrituras en carpetas locales cuando el SSD no está montado.
5. **Doble modalidad (TUI y CLI Headless):** Operable visualmente mediante `whiptail` o mediante argumentos de línea de comandos para scripts y conexiones TTY remotas rápidas.

---

## 2. Arquitectura del Sistema (Patrón MVC en Bash)

```
BackupConfig/
├── backup_manager.sh             # Punto de entrada (CLI + invocación del Controller)
├── config/
│   ├── config.env                # Configuración global (UUID/LABEL, rutas, defaults)
│   └── default_tags.conf         # Etiquetas predefinidas (dev, sensitive, system, etc.)
├── modules.d/                    # Directorio de módulos independientes
│   ├── vscode-standard.conf      # Módulo no sensible de VSCode
│   ├── vscode-sensitive.conf     # Módulo sensible de VSCode (tokens, auth)
│   ├── bash-env.conf
│   └── ssh-keys.conf
├── lib/
│   ├── models/
│   │   ├── device_model.sh       # Detección UUID/LABEL, montajes y marcadores
│   │   ├── module_model.sh       # CRUD de módulos, validación y filtrado por tags
│   │   ├── backup_model.sh       # Empaquetado tar/zstd, cálculo de manifests y diffs
│   │   ├── restore_model.sh      # Desempaquetado, permisos y ejecución de hooks
│   │   └── crypto_model.sh       # Cifrado/Descifrado GPG AES-256 y shred seguro
│   ├── views/
│   │   ├── whiptail_view.sh      # Implementación completa de pantallas en whiptail
│   │   └── ansi_view.sh          # Formateo de banners, colores y mensajes de log
│   └── controllers/
│       └── app_controller.sh     # Enrutador de eventos, menú principal y CLI router
└── markers/
    ├── .backup_app_marker        # Marcador en la raíz de la app
    └── .backup_storage_marker    # Marcador presente en la raíz del SSD externo
```

### 2.1 Responsabilidades

- **Modelos (`lib/models/`):**
  - No imprimen menús ni dialogan con el usuario.
  - Retornan códigos de salida estándar (0 = éxito, >0 = error) y datos vía `stdout` (listas delimitadas, JSON plano o variables).
- **Vistas (`lib/views/`):**
  - Se encargan exclusivamente de la interacción: capturan entradas de usuario mediante `whiptail` (`--menu`, `--checklist`, `--passwordbox`, `--gauge`, `--msgbox`, `--yesno`).
  - No realizan operaciones de disco ni cálculos de copia.
- **Controlador (`lib/controllers/`):**
  - Recibe la acción del usuario desde la vista o desde los flags de `backup_manager.sh`.
  - Invoca a los modelos correspondientes, verifica estados de retorno y solicita a la vista que muestre el resultado o error.

---

## 3. Especificación del Sistema de Módulos

### 3.1 Estructura de un Módulo (`modules.d/<module_id>.conf`)
Cada módulo es un archivo independiente con sintaxis declarativa Bash:

```bash
# Identificador único (alfanumérico sin espacios)
MODULE_ID="vscode-sensitive"

# Nombre descriptivo en menús
MODULE_NAME="VSCode - Credenciales, Sincronización y Tokens"

# Etiquetas asignadas para respaldos/restauraciones en bloque
MODULE_TAGS=("dev" "sensitive")

# Rutas a respaldar (relativas a $TARGET_USER_HOME)
MODULE_PATHS=(
    ".config/Code/User/globalStorage/state.vscdb"
    ".config/Code/User/sync"
)

# Indicador de sensibilidad
# Si es true: se fuerza cifrado GPG simétrico (AES-256)
IS_SENSITIVE=true

# Eliminación segura tras el respaldo (Vault & Shred)
# Si es true: tras verificar la copia en el SSD, se eliminan los archivos locales con shred -u
# Si es false: los archivos locales en el equipo anfitrión permanecen intactos
PURGE_AFTER_BACKUP=true

# Hook posterior a la restauración (opcional)
POST_RESTORE_HOOK=""
```

### 3.2 Caso de Uso: Desacoplamiento VSCode
Para satisfacer el caso de uso planteado, VSCode se desglosa en dos recetas independientes:
1. **`vscode-standard.conf`**:
   - `MODULE_TAGS=("dev" "editor")`
   - `IS_SENSITIVE=false`
   - `PURGE_AFTER_BACKUP=false`
   - `MODULE_PATHS=(".config/Code/User/settings.json" ".config/Code/User/keybindings.json" ".config/Code/User/snippets")`
   - *Comportamiento:* Copia abierta sin cifrar, nunca se purga del equipo local.
2. **`vscode-sensitive.conf`**:
   - `MODULE_TAGS=("dev" "sensitive")`
   - `IS_SENSITIVE=true`
   - `PURGE_AFTER_BACKUP=true`
   - `MODULE_PATHS=(".config/Code/User/globalStorage/state.vscdb" ".config/Code/User/sync")`
   - *Comportamiento:* Requiere contraseña GPG, genera `.tar.zst.gpg` y purga automáticamente con `shred -u` en el equipo local tras confirmar la integridad del respaldo.

### 3.3 Gestión Dinámica de Módulos y Etiquetas desde TUI
La vista `whiptail` proporcionará un asistente de administración:
- **Crear nuevo módulo:** Formulario asistido que solicita ID, nombre, rutas, selección de etiquetas (mediante checklist) y flag sensible.
- **Editar / Eliminar módulo:** Listado de módulos existentes en `modules.d/`.
- **Gestión de etiquetas:** Posibilidad de crear etiquetas personalizadas que se guardarán en `config/default_tags.conf` junto a las predeterminadas (`dev`, `sensitive`, `system`, `office`).

---

## 4. Identificación de Dispositivos y Seguridad de Rutas

Para evitar pérdida de datos o escrituras en el disco interno si el SSD se desmonta:
1. **Configuración en `config/config.env`:**
   - `TARGET_USER_HOME`: Ruta al home a respaldar (por defecto `$HOME`).
   - `STORAGE_ID_TYPE`: Tipo de identificación (`LABEL`, `UUID`, o `STATIC_PATH`).
   - `STORAGE_ID_VALUE`: Valor identificador (ej: `DISCO_BACKUP` o el UUID de partición obtenido por `blkid`/`lsblk`).
   - `STORAGE_SUBDIR`: Subcarpeta dentro del SSD (ej: `Backups/Lliurex25`).
2. **Archivos Marcadores (*Safety Markers*):**
   - **Marcador en SSD:** `$BACKUP_DIR/.backup_storage_marker`
   - **Marcador en App:** Carpeta del proyecto contiene `.backup_app_marker`
3. **Flujo de Comprobación (`device_model.sh`):**
   - Resuelve el punto de montaje actual del dispositivo según `LABEL` o `UUID`.
   - Verifica que el archivo `.backup_storage_marker` exista y sea legible en el destino.
   - Si no existe: la ejecución se aborta de inmediato con una alerta clara en la TUI, impidiendo escribir en una ruta local fantasma.

---

## 5. Motor de Respaldo, Histórico y Logs de Auditoría

### 5.1 Convención de Marcas de Tiempo
- Formato estricto: `AAAAMMDD_HHMMSS` (ejemplo: `20260918_153045`).

### 5.2 Estructura en Disco Externo
```text
<PUNTO_MONTAJE_SSD>/Backups/
├── .backup_storage_marker
├── archives/
│   ├── vscode-standard/
│   │   ├── 20260918_090000.tar.zst
│   │   ├── 20260918_090000.manifest.log
│   │   ├── 20260918_143000.tar.zst
│   │   └── 20260918_143000.manifest.log
│   └── vscode-sensitive/
│       ├── 20260918_143000.tar.zst.gpg
│       └── 20260918_143000.manifest.log
└── logs/
    └── backup_history.log
```

### 5.3 Contenido del Manifest y Detección de Cambios
Cada archivo `.manifest.log` incluye:
- **Cabecera:** Módulo, Timestamp, Usuario, Hostname, Algoritmo de compresión/cifrado.
- **Inventario:** Lista detallada de archivos respaldados con tamaño en bytes y suma SHA-256.
- **Diff respecto al histórico anterior:**
  - Archivos añadidos (`+`).
  - Archivos modificados (`~`).
  - Archivos eliminados (`-`).

---

## 6. Cifrado y Purga Segura (*Vault & Shred*)

### 6.1 Cifrado Simétrico GPG
- Para los módulos con `IS_SENSITIVE=true`, el flujo ejecuta:
  ```bash
  tar -I 'zstd -3' -cf - -C "$TARGET_USER_HOME" "${PATHS[@]}" | \
  gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase-fd 0 -o "$DEST_FILE"
  ```
- La contraseña se solicita mediante el widget `--passwordbox` de `whiptail` y nunca se almacena en disco ni en variables de entorno globales.

### 6.2 Purga Segura con `shred`
- La purga se ejecuta de acuerdo a la configuración del módulo (`PURGE_AFTER_BACKUP=true`) o cuando se invoque con el flag explícito `--purge`.
- Precedencia y control:
  - Si un módulo tiene `PURGE_AFTER_BACKUP=true`, se purga automáticamente salvo que se use el flag `--no-purge`.
  - Si un módulo tiene `PURGE_AFTER_BACKUP=false`, no se purga salvo que se invoque con `--purge`.
  - En la interfaz TUI, se presentará confirmación visual informando los módulos que tienen activada la purga por configuración.
- Procedimiento estricto de purga:
  1. Se verifica la integridad del archivo generado en el SSD (test de descompresión o verificación de integridad del paquete cifrado).
  2. Solo tras confirmar la integridad en el SSD, para cada archivo respaldado:
     ```bash
     shred -u -z -n 3 "$TARGET_USER_HOME/$FILE"
     ```
  3. Los directorios vacíos remanentes se eliminan limpiamente con `rmdir -p 2>/dev/null`.
- **Garantía:** Los datos sensibles desaparecen por completo del almacenamiento físico del centro de trabajo antes de desconectar el SSD.

---

## 7. Flujos de Restauración

1. **Restauración Express Sensible:**
   - Comando directo: `./backup_manager.sh --restore-sensitive`
   - Acción: Filtra todos los módulos con `IS_SENSITIVE=true`, solicita la contraseña GPG una única vez y restaura el último estado válido de cada uno.
2. **Restauración por Etiquetas:**
   - La TUI presenta las etiquetas activas (`dev`, `system`, etc.) en un checklist; restaura los últimos backups de los módulos asociados.
3. **Restauración Atómica por Aplicación:**
   - Permite seleccionar un módulo concreto y examinar el histórico de marcas de tiempo (`AAAAMMDD_HHMMSS`), restaurando una versión anterior si se desea revertir una configuración.
4. **Restauración Total:**
   - Procesa secuencialmente todos los módulos disponibles en el SSD para reconstruir el entorno completo tras un restablecimiento del SAI.

---

## 8. Interfaces de Usuario

### 8.1 Menú Principal TUI (`whiptail`)
```text
┌───────────────────────────────────────────────────────────────┐
│        SISTEMA DE BACKUP Y RECUPERACIÓN - LLIUREX 25          │
│                      [Patrón MVC / Bash]                      │
├───────────────────────────────────────────────────────────────┤
│ 1.  [BACKUP]    Realizar Backup Completo                      │
│ 2.  [BACKUP]    Realizar Backup por Etiquetas (Tags)          │
│ 3.  [BACKUP]    Realizar Backup por Módulo Individual         │
│ 4.  [RESTORE]   Restauración Rápida de Datos Sensibles        │
│ 5.  [RESTORE]   Restauración Selectiva (Módulo / Histórico)   │
│ 6.  [RESTORE]   Restauración Total                            │
│ 7.  [MODULES]   Administrar Módulos y Etiquetas               │
│ 8.  [CONFIG]    Verificar Disco Externo y Estado              │
│ 0.  [SALIR]     Salir del gestor                              │
└───────────────────────────────────────────────────────────────┘
```

### 8.2 Interfaz CLI Headless (Servidores y TTY Remota)
```bash
./backup_manager.sh --help
./backup_manager.sh --backup-all [--purge | --no-purge]
./backup_manager.sh --backup-tag <tag_name> [--purge | --no-purge]
./backup_manager.sh --backup-module <module_id> [--purge | --no-purge]
./backup_manager.sh --restore-sensitive
./backup_manager.sh --restore-all
./backup_manager.sh --restore-module <module_id> [--timestamp <AAAAMMDD_HHMMSS>]
./backup_manager.sh --check-device
```

---

## 9. Criterios de Aceptación y Pruebas
1. **Prueba de desacoplamiento:** Separar VSCode en `vscode-standard` y `vscode-sensitive`, verificar que ambos pueden respaldarse y restaurarse de forma independiente.
2. **Prueba de integridad de cifrado:** Comprobar que un módulo sensible no puede desencriptarse con contraseña errónea y que se empaqueta en AES-256.
3. **Prueba de purga segura:** Comprobar con `test -f` que los ficheros sensibles desaparecen del `$HOME` tras un backup con purga.
4. **Prueba de protección de disco:** Ejecutar el backup con el SSD desconectado; el sistema debe abortar limpiamente sin crear carpetas falsas en `/media/$USER/`.
5. **Prueba sin privilegios:** Todo el conjunto debe ejecutarse con éxito con un usuario estándar sin privilegios `sudo`.
