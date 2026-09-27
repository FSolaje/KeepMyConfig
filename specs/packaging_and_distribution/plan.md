# Plan Técnico Arquitectónico: Empaquetado y Distribución Automatizada (Sub-Hito 12.5)

> **Módulo:** Empaquetado, Instalación sin Privilegios y Distribución para Releases  
> **Rama GitFlow:** `dev/feature/packaging-distribution`  
> **Estado:** Borrador de Plan Técnico  
> **Metodología:** Desarrollo Guiado por Especificaciones (SDD)  

---

## 1. Arquitectura de Componentes de Distribución

El sistema de empaquetado y distribución desacopla la fase de desarrollo/mantenimiento de la fase de despliegue en producción mediante cuatro componentes bien definidos:

```text
KeepMyConfig/
├── assets/
│   ├── keepmyconfig.svg         # Icono vectorial oficial (alta resolución)
│   └── keepmyconfig.desktop     # Plantilla de lanzador Freedesktop
├── scripts/
│   └── package.sh               # Generador reproducible de archivos de distribución
├── install.sh                   # Instalador asistido/desatendido sin privilegios (non-root)
├── uninstall.sh                 # Desinstalador limpio para el usuario
└── .github/workflows/
    └── release.yml              # Pipeline de publicación automatizada en GitHub Releases
```

---

## 2. Detalle Técnico de los Componentes

### 2.1. Artefactos Visuales y Metadatos de Escritorio (`assets/`)

1. **`assets/keepmyconfig.svg`:**
   - Icono vectorial escalable en formato SVG estándar (compatible con `librsvg`, `hicolor-icon-theme` y entornos de escritorio GNOME/XFCE/KDE).
   - Diseño representativo: Escudo protector con terminal de comandos en fondo oscuro, prompt característico de terminal `>_` y engranaje/flechas circulares de respaldo.
2. **`assets/keepmyconfig.desktop`:**
   - Lanzador de escritorio estándar Freedesktop.
   - Detecta y enlaza el emulador de terminal adecuado en tiempo de instalación (`x-terminal-emulator`, `gnome-terminal`, `ptyxis`, `konsole`, `xfce4-terminal`, `xterm`).

---

### 2.2. Generador Reproducible de Distribución (`scripts/package.sh`)

- **Objetivo:** Construir de manera estricta y verificable el paquete `.tar.gz` oficial y su archivo `SHA256SUMS.txt`.
- **Estructura Interna:**
  ```bash
  scripts/package.sh [OPCIONES]
    --version <tag>     # Especificar versión explícita (ej. v0.1.0-alpha.2)
    --output-dir <dir>  # Directorio destino de los artefactos (default: dist/)
    --clean             # Limpiar artefactos previos en el directorio de salida
    --skip-tests        # Omitir el smoke test posterior (no recomendado)
    -h, --help          # Ayuda de uso
  ```

- **Mecanismo de Lista Blanca Estricta:**
  El script no empaqueta directamente con comodines del repositorio. En su lugar, despliega un entorno de preparación (*staging directory*) en una ruta temporal aislada (`mktemp -d`):
  ```text
  STAGING_DIR/
  └── KeepMyConfig-${VERSION}/
      ├── backup_manager.sh
      ├── install.sh
      ├── uninstall.sh
      ├── lib/
      ├── config/
      ├── templates.d/
      ├── modules.d/
      ├── profiles/default/
      ├── markers/
      ├── assets/
      ├── .backup_app_marker
      ├── LICENSE
      ├── README.md
      ├── MANUAL_USUARIO.md
      └── CHANGELOG.md
  ```

- **Normalización de Permisos:**
  - `find "$STAGING_DIR" -type d -exec chmod 755 {} +`
  - `find "$STAGING_DIR" -type f -exec chmod 644 {} +`
  - `chmod 755 "$STAGING_DIR/KeepMyConfig-${VERSION}/backup_manager.sh"`
  - `chmod 755 "$STAGING_DIR/KeepMyConfig-${VERSION}/install.sh"`
  - `chmod 755 "$STAGING_DIR/KeepMyConfig-${VERSION}/uninstall.sh"`

- **Generación de Archivos y Checksums:**
  - `tar -czf "${OUTPUT_DIR}/KeepMyConfig-${VERSION}.tar.gz" -C "$STAGING_DIR" "KeepMyConfig-${VERSION}"`
  - `sha256sum "KeepMyConfig-${VERSION}.tar.gz" > "${OUTPUT_DIR}/SHA256SUMS.txt"`

- **Smoke Test Automatizado:**
  - Descomprime el tarball generado en una carpeta temporal independiente.
  - Verifica que la carpeta raíz sea exactamente `KeepMyConfig-${VERSION}`.
  - Verifica que `backup_manager.sh --help` retorne código de salida 0.
  - Comprueba que ningún archivo no deseado (`.git`, `user_data`, `tests`, `specs`, etc.) esté presente.

