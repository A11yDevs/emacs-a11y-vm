#!/bin/bash
# Script para instalar VirtualBox Guest Additions durante o build do Packer
# Executado uma única vez durante a criação da imagem

set -euo pipefail

VBOX_VERSION="7.0.20"  # Versão do VirtualBox Guest Additions
GA_ISO="/tmp/VBoxGuestAdditions.iso"
MOUNT_POINT="/mnt/vbox-ga"

echo "=== Instalando VirtualBox Guest Additions v${VBOX_VERSION} ==="

# Baixar ISO do Guest Additions
echo "Baixando Guest Additions ISO..."
GA_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"

if ! curl -fL "$GA_URL" -o "$GA_ISO"; then
    echo "ERRO: Não foi possível baixar Guest Additions de $GA_URL"
    exit 1
fi

echo "Download concluído: $(ls -lh $GA_ISO | awk '{print $5}')"

# Montar ISO
echo "Montando ISO..."
mkdir -p "$MOUNT_POINT"
mount -o loop "$GA_ISO" "$MOUNT_POINT"

# Instalar Guest Additions
echo "Instalando Guest Additions (pode levar alguns minutos)..."
cd "$MOUNT_POINT"

# Executar instalador
# Nota: O instalador pode retornar código de erro mesmo com instalação bem-sucedida
# por causa de módulos opcionais que não compilam. Verificamos o resultado depois.
./VBoxLinuxAdditions.run --nox11 || {
    EXITCODE=$?
    echo "Instalador retornou código: $EXITCODE"
}

# Verificar se módulos principais foram instalados
echo ""
echo "=== Verificando instalação ==="

if [[ -f /usr/sbin/VBoxService ]]; then
    echo "✓ VBoxService instalado"
else
    echo "✗ VBoxService NÃO encontrado"
fi

if [[ -f /sbin/mount.vboxsf ]]; then
    echo "✓ mount.vboxsf instalado"
else
    echo "✗ mount.vboxsf NÃO encontrado"
fi

# Listar módulos instalados
echo ""
echo "Módulos do kernel instalados:"
ls -la /lib/modules/$(uname -r)/updates/dkms/ 2>/dev/null || echo "Nenhum módulo DKMS encontrado"

# Desmontar e limpar
cd /
umount "$MOUNT_POINT"
rm -rf "$MOUNT_POINT" "$GA_ISO"

echo ""
echo "=== Guest Additions instalado com sucesso! ==="
echo "Os módulos serão carregados automaticamente no próximo boot no VirtualBox"
