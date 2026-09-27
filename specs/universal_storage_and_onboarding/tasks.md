# Lista Atómica de Tareas: Ruta Universal de Backup, Destino por Perfil y Onboarding

**Sub-Hito:** 12.3  
**Rama:** `dev/feature/backup-profiles`  
**Estado:** Propuesto para Aprobación  
**Fecha:** 2026-09-21  

---

## Tareas

### Fase 1: Especificación y Diseño (SDD)
- [x] Redactar `specs/universal_storage_and_onboarding/spec.md`.
- [x] Redactar `specs/universal_storage_and_onboarding/plan.md`.
- [x] Redactar `specs/universal_storage_and_onboarding/tasks.md`.
- [x] Aprobación humana de los documentos de especificación (Clean Slate sin retrocompatibilidad).

---

### Fase 2: Modelo de Dispositivo y Almacenamiento Universal (`device_model.sh`)
- [x] Implementar `device_model_resolve_destination` (resolución de `BACKUP_DESTINATION` con soporte local, externo y notación `@media`).
- [x] Implementar `device_model_detect_external_drives` (detección de soportes montados en `/media/$USER/*` y `/run/media/$USER/*`).
- [x] Implementar `device_model_update_config_destination` (actualización atómica de `BACKUP_DESTINATION` en `config.conf`).
- [x] Adaptar `device_model_validate_storage` para evaluar directamente `BACKUP_DESTINATION`.
- [x] Añadir pruebas unitarias en `tests/test_device_model.sh`.

---

### Fase 3: Perfil Default Físico y Convención de Destinos (`profile_model.sh`)
- [x] Crear físicamente `profiles/default/profile.conf`.
- [x] Implementar `profile_model_init_default` y auto-reparación en `profile_model_get`.
- [x] Implementar convención de destino por perfil: `<BACKUP_DESTINATION>/<id_perfil>` si `TARGET_SUBDIR` no está definido.
- [x] Añadir pruebas unitarias en `tests/test_profile_model.sh`.

---

### Fase 4: Asistente de Onboarding y Persistencia de Sesión (`app_controller.sh`)
- [x] Incorporar banderas en `config/config.conf`: `INITIAL_SETUP_DONE="false"`, `BACKUP_DESTINATION="~/Backups/KeepMyConfig"`, `REMEMBER_LAST_PROFILE="true"`.
- [x] Implementar `controller_handle_onboarding_wizard` en `app_controller.sh` (bienvenida, detección de discos, opción local, marcador y preferencia de perfil).
- [x] Integrar verificación de onboarding en `controller_run_tui`.
- [x] Integrar lógica de `REMEMBER_LAST_PROFILE` al arrancar la TUI.
- [x] Añadir flag CLI `--setup` para invocar el asistente.
- [x] Añadir pruebas de integración en `tests/test_controller.sh`.

---

### Fase 5: Actualización Mandatoria de Documentación (Regla 10 AGENT.md)
- [ ] Actualizar `README.md` documentando la directiva `BACKUP_DESTINATION`, el Onboarding Wizard y el flag `--setup`.
- [ ] Actualizar `MANUAL_USUARIO.md` con el flujo del Onboarding Wizard, capturas TUI y ejemplos de uso de `BACKUP_DESTINATION`.
- [ ] Actualizar `CHANGELOG.md` bajo `[Unreleased]`.
- [ ] Actualizar `PROXIMOS_PASOS.md`.

---

### Fase 6: Verificación y Calidad
- [ ] Ejecutar suite completa de pruebas unitarias (`for t in tests/test_*.sh; do bash "$t"; done`).
- [ ] Ejecutar escáner SAST obligatorio (`bash user_data/scripts/security_check/security_check.sh --all`).
- [ ] Solicitar aprobación humana y realizar el commit independiente del Sub-Hito 12.3:
  `feat!(storage): ruta universal de backup, destino por perfil y asistente de onboarding`.
