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

Há dois scripts disponíveis para baixar uma release de VM emacs-a11y do GitHub e instalar no VirtualBox a partir de um disco VMDK pronto:

- **Linux/macOS**: [scripts/install-release-vm.sh](scripts/install-release-vm.sh)
- **Windows**: [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1)

Esse fluxo:

- consulta a API de releases do GitHub
- baixa automaticamente o asset `.vmdk`
- cria uma VM Debian no VirtualBox
- anexa o disco baixado
- configura rede NAT com redirecionamento de porta para SSH

Use este caminho quando você quiser subir rapidamente uma VM já pronta, sem passar pela instalação do Debian.

#### Linux/macOS (Bash)

Exemplo com a última release:

```bash
./scripts/install-release-vm.sh
```

Exemplo com uma tag específica:

```bash
./scripts/install-release-vm.sh --tag v1.0.0
```

No macOS, se necessário, force explicitamente o CoreAudio:

```bash
./scripts/install-release-vm.sh --audio-driver coreaudio
```

**Execução direta via URL (sem clonar o repositório):**

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.sh | bash
```

Com parâmetros customizados:

```bash
curl -fsSL https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.sh | bash -s -- --tag v1.0.0 --ram 4096
```

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
│      VMDK           │      VDI         │
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

- **Disco 1 (Sistema VMDK)**: Debian + Emacs + espeakup (da release GitHub)
- **Disco 2 (Dados VDI)**: `/home` completo com suas configurações e projetos

Suas configurações do Emacs (`.emacs.d`), dotfiles (`.bashrc`, `.profile`), projetos e arquivos pessoais ficam no **disco de dados** e são **automaticamente preservados** em upgrades.

**Customização:**

```bash
# Aumentar tamanho do disco de dados (padrão: 10GB)
./scripts/install-release-vm.sh --user-data-size 20480  # 20GB

# PowerShell (Windows)
.\scripts\install-release-vm.ps1 -UserDataSize 20480
```

**Documentação detalhada:**

- [docs/architecture.md](docs/architecture.md) - Arquitetura completa do sistema de dois discos
- [docs/customization-guide.md](docs/customization-guide.md) - Como personalizar Emacs e sistema com segurança
- [docs/upgrade-guide.md](docs/upgrade-guide.md) - Como atualizar para novas versões preservando dados

## Qual opção usar?

- Use [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md) se quiser aprender e executar a instalação manualmente.
- Use [docs/generate-vm.md](docs/generate-vm.md) e [scripts/setup-vm.sh](scripts/setup-vm.sh) se quiser gerar a VM automaticamente a partir de uma ISO do Debian.
- Use [scripts/install-release-vm.sh](scripts/install-release-vm.sh) (Linux/macOS) ou [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1) (Windows) se quiser instalar rapidamente uma VM pronta publicada como release no GitHub.

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
