#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cli/backend-scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

ea11_backend_ensure_dirs

qemu_state_file() {
    printf '%s/%s.env\n' "$EA11_QEMU_STATE_DIR" "$1"
}

qemu_log_file() {
    printf '%s/%s.qemu.log\n' "$EA11_LOG_DIR" "$1"
}

qemu_load_state() {
    local vm_name="$1"
    local state_file
    state_file=$(qemu_state_file "$vm_name")
    if [[ -f "$state_file" ]]; then
        # shellcheck source=/dev/null
        source "$state_file"
    fi
}

qemu_save_state() {
    local vm_name="$1"
    local state_file
    state_file=$(qemu_state_file "$vm_name")
    cat > "$state_file" <<EOF
VM_NAME=${VM_NAME}
QEMU_PID=${QEMU_PID:-}
SSH_PORT=${SSH_PORT}
SYSTEM_IMAGE=${SYSTEM_IMAGE}
DATA_DISK=${DATA_DISK}
LOG_FILE=${LOG_FILE}
STATE=${STATE}
EOF
}

qemu_resolve_accel_args() {
    if [[ -n "${EA11_QEMU_ACCEL:-}" ]]; then
        printf '%s\n' '-accel' "$EA11_QEMU_ACCEL"
        return 0
    fi

    if [[ "$(uname -s)" == "Darwin" ]]; then
        printf '%s\n' '-accel' 'hvf'
        return 0
    fi

    if [[ -e /dev/kvm ]]; then
        printf '%s\n' '-enable-kvm'
    fi
}

qemu_resolve_cpu_args() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # Evita warnings/falhas de virtualizacao no macOS com HVF.
        printf '%s\n' '-cpu' 'host,-svm'
        return 0
    fi
}

qemu_apply_macos_desktop_args() {
    local -n _cmd_ref=$1
    local fullscreen_mode vga_mode

    if [[ "$(uname -s)" != "Darwin" ]]; then
        return 0
    fi

    fullscreen_mode="${EA11_QEMU_FULLSCREEN:-on}"
    vga_mode="${EA11_QEMU_VGA:-virtio}"

    _cmd_ref+=(
        -vga "$vga_mode"
        -display "cocoa,zoom-to-fit=on,full-screen=${fullscreen_mode}"
        -k en-us
        -audiodev coreaudio,id=audio0,out.frequency=44100,out.mixing-engine=on,in.mixing-engine=off
        -device virtio-sound-pci,audiodev=audio0
    )
}

qemu_runtime_memory_mb() {
    if [[ -n "${EA11_QEMU_MEMORY_MB:-}" ]]; then
        printf '%s\n' "$EA11_QEMU_MEMORY_MB"
        return 0
    fi

    if [[ "$(uname -s)" == "Darwin" ]]; then
        printf '1536\n'
    else
        printf '2048\n'
    fi
}

qemu_runtime_cpus() {
    if [[ -n "${EA11_QEMU_CPUS:-}" ]]; then
        printf '%s\n' "$EA11_QEMU_CPUS"
        return 0
    fi

    if [[ "$(uname -s)" == "Darwin" ]]; then
        printf '1\n'
    else
        printf '2\n'
    fi
}

qemu_net_device_name() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        printf 'virtio-net\n'
    else
        printf 'virtio-net-pci\n'
    fi
}

