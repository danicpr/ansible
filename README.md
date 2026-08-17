# Bootstrap CachyOS / Arch Linux (Agnóstico de DE + Opción GNOME)

Este repositorio contiene la configuración automatizada para un entorno de desarrollo en CachyOS / Arch Linux. Es **agnóstico del entorno de escritorio (DE)** por defecto (compatible con Hyprland, Sway, KDE Plasma, XFCE, sesiones TTY/headless o GNOME), e incluye un módulo opcional para personalizaciones de GNOME (temas MacTahoe y extensiones).

1. Instala manualmente las herramientas iniciales:

   ```bash
   sudo pacman -S --needed ansible
   ```

   `bitwarden-cli` solo es necesario si quieres que el playbook genere `~/.secrets/api_keys.zsh` desde tu vault (las claves de DeepSeek/OpenRouter). Sin él, pulsa Enter en el prompt de Bitwarden y los secrets se omiten.

   El playbook también pregunta el nombre y correo para `~/.gitconfig`; pulsar Enter en ambos los omite y se deja el archivo sin sección `[user]`.

2. (Opcional, solo para secrets) Inicia sesión en Bitwarden:

   ```bash
   bw login
   ```

3. Copia este repositorio al equipo y entra en su raíz.

4. Comprueba que están disponibles las tareas Flatpak:

   ```bash
   ansible-doc community.general.flatpak
   ansible-doc community.general.flatpak_remote
   ```

   Si alguna no existe, instala la colección solo entonces:

   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

5. Ejecuta el bootstrap desde la raíz del repositorio:

   **Modo recomendado (mediante script lanzador):**
   ```bash
   # Modo agnóstico (CLI, Dev Tools, Fuentes, Apps, Dotfiles):
   ./bootstrap.sh

   # Modo completo con temas y extensiones de GNOME:
   ./bootstrap.sh --gnome
   ```

   **O directamente mediante Ansible Playbook:**
   ```bash
   # Modo agnóstico:
   ansible-playbook -K site.yml -e "enable_gnome=false"

   # Modo GNOME:
   ansible-playbook -K site.yml -e "enable_gnome=true"
   ```

No ejecutes `sudo ./bootstrap.sh` ni `sudo ansible-playbook`: `-K` permite que Ansible pida la contraseña para las tareas root sin cambiar el usuario de escritorio que gestiona `$HOME`.
## Prerrequisitos y extras

La imagen CachyOS + Zsh debe proporcionar `oh-my-zsh`, sus plugins de Zsh, `pkgfile` y `expac`; no se instalan aquí como sustituto de esa base. `starship` sí lo instala el role `packages` (está en `pacman_packages`). Los paquetes de CachyOS `paru`, `zen-browser-bin`, `onlyoffice-bin` y `vesktop` se mantienen en la estrategia actual del role y no se convierten a una estrategia Arch distinta.

Los siguientes aliases son conveniencias opcionales y pueden fallar si no instalas sus dependencias: `mirrors` necesita `reflector`; `sun` necesita `tailscale` y `sunshine`; `mvn-new` necesita Maven (`mvn`) y Java; `rip` necesita `expac`. `gh` y `fd` también son extras opcionales. `reflector`, `tailscale`, `sunshine`, Maven/Java, `gh` y `fd` no bloquean el bootstrap base. `rsync` sí se declara porque el hook de Zen lo usa para sincronizar únicamente su directorio `chrome/`.

Mantén Zen cerrado mientras se aplica la configuración para que el hook pueda actualizar el perfil sin que el navegador sobrescriba sus archivos.

## Chezmoi y secretos

El playbook instala chezmoi en `~/.local/bin`, pasa `BW_SESSION` sin imprimirlo y aplica el source de dotfiles como usuario de escritorio. El secreto `~/.secrets/api_keys.zsh` se genera desde Bitwarden con permisos privados; no lo copies al repositorio.

Los cambios locales de `/home/dev/.local/share/chezmoi` solo llegan a otro equipo si copias ese source repo o lo publicas posteriormente con una operación explícita. Este flujo no hace `git push`, y `chezmoi update` tampoco forma parte del bootstrap automático.

## Política de OMP

La configuración privada de OMP conserva deliberadamente `approvalMode: yolo` y Bash permitido. La configuración local asociada conserva `allow_unsandboxed: true`. Es una decisión de comodidad y una superficie de riesgo: permite comandos destructivos o fuera del sandbox si una instrucción los solicita. No se modifica como parte del formateo.
