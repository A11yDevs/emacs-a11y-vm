# emacs-a11y-vm

Repositório com materiais para criar, gerar ou instalar uma máquina virtual Debian acessível com Emacs no VirtualBox.

O projeto atualmente oferece três formas principais de uso:

1. Criação manual de uma VM Debian acessível com VirtualBox.
2. Geração automática de uma VM com um script bash.
3. Instalação de uma VM pronta a partir de uma release publicada no GitHub.

## Opções disponíveis

### 1. Criação manual: [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md)

O arquivo [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md) é um tutorial passo a passo para criar manualmente uma VM Debian mínima e acessível no VirtualBox.

Esse guia cobre:

- criação da VM no VirtualBox
- instalação textual do Debian com suporte à fala
- configuração básica de rede e acesso por SSH
- instalação de pacotes essenciais para acessibilidade e uso com Emacs

Use este caminho se você quiser controlar cada etapa da instalação e entender o processo completo.

### 2. Geração automática: [docs/generate-vm.md](docs/generate-vm.md)

O arquivo [docs/generate-vm.md](docs/generate-vm.md) documenta o uso do script [scripts/setup-vm.sh](scripts/setup-vm.sh), que automatiza a criação de uma VM Debian com emacs-a11y.

Esse fluxo:

- lê parâmetros de um arquivo `.env`
- cria a VM automaticamente no VirtualBox
- configura instalação desassistida do Debian
- instala um sistema mínimo, textual e com síntese de voz
- instala `espeakup`, `sudo`, `emacs` e `openssh-server`

Use este caminho se você quiser reproduzir rapidamente uma VM acessível sem executar manualmente todos os passos do instalador.

Exemplo:

```bash
cp .env.example .env
./scripts/setup-vm.sh
```

### 3. Instalação a partir de release

O script [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1) (Windows) baixa uma release de VM emacs-a11y do GitHub e instala no VirtualBox a partir de um disco QCOW2 que é convertido para VDI.

Esse fluxo:

- consulta a API de releases do GitHub
- baixa automaticamente o asset `.qcow2`
- converte QCOW2 para VDI nativo do VirtualBox (~5-10 min, apenas quando versão muda)
- cria uma VM Debian no VirtualBox
- anexa o disco convertido
- configura rede bridge (padrão) ou NAT (opcional, com port forwarding para SSH)

Use este caminho quando você quiser subir rapidamente uma VM já pronta, sem passar pela instalação do Debian.

#### Windows (PowerShell)

**⚠️ Importante**: O Windows pode bloquear a execução de scripts não assinados. Use o comando com `-ExecutionPolicy Bypass` ou veja as soluções na seção de problemas abaixo.

**Método 1: Usando o arquivo .cmd (mais fácil)**

Execute o arquivo `.cmd` que faz o bypass automaticamente:

```cmd
.\scripts\install-release-vm.cmd
```

Ou clique duas vezes no arquivo [scripts/install-release-vm.cmd](scripts/install-release-vm.cmd) no Windows Explorer.

**Método 2: Usando PowerShell diretamente**

Exemplo com a última release:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1
```

Exemplo com uma tag específica:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -Tag v1.0.0
```

Exemplo com parâmetros customizados:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -RAM 4096 -CPUs 4 -SSHPort 3333
```

Para ver todas as opções disponíveis:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -Help
```

**Execução direta via URL (sem clonar o repositório):**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1' -UseBasicParsing).Content
```

Com parâmetros customizados:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
& ([scriptblock]::Create((iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1' -UseBasicParsing).Content)) -Tag v1.0.0 -RAM 4096
```

### 4. CLI global no Windows: `ea11ctl`

Também é possível instalar a CLI `ea11ctl` para usar comandos da VM em qualquer diretório/shell do Windows.

Instalação remota:

```powershell
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/cli/install.ps1' -UseBasicParsing).Content
```

Após instalar (abra um novo terminal), você pode usar:

```powershell
ea11ctl vm install
ea11ctl vm list
ea11ctl vm start
ea11ctl vm stop
ea11ctl vm close
ea11ctl vm diagnose --try-start
ea11ctl vm status
ea11ctl vm ssh
ea11ctl vm share-folder list
ea11ctl vm share-folder add --path "C:\\Users\\seu-usuario"
ea11ctl self-update
```

Ajuda da CLI:

```powershell
ea11ctl help
```

Atualizar a CLI instalada (sem repetir `iex (...)`):

```powershell
ea11ctl self-update
```

Checar se existe versão mais nova da CLI:

```powershell
ea11ctl version --check-update
```

Forçar atualização:

```powershell
ea11ctl self-update --force
```

Versionamento da CLI `ea11ctl`:

- A versão atual da CLI fica em `cli/VERSION`.
- A cada nova funcionalidade ou correção na CLI, a versão deve ser incrementada (por exemplo: `0.1.0` -> `0.1.1`).
- Versão atual: `0.1.4`.

**Solução de problemas no Windows:**

