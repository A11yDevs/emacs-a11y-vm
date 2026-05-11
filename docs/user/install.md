# Instalando a VM emacs-a11y

Este guia mostra como instalar a VM emacs-a11y no Windows usando uma release pronta do GitHub.

## Pré-requisitos

- **Windows** (10 ou 11)
- **QEMU** instalado (`qemu-system-x86_64` e `qemu-img` no PATH)
- Conexão com a internet

---

## Instalação

### Opção 1: PowerShell (linha de comando)

```powershell
ea11ctl vm install
ea11ctl vm start
```

Com parâmetros personalizados (mais memória, mais CPUs):

```powershell
ea11ctl vm start --memory 2048 --cpus 2
```

Para ver todas as opções:

```powershell
ea11ctl help
```

### Opção 2: Sem clonar o repositório

Execute diretamente via URL:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.ps1' -UseBasicParsing).Content
ea11ctl vm install
ea11ctl vm start
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

Use `-ExecutionPolicy Bypass` ao instalar a CLI por URL.

Se preferir uma solução permanente:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Erro de permissão (UnauthorizedAccess)

Execute o PowerShell como Administrador ou navegue para uma pasta com permissão de escrita:

```powershell
cd $env:USERPROFILE\Downloads
ea11ctl vm install
ea11ctl vm start
```

### QEMU não encontrado

Verifique se o QEMU está instalado corretamente:

```powershell
qemu-system-x86_64 --version
qemu-img --version
```

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

A CLI usa backend QEMU como padrão.

Exemplos:

```powershell
ea11ctl vm start
ea11ctl vm status
ea11ctl vm ssh
ea11ctl vm stop
```

No backend QEMU, o ea11ctl usa `~/.emacs-a11y-vm` para manter consistência:

- `debian-a11ydevs.qcow2`: imagem de sistema padrão
- `<vm>-home.qcow2`: disco de dados do usuário (persistente, montado em `/home`)
- `qemu/<vm>.json`: estado da VM

Se a imagem de sistema não existir em `~/.emacs-a11y-vm`, a CLI tenta localizar `debian-a11ydevs.qcow2` no projeto e copiar para lá automaticamente.
