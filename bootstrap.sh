#!/usr/bin/env bash
set -euo pipefail

# Colores para la salida
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_RED='\033[0;31m'
C_DIM='\033[2m'

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

show_help() {
    printf "%bUso:%b ./bootstrap.sh [OPCIONES] [-- ANSIBLE_ARGS...]\n\n" "${C_BOLD}" "${C_RESET}"
    printf "Script lanzador agnóstico de configuración de sistema para CachyOS / Arch Linux.\n\n"
    printf "%bOpciones:%b\n" "${C_BOLD}" "${C_RESET}"
    printf "  %b--gnome%b              Instala paquetes base + temas MacTahoe y extensiones GNOME.\n" "${C_CYAN}" "${C_RESET}"
    printf "  %b--no-gnome, --agnostic%b Modo 100%% agnóstico (CLI, Dev, Fonts, Apps, Dotfiles). Omite temas/extensiones GNOME.\n" "${C_CYAN}" "${C_RESET}"
    printf "  %b--intel%b              Instala drivers y aceleración para GPU Intel (Arc / iGPU: OpenCL/Vulkan/VA-API).\n" "${C_CYAN}" "${C_RESET}"
    printf "  %b--no-intel%b           Omite la instalación de drivers para GPU Intel.\n" "${C_CYAN}" "${C_RESET}"
    printf "  %b--bitwarden%b          Habilita la integración y desbloqueo de Bitwarden (omitido por defecto en bootstrap).\n" "${C_CYAN}" "${C_RESET}"
    printf "  %b--no-bitwarden%b       Deshabilita explícitamente Bitwarden.\n" "${C_CYAN}" "${C_RESET}"
    printf "  %b-h, --help%b            Muestra esta ayuda y sale.\n\n" "${C_CYAN}" "${C_RESET}"
    printf "  Cualquier otro argumento no reconocido se pasará directamente a %bansible-playbook%b.\n" "${C_BOLD}" "${C_RESET}"
    printf "  Ejemplo: ./bootstrap.sh --gnome --tags \"packages,dev\" -vv\n\n"
}

# 1. Comprobar que no se ejecute como root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log_error "No ejecutes este script directamente con sudo o como root."
    log_error "El playbook pedirá sudo de forma controlada cuando sea necesario."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.local/bin:$PATH"


ENABLE_GNOME=""
ENABLE_INTEL=""
ENABLE_BITWARDEN="false"
ANSIBLE_EXTRA_ARGS=()

# 2. Parsear argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gnome)
            ENABLE_GNOME="true"
            shift
            ;;
        --no-gnome|--agnostic)
            ENABLE_GNOME="false"
            shift
            ;;
        --intel|--intel-gpu)
            ENABLE_INTEL="true"
            shift
            ;;
        --no-intel)
            ENABLE_INTEL="false"
            shift
            ;;
        --bitwarden)
            ENABLE_BITWARDEN="true"
            shift
            ;;
        --no-bitwarden)
            ENABLE_BITWARDEN="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                ANSIBLE_EXTRA_ARGS+=("$1")
                shift
            done
            break
            ;;
        *)
            ANSIBLE_EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

printf "\n${C_CYAN}${C_BOLD}=== Bootstrap de Sistema (CachyOS / Arch) ===${C_RESET}\n\n"

# 3. Determinar si se debe activar GNOME si no se especificó flag
if [[ -z "$ENABLE_GNOME" ]]; then
    CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-}"
    if [[ -t 0 ]]; then
        if [[ "$CURRENT_DESKTOP" =~ [Gg][Nn][Oo][Mm][Ee] ]]; then
            log_info "Se detectó entorno de escritorio GNOME ($CURRENT_DESKTOP)."
            read -rp "$(printf "${C_YELLOW}? ¿Deseas aplicar temas MacTahoe y extensiones de GNOME? [S/n]: ${C_RESET}")" answer
            answer="${answer:-s}"
            if [[ "$answer" =~ ^[sSyY]$ ]]; then
                ENABLE_GNOME="true"
            else
                ENABLE_GNOME="false"
            fi
        else
            log_info "Entorno actual: ${CURRENT_DESKTOP:-No detectado / TTY} (Modo agnóstico por defecto)."
            read -rp "$(printf "${C_YELLOW}? ¿Deseas instalar temas y extensiones específicas de GNOME? [s/N]: ${C_RESET}")" answer
            answer="${answer:-n}"
            if [[ "$answer" =~ ^[sSyY]$ ]]; then
                ENABLE_GNOME="true"
            else
                ENABLE_GNOME="false"
            fi
        fi
    else
        log_info "Sesión no interactiva detectada: usando modo agnóstico (sin GNOME)."
        ENABLE_GNOME="false"
    fi
fi

if [[ "$ENABLE_GNOME" == "true" ]]; then
    log_ok "Modo seleccionado: ${C_BOLD}Completo con GNOME${C_RESET} (Temas MacTahoe, extensiones, utilidades GNOME)"
else
    log_ok "Modo seleccionado: ${C_BOLD}Agnóstico de DE${C_RESET} (Base, CLI, Dev Tools, Fuentes, Apps, Dotfiles)"
fi

# 4. Determinar si se deben instalar drivers de Intel GPU si no se especificó flag
if [[ -z "$ENABLE_INTEL" ]]; then
    if lspci 2>/dev/null | grep -iE "VGA|3D|Display" | grep -qi "Intel"; then
        if [[ -t 0 ]]; then
            log_info "Se detectó GPU Intel en el sistema."
            read -rp "$(printf "${C_YELLOW}? ¿Deseas instalar drivers y aceleración para Intel GPU (Arc/iGPU)? [S/n]: ${C_RESET}")" answer
            answer="${answer:-s}"
            if [[ "$answer" =~ ^[sSyY]$ ]]; then
                ENABLE_INTEL="true"
            else
                ENABLE_INTEL="false"
            fi
        else
            ENABLE_INTEL="true"
        fi
    else
        ENABLE_INTEL="false"
    fi
fi

if [[ "$ENABLE_INTEL" == "true" ]]; then
    log_ok "Drivers Intel: ${C_BOLD}Activados${C_RESET} (Vulkan, VA-API, OpenCL/Level Zero para Arc/iGPU)"
fi
printf "\n"

# 5. Comprobar e instalar Ansible si no existe
if ! command -v ansible-playbook >/dev/null 2>&1; then
    log_warn "Ansible no está instalado. Instalando con pacman..."
    sudo pacman -S --needed --noconfirm ansible
    log_ok "Ansible instalado correctamente."
fi

# 6. Comprobar colección community.general
log_info "Verificando dependencias de colecciones de Ansible..."
if ! ansible-galaxy collection list community.general &>/dev/null; then
    log_info "Instalando requisitos de Ansible Galaxy desde requirements.yml..."
    ansible-galaxy collection install -r requirements.yml
    log_ok "Colecciones instaladas."
else
    log_ok "Colección community.general ya disponible."
fi

printf "\n${C_CYAN}${C_BOLD}--- Iniciando ejecución de Ansible Playbook ---${C_RESET}\n\n"

# 7. Ejecutar Ansible Playbook
exec ansible-playbook -K site.yml \
    -e "enable_gnome=${ENABLE_GNOME}" \
    -e "enable_intel=${ENABLE_INTEL}" \
    -e "enable_bitwarden=${ENABLE_BITWARDEN}" \
    "${ANSIBLE_EXTRA_ARGS[@]+"${ANSIBLE_EXTRA_ARGS[@]}"}"
