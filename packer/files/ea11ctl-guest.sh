#!/usr/bin/env bash

set -euo pipefail

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

host_share_mountpoint() {
    local host_user
    host_user="$(sanitize_user "$(read_fw_cfg_string host_user)")"
    printf '/home/%s\n' "$host_user"
}

show_help() {
    cat <<'EOF'
ea11ctl (guest)

Uso:
  ea11ctl host-share list
  ea11ctl host-share config
  ea11ctl host-share mount
  ea11ctl host-share umount
EOF
}

host_share_list() {
    local mount_point
    mount_point="$(host_share_mountpoint)"

    echo "Mount point esperado: $mount_point"
    echo
    findmnt -rn -t cifs,fuse.sshfs,9p || true
}

host_share_config() {
    local mode host_user ssh_host ssh_port ssh_user ssh_path smb_server smb_share smb_user

    mode="$(read_fw_cfg_string share_mode)"
    host_user="$(sanitize_user "$(read_fw_cfg_string host_user)")"
    ssh_host="$(read_fw_cfg_string ssh_host)"
    ssh_port="$(read_fw_cfg_string ssh_port)"
    ssh_user="$(read_fw_cfg_string ssh_user)"
    ssh_path="$(read_fw_cfg_string ssh_path)"
    smb_server="$(read_fw_cfg_string smb_server)"
    smb_share="$(read_fw_cfg_string smb_share)"
    smb_user="$(read_fw_cfg_string smb_user)"

    printf 'mode=%s\n' "${mode:-auto}"
    printf 'host_user=%s\n' "${host_user}"
    printf 'ssh_host=%s\n' "${ssh_host}"
    printf 'ssh_port=%s\n' "${ssh_port}"
    printf 'ssh_user=%s\n' "${ssh_user}"
    printf 'ssh_path=%s\n' "${ssh_path}"
    printf 'smb_server=%s\n' "${smb_server}"
    printf 'smb_share=%s\n' "${smb_share}"
    printf 'smb_user=%s\n' "${smb_user}"
}

host_share_mount() {
    sudo /usr/local/bin/mount-shared-folder.sh
}

host_share_umount() {
    local mount_point
    mount_point="$(host_share_mountpoint)"

    if mountpoint -q "$mount_point"; then
        sudo umount "$mount_point"
        echo "Desmontado: $mount_point"
    else
        echo "Nao montado: $mount_point"
    fi
}

main() {
    local command="${1:-}"
    local subcommand="${2:-}"

    case "$command" in
        host-share)
            case "$subcommand" in
                list)
                    host_share_list
                    ;;
                config)
                    host_share_config
                    ;;
                mount)
                    host_share_mount
                    ;;
                umount)
                    host_share_umount
                    ;;
                *)
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        help|-h|--help|"")
            show_help
            ;;
        *)
            show_help
            exit 1
            ;;
    esac
}

main "$@"