**Erro: "O script não está assinado digitalmente"**

Esse é o erro mais comum no Windows. Há várias soluções:

**Solução 1: Executar com bypass (mais simples)**

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1
```

**Solução 2: Desbloquear o arquivo**

```powershell
Unblock-File .\scripts\install-release-vm.ps1
.\scripts\install-release-vm.ps1
```

**Solução 3: Alterar política de execução (permanente para o usuário)**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\install-release-vm.ps1
```

**Solução 4: Alterar política de execução (temporária para a sessão)**

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
.\scripts\install-release-vm.ps1
```

**Com parâmetros customizados:**

```powershell
PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -Tag v1.0.0 -RAM 4096
```

**Outros problemas:**

Se você encontrar erros de `UnauthorizedAccess`:

1. **Execute o PowerShell como Administrador** (clique com botão direito > "Executar como Administrador")

2. **Navegue para uma pasta onde você tem permissão de escrita**:
   ```powershell
   cd $env:USERPROFILE\Downloads
   ```

3. **Execute o script especificando um diretório de saída**:
   ```powershell
   PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1 -OutputDir "$env:USERPROFILE\Downloads\emacs-a11y-vm"
   ```

4. **Verifique se o VirtualBox está instalado corretamente**:
   ```powershell
   VBoxManage --version
   ```

   **Nota**: O script busca automaticamente o VBoxManage nos locais comuns de instalação do Windows (`C:\Program Files\Oracle\VirtualBox`). Se você quiser adicionar permanentemente o VirtualBox ao PATH do sistema:

   a. Abra "Configurações do Sistema" (Win + Pause)
   b. Clique em "Configurações avançadas do sistema" > "Variáveis de Ambiente"
   c. Na seção "Variáveis do sistema", selecione "Path" e clique em "Editar"
   d. Adicione o caminho: `C:\Program Files\Oracle\VirtualBox`
   e. Clique em "OK" para salvar

   Após isso, reinicie o PowerShell para que as mudanças tenham efeito.


#### Acesso via SSH

Após criar a VM, o acesso padrão por SSH é:

```bash
ssh -p 2222 a11ydevs@localhost
```

### Arquitetura de Dois Discos

A VM usa uma **arquitetura de dois discos** para separar sistema e dados do usuário:

```
┌─────────────────────────────────────┐
│  Disco 1 (Sistema)  │  Disco 2 (Dados) │
│      VDI            │      VDI         │
│   (Imutável)        │  (Persistente)   │
└─────────────────────────────────────┘
      Substituído           Preservado
      em upgrades          em upgrades
```

**Benefícios:**

✅ **Liberdade de customização** - Customize Emacs, dotfiles e instale pacotes sem restrições  
✅ **Upgrades seguros** - Atualize o sistema base sem perder suas configurações  
✅ **Backup simples** - Copie apenas o disco de dados (VDI)  
✅ **Rollback fácil** - Troque versões do sistema sem afetar seus dados  

**Discos:**

- **Disco 1 (Sistema VDI)**: Debian + Emacs + espeakup (da release GitHub, convertido de QCOW2)
- **Disco 2 (Dados VDI)**: `/home` completo com suas configurações e projetos

Suas configurações do Emacs (`.emacs.d`), dotfiles (`.bashrc`, `.profile`), projetos e arquivos pessoais ficam no **disco de dados** e são **automaticamente preservados** em upgrades.

**Verificar versão instalada:**

```bash
# Conecte à VM via SSH (se modo NAT)
ssh -p 2222 a11ydevs@localhost

# Ou acesse diretamente no console (modo bridge ou GUI)
# Execute o comando:
emacs-a11y-version
```

Esse comando mostra:
- Versão da release (ex: 2.0.1)
- Data do build
- Configuração de voz (espeakup)
- Status dos serviços de acessibilidade
- Vozes disponíveis

**Detecção inteligente de versão:**

O script `install-release-vm.ps1` usa **comparação por versão** (não por tamanho de arquivo) para evitar downloads desnecessários:

1. **Primeira instalação**: Baixa o QCOW2, converte para VDI e cria arquivo `.version` ao lado (ex: `debian-a11ydevs-system.vdi.version`)
2. **Reinstalação mesma versão**: Detecta versão igual no `.version`, **pula download e conversão** ✅
3. **Upgrade (nova versão)**: Detecta versão diferente, baixa nova release 🔄
4. **Forçar download**: Use `-ForceDownload` (PS1) ou `--force-download` (bash) para ignorar `.version` e baixar sempre

**Por que comparação por versão?**

Comparar tamanhos de arquivo não funciona com discos de sistema porque:
- Formato dinâmico cresce com uso
- Ao inicializar a VM, logs e estado alteram o tamanho do arquivo
- Ao inicializar a VM, logs e estado alteram o tamanho do arquivo
- Mesmo sem mudanças do usuário, o tamanho muda

Com comparação por versão:
- ✅ Não baixa/converte desnecessariamente
- ✅ Funciona mesmo após VM ser inicializada (disco alterado)
- ✅ Lógica mais confiável e previsível
- ✅ Suporta upgrade e downgrade de versões

**Configuração de rede:**

Por padrão, as VMs são criadas em **modo bridge** (acesso direto na rede local):

```powershell
# Bridge (padrão)
.\scripts\install-release-vm.ps1

