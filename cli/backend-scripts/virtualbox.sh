#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cli/backend-scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

ea11_backend_ensure_dirs

vboxmanage_cmd() {
    if command -v VBoxManage >/dev/null 2>&1; then
        printf 'VBoxManage\n'
        return 0
    fi
    if command -v vboxmanage >/dev/null 2>&1; then
        printf 'vboxmanage\n'
        return 0
    fi
    ea11_backend_die 'VBoxManage nao encontrado no PATH.'
}

vbox_vm_name() {
    ea11_backend_option_value --name -n "$@" || printf '%s\n' "$EA11_DEFAULT_VM_NAME"
}

vbox_ssh_port() {
    ea11_backend_option_value --port -p "$@" || printf '%s\n' "$EA11_DEFAULT_SSH_PORT"
}

vbox_ssh_user() {
    ea11_backend_option_value --user -u "$@" || printf '%s\n' "$EA11_DEFAULT_SSH_USER"
}

vbox_state() {
    local vm_name="$1"
    local cmd
    cmd=$(vboxmanage_cmd)
    "$cmd" showvminfo "$vm_name" --machinereadable 2>/dev/null | awk -F= '/^VMState=/{gsub(/"/, "", $2); print $2}'
}

vbox_exists() {
    local vm_name="$1"
    local cmd
    cmd=$(vboxmanage_cmd)
    "$cmd" showvminfo "$vm_name" >/dev/null 2>&1
}

vbox_ram_mb() {
    ea11_backend_option_value --ram '' "$@" || printf '2048\n'
}

vbox_cpus() {
    ea11_backend_option_value --cpus '' "$@" || printf '2\n'
}

vbox_user_data_size_mb() {
    ea11_backend_option_value --userdata-size '' "$@" || printf '10240\n'
}

vbox_system_disk_path() {
    local vm_name="$1"
    printf '%s/%s-system.vdi\n' "$EA11_HOME" "$vm_name"
}

vbox_user_data_disk_path() {
    local vm_name="$1"
    printf '%s/%s-userdata.vdi\n' "$EA11_HOME" "$vm_name"
}

vbox_vm_directory() {
    local vm_name="$1"
    printf '%s/VirtualBox VMs/%s\n' "$HOME" "$vm_name"
}

vbox_close_medium_if_exists() {
    local disk_path="$1"
    local cmd
    cmd=$(vboxmanage_cmd)
    if [[ -f "$disk_path" ]]; then
        "$cmd" closemedium disk "$disk_path" --delete >/dev/null 2>&1 || true
        rm -f "$disk_path"
    fi
}

vbox_unregister_vm_if_needed() {
    local vm_name="$1"
    local cmd
    cmd=$(vboxmanage_cmd)

    if ! vbox_exists "$vm_name"; then
        return 0
    fi

    if [[ "$(vbox_state "$vm_name")" == 'running' ]]; then
        "$cmd" controlvm "$vm_name" poweroff >/dev/null 2>&1 || true
    fi

    "$cmd" unregistervm "$vm_name" >/dev/null 2>&1 || "$cmd" unregistervm "$vm_name" --delete >/dev/null 2>&1 || true
}

vbox_remove_stale_vm_directory() {
    local vm_name="$1"
    local vm_dir
    vm_dir=$(vbox_vm_directory "$vm_name")

    if vbox_exists "$vm_name"; then
        return 0
    fi

    if [[ -d "$vm_dir" ]]; then
        ea11_backend_warn "Removendo diretorio residual do VirtualBox em $vm_dir"
        rm -rf "$vm_dir"
    fi
}

vbox_create_or_preserve_userdata_disk() {
    local vm_name="$1"
    local disk_size_mb="$2"
    local disk_path
    local cmd

    disk_path=$(vbox_user_data_disk_path "$vm_name")
    cmd=$(vboxmanage_cmd)

    if [[ -f "$disk_path" ]]; then
        ea11_backend_info "Preservando disco de dados existente em $disk_path"
        return 0
    fi

    ea11_backend_info "Criando disco de dados em $disk_path"
    "$cmd" createmedium disk --filename "$disk_path" --size "$disk_size_mb" --format VDI >/dev/null
}

