# emacs-a11y-vm

Máquina virtual Debian com Emacs e síntese de voz, pronta para uso.

A VM é textual, sem interface gráfica, com fala habilitada desde o boot via espeakup. O acesso é feito por SSH do host.

---

## Pré-requisitos

- Windows 10 ou 11
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) instalado

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
| `ea11ctl vm start` | Inicia a VM |
| `ea11ctl vm stop` | Desliga a VM de forma segura |
| `ea11ctl vm status` | Mostra o estado atual da VM |
| `ea11ctl vm ssh` | Abre uma sessão SSH na VM |
| `ea11ctl self-update` | Atualiza a CLI para a versão mais recente |

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
