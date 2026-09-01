#!/usr/bin/env bash
set -euo pipefail

# Colores para la salida
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'

log_info() { printf "${C_CYAN}${C_BOLD}[INFO]${C_RESET} %s\n" "$1"; }
log_ok()   { printf "${C_GREEN}${C_BOLD}[OK]${C_RESET} %s\n" "$1"; }
log_warn() { printf "${C_YELLOW}${C_BOLD}[AVISO]${C_RESET} %s\n" "$1"; }
log_error(){ printf "${C_RED}${C_BOLD}[ERROR]${C_RESET} %s\n" "$1" >&2; }

printf "\n${C_CYAN}${C_BOLD}=== Configuración de Sincronización de Sesiones OMP con Rclone ===${C_RESET}\n\n"

# 1. Comprobar que no se ejecute como root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log_error "No ejecutes este script como root. Debe ejecutarse como tu usuario normal."
    exit 1
fi

# 2. Asegurar que rclone esté instalado
if ! command -v rclone >/dev/null 2>&1; then
    log_warn "rclone no está instalado. Instalándolo con pacman..."
    sudo pacman -S --needed --noconfirm rclone
    log_ok "rclone instalado correctamente."
fi

# 3. Comprobar si el remote 'gdrive' ya existe
if ! rclone listremotes 2>/dev/null | grep -q '^gdrive:'; then
    log_info "No se encontró el remote 'gdrive' en rclone."
    log_info "Iniciando configuración interactiva de Google Drive..."
    printf "\n${C_YELLOW}Instrucciones para el asistente:${C_RESET}\n"
    printf "  1. Selecciona 'n' (New remote)\n"
    printf "  2. Nombre: 'gdrive'\n"
    printf "  3. Tipo de almacenamiento: 'drive' (Google Drive)\n"
    printf "  4. Deja 'client_id' y 'client_secret' en blanco (Enter)\n"
    printf "  5. Scope: 1 (Full access)\n"
    printf "  6. Sigue las instrucciones del navegador para autorizar tu cuenta.\n\n"
    read -rp "Presiona Enter para iniciar 'rclone config'..." _
    rclone config
fi

if ! rclone listremotes 2>/dev/null | grep -q '^gdrive:'; then
    log_error "No se configuró el remote 'gdrive'. Abortando activación de servicio."
    exit 1
fi
log_ok "Remote 'gdrive' detectado y listo."

# 4. Asegurar archivos unitarios de systemd de usuario
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

cat << 'EOF' > "$SYSTEMD_USER_DIR/omp-sync.service"
[Unit]
Description=Sincronizar sesiones de OMP a Google Drive (rclone)
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStartPre=/usr/bin/mkdir -p %h/.omp/agent/sessions
ExecStart=/usr/bin/rclone sync %h/.omp/agent/sessions gdrive:omp-backup/sessions --fast-list --transfers 4 --quiet
ExecStop=/usr/bin/rclone sync %h/.omp/agent/sessions gdrive:omp-backup/sessions --fast-list --transfers 4 --quiet
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF

cat << 'EOF' > "$SYSTEMD_USER_DIR/omp-sync.timer"
[Unit]
Description=Ejecutar sincronización de sesiones de OMP cada 30 minutos

[Timer]
OnCalendar=*:0/30
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 5. Habilitar e iniciar servicio y timer
systemctl --user daemon-reload
systemctl --user enable --now omp-sync.service omp-sync.timer

log_ok "Servicio y timer activados con éxito."
log_info "Tus sesiones de OMP se sincronizarán cada 30 minutos y automáticamente al cerrar sesión / apagar el PC."

# 6. Sincronización inicial si existe la carpeta
if [[ -d "$HOME/.omp/agent/sessions" ]]; then
    log_info "Ejecutando primera sincronización de prueba..."
    systemctl --user start omp-sync.service
    log_ok "Sincronización inicial completada."
fi
