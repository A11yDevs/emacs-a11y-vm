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

qemu_share_config_file() {
    printf '%s\n' "$EA11_QEMU_SHARE_CONFIG"
}

qemu_runtime_config_file() {
    printf '%s\n' "$EA11_QEMU_RUNTIME_CONFIG"
}

qemu_runtime_config_backup_file() {
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    printf '%s.bak-%s\n' "$(qemu_runtime_config_file)" "$stamp"
}

qemu_default_accel() {
    case "$(uname -s)" in
        Darwin*)
            printf 'hvf\n'
            ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            printf 'whpx\n'
            ;;
        *)
            if [[ -e /dev/kvm ]]; then
                printf 'kvm\n'
            else
                printf 'tcg\n'
            fi
            ;;
    esac
}

qemu_default_cpu_model() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            printf 'qemu64\n'
            ;;
        *)
            printf 'host\n'
            ;;
    esac
}

qemu_load_runtime_config() {
    local cfg
    cfg=$(qemu_runtime_config_file)

    qemu_set_runtime_defaults

    if [[ -f "$cfg" ]]; then
        # shellcheck source=/dev/null
        source "$cfg"
    fi
}

qemu_set_runtime_defaults() {
    QEMU_ACCEL="$(qemu_default_accel)"
    QEMU_CPU_MODEL="$(qemu_default_cpu_model)"
    QEMU_CPUS='4'
    QEMU_MEMORY_MB='4096'
    QEMU_NET_DEVICE='virtio-net-pci'
    QEMU_DISK_IF='virtio'
    QEMU_DISK_CACHE='writeback'
    QEMU_DISK_DISCARD='unmap'
    QEMU_VIDEO_DEVICE='virtio-vga'
    QEMU_FULLSCREEN='on'
}

qemu_save_runtime_config() {
    local cfg
    cfg=$(qemu_runtime_config_file)
    {
        printf '# Configuracao de runtime do QEMU para ea11ctl\n'
        printf '# Edite com cuidado. Valores invalidos podem impedir o boot.\n'
        printf 'QEMU_ACCEL=%q\n' "$QEMU_ACCEL"
        printf 'QEMU_CPU_MODEL=%q\n' "$QEMU_CPU_MODEL"
        printf 'QEMU_CPUS=%q\n' "$QEMU_CPUS"
        printf 'QEMU_MEMORY_MB=%q\n' "$QEMU_MEMORY_MB"
        printf 'QEMU_NET_DEVICE=%q\n' "$QEMU_NET_DEVICE"
        printf 'QEMU_DISK_IF=%q\n' "$QEMU_DISK_IF"
        printf 'QEMU_DISK_CACHE=%q\n' "$QEMU_DISK_CACHE"
        printf 'QEMU_DISK_DISCARD=%q\n' "$QEMU_DISK_DISCARD"
        printf 'QEMU_VIDEO_DEVICE=%q\n' "$QEMU_VIDEO_DEVICE"
        printf 'QEMU_FULLSCREEN=%q\n' "$QEMU_FULLSCREEN"
    } > "$cfg"
    chmod 600 "$cfg"
}

qemu_print_runtime_config() {
    local cfg
    cfg=$(qemu_runtime_config_file)
    qemu_load_runtime_config
    printf 'config_file=%s\n' "$cfg"
    printf 'QEMU_ACCEL=%s\n' "$QEMU_ACCEL"
    printf 'QEMU_CPU_MODEL=%s\n' "$QEMU_CPU_MODEL"
    printf 'QEMU_CPUS=%s\n' "$QEMU_CPUS"
    printf 'QEMU_MEMORY_MB=%s\n' "$QEMU_MEMORY_MB"
    printf 'QEMU_NET_DEVICE=%s\n' "$QEMU_NET_DEVICE"
    printf 'QEMU_DISK_IF=%s\n' "$QEMU_DISK_IF"
    printf 'QEMU_DISK_CACHE=%s\n' "$QEMU_DISK_CACHE"
    printf 'QEMU_DISK_DISCARD=%s\n' "$QEMU_DISK_DISCARD"
    printf 'QEMU_VIDEO_DEVICE=%s\n' "$QEMU_VIDEO_DEVICE"
    printf 'QEMU_FULLSCREEN=%s\n' "$QEMU_FULLSCREEN"
}

