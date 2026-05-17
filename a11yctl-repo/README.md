# a11yctl

CLI do projeto **A11yDevs** para gerenciamento de VMs acessíveis, pacotes e ambientes — sucessor do `ea11ctl`.

## Instalação rápida (Windows)

Abra o **PowerShell** como usuário comum e execute:

```powershell
irm https://raw.githubusercontent.com/A11yDevs/a11yctl/main/install.ps1 | iex
```

O instalador:
1. Verifica/instala o QEMU via `winget`
2. Baixa `a11yctl.ps1`, `a11yctl.cmd`, `ea11ctl.ps1` (alias de compatibilidade), `ea11ctl.cmd` e `VERSION`
3. Instala em `%USERPROFILE%\.a11yctl\bin`
4. Adiciona o diretório ao `PATH` do usuário
5. Detecta automaticamente a instalação antiga (`~/.emacs-a11y-vm`) e copia VMs/configurações para `~/.a11yctl`

## Uso básico

```
a11yctl help
a11yctl vm install
a11yctl vm start
a11yctl vm stop
a11yctl vm ssh
a11yctl migrate
a11yctl self-update
a11yctl version --check-update
```

## Migração de ea11ctl / emacs-a11y-vm

Se você estava usando o `ea11ctl` do repositório `A11yDevs/emacs-a11y-vm`, este é o repositório sucessor.

### Migração automática pelo instalador

O instalador (`install.ps1`) detecta automaticamente `~/.emacs-a11y-vm` e copia VMs e configurações para `~/.a11yctl`. O diretório antigo **nunca é removido automaticamente**.

### Migração manual pelo comando

Após instalar `a11yctl`, execute:

```powershell
a11yctl migrate
```

O comando:
- Detecta `~/.emacs-a11y-vm`
- Copia arquivos de disco (`.qcow2`, `.vmdk`, `.vdi`, etc.)
- Migra configurações (substituindo caminhos legados)
- **Nunca remove** o diretório antigo
- Avisa sobre conflitos (renomeia com sufixo `.migrated`)

Depois de validar que tudo funciona, remova o diretório antigo manualmente:

```powershell
Remove-Item -Path "$env:USERPROFILE\.emacs-a11y-vm" -Recurse -Force
```

### Compatibilidade com ea11ctl

O comando `ea11ctl` continua funcionando como **alias de compatibilidade** — ele exibe um aviso e delega para `a11yctl`. Não há quebra de automações existentes.

O alias `ea11ctl` será removido em versão futura.

## Diretório de estado

| Versão | Diretório |
|--------|-----------|
| ea11ctl ≤ 0.1.x | `~/.emacs-a11y-vm` |
| a11yctl ≥ 0.2.0 | `~/.a11yctl` |

## Atualização

```powershell
a11yctl self-update
```

## Desinstalação

```powershell
a11yctl uninstall
# Com remoção de estado:
a11yctl uninstall --purge-state
```

## Repositório anterior

O código-fonte do `ea11ctl` (≤ 0.1.x) está em [A11yDevs/emacs-a11y-vm](https://github.com/A11yDevs/emacs-a11y-vm).
