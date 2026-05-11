# Arquitetura tecnica (Devs)

Arquitetura vigente do projeto emacs-a11y-vm.

## Escopo suportado

- Hypervisor: QEMU
- Formato de release: qcow2
- Persistencia de usuario: qcow2 separado para /home

## Pipeline

1. CI executa packer/debian-a11y.pkr.hcl
2. Gera imagem qcow2
3. Publica asset qcow2 em release

## Runtime host

CLI host controla:

- download/uso de imagem de sistema
- ciclo de vida da VM (start/stop/status/ssh)
- configuracao de compartilhamento host->guest

Estado local padrao:

- ~/.emacs-a11y-vm/debian-a11ydevs.qcow2
- ~/.emacs-a11y-vm/<vm>-home.qcow2
- ~/.emacs-a11y-vm/qemu/*.env|json (dependendo da CLI)
- ~/.emacs-a11y-vm/logs/*

## Runtime guest

Provisionamento instala:

- setup-userdata-disk.sh
- emacs-a11y-userdata.service
- mount-shared-folder.sh
- mount-shared-folder.service
- ea11ctl guest em /usr/local/bin/ea11ctl

## Contratos de compatibilidade

1. /home persistente
- nunca sobrescrever disco de dados por padrao

2. Acessibilidade
- speakup/espeakup funcionais no boot
- recuperacao de voz preservada

3. Compatibilidade de update
- troca de disco de sistema nao deve exigir migracao manual de /home

4. Erro e observabilidade
- logs locais no host
- mensagens claras em falha de boot/montagem/share

## Compartilhamento host->guest

Estrategias:

- sshfs (share_mode=ssh)
- cifs (share_mode=cifs)

Parametros trafegam via fw_cfg (opt/ea11/*).

## Nao-funcionais

- Evitar acoplamento com ferramentas de VirtualBox
- Manter comandos idempotentes
- Manter docs sincronizadas com comportamento real