vbox_convert_qcow2_to_vdi() {
    local source_qcow2="$1"
    local target_vdi="$2"
    local cmd
    cmd=$(vboxmanage_cmd)

    vbox_close_medium_if_exists "$target_vdi"
    ea11_backend_info "Convertendo QCOW2 para VDI..."
    "$cmd" clonemedium disk "$source_qcow2" "$target_vdi" --format VDI >/dev/null
}

vbox_configure_network() {
    local vm_name="$1"
    local ssh_port="$2"
    local cmd
    cmd=$(vboxmanage_cmd)
    "$cmd" modifyvm "$vm_name" --nic1 nat >/dev/null
    "$cmd" modifyvm "$vm_name" --natpf1 delete ssh >/dev/null 2>&1 || true
    "$cmd" modifyvm "$vm_name" --natpf1 "ssh,tcp,127.0.0.1,${ssh_port},,22" >/dev/null
}

vbox_attach_shared_folder_if_requested() {
    local vm_name="$1"
    shift
    local cmd
    cmd=$(vboxmanage_cmd)

    if ea11_backend_has_flag --no-shared-folder "$@"; then
        return 0
    fi

    "$cmd" sharedfolder remove "$vm_name" --name hosthome >/dev/null 2>&1 || true
    "$cmd" sharedfolder add "$vm_name" --name hosthome --hostpath "$HOME" --automount >/dev/null 2>&1 || true
}

vbox_cmd_install() {
    local owner repo tag vm_name ram_mb cpu_count ssh_port user_data_size_mb
    local force_download reinstall
    local qcow2_path system_vdi_path userdata_vdi_path
    local cmd

    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    tag=$(ea11_backend_release_tag "$@")
    vm_name=$(vbox_vm_name "$@")
    ram_mb=$(vbox_ram_mb "$@")
    cpu_count=$(vbox_cpus "$@")
    ssh_port=$(vbox_ssh_port "$@")
    user_data_size_mb=$(vbox_user_data_size_mb "$@")
    force_download=0
    reinstall=0
    cmd=$(vboxmanage_cmd)

    if ea11_backend_download_force "$@"; then
        force_download=1
        reinstall=1
    fi
    if ea11_backend_has_flag --reinstall "$@"; then
        reinstall=1
    fi

    qcow2_path="$EA11_DEFAULT_SYSTEM_IMAGE"
    system_vdi_path=$(vbox_system_disk_path "$vm_name")
    userdata_vdi_path=$(vbox_user_data_disk_path "$vm_name")

    if [[ ! -f "$qcow2_path" || $force_download -eq 1 ]]; then
        ea11_backend_download_release_asset \
            "$owner" \
            "$repo" \
            "$tag" \
            "$EA11_DEFAULT_RELEASE_ASSET" \
            "$qcow2_path"
    fi

    if vbox_exists "$vm_name" && [[ $reinstall -eq 0 ]]; then
        ea11_backend_info "VM VirtualBox '$vm_name' ja existe. Use --reinstall ou --force-download para recriar."
        return 0
    fi

    if [[ $reinstall -eq 1 ]]; then
        vbox_unregister_vm_if_needed "$vm_name"
        vbox_close_medium_if_exists "$system_vdi_path"
    fi

    vbox_remove_stale_vm_directory "$vm_name"

    vbox_convert_qcow2_to_vdi "$qcow2_path" "$system_vdi_path"
    vbox_create_or_preserve_userdata_disk "$vm_name" "$user_data_size_mb"

    ea11_backend_info "Criando VM VirtualBox '$vm_name'"
    "$cmd" createvm --name "$vm_name" --ostype Debian_64 --register >/dev/null
    "$cmd" modifyvm "$vm_name" \
        --memory "$ram_mb" \
        --cpus "$cpu_count" \
        --ioapic on \
        --boot1 disk --boot2 none --boot3 none --boot4 none \
        --graphicscontroller vmsvga \
        --vram 16 \
        --audio-enabled on \
        --audio-driver default \
        --audio-controller ac97 >/dev/null

    vbox_configure_network "$vm_name" "$ssh_port"

    "$cmd" storagectl "$vm_name" --name SATA --add sata --controller IntelAhci >/dev/null
    "$cmd" storageattach "$vm_name" --storagectl SATA --port 0 --device 0 --type hdd --medium "$system_vdi_path" >/dev/null
    "$cmd" storageattach "$vm_name" --storagectl SATA --port 1 --device 0 --type hdd --medium "$userdata_vdi_path" >/dev/null

    vbox_attach_shared_folder_if_requested "$vm_name" "$@"

    ea11_backend_info "VM VirtualBox '$vm_name' instalada."
    ea11_backend_info "Use: ea11ctl vm start -b virtualbox --name $vm_name"
    ea11_backend_info "SSH apos boot: ssh -p $ssh_port ${EA11_DEFAULT_SSH_USER}@localhost"
}

