#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cli/backend-scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

ea11_backend_ensure_dirs

# ============================================================================
# OS DETECTION AND VALIDATION
# ============================================================================

host_detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        ea11_backend_die "Erro: /etc/os-release não encontrado. Não é um sistema Debian/Ubuntu?"
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    case "$ID" in
        debian)
            # Debian >= 11 (bullseye)
            if [[ ${VERSION_ID:-0} -lt 11 ]]; then
                ea11_backend_die "Erro: Debian 11+ é requerido. Versão detectada: ${VERSION_ID}"
            fi
            printf 'debian\n'
            ;;
        ubuntu)
            # Ubuntu >= 20.04 (focal)
            if [[ ${VERSION_ID:-0} < '20.04' ]]; then
                ea11_backend_die "Erro: Ubuntu 20.04+ é requerido. Versão detectada: ${VERSION_ID}"
            fi
            printf 'ubuntu\n'
            ;;
        *)
            ea11_backend_die "Erro: Distribuição não suportada: $ID. Apenas Debian 11+ e Ubuntu 20.04+ são suportados."
            ;;
    esac
}

host_check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        ea11_backend_info "Permissão de sudo é necessária para instalar pacotes."
        if ! sudo -v; then
            ea11_backend_die "Erro: Falha ao obter permissão de sudo."
        fi
    fi
}

# ============================================================================
# PACKAGE DETECTION AND MANAGEMENT
# ============================================================================

host_is_package_installed() {
    local pkg="$1"
    dpkg -l | grep -q "^ii  ${pkg}" || return 1
}

host_get_package_version() {
    local pkg="$1"
    if host_is_package_installed "$pkg"; then
        dpkg -l | grep "^ii  ${pkg}" | awk '{print $3}' | head -1
    else
        printf 'not-installed\n'
    fi
}

