#!/bin/bash
# Script para montar automaticamente VirtualBox Shared Folders
# Executado pelo systemd no boot se Guest Additions estiver instalado

set -euo pipefail

SHARED_FOLDER_NAME="host-home"
MOUNT_POINT="/home/shared"
USERNAME="a11ydevs"
USER_UID=1000
USER_GID=1000

# Verificar se vboxsf está disponível (Guest Additions instalado)
if ! modinfo vboxsf &>/dev/null; then
    # Guest Additions não instalado, sair silenciosamente
    exit 0
fi

# Verificar se módulo vboxsf está carregado
if ! lsmod | grep -q vboxsf; then
    # Tentar carregar módulo
    modprobe vboxsf 2>/dev/null || {
        # Se falhar, não é erro - VM pode não estar no VirtualBox
        exit 0
    }
fi

# Verificar se shared folder existe
if ! VBoxControl --nologo sharedfolder list 2>/dev/null | grep -q "$SHARED_FOLDER_NAME"; then
    # Shared folder não configurado, sair silenciosamente (não é erro)
    exit 0
fi

echo "Shared folder '$SHARED_FOLDER_NAME' detectado, configurando montagem..."

# Criar ponto de montagem se não existe
if [[ ! -d "$MOUNT_POINT" ]]; then
    mkdir -p "$MOUNT_POINT"
    chown "$USER_UID:$USER_GID" "$MOUNT_POINT"
fi

# Verificar se já está montado
if mountpoint -q "$MOUNT_POINT"; then
    echo "Shared folder já está montado em $MOUNT_POINT"
    exit 0
fi

# Montar shared folder
if mount -t vboxsf -o uid="$USER_UID",gid="$USER_GID" "$SHARED_FOLDER_NAME" "$MOUNT_POINT"; then
    echo "Shared folder montado com sucesso em $MOUNT_POINT"
    ls -ld "$MOUNT_POINT"
else
    echo "AVISO: Não foi possível montar shared folder (pode não estar disponível)"
    exit 0
fi
