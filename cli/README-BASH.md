# ea11ctl CLI - Versão Bash

CLI para o projeto **emacs-a11y-vm** em Bash, compatível com:
- **macOS** (Intel e Apple Silicon)
- **Debian** / **Ubuntu** / Distribuições Linux baseadas em Debian
- **Outras distribuições Linux** (com bash)

## Instalação Rápida

### macOS

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.sh | bash
```

Ou diretamente:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.sh)
```

### Linux (Debian/Ubuntu)

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.sh | bash
```

Ou:

```bash
wget -O - https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.sh | bash
```

## Instalação Manual

### 1. Clone ou baixe o repositório

```bash
git clone https://github.com/A11yDevs/emacs-a11y-vm.git
cd emacs-a11y-vm/cli
```

### 2. Execute o instalador

```bash
bash install.sh
```

O script automaticamente:
- Detecta seu SO (macOS, Linux)
- Baixa os arquivos necessários
- Instala em `/usr/local/bin` ou `~/.local/bin`
- Configura o PATH se necessário

### 3. Verifique a instalação

```bash
ea11ctl --version
ea11ctl help
```

## Uso

### Comandos Principais

#### Ajuda

```bash
ea11ctl help
ea11ctl -h
```

#### Versão

```bash
ea11ctl version
ea11ctl --version
ea11ctl version --check-update  # Verifica se há atualizações disponíveis
```

#### Auto-Atualização

```bash
ea11ctl self-update              # Atualiza se houver nova versão
ea11ctl update --force           # Força atualização
```

### Gerenciamento de VM

#### Listar VMs

```bash
# VirtualBox (padrão)
ea11ctl vm list

# QEMU
ea11ctl vm list --backend qemu
```

#### Iniciar VM

```bash
# VirtualBox
ea11ctl vm start

# Com nome específico
ea11ctl vm start -n debian-a11y

# QEMU
ea11ctl vm start --backend qemu

# Modo headless (sem GUI)
ea11ctl vm start --headless
```

#### Parar VM

```bash
ea11ctl vm stop

# Parar com força
ea11ctl vm stop -f

# Após timeout
ea11ctl vm close -t 30
```

#### Status da VM

```bash
ea11ctl vm status
ea11ctl vm status -q  # Status abreviado
```

#### Diagnóstico

```bash
ea11ctl vm diagnose
```

#### Conectar via SSH

```bash
# Conexão padrão
ea11ctl vm ssh

# Usuário e porta personalizados
ea11ctl vm ssh -u a11ydevs -p 2222

# Com argumentos adicionais para SSH
ea11ctl vm ssh -- -v
```

#### Pastas Compartilhadas

```bash
# Adicionar pasta
ea11ctl vm share-folder add -p /caminho/local -n shared_folder

# Remover pasta
ea11ctl vm share-folder remove --name shared_folder

# Listar pastas
ea11ctl vm share-folder list
```

#### Instalar VM Release

```bash
ea11ctl vm install

# Com argumentos adicionais
ea11ctl vm install -n debian-a11y --no-gui
```

## Configuração Padrão

| Opção | Valor Padrão |
|-------|--------------|
| Backend | virtualbox |
| VM | debian-a11y |
| Usuário SSH | a11ydevs |
| Porta SSH | 2222 |

## Estrutura de Diretórios

A CLI cria e utiliza os seguintes diretórios:

```
~/.emacs-a11y-vm/
  ├── debian-a11ydevs.qcow2        # Imagem de sistema QEMU
  ├── debian-a11y-home.qcow2       # Disco de dados (montado em /home)
  └── qemu/                        # Estados das VMs QEMU
      └── <vm-name>.json
```

## Requisitos

### macOS
- bash 4.0+ (incluso no sistema)
- curl ou wget
- VirtualBox (para backend virtualbox) ou QEMU (para backend qemu)
- OpenSSH (incluso no sistema)

### Linux
- bash 4.0+
- curl ou wget
- VirtualBox ou QEMU (conforme backend)
- OpenSSH
- qemu-system-x86_64 (para QEMU)

### Instalação de Requisitos

#### macOS
```bash
# Usando Homebrew
brew install qemu              # Para QEMU
brew cask install virtualbox   # Para VirtualBox
```

#### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    virtualbox \
    openssh-client \
    curl
```

## Troubleshooting

### "Comando não encontrado"

Se após instalar você receber "comando não encontrado", adicione ao seu shell rc:

**Para bash** (`~/.bashrc` ou `~/.bash_profile`):
```bash
export PATH="$PATH:$HOME/.local/bin"
# ou
export PATH="$PATH:/usr/local/bin"
```

**Para zsh** (`~/.zshrc`):
```bash
export PATH="$PATH:$HOME/.local/bin"
```

### Problemas de Permissão

```bash
# Verificar permissões
ls -la $(which ea11ctl)

# Reparar permissões
chmod +x $(which ea11ctl)
```

### Falha ao Baixar

Se houver problemas de conectividade ao GitHub:

1. Verifique sua conexão de internet
2. Tente usando a flag `--force`:
   ```bash
   ea11ctl self-update --force
   ```
3. Instale manualmente seguindo os passos do repositório

## Desenvolvimento

### Executar localmente

```bash
# Clonar o repositório
git clone https://github.com/A11yDevs/emacs-a11y-vm.git
cd emacs-a11y-vm/cli

# Testar sem instalar
./ea11ctl help
./ea11ctl version

# Simular instalação
./install.sh
```

### Testes

```bash
# Executar suite de testes
cd ../tests
pytest -v

# Teste específico
pytest -v tests/test_*.py
```

## Compatibilidade

| OS | Status | Notas |
|-------|--------|-------|
| macOS 10.15+ | ✅ Suportado | Intel e Apple Silicon (M1+) |
| Ubuntu 20.04+ | ✅ Suportado | Debian 11+, Raspberry Pi OS |
| Debian 11+ | ✅ Suportado | |
| Fedora/CentOS | ⚠️ Parcial | Bash disponível, adapte comandos |
| Alpine Linux | ⚠️ Parcial | Verifique dependências (sh vs bash) |
| WSL (Windows) | ✅ Suportado | Como Linux (Ubuntu ou Debian) |

## Licença

GNU General Public License v3.0

Ver [LICENSE](../../LICENSE) para detalhes.

## Suporte

Para reportar problemas ou sugerir melhorias:
- [Issues do GitHub](https://github.com/A11yDevs/emacs-a11y-vm/issues)
- [Discussions](https://github.com/A11yDevs/emacs-a11y-vm/discussions)
