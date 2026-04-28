#!/bin/bash
# Script para configurar montagem manual de VirtualBox Shared Folders
# Normalmente não é necessário executar este script — o serviço systemd
# mount-shared-folder.service faz a montagem automaticamente no boot.
#
# Use este script apenas para diagnóstico ou montagem manual.
#
# Uso:
#   sudo /usr/local/sbin/setup-shared-folder.sh <nome-da-share>
#
# Exemplo (usuário Windows "joao"):
#   sudo /usr/local/sbin/setup-shared-folder.sh joao
#   -> Monta a share "joao" em /home/joao

set -euo pipefail

USERNAME="a11ydevs"
USER_UID=1000
USER_GID=1000

# --- Parâmetros --------------------------------------------------------------

if [[ $# -lt 1 ]]; then
    echo "Uso: $0 <nome-da-share>"
    echo ""
    echo "Shares configuradas no VirtualBox:"
    VBoxControl --nologo sharedfolder list 2>/dev/null || echo "  (VBoxControl nao disponivel)"
    exit 1
fi

SHARED_FOLDER_NAME="$1"
MOUNT_POINT="/home/$SHARED_FOLDER_NAME"

# --- Verificações ------------------------------------------------------------

if ! lsmod | grep -q vboxguest; then
    echo "Guest Additions nao esta carregado. Execute install-guest-additions.sh primeiro."
    exit 1
fi

if ! lsmod | grep -q vboxsf; then
    modprobe vboxsf || { echo "Falha ao carregar modulo vboxsf"; exit 1; }
fi

# --- Adicionar usuário ao grupo vboxsf ---------------------------------------

if ! groups "$USERNAME" | grep -q vboxsf; then
    echo "Adicionando $USERNAME ao grupo vboxsf..."
    sudo usermod -aG vboxsf "$USERNAME"
fi

# --- Criar ponto de montagem -------------------------------------------------

if [[ ! -d "$MOUNT_POINT" ]]; then
    echo "Criando ponto de montagem: $MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT"
    sudo chown "$USER_UID:$USER_GID" "$MOUNT_POINT"
fi

# --- Montar ------------------------------------------------------------------

echo "Montando share '$SHARED_FOLDER_NAME' em $MOUNT_POINT..."
if sudo mount -t vboxsf -o "uid=$USER_UID,gid=$USER_GID" "$SHARED_FOLDER_NAME" "$MOUNT_POINT"; then
    echo "Share montada com sucesso em $MOUNT_POINT"
else
    echo "AVISO: Nao foi possivel montar (share pode nao estar configurada no host)"
    echo "Configure no host com:"
    echo "  VBoxManage sharedfolder add <VM> --name $SHARED_FOLDER_NAME --hostpath <pasta-host> --automount --automount-point $MOUNT_POINT"
    exit 1
fi
