#!/bin/bash

################################################################################
# install.sh - Instalador da CLI ea11ctl para bash (macOS, Debian, Ubuntu, Linux)
################################################################################

set -euo pipefail

readonly INSTALL_OWNER='A11yDevs'
readonly INSTALL_REPO='emacs-a11y-vm'
readonly INSTALL_BRANCH='main'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#################################################################################
# Funções de Logging
#################################################################################

print_info() {
    printf '\033[36m[ea11ctl-install] %s\033[0m\n' "$*"
}

print_warn() {
    printf '\033[33m[ea11ctl-install] %s\033[0m\n' "$*"
}

print_error() {
    printf '\033[31m[ea11ctl-install] %s\033[0m\n' "$*" >&2
}

print_success() {
    printf '\033[32m%s\033[0m\n' "$*"
}

#################################################################################
# Detecção do Sistema
#################################################################################

detect_os() {
    local uname_out
    uname_out=$(uname -s)
    
    case "$uname_out" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

detect_distro() {
    # Detalhes para Linux
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo "${ID:-unknown}" | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

get_install_dir() {
    local os="$1"
    
    if [[ "$os" == "macos" ]]; then
        # Para macOS, usar /usr/local/bin ou similar
        if [[ -w /usr/local/bin ]]; then
            echo "/usr/local/bin"
        elif [[ -w "$HOME/.local/bin" ]]; then
            echo "$HOME/.local/bin"
        else
            echo "$HOME/.local/bin"
        fi
    else
        # Para Linux
        if [[ -w /usr/local/bin ]]; then
            echo "/usr/local/bin"
        elif [[ -w "$HOME/.local/bin" ]]; then
            echo "$HOME/.local/bin"
        else
            echo "$HOME/.local/bin"
        fi
    fi
}

#################################################################################
# Funções de Instalação
#################################################################################

ensure_directory() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        mkdir -p "$path"
        print_info "Diretório criado: $path"
    fi
}

add_to_path_if_needed() {
    local path_to_add="$1"
    
    # Verificar se já está no PATH
    if echo "$PATH" | grep -q "$path_to_add"; then
        return 0
    fi
    
    # Tentar adicionar ao PATH permanentemente
    local shell_rc=""
    
    # Detectar shell e arquivo de configuração
    if [[ -n "${BASH_VERSION:-}" ]]; then
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_rc="$HOME/.bashrc"
        elif [[ -f "$HOME/.bash_profile" ]]; then
            shell_rc="$HOME/.bash_profile"
        fi
    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        if [[ -f "$HOME/.zshrc" ]]; then
            shell_rc="$HOME/.zshrc"
        fi
    fi
    
    if [[ -n "$shell_rc" ]] && ! grep -q "$path_to_add" "$shell_rc"; then
        cat >> "$shell_rc" << EOF

# ea11ctl - adicionado por instalador
export PATH="\$PATH:$path_to_add"
EOF
        print_info "Adicionado ao PATH em $shell_rc"
    fi
    
    return 0
}

download_file() {
    local url="$1"
    local dest="$2"
    local file_name="$3"
    
    print_info "Baixando $file_name..."
    
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$dest" || {
            print_error "Falha ao baixar $file_name via curl"
            return 1
        }
    elif command -v wget &>/dev/null; then
        wget -q -O "$dest" "$url" || {
            print_error "Falha ao baixar $file_name via wget"
            return 1
        }
    else
        print_error "Nenhum cliente de download (curl/wget) disponível"
        return 1
    fi
}

check_force_reinstall() {
    local force_reinstall=1
    
    for arg in "$@"; do
        if [[ "$arg" == "--no-force-reinstall" ]]; then
            force_reinstall=0
        fi
    done
    
    echo "$force_reinstall"
}

