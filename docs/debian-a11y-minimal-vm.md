# Instalacao minima acessivel (QEMU)

Este guia substitui o fluxo antigo baseado em VirtualBox.

## Caminho recomendado

1. Gerar imagem com Packer:

```bash
packer init packer/debian-a11y.pkr.hcl
packer build \
  -var "iso_url=file:///caminho/para/debian-netinst.iso" \
  -var "iso_checksum=none" \
  packer/debian-a11y.pkr.hcl
```

2. Iniciar com a CLI:

```bash
ea11ctl vm install
ea11ctl vm start
```

3. Conectar por SSH:

```bash
ssh -p 2222 a11ydevs@localhost
```

## Observacoes

- O projeto esta em modo QEMU-only.
- Guias antigos com VBoxManage/VDI estao descontinuados.
- Para detalhes de build e runtime, consulte:
  - docs/generate-vm.md
  - docs/architecture.md
  - docs/user/install.md
