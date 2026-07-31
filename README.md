# Bootstrap CachyOS + GNOME

Este repositorio está preparado exclusivamente para una instalación base de CachyOS con GNOME y la configuración Zsh que proporciona CachyOS. No es un playbook para Arch genérico, otros escritorios ni sesiones headless.

## Flujo de instalación

1. Instala manualmente las herramientas iniciales:

   ```bash
   sudo pacman -S --needed bitwarden-cli ansible
   ```

2. Inicia sesión en Bitwarden:

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

5. Abre una sesión GNOME gráfica, cierra Zen Browser y ejecuta desde la raíz del repositorio:

   ```bash
   ansible-playbook -K site.yml
   ```

No ejecutes `sudo ansible-playbook`: `-K` permite que Ansible pida la contraseña para las tareas root sin cambiar el usuario de escritorio que gestiona `$HOME`. El playbook necesita una sesión GNOME iniciada para las extensiones, D-Bus y Flatpak.

## Prerrequisitos y extras

La imagen CachyOS + Zsh debe proporcionar `oh-my-zsh`, sus plugins de Zsh, `pkgfile`, `expac` y `starship`; no se instalan aquí como sustituto de esa base. Los paquetes de CachyOS `paru`, `zen-browser-bin`, `onlyoffice-bin` y `vesktop` se mantienen en la estrategia actual del role y no se convierten a una estrategia Arch distinta.

Los siguientes aliases son conveniencias opcionales y pueden fallar si no instalas sus dependencias: `mirrors` necesita `reflector`; `sun` necesita `tailscale` y `sunshine`; `mvn-new` necesita Maven (`mvn`) y Java; `rip` necesita `expac`. `gh` y `fd` también son extras opcionales. `reflector`, `tailscale`, `sunshine`, Maven/Java, `gh` y `fd` no bloquean el bootstrap base. `rsync` sí se declara porque el hook de Zen lo usa para sincronizar únicamente su directorio `chrome/`.

Mantén Zen cerrado mientras se aplica la configuración para que el hook pueda actualizar el perfil sin que el navegador sobrescriba sus archivos.

## Chezmoi y secretos

El playbook instala chezmoi en `~/.local/bin`, pasa `BW_SESSION` sin imprimirlo y aplica el source de dotfiles como usuario de escritorio. El secreto `~/.secrets/api_keys.zsh` se genera desde Bitwarden con permisos privados; no lo copies al repositorio.

Los cambios locales de `/home/dev/.local/share/chezmoi` solo llegan a otro equipo si copias ese source repo o lo publicas posteriormente con una operación explícita. Este flujo no hace `git push`, y `chezmoi update` tampoco forma parte del bootstrap automático.

## Política de OMP

La configuración privada de OMP conserva deliberadamente `approvalMode: yolo` y Bash permitido. La configuración local asociada conserva `allow_unsandboxed: true`. Es una decisión de comodidad y una superficie de riesgo: permite comandos destructivos o fuera del sandbox si una instrucción los solicita. No se modifica como parte del formateo.
