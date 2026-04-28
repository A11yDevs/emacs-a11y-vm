#!/bin/bash
# Script para configurar montagem automática de pasta compartilhada VirtualBox
# Executa após instalação do Guest Additions

set -euo pipefail

SHARED_FOLDER_NAME="host-home"
MOUNT_POINT="/home/shared"
USERNAME="a11ydevs"

# Verificar se Guest Additions está instalado
if ! lsmod | grep -q vboxguest; then
    echo "Guest Additions não está carregado. Execute install-guest-additions.sh primeiro."
    exit 1
fi

# Adicionar usuário ao grupo vboxsf (necessário para acessar pastas compartilhadas)
if ! groups "$USERNAME" | grep -q vboxsf; then
    echo "Adicionando $USERNAME ao grupo vboxsf..."
    sudo usermod -aG vboxsf "$USERNAME"
    echo "Usuário adicionado ao grupo vboxsf"
fi

# Criar ponto de montagem
if [[ ! -d "$MOUNT_POINT" ]]; then
    echo "Criando ponto de montagem: $MOUNT_POINT"
    sudo mkdir -p "$MOUNT_POINT"
    sudo chown "$USERNAME:$USERNAME" "$MOUNT_POINT"
fi

# Adicionar entrada ao /etc/fstab para montagem automática
FSTAB_ENTRY="$SHARED_FOLDER_NAME $MOUNT_POINT vboxsf defaults,uid=$(id -u $USERNAME),gid=$(id -g $USERNAME) 0 0"

if ! grep -q "$SHARED_FOLDER_NAME" /etc/fstab; then
    echo "Adicionando entrada ao /etc/fstab..."
    echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
    echo "Entrada adicionada ao /etc/fstab"
fi

# Tentar montar agora
echo "Tentando montar pasta compartilhada..."
if sudo mount -t vboxsf -o uid=$(id -u $USERNAME),gid=$(id -g $USERNAME) "$SHARED_FOLDER_NAME" "$MOUNT_POINT" 2>/dev/null; then
    echo "Pasta compartilhada montada com sucesso em $MOUNT_POINT"
else
    echo "AVISO: Não foi possível montar agora (pasta compartilhada pode não estar configurada)"
    echo "Configure a pasta compartilhada no VirtualBox com nome: $SHARED_FOLDER_NAME"
fi

echo ""
echo "Configuração completa!"
echo "- Pasta compartilhada será montada automaticamente em: $MOUNT_POINT"
echo "- Usuário $USERNAME tem permissões de leitura/escrita"
echo ""
echo "Para configurar no VirtualBox:"
echo "  VBoxManage sharedfolder add $VM_NAME --name $SHARED_FOLDER_NAME --hostpath /Users/\$USER --automount"
