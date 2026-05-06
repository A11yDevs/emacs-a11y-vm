# Comparação: CLI PowerShell vs Bash

## Resumo da Migração

A CLI agora está disponível em **duas versões**:
- **PowerShell** (`ea11ctl.ps1`) - Windows
- **Bash** (`ea11ctl`) - macOS, Linux (Debian, Ubuntu, etc.)

Ambas possuem funcionalidades equivalentes e sintaxe idêntica.

## Compatibilidade de Comandos

| Comando | PowerShell | Bash | Status |
|---------|-----------|------|--------|
| `help`, `-h`, `--help` | ✅ | ✅ | Completo |
| `version`, `--version` | ✅ | ✅ | Completo |
| `version --check-update` | ✅ | ✅ | Completo |
| `self-update`, `update` | ✅ | ✅ | Completo |
| `self-update --force` | ✅ | ✅ | Completo |
| `vm install`, `vm -i` | ✅ | 🔄 | Base implementada |
| `vm list`, `vm -l` | ✅ | 🔄 | Base implementada |
| `vm start`, `vm -s` | ✅ | 🔄 | Base implementada |
| `vm stop`, `vm -S` | ✅ | 🔄 | Base implementada |
| `vm close`, `vm -c` | ✅ | 🔄 | Base implementada |
| `vm diagnose`, `vm -d` | ✅ | 🔄 | Base implementada |
| `vm status`, `vm -q` | ✅ | 🔄 | Base implementada |
| `vm ssh`, `vm -x` | ✅ | 🔄 | Base implementada |
| `vm share-folder` | ✅ | 🔄 | Base implementada |
| `--backend virtualbox` | ✅ | 🔄 | Parcialmente |
| `--backend qemu` | ✅ | 🔄 | Parcialmente |

**Legenda:**
- ✅ Completo e testado
- 🔄 Base implementada, falta integração com backends
- ❌ Não implementado

## Diferenças e Particularidades

### Instalação

#### PowerShell (Windows)
```powershell
powershell -ExecutionPolicy Bypass -Command "
    IEX (New-Object System.Net.WebClient).DownloadString('https://...')
"
```

#### Bash (macOS/Linux)
```bash
curl -fsSL https://... | bash
# ou
wget -O - https://... | bash
```

### Localização da CLI

#### PowerShell
- Windows: `%LOCALAPPDATA%\ea11ctl\bin\ea11ctl.ps1`
- PATH: adicionado ao `$env:Path` do usuário

#### Bash
- macOS: `/usr/local/bin/ea11ctl` (preferido) ou `~/.local/bin/ea11ctl`
- Linux: `/usr/local/bin/ea11ctl` (preferido) ou `~/.local/bin/ea11ctl`
- PATH: adicionado a `~/.bashrc` ou `~/.zshrc`

### Estrutura de Dados

#### PowerShell (Windows)
```
%LOCALAPPDATA%\emacs-a11y-vm\
  ├── qemu/
  │   └── <vm-name>.json
```

#### Bash (macOS/Linux)
```
~/.emacs-a11y-vm/
  ├── qemu/
  │   └── <vm-name>.json
  ├── debian-a11ydevs.qcow2
  └── <vm-name>-home.qcow2
```

## Status de Implementação por Funcionalidade

### ✅ Completo

- [x] Sistema de ajuda (`help`, `-h`, `--help`)
- [x] Exibição de versão (`version`, `--version`)
- [x] Verificação de atualizações (`--check-update`, `-c`)
- [x] Auto-atualização (`self-update`, `update`)
- [x] Atualização forçada (`--force`, `-f`)
- [x] Detecção automática de SO (macOS, Linux)
- [x] Download com fallback múltiplo
- [x] Resolução de SHA do commit

### 🔄 Em Desenvolvimento

- [ ] **VM Commands**
  - [ ] Integração completa com VirtualBox
  - [ ] Integração completa com QEMU
  - [ ] Suporte a múltiplos nomes de VM
  - [ ] Montagem de pastas compartilhadas
  - [ ] Diagnóstico completo
  - [ ] Persistência de estado

