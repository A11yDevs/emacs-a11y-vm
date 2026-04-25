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

**⚠️ Importante**: Execute o script a partir do PowerShell (não clique duas vezes no arquivo). Abra o PowerShell e navegue até a pasta do projeto antes de executar.

Exemplo com a última release:

```powershell
.\scripts\install-release-vm.ps1
```

Exemplo com uma tag específica:

```powershell
.\scripts\install-release-vm.ps1 -Tag v1.0.0
```

Para ver todas as opções disponíveis:

```powershell
.\scripts\install-release-vm.ps1 -Help
```

**Execução direta via URL (sem clonar o repositório):**

```powershell
iex (iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1' -UseBasicParsing).Content
```

Com parâmetros customizados:

```powershell
& ([scriptblock]::Create((iwr 'https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1' -UseBasicParsing).Content)) -Tag v1.0.0 -RAM 4096
```

**Solução de problemas no Windows:**

Se você encontrar erros de política de execução, execute:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```


#### Acesso via SSH

Após criar a VM, o acesso padrão por SSH é:

```bash
ssh -p 2222 a11ydevs@localhost
```

Observação: este fluxo ainda não possui um arquivo `.md` dedicado. No momento, a referência principal são os próprios scripts [scripts/install-release-vm.sh](scripts/install-release-vm.sh) e [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1), além desta seção do README.

## Qual opção usar?

- Use [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md) se quiser aprender e executar a instalação manualmente.
- Use [docs/generate-vm.md](docs/generate-vm.md) e [scripts/setup-vm.sh](scripts/setup-vm.sh) se quiser gerar a VM automaticamente a partir de uma ISO do Debian.
- Use [scripts/install-release-vm.sh](scripts/install-release-vm.sh) (Linux/macOS) ou [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1) (Windows) se quiser instalar rapidamente uma VM pronta publicada como release no GitHub.

## Arquivos principais do repositório

- [docs/debian-a11y-minimal-vm.md](docs/debian-a11y-minimal-vm.md): tutorial manual de criação da VM acessível.
- [docs/generate-vm.md](docs/generate-vm.md): documentação do fluxo automatizado com [scripts/setup-vm.sh](scripts/setup-vm.sh).
- [docs/github-releases.md](docs/github-releases.md): documentação complementar sobre distribuição e publicação de releases no GitHub, incluindo o papel de [.github](.github) e [packer](packer).
- [scripts/setup-vm.sh](scripts/setup-vm.sh): script para criação automática da VM a partir de uma ISO Debian.
- [scripts/install-release-vm.sh](scripts/install-release-vm.sh): script Bash para baixar e instalar uma VM pronta via release do GitHub (Linux/macOS).
- [scripts/install-release-vm.ps1](scripts/install-release-vm.ps1): script PowerShell para baixar e instalar uma VM pronta via release do GitHub (Windows).
- [.env.example](.env.example): arquivo de exemplo para configurar a geração automática da VM.
- [packer](packer): arquivos relacionados à geração da imagem da VM.
- [releases](releases): diretório usado para armazenar discos e artefatos baixados ou gerados.

## Distribuição e releases

Para entender como a VM é construída no CI e publicada no GitHub Releases, consulte:

- [docs/github-releases.md](docs/github-releases.md)
