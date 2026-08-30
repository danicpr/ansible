# Bootstrap CachyOS / Arch Linux (Agnóstico de DE + Opción GNOME)

Este repositorio contiene la configuración automatizada para un entorno de desarrollo en CachyOS / Arch Linux. Es **agnóstico del entorno de escritorio (DE)** por defecto (compatible con Hyprland, Sway, KDE Plasma, XFCE, sesiones TTY/headless o GNOME), e incluye un módulo opcional para personalizaciones de GNOME (temas MacTahoe y extensiones).

---

## 1. Bootstrap del Sistema

El bootstrap instala paquetes del sistema, herramientas de desarrollo (Rust, FNM/Node, PNPM, SDKMAN/Java, Silicon, OMP), fuentes, temas y dotfiles (Chezmoi) de forma completamente limpia y sin bloqueos interactivos.

```bash
# Modo agnóstico (CLI, Dev Tools, Fuentes, Apps, Dotfiles):
./bootstrap.sh

# O modo completo con temas y extensiones de GNOME:
./bootstrap.sh --gnome
```

*(No ejecutes `sudo ./bootstrap.sh`: el script gestiona las elevaciones de permisos automáticamente).*

---

## 2. Inyección de Secretos y Bitwarden (Paso posterior)

Una vez que el bootstrap instala Node/FNM y las herramientas base, puedes sincronizar tus secretos (API keys y clave SSH `github_vibe`):

1. **Instalar Bitwarden CLI:**
   ```bash
   ./install_bw.sh
   ```
2. **Iniciar sesión en Bitwarden:**
   ```bash
   bw login
   ```
3. **Sincronizar secretos y dotfiles con Ansible:**
   ```bash
   ./bw.sh
   ```

Este script ejecuta únicamente las tareas de Bitwarden y Chezmoi para inyectar `~/.secrets/api_keys.zsh` y la clave SSH `~/.ssh/id_github_vibe`.

---

## Prerrequisitos y extras

La imagen CachyOS + Zsh debe proporcionar `oh-my-zsh`, sus plugins de Zsh, `pkgfile` y `expac`; no se instalan aquí como sustituto de esa base. `starship` sí lo instala el role `packages` (está en `pacman_packages`). Los paquetes de CachyOS `paru`, `zen-browser-bin`, `onlyoffice-bin` y `vesktop` se mantienen en la estrategia actual del role y no se convierten a una estrategia Arch distinta.

Los siguientes aliases son conveniencias opcionales y pueden fallar si no instalas sus dependencias: `mirrors` necesita `reflector`; `sun` necesita `tailscale` y `sunshine`; `mvn-new` necesita Maven (`mvn`) y Java; `rip` necesita `expac`. `gh` y `fd` también son extras opcionales. `reflector`, `tailscale`, `sunshine`, Maven/Java, `gh` y `fd` no bloquean el bootstrap base. `rsync` sí se declara porque el hook de Zen lo usa para sincronizar únicamente su directorio `chrome/`.

Mantén Zen cerrado mientras se aplica la configuración para que el hook pueda actualizar el perfil sin que el navegador sobrescriba sus archivos.

---

## Chezmoi y cuentas de Git / SSH

El playbook instala chezmoi en `~/.local/bin` y aplica el source de dotfiles como usuario de escritorio.

- Si el usuario es **Daniel Borre**:
  - Se integra la clave SSH `github_vibe` desde Bitwarden en `~/.ssh/id_github_vibe`.
  - Se configura el host `github-vibe` en `~/.ssh/config`.
  - Se aplica `includeIf` en `.gitconfig` para `~/vibe/`, `~/ansible` y `~/.local/share/chezmoi` con la cuenta secundaria de GitHub (`danisecundarioxd@gmail.com`).
- Para cualquier otro usuario, se mantiene la configuración global estándar.

---

## Política de OMP

La configuración privada de OMP conserva deliberadamente `approvalMode: yolo` y Bash permitido. La configuración local asociada conserva `allow_unsandboxed: true`. Es una decisión de comodidad y una superficie de riesgo: permite comandos destructivos o fuera del sandbox si una instrucción los solicita. No se modifica como parte del formateo.