vbox_cmd_version() {
    local vm_name owner repo latest_tag
    vm_name=$(vbox_vm_name "$@")
    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    latest_tag=$(ea11_backend_resolve_release_tag "$owner" "$repo" latest)

    local local_tag="unknown"
    local ssh_port ssh_user
    ssh_port=$(vbox_ssh_port "$@")
    ssh_user=$(vbox_ssh_user "$@")

    if [[ "$(vbox_state "$vm_name" 2>/dev/null || true)" == "running" ]]; then
        local_tag=$(ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=3 \
            -o StrictHostKeyChecking=accept-new \
            -p "$ssh_port" \
            "$ssh_user@localhost" \
            "cat /etc/emacs-a11y-release 2>/dev/null || cat /etc/motd 2>/dev/null | head -n 1" 2>/dev/null | tr -d '[:space:]' || true)
        if [[ -z "$local_tag" ]]; then
            local_tag="unknown"
        fi
    fi

    printf 'backend=virtualbox\nvm=%s\nlocal_tag=%s\nlatest_tag=%s\n' "$vm_name" "$local_tag" "$latest_tag"
}

vbox_cmd_check_update() {
    local vm_name owner repo latest_tag local_tag
    vm_name=$(vbox_vm_name "$@")
    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    latest_tag=$(ea11_backend_resolve_release_tag "$owner" "$repo" latest)
    local_tag="unknown"

    local ssh_port ssh_user
    ssh_port=$(vbox_ssh_port "$@")
    ssh_user=$(vbox_ssh_user "$@")

    if [[ "$(vbox_state "$vm_name" 2>/dev/null || true)" == "running" ]]; then
        local_tag=$(ssh \
            -o BatchMode=yes \
            -o ConnectTimeout=3 \
            -o StrictHostKeyChecking=accept-new \
            -p "$ssh_port" \
            "$ssh_user@localhost" \
            "cat /etc/emacs-a11y-release 2>/dev/null || cat /etc/motd 2>/dev/null | head -n 1" 2>/dev/null | tr -d '[:space:]' || true)
        if [[ -z "$local_tag" ]]; then
            local_tag="unknown"
        fi
    fi

    printf 'backend=virtualbox\nvm=%s\nlocal_tag=%s\nlatest_tag=%s\n' "$vm_name" "$local_tag" "$latest_tag"

    if [[ "$local_tag" == "unknown" ]]; then
        printf 'update_status=unknown-local\n'
        ea11_backend_warn 'Tag local da VM VirtualBox nao disponivel. Inicie a VM e rode novamente para detectar versao interna.'
        ea11_backend_info 'Atualizacao segura: ea11ctl vm install -b virtualbox --force-download --reinstall'
        return 0
    fi

    if [[ "$latest_tag" == "latest" ]]; then
        printf 'update_status=unknown-remote\n'
        ea11_backend_warn 'Nao foi possivel consultar a release mais nova no GitHub agora.'
        return 0
    fi

    if [[ "$local_tag" == "$latest_tag" ]]; then
        printf 'update_status=up-to-date\n'
        ea11_backend_info "VM VirtualBox ja esta na versao mais recente ($local_tag)."
    else
        printf 'update_status=update-available\n'
        ea11_backend_warn "Nova release disponivel: $latest_tag (local: $local_tag)."
        ea11_backend_info "Atualize com: ea11ctl vm install -b virtualbox --force-download --reinstall"
    fi
}

