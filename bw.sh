#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"
curl -fsSL "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o /tmp/bw.zip
unzip -q -o /tmp/bw.zip -d "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/bw"
rm -f /tmp/bw.zip

echo "Bitwarden CLI instalado correctamente en $HOME/.local/bin/bw"
echo "Para iniciar sesión ejecuta: bw login"
