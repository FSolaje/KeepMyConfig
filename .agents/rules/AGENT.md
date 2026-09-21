---
trigger: always_on
---

# Directrices y Parámetros del Agente (AGENT.md)

Este documento define las reglas de comportamiento, estándares de desarrollo, gobernanza Git y parámetros operativos para el agente de IA en el proyecto **BackupConfig**.

---

## 1. Regla Mandatoria: Conventional Commits

Todos los commits realizados en este repositorio deben seguir **estrictamente** la especificación de [Conventional Commits v1.0.0](https://www.conventionalcommits.org/):

### Formato Obligatorio
```text
<tipo>(<ámbito>): <descripción concisa en imperativo>

[cuerpo opcional detallando el motivo y contexto del cambio]

[pie opcional con notas de rotura o referencias a issues/tareas]
```

### Tipos Permitidos
- **`feat`**: Nueva característica o funcionalidad (ej. `feat(model): implementar verificación de marcador en device_model`).
- **`fix`**: Corrección de un error o bug en la lógica, rutas o permisos (ej. `fix(crypto): corregir tubería de descifrado en restore`).
- **`docs`**: Cambios exclusivos en documentación o especificaciones (ej. `docs(sdd): redactar spec y plan para module_model`).
- **`refactor`**: Refactorización de código que no añade funcionalidades ni corrige bugs.
- **`test`**: Creación o ajuste de scripts y suites de verificación (ej. `test(device): añadir test unitario de punto de montaje`).
- **`chore`**: Tareas auxiliares, mantenimiento de configuración, `.gitignore`, setup de git, etc.
- **`style`**: Formateo de código, indentación o ajuste de espaciado sin alterar lógica.

### Ámbitos Sugeridos (`scope`)
- `model`, `view`, `controller`, `modules`, `crypto`, `tui`, `cli`, `storage`, `deps`, `structure`, `security`, `spec`.

---

## 2. Estrategia de Ramas: GitFlow

Se adopta **GitFlow** como modelo de control de versiones y ciclo de ramas:

1. **Ramas Principales:**
   - **`main`**: Versiones estables y publicadas.
   - **`develop`**: Rama base de integración continua activa.
2. **Ramas de Funcionalidad (`feature branches`):**
   - Para cada modelo, vista, controlador o lógica específica, se crea una rama dedicada a partir de `develop`:
     ```text
     dev/feature/<nombre-de-la-feature>
     ```
   - Ejemplos: `dev/feature/device-model`, `dev/feature/module-model`, `dev/feature/crypto-shred`.
3. **Ramas de Corrección (`fix branches`):**
   - Para reparaciones de bugs o incidencias sobre `develop`, se crea una rama dedicada:
     ```text
     dev/fix/<nombre-del-bug>
     ```
   - Ejemplo: `dev/fix/module-admin-wizard`.
4. **Ciclo de Integración:**
   - Cada tarea se implementa, especifica y verifica en su rama de feature o fix correspondiente.
   - Una vez concluida y validada por el escáner de seguridad y pruebas unitarias, se integrará en `develop` preservando el histórico.
5. **Comandos Git Modernos (`git switch` y `git restore`):**
   - Queda prohibido el uso del comando sobrecargado `git checkout`.
   - Para la navegación y creación de ramas se usará exclusivamente `git switch` (ej. `git switch <rama>` o `git switch -c dev/feature/<nombre>`).
   - Para descartar cambios o gestionar el área de preparación (staging) se usará exclusivamente `git restore` (ej. `git restore <archivo>` o `git restore --staged <archivo>`).

---

## 3. Sistema de Versionado Semántico (SemVer), Tags de Git y CHANGELOG

El proyecto adopta de forma mandatoria la especificación [Semantic Versioning 2.0.0](https://semver.org/lang/es/) en conjunción con Conventional Commits y las directrices de publicación de **GitHub Releases**.

### 3.1. Formato de Versión
```text
v<MAJOR>.<MINOR>.<PATCH>[-<PRERELEASE>]
```
- El prefijo **`v`** es obligatorio para todos los tags de Git y releases de GitHub (ej. `v0.1.0-alpha.1`, `v1.0.0`).
- **`MAJOR` (X.0.0):** Cambios que rompen la compatibilidad hacia atrás (*Breaking Changes*).
- **`MINOR` (X.Y.0):** Nuevas funcionalidades o características compatibles hacia atrás (*Features*).
- **`PATCH` (X.Y.Z):** Correcciones de errores o bugs compatibles hacia atrás (*Fixes*).
- **`<PRERELEASE>` (`-alpha.N`, `-beta.N`, `-rc.N`):** Versiones preliminares de prueba, iteración o validación.

### 3.2. Reglas de Incremento según Conventional Commits
Con cada commit o integración de rama en `develop` o `main`, se evaluará el impacto del cambio sobre la numeración:

| Tipo de Cambio (Conventional Commit) | Impacto SemVer (Producción) | Impacto en Fase Pre-Release / Alfa | Ejemplo |
| :--- | :--- | :--- | :--- |
| **Breaking Change** (`feat!: ...`, `fix!: ...`, o pie `BREAKING CHANGE:`) | Incrementa `MAJOR` (`v1.0.0` -> `v2.0.0`) | Incrementa `MINOR` en fase `0.y.z` (`v0.1.0-alpha.X` -> `v0.2.0-alpha.1`) o cambia de fase | Cambio incompatible en CLI o formato de empaquetado |
| **Nueva Funcionalidad** (`feat: ...`) | Incrementa `MINOR` (`v1.0.0` -> `v1.1.0`) | Incrementa `MINOR` si es un salto funcional mayor (`v0.1.0` -> `v0.2.0-alpha.1`) o incrementa iteración alfa si es parte del hito actual (`-alpha.1` -> `-alpha.2`) | Soporte `LOCAL_PATH`, sistema de perfiles, o soporte SSH |
| **Corrección de Bug** (`fix: ...`) | Incrementa `PATCH` (`v1.0.0` -> `v1.0.1`) | Incrementa la iteración de pre-release (`-alpha.1` -> `-alpha.2`) o parche alfa (`v0.1.1-alpha.1`) | Corrección de parámetros en el asistente TUI de módulos |
| **Tareas / Docs / Tests** (`docs:`, `test:`, `chore:`, `refactor:`, `style:`) | No incrementa versión productiva automáticamente; se acumula en el siguiente release | No incrementa número de versión salvo que concluya formalmente un hito de documentación/calidad | Actualización de `MANUAL_USUARIO.md` o suites de pruebas |

### 3.3. Ciclo de Pre-Releases y Publicaciones en GitHub
1. **Detección Automática de Pre-release:**
   Todo tag que contenga un guion seguido de identificador pre-release (ej. `-alpha.1`, `-beta.1`, `-rc.1`) es reconocido automáticamente por GitHub como **`Pre-release`**, diferenciándolo visualmente de las versiones finales **`Latest`** (`v1.0.0`).
2. **Creación de Tags Anotados Obligatoria:**
   Queda prohibido el uso de tags ligeros (lightweight). Siempre se utilizarán tags anotados con mensaje descriptivo del hito:
   ```bash
   git tag -a v0.1.0-alpha.1 -m "release: versión alfa inicial (MVP funcional: MVC, GPG, Shred, TUI/CLI, Multi-target)"
   ```
3. **Mantenimiento Obligatorio de `CHANGELOG.md`:**
   Todo cambio versionado debe quedar registrado en `CHANGELOG.md` siguiendo el estándar [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/):
   - `### Added`: Nuevas funcionalidades incorporadas (`feat`).
   - `### Fixed`: Errores o bugs solventados (`fix`).
   - `### Changed`: Modificaciones en el comportamiento existente o refactorizaciones.
   - `### Security`: Mejoras criptográficas, SAST o purga segura.
   - `### Documentation`: Nuevos manuales o especificaciones.
4. **Protocolo de Evaluación en cada Commit / Integración:**
   En cada solicitud de commit o merge, la IA deberá:
   - Identificar si los cambios ameritan una actualización en la sección `[Unreleased]` de `CHANGELOG.md`.
   - Evaluar si el hito justifica un nuevo tag pre-release o release, proponiéndolo explícitamente al usuario.

---

## 4. Gobernanza Git: Prohibición de Operaciones Autónomas

- **Prohibición Terminante de `git push`:** Queda estrictamente prohibido ejecutar `git push` de forma autónoma.
- **Prohibición de `git commit` Autónomo:** 
  Queda **terminantemente prohibido ejecutar `git commit`** sin cumplir el siguiente protocolo:
  1. Presentar al usuario un resumen claro de los archivos modificados.
  2. Ejecutar la suite de pruebas unitarias asociada a los cambios.
  3. Ejecutar el escáner SAST obligatorio:
     ```bash
     bash user_data/scripts/security_check/security_check.sh
     ```
  4. Mostrar el reporte de seguridad limpio.
  5. **Esperar la orden y aprobación humana explícita:** *"Procede con el commit"*.

---

## 5. Desarrollo Guiado por Especificaciones (SDD) - Regla No-Spec-No-Code

1. **No-Spec-No-Code:** Queda terminantemente prohibido crear o modificar código de producción (en `lib/`, `config/`, etc.) sin que exista una especificación aprobada para la rama activa.
2. **Ciclo Obligatorio por Rama (`dev/feature/<nombre>`):**
   Antes de codificar la lógica de cualquier componente, se deben crear en `specs/<nombre_feature>/`:
   - **`spec.md`**: Especificación de requerimientos funcionales, entradas, salidas y casos borde.
   - **`plan.md`**: Plan técnico arquitectónico, funciones del modelo/vista/controlador y Walkthrough de impacto.
   - **`tasks.md`**: Lista atómica de tareas secuenciales de ejecución con checkboxes.
3. **Aprobación Previa:** Solo tras la revisión de estos tres documentos se procederá a implementar el código y sus pruebas unitarias.

---

## 6. Constitución de Seguridad y Privacidad

- **Cero Credenciales:** Queda estrictamente prohibido incluir contraseñas, tokens de API, rutas absolutas privadas locales (ej. `/home/<usuario>`), correos personales o claves privadas en archivos versionados.
- **Aislamiento Estricto de `user_data/`:**
  Todo el contenido de la carpeta `user_data/` (herramientas locales, scripts de SAST, cachés o datos de usuario) queda **SIEMPRE EXCLUIDO** del repositorio mediante `.gitignore`. Bajo ninguna circunstancia se eliminará del `.gitignore` ni se comitearán archivos de este directorio.
- **SAST Pre-Commit Obligatorio:** Antes de solicitar cualquier commit, la IA debe ejecutar imperativamente:
  ```bash
  bash user_data/scripts/security_check/security_check.sh
  ```
  y verificar que finalice con código de salida 0 sin alertas críticas.

---

## 7. Principios de Arquitectura y Desarrollo

1. **Patrón MVC Estricto en Bash:**
   - **Modelos (`lib/models/`):** Contienen exclusivamente lógica de negocio (empaquetado, cálculo de hashes SHA-256, llamadas a `gpg`, borrado con `shred`, lectura de `.conf`). **Jamás** deben invocar `whiptail`, ni imprimir menús, ni pedir entradas interactivas al usuario. Comunican resultados mediante códigos de retorno numéricos y salidas estructuradas (`CLAVE=VALOR`) por `stdout`.
   - **Vistas (`lib/views/`):** Contienen únicamente la presentación en pantalla (diálogos `whiptail`, formatos ANSI, banners). **Jamás** realizan operaciones sobre el sistema de archivos de backup ni aplican lógica de negocio.
   - **Controlador (`lib/controllers/`):** Recibe las interacciones de la vista o los argumentos de la CLI, llama a los modelos correspondientes y coordina el flujo.
2. **Módulos Independientes (`modules.d/`):**
   - Cada aplicación o configuración es un archivo `.conf` independiente.
   - Las configuraciones sensibles y no sensibles se desacoplan en módulos separados (ej. `vscode-standard.conf` y `vscode-sensitive.conf`).
3. **Seguridad y Entorno sin Privilegios:**
   - Ejecución en **Lliurex 25 / Ubuntu 24.04** como **usuario estándar sin privilegios `sudo`**.
   - Para la purga de datos sensibles en el equipo de origen, usar siempre `shred -u -z -n 3`.
   - Validar obligatoriamente la presencia del archivo marcador `.backup_storage_marker` antes de cualquier escritura hacia el disco de backup para evitar escrituras fantasma en carpetas locales.
4. **Interfaz Dual:**
   - 100% funcional desde la TUI interactiva (`whiptail`) y en modo desatendido por línea de comandos (CLI Headless).

---

## 8. Reglas de Ciclo de Vida (Lifecycle Rules)

- **Think-Before-Act:** Antes de modificar código fuente, la IA debe explicar brevemente qué va a realizar y a qué punto exacto de la especificación técnica (`spec.md`) sirve esa edición.
- **Read-Before-Edit:** Queda prohibido modificar o sobrescribir un archivo sin haber leído previamente su contenido completo en la sesión activa.
- **Uncertainty Marker (`[NEEDS CLARIFICATION]`):** Si se detectan ambigüedades, vacíos de diseño o contradicciones funcionales, la IA se detendrá y lanzará un bloque `[NEEDS CLARIFICATION]` interrogando directamente al usuario, sin asumir ni inventar arquitecturas.
- **Gitignore Retroactivo:** Si se modifica `.gitignore` para añadir nuevas exclusiones, la IA purgará la caché mediante `git rm -r --cached .` y re-indexará antes de presentar los cambios para evitar "Ghost Tracking".

---

## 9. Continuidad de Sesión y Estado

1. **Al iniciar cualquier sesión:**
   - Comprobar automáticamente la existencia del archivo `PROXIMOS_PASOS.md` en el espacio de trabajo.
   - Leer su contenido para retomar el contexto exacto antes de realizar cualquier acción.
2. **Al finalizar un hito o sesión:**
   - Actualizar `PROXIMOS_PASOS.md` reflejando las tareas completadas, el estado del código y los pasos inmediatos siguientes.