---

### 2.3. Instalador sin Privilegios (`install.sh`)

- **Objetivo:** Permitir a cualquier alumno, docente o usuario instalar KeepMyConfig en su cuenta sin privilegios de administración.
- **Rutas Destino XDG:**
  - **Directorio de la Aplicación:** `~/.local/share/KeepMyConfig/`
  - **Enlace Ejecutable en PATH:** `~/.local/bin/keepmyconfig` apuntando a `~/.local/share/KeepMyConfig/backup_manager.sh`
  - **Lanzador de Escritorio:** `~/.local/share/applications/keepmyconfig.desktop`
  - **Icono de Aplicación:** `~/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg`
- **Flujo de Ejecución:**
  1. **Comprobación de Dependencias:** Verifica `bash`, `whiptail`, `tar`, `zstd`, `gpg`, `shred`, `sha256sum`.
  2. **Detección de Emulador de Terminal:** Identifica el emulador instalado en el sistema para configurar el lanzador `.desktop`:
     - Prioridad: `x-terminal-emulator` (estándar Debian/Ubuntu/Lliurex) -> `gnome-terminal` -> `ptyxis` (Ubuntu 24.04+) -> `konsole` -> `xfce4-terminal` -> `xterm`.
  3. **Copia No Destructiva:**
     - Copia los componentes a `~/.local/share/KeepMyConfig/`.
     - Si ya existe `~/.local/share/KeepMyConfig/config/config.conf` y recetas en `modules.d/`, las preserva intactas para no perder configuraciones del usuario.
  4. **Instalación de Enlace e Icono:**
     - Crea `~/.local/bin` si no existe.
     - Enlaza `ln -sf ~/.local/share/KeepMyConfig/backup_manager.sh ~/.local/bin/keepmyconfig`.
     - Instala el icono en el tema hicolor y actualiza caché si `gtk-update-icon-cache` está presente.
  5. **Auditoría del `$PATH`:**
     - Si `~/.local/bin` no está en el `$PATH`, emite un mensaje amigable con las instrucciones exactas para activarlo.
  6. **Flags Soportadas:**
     - `-y`, `--yes`, `--silent`: Instalación desatendida.
     - `--target-dir <dir>`: Ruta alternativa de instalación (por defecto `~/.local/share/KeepMyConfig`).
     - `--force`: Sobrescribir incluso configuraciones existentes.

---

### 2.4. Desinstalador Limpio (`uninstall.sh`)

- **Objetivo:** Eliminar la instalación sin dejar huellas en el sistema de escritorio.
- **Acciones:**
  - Elimina `~/.local/bin/keepmyconfig`.
  - Elimina `~/.local/share/applications/keepmyconfig.desktop`.
  - Elimina `~/.local/share/icons/hicolor/scalable/apps/keepmyconfig.svg`.
  - Por defecto conserva `~/.local/share/KeepMyConfig/` o pregunta interactivamente.
  - Con el flag `--purge`, elimina también `~/.local/share/KeepMyConfig/` por completo.

---

### 2.5. Actualización del Workflow de GitHub Actions (`release.yml`)

- Modificar el paso de empaquetado en `.github/workflows/release.yml`:
  - Reemplazar la llamada inline de `tar` por la ejecución del script estandarizado:
    ```bash
    chmod +x scripts/package.sh
    ./scripts/package.sh --version "${TAG}" --output-dir dist
    ```
  - Adjuntar a la release de GitHub:
    - `dist/KeepMyConfig-${TAG}.tar.gz`
    - `dist/SHA256SUMS.txt`

---

## 3. Plan de Pruebas Unitarias e Integración

Se creará una suite dedicada en **`tests/test_packaging_and_distribution.sh`** que validará:

1. **Test Empaquetado:** `scripts/package.sh` genera el archivo `.tar.gz` y `SHA256SUMS.txt`.
2. **Test Anti-Tarbomb:** El archivo contiene un único directorio raíz con el nombre del paquete.
3. **Test Lista Blanca:** El archivo contiene todos los elementos requeridos y ninguno de la lista negra (`.git`, `user_data`, `tests`, `specs`, etc.).
4. **Test Sumas de Verificación:** `sha256sum -c SHA256SUMS.txt` valida con éxito el paquete generado.
5. **Test Instalador en Entorno Aislado:** `install.sh` ejecutado sobre un `HOME` temporal crea correctamente los enlaces, el archivo `.desktop` y el icono.
6. **Test Idempotencia y Protección:** Una segunda ejecución de `install.sh` no sobrescribe un `config.conf` existente personalizado.
7. **Test Desinstalador:** `uninstall.sh` retira los enlaces y lanzadores correctamente.