qemu_cmd_config() {
    local action="${1:-show}"
    shift || true

    case "$action" in
        show|list)
            qemu_print_runtime_config
            ;;
        path)
            printf '%s\n' "$(qemu_runtime_config_file)"
            ;;
        reset)
            qemu_set_runtime_defaults
            qemu_save_runtime_config
            ea11_backend_info "Configuracao resetada para defaults em $(qemu_runtime_config_file)"
            ;;
        *)
            ea11_backend_die "Acao de config desconhecida: $action"
            ;;
    esac
}

qemu_cmd_optimize() {
    local cfg backup_file
    cfg=$(qemu_runtime_config_file)

    if [[ -f "$cfg" ]]; then
        backup_file=$(qemu_runtime_config_backup_file)
        cp "$cfg" "$backup_file"
        ea11_backend_info "Backup da configuracao atual: $backup_file"
    fi

    qemu_load_runtime_config

    # Recomendacoes base de performance/latencia por host.
    case "$(uname -s)" in
        Darwin*)
            QEMU_ACCEL='hvf'
            QEMU_CPU_MODEL='host'
            ;;
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            QEMU_ACCEL='whpx'
            QEMU_CPU_MODEL='qemu64'
            ;;
        *)
            QEMU_ACCEL='kvm'
            QEMU_CPU_MODEL='host'
            ;;
    esac

    QEMU_CPUS='4'
    QEMU_MEMORY_MB='4096'
    QEMU_NET_DEVICE='virtio-net-pci'
    QEMU_DISK_IF='virtio'
    QEMU_DISK_CACHE='writeback'
    QEMU_DISK_DISCARD='unmap'
    QEMU_VIDEO_DEVICE='virtio-vga'

    qemu_save_runtime_config
    ea11_backend_info "Configuracao otimizada aplicada em $cfg"
    ea11_backend_info 'Use: ea11ctl vm config show'
    ea11_backend_info 'Se houver regressao, restaure o backup ou execute: ea11ctl vm config reset'
}

qemu_default_share_mode() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows_NT)
            printf 'cifs\n'
            ;;
        *)
            printf 'ssh\n'
            ;;
    esac
}

qemu_load_share_config() {
    local share_file
    share_file=$(qemu_share_config_file)

    SHARE_MODE=$(qemu_default_share_mode)
    SHARE_HOST_USER="${USER:-hosthome}"
    SHARE_SSH_HOST='10.0.2.2'
    SHARE_SSH_PORT='22'
    SHARE_SSH_USER=''
    SHARE_SSH_PATH=''
    SHARE_SSH_PASSWORD=''
    SHARE_SMB_SERVER=''
    SHARE_SMB_SHARE=''
    SHARE_SMB_USER=''
    SHARE_SMB_PASSWORD=''

    if [[ -f "$share_file" ]]; then
        # shellcheck source=/dev/null
        source "$share_file"
    fi

    if [[ -z "${SHARE_SSH_USER:-}" ]]; then
        SHARE_SSH_USER="${USER:-}"
    fi

    if [[ -z "${SHARE_SSH_PATH:-}" ]]; then
        SHARE_SSH_PATH="${HOME:-}"
    fi
}

