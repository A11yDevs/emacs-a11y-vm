#!/bin/bash
# Script para iniciar a VM emacs-a11y no macOS usando QEMU
# Uso: ./scripts/run-qemu-macos.sh [opções adicionais do QEMU]

set -e

QCOW2_PATH="output/debian-a11ydevs.qcow2"
HOME_DISK="output/debian-a11ydevs-home.qcow2"
MEMORY="2048"
CPUS="2"
SSH_PORT="2222"

# Cria disco de dados se não existir
if [ ! -f "$HOME_DISK" ]; then
  echo "Criando disco de dados (10G) em $HOME_DISK..."
  qemu-img create -f qcow2 "$HOME_DISK" 10G
fi

# Inicia QEMU
qemu-system-x86_64 \
  -m "$MEMORY" \
  -smp "$CPUS" \
  -drive file="$QCOW2_PATH",format=qcow2,if=virtio \
  -drive file="$HOME_DISK",format=qcow2,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
  -device virtio-net,netdev=net0 \
  -nographic \
  -serial stdio \
  "$@"

# Dicas de uso:
# - Para acessar via SSH: ssh -p 2222 a11ydevs@localhost (senha: a11ydevs)
# - Para console gráfico, remova -nographic e -serial stdio
# - Para alterar memória, CPUs ou portas, edite as variáveis no topo do script
