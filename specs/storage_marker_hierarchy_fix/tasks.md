# Tareas de Ejecución: Validación Jerárquica de Marcador y Sanitización de Destinos (`storage_marker_hierarchy_fix`)

**Rama:** `dev/feature/backup-profiles`  
**Tipo:** Tareas Atómicas de Fix  
**Fecha:** 2026-09-21  

---

## Tareas

### Fase 1: Implementación de Lógica en `device_model.sh`
- [x] Implementar `device_model_sanitize_subdir` en `lib/models/device_model.sh`.
- [x] Actualizar `device_model_validate_storage` con sanitización de subdirectorio y validación jerárquica con auto-creación de `backup_dir`.
- [x] Actualizar `device_model_update_config_subdir` para sanitizar el valor antes de escribir en `config.conf`.

### Fase 2: Actualización de Controlador en `app_controller.sh`
- [x] Sanitizar argumentos en `controller_handle_init_target`.

### Fase 3: Pruebas Unitarias
- [x] Añadir pruebas de sanitización y jerarquía en `tests/test_device_model.sh`.
- [x] Ejecutar suite completa de pruebas unitarias (`for t in tests/test_*.sh; do bash "$t"; done`).

### Fase 4: Restauración de Datos de Prueba del Usuario y Verificación en Vivo
- [x] Restaurar `modules.d/PruebaNotas.conf`, `profiles/PerfilPruebas/` y `config/config.conf` desde `user_data/scratch/user_test_backup/`.
- [x] Limpiar la carpeta física literal `'$HOME'` del SSD si existe.
- [x] Ejecutar `./backup_manager.sh --backup-all` bajo `PerfilPruebas` y verificar que auto-cree el destino y respalde los módulos con éxito.

### Fase 5: SAST y Commit
- [ ] Ejecutar escáner SAST obligatorio (`bash user_data/scripts/security_check/security_check.sh --all`).
- [ ] Confirmar y ejecutar commit de fix: `fix(storage): validar marcador en soporte base y auto-crear carpetas de perfil`.