qemu_save_share_config() {
    local share_file
    share_file=$(qemu_share_config_file)

    {
        printf 'SHARE_MODE=%q\n' "$SHARE_MODE"
        printf 'SHARE_HOST_USER=%q\n' "$SHARE_HOST_USER"
        printf 'SHARE_SSH_HOST=%q\n' "$SHARE_SSH_HOST"
        printf 'SHARE_SSH_PORT=%q\n' "$SHARE_SSH_PORT"
        printf 'SHARE_SSH_USER=%q\n' "$SHARE_SSH_USER"
        printf 'SHARE_SSH_PATH=%q\n' "$SHARE_SSH_PATH"
        printf 'SHARE_SSH_PASSWORD=%q\n' "$SHARE_SSH_PASSWORD"
        printf 'SHARE_SMB_SERVER=%q\n' "$SHARE_SMB_SERVER"
        printf 'SHARE_SMB_SHARE=%q\n' "$SHARE_SMB_SHARE"
        printf 'SHARE_SMB_USER=%q\n' "$SHARE_SMB_USER"
        printf 'SHARE_SMB_PASSWORD=%q\n' "$SHARE_SMB_PASSWORD"
    } > "$share_file"
    chmod 600 "$share_file"
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
IMAGE_TAG=${IMAGE_TAG:-unknown}
EOF
}

qemu_resolve_accel_args() {
    case "${QEMU_ACCEL:-$(qemu_default_accel)}" in
        kvm)
            printf '%s\n' '-enable-kvm'
            ;;
        hvf|whpx|tcg)
            printf '%s\n' '-accel' "${QEMU_ACCEL}"
            ;;
        *)
            printf '%s\n' '-accel' "${QEMU_ACCEL}"
            ;;
    esac
}

qemu_resolve_cpu_args() {
    local cpu_model
    cpu_model="${QEMU_CPU_MODEL:-$(qemu_default_cpu_model)}"
    if [[ "$(uname -s)" == "Darwin" && "$cpu_model" == 'host' ]]; then
        printf '%s\n' '-cpu' 'host,-svm'
        return 0
    fi
    printf '%s\n' '-cpu' "$cpu_model"
}

qemu_apply_macos_desktop_args() {
    local -n _cmd_ref=$1
    local fullscreen_mode

    if [[ "$(uname -s)" != "Darwin" ]]; then
        return 0
    fi

    # Alinha defaults com scripts/run-qemu-macos para janela legivel no boot.
    fullscreen_mode="${QEMU_FULLSCREEN:-on}"

    _cmd_ref+=(
        -device "${QEMU_VIDEO_DEVICE:-virtio-vga}"
        -display "cocoa,zoom-to-fit=on,full-screen=${fullscreen_mode}"
        -k en-us
        -audiodev coreaudio,id=audio0,out.frequency=44100,out.mixing-engine=on,in.mixing-engine=off
        -device virtio-sound-pci,audiodev=audio0
    )
}

qemu_runtime_memory_mb() {
    if [[ -n "${QEMU_MEMORY_MB:-}" ]]; then
        printf '%s\n' "$QEMU_MEMORY_MB"
        return 0
    fi
    printf '4096\n'
}

qemu_runtime_cpus() {
    if [[ -n "${QEMU_CPUS:-}" ]]; then
        printf '%s\n' "$QEMU_CPUS"
        return 0
    fi
    printf '4\n'
}

