# Desglose Atómico de Tareas: Gestor Robusto de Rutas e Inicialización de Almacenamiento

> **Rama:** `dev/fix/path-manager-and-profile-storage-init`  
> **Metodología:** SDD estricto con commits atómicos por fase verificada  

---

## Fase 0: Especificación y Línea Base Arquitectónica
- [x] Crear especificación técnica detallada (`specs/robust_path_manager_and_profile_storage/spec.md`).
- [x] Crear plan técnico y arquitectura de componentes (`specs/robust_path_manager_and_profile_storage/plan.md`).
- [x] Crear desglose atómico de tareas secuenciales (`specs/robust_path_manager_and_profile_storage/tasks.md`).
- [x] **Hito de Commit 0 (docs - mandatorio previo a codificación):**
  ```bash
  docs(spec): definir requerimientos, plan tecnico y tareas para gestor robusto de rutas e inicializacion de perfiles
  ```

---

## Fase 1: Saneamiento y Desacoplamiento de Rutas en `profile_model.sh`
- [x] Modificar `profile_model_sanitize_target_subdir` en `lib/models/profile_model.sh`:
  - Preservar rutas absolutas completas sin despojar la barra inicial `/`.
  - Normalizar rutas con tilde `~` y prefijos de usuario.
  - Saneamiento de subcarpetas relativas estrictas.
- [x] Modificar `profile_model_get_destination`:
  - Si el destino del perfil es una ruta absoluta (`^/`), devolverlo directamente sin concatenar al `base_dest`.
  - Si es una subcarpeta relativa, concatenar una sola vez al `base_dest`.
- [x] **Hito de Commit 1 (fix):**
  ```bash
  fix(profile): desacoplar destinos absolutos y subcarpetas relativas en perfiles
  ```

---

## Fase 2: Normalización Canónica y Detección Anti-Recursión en `device_model.sh`
- [x] Implementar `device_model_normalize_path` para purgar barras consecutivas (`//` -> `/`) y trailing slashes.
- [x] Implementar `device_model_detect_path_recursion` para detectar duplicaciones o anidamiento de prefijos base.
- [x] Integrar detector en `device_model_validate_storage` emitiendo error `DEV_ERR_RECURSIVE_PATH` (`12`) y bloqueando la operación.
- [x] **Hito de Commit 2 (fix):**
  ```bash
  fix(device): incorporar normalizacion canonica de rutas y detector de recursion
  ```

---

## Fase 3: Despliegue Asistido del Marcador al Crear Perfiles (`app_controller.sh`)
- [x] Actualizar el asistente interactivo de creación de perfiles (`controller_handle_create_profile`):
  - Clarificar las opciones de destino en la TUI (Zero-Config, subcarpeta relativa o ruta absoluta).
  - Resolver el destino efectivo del perfil recién creado.
  - Comprobar la presencia del marcador `.backup_storage_marker`.
  - Desplegar diálogo afirmativo/negativo en TUI ofreciendo inicializar la carpeta y desplegar el marcador en ese instante.
  - Soporte de flag `--init-storage` / `--yes` en CLI.
- [x] **Hito de Commit 3 (feat):**
  ```bash
  feat(controller): ofrecer despliegue automatico de marcador al crear o configurar perfil
  ```

---

## Fase 4: Salvaguarda Pre-Shred Reforzada (`backup_model.sh`)
- [x] Modificar `backup_model_run` y `backup_model_run_all`:
  - Verificar que el archivo respaldado existe en disco y su tamaño es mayor que 0 antes de autorizar la purga.
  - Verificar que la ruta no contiene anomalías sintácticas (`//`).
  - Abortar la purga y preservar los archivos locales si la comprobación falla.
- [x] **Hito de Commit 4 (fix):**
  ```bash
  fix(backup): reforzar verificacion de integridad de archivo y ruta previo a la purga shred
  ```

---

## Fase 5: Suite de Pruebas Unitarias Automatizadas
- [x] Crear suite `tests/test_path_manager.sh` cubriendo:
  - Rutas absolutas independientes en perfiles.
  - Subcarpetas relativas en perfiles.
  - Detección de duplicación y bloqueo ante recursión.
  - Despliegue asistido del marcador en `controller_handle_create_profile`.
  - Salvaguarda pre-shred ante fallos de archivo.
- [x] Ejecutar la suite completa y certificar 100% de éxito.
- [x] **Hito de Commit 5 (test):**
  ```bash
  test: incorporar suite unitaria de validacion de rutas e inicializacion de perfil
  ```

---

## Fase 6: Documentación Pública y Sincronización
- [x] Actualizar [`MANUAL_USUARIO.md`](../../MANUAL_USUARIO.md) detallando el nuevo comportamiento de destinos en perfiles y la inicialización automática del marcador.
- [x] Actualizar [`README.md`](../../README.md).
- [x] Actualizar [`CHANGELOG.md`](../../CHANGELOG.md) bajo `[Unreleased]`.
- [x] Actualizar [`PROXIMOS_PASOS.md`](../../PROXIMOS_PASOS.md).
- [x] **Hito de Commit 6 (docs):**
  ```bash
  docs: documentar en manual y changelog el gestor de rutas y despliegue guiado de marcador
  ```
