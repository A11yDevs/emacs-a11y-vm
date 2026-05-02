#!/bin/bash
# Script para montar automaticamente pastas compartilhadas de host
# Suporta:
# - VirtualBox Shared Folders (vboxsf)
# - QEMU 9p/virtfs com tag hosthome_<usuario>
# - QEMU usernet SMB fallback (//10.0.2.4/qemu -> /home/hosthome)
#
# Executado pelo systemd no boot.
#
# Para cada shared folder configurada no VirtualBox (VBoxControl sharedfolder list),
# monta em /home/<nome-da-share> com uid/gid do usuario a11ydevs.
# Isso permite que a pasta pessoal do Windows apareça em /home/<usuario-windows>.

set -uo pipefail

USER_UID=1000
USER_GID=1000

echo "=== mount-shared-folder.sh iniciado ==="
echo "Data: $(date)"

# --- Montagem QEMU 9p/virtfs ------------------------------------------------

mount_qemu_9p() {
    local mounted=0
    local failed=0

    # Carregar modulos 9p, se disponiveis
    modprobe 9pnet_virtio 2>/dev/null || true
    modprobe 9pnet 2>/dev/null || true
    modprobe 9p 2>/dev/null || true

    mapfile -t qemu_tags < <(
        find /sys -type f -name mount_tag 2>/dev/null \
            | while read -r tag_file; do
                cat "$tag_file" 2>/dev/null || true
              done \
            | sort -u
    )

    for tag in "${qemu_tags[@]}"; do
        [[ -z "$tag" ]] && continue

        if [[ "$tag" =~ ^hosthome_(.+)$ ]]; then
            host_user="${BASH_REMATCH[1]}"
            mount_point="/home/$host_user"

            if [[ ! -d "$mount_point" ]]; then
                mkdir -p "$mount_point"
                chown "$USER_UID:$USER_GID" "$mount_point"
            fi

            if mountpoint -q "$mount_point"; then
                echo "QEMU 9p tag '$tag' ja montada em $mount_point"
                continue
            fi

            if mount -t 9p -o trans=virtio,version=9p2000.L,msize=262144,cache=mmap "$tag" "$mount_point"; then
                echo "QEMU 9p tag '$tag' montada em $mount_point"
                chown "$USER_UID:$USER_GID" "$mount_point" 2>/dev/null || true
                (( mounted++ )) || true
            else
                echo "AVISO: Nao foi possivel montar QEMU 9p tag '$tag' em $mount_point"
                (( failed++ )) || true
            fi
        fi
    done

    echo "QEMU 9p: $mounted montagem(ns), $failed falha(s)"
}

mount_qemu_smb_fallback() {
    local smb_server="10.0.2.4"
    local smb_share="qemu"
    local mount_point="/home/hosthome"
    local mounted=0

    if ! command -v mount.cifs &>/dev/null; then
        echo "AVISO: mount.cifs nao encontrado (instale cifs-utils para SMB fallback no QEMU)"
        return
    fi

    if mountpoint -q "$mount_point"; then
        echo "QEMU SMB fallback ja montado em $mount_point"
        return
    fi

    mkdir -p "$mount_point"
    chown "$USER_UID:$USER_GID" "$mount_point" 2>/dev/null || true

    # Alguns ambientes aceitam SMB moderno; outros so montam com versao antiga.
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
    fi
}

# --- Montagem VirtualBox Shared Folders -------------------------------------

mount_virtualbox_shares() {
    # --- Verificações de pré-requisito ---------------------------------------

# Guest Additions disponível?
    if ! modinfo vboxsf &>/dev/null; then
        echo "AVISO: módulo vboxsf não encontrado (Guest Additions não instalado?)"
        return
    fi
    echo "OK: módulo vboxsf disponível"

# Carregar módulo vboxsf se necessário
    if ! lsmod | grep -q vboxsf; then
        echo "Carregando módulo vboxsf..."
        modprobe vboxsf 2>/dev/null || {
            echo "AVISO: falha ao carregar módulo vboxsf"
            return
        }
    fi
    echo "OK: módulo vboxsf carregado"

# VBoxControl acessível?
    if ! command -v VBoxControl &>/dev/null; then
        echo "AVISO: VBoxControl não encontrado no PATH"
        return
    fi
    echo "OK: VBoxControl encontrado em $(command -v VBoxControl)"

# --- Descobrir shares configuradas -------------------------------------------
# Formato da saída de VBoxControl sharedfolder list (VirtualBox 6+):
#   No.  Name        Host Path        Access  AutoMount  AutoMountPoint
#   ---  ----        ---------        ------  ---------  --------------
#     1  joao        C:\Users\joao    rw      y          /home/joao
#
# Extrai a coluna "Name" (campo 2, linhas de dados após o cabeçalho).
# Usa método robusto: pula linhas que começam com "No." ou "---" ou são vazias.

    mapfile -t SHARE_NAMES < <(
        VBoxControl sharedfolder list 2>/dev/null \
            | awk '$1 ~ /^[0-9]+$/ && NF>=3 { print $3 }'
    )

# Debug: mostrar o que foi encontrado
    echo "VBoxControl encontrou ${#SHARE_NAMES[@]} share(s)"
    for share_name in "${SHARE_NAMES[@]}"; do
        echo "  - $share_name"
    done

    if [[ ${#SHARE_NAMES[@]} -eq 0 ]]; then
        # Nenhuma shared folder configurada — sair silenciosamente
        return
    fi

# --- Montar cada share -------------------------------------------------------

    mounted=0
    failed=0

    for share_name in "${SHARE_NAMES[@]}"; do
        [[ -z "$share_name" ]] && continue

        mount_point="/home/$share_name"

    # Criar ponto de montagem se não existe
        if [[ ! -d "$mount_point" ]]; then
            mkdir -p "$mount_point"
            chown "$USER_UID:$USER_GID" "$mount_point"
        fi

    # Pular se já montado
        if mountpoint -q "$mount_point"; then
            echo "Shared folder '$share_name' ja montado em $mount_point"
            continue
        fi

    # Montar
        if mount -t vboxsf -o "uid=$USER_UID,gid=$USER_GID" "$share_name" "$mount_point"; then
            echo "Shared folder '$share_name' montado em $mount_point"
            (( mounted++ )) || true
        else
            echo "AVISO: Nao foi possivel montar '$share_name' em $mount_point"
            (( failed++ )) || true
        fi
    done

    echo "VirtualBox shares: $mounted montagem(ns), $failed falha(s)"
}

mount_qemu_9p
mount_qemu_smb_fallback
mount_virtualbox_shares
