# Arquitetura da VM emacs-a11y

Este documento descreve a arquitetura atual do projeto em modo QEMU-only.

## Visao geral

A VM usa dois discos qcow2:

- Disco de sistema (qcow2): contem Debian base e componentes de runtime.
- Disco de dados (qcow2): montado em /home e preservado entre upgrades.

Essa separacao permite atualizar o sistema sem perder configuracoes e arquivos do usuario.

## Componentes principais

1. Build de imagem
- Packer: packer/debian-a11y.pkr.hcl
- Preseed: packer/http/preseed.cfg
- Scripts/arquivos guest: packer/files

2. Runtime host
- CLI host (bash/powershell): ea11ctl
- Virtualizacao: qemu-system-x86_64
- Manipulacao de disco: qemu-img

3. Runtime guest
- setup-userdata-disk.sh: prepara e monta disco de dados em /home
- mount-shared-folder.sh: monta compartilhamento host->guest (ssh/cifs)
- ea11ctl guest: visualiza configuracao e aciona montagem de compartilhamento

## Layout de discos

No host, por padrao:

- ~/.emacs-a11y-vm/debian-a11ydevs.qcow2 (sistema)
- ~/.emacs-a11y-vm/<vm>-home.qcow2 (dados)

No guest:

- /dev/sda (ou equivalente): /
- /dev/sdb (ou equivalente): /home

## Fluxo de instalacao e start

1. vm install
- baixa (ou reutiliza) qcow2 de sistema da release
- registra estado local da VM
- garante disco de dados qcow2

2. vm start
- inicia QEMU com os dois discos
- configura rede usernet com encaminhamento de SSH (porta 2222 por padrao)
- injeta configuracao de compartilhamento via fw_cfg

3. primeiro boot
- service emacs-a11y-userdata configura /home no disco de dados
- service mount-shared-folder tenta montar compartilhamento do host

## Upgrade

Upgrade esperado:

- substituir qcow2 de sistema por versao nova
- manter qcow2 de dados
- reiniciar VM

Resultado:

- sistema atualizado
- dados/configuracoes em /home preservados

## Compartilhamento host->guest

Suporte atual:

- modo ssh (tipico em Unix/macOS)
- modo cifs (tipico em Windows)

Configuracao e enviada do host para guest via fw_cfg.

## Invariantes de projeto

- backend suportado: QEMU
- release suportado: qcow2
- dados do usuario devem permanecer em /home no disco persistente
- recursos de acessibilidade devem continuar funcionais no boot e no pos-boot
