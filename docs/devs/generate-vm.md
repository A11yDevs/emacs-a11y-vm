# Geracao de VM para desenvolvedores (QEMU-only)

Guia tecnico para build, validacao e execucao local da imagem.

## Requisitos

- qemu-system-x86_64
- qemu-img
- packer
- acesso a ISO Debian netinst

## Build com Packer

```bash
packer init packer/debian-a11y.pkr.hcl

packer build \
  -var "iso_url=file:///caminho/para/debian-netinst.iso" \
  -var "iso_checksum=none" \
  -var "output_dir=output" \
  -var "version=dev-local" \
  packer/debian-a11y.pkr.hcl
```

Artefato principal:

- output/debian-a11ydevs.qcow2

## Smoke local

1. Copiar/instalar imagem no estado local:

```bash
ea11ctl vm install --force-download
```

2. Substituir temporariamente por build local (se necessario):

```bash
cp output/debian-a11ydevs.qcow2 ~/.emacs-a11y-vm/debian-a11ydevs.qcow2
```

3. Iniciar e validar:

```bash
ea11ctl vm start
ea11ctl vm status
ea11ctl vm ssh
```

## Checkpoints de validacao

No guest:

- /home em disco separado
- espeakup habilitado
- mount-shared-folder.service habilitado
- /usr/local/bin/ea11ctl presente

No host:

- logs de QEMU disponiveis em ~/.emacs-a11y-vm/logs
- porta SSH encaminhada (2222 por padrao)

## Politica de manutencao

- Nao adicionar novos fluxos de VirtualBox.
- Ajustes de geracao devem ocorrer em packer/debian-a11y.pkr.hcl e packer/files.
- Qualquer alteracao de comportamento precisa atualizar docs de usuario e de devs.
