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
ea11ctl vm list
```

#### Iniciar VM

```bash
ea11ctl vm start

# Com nome específico
ea11ctl vm start -n debian-a11y

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

#### Remover VM

```bash
# Remove apenas registro/estado local da VM
ea11ctl vm remove -n debian-a11y

# Remove tambem disco de dados (/home)
ea11ctl vm remove -n debian-a11y --data --yes

# Remove tambem imagem de sistema
ea11ctl vm remove -n debian-a11y --system --yes

# Remocao completa (registro + dados + sistema)
ea11ctl vm remove -n debian-a11y --all --yes
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
# Ver configuração atual
ea11ctl vm host-share list

# Unix/macOS: compartilhar via SSH
ea11ctl vm host-share set --mode ssh --ssh-user "$USER" --ssh-path "$HOME"

# Windows host (via Bash): compartilhar via CIFS
ea11ctl vm host-share set --mode cifs --smb-server 10.0.2.2 --smb-share Users --smb-user "$USER" --smb-password '<senha>'

# Limpar configuração
ea11ctl vm host-share clear
```

#### Instalar VM Release

```bash
ea11ctl vm install

# Com argumentos adicionais
ea11ctl vm install -n debian-a11y --no-gui
```

#### Configuração de runtime do QEMU

```bash
# Mostrar configuração efetiva atual
ea11ctl vm config show

# Caminho do arquivo de configuração
ea11ctl vm config path

# Resetar para defaults seguros
ea11ctl vm config reset
```

Arquivo usado:

```text
~/.emacs-a11y-vm/qemu/config.env
```

#### Otimização automática (com backup)

```bash
# Aplica perfil otimizado por sistema operacional host
ea11ctl vm optimize

# Depois confira o resultado
ea11ctl vm config show
```

O comando `optimize` cria backup automático de `config.env` antes de alterar os valores.

Perfil aplicado (base):

- Linux host: `-enable-kvm`, `-cpu host`, `-smp 4`, `-m 4096`
- macOS host: `-accel hvf`, `-cpu host`, `-smp 4`, `-m 4096`
- Windows host (bash): `-accel whpx`, `-smp 4`, `-m 4096`

Além disso, aplica defaults de baixa latência para I/O:

- `-drive ... if=virtio,cache=writeback,discard=unmap`
- `-device virtio-net-pci`
- `-device virtio-vga`

### Desinstalar CLI

```bash
# Remove apenas a CLI instalada
ea11ctl uninstall --yes

# Remove CLI e todo estado local (VMs, discos e logs)
ea11ctl uninstall --purge-state --yes
```

## Configuração Padrão

| Opção | Valor Padrão |
|-------|--------------|
| VM | debian-a11y |
| Usuário SSH | a11ydevs |
| Porta SSH | 2222 |

Observacao: a CLI e QEMU-only; a opcao de backend foi removida.

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
- QEMU
- OpenSSH (incluso no sistema)

### Linux
- bash 4.0+
- curl ou wget
- QEMU
- OpenSSH
- qemu-system-x86_64 (para QEMU)

### Instalação de Requisitos

#### macOS
```bash
# Usando Homebrew
brew install qemu              # Para QEMU
```

#### Debian/Ubuntu
```bash
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
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
