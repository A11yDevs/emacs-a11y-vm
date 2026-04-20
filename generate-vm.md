# Gerando a VM acessível automaticamente

Este documento explica como usar o script `setup-vm.sh` para criar uma VM Debian 13 totalmente textual, sem interface gráfica e com síntese de voz (Speakup + eSpeak-NG) habilitada desde o boot. O script automatiza os passos descritos no [guia de instalação manual](debian-a11-minimal-vm.md).

## Pré-requisitos

1. **VirtualBox** instalado (com o comando `VBoxManage` disponível no PATH).
2. **ISO netinst do Debian 13** (amd64) — baixe em [cdimage.debian.org](https://cdimage.debian.org/). Se sua placa de som requer firmware, use a ISO non-free com firmware.
3. **Áudio funcional** no host para ouvir a síntese de voz da VM.

## Configuração

1. Copie o arquivo de exemplo de configuração:

```bash
cp .env.example .env
```

2. Edite o `.env` com os valores desejados:

```bash
# Caminho para a ISO do Debian (obrigatório)
ISO_PATH=~/Downloads/debian-13-amd64-netinst.iso

# Nome da VM no VirtualBox
VM_NAME=debian-a11ydevs

# Recursos de hardware
VM_RAM=2048
VM_CPUS=2
VM_DISK_MB=16000

# Conta de usuário da VM
VM_USER=a11ydevs
VM_PASSWORD=123456
VM_FULLNAME=A11y Devs

# Rede e hostname
VM_HOSTNAME=debian-a11ydevs
VM_DOMAIN=local
# Interface bridge (deixe vazio para auto-detectar)
BRIDGE_ADAPTER=

# Localização
VM_LOCALE=pt_BR
VM_COUNTRY=BR
VM_TIMEZONE=America/Sao_Paulo
# Layout do teclado (us = americano, br = ABNT2)
VM_KEYBOARD=br
```

> **Importante:** o arquivo `.env` contém a senha da VM e é ignorado pelo Git (`.gitignore`). Nunca faça commit dele.

## Criar a VM

Execute o script:

```bash
./setup-vm.sh
```

O script irá:

1. Validar que o VirtualBox e a ISO existem
2. Criar a VM com controlador de áudio **ICH AC97** (compatível com síntese de voz)
3. Configurar rede em modo **Bridge** (auto-detecta a interface do host)
4. Gerar um **preseed** que instala apenas o sistema base (sem desktop/GUI)
5. Selecionar a task `ssh-server` e instalar os pacotes `espeakup`, `sudo` e `emacs`
6. Configurar `speakup.synth=soft` no GRUB para voz em todo boot
7. Adicionar o usuário ao grupo `sudo`
8. Iniciar a instalação em modo **headless** (sem janela)

A instalação leva alguns minutos. Acompanhe o estado com:

```bash
VBoxManage showvminfo debian-a11ydevs | grep -i state
```

## Acessar a VM

Após a instalação terminar e a VM reiniciar, a VM obtém um IP via DHCP na sua rede local (modo Bridge). Para descobrir o IP, abra o console da VM ou consulte o roteador:

```bash
# Abrir console para ver o IP
VBoxManage startvm debian-a11ydevs --type gui
# Na VM, execute: ip a
```

Conecte via SSH:

```bash
ssh a11ydevs@<IP_DA_VM>
```

Use o usuário configurado no `.env`.

> **Dica:** se preferir usar rede NAT com port-forwarding em vez de Bridge, configure `BRIDGE_ADAPTER` como vazio e altere manualmente a rede após criar a VM:
> ```bash
> VBoxManage modifyvm debian-a11ydevs --nic1 nat --nat-pf1 "ssh,tcp,,2222,,22"
> ```

## Comandos úteis

| Ação | Comando |
|---|---|
| Ver estado da VM | `VBoxManage showvminfo debian-a11ydevs \| grep -i state` |
| Abrir console gráfico | `VBoxManage startvm debian-a11ydevs --type gui` |
| Desligar a VM | `VBoxManage controlvm debian-a11ydevs acpipowerbutton` |
| Forçar desligamento | `VBoxManage controlvm debian-a11ydevs poweroff` |
| Remover a VM | `VBoxManage unregistervm debian-a11ydevs --delete` |

> Substitua `debian-a11ydevs` pelo valor de `VM_NAME` se você alterou o nome.

## O que é instalado na VM

- **Debian 13** minimal (apenas `standard system utilities` + `ssh-server`)
- **espeakup** — ponte entre o módulo do kernel Speakup e o sintetizador eSpeak-NG
- **sudo** — permite executar comandos como root
- **emacs** — editor de texto
- **openssh-server** — acesso remoto via SSH (via task `ssh-server`)
- **Nenhuma interface gráfica** — sem X11, Wayland, GNOME, KDE, etc.
- **speakup.synth=soft** no GRUB — voz ativa em todo boot
- Usuário adicionado ao grupo **sudo**

## Próximos passos

Após acessar a VM via SSH, você pode instalar pacotes adicionais conforme suas necessidades:

```bash
sudo apt update
sudo apt install emacspeak
```

Consulte o [guia de instalação manual](debian-a11-minimal-vm.md) para dicas de acessibilidade (volume, velocidade da voz, alto contraste) e configurações adicionais.