qemu_net_device_name() {
    printf '%s\n' "${QEMU_NET_DEVICE:-virtio-net-pci}"
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

qemu_guest_release_version() {
    local ssh_port="$1"
    local ssh_user="$2"

    ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile="${HOME}/.ssh/known_hosts" \
        -p "$ssh_port" \
        "$ssh_user@localhost" \
        "cat /etc/emacs-a11y-release 2>/dev/null || cat /etc/motd 2>/dev/null | head -n 1" 2>/dev/null | tr -d '[:space:]'
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
    qemu_load_runtime_config
    mem_mb=$(qemu_runtime_memory_mb)
    cpu_count=$(qemu_runtime_cpus)
    net_device=$(qemu_net_device_name)
    qemu_load_share_config

    if [[ "$SHARE_MODE" == 'ssh' ]] && [[ -z "$SHARE_SSH_USER" || -z "$SHARE_SSH_PATH" ]]; then
        ea11_backend_warn 'Compartilhamento ssh sem --ssh-user/--ssh-path definidos; guest pode nao montar automaticamente.'
    fi
    if [[ "$SHARE_MODE" == 'cifs' ]] && [[ -z "$SHARE_SMB_SERVER" || -z "$SHARE_SMB_SHARE" ]]; then
        ea11_backend_warn 'Compartilhamento cifs sem --smb-server/--smb-share definidos; guest usara fallback SMB do QEMU se disponivel.'
    fi

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
        -drive "file=${system_image},format=qcow2,if=${QEMU_DISK_IF},cache=${QEMU_DISK_CACHE},discard=${QEMU_DISK_DISCARD}"
        -drive "file=${data_disk},format=qcow2,if=${QEMU_DISK_IF},cache=${QEMU_DISK_CACHE},discard=${QEMU_DISK_DISCARD}"
        -netdev "user,id=net0,hostfwd=tcp::${ssh_port}-:22"
        -device "${net_device},netdev=net0"
        -fw_cfg "name=opt/ea11/share_mode,string=${SHARE_MODE}"
        -fw_cfg "name=opt/ea11/host_user,string=${SHARE_HOST_USER}"
    )

    if [[ "$SHARE_MODE" == 'ssh' ]]; then
        qemu_cmd+=(
            -fw_cfg "name=opt/ea11/ssh_host,string=${SHARE_SSH_HOST}"
            -fw_cfg "name=opt/ea11/ssh_port,string=${SHARE_SSH_PORT}"
            -fw_cfg "name=opt/ea11/ssh_user,string=${SHARE_SSH_USER}"
            -fw_cfg "name=opt/ea11/ssh_path,string=${SHARE_SSH_PATH}"
        )
        if [[ -n "${SHARE_SSH_PASSWORD:-}" ]]; then
            qemu_cmd+=(-fw_cfg "name=opt/ea11/ssh_password,string=${SHARE_SSH_PASSWORD}")
        fi
    fi

    if [[ "$SHARE_MODE" == 'cifs' ]]; then
        qemu_cmd+=(
            -fw_cfg "name=opt/ea11/smb_server,string=${SHARE_SMB_SERVER}"
            -fw_cfg "name=opt/ea11/smb_share,string=${SHARE_SMB_SHARE}"
            -fw_cfg "name=opt/ea11/smb_user,string=${SHARE_SMB_USER}"
        )
        if [[ -n "${SHARE_SMB_PASSWORD:-}" ]]; then
            qemu_cmd+=(-fw_cfg "name=opt/ea11/smb_password,string=${SHARE_SMB_PASSWORD}")
        fi
    fi

    if [[ $headless -eq 1 ]]; then
        qemu_cmd+=(-nographic -serial mon:stdio)
    else
        if [[ "$(uname -s)" == 'Darwin' ]]; then
            qemu_apply_macos_desktop_args qemu_cmd
        else
            case "$(uname -s)" in
                MINGW*|MSYS*|CYGWIN*|Windows_NT)
                    qemu_cmd+=(-device "${QEMU_VIDEO_DEVICE:-virtio-vga}" -display sdl -full-screen)
                    ;;
                *)
                    qemu_cmd+=(-device "${QEMU_VIDEO_DEVICE:-virtio-vga}")
                    ;;
            esac
        fi
    fi

    nohup "${qemu_cmd[@]}" > "$log_file" 2>&1 < /dev/null &
    local qemu_pid=$!
    sleep 3

    # Em alguns macOS/QEMU, HVF aborta no boot; faz fallback automatico para TCG.
    if ! qemu_is_running "$qemu_pid"; then
        if [[ "$(uname -s)" == "Darwin" ]] && printf '%s\n' "${accel_args[*]}" | grep -q 'hvf'; then
            ea11_backend_warn 'Falha no acelerador HVF detectada, tentando fallback com TCG.'
            accel_args=(-accel tcg)
            cpu_args=(-cpu qemu64)
            qemu_cmd=(
                qemu-system-x86_64
                "${accel_args[@]}"
                "${cpu_args[@]}"
                -m "$mem_mb"
                -smp "$cpu_count"
                -drive "file=${system_image},format=qcow2,if=${QEMU_DISK_IF},cache=${QEMU_DISK_CACHE},discard=${QEMU_DISK_DISCARD}"
                -drive "file=${data_disk},format=qcow2,if=${QEMU_DISK_IF},cache=${QEMU_DISK_CACHE},discard=${QEMU_DISK_DISCARD}"
                -netdev "user,id=net0,hostfwd=tcp::${ssh_port}-:22"
                -device "${net_device},netdev=net0"
                -fw_cfg "name=opt/ea11/share_mode,string=${SHARE_MODE}"
                -fw_cfg "name=opt/ea11/host_user,string=${SHARE_HOST_USER}"
            )

            if [[ "$SHARE_MODE" == 'ssh' ]]; then
                qemu_cmd+=(
                    -fw_cfg "name=opt/ea11/ssh_host,string=${SHARE_SSH_HOST}"
                    -fw_cfg "name=opt/ea11/ssh_port,string=${SHARE_SSH_PORT}"
                    -fw_cfg "name=opt/ea11/ssh_user,string=${SHARE_SSH_USER}"
                    -fw_cfg "name=opt/ea11/ssh_path,string=${SHARE_SSH_PATH}"
                )
                if [[ -n "${SHARE_SSH_PASSWORD:-}" ]]; then
                    qemu_cmd+=(-fw_cfg "name=opt/ea11/ssh_password,string=${SHARE_SSH_PASSWORD}")
                fi
            fi

            if [[ "$SHARE_MODE" == 'cifs' ]]; then
                qemu_cmd+=(
                    -fw_cfg "name=opt/ea11/smb_server,string=${SHARE_SMB_SERVER}"
                    -fw_cfg "name=opt/ea11/smb_share,string=${SHARE_SMB_SHARE}"
                    -fw_cfg "name=opt/ea11/smb_user,string=${SHARE_SMB_USER}"
                )
                if [[ -n "${SHARE_SMB_PASSWORD:-}" ]]; then
                    qemu_cmd+=(-fw_cfg "name=opt/ea11/smb_password,string=${SHARE_SMB_PASSWORD}")
                fi
            fi

            if [[ $headless -eq 1 ]]; then
                qemu_cmd+=(-nographic -serial mon:stdio)
            else
                if [[ "$(uname -s)" == 'Darwin' ]]; then
                    qemu_apply_macos_desktop_args qemu_cmd
                else
                    case "$(uname -s)" in
                        MINGW*|MSYS*|CYGWIN*|Windows_NT)
                            qemu_cmd+=(-device "${QEMU_VIDEO_DEVICE:-virtio-vga}" -display sdl -full-screen)
                            ;;
                        *)
                            qemu_cmd+=(-device "${QEMU_VIDEO_DEVICE:-virtio-vga}")
                            ;;
                    esac
                fi
            fi

            nohup "${qemu_cmd[@]}" > "$log_file" 2>&1 < /dev/null &
            qemu_pid=$!
            sleep 3
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
    ea11_backend_info "Compartilhamento do host: modo=${SHARE_MODE}"
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
    local owner repo tag base_url resolved_tag force_download vm_name ssh_port data_disk log_file
    local downloaded image_tag latest_tag
    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    tag=$(ea11_backend_release_tag "$@")
    base_url=$(ea11_backend_release_base_url "$@")
    resolved_tag=$(ea11_backend_resolve_release_tag "$owner" "$repo" "$tag")
    vm_name=$(qemu_parse_vm_name "$@")
    ssh_port=$(qemu_parse_ssh_port "$@")
    data_disk="${EA11_HOME}/${vm_name}-home.qcow2"
    log_file=$(qemu_log_file "$vm_name")
    force_download=0
    downloaded=0
    if ea11_backend_download_force "$@"; then
        force_download=1
    fi

    ea11_backend_require_command qemu-img

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE IMAGE_TAG
    qemu_load_state "$vm_name"

    if [[ -f "$EA11_DEFAULT_SYSTEM_IMAGE" && $force_download -eq 0 ]]; then
        ea11_backend_info "Imagem QEMU ja existe em $EA11_DEFAULT_SYSTEM_IMAGE"
        image_tag="${IMAGE_TAG:-unknown}"
    else
        ea11_backend_download_release_asset \
            "$owner" \
            "$repo" \
            "$tag" \
            "$EA11_DEFAULT_RELEASE_ASSET" \
            "$EA11_DEFAULT_SYSTEM_IMAGE" \
            "$base_url"
        downloaded=1
        image_tag="$resolved_tag"
    fi

    qemu-img info "$EA11_DEFAULT_SYSTEM_IMAGE" >/dev/null

    if [[ $downloaded -eq 0 ]]; then
        latest_tag=$(ea11_backend_resolve_release_tag "$owner" "$repo" latest)
        if [[ "$image_tag" != "unknown" && "$latest_tag" != "latest" && "$image_tag" != "$latest_tag" ]]; then
            ea11_backend_warn "Existe imagem mais nova: $latest_tag (local: $image_tag). Use --force-download para atualizar."
        fi
    fi

    VM_NAME="$vm_name"
    QEMU_PID=''
    SSH_PORT="$ssh_port"
    SYSTEM_IMAGE="$EA11_DEFAULT_SYSTEM_IMAGE"
    DATA_DISK="$data_disk"
    LOG_FILE="$log_file"
    STATE='stopped'
    IMAGE_TAG="$image_tag"
    qemu_save_state "$vm_name"

    if [[ ! -f "$data_disk" ]]; then
        ea11_backend_info "Criando disco de home em $data_disk"
        qemu-img create -f qcow2 "$data_disk" 20G >/dev/null
    fi

    ea11_backend_info "Imagem QEMU pronta em $EA11_DEFAULT_SYSTEM_IMAGE"
    ea11_backend_info "VM QEMU '$vm_name' registrada (state=stopped, tag=${image_tag})."
    ea11_backend_info "Use: ea11ctl vm start"
}

