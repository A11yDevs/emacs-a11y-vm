# Instalando a VM emacs-a11y

Este guia mostra como instalar a VM emacs-a11y no Windows usando uma release pronta do GitHub.

## Pré-requisitos

- **Windows** (10 ou 11)
- **VirtualBox** instalado — [download em virtualbox.org](https://www.virtualbox.org/wiki/Downloads)
- Conexão com a internet

---

## Instalação

### Opção 1: Arquivo .cmd (mais fácil)

Baixe o repositório e clique duas vezes em `scripts\install-release-vm.cmd`.

O script cuida de tudo automaticamente:

1. Baixa a imagem da VM do GitHub
2. Converte para o formato do VirtualBox (~5-10 min na primeira vez)
3. Cria a VM e configura a rede

### Opção 2: PowerShell (linha de comando)

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1
```

Com parâmetros personalizados (mais memória, mais CPUs):

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -RAM 4096 -CPUs 4
```

Para ver todas as opções:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -Help
```

### Opção 3: Sem clonar o repositório

Execute diretamente via URL:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1' -UseBasicParsing).Content
```

---

## Após a instalação

A VM inicia automaticamente. Conecte via SSH:

```bash
ssh -p 2222 a11ydevs@localhost
```

- **Usuário**: `a11ydevs`
- **Senha**: `123456`

---

## Solução de problemas

### "O script não está assinado digitalmente"

Use o arquivo `.cmd` (Opção 1) ou execute com `-ExecutionPolicy Bypass` (Opção 2).

Se preferir uma solução permanente:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Erro de permissão (UnauthorizedAccess)

Execute o PowerShell como Administrador ou navegue para uma pasta com permissão de escrita:

```powershell
cd $env:USERPROFILE\Downloads
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -OutputDir "$env:USERPROFILE\Downloads\emacs-a11y-vm"
```

### VBoxManage não encontrado

Verifique se o VirtualBox está instalado corretamente:

```powershell
VBoxManage --version
```

Se necessário, adicione `C:\Program Files\Oracle\VirtualBox` ao PATH do sistema.

### Diagnóstico de áudio na VM

As novas imagens incluem `alsa-utils` por padrão (comandos `aplay`, `amixer`, `speaker-test`).

Após boot da VM, você pode validar rapidamente:

```bash
cat /proc/asound/cards
aplay -l
speaker-test -c 2 -t wav
```

---

## CLI global: `ea11ctl`

Instale a CLI `ea11ctl` para gerenciar a VM de qualquer terminal do Windows:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.ps1' -UseBasicParsing).Content
```

Após instalar, você pode usar `ea11ctl` em qualquer diretório.

### Gerenciamento por backend

A CLI usa um único comando `vm` para todos os backends, com seleção preferencial via `-b` (ou `--backend`).

Exemplos:

```powershell
# VirtualBox (padrão)
ea11ctl vm start

# VirtualBox explícito
ea11ctl vm start -b virtualbox

# QEMU
ea11ctl vm start -b qemu
ea11ctl vm status -b qemu
ea11ctl vm ssh -b qemu
ea11ctl vm stop -b qemu
```

No backend QEMU, o ea11ctl usa `~/.emacs-a11y-vm` para manter consistência:

- `debian-a11ydevs.qcow2`: imagem de sistema padrão
- `<vm>-home.qcow2`: disco de dados do usuário (persistente, montado em `/home`)
- `qemu/<vm>.json`: estado da VM

Se a imagem de sistema não existir em `~/.emacs-a11y-vm`, a CLI tenta localizar `debian-a11ydevs.qcow2` no projeto e copiar para lá automaticamente.
