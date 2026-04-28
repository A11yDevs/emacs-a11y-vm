#!/bin/bash
# Script para instalar VirtualBox Guest Additions
# Executa no primeiro boot se detectar VirtualBox e Guest Additions não instalado

set -euo pipefail

VBOX_VERSION="7.0.20"  # Versão padrão se não conseguir detectar
GA_ISO="/tmp/VBoxGuestAdditions.iso"
MOUNT_POINT="/mnt/vbox-ga"
FLAG_FILE="/home/.guest-additions-installed"

# Verificar se já foi instalado
if [[ -f "$FLAG_FILE" ]]; then
    echo "Guest Additions já instalado anteriormente"
    exit 0
fi

# Verificar se está rodando no VirtualBox
if ! lspci | grep -qi virtualbox && ! dmidecode -s system-product-name 2>/dev/null | grep -qi virtualbox; then
    echo "Não está rodando no VirtualBox, pulando instalação do Guest Additions"
    exit 0
fi

# Verificar se Guest Additions já está carregado
if lsmod | grep -q vboxguest; then
    echo "Guest Additions já está carregado"
    touch "$FLAG_FILE"
    exit 0
fi

echo "=== Instalando VirtualBox Guest Additions ==="

# Detectar versão do VirtualBox (se possível)
DETECTED_VERSION=$(VBoxControl --version 2>/dev/null | cut -d'r' -f1 || echo "$VBOX_VERSION")
VBOX_VERSION="${DETECTED_VERSION:-$VBOX_VERSION}"

echo "Versão detectada do VirtualBox: $VBOX_VERSION"

# Baixar ISO do Guest Additions
echo "Baixando Guest Additions ISO..."
GA_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"

if ! curl -fL "$GA_URL" -o "$GA_ISO"; then
    echo "AVISO: Não foi possível baixar Guest Additions"
    echo "Você pode instalar manualmente via VirtualBox menu: Devices > Insert Guest Additions CD Image"
    exit 0
fi

# Montar ISO
echo "Montando ISO..."
mkdir -p "$MOUNT_POINT"
mount -o loop "$GA_ISO" "$MOUNT_POINT"

# Instalar
echo "Instalando Guest Additions..."
cd "$MOUNT_POINT"
./VBoxLinuxAdditions.run || {
    echo "AVISO: Instalação retornou código de erro, mas pode ter funcionado parcialmente"
}

# Desmontar e limpar
cd /
umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT" "$GA_ISO"

# Marcar como instalado
touch "$FLAG_FILE"

echo "Guest Additions instalado com sucesso!"
echo "Reinicie a VM para aplicar: sudo reboot"