- [ ] **SSH**
  - [ ] Suporte a autenticação por chave
  - [ ] Port forwarding automático
  - [ ] Proxy de comandos

- [ ] **Melhorias de UX**
  - [ ] Barra de progresso para downloads
  - [ ] Output formatado (JSON, YAML)
  - [ ] Suporte a auto-completion (bash/zsh)
  - [ ] Modo verbose/debug

### ❓ Futuro

- [ ] Suporte a Fedora/RHEL
- [ ] Suporte a Alpine Linux
- [ ] Suporte a BSD
- [ ] Integração com package managers (brew, apt, etc.)
- [ ] Testes automatizados
- [ ] CI/CD pipeline

## Guia de Migração para Usuários

### Se você usava PowerShell no Windows

**Antes:**
```powershell
ea11ctl vm install
ea11ctl vm start -n debian-a11y
```

**Agora em bash (macOS/Linux):**
```bash
ea11ctl vm install
ea11ctl vm start -n debian-a11y
```

A sintaxe é **exatamente a mesma**! 🎉

### Diferenças Principais

1. **Instalação**
   - PowerShell: Via `install.ps1`
   - Bash: Via `install.sh`

2. **Requisitos**
   - PowerShell: curl/Invoke-WebRequest, Windows
   - Bash: curl/wget, bash 4.0+

3. **Localização de arquivos**
   - PowerShell: `%LOCALAPPDATA%`
   - Bash: `~/.emacs-a11y-vm`

## Testes

### Executar Testes da CLI

```bash
# Testes unitários
pytest tests/ -v

# Testes e2e
pytest tests/e2e/ -v

# Teste específico
pytest tests/test_*.py -k "version" -v
```

### Teste Local

```bash
# Clonar repo
git clone https://github.com/A11yDevs/emacs-a11y-vm.git
cd emacs-a11y-vm/cli

# Testar sem instalar
./ea11ctl --version
./ea11ctl help

# Executar script de teste
bash test-install.sh
```

## Solução de Problemas

### Comando não encontrado

```bash
# Verificar se está no PATH
which ea11ctl

# Adicionar ao PATH temporariamente
export PATH="$PATH:/usr/local/bin"

# Adicionar permanentemente (bash)
echo 'export PATH="$PATH:/usr/local/bin"' >> ~/.bashrc
source ~/.bashrc

# Ou para zsh
echo 'export PATH="$PATH:/usr/local/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Erro de permissão

```bash
# Reparar permissões
chmod +x $(which ea11ctl)

# Ou reinstalar
bash install.sh --force-reinstall
```

### Falha ao baixar

```bash
# Verificar conectividade
curl -I https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/VERSION

# Atualizar com força
ea11ctl self-update --force

# Verificar diretório temporário
ls -la /tmp/ea11ctl-update-*
```

## Roadmap

### v0.2.0 (Próximo)
- [ ] Integração completa com VirtualBox
- [ ] Suporte a QEMU aprimorado
- [ ] Shell auto-completion (bash/zsh)
- [ ] Testes automatizados completos

### v0.3.0
- [ ] Interface JSON output
- [ ] Modo batch/script
- [ ] Plugin system
- [ ] Suporte a Fedora/RHEL

### v1.0.0
- [ ] Estabilidade de API
- [ ] Documentação completa
- [ ] Suporte a múltiplas plataformas
- [ ] Release oficial

## Contribuindo

Para contribuir com a CLI bash:

1. Fork o repositório
2. Crie uma branch para sua feature
3. Implemente a funcionalidade
4. Adicione testes
5. Abra um Pull Request

## Referências

- [Repositório](https://github.com/A11yDevs/emacs-a11y-vm)
- [Issues](https://github.com/A11yDevs/emacs-a11y-vm/issues)
- [Documentação do Projeto](../docs/)
- [README Bash CLI](./README-BASH.md)