vbox_cmd_list() {
    local cmd
    cmd=$(vboxmanage_cmd)
    "$cmd" list vms
}

vbox_cmd_start() {
    local vm_name headless cmd start_type
    vm_name=$(vbox_vm_name "$@")
    headless=0
    if ea11_backend_has_flag --headless "$@" || ea11_backend_has_flag -h "$@"; then
        headless=1
    fi
    cmd=$(vboxmanage_cmd)

    vbox_exists "$vm_name" || ea11_backend_die "VM VirtualBox '$vm_name' nao encontrada."
    if [[ "$(vbox_state "$vm_name")" == 'running' ]]; then
        ea11_backend_info "VM VirtualBox '$vm_name' ja esta em execucao."
        return 0
    fi

    start_type='gui'
    if [[ $headless -eq 1 ]]; then
        start_type='headless'
    fi

    "$cmd" startvm "$vm_name" --type "$start_type" >/dev/null
    ea11_backend_info "VM VirtualBox '$vm_name' iniciada em modo $start_type."
}

vbox_cmd_stop() {
    local vm_name cmd
    vm_name=$(vbox_vm_name "$@")
    cmd=$(vboxmanage_cmd)

    vbox_exists "$vm_name" || ea11_backend_die "VM VirtualBox '$vm_name' nao encontrada."
    if [[ "$(vbox_state "$vm_name")" != 'running' ]]; then
        ea11_backend_warn "VM VirtualBox '$vm_name' nao esta em execucao."
        return 0
    fi

    if ea11_backend_has_flag --force "$@" || ea11_backend_has_flag -f "$@"; then
        "$cmd" controlvm "$vm_name" poweroff >/dev/null
    else
        "$cmd" controlvm "$vm_name" acpipowerbutton >/dev/null
    fi

    ea11_backend_info "Sinal de desligamento enviado para '$vm_name'."
}

vbox_cmd_close() {
    local vm_name timeout cmd elapsed
    vm_name=$(vbox_vm_name "$@")
    timeout=$(ea11_backend_option_value --timeout -t "$@" || printf '30\n')
    cmd=$(vboxmanage_cmd)

    vbox_cmd_stop --name "$vm_name" "$@"
    elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if [[ "$(vbox_state "$vm_name")" != 'running' ]]; then
            ea11_backend_info "VM VirtualBox '$vm_name' encerrada."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    "$cmd" controlvm "$vm_name" poweroff >/dev/null
    ea11_backend_warn "Timeout atingido; desligamento forcado aplicado em '$vm_name'."
}

vbox_cmd_status() {
    local vm_name state
    vm_name=$(vbox_vm_name "$@")
    vbox_exists "$vm_name" || ea11_backend_die "VM VirtualBox '$vm_name' nao encontrada."
    state=$(vbox_state "$vm_name")
    printf 'backend=virtualbox\nvm=%s\nstate=%s\n' "$vm_name" "$state"
}

