# Plan Técnico y Arquitectura: Gestor Robusto de Rutas e Inicialización de Almacenamiento

> **Módulo:** Core / Device Model / Profile Model / App Controller  
> **Rama GitFlow:** `dev/fix/path-manager-and-profile-storage-init`  
> **Tipo:** Corrección Crítica de Arquitectura y Seguridad  

---

## 1. Arquitectura de Resolución Canónica de Rutas

Para erradicar la duplicación de rutas y las anomalías de anidamiento, se establece un modelo jerárquico inequívoco:

```text
                                  ┌──────────────────────────────────────────────┐
                                  │      DESTINO ASIGNADO AL PERFIL (ENTRADA)     │
                                  └──────────────────────────────────────────────┘
                                                          │
                                ┌─────────────────────────┴─────────────────────────┐
                                ▼                                                   ▼
                ┌───────────────────────────────┐                   ┌───────────────────────────────┐
                │        RUTA ABSOLUTA          │                   │      SUBDIRECTORIO RELATIVO   │
                │ (/..., ~..., $HOME/..., @media)│                   │(ej: 'Equipo_Docente', 'Lab')  │
                └───────────────────────────────┘                   └───────────────────────────────┘
                                │                                                   │
                                ▼                                                   ▼
                ┌───────────────────────────────┐                   ┌───────────────────────────────┐
                │   OVERRIDE AUTÓNOMO COMPLETO  │                   │    CONCATENACIÓN CONTROLADA   │
                │  No se concatena a base_dest. │                   │    base_dest + '/' + sub      │
                │  Se preserva la barra inicial.│                   │    (Una única concatenación)  │
                └───────────────────────────────┘                   └───────────────────────────────┘
                                │                                                   │
                                └─────────────────────────┬─────────────────────────┘
                                                          ▼
                                        ┌───────────────────────────────────┐
                                        │    NORMALIZACIÓN CANÓNICA         │
                                        │   • Eliminar '//' y trailing '/'  │
                                        │   • realpath / resolución tilde   │
                                        └───────────────────────────────────┘
                                                          │
                                                          ▼
                                        ┌───────────────────────────────────┐
                                        │    DETECTOR ANTI-RECURSIÓN        │
                                        │  ¿Contiene repetición de prefijo? │
                                        └───────────────────────────────────┘
                                                │                    │
                                       (Sí)     ▼                    ▼     (No)
                                        ┌──────────────┐      ┌──────────────┐
                                        │ BLOQUEO (12) │      │ RUTA VÁLIDA  │
                                        └──────────────┘      └──────────────┘
```

---

## 2. Modificaciones por Componente

### 2.1 Modelo de Perfiles (`lib/models/profile_model.sh`)

1. **`profile_model_sanitize_target_subdir(raw_subdir)`:**
   - Detectar si la entrada comienza por `/`, `~`, `$HOME`, `${HOME}` o `@media/`.
   - **Si es absoluta:**
     - Expandir prefijos de usuario (`~` -> `$HOME`).
     - Normalizar múltiples barras internas (`sed -E 's#/{2,}#/#g'`).
     - Preservar estrictamente la barra inicial `/`.
     - Eliminar barra final trailing `/`.
     - Bloquear navegación con `..`.
   - **Si es relativa:**
     - Eliminar cualquier barra inicial redundante.
     - Bloquear navegación con `..`.
     - Eliminar barra final trailing.

2. **`profile_model_get_destination(profile_id, base_dest, profiles_dir)`:**
   - Obtener `p_sub` saneado del perfil.
   - **Si `p_sub` es absoluto (inicia con `/`):**
     - Retornar directamente `p_sub` (ignorar `base_dest`, ya que el perfil tiene su propio destino completo).
   - **Si `p_sub` es relativo o vacío:**
     - Si `p_sub` está definido: retornar `${resolved_base%/}/$p_sub`.
     - Si `p_sub` está vacío:
       - Si `profile_id == "default"`: retornar `${resolved_base%/}`.
       - Si perfil secundario: retornar `${resolved_base%/}/$profile_id`.

### 2.2 Modelo de Dispositivos y Almacenamiento (`lib/models/device_model.sh`)

1. **`device_model_normalize_path(path)`:**
   - Normaliza cualquier ruta de sistema de archivos eliminando barras consecutivas (`//` -> `/`), segmentos `.`, y barras finales redundantes.
2. **`device_model_detect_path_recursion(path)`:**
   - Analiza los componentes del path. Si detecta secuencias repetidas de directorios consecutivas (ej. `.../Backups/.../Backups` o duplicación de prefijos `/media/user/SSD/Backups/media/user/SSD/Backups`), retorna `1` (recursión detectada).
3. **`device_model_validate_storage`:**
   - Validar `backup_dir` con `device_model_normalize_path`.
   - Comprobar `device_model_detect_path_recursion`: si falla, abortar retornando `DEV_ERR_RECURSIVE_PATH` (`12`) y emitir error informativo por stderr.

### 2.3 Controlador (`lib/controllers/app_controller.sh`)

1. **`controller_handle_create_profile`:**
   - Mejorar el diálogo TUI clarificando:
     - Dejar vacío: Automático `<DESTINO_BASE>/<ID_PERFIL>`.
     - Subcarpeta relativa simple (ej. `Trabajo`).
     - Ruta absoluta independiente (ej. `/media/usuario/OTRO_DISCO/Backups`).
   - Tras crear el perfil con éxito:
     - Resolver la ruta efectiva del nuevo perfil mediante `profile_model_get_destination`.
     - Comprobar si `.backup_storage_marker` está presente en la ruta o en su jerarquía.
     - **Si falta el marcador:**
       - En TUI: Preguntar con `whiptail_view_yesno`:
         `"El destino para este perfil:\n\n$eff_dest\n\nno contiene el marcador de seguridad (.backup_storage_marker).\n\n¿Desea inicializar este almacenamiento ahora mismo creando la estructura necesaria?"`
       - Si acepta: invocar `controller_handle_deploy_marker "$eff_dest" "true"`.
       - En CLI: si se pasa `--init-storage` o `--yes`, desplegar marcador de inmediato; si no, advertir.

### 2.4 Modelo de Backup (`lib/models/backup_model.sh`)

1. **`backup_model_run` y `backup_model_run_all`:**
   - Previo a la llamada a `crypto_model_shred_files`:
     - Certificar que el archivo destino de la copia existe físicamente y tiene tamaño > 0.
     - Certificar que `backup_dir` no contiene duplicación de rutas.
     - Si falla, cancelar purga y retornar error defensivo sin tocar archivos de origen.

---

## 3. Plan de Pruebas Unitarias

Se actualizarán y ampliarán las suites de pruebas existentes y se creará `tests/test_path_manager.sh`:
1. **Test 1:** Normalización de rutas con barras múltiples (`//media///user//` -> `/media/user`).
2. **Test 2:** Saneamiento de ruta absoluta en perfil preserva la barra inicial.
3. **Test 3:** `profile_model_get_destination` con ruta absoluta retorna el destino autónomo sin concatenar al `base_dest`.
4. **Test 4:** `profile_model_get_destination` con subcarpeta relativa concatena una sola vez al `base_dest`.
5. **Test 5:** Detección y bloqueo ante ruta recursiva/duplicada (`DEV_ERR_RECURSIVE_PATH = 12`).
6. **Test 6:** `controller_handle_create_profile` despliega el marcador de seguridad automáticamente si el usuario lo confirma.
7. **Test 7:** Salvaguarda pre-shred bloquea la destrucción si el archivo de copia no existe o tiene tamaño 0.