qemu_cmd_share() {
    local action="${1:-list}"
    shift || true

    qemu_load_share_config

    case "$action" in
        list)
            printf 'mode=%s\n' "$SHARE_MODE"
            printf 'host_user=%s\n' "$SHARE_HOST_USER"
            printf 'ssh_host=%s\n' "$SHARE_SSH_HOST"
            printf 'ssh_port=%s\n' "$SHARE_SSH_PORT"
            printf 'ssh_user=%s\n' "$SHARE_SSH_USER"
            printf 'ssh_path=%s\n' "$SHARE_SSH_PATH"
            printf 'smb_server=%s\n' "$SHARE_SMB_SERVER"
            printf 'smb_share=%s\n' "$SHARE_SMB_SHARE"
            printf 'smb_user=%s\n' "$SHARE_SMB_USER"
            ;;
        set)
            SHARE_MODE=$(ea11_backend_option_value --mode '' "$@" || printf '%s\n' "$SHARE_MODE")
            SHARE_HOST_USER=$(ea11_backend_option_value --host-user '' "$@" || printf '%s\n' "$SHARE_HOST_USER")
            SHARE_SSH_HOST=$(ea11_backend_option_value --ssh-host '' "$@" || printf '%s\n' "$SHARE_SSH_HOST")
            SHARE_SSH_PORT=$(ea11_backend_option_value --ssh-port '' "$@" || printf '%s\n' "$SHARE_SSH_PORT")
            SHARE_SSH_USER=$(ea11_backend_option_value --ssh-user '' "$@" || printf '%s\n' "$SHARE_SSH_USER")
            SHARE_SSH_PATH=$(ea11_backend_option_value --ssh-path '' "$@" || printf '%s\n' "$SHARE_SSH_PATH")
            SHARE_SSH_PASSWORD=$(ea11_backend_option_value --ssh-password '' "$@" || printf '%s\n' "$SHARE_SSH_PASSWORD")
            SHARE_SMB_SERVER=$(ea11_backend_option_value --smb-server '' "$@" || printf '%s\n' "$SHARE_SMB_SERVER")
            SHARE_SMB_SHARE=$(ea11_backend_option_value --smb-share '' "$@" || printf '%s\n' "$SHARE_SMB_SHARE")
            SHARE_SMB_USER=$(ea11_backend_option_value --smb-user '' "$@" || printf '%s\n' "$SHARE_SMB_USER")
            SHARE_SMB_PASSWORD=$(ea11_backend_option_value --smb-password '' "$@" || printf '%s\n' "$SHARE_SMB_PASSWORD")

            case "$SHARE_MODE" in
                ssh|cifs)
                    ;;
                *)
                    ea11_backend_die "Modo de compartilhamento invalido: $SHARE_MODE (use ssh ou cifs)"
                    ;;
            esac

            qemu_save_share_config
            ea11_backend_info "Configuracao de compartilhamento salva em $(qemu_share_config_file)"
            ;;
        clear)
            rm -f "$(qemu_share_config_file)"
            ea11_backend_info 'Configuracao de compartilhamento removida.'
            ;;
        *)
            ea11_backend_die "Acao de share desconhecida: $action"
            ;;
    esac
}