vbox_cmd_ssh() {
    local ssh_user ssh_port
    ssh_user=$(vbox_ssh_user "$@")
    ssh_port=$(vbox_ssh_port "$@")
    local -a extra_args=()
    mapfile -t extra_args < <(ea11_backend_extract_extra_args "$@")
    exec ssh -p "$ssh_port" "$ssh_user@localhost" "${extra_args[@]}"
}

vbox_cmd_diagnose() {
    local vm_name lines cmd
    vm_name=$(vbox_vm_name "$@")
    lines=$(ea11_backend_option_value --lines -L "$@" || printf '50\n')
    cmd=$(vboxmanage_cmd)

    vbox_cmd_status --name "$vm_name"
    printf '\n'
    "$cmd" showvminfo "$vm_name"
    printf '\nUltimas %s linhas do VBox.log:\n' "$lines"
    local vm_dir
    vm_dir=$("$cmd" showvminfo "$vm_name" --machinereadable | awk -F= '/^CfgFile=/{gsub(/"/, "", $2); sub(/\/[^\/]+$/, "", $2); print $2}')
    if [[ -n "$vm_dir" && -f "$vm_dir/Logs/VBox.log" ]]; then
        tail -n "$lines" "$vm_dir/Logs/VBox.log"
    else
        ea11_backend_warn 'Log principal do VirtualBox nao encontrado.'
    fi
}

vbox_share_add() {
    local vm_name share_path share_name cmd
    vm_name=$(vbox_vm_name "$@")
    share_path=$(ea11_backend_option_value --path -p "$@" || true)
    share_name=$(ea11_backend_option_value --name '' "$@" || printf 'shared\n')
    cmd=$(vboxmanage_cmd)

    [[ -n "$share_path" ]] || ea11_backend_die 'Use --path para informar o caminho da pasta compartilhada.'
    [[ -d "$share_path" ]] || ea11_backend_die "Caminho nao encontrado: $share_path"

    if ea11_backend_has_flag --readonly "$@" || ea11_backend_has_flag -r "$@"; then
        "$cmd" sharedfolder add "$vm_name" --name "$share_name" --hostpath "$share_path" --readonly
    else
        "$cmd" sharedfolder add "$vm_name" --name "$share_name" --hostpath "$share_path"
    fi
}

vbox_share_remove() {
    local vm_name share_name cmd
    vm_name=$(vbox_vm_name "$@")
    share_name=$(ea11_backend_option_value --name '' "$@" || true)
    [[ -n "$share_name" ]] || ea11_backend_die 'Use --name para informar a pasta compartilhada.'
    cmd=$(vboxmanage_cmd)
    "$cmd" sharedfolder remove "$vm_name" --name "$share_name"
}

vbox_share_list() {
    local vm_name cmd
    vm_name=$(vbox_vm_name "$@")
    cmd=$(vboxmanage_cmd)
    "$cmd" showvminfo "$vm_name" | awk '/^Shared folders:/,/^$/ {print}'
}

vbox_cmd_share_folder() {
    local action="${1:-list}"
    shift || true
    case "$action" in
        add) vbox_share_add "$@" ;;
        remove) vbox_share_remove "$@" ;;
        list) vbox_share_list "$@" ;;
        *) ea11_backend_die "Acao de share-folder desconhecida: $action" ;;
    esac
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        install) vbox_cmd_install "$@" ;;
        version) vbox_cmd_version "$@" ;;
        check-update) vbox_cmd_check_update "$@" ;;
        list) vbox_cmd_list "$@" ;;
        start) vbox_cmd_start "$@" ;;
        stop) vbox_cmd_stop "$@" ;;
        close) vbox_cmd_close "$@" ;;
        status) vbox_cmd_status "$@" ;;
        ssh) vbox_cmd_ssh "$@" ;;
        diagnose) vbox_cmd_diagnose "$@" ;;
        share-folder) vbox_cmd_share_folder "$@" ;;
        *) ea11_backend_die "Comando VirtualBox desconhecido: $command" ;;
    esac
}

main "$@"