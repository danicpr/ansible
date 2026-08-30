#!/usr/bin/env bash
set -euo pipefail

C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

mkdir -p "$HOME/.local/bin"

# 1. Si fnm está disponible, usar el npm gestionado por fnm
if command -v fnm >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/fnm" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
    eval "$(fnm env --use-on-cd --shell bash)"
    printf "${C_CYAN}${C_BOLD}[INFO]${C_RESET} Instalando @bitwarden/cli vía npm (fnm)...\n"
    npm install -g @bitwarden/cli

# 2. Si bun está disponible, instalar vía bun
elif command -v bun >/dev/null 2>&1; then
    printf "${C_CYAN}${C_BOLD}[INFO]${C_RESET} Instalando @bitwarden/cli vía bun...\n"
    bun install -g @bitwarden/cli
    mkdir -p "$HOME/.bun/bin"
    ln -sf "$HOME/.bun/bin/bw" "$HOME/.local/bin/bw"

# 3. Si es un sistema recién instalado sin fnm ni bun:
else
    if command -v pacman >/dev/null 2>&1; then
        printf "${C_YELLOW}${C_BOLD}[AVISO]${C_RESET} Instalando bun con pacman...\n"
        sudo pacman -S --needed --noconfirm bun
        printf "${C_CYAN}${C_BOLD}[INFO]${C_RESET} Instalando @bitwarden/cli vía bun...\n"
        bun install -g @bitwarden/cli
        mkdir -p "$HOME/.bun/bin"
        ln -sf "$HOME/.bun/bin/bw" "$HOME/.local/bin/bw"
    else
        printf "${C_RED}${C_BOLD}[ERROR]${C_RESET} No se encontró fnm ni bun para instalar Bitwarden CLI.\n" >&2
        exit 1
    fi
fi

# Asegurar enlace simbólico en ~/.local/bin/bw si está en otra ruta
if command -v bw >/dev/null 2>&1; then
    BW_BIN="$(command -v bw)"
    if [[ "$BW_BIN" != "$HOME/.local/bin/bw" ]]; then
        ln -sf "$BW_BIN" "$HOME/.local/bin/bw"
    fi
fi

printf "\n${C_GREEN}${C_BOLD}[OK] Bitwarden CLI instalado correctamente (%s)${C_RESET}\n\n" "$("$HOME/.local/bin/bw" --version)"
printf "Pasos siguientes:\n"
printf "  1. Inicia sesión:            ${C_CYAN}bw login${C_RESET}\n"
printf "  2. Inyecta secrets en Ansible: ${C_CYAN}./bw.sh${C_RESET}\n"
