# Borrador de Especificación Técnica: Blindaje Criptográfico de Integridad y Protección de Código en Bash

> **Módulo:** Seguridad del Núcleo, Integridad Criptográfica y Hardening de Permisos  
> **Sub-Hito:** 12.6 (Planificado tras finalizar el Sub-Hito 12.5: Empaquetado y Distribución)  
> **Estado:** Documento de Trabajo / Borrador de Análisis y Recomendaciones  
> **Fecha de Creación:** 2026-09-27  

---

## 1. Contexto del Problema y Vectores de Amenaza

KeepMyConfig es una solución de respaldo y recuperación construida íntegramente en Bash bajo el patrón arquitectónico MVC. Al tratarse de un lenguaje interpretado, el código fuente reside en archivos de texto plano que son leídos directamente por el intérprete `/usr/bin/bash` en cada ejecución.

En la instalación estándar en el espacio del usuario (`~/.local/share/KeepMyConfig/lib/`):
- Los archivos pertenecen al propio usuario con permisos de lectura y escritura (`rw-r--r--` o `rwxr-xr-x`).
- **Amenaza 1 (Inyección Maliciosa Silenciosa):** Cualquier script o proceso ejecutado en el contexto de usuario (extensiones de navegador comprometidas, paquetes de dependencias de terceros en Python/Node, utilidades descargadas de internet) tiene permisos suficientes para editar archivos críticos como `lib/models/crypto_model.sh`, alterando llamadas criptográficas, capturando contraseñas GPG o adulterando la purga segura con `shred -u`.
- **Amenaza 2 (Modificación Accidental o Corrupción):** Un usuario o editor que modifique una función interna en `lib/` sin percatarse, rompiendo la lógica de respaldo o recuperación.

---

## 2. Comparativa Técnica Exhaustiva de Alternativas

| Alternativa | Mecanismo Técnico | Nivel de Blindaje | Filosofía Non-Root (Sin Sudo) | Ventajas | Inconvenientes / Limitaciones |
| :--- | :--- | :---: | :---: | :--- | :--- |
| **1. Sello Criptográfico SHA-256 (`.app_integrity`) al arranque** | En el empaquetado oficial se genera un manifiesto sellado con las sumas SHA-256 de todos los scripts inmutables (`backup_manager.sh`, `lib/**/*.sh`). Al arrancar, `backup_manager.sh` verifica en <0.05s la correspondencia exacta de cada archivo. | **Alto** (Detección en tiempo real) | **100% Nativo** (usa `sha256sum`) | • Detección instantánea de cualquier alteración de un solo byte.<br>• Extremadamente rápido.<br>• Transparente y auditable. | Si un atacante malicioso tiene permisos de escritura sobre toda la carpeta del usuario, podría alterar el script y recalcular el archivo `.app_integrity`. (Se mitiga combinándolo con la Alternativa 3). |
| **2. Sello SHA-256 + Firma Digital GPG (`.app_integrity.asc`)** | Igual que la Alternativa 1, pero el archivo `.app_integrity` va firmado criptográficamente con la clave privada GPG del mantenedor/release. | **Militar / Enterprise** (Infalsificable) | **100% Nativo** (usa `gpg`) | • Imposible de falsificar: ningún proceso local puede regenerar un `.app_integrity` válido sin la clave privada. | Requiere que el usuario disponga de la clave pública del mantenedor en su llavero de GPG. Puede suponer fricción de onboarding si la clave caduca o para usuarios no técnicos. |
| **3. Endurecimiento de Permisos UNIX (`chmod 0555` / `u-w`)** | Durante la instalación con `install.sh`, se retiran los permisos de escritura del propietario a todo el directorio `lib/` y binarios, dejando modificables exclusivamente las carpetas de datos del usuario (`config/`, `modules.d/`, `profiles/`). | **Medio / Preventivo** | **100% Nativo** (permisos POSIX) | • Bloquea escrituras directas accidentales.<br>• Impide que programas o scripts abran ficheros en modo *append* (`>>`). | Al ser el propietario el mismo usuario, un proceso hostil avanzado que se ejecute con sus credenciales podría ejecutar previamente `chmod u+w` si busca activamente atacar KeepMyConfig. |
| **4. Inmutabilidad del Filesystem (`chattr +i`)** | Flag del sistema de archivos Linux (ext4/btrfs) que impide modificar, borrar o renombrar el archivo, incluso para su propietario. | **Máximo** (Inmutable en kernel) | ❌ **Requiere `sudo`** | • Protección absoluta contra cualquier proceso del usuario. | Rompe terminantemente la filosofía de KeepMyConfig de instalación y ejecución sin privilegios de superusuario (`sudo`). |
| **5. Compilación a Binario ELF con `shc` (Shell Compiler)** | Traduce el script de Bash a lenguaje C y lo compila con `gcc` en un binario ejecutable nativo cerrado. | **Medio** (Ofuscación binaria) | ❌ **Dependencia Externa** | • El código fuente deja de ser texto plano legible o editable directamente con un editor. | • No está instalado por defecto en Lliurex / Ubuntu.<br>• Genera binarios dependientes de la arquitectura de la CPU (x86_64 vs arm64).<br>• Puede ser desempaquetado por analistas con volcados de memoria. |

