# Instalacao manual para devs (QEMU-only)

Este guia descreve um fluxo manual de desenvolvimento sem usar a CLI.

## 1. Build da imagem

```bash
packer init packer/debian-a11y.pkr.hcl
packer build \
  -var "iso_url=file:///caminho/para/debian-netinst.iso" \
  -var "iso_checksum=none" \
  -var "output_dir=output" \
  packer/debian-a11y.pkr.hcl
```

## 2. Criar disco de dados

```bash
qemu-img create -f qcow2 output/debian-a11ydevs-home.qcow2 10G
```

## 3. Subir VM manualmente

```bash
qemu-system-x86_64 \
  -m 2048 \
  -smp 2 \
  -drive file=output/debian-a11ydevs.qcow2,format=qcow2,if=virtio \
  -drive file=output/debian-a11ydevs-home.qcow2,format=qcow2,if=virtio \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0 \
  -nographic -serial stdio
```

## 4. Validar no guest

- /home em disco separado
- espeakup habilitado
- mount-shared-folder.service habilitado
- /usr/local/bin/ea11ctl presente

## Nota

Conteudos legados de VirtualBox nesse repositorio sao historicos e nao devem ser usados para fluxo novo.
