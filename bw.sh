#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"

# 1. Si fnm está disponible, usar el npm gestionado por fnm
if command -v fnm >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/fnm" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
    eval "$(fnm env --use-on-cd --shell bash)"
    echo "Instalando @bitwarden/cli vía npm (fnm)..."
    npm install -g @bitwarden/cli

# 2. Si bun está disponible, instalar vía bun
elif command -v bun >/dev/null 2>&1; then
    echo "Instalando @bitwarden/cli vía bun..."
    bun install -g @bitwarden/cli
    mkdir -p "$HOME/.bun/bin"
    ln -sf "$HOME/.bun/bin/bw" "$HOME/.local/bin/bw"

# 3. Si es un sistema recién instalado sin fnm ni bun:
else
    if command -v pacman >/dev/null 2>&1; then
        echo "Instalando bun con pacman..."
        sudo pacman -S --needed --noconfirm bun
        echo "Instalando @bitwarden/cli vía bun..."
        bun install -g @bitwarden/cli
        mkdir -p "$HOME/.bun/bin"
        ln -sf "$HOME/.bun/bin/bw" "$HOME/.local/bin/bw"
    else
        echo "Error: No se encontró fnm ni bun para instalar Bitwarden CLI." >&2
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

echo ""
echo "Bitwarden CLI instalado correctamente ($("$HOME/.local/bin/bw" --version))"
echo "Para iniciar sesión ejecuta: bw login"
