# Especificación Técnica (SDD): Ámbito de Módulos y Sanitización de Rutas (`scoped_modules_sanitization`)

**Sub-Hito:** 12.1  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## 1. Justificación y Objetivos

En las pruebas operativas del sistema de perfiles, se detectaron las siguientes necesidades funcionales:
1. Al crear un módulo desde el asistente TUI (Opción 7), el sistema no ofrece la opción de asignarlo exclusivamente al perfil activo, forzándolo siempre al catálogo global `modules.d/`.
2. Si un usuario define rutas con `$HOME/`, `~/` o `/home/usuario/` en `MODULE_PATHS`, el motor `tar` falla o produce rutas anidadas incorrectas porque la arquitectura espera rutas relativas respecto a `$TARGET_USER_HOME`.
3. Si un perfil configura `TARGET_SUBDIR` con una ruta absoluta (ej. `/home/...`), al concatenarse con el punto de montaje de una unidad de almacenamiento externa genera rutas inválidas que rompen la verificación del marcador de seguridad (`Safety Marker`).

### Objetivos:
- **FR-MOD-001 (Selector de Ámbito en TUI):** Permitir al usuario elegir en el asistente de creación si el módulo es **Global** (`modules.d/`) o **Exclusivo del perfil activo** (`profiles/<activo>/modules.d/`).
- **FR-MOD-002 (Sanitización de `MODULE_PATHS`):** Normalizar automáticamente cualquier ruta ingresada, convirtiendo prefijos absolutos o comodines `$HOME` en rutas relativas limpias.
- **FR-MOD-003 (Sanitización y Protección de `TARGET_SUBDIR`):** Eliminar slashes iniciales redundantes y advertir/bloquear el uso de rutas absolutas locales dentro de configuraciones de almacenamiento para dispositivos externos.

---

## 2. Requerimientos Funcionales Detallados

### FR-MOD-001: Selector de Ámbito en Asistente TUI
1. Cuando el usuario accede a *Opción 7: Administrar Módulos y Etiquetas -> Crear un nuevo módulo*:
   - El sistema detecta el perfil actualmente activo (`act_prof`).
   - **Si `act_prof == "default"`:** El módulo se guarda automáticamente en `modules.d/` (catálogo global).
   - **Si `act_prof != "default"`:** Se despliega un diálogo de menú interactivo:
     - `1) Catálogo Global (modules.d/)` *(Disponible para todos los perfiles)*.
     - `2) Exclusivo del Perfil '$act_prof'` *(Visible únicamente en este perfil)*.
2. Al listar módulos para inspeccionar o eliminar en el asistente TUI:
   - Se muestra visualmente el ámbito de cada módulo: `[Global]` o `[Perfil: <id>]`.

### FR-MOD-002: Sanitización Automática de Rutas
1. Al registrar rutas para una receta (vía TUI, CLI o directamente en `module_model_save`):
   - Cualquier elemento de la lista debe procesarse por `module_model_sanitize_path`:
     - Si coincide con `^(\$HOME|~|/home/[^/]+)/?(.*)$`, extraer la parte relativa `$2`.
     - Eliminar cualquier slash inicial redundante (`/`).
     - Si el resultado es una cadena vacía o '.', rechazar por ruta inválida.
2. La receta `.conf` resultante debe persistir la ruta estrictamente relativa (ej: `Documentos/Pruebas_Macros`).

### FR-MOD-003: Sanitización y Protección de `TARGET_SUBDIR`
1. En `profile_model_create` y en el asistente interactivo de perfiles:
   - Si se ingresa una subcarpeta con slashes iniciales (ej. `/Backups/Docente` o `//Backups/...`), sanitizarla a `Backups/Docente`.
   - Si el usuario introduce una ruta que contiene `$HOME` o `/home/`, advertir que los destinos de dispositivos deben ser relativos, o convertirla adecuadamente.

---

## 3. Criterios de Aceptación

- [ ] Un módulo creado bajo un perfil activo puede ser guardado en `profiles/<perfil>/modules.d/` y no aparece al cambiar a otro perfil distinto.
- [ ] Cualquier entrada como `$HOME/mis-datos` o `/home/usuario/mis-datos` se guarda en el `.conf` como `mis-datos`.
- [ ] Todas las pruebas unitarias existentes (249) continúan pasando al 100%.
- [ ] Se añaden al menos 10 nuevas aserciones en `test_module_model.sh` y `test_controller.sh` cubriendo sanitización y selector de ámbito.
