# emacs-a11y-vm

Máquina virtual Debian com Emacs e síntese de voz, pronta para uso.

A VM é textual, sem interface gráfica, com fala habilitada desde o boot via espeakup. O acesso é feito por SSH do host.

---

## Pré-requisitos

- Windows 10 ou 11
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) instalado

---

## Instalação rápida

### Método mais fácil: arquivo .cmd

Baixe ou clone este repositório e execute:

```cmd
scripts\install-release-vm.cmd
```

Ou clique duas vezes em `scripts\install-release-vm.cmd` no Windows Explorer.

O script baixa a imagem do GitHub, converte para VDI e cria a VM automaticamente.

### PowerShell

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1
```

Com parâmetros personalizados:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -RAM 4096 -CPUs 4
```

### Sem clonar o repositório

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1' -UseBasicParsing).Content
```

---

## Acesso à VM

Após a instalação, conecte via SSH:

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

### Para usuários

| Guia | Descrição |
|---|---|
| [Instalação detalhada](docs/user/install.md) | Opções de instalação, CLI e solução de problemas |
| [Personalização](docs/user/customize.md) | Configurar Emacs, shell e seus arquivos |
| [Upgrade](docs/user/upgrade.md) | Atualizar a VM sem perder dados |

### Seus dados estão seguros em upgrades

A VM usa dois discos separados: o sistema (substituído em upgrades) e seus dados em `/home` (preservados sempre). Suas configurações do Emacs, projetos e dotfiles nunca são apagados em uma atualização.

---

## Contribuir com o projeto

Interessado em desenvolver ou melhorar o emacs-a11y-vm?

A documentação técnica para desenvolvedores está em **[docs/devs/](docs/devs/README.md)**. Ela cobre a arquitetura do projeto, os princípios de design, como gerar a VM localmente e o pipeline de CI/CD.
