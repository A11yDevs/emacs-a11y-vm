#!/bin/bash
# Script para montar compartilhamento do host no guest (QEMU).
# Modos suportados:
# - SSH (Unix/macOS): sshfs via fw_cfg (opt/ea11/ssh_*)
# - CIFS (Windows): cifs via fw_cfg (opt/ea11/smb_*)

set -euo pipefail

USER_UID=1000
USER_GID=1000

echo "=== mount-shared-folder.sh iniciado ==="
echo "Data: $(date)"

read_fw_cfg_string() {
    local key="$1"
    local value=""
    local raw_path="/sys/firmware/qemu_fw_cfg/by_name/opt/ea11/${key}/raw"
    local alt_path="/sys/firmware/qemu_fw_cfg/by_name/opt/ea11/${key}"

    if [[ -r "$raw_path" ]]; then
        value="$(tr -d '\0\r\n' < "$raw_path" 2>/dev/null || true)"
    elif [[ -r "$alt_path" ]]; then
        value="$(tr -d '\0\r\n' < "$alt_path" 2>/dev/null || true)"
    fi

    printf '%s\n' "$value"
}

sanitize_user() {
    local value="$1"
    value="$(printf '%s' "$value" | tr -cd '[:alnum:]_-')"
    if [[ -z "$value" ]]; then
        printf 'hosthome\n'
        return
    fi
    printf '%s\n' "$value"
}

share_mountpoint() {
    local host_user
    host_user="$(sanitize_user "$(read_fw_cfg_string host_user)")"
    printf '/home/%s\n' "$host_user"
}

prepare_mountpoint() {
    local mount_point="$1"
    mkdir -p "$mount_point"
    chown "$USER_UID:$USER_GID" "$mount_point" 2>/dev/null || true
}

mount_host_ssh() {
    local ssh_host ssh_port ssh_user ssh_path ssh_password mount_point target
    local -a sshfs_args

    ssh_host="$(read_fw_cfg_string ssh_host)"
    ssh_port="$(read_fw_cfg_string ssh_port)"
    ssh_user="$(read_fw_cfg_string ssh_user)"
    ssh_path="$(read_fw_cfg_string ssh_path)"
    ssh_password="$(read_fw_cfg_string ssh_password)"
    mount_point="$(share_mountpoint)"

    [[ -z "$ssh_host" ]] && ssh_host='10.0.2.2'
    [[ -z "$ssh_port" ]] && ssh_port='22'

    if [[ -z "$ssh_user" || -z "$ssh_path" ]]; then
        echo "SSH share sem usuario/caminho configurado; pulando."
        return 1
    fi

    if ! command -v sshfs &>/dev/null; then
        echo "AVISO: sshfs nao encontrado (instale pacote sshfs no guest)."
        return 1
    fi

    prepare_mountpoint "$mount_point"
    if mountpoint -q "$mount_point"; then
        echo "SSH share ja montado em $mount_point"
        return 0
    fi

    target="${ssh_user}@${ssh_host}:${ssh_path}"
    sshfs_args=(
        -p "$ssh_port"
        -o StrictHostKeyChecking=accept-new
        -o UserKnownHostsFile=/root/.ssh/known_hosts
        -o reconnect
        -o uid="$USER_UID"
        -o gid="$USER_GID"
    )

    if [[ -n "$ssh_password" ]]; then
        if printf '%s' "$ssh_password" | sshfs "$target" "$mount_point" "${sshfs_args[@]}" -o password_stdin; then
            echo "SSH share montado: $target -> $mount_point"
            return 0
        fi
    else
        if sshfs "$target" "$mount_point" "${sshfs_args[@]}"; then
            echo "SSH share montado: $target -> $mount_point"
            return 0
        fi
    fi

    echo "AVISO: Falha ao montar SSH share ($target)"
    return 1
}

mount_qemu_smb_fallback() {
    local smb_server='10.0.2.4'
    local smb_share='qemu'
    local mount_point
    local mounted=0

    if ! command -v mount.cifs &>/dev/null; then
        echo "AVISO: mount.cifs nao encontrado (instale cifs-utils para SMB fallback no QEMU)"
        return 1
    fi

    mount_point="$(share_mountpoint)"

    if mountpoint -q "$mount_point"; then
        echo "QEMU SMB fallback ja montado em $mount_point"
        return 0
    fi

    prepare_mountpoint "$mount_point"

    local options=(
        "guest,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,noperm,vers=3.0"
        "guest,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,noperm,vers=2.1"
        "guest,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,noperm,vers=2.0"
        "guest,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,noperm,vers=1.0"
    )

    for opt in "${options[@]}"; do
        if mount -t cifs "//$smb_server/$smb_share" "$mount_point" -o "$opt"; then
            echo "QEMU SMB fallback montado: //$smb_server/$smb_share -> $mount_point"
            mounted=1
            break
        fi
    done

    if [[ $mounted -eq 0 ]]; then
        echo "AVISO: SMB fallback do QEMU indisponivel (//$smb_server/$smb_share)."
        return 1
    fi

    return 0
}

mount_host_smb() {
    local smb_server smb_share smb_user smb_password mount_point

    if ! command -v mount.cifs &>/dev/null; then
        return 1
    fi

    smb_server="$(read_fw_cfg_string smb_server)"
    smb_share="$(read_fw_cfg_string smb_share)"
    smb_user="$(read_fw_cfg_string smb_user)"
    smb_password="$(read_fw_cfg_string smb_password)"

    if [[ -z "$smb_server" || -z "$smb_share" ]]; then
        return 1
    fi

    mount_point="$(share_mountpoint)"

    if mountpoint -q "$mount_point"; then
        echo "SMB do host ja montado em $mount_point"
        return 0
    fi

    prepare_mountpoint "$mount_point"

    local options=()
    if [[ -n "$smb_user" && -n "$smb_password" ]]; then
        options=("username=$smb_user,password=$smb_password,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,vers=3.0")
    else
        options=("guest,uid=$USER_UID,gid=$USER_GID,iocharset=utf8,noperm,vers=3.0")
    fi

    if mount -t cifs "//$smb_server/$smb_share" "$mount_point" -o "${options[0]}"; then
        echo "SMB do host montado: //$smb_server/$smb_share -> $mount_point"
        return 0
    fi

    local fallback_options=('vers=2.1' 'vers=2.0' 'vers=1.0')
    for fallback_opt in "${fallback_options[@]}"; do
        local opt_string="${options[0]%%vers=*}$fallback_opt"
        if mount -t cifs "//$smb_server/$smb_share" "$mount_point" -o "$opt_string" 2>/dev/null; then
            echo "SMB do host montado (fallback $fallback_opt): //$smb_server/$smb_share -> $mount_point"
            return 0
        fi
    done

    echo "AVISO: Falha ao montar SMB do host ($smb_server/$smb_share)"
    return 1
}

mount_by_mode() {
    local mode
    mode="$(read_fw_cfg_string share_mode)"
    [[ -z "$mode" ]] && mode='auto'

    case "$mode" in
        ssh)
            mount_host_ssh || true
            ;;
        cifs)
            mount_host_smb || mount_qemu_smb_fallback || true
            ;;
        auto)
            mount_host_ssh || mount_host_smb || mount_qemu_smb_fallback || true
            ;;
        *)
            echo "AVISO: share_mode desconhecido '$mode', usando auto"
            mount_host_ssh || mount_host_smb || mount_qemu_smb_fallback || true
            ;;
    esac
}

mount_by_mode
