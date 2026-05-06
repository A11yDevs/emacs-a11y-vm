# emacs-a11y-vm

Máquina virtual Debian com Emacs e síntese de voz, pronta para uso.

A VM é textual, sem interface gráfica, com fala habilitada desde o boot via espeakup. 

---

## Pré-requisitos

### Windows

- Windows 10 ou 11
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) instalado

### macOS

- macOS 10.15+
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) **ou** QEMU
  - VirtualBox: `brew install --cask virtualbox`
  - QEMU: `brew install qemu`

### Linux (Debian/Ubuntu)

- Debian 11+ ou Ubuntu 20.04+
- VirtualBox **ou** QEMU
  - VirtualBox: `sudo apt-get install virtualbox`
  - QEMU: `sudo apt-get install qemu-system-x86 qemu-utils`

### QEMU (todos os SOs)

Para usar backend QEMU em qualquer plataforma:

- `qemu-system-x86_64` e `qemu-img` instalados e no PATH

---

## Instalação com ea11ctl (recomendado)

`ea11ctl` é a CLI do projeto. Com ela você instala, atualiza e gerencia a VM sem precisar clonar o repositório.

### 1. Instalar a CLI

#### Windows (PowerShell)

Execute no PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.ps1' -UseBasicParsing).Content
```

Após a instalação, `ea11ctl` fica disponível em qualquer terminal do Windows.

#### macOS e Linux (Bash)

Execute no terminal (bash/zsh):

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.sh | bash
```

Ou com `wget`:

```bash
wget -O - https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.sh | bash
```

Após a instalação, `ea11ctl` fica disponível em qualquer terminal do macOS ou Linux.

**Nota:** O instalador detecta seu sistema operacional automaticamente e instala em `/usr/local/bin` (preferido) ou `~/.local/bin` (caso não tenha permissão de escrita em `/usr/local/bin`).

### 2. Instalar a VM

#### Windows

```powershell
ea11ctl vm install
```

#### macOS e Linux

```bash
ea11ctl vm install
```

O comando baixa a imagem do GitHub, converte para o formato do VirtualBox e cria a VM automaticamente (~5-10 min na primeira vez).

---

## Comandos essenciais

A CLI `ea11ctl` funciona **identicamente** em Windows (PowerShell), macOS e Linux (bash/zsh).

| Comando | O que faz |
|---|---|
| `ea11ctl vm install` | Instala a VM a partir da última release |
| `ea11ctl vm start` | Inicia a VM (backend padrão: `virtualbox`) |
| `ea11ctl vm start -b qemu` | Inicia a VM no QEMU |
| `ea11ctl vm stop -b qemu` | Desliga a VM QEMU |
| `ea11ctl vm status -b qemu` | Mostra o estado atual no backend QEMU |
| `ea11ctl vm ssh -b qemu` | Abre sessão SSH na VM QEMU |
| `ea11ctl self-update` | Atualiza a CLI para a versão mais recente |

### Backends da CLI

O comando `vm` é único e aceita seleção de backend, preferencialmente com a opção curta `-b`:

- `-b virtualbox` (equivalente: `--backend virtualbox`)
- `-b qemu` (equivalente: `--backend qemu`)

Exemplos (funciona em Windows, macOS e Linux):

```bash
# Linux/macOS (bash/zsh)
ea11ctl vm start -b virtualbox
ea11ctl vm start -b qemu
ea11ctl vm status -b qemu
ea11ctl vm ssh -b qemu
```

```powershell
# Windows (PowerShell)
ea11ctl vm start -b virtualbox
ea11ctl vm start -b qemu
ea11ctl vm status -b qemu
ea11ctl vm ssh -b qemu
```

No backend QEMU, os arquivos da VM ficam em `~/.emacs-a11y-vm`:

- `debian-a11ydevs.qcow2` (imagem de sistema)
- `<nome-da-vm>-home.qcow2` (disco de dados persistente, montado em `/home`)
- `qemu/<nome-da-vm>.json` (estado da VM)

Para ver todos os comandos disponíveis:

```bash
# Linux/macOS
ea11ctl help
```

```powershell
# Windows
ea11ctl help
```

Para ver a ajuda de um comando específico, use `-h`:

```bash
# Linux/macOS
ea11ctl vm install -h
```

```powershell
# Windows
ea11ctl vm install -h
```

---

## Acesso à VM

Após iniciar a VM, conecte via SSH:

```bash
# Linux/macOS
ea11ctl vm ssh
```

```powershell
# Windows
ea11ctl vm ssh
```

Para backend QEMU:

```powershell
ea11ctl vm ssh -b qemu
```

Ou diretamente:

```bash
ssh -p 2222 a11ydevs@localhost
```

| Campo | Valor |
|---|---|
| Usuário | `a11ydevs` |
| Senha | `123456` |
| Porta SSH | `2222` |

---

## Documentação

| Guia | Descrição |
|---|---|
| [Instalação detalhada](docs/user/install.md) | Outras formas de instalação e solução de problemas |
| [Personalização](docs/user/customize.md) | Configurar Emacs, shell e seus arquivos |
| [Upgrade](docs/user/upgrade.md) | Atualizar a VM sem perder dados |

### Para usuários de macOS e Linux

| Guia | Descrição |
|---|---|
| [CLI Bash - Guia Completo](cli/README-BASH.md) | Instalação, uso e troubleshooting da CLI para macOS/Linux |
| [CLI Bash vs PowerShell](docs/cli-bash-comparison.md) | Compatibilidade entre as versões Windows e Unix |
| [Implementação de VM Backends](docs/cli-vm-implementation-guide.md) | Guia técnico para VirtualBox e QEMU |

### Seus dados estão seguros em upgrades

A VM usa dois discos separados: o sistema (substituído em upgrades) e seus dados em `/home` (preservados sempre). Suas configurações do Emacs, projetos e dotfiles nunca são apagados em uma atualização.

---

## Contribuir com o projeto

Interessado em desenvolver ou melhorar o emacs-a11y-vm?

A documentação técnica para desenvolvedores está em **[docs/devs/](docs/devs/README.md)**. Ela cobre a arquitetura do projeto, os princípios de design, como gerar a VM localmente e o pipeline de CI/CD.