# Usar NAT com port forwarding (SSH localhost:2222 -> VM:22)
.\scripts\install-release-vm.ps1 -NetworkMode nat
```

**Customização:**

```powershell
# Aumentar tamanho do disco de dados (padrão: 10GB)
.\scripts\install-release-vm.ps1 -UserDataSize 20480  # 20GB
```

**Documentação detalhada:**

- [docs/architecture.md](docs/architecture.md) - Arquitetura completa do sistema de dois discos
- [docs/customization-guide.md](docs/customization-guide.md) - Como personalizar Emacs e sistema com segurança
- [docs/upgrade-guide.md](docs/upgrade-guide.md) - Como atualizar para novas versões preservando dados

## Qual opção usar?

- Use [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md) se quiser aprender e executar a instalação manualmente.
- Use [docs/generate-vm.md](docs/generate-vm.md) e [scripts/setup-vm.sh](scripts/setup-vm.sh) se quiser gerar a VM automaticamente a partir de uma ISO do Debian.
- Use [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1) (Windows) se quiser instalar rapidamente uma VM pronta publicada como release no GitHub.

## Problemas Conhecidos

### Erro 404 ao instalar pacotes emacs-a11y via APT

**Sintoma:**

Ao tentar instalar `emacs-a11y-config` ou `emacs-a11y-launchers` dentro da VM:

```bash
sudo apt install -y emacs-a11y-config emacs-a11y-launchers
```

Você recebe erros 404:

```
Erro: Falhou ao obter https://a11ydevs.github.io/emacs-a11y/debian/pages/debian/pool/main/emacs-a11y-config_0.1.0_all.deb  404  Not Found
```

**Causa:**

A URL do repositório APT está incorreta, com `/pages/debian` duplicado no caminho.

**Solução:**

Dentro da VM, corrija a URL do repositório:

**Opção 1: Via sed (mais rápida):**

```bash
sudo sed -i 's|/debian/pages/debian|/debian|g' /etc/apt/sources.list.d/emacs-a11y.list
sudo apt update
sudo apt install -y emacs-a11y-config emacs-a11y-launchers
```

**Opção 2: Via editor de texto:**

```bash
# 1. Editar o arquivo do repositório
sudo nano /etc/apt/sources.list.d/emacs-a11y.list

# 2. Procure a linha com a URL incorreta e corrija:
# ANTES: deb https://a11ydevs.github.io/emacs-a11y/debian/pages/debian stable main
# DEPOIS: deb https://a11ydevs.github.io/emacs-a11y/debian stable main

# 3. Salvar (Ctrl+O, Enter, Ctrl+X)

# 4. Atualizar e instalar
sudo apt update
sudo apt install -y emacs-a11y-config emacs-a11y-launchers
```

**Nota:** Este é um problema temporário do repositório APT `emacs-a11y`. O problema será corrigido na fonte em versões futuras da VM.

## Arquivos principais do repositório

- [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md): tutorial manual de criação da VM acessível.
- [docs/generate-vm.md](docs/generate-vm.md): documentação do fluxo automatizado com [scripts/setup-vm.sh](scripts/setup-vm.sh).
- [docs/github-releases.md](docs/github-releases.md): documentação complementar sobre distribuição e publicação de releases no GitHub, incluindo o papel de [.github](.github) e [packer](packer).
- [docs/architecture.md](docs/architecture.md): arquitetura de dois discos (sistema imutável + dados persistentes).
- [docs/customization-guide.md](docs/customization-guide.md): guia para personalizar Emacs, dotfiles e sistema com segurança.
- [docs/upgrade-guide.md](docs/upgrade-guide.md): como atualizar a VM preservando configurações e dados.
- [scripts/setup-vm.sh](scripts/setup-vm.sh): script para criação automática da VM a partir de uma ISO Debian.
- [scripts/install-release-vm.sh](scripts/install-release-vm.sh): script Bash para baixar e instalar uma VM pronta via release do GitHub (Linux/macOS).
- [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1): script PowerShell para baixar e instalar uma VM pronta via release do GitHub (Windows).
- [scripts/install-release-vm.cmd](scripts/install-release-vm.cmd): wrapper batch para executar o script PowerShell sem problemas de política de execução (Windows).
- [.env.example](.env.example): arquivo de exemplo para configurar a geração automática da VM.
- [packer](packer): arquivos relacionados à geração da imagem da VM.
- [releases](releases): diretório usado para armazenar discos e artefatos baixados ou gerados.

## Distribuição e releases

Para entender como a VM é construída no CI e publicada no GitHub Releases, consulte:

- [docs/github-releases.md](docs/github-releases.md)
