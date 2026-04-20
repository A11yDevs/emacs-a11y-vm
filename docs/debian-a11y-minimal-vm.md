# Instalação mínima e acessível do Debian 13 no VirtualBox com voz e SSH

Este guia explica como criar uma máquina virtual (VM) ultra-mínima do Debian 13 usando o VirtualBox. A instalação utiliza o netinst ISO e é totalmente textual, com suporte à síntese de voz desde o menu de boot. Também mostra como configurar a rede em modo bridge para permitir acesso remoto via SSH ao sistema instalado.

## 1. Pré-requisitos

- **Imagem ISO netinst do Debian 13** — baixe a versão amd64 em `cdimage.debian.org`. Se sua placa de som requer firmware, use a ISO non-free com firmware.
- **VirtualBox** instalado no host (Windows, macOS ou Linux).
- **Áudio funcional no host**; a fala do instalador será reproduzida pela VM.

## 2. Criar a máquina virtual

1. Abra o **VirtualBox** e clique em **Novo**.
2. Dê um nome (por exemplo, **“Debian 13 A11yDevs”**) e escolha a imagem ISO baixada, por exemplo:
   - /Users/usuario/Downloads/debian-13-amd64-netinst.iso 
   - Automaticamente, o VirtualBox marcará a opção "Proceed with unattended installation, desmarque as opções de instalação automática e mantenha os preenchimentos automáticos intactos. Clique em **Próximo**.
      - **OS** → Linux
      - **OS Distribution** → Debian
      - **OS Version** → Debian (64-bit)

3. Clique em próximo e preencha os campos:
   - **Username**: `a11ydevs`
   - **Password**: `123456`
   - **Full Name**: `A11y Devs`
   - **Hostname**: `debian-a11ydevs`
   - **Domain Name**: `local`
   - clique em **Próximo**
4. Configure a quantidade de memória (**≥ 1 GB**), quantidade de CPUs (**≥2**) e crie um disco rígido virtual (**VDI**) de pelo menos **16 GB**. O instalador minimalista não ocupa muito espaço, mas módulos a serem instalados podem ocupar mais. Clique em **Próximo**.
5. Confira a configuração final e clique em **Finalizar**.

## 3. Iniciar a instalação acessível

1. Inicie a VM. Caso a tela fique muito pequena, configure modo escalonado na opção de menu `View > Scaled Mode` ou use `Host + C` para alternar. O instalador Debian é totalmente acessível por voz, e um bip indica que você pode interagir.
2. Após carregar, o menu de boot do instalador Debian é exibido e um bip indica que você pode interagir.
3. **Ative a fala**:
   - pressione `s` e em seguida `Enter` (no BIOS tradicional) para iniciar a instalação com síntese de voz.
   - Segundo o wiki do Debian, desde o Debian 7 o suporte de fala é ativado dessa forma.
   - No Debian 12 ou posterior, se você não pressionar nada, essa opção é selecionada automaticamente após 30 segundos.
4. **Opcional:** para acessar modos avançados, pressione `a` para abrir o menu **Advanced**. No submenu:
   - `x` inicia a instalação expert
   - `r` abre o rescue mode
   - `a` inicia uma instalação automatizada
5. Selecione a língua, para Português do Brasil, escolha o número 58.
6. Selecione sua localidade (fuso horário), para Brasil, escolha o número 1.
7. Selecione o layout do teclado, para ABNT2, escolha o número 11.
8. Informe o nome da máquina (hostname), por exemplo `debian-a11ydevs`.
9. Informe o nome do domínio, por exemplo `local`. Se não tiver um domínio, pode usar `local` ou deixar em branco.
10. Configure a senha do usuário root. Se não quiser usar o root, deixe em branco e confirme. O instalador criará um usuário normal posteriormente.
11. Crie um usuário normal, por exemplo: 
    - Nome completo: `A11y Devs`
    - Nome de usuário: `a11ydevs`
    - Senha: `123456`
12. Configure o fuso horário, para São Paulo, escolha o número 27.
13. Particione o disco rígido. Para uma instalação mínima, escolha as opções:
    - **Guided – use entire disk**: opção 1
    - **All files in one partition (recommended)**: opção 1
    - Confirme para gravar as partições: opcão 12
14. Ler mmídias adicionais: escolha **No** (opção 2).
15. Espelho Debian: escolha o padrão (opção 1).
16. Configurar o proxy: deixe em branco e confirme.
17. Participar do programa de uso anônimo: escolha **No** (opção 2).
18. Selecione os softwares a instalar. Escolha somente a opção 11 (SSH), assim o sistema fica mínimo e sem interface gráfica. O instalador irá instalar o sistema base e o servidor SSH.
19. Instalação do GRUB: escolha a opção 2 para instalar o GRUB no disco rígido virtual.
20. Finalize a instalação e reinicie a máquina virtual.

## 5. Pós-instalação e acesso remoto

Após reiniciar, o sistema em modo texto inicializa com o mesmo suporte de fala ativado durante a instalação. Faça login com o usuário criado.

Instale o pacote `espeakup` para ter suporte à síntese de voz no sistema instalado:

```bash
su -
apt update
apt install espeakup
```

Instale também os pacotes sudo e emacs:

```bash
apt install sudo emacs
```

Para que a máquina virtual obtenha um endereço IP na mesma rede do host, configure a placa de rede em modo **Bridge** nas configurações da VM. Selecione a opção `Configurações > Rede > Adaptador 1 > Ligado a: Placa em modo Bridge` e escolha a interface de rede do host. 

Após configurar a rede, reinicie a VM para obter um endereço IP. Você pode verificar o endereço IP com o comando:

```bash
ip addr
```

Anote o endereço IP atribuído à VM. Agora, você pode acessar a máquina virtual remotamente via SSH usando o seguinte comando no terminal do host:

```bash
ssh a11ydevs@<IP_DA_VM>
```

Pronto! Agora você tem um sistema Debian 13 minimalista, totalmente acessível por voz e com acesso remoto via SSH.


## 6. Conclusão

Seguindo estes passos, você criará uma máquina virtual Debian 13 extremamente enxuta e totalmente acessível por voz desde o boot. A escolha do modo bridge e a instalação do SSH permitem administrar a VM remotamente com facilidade. Após concluir a instalação, você pode adicionar softwares adicionais, de acordo com suas necessidades.

## Referência

- Debian Wiki — *accessibility*: `https://wiki.debian.org/accessibility`