qemu_cmd_version() {
    local vm_name owner repo latest_tag local_tag ssh_user guest_tag
    vm_name=$(qemu_parse_vm_name "$@")
    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    ssh_user=$(qemu_parse_ssh_user "$@")

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE IMAGE_TAG
    qemu_load_state "$vm_name"
    latest_tag=$(ea11_backend_resolve_release_tag "$owner" "$repo" latest)
    local_tag="${IMAGE_TAG:-unknown}"

    if qemu_is_running "${QEMU_PID:-}"; then
        guest_tag=$(qemu_guest_release_version "${SSH_PORT:-$EA11_DEFAULT_SSH_PORT}" "$ssh_user" || true)
        if [[ -n "$guest_tag" ]]; then
            local_tag="$guest_tag"
        fi
    fi

    printf 'backend=qemu\nvm=%s\nlocal_tag=%s\nlatest_tag=%s\n' "$vm_name" "$local_tag" "$latest_tag"
}

qemu_cmd_check_update() {
    local vm_name owner repo latest_tag local_tag ssh_user guest_tag
    vm_name=$(qemu_parse_vm_name "$@")
    owner=$(ea11_backend_release_owner "$@")
    repo=$(ea11_backend_release_repo "$@")
    ssh_user=$(qemu_parse_ssh_user "$@")

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE IMAGE_TAG
    qemu_load_state "$vm_name"
    latest_tag=$(ea11_backend_resolve_release_tag "$owner" "$repo" latest)
    local_tag="${IMAGE_TAG:-unknown}"

    if qemu_is_running "${QEMU_PID:-}"; then
        guest_tag=$(qemu_guest_release_version "${SSH_PORT:-$EA11_DEFAULT_SSH_PORT}" "$ssh_user" || true)
        if [[ -n "$guest_tag" ]]; then
            local_tag="$guest_tag"
        fi
    fi

    printf 'backend=qemu\nvm=%s\nlocal_tag=%s\nlatest_tag=%s\n' "$vm_name" "$local_tag" "$latest_tag"

    if [[ "$local_tag" == "unknown" ]]; then
        printf 'update_status=unknown-local\n'
        ea11_backend_warn 'Tag local da imagem nao registrada.'
        ea11_backend_info 'Atualize para registrar a tag local: ea11ctl vm install --force-download'
        return 0
    fi

    if [[ "$latest_tag" == "latest" ]]; then
        printf 'update_status=unknown-remote\n'
        ea11_backend_warn 'Nao foi possivel consultar a release mais nova no GitHub agora.'
        return 0
    fi

    if [[ "$local_tag" == "$latest_tag" ]]; then
        printf 'update_status=up-to-date\n'
        ea11_backend_info "VM QEMU ja esta na versao mais recente ($local_tag)."
    else
        printf 'update_status=update-available\n'
        ea11_backend_warn "Nova release disponivel: $latest_tag (local: $local_tag)."
        ea11_backend_info 'Atualize com: ea11ctl vm install --force-download'
    fi
}