---

## 3. Recomendación Arquitectónica: Defensa en Profundidad de 2 Barreras

Para garantizar la máxima seguridad sin romper la filosofía **non-root**, la solución técnica recomendada es la combinación de las **Alternativas 1 y 3**:

```text
                               ┌─────────────────────────────────────────────────────────────┐
                               │             DEFENSA EN PROFUNDIDAD (NON-ROOT)               │
                               └─────────────────────────────────────────────────────────────┘
                                                              │
                    ┌─────────────────────────────────────────┴─────────────────────────────────────────┐
                    ▼                                                                                   ▼
    ┌───────────────────────────────┐                                                   ┌───────────────────────────────┐
    │     BARRERA 1: PERMISOS       │                                                   │      BARRERA 2: SELLO SHA     │
    │   Hardening en install.sh     │                                                   │   Verificación en arranque    │
    ├───────────────────────────────┤                                                   ├───────────────────────────────┤
    │ • chmod -R 0555 en lib/       │                                                   │ • Lee .app_integrity.sha256   │
    │ • chmod 0555 backup_manager.sh│                                                   │ • Verifica sha256sum -c       │
    │ • Protege contra escritura y  │                                                   │ • Si hay discrepancia:        │
    │   inyección involuntaria.     │                                                   │   BLOQUEO INMEDIATO Y ALERTA  │
    └───────────────────────────────┘                                                   └───────────────────────────────┘
```

1. **Barrera 1 (Permisos de Solo Lectura):** Al instalar KeepMyConfig, `install.sh` aplica `chmod -R 0555` (o `chmod -R u-w`) a todo el árbol de código (`lib/`, `backup_manager.sh`). Las carpetas mutables (`config/`, `modules.d/`, `profiles/`) mantienen permisos `0755`/`0644`.
2. **Barrera 2 (Sello Criptográfico al Arranque):** Al empaquetar, `scripts/package.sh` genera el archivo oculto `.app_integrity.sha256`. Al arrancar, `backup_manager.sh` comprueba en milisegundos que ningún archivo de `lib/` ni el propio script principal hayan sido manipulados. Ante cualquier discrepancia, finaliza con código de error crítico y muestra una alerta roja en consola/TUI.
3. **Elusión Controlada para Desarrollo:** Soporte de variable de entorno `KEEP_MY_CONFIG_DEV=true` y modo sandbox para que el desarrollador pueda trabajar en código fuente sin falsos positivos.

---

## 4. Decisiones Pendientes a Tomar al Iniciar el Sub-Hito 12.6

Cuando concluyamos el Sub-Hito 12.5 (Empaquetado) y activemos la rama `dev/feature/codebase-integrity`, se someterán a validación:
1. **Adopción de la Defensa en 2 Barreras:** Confirmar la combinación de `chmod 0555` + `.app_integrity.sha256`.
2. **Soporte Opcional de Firma GPG:** Decidir si se añade soporte optativo para verificar un `.app_integrity.sha256.asc` firmado con la clave del autor si el entorno dispone de la clave pública.
3. **Comportamiento en la Edición Portable:** Definir si la versión portable verifica el sello de integridad de igual forma o si permite auto-reparación.
4. **Diseño de Alertas de Seguridad:** Formato visual de la advertencia crítica ante detección de inyecciones maliciosas.
