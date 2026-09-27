# Desglose Atómico de Tareas: Sub-Hito 12.5

> **Módulo:** Empaquetado, Instalación sin Privilegios y Distribución para Releases  
> **Rama:** `dev/feature/packaging-distribution`  
> **Metodología:** SDD estricto con commits atómicos por fase verificada  

---

## Fase 0: Especificación y Línea Base Arquitectónica
- [x] Crear especificación funcional detallada (`specs/packaging_and_distribution/spec.md`).
- [x] Crear plan técnico y arquitectura de componentes (`specs/packaging_and_distribution/plan.md`).
- [x] Crear desglose atómico de tareas secuenciales (`specs/packaging_and_distribution/tasks.md`).
- [x] **Hito de Commit 0 (docs):** Consolidado en `702ff8a`.
  ```bash
  docs(spec): definir sistema de empaquetado y distribucion para releases
  ```

---

## Fase 1: Artefactos Visuales y Metadatos de Escritorio (Subfases Atómicas)

### Subfase 1.1: Aislamiento en `.gitignore`
- [x] Añadir carpeta `dist/` a `.gitignore` para aislar compilaciones locales de paquetes.
- [x] Aplicar purga preventiva de caché si procede según Regla 8 de `AGENT.md`.
- [ ] **Hito de Commit 1.1 (chore):**
  ```bash
  chore(git): aislar directorio dist en gitignore para artefactos de empaquetado
  ```

### Subfase 1.2: Icono Vectorial Oficial SVG
- [x] Crear icono vectorial oficial `assets/keepmyconfig.svg` (diseño escalable profesional con escudo de seguridad, terminal `>_` y flechas de sincronización).
- [x] Validar sintaxis XML/SVG y escalabilidad sin degradación.
- [ ] **Hito de Commit 1.2 (feat):**
  ```bash
  feat(assets): incorporar icono vectorial oficial svg para la aplicacion
  ```

### Subfase 1.3: Lanzador de Escritorio Freedesktop
- [x] Crear plantilla de lanzador de escritorio `assets/keepmyconfig.desktop` conforme al estándar XDG Freedesktop (`Categories=Utility;Archiving;`, `Terminal=true`, `Icon=keepmyconfig`).
- [x] Validar formato con `desktop-file-validate` si está disponible en el entorno.
- [ ] **Hito de Commit 1.3 (feat):**
  ```bash
  feat(desktop): incorporar plantilla de lanzador de escritorio freedesktop
  ```

---

## Fase 2: Script Reproducible de Empaquetado y Checksums
- [ ] Crear directorio `scripts/` y el script `scripts/package.sh` con permisos `0755`.
- [ ] Implementar resolución automática de versión (flag `--version`, git tags SemVer o fallback de `CHANGELOG.md`).
- [ ] Implementar mecanismo de lista blanca estricta con directorio temporal de preparación (*staging*).
- [ ] Implementar normalización de permisos UNIX (`0755` directorios y ejecutables, `0644` ficheros regulares).
- [ ] Implementar compresión sin tarbomb (`KeepMyConfig-${VERSION}/`) en `.tar.gz` y `.tar.zst` si está disponible.
- [ ] Implementar generación automática de `SHA256SUMS.txt`.
- [ ] Implementar smoke test integrado para verificar integridad del paquete generado y respuesta de `--help`.
- [ ] **Hito de Commit 2 (feat):**
  ```bash
  feat(packaging): implementar script de empaquetado reproducible y generacion de checksums
  ```

---

## Fase 3: Instalador y Desinstalador sin Privilegios (Non-Root)
- [ ] Crear script `install.sh` con permisos `0755`:
  - [ ] Comprobación previa de dependencias del sistema (`bash`, `whiptail`, `tar`, `zstd`, `gpg`, `shred`).
  - [ ] Detección inteligente del emulador de terminal del sistema para el `.desktop`.
  - [ ] Despliegue en `~/.local/share/KeepMyConfig/` preservando configuraciones y recetas existentes.
  - [ ] Enlace ejecutable en `~/.local/bin/keepmyconfig` y verificación de presencia en `$PATH`.
  - [ ] Instalación de icono en `~/.local/share/icons/hicolor/scalable/apps/` y lanzador `.desktop`.
  - [ ] Soporte para modo interactivo y modo desatendido (`-y`, `--yes`).
- [ ] Crear script `uninstall.sh` con permisos `0755`:
  - [ ] Retirada limpia de binarios, iconos y lanzador de escritorio.
  - [ ] Pregunta interactiva o flag `--purge` para gestionar datos y configuraciones en `~/.local/share/KeepMyConfig/`.
- [ ] **Hito de Commit 3 (feat):**
  ```bash
  feat(installer): incorporar scripts de instalacion y desinstalacion sin privilegios sudo
  ```

---

## Fase 4: Suite de Pruebas Unitarias Automatizadas
- [ ] Crear suite de pruebas `tests/test_packaging_and_distribution.sh`.
- [ ] Test 1: Ejecución de `scripts/package.sh --clean` y generación de `.tar.gz` y `SHA256SUMS.txt`.
- [ ] Test 2: Verificación anti-tarbomb y jerarquía de directorios.
- [ ] Test 3: Verificación de lista blanca y ausencia de ficheros excluidos (`.git`, `user_data`, `tests`, `specs`).
- [ ] Test 4: Verificación criptográfica con `sha256sum -c SHA256SUMS.txt`.
- [ ] Test 5: Instalación aislada con `install.sh` en `HOME` virtual temporal.
- [ ] Test 6: Verificación de idempotencia y no sobreescritura de configuraciones previas.
- [ ] Test 7: Desinstalación con `uninstall.sh` y comprobación de limpieza.
- [ ] Ejecutar la suite completa (11 suites) y certificar 100% de éxito.
- [ ] **Hito de Commit 4 (test):**
  ```bash
  test: incorporar suite de pruebas automatizadas para empaquetado e instalador
  ```

---

## Fase 5: Integración en Workflow de GitHub Actions
- [ ] Actualizar `.github/workflows/release.yml` para invocar `scripts/package.sh`.
- [ ] Adjuntar a la release tanto el paquete `KeepMyConfig-${TAG}.tar.gz` como `SHA256SUMS.txt`.
- [ ] **Hito de Commit 5 (ci):**
  ```bash
  ci(release): integrar empaquetado estandarizado y checksums en workflow de github actions
  ```

---

## Fase 6: Sincronización Mandatoria de Documentación Pública
- [ ] Actualizar [`README.md`](../../README.md) con la guía de instalación y desinstalación sin privilegios.
- [ ] Actualizar [`MANUAL_USUARIO.md`](../../MANUAL_USUARIO.md) con capítulo/sección de instalación XDG y atajo de escritorio.
- [ ] Actualizar [`CHANGELOG.md`](../../CHANGELOG.md) bajo la sección `[Unreleased]`.
- [ ] Actualizar [`PROXIMOS_PASOS.md`](../../PROXIMOS_PASOS.md).
- [ ] Ejecutar escáner SAST obligatorio.
- [ ] **Hito de Commit 6 (docs - aislado):**
  ```bash
  docs: documentar proceso de empaquetado, instalacion y desinstalacion en manual y readme
  ```
