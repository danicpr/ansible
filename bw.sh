#!/usr/bin/env bash
set -euo pipefail

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

log_info() {
    printf "${C_CYAN}${C_BOLD}[INFO]${C_RESET} %s\n" "$1"
}

log_ok() {
    printf "${C_GREEN}${C_BOLD}[OK]${C_RESET} %s\n" "$1"
}

log_warn() {
    printf "${C_YELLOW}${C_BOLD}[AVISO]${C_RESET} %s\n" "$1"
}

log_error() {
    printf "${C_RED}${C_BOLD}[ERROR]${C_RESET} %s\n" "$1" >&2
}

# 1. Comprobar que no se ejecute como root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log_error "No ejecutes este script directamente con sudo o como root."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.cargo/bin:$PATH"

if [[ -x "$HOME/.cargo/bin/fnm" ]]; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

printf "\n${C_CYAN}${C_BOLD}=== Sincronización de Secrets / Bitwarden ===${C_RESET}\n\n"

# 2. Comprobar instalación de Bitwarden CLI
if ! command -v bw >/dev/null 2>&1; then
    log_error "Bitwarden CLI ('bw') no está instalado o no se encuentra en el PATH."
    log_info "Ejecuta primero: ./install_bw.sh"
    exit 1
fi

# 3. Comprobar autenticación en Bitwarden
BW_STATUS_RAW="$(bw status 2>/dev/null || echo '{}')"
BW_STATUS="$(python3 -c "import json, sys; print(json.loads('''$BW_STATUS_RAW''').get('status', 'unauthenticated'))" 2>/dev/null || echo "unauthenticated")"

if [[ "$BW_STATUS" == "unauthenticated" ]]; then
    log_error "No has iniciado sesión en Bitwarden."
    log_info "Ejecuta primero: bw login"
    exit 1
fi

# 4. Desbloquear vault de forma interactiva si es necesario
BW_SESSION="${BW_SESSION:-}"

if [[ "$BW_STATUS" == "unlocked" && -n "$BW_SESSION" ]]; then
    log_ok "Sesión de Bitwarden ya activa en el entorno."
else
    log_info "El vault de Bitwarden está bloqueado."
    read -r -s -p "$(printf "${C_YELLOW}? Clave maestra de Bitwarden: ${C_RESET}")" BW_PASSWORD
    printf "\n"
    if [[ -z "$BW_PASSWORD" ]]; then
        log_error "No se proporcionó la clave maestra. Abortando."
        exit 1
    fi
    log_info "Desbloqueando vault de Bitwarden..."
    BW_SESSION="$(BW_PASSWORD="$BW_PASSWORD" bw unlock --passwordenv BW_PASSWORD --raw)"
    export BW_SESSION
fi

# 5. Sincronizar vault (no fatal si hay fallo de red o FetchError)
log_info "Sincronizando vault con Bitwarden..."
if bw sync --session "$BW_SESSION" >/dev/null 2>&1; then
    log_ok "Vault sincronizado correctamente."
else
    log_warn "No se pudo sincronizar en línea (FetchError / red). Se utilizará el vault local descifrado."
fi

# 6. Extraer y escribir la clave SSH github-vibe directamente
log_info "Extrayendo clave SSH github-vibe desde Bitwarden..."
python3 - << 'PYEOF'
import json, subprocess, sys, os
from pathlib import Path

session = os.environ.get("BW_SESSION", "")
home = Path.home()
ssh_dir = home / ".ssh"
ssh_dir.mkdir(mode=0o700, exist_ok=True)

try:
    res = subprocess.run(
        ["bw", "list", "items", "--search", "vibe", "--session", session],
        capture_output=True, text=True, check=False
    )
    items = []
    if res.returncode == 0 and res.stdout.strip():
        try:
            items = json.loads(res.stdout)
        except Exception:
            items = []
    
    if not items:
        res2 = subprocess.run(
            ["bw", "list", "items", "--session", session],
            capture_output=True, text=True, check=False
        )
        if res2.returncode == 0 and res2.stdout.strip():
            try:
                all_items = json.loads(res2.stdout)
                items = [i for i in all_items if i.get("type") == 5 or "vibe" in i.get("name", "").lower()]
            except Exception:
                items = []

    priv_key, pub_key, found_name = "", "", ""
    for it in items:
        if isinstance(it, dict):
            ssh_info = it.get("sshKey")
            if isinstance(ssh_info, dict):
                priv_key = ssh_info.get("privateKey", "")
                pub_key = ssh_info.get("publicKey", "")
            if not priv_key and it.get("notes") and "PRIVATE KEY" in it["notes"]:
                priv_key = it["notes"]
            if not priv_key and isinstance(it.get("login"), dict) and "PRIVATE KEY" in it["login"].get("password", ""):
                priv_key = it["login"]["password"]
            if not priv_key:
                for f in it.get("fields", []):
                    if isinstance(f, dict) and "PRIVATE KEY" in f.get("value", ""):
                        priv_key = f["value"]
                        break
            if priv_key:
                found_name = it.get("name", "github-vibe")
                break

    if priv_key:
        priv_path = ssh_dir / "id_github_vibe"
        priv_path.write_text(priv_key.strip() + "\n")
        priv_path.chmod(0o600)
        print(f"\033[0;32m\033[1m[OK]\033[0m Clave SSH privada extraída del item '{found_name}' -> ~/.ssh/id_github_vibe")
        if pub_key:
            pub_path = ssh_dir / "id_github_vibe.pub"
            pub_path.write_text(pub_key.strip() + "\n")
            pub_path.chmod(0o644)
            print(f"\033[0;32m\033[1m[OK]\033[0m Clave SSH pública guardada -> ~/.ssh/id_github_vibe.pub")
    else:
        print("\033[0;33m\033[1m[AVISO]\033[0m No se encontró ningún item de SSH Key con 'vibe' en Bitwarden.", file=sys.stderr)
except Exception as e:
    print(f"\033[0;31m\033[1m[ERROR]\033[0m Error extrayendo clave SSH desde Bitwarden: {e}", file=sys.stderr)
PYEOF

# 7. Comprobar e instalar Ansible si no existe
if ! command -v ansible-playbook >/dev/null 2>&1; then
    log_warn "Ansible no está instalado. Instalando con pacman..."
    sudo pacman -S --needed --noconfirm ansible
fi

log_info "Ejecutando roles de Secrets, Bitwarden y Chezmoi con Ansible..."
printf "\n"

# 8. Ejecutar el playbook filtrando por tags de Bitwarden/secrets/chezmoi
exec ansible-playbook -K site.yml \
    -e "enable_bitwarden=true" \
    -e "bw_session=${BW_SESSION}" \
    --tags "bitwarden,secrets,chezmoi" \
    "$@"
