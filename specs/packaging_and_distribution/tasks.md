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
- [x] **Hito de Commit 1.1 (chore):** Consolidado en `128df06`.
  ```bash
  chore(git): aislar directorio dist en gitignore para artefactos de empaquetado
  ```

### Subfase 1.2: Icono Vectorial Oficial SVG
- [x] Crear icono vectorial oficial `assets/keepmyconfig.svg` (diseño escalable profesional con escudo de seguridad, terminal `>_` y flechas de sincronización).
- [x] Validar sintaxis XML/SVG y escalabilidad sin degradación.
- [x] **Hito de Commit 1.2 (feat):** Consolidado en `22245b4`.
  ```bash
  feat(assets): incorporar icono vectorial oficial svg para la aplicacion
  ```

### Subfase 1.3: Lanzador de Escritorio Freedesktop
- [x] Crear plantilla de lanzador de escritorio `assets/keepmyconfig.desktop` conforme al estándar XDG Freedesktop (`Categories=Utility;Archiving;`, `Terminal=true`, `Icon=keepmyconfig`).
- [x] Validar formato con `desktop-file-validate` si está disponible en el entorno.
- [x] **Hito de Commit 1.3 (feat):** Consolidado en `9c82bd0`.
  ```bash
  feat(desktop): incorporar plantilla de lanzador de escritorio freedesktop
  ```

---

## Fase 2: Script Reproducible de Empaquetado Dual y Checksums
- [x] Crear directorio `scripts/` y el script `scripts/package.sh` con permisos `0755`.
- [x] Implementar resolución automática de versión (flag `--version`, git tags SemVer o fallback de `CHANGELOG.md`).
- [x] Implementar soporte para selector de tipo de paquete `--type all|standard|portable` (por defecto `all`).
- [x] Implementar mecanismo de lista blanca estricta con directorios temporales de preparación (*staging*) diferenciados.
- [x] Implementar generación de edición estándar (`KeepMyConfig-${VERSION}`) y edición portable (`KeepMyConfig-${VERSION}-portable`) con marcador `.portable` y lanzador `keepmyconfig.sh`.
- [x] Implementar normalización de permisos UNIX (`0755` directorios y ejecutables, `0644` ficheros regulares).
- [x] Implementar compresión sin tarbomb en `.tar.gz` y `.tar.zst` si está disponible.
- [x] Implementar generación automática unificada de `SHA256SUMS.txt`.
- [x] Implementar smoke test integrado para verificar integridad de ambas ediciones y respuesta de `--help`.
- [x] **Hito de Commit 2 (feat):** Consolidado en `e67aabb`.
  ```bash
  feat(packaging): implementar empaquetado reproducible dual y generacion de checksums
  ```

---

## Fase 3: Instalador y Desinstalador sin Privilegios (Non-Root)
- [x] Crear script `install.sh` con permisos `0755`:
  - [x] Comprobación previa de dependencias del sistema (`bash`, `whiptail`, `tar`, `zstd`, `gpg`, `shred`).
  - [x] Detección inteligente del emulador de terminal del sistema para el `.desktop`.
  - [x] Despliegue en `~/.local/share/KeepMyConfig/` preservando configuraciones y recetas existentes.
  - [x] Enlace ejecutable en `~/.local/bin/keepmyconfig` y verificación de presencia en `$PATH`.
  - [x] Instalación de icono en `~/.local/share/icons/hicolor/scalable/apps/` y lanzador `.desktop`.
  - [x] Soporte para modo interactivo y modo desatendido (`-y`, `--yes`).
  - [x] Asistente de primera instalación (OOBE) con selector guiado de destino universal y perfil inicial.
  - [x] Endurecimiento preventivo de permisos UNIX (read-only `0555`/`0444` en core/lib/templates y `0755`/`0644` en datos de usuario).
- [x] Crear script `uninstall.sh` con permisos `0755`:
  - [x] Retirada limpia de binarios, iconos y lanzador de escritorio.
  - [x] Pregunta interactiva o flag `--purge` para gestionar datos y configuraciones en `~/.local/share/KeepMyConfig/`.
  - [x] Desbloqueo preventivo defensivo con `chmod -R u+w` antes de purgar.
- [x] **Hito de Commit 3.1 (feat):** Consolidado en `513bd5e`.
  ```bash
  feat(installer): incorporar scripts base de instalacion y desinstalacion sin privilegios
  ```
- [x] **Hito de Commit 3.2 (feat):** Consolidado en `8fe5d3f`.
  ```bash
  feat(installer): implementar asistente de configuracion inicial de rutas destino y perfiles
  ```
- [x] **Hito de Commit 3.3 (feat):** Consolidado en `16b84f8`.
  ```bash
  feat(security): aplicar endurecimiento preventivo de permisos de solo lectura en instalador
  ```

---

## Fase 4: Suite de Pruebas Unitarias Automatizadas
- [x] Crear suite de pruebas `tests/test_packaging_and_distribution.sh`.
- [x] Test 1: Ejecución de `scripts/package.sh --clean` y generación de `.tar.gz` y `SHA256SUMS.txt`.
- [x] Test 2: Verificación anti-tarbomb y jerarquía de directorios.
- [x] Test 3: Verificación de lista blanca y ausencia de ficheros excluidos (`.git`, `user_data`, `tests`, `specs`).
- [x] Test 4: Verificación criptográfica con `sha256sum -c SHA256SUMS.txt`.
- [x] Test 5: Instalación aislada con `install.sh` en `HOME` virtual temporal.
- [x] Test 6: Verificación de endurecimiento de permisos UNIX y bloqueo contra inyecciones.
- [x] Test 7: Verificación de idempotencia y no sobreescritura de configuraciones previas en reinstalación.
- [x] Test 8: Lanzador portable directo `keepmyconfig.sh`.
- [x] Test 9: Desinstalación limpia preservando datos de usuario.
- [x] Test 10: Desinstalación con `--purge` y comprobación de purga completa.
- [x] Ejecutar la suite completa (11 suites con 624 pruebas) y certificar 100% de éxito.
- [x] **Hito de Commit 4 (test):** Consolidado en `2b6957c`.
  ```bash
  test: incorporar suite de pruebas automatizadas para empaquetado e instalador
  ```

---

## Fase 5: Integración en Workflow de GitHub Actions
- [x] Actualizar `.github/workflows/release.yml` para invocar `scripts/package.sh`.
- [x] Adjuntar a la release tanto los paquetes `KeepMyConfig-${TAG}.tar.*` como `SHA256SUMS.txt`.
- [x] **Hito de Commit 5 (ci):** Consolidado en `fb8ac1e`.
  ```bash
  ci(release): integrar empaquetado estandarizado y checksums en workflow de github actions
  ```

---

## Fase 6: Sincronización Mandatoria de Documentación Pública
- [x] Actualizar [`README.md`](../../README.md) con la guía de instalación y desinstalación sin privilegios.
- [x] Actualizar [`MANUAL_USUARIO.md`](../../MANUAL_USUARIO.md) con capítulo/sección de instalación XDG y atajo de escritorio.
- [x] Actualizar [`CHANGELOG.md`](../../CHANGELOG.md) bajo la sección `[Unreleased]`.
- [x] Actualizar [`PROXIMOS_PASOS.md`](../../PROXIMOS_PASOS.md).
- [x] Ejecutar escáner SAST obligatorio.
- [ ] **Hito de Commit 6 (docs - aislado):**
  ```bash
  docs: documentar proceso de empaquetado, instalacion y desinstalacion en manual y readme
  ```
