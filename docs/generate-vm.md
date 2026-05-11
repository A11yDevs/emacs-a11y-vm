# Gerando a VM acessivel (QEMU)

Este guia descreve o fluxo atual para gerar a imagem localmente com Packer + QEMU.

## Pre-requisitos

- qemu-system-x86_64
- qemu-img
- packer
- ISO netinst Debian 13 (amd64)

## Build da imagem

Na raiz do repositorio:

```bash
packer init packer/debian-a11y.pkr.hcl

packer build \
  -var "iso_url=file:///caminho/para/debian-netinst.iso" \
  -var "iso_checksum=none" \
  -var "output_dir=output" \
  packer/debian-a11y.pkr.hcl
```

Saida esperada:

- output/debian-a11ydevs.qcow2

## Execucao local rapida no QEMU

Opcao 1 (script pronto no repositorio):

```bash
./scripts/run-qemu-macos.sh
```

Opcao 2 (CLI):

```bash
ea11ctl vm install
ea11ctl vm start
```

## Acesso SSH

```bash
ssh -p 2222 a11ydevs@localhost
```

## Disco de dados

No runtime, a VM usa disco separado para /home:

- ~/.emacs-a11y-vm/<vm>-home.qcow2

Esse disco deve ser preservado em upgrades.

## Observacoes

- O fluxo VirtualBox legado foi descontinuado.
- Scripts antigos baseados em VBoxManage existem apenas como referencia historica e nao devem ser usados para novo provisionamento.