qemu_cmd_remove() {
    local vm_name remove_data remove_system remove_all force yes
    local state_file system_image data_disk log_file
    vm_name=$(qemu_parse_vm_name "$@")
    remove_data=0
    remove_system=0
    remove_all=0
    force=0
    yes=0

    if ea11_backend_has_flag --data "$@"; then
        remove_data=1
    fi
    if ea11_backend_has_flag --system "$@"; then
        remove_system=1
    fi
    if ea11_backend_has_flag --all "$@"; then
        remove_all=1
        remove_data=1
        remove_system=1
    fi
    if ea11_backend_has_flag --force "$@" || ea11_backend_has_flag -f "$@"; then
        force=1
    fi
    if ea11_backend_has_flag --yes "$@" || ea11_backend_has_flag -y "$@"; then
        yes=1
    fi

    unset VM_NAME QEMU_PID SSH_PORT SYSTEM_IMAGE DATA_DISK LOG_FILE STATE IMAGE_TAG
    qemu_load_state "$vm_name"

    state_file=$(qemu_state_file "$vm_name")
    system_image="${SYSTEM_IMAGE:-$EA11_DEFAULT_SYSTEM_IMAGE}"
    data_disk="${DATA_DISK:-$EA11_HOME/${vm_name}-home.qcow2}"
    log_file="${LOG_FILE:-$(qemu_log_file "$vm_name")}" 

    if qemu_is_running "${QEMU_PID:-}"; then
        if [[ $force -eq 1 ]]; then
            kill -KILL "$QEMU_PID" 2>/dev/null || true
            ea11_backend_warn "VM '$vm_name' estava em execucao e foi encerrada com --force."
        else
            ea11_backend_die "VM '$vm_name' esta em execucao. Pare com 'ea11ctl vm stop --name $vm_name' ou use --force."
        fi
    fi

    if [[ $yes -eq 0 ]]; then
        ea11_backend_warn "Isso removera o registro da VM '$vm_name'."
        if [[ $remove_data -eq 1 ]]; then
            ea11_backend_warn "Tambem removera disco de dados: $data_disk"
        fi
        if [[ $remove_system -eq 1 ]]; then
            ea11_backend_warn "Tambem removera imagem de sistema: $system_image"
        fi
        printf 'Digite "yes" para confirmar: '
        local reply
        read -r reply
        if [[ "$reply" != 'yes' ]]; then
            ea11_backend_info 'Remocao cancelada.'
            return 0
        fi
    fi

    rm -f "$state_file" 2>/dev/null || true
    rm -f "$log_file" 2>/dev/null || true

    if [[ $remove_data -eq 1 ]]; then
        rm -f "$data_disk" 2>/dev/null || true
    fi

    if [[ $remove_system -eq 1 ]]; then
        rm -f "$system_image" 2>/dev/null || true
    fi

    ea11_backend_info "VM '$vm_name' removida (registro/local state)."
    if [[ $remove_data -eq 1 ]]; then
        ea11_backend_info 'Disco de dados removido.'
    fi
    if [[ $remove_system -eq 1 ]]; then
        ea11_backend_info 'Imagem de sistema removida.'
    fi
    if [[ $remove_all -eq 1 ]]; then
        ea11_backend_info 'Remocao completa concluida (--all).'
    fi
}

main() {
    local command="${1:-}"
    shift || true

    case "$command" in
        install) qemu_cmd_install "$@" ;;
        config) qemu_cmd_config "$@" ;;
        optimize) qemu_cmd_optimize "$@" ;;
        version) qemu_cmd_version "$@" ;;
        check-update) qemu_cmd_check_update "$@" ;;
        share) qemu_cmd_share "$@" ;;
        list) qemu_cmd_list "$@" ;;
        start) qemu_cmd_start "$@" ;;
        stop|close) qemu_cmd_stop "$@" ;;
        remove) qemu_cmd_remove "$@" ;;
        status) qemu_cmd_status "$@" ;;
        ssh) qemu_cmd_ssh "$@" ;;
        diagnose) qemu_cmd_diagnose "$@" ;;
        *) ea11_backend_die "Comando QEMU desconhecido: $command" ;;
    esac
}

main "$@"