qemu_is_running() {
    local pid="$1"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

qemu_parse_vm_name() {
    ea11_backend_option_value --name -n "$@" || printf '%s\n' "$EA11_DEFAULT_VM_NAME"
}

qemu_parse_ssh_port() {
    ea11_backend_option_value --port -p "$@" || printf '%s\n' "$EA11_DEFAULT_SSH_PORT"
}

qemu_parse_ssh_user() {
    ea11_backend_option_value --user -u "$@" || printf '%s\n' "$EA11_DEFAULT_SSH_USER"
}

qemu_cmd_list() {
    local found=0
    shopt -s nullglob
    local state_file
    for state_file in "$EA11_QEMU_STATE_DIR"/*.env; do
        found=1
        unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE
        # shellcheck source=/dev/null
        source "$state_file"
        if qemu_is_running "${QEMU_PID:-}"; then
            printf '%s\trunning\tssh:%s\n' "$VM_NAME" "$SSH_PORT"
        else
            printf '%s\tstopped\tssh:%s\n' "$VM_NAME" "${SSH_PORT:-$EA11_DEFAULT_SSH_PORT}"
        fi
    done
    shopt -u nullglob

    if [[ $found -eq 0 ]]; then
        ea11_backend_info 'Nenhuma VM QEMU registrada.'
    fi
}

qemu_cmd_start() {
    local vm_name ssh_port headless system_image data_disk log_file mem_mb cpu_count net_device
    vm_name=$(qemu_parse_vm_name "$@")
    ssh_port=$(qemu_parse_ssh_port "$@")
    headless=0
    if ea11_backend_has_flag --headless "$@" || ea11_backend_has_flag -h "$@"; then
        headless=1
    fi

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE
    qemu_load_state "$vm_name"

    if qemu_is_running "${QEMU_PID:-}"; then
        ea11_backend_info "VM QEMU '$vm_name' ja esta em execucao (PID ${QEMU_PID})."
        return 0
    fi

    system_image="${EA11_SYSTEM_IMAGE:-$EA11_DEFAULT_SYSTEM_IMAGE}"
    data_disk="${EA11_HOME}/${vm_name}-home.qcow2"
    log_file=$(qemu_log_file "$vm_name")
    mem_mb=$(qemu_runtime_memory_mb)
    cpu_count=$(qemu_runtime_cpus)
    net_device=$(qemu_net_device_name)

    [[ -f "$system_image" ]] || ea11_backend_die "Imagem de sistema nao encontrada: $system_image"

    if [[ ! -f "$data_disk" ]]; then
        ea11_backend_info "Criando disco de dados em $data_disk"
        qemu-img create -f qcow2 "$data_disk" 20G >/dev/null
    fi

    local -a accel_args=()
    local -a cpu_args=()
    mapfile -t accel_args < <(qemu_resolve_accel_args)
    mapfile -t cpu_args < <(qemu_resolve_cpu_args)

    local -a qemu_cmd=(
        qemu-system-x86_64
        "${accel_args[@]}"
        "${cpu_args[@]}"
        -m "$mem_mb"
        -smp "$cpu_count"
        -drive "file=${system_image},format=qcow2,if=virtio"
        -drive "file=${data_disk},format=qcow2,if=virtio"
        -netdev "user,id=net0,hostfwd=tcp::${ssh_port}-:22"
        -device "${net_device},netdev=net0"
    )

    if [[ $headless -eq 1 ]]; then
        qemu_cmd+=(-nographic -serial mon:stdio)
    else
        qemu_apply_macos_desktop_args qemu_cmd
    fi

    nohup "${qemu_cmd[@]}" > "$log_file" 2>&1 < /dev/null &
    local qemu_pid=$!
    sleep 1

    # Em alguns macOS/QEMU, HVF aborta no boot; faz fallback automatico para TCG.
    if ! qemu_is_running "$qemu_pid"; then
        if [[ "$(uname -s)" == "Darwin" ]] && grep -qi 'hvf-all.c\|do_hv_vm_protect\|assertion failed' "$log_file"; then
            ea11_backend_warn 'Falha no acelerador HVF detectada, tentando fallback com TCG.'
            accel_args=(-accel tcg)
            qemu_cmd=(
                qemu-system-x86_64
                "${accel_args[@]}"
                "${cpu_args[@]}"
                -m "$mem_mb"
                -smp "$cpu_count"
                -drive "file=${system_image},format=qcow2,if=virtio"
                -drive "file=${data_disk},format=qcow2,if=virtio"
                -netdev "user,id=net0,hostfwd=tcp::${ssh_port}-:22"
                -device "${net_device},netdev=net0"
            )

            if [[ $headless -eq 1 ]]; then
                qemu_cmd+=(-nographic -serial mon:stdio)
            else
                qemu_apply_macos_desktop_args qemu_cmd
            fi

            nohup "${qemu_cmd[@]}" > "$log_file" 2>&1 < /dev/null &
            qemu_pid=$!
            sleep 1
        fi
    fi

    if ! qemu_is_running "$qemu_pid"; then
        ea11_backend_die "Falha ao iniciar VM QEMU '$vm_name'. Veja log em $log_file"
    fi

    VM_NAME="$vm_name"
    QEMU_PID="$qemu_pid"
    SSH_PORT="$ssh_port"
    SYSTEM_IMAGE="$system_image"
    DATA_DISK="$data_disk"
    LOG_FILE="$log_file"
    STATE="running"
    qemu_save_state "$vm_name"

    ea11_backend_info "VM QEMU '$vm_name' iniciada com PID ${qemu_pid}."
    ea11_backend_info "SSH: ssh -p ${ssh_port} ${EA11_DEFAULT_SSH_USER}@localhost"
}

qemu_cmd_stop() {
    local vm_name force
    vm_name=$(qemu_parse_vm_name "$@")
    force=0
    if ea11_backend_has_flag --force "$@" || ea11_backend_has_flag -f "$@"; then
        force=1
    fi

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE
    qemu_load_state "$vm_name"

    if ! qemu_is_running "${QEMU_PID:-}"; then
        ea11_backend_warn "VM QEMU '$vm_name' nao esta em execucao."
        return 0
    fi

    if [[ $force -eq 1 ]]; then
        kill -KILL "$QEMU_PID"
    else
        kill -TERM "$QEMU_PID"
    fi

    STATE='stopped'
    QEMU_PID=''
    qemu_save_state "$vm_name"
    ea11_backend_info "VM QEMU '$vm_name' finalizada."
}

qemu_cmd_status() {
    local vm_name
    vm_name=$(qemu_parse_vm_name "$@")
    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE
    qemu_load_state "$vm_name"

    if qemu_is_running "${QEMU_PID:-}"; then
        printf 'backend=qemu\nvm=%s\nstate=running\npid=%s\nssh_port=%s\n' "$VM_NAME" "$QEMU_PID" "$SSH_PORT"
    else
        printf 'backend=qemu\nvm=%s\nstate=stopped\nssh_port=%s\n' "${VM_NAME:-$vm_name}" "${SSH_PORT:-$EA11_DEFAULT_SSH_PORT}"
    fi
}

qemu_cmd_ssh() {
    local vm_name ssh_user ssh_port
    vm_name=$(qemu_parse_vm_name "$@")
    ssh_user=$(qemu_parse_ssh_user "$@")
    ssh_port=$(qemu_parse_ssh_port "$@")

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE
    qemu_load_state "$vm_name"

    if [[ -n "${SSH_PORT:-}" ]]; then
        ssh_port="$SSH_PORT"
    fi

    local -a extra_args=()
    mapfile -t extra_args < <(ea11_backend_extract_extra_args "$@")
    exec ssh -p "$ssh_port" "$ssh_user@localhost" "${extra_args[@]}"
}

qemu_cmd_diagnose() {
    local vm_name lines
    vm_name=$(qemu_parse_vm_name "$@")
    lines=$(ea11_backend_option_value --lines -L "$@" || printf '40\n')

    qemu_cmd_status --name "$vm_name"
    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE
    qemu_load_state "$vm_name"
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '\nlog=%s\n' "$LOG_FILE"
        ea11_backend_tail_lines "$LOG_FILE" "$lines"
    fi
}

qemu_cmd_install() {
    local owner repo tag force_download vm_name ssh_port data_disk log_file
    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    tag=$(ea11_backend_release_tag "$@")
    vm_name=$(qemu_parse_vm_name "$@")
    ssh_port=$(qemu_parse_ssh_port "$@")
    data_disk="${EA11_HOME}/${vm_name}-home.qcow2"
    log_file=$(qemu_log_file "$vm_name")
    force_download=0
    if ea11_backend_download_force "$@"; then
        force_download=1
    fi

    ea11_backend_require_command qemu-img

    if [[ -f "$EA11_DEFAULT_SYSTEM_IMAGE" && $force_download -eq 0 ]]; then
        ea11_backend_info "Imagem QEMU ja existe em $EA11_DEFAULT_SYSTEM_IMAGE"
    else
        ea11_backend_download_release_asset \
            "$owner" \
            "$repo" \
            "$tag" \
            "$EA11_DEFAULT_RELEASE_ASSET" \
            "$EA11_DEFAULT_SYSTEM_IMAGE"
    fi

    qemu-img info "$EA11_DEFAULT_SYSTEM_IMAGE" >/dev/null

    VM_NAME="$vm_name"
    QEMU_PID=''
    SSH_PORT="$ssh_port"
    SYSTEM_IMAGE="$EA11_DEFAULT_SYSTEM_IMAGE"
    DATA_DISK="$data_disk"
    LOG_FILE="$log_file"
    STATE='stopped'
    qemu_save_state "$vm_name"

    ea11_backend_info "Imagem QEMU pronta em $EA11_DEFAULT_SYSTEM_IMAGE"
    ea11_backend_info "VM QEMU '$vm_name' registrada (state=stopped)."
    ea11_backend_info "Use: ea11ctl vm start -b qemu"
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        install) qemu_cmd_install "$@" ;;
        list) qemu_cmd_list "$@" ;;
        start) qemu_cmd_start "$@" ;;
        stop|close) qemu_cmd_stop "$@" ;;
        status) qemu_cmd_status "$@" ;;
        ssh) qemu_cmd_ssh "$@" ;;
        diagnose) qemu_cmd_diagnose "$@" ;;
        *) ea11_backend_die "Comando QEMU desconhecido: $command" ;;
    esac
}

main "$@"