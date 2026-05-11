# Guia de implementacao da CLI VM (QEMU)

Este guia descreve como o comando vm da CLI opera no backend QEMU.

## Objetivo

Fornecer uma interface unica para:

- install
- start
- stop/close
- status
- ssh
- diagnose
- host-share (bash)

## Estado local

Diretorio base:

- ~/.emacs-a11y-vm

Arquivos principais:

- debian-a11ydevs.qcow2 (sistema)
- <vm>-home.qcow2 (dados)
- qemu/*.env|json (estado)
- logs/*.log (logs de runtime)

## Contrato de comandos

1. vm install
- baixa/reutiliza imagem qcow2 de release
- garante disco de dados
- nao sobrescreve dados por padrao

2. vm start
- monta linha de comando qemu-system-x86_64
- anexa sistema + dados
- aplica hostfwd para ssh
- injeta configuracao de compartilhamento via fw_cfg

3. vm stop/close
- encerra processo QEMU de forma graciosa
- marca estado local como stopped

4. vm status
- informa estado atual e porta ssh

5. vm ssh
- abre sessao ssh para localhost:<porta>

6. vm diagnose
- imprime estado e ultimas linhas de log

## Compartilhamento host->guest

No backend bash:

- vm host-share list
- vm host-share set --mode ssh|cifs ...
- vm host-share clear

A configuracao e persistida no host e enviada ao guest via fw_cfg.

## Guest integration

No guest existem:

- /usr/local/bin/mount-shared-folder.sh
- /usr/local/bin/ea11ctl (guest)
- mount-shared-folder.service

## Invariantes

- backend suportado: QEMU
- release suportada: qcow2
- /home deve continuar em disco separado
- funcionalidades de acessibilidade nao podem regredir

## Boas praticas

- manter mensagens de erro orientativas
- validar prerequisitos (qemu-system-x86_64, qemu-img)
- nao introduzir dependencias de VirtualBox
- atualizar docs sempre que comportamento mudar
