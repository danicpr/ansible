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

# 4. Obtener contraseña si el vault está bloqueado y no hay sesión activa
BW_PASSWORD=""
if [[ "$BW_STATUS" == "unlocked" && -n "${BW_SESSION:-}" ]]; then
    log_ok "Sesión de Bitwarden ya activa en el entorno."
else
    log_info "El vault de Bitwarden está bloqueado."
    read -r -s -p "$(printf "${C_YELLOW}? Clave maestra de Bitwarden: ${C_RESET}")" BW_PASSWORD
    printf "\n"
    if [[ -z "$BW_PASSWORD" ]]; then
        log_error "No se proporcionó la clave maestra. Abortando."
        exit 1
    fi
fi

# 5. Comprobar e instalar Ansible si no existe
if ! command -v ansible-playbook >/dev/null 2>&1; then
    log_warn "Ansible no está instalado. Instalando con pacman..."
    sudo pacman -S --needed --noconfirm ansible
fi

log_info "Ejecutando roles de Secrets, Bitwarden y Chezmoi..."
printf "\n"

# 6. Ejecutar el playbook filtrando por tags de Bitwarden/secrets/chezmoi
exec ansible-playbook -K site.yml \
    -e "enable_bitwarden=true" \
    -e "bw_password=${BW_PASSWORD}" \
    --tags "bitwarden,secrets,chezmoi" \
    "$@"
