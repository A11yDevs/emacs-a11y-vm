# emacs-a11y-vm

Máquina virtual Debian com Emacs e síntese de voz, pronta para uso.

A VM é textual, sem interface gráfica, com fala habilitada desde o boot via espeakup. 

---

## Pré-requisitos

- Windows 10 ou 11
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) instalado

Para uso com backend QEMU:

- macOS com QEMU instalado (`qemu-system-x86_64` e `qemu-img` no PATH)

---

## Instalação com ea11ctl (recomendado)

`ea11ctl` é a CLI do projeto. Com ela você instala, atualiza e gerencia a VM sem precisar clonar o repositório.

### 1. Instalar a CLI

Execute no PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.ps1' -UseBasicParsing).Content
```

Após a instalação, `ea11ctl` fica disponível em qualquer terminal do Windows.

### 2. Instalar a VM

```powershell
ea11ctl vm install
```

O comando baixa a imagem do GitHub, converte para o formato do VirtualBox e cria a VM automaticamente (~5-10 min na primeira vez).

---

## Comandos essenciais

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

O comando `vm` é único e aceita seleção de backend por opção:

- `--backend virtualbox` ou `-b virtualbox`
- `--backend qemu` ou `-b qemu`

Exemplos:

```powershell
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

```powershell
ea11ctl help
```

Para ver a ajuda de um comando específico, use `-h`:

```powershell
ea11ctl vm install -h
```

---

## Acesso à VM

Após iniciar a VM, conecte via SSH:

```powershell
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

### Seus dados estão seguros em upgrades

A VM usa dois discos separados: o sistema (substituído em upgrades) e seus dados em `/home` (preservados sempre). Suas configurações do Emacs, projetos e dotfiles nunca são apagados em uma atualização.

---

## Contribuir com o projeto

Interessado em desenvolver ou melhorar o emacs-a11y-vm?

A documentação técnica para desenvolvedores está em **[docs/devs/](docs/devs/README.md)**. Ela cobre a arquitetura do projeto, os princípios de design, como gerar a VM localmente e o pipeline de CI/CD.
