#!/usr/bin/env bash

set -euo pipefail

EA11_HOME="${HOME}/.emacs-a11y-vm"
EA11_SCRIPTS_DIR="${EA11_HOME}/scripts"
EA11_QEMU_STATE_DIR="${EA11_HOME}/qemu"
EA11_LOG_DIR="${EA11_HOME}/logs"
EA11_DEFAULT_VM_NAME="debian-a11y"
EA11_DEFAULT_SSH_USER="a11ydevs"
EA11_DEFAULT_SSH_PORT="2222"
EA11_DEFAULT_SYSTEM_IMAGE="${EA11_HOME}/debian-a11ydevs.qcow2"
EA11_DEFAULT_RELEASE_OWNER="A11yDevs"
EA11_DEFAULT_RELEASE_REPO="emacs-a11y-vm"
EA11_DEFAULT_RELEASE_TAG="latest"
EA11_DEFAULT_RELEASE_ASSET="debian-a11ydevs.qcow2"

ea11_backend_info() {
    printf '[ea11ctl] %s\n' "$*" >&2
}

ea11_backend_warn() {
    printf '[ea11ctl] %s\n' "$*" >&2
}

ea11_backend_error() {
    printf '[ea11ctl] %s\n' "$*" >&2
}

ea11_backend_die() {
    ea11_backend_error "$*"
    exit 1
}

ea11_backend_ensure_dirs() {
    mkdir -p "$EA11_HOME" "$EA11_SCRIPTS_DIR" "$EA11_QEMU_STATE_DIR" "$EA11_LOG_DIR"
}

ea11_backend_has_flag() {
    local needle="$1"
    shift
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

ea11_backend_option_value() {
    local long_name="$1"
    local short_name="$2"
    shift 2

    local current
    while [[ $# -gt 0 ]]; do
        current="$1"
        shift

        if [[ "$current" == "$long_name" || "$current" == "$short_name" ]]; then
            if [[ $# -eq 0 ]]; then
                ea11_backend_die "Opcao $current requer um valor."
            fi
            printf '%s\n' "$1"
            return 0
        fi
    done

    return 1
}

ea11_backend_tail_lines() {
    local file_path="$1"
    local line_count="$2"
    if [[ -f "$file_path" ]]; then
        tail -n "$line_count" "$file_path"
    else
        ea11_backend_warn "Arquivo nao encontrado: $file_path"
    fi
}

ea11_backend_extract_extra_args() {
    local found_separator=0
    local arg
    for arg in "$@"; do
        if [[ $found_separator -eq 1 ]]; then
            printf '%s\n' "$arg"
            continue
        fi
        if [[ "$arg" == "--" ]]; then
            found_separator=1
        fi
    done
}

ea11_backend_require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 || ea11_backend_die "Comando requerido nao encontrado: $command_name"
}

ea11_backend_release_owner() {
    ea11_backend_option_value --owner '' "$@" || printf '%s\n' "$EA11_DEFAULT_RELEASE_OWNER"
}

ea11_backend_release_repo() {
    ea11_backend_option_value --repo '' "$@" || printf '%s\n' "$EA11_DEFAULT_RELEASE_REPO"
}

ea11_backend_release_tag() {
    ea11_backend_option_value --tag '' "$@" || printf '%s\n' "$EA11_DEFAULT_RELEASE_TAG"
}

ea11_backend_download_force() {
    if ea11_backend_has_flag --force-download "$@" || ea11_backend_has_flag --force "$@" || ea11_backend_has_flag -f "$@"; then
        return 0
    fi
    return 1
}

ea11_backend_release_asset_url() {
    local owner="$1"
    local repo="$2"
    local tag="$3"
    local asset_name="$4"

    if [[ "$tag" == "latest" ]]; then
        printf 'https://github.com/%s/%s/releases/latest/download/%s\n' "$owner" "$repo" "$asset_name"
    else
        printf 'https://github.com/%s/%s/releases/download/%s/%s\n' "$owner" "$repo" "$tag" "$asset_name"
    fi
}

ea11_backend_download_file() {
    local url="$1"
    local destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fL --retry 3 --retry-delay 2 "$url" -o "$destination"
        return 0
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -O "$destination" "$url"
        return 0
    fi

    ea11_backend_die 'Nem curl nem wget estao disponiveis para download.'
}

ea11_backend_download_release_asset() {
    local owner="$1"
    local repo="$2"
    local tag="$3"
    local asset_name="$4"
    local destination="$5"

    local tmp_file
    local url
    url=$(ea11_backend_release_asset_url "$owner" "$repo" "$tag" "$asset_name")
    tmp_file="${destination}.download"

    ea11_backend_info "Baixando asset ${asset_name} (${tag})..."
    ea11_backend_download_file "$url" "$tmp_file" || {
        rm -f "$tmp_file"
        ea11_backend_die "Falha ao baixar asset da release: $url"
    }

    mv "$tmp_file" "$destination"
}