host_check_required_packages() {
    local -a missing=()
    local -a exists=()
    local -a incompatible=()

    ea11_backend_info "Verificando pacotes necessários..."

    # emacs: required
    if host_is_package_installed 'emacs'; then
        exists+=('emacs')
    else
        missing+=('emacs')
    fi

    # espeakup: required
    if host_is_package_installed 'espeakup'; then
        exists+=('espeakup')
    else
        missing+=('espeakup')
    fi

    # espeak-ng: required
    if host_is_package_installed 'espeak-ng'; then
        exists+=('espeak-ng')
    else
        missing+=('espeak-ng')
    fi

    # sudo: required
    if host_is_package_installed 'sudo'; then
        exists+=('sudo')
    else
        missing+=('sudo')
    fi

    # git: optional but recommended
    if host_is_package_installed 'git'; then
        exists+=('git')
    fi

    # Report status
    if [[ ${#exists[@]} -gt 0 ]]; then
        ea11_backend_info "Pacotes já instalados: ${exists[*]}"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        ea11_backend_info "Pacotes a instalar: ${missing[*]}"
    fi

    if [[ ${#incompatible[@]} -gt 0 ]]; then
        ea11_backend_warn "Pacotes com versão potencialmente incompatível: ${incompatible[*]}"
    fi

    # Decide action
    if [[ ${#missing[@]} -eq 0 ]]; then
        ea11_backend_info "Todos os pacotes necessários já estão instalados."
        return 0
    fi

    return 1
}

# ============================================================================
# USER PROMPTS AND CONFIRMATIONS
# ============================================================================

host_prompt_install() {
    local msg="$1"
    local response

    printf '%s (s/n): ' "$msg" >&2
    read -r response < /dev/tty

    case "$response" in
        s|S|sim|Sim|SIM)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

host_prompt_overwrite_config() {
    local config_name="$1"
    local response

    printf 'O arquivo %s já existe. Deseja sobrescrever? (s/n): ' "$config_name" >&2
    read -r response < /dev/tty

    case "$response" in
        s|S|sim|Sim|SIM)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# BACKUP AND RESTORE
# ============================================================================

host_backup_file() {
    local file="$1"
    local backup_dir="${2:-.}"

    if [[ ! -e "$file" ]]; then
        return 0
    fi

    local filename
    filename=$(basename "$file")
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${backup_dir}/${filename}.bak-${stamp}"

    ea11_backend_info "Criando backup: $backup_path"
    cp -r "$file" "$backup_path"
}

# ============================================================================
# INSTALLATION AND CONFIGURATION
# ============================================================================

host_install_packages() {
    local -a to_install=()

    # Check each required package
    if ! host_is_package_installed 'emacs'; then
        to_install+=('emacs')
    fi

    if ! host_is_package_installed 'espeakup'; then
        to_install+=('espeakup')
    fi

    if ! host_is_package_installed 'espeak-ng'; then
        to_install+=('espeak-ng')
    fi

    if ! host_is_package_installed 'sudo'; then
        to_install+=('sudo')
    fi

    # git is optional
    if ! host_is_package_installed 'git'; then
        if host_prompt_install "Instalar git (recomendado)?"; then
            to_install+=('git')
        fi
    fi

    if [[ ${#to_install[@]} -eq 0 ]]; then
        ea11_backend_info "Nenhum pacote para instalar."
        return 0
    fi

    ea11_backend_info "Instalando pacotes: ${to_install[*]}"
    if ! sudo apt-get update; then
        ea11_backend_die "Erro ao atualizar lista de pacotes."
    fi

    if ! sudo apt-get install -y "${to_install[@]}"; then
        ea11_backend_die "Erro ao instalar pacotes."
    fi

    ea11_backend_info "Pacotes instalados com sucesso."
}

host_setup_emacs_config() {
    local emacs_dir="${HOME}/.config/emacs-a11y"
    local emacs_d="${HOME}/.emacs.d"
    local skel_src="/etc/skel/emacs-a11y"

    ea11_backend_info "Configurando Emacs..."

    # Create config directory if needed
    if [[ ! -d "$emacs_dir" ]]; then
        mkdir -p "$emacs_dir"
    fi

    # Check if dotfiles exist in skel
    if [[ ! -d "$skel_src" ]]; then
        ea11_backend_warn "Diretório de dotfiles não encontrado: $skel_src"
        return 0
    fi

    # Handle .emacs.d directory
    if [[ -e "$emacs_d" ]]; then
        if host_prompt_overwrite_config ".emacs.d"; then
            host_backup_file "$emacs_d" "$HOME"
            rm -rf "$emacs_d"
        else
            ea11_backend_warn "Pulando configuração de .emacs.d (arquivo existente preservado)"
            return 0
        fi
    fi

    # Copy dotfiles
    ea11_backend_info "Copiando arquivos de configuração..."
    cp -r "${skel_src}/"* "$emacs_dir/" 2>/dev/null || true
    cp -r "$skel_src/emacs.d" "$emacs_d"

    ea11_backend_info "Configuração do Emacs concluída."
}

host_setup_espeakup() {
    local espeakup_conf="/etc/espeakup/espeakup.conf"
    local espeakup_default_conf="/etc/default/espeakup"

    ea11_backend_info "Configurando espeakup..."

    # Enable espeakup service
    if systemctl is-enabled espeakup >/dev/null 2>&1; then
        ea11_backend_info "Serviço espeakup já está habilitado."
    else
        ea11_backend_info "Habilitando serviço espeakup..."
        if ! sudo systemctl enable espeakup; then
            ea11_backend_warn "Aviso: Não foi possível habilitar espeakup via systemctl"
        fi
    fi

    # Set speech synth to espeak-ng
    if [[ -f "$espeakup_conf" ]]; then
        if ! grep -q 'synth=espeak-ng' "$espeakup_conf"; then
            ea11_backend_info "Configurando synth espeak-ng em espeakup.conf..."
            if ! sudo sed -i 's/^synth=.*/synth=espeak-ng/' "$espeakup_conf"; then
                ea11_backend_warn "Aviso: Não foi possível configurar espeakup.conf"
            fi
        fi
    fi

    ea11_backend_info "Configuração de espeakup concluída."
}

host_setup_locale() {
    local locale_setting='pt_BR.UTF-8'

    ea11_backend_info "Verificando locale pt_BR.UTF-8..."

    if ! locale -a | grep -q "$locale_setting"; then
        ea11_backend_info "Gerando locale pt_BR.UTF-8..."
        if ! sudo locale-gen pt_BR.UTF-8; then
            ea11_backend_warn "Aviso: Não foi possível gerar locale pt_BR.UTF-8"
        fi
    fi

    ea11_backend_info "Locale pt_BR.UTF-8 está disponível."
}

host_setup_sudoers() {
    local sudoers_a11y_file="/etc/sudoers.d/a11ydevs-nopasswd"

    ea11_backend_info "Configurando regras sudoers para a11y..."

    if [[ -f "$sudoers_a11y_file" ]]; then
        ea11_backend_info "Regras sudoers já existem."
        return 0
    fi

    ea11_backend_info "Adicionando regras sudoers para permitir espeakup sem senha..."

    # Create sudoers rule for espeakup restart
    local sudoers_content="%a11ydevs ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart espeakup
%a11ydevs ALL=(ALL) NOPASSWD: /usr/bin/systemctl start espeakup
%a11ydevs ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop espeakup"

    if ! echo "$sudoers_content" | sudo tee "$sudoers_a11y_file" >/dev/null; then
        ea11_backend_warn "Aviso: Não foi possível criar arquivo sudoers"
    fi

    # Validate sudoers syntax
    if ! sudo visudo -c -f "$sudoers_a11y_file" >/dev/null 2>&1; then
        ea11_backend_warn "Aviso: Sintaxe do sudoers inválida, removendo..."
        sudo rm -f "$sudoers_a11y_file"
    fi
}

# ============================================================================
# MAIN INSTALL COMMAND
# ============================================================================

host_cmd_install() {
    ea11_backend_info "=== Instalação nativa de emacs-a11y ==="
    ea11_backend_info "Sistema operacional: $(host_detect_os)"

    # Check sudo access
    host_check_sudo

    # Check and report package status
    if ! host_check_required_packages; then
        # Packages are missing, proceed with installation
        if ! host_prompt_install "Deseja instalar os pacotes necessários?"; then
            ea11_backend_die "Instalação cancelada pelo usuário."
        fi

        host_install_packages
    fi

    # Setup configurations
    ea11_backend_info "Configurando sistema..."
    host_setup_emacs_config
    host_setup_espeakup
    host_setup_locale
    host_setup_sudoers

    ea11_backend_info "=== Instalação concluída com sucesso! ==="
    ea11_backend_info "Execute 'espeak-ng' para testar fala ou 'emacs' para iniciar Emacs."
}

# ============================================================================
# DISPATCHER
# ============================================================================

if [[ ${#BASH_SOURCE[@]} -eq 1 ]]; then
    # Script is being run directly
    host_cmd_install "$@"
fi