install_backend_scripts() {
    local backend_dir="$HOME/.emacs-a11y-vm/scripts"
    local local_backend_dir="$SCRIPT_DIR/backend-scripts"
    local remote_backend_url="https://raw.githubusercontent.com/$INSTALL_OWNER/$INSTALL_REPO/$INSTALL_BRANCH/cli/backend-scripts"
    local file

    ensure_directory "$backend_dir"

    for file in common.sh qemu.sh virtualbox.sh; do
        if [[ -f "$local_backend_dir/$file" ]]; then
            cp "$local_backend_dir/$file" "$backend_dir/$file"
        else
            download_file "$remote_backend_url/$file" "$backend_dir/$file" "$file"
        fi
    done

    chmod +x "$backend_dir/qemu.sh" "$backend_dir/virtualbox.sh"
    print_info "Scripts de backend instalados em: $backend_dir"
}

#################################################################################
# Main
#################################################################################

main() {
    print_info "=== Instalador da CLI ea11ctl ==="
    
    local os
    os=$(detect_os)
    
    if [[ "$os" == "unknown" ]]; then
        print_error "Sistema operacional não suportado"
        exit 1
    fi
    
    print_info "Sistema detectado: $os"
    
    local distro=""
    if [[ "$os" == "linux" ]]; then
        distro=$(detect_distro)
        print_info "Distribuição detectada: $distro"
    fi
    
    # Determinar diretório de instalação
    local install_dir
    install_dir=$(get_install_dir "$os")
    
    # Garantir que o diretório existe
    ensure_directory "$install_dir"
    
    # URLs dos arquivos
    local base_url="https://raw.githubusercontent.com/$INSTALL_OWNER/$INSTALL_REPO/$INSTALL_BRANCH/cli"
    declare -a files=(
        "ea11ctl"
        "install.sh"
        "VERSION"
    )
    
    # Verificar se deve fazer reinstalação forçada
    local force_reinstall
    force_reinstall=$(check_force_reinstall "$@")
    
    print_info "Baixando arquivos da CLI..."
    print_info "Destino: $install_dir"
    
    # Baixar arquivos
    for file in "${files[@]}"; do
        local dest="$install_dir/$file"
        local url="$base_url/$file"
        
        if [[ -f "$dest" ]] && [[ $force_reinstall -eq 0 ]]; then
            print_info "Arquivo já existe (modo atualização): $file"
        else
            if [[ -f "$dest" ]] && [[ $force_reinstall -eq 1 ]]; then
                rm -f "$dest"
            fi
            download_file "$url" "$dest" "$file"
        fi
    done
    
    # Tornar ea11ctl executável
    chmod +x "$install_dir/ea11ctl"
    chmod +x "$install_dir/install.sh"
    print_info "Permissões de execução aplicadas"

    install_backend_scripts
    
    # Adicionar ao PATH se necessário
    add_to_path_if_needed "$install_dir"
    
    # Verificar se ea11ctl está no PATH atual
    if ! echo "$PATH" | grep -q "$install_dir"; then
        export PATH="$install_dir:$PATH"
    fi
    
    print_success ""
    print_success "Instalação concluída!"
    
    # Mostrar informações
    local installed_version
    if [[ -f "$install_dir/VERSION" ]]; then
        installed_version=$(cat "$install_dir/VERSION" | tr -d '[:space:]')
    else
        installed_version="desconhecida"
    fi
    
    print_success "Versão instalada: $installed_version"
    print_success "Localização: $install_dir/ea11ctl"
    
    print_info "Teste agora com:"
    echo "  ea11ctl help"
    echo "  ea11ctl version --check-update"
    echo "  ea11ctl vm list"
    
    # Se o PATH foi alterado, avisar
    if ! echo "$PATH" | grep -q "$install_dir"; then
        print_warn ""
        print_warn "AVISO: Adicione o diretório ao seu PATH permanentemente:"
        print_warn "  export PATH=\"\$PATH:$install_dir\""
        print_warn ""
        print_warn "Ou execute para usar no terminal atual:"
        print_warn "  export PATH=\"$install_dir:\$PATH\""
    fi
}

# Executar main
main "$@"
