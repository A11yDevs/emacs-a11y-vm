# ==============================================================================
# install-release-vm.ps1 — Baixa release do GitHub e cria VM no VirtualBox
#
# Exemplo (última release):
#   .\scripts\install-release-vm.ps1
#
# Exemplo (tag específica):
#   .\scripts\install-release-vm.ps1 -Tag v1.0.0
#
# Exemplo (outro repositório):
#   .\scripts\install-release-vm.ps1 -Owner A11yDevs -Repo emacs-a11y-vm
#
# ==============================================================================
# SOLUÇÃO DE PROBLEMAS - "Script não está assinado digitalmente"
# ==============================================================================
# Se você receber erro sobre assinatura digital, use uma dessas opções:
#
# Opção 1 (mais simples):
#   PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1
#
# Opção 2 (desbloquear arquivo):
#   Unblock-File .\scripts\install-release-vm.ps1
#   .\scripts\install-release-vm.ps1
#
# Opção 3 (alterar política permanentemente):
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#   .\scripts\install-release-vm.ps1
# ==============================================================================

[CmdletBinding()]
param(
    [string]$Owner = "A11yDevs",
    [string]$Repo = "emacs-a11y-vm",
    [string]$Tag = "latest",
    [string]$VMName = "debian-a11y",
    [int]$RAM = 2048,
    [int]$CPUs = 2,
    [int]$SSHPort = 2222,
    [string]$OutputDir = "releases",
    [string]$AudioDriver = "",
    [switch]$KeepOldVM,
    [switch]$Help
)

# Impede que o script feche a janela imediatamente em caso de erro
$ErrorActionPreference = "Stop"

function Pause-BeforeExit {
    param([int]$ExitCode = 0)
    Write-Host ""
    Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit $ExitCode
}

function Show-Usage {
    @"
Uso:
    .\scripts\install-release-vm.ps1 [opções]

Opções:
  -Owner <owner>          Dono do repositório no GitHub (padrão: A11yDevs)
  -Repo <repo>            Nome do repositório (padrão: emacs-a11y-vm)
  -Tag <tag|latest>       Tag da release (padrão: latest)
  -VMName <nome>          Nome da VM no VirtualBox (padrão: debian-a11y)
  -RAM <mb>               RAM da VM em MB (padrão: 2048)
  -CPUs <n>               Número de CPUs (padrão: 2)
  -SSHPort <porta>        Porta SSH no host (NAT PF host:guest 2222:22)
  -OutputDir <dir>        Pasta para baixar o VMDK (padrão: .\releases)
  -AudioDriver <driver>   Driver de áudio do VirtualBox (auto por padrão)
  -KeepOldVM              Não remove VM existente com o mesmo nome
  -Help                   Mostra esta ajuda

Fluxo:
  1) Busca release via API GitHub
  2) Baixa asset .vmdk
  3) Cria VM VirtualBox (Debian_64)
  4) Anexa disco VMDK e habilita NAT + SSH forwarding
"@
}

function Write-Error-Exit {
    param([string]$Message)
    Write-Host ""
    Write-Host "Erro: $Message" -ForegroundColor Red
    Pause-BeforeExit 1
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-AudioDriver {
    if ($AudioDriver) {
        return $AudioDriver
    }
    
    # Windows usa dsound por padrão
    return "dsound"
}

if ($Help) {
    Show-Usage
    Pause-BeforeExit 0
}

# Capturar erros não tratados
trap {
    Write-Host ""
    Write-Host "Erro não tratado: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Pause-BeforeExit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Instalador de VM Debian A11y via GitHub Release" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Informações do ambiente:"
Write-Host "  Usuário: $env:USERNAME"
Write-Host "  Diretório atual: $(Get-Location)"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
Write-Host ""

# Verificar dependências
Write-Host "==> Verificando dependências..."
if (-not (Test-Command "VBoxManage")) {
    Write-Host ""
    Write-Host "VirtualBox não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "O VBoxManage não está disponível no PATH." -ForegroundColor Yellow
    Write-Host "Certifique-se de que o VirtualBox está instalado." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Locais comuns de instalação:" -ForegroundColor Cyan
    Write-Host "  C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
    Write-Host "  C:\Program Files (x86)\Oracle\VirtualBox\VBoxManage.exe"
    Write-Host ""
    Pause-BeforeExit 1
}

$vboxVersion = VBoxManage --version 2>&1
Write-Host "    VirtualBox encontrado: $vboxVersion" -ForegroundColor Green


# Criar diretório de saída se não existir
# Tenta usar o caminho relativo ao script, senão usa o diretório atual
if ($OutputDir.StartsWith(".\") -or $OutputDir.StartsWith("./") -or -not [System.IO.Path]::IsPathRooted($OutputDir)) {
    if ($PSScriptRoot) {
        # Executando de um arquivo .ps1
        $OutputDirPath = Join-Path $PSScriptRoot ".." $OutputDir
    } else {
        # Executando via iex/download direto
        $OutputDirPath = Join-Path (Get-Location) $OutputDir
    }
} else {
    $OutputDirPath = $OutputDir
}

Write-Host "==> Verificando diretório de saída: $OutputDirPath"

if (-not (Test-Path $OutputDirPath)) {
    try {
        New-Item -ItemType Directory -Path $OutputDirPath -Force -ErrorAction Stop | Out-Null
        Write-Host "    Diretório criado com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "    Falha ao criar em: $OutputDirPath" -ForegroundColor Yellow
        Write-Host "    Tentando usar diretório temporário..." -ForegroundColor Yellow
        
        # Fallback: usar pasta temporária do usuário
        $OutputDirPath = Join-Path $env:USERPROFILE "Downloads\emacs-a11y-vm-releases"
        
        try {
            if (-not (Test-Path $OutputDirPath)) {
                New-Item -ItemType Directory -Path $OutputDirPath -Force -ErrorAction Stop | Out-Null
            }
            Write-Host "    Usando: $OutputDirPath" -ForegroundColor Green
        } catch {
            Write-Error-Exit "Sem permissão para criar diretórios. Erro: $($_.Exception.Message)"
        }
    }
}

# Determinar driver de áudio
$AudioDriverUsed = Get-AudioDriver

# Construir URL da API
if ($Tag -eq "latest") {
    $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
} else {
    $ApiUrl = "https://api.github.com/repos/$Owner/$Repo/releases/tags/$Tag"
}

Write-Host "==> Consultando release: $Owner/$Repo ($Tag)"

try {
    # Configurar TLS 1.2 para downloads seguros
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $ReleaseJson = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing
} catch {
    Write-Error-Exit "Falha ao consultar release no GitHub: $_"
}

# Encontrar asset .vmdk
$VmdkAsset = $ReleaseJson.assets | Where-Object { $_.name -like "*.vmdk" } | Select-Object -First 1

if (-not $VmdkAsset) {
    Write-Error-Exit "Nenhum asset .vmdk encontrado na release."
}

$AssetUrl = $VmdkAsset.browser_download_url
$AssetName = $VmdkAsset.name
$ResolvedTag = $ReleaseJson.tag_name

$VmdkPath = Join-Path $OutputDirPath $AssetName

Write-Host "==> Baixando asset: $AssetName"
Write-Host "    URL: $AssetUrl"
Write-Host "    Destino: $VmdkPath"

try {
    # Verificar se temos permissão de escrita no diretório
    $testFile = Join-Path $OutputDirPath ".test_write_permission"
    try {
        [System.IO.File]::WriteAllText($testFile, "test")
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    } catch {
        throw "Sem permissão de escrita no diretório: $OutputDirPath"
    }
    
    # Baixar o arquivo com barra de progresso
    Write-Host "    Baixando... (isso pode levar alguns minutos)"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $AssetUrl -OutFile $VmdkPath -UseBasicParsing
    $ProgressPreference = 'Continue'
    
    if (-not (Test-Path $VmdkPath)) {
        Write-Error-Exit "Download falhou: arquivo não foi criado em $VmdkPath"
    }
    
    $fileSize = (Get-Item $VmdkPath).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    Write-Host "    Download completo: $fileSizeMB MB" -ForegroundColor Green
} catch {
    Write-Error-Exit "Download falhou: $($_.Exception.Message)"
}

Write-Host "==> Verificando VM existente: $VMName"

# Verificar se VM existe
$VMExists = $false
try {
    $null = VBoxManage showvminfo $VMName 2>&1
    $VMExists = ($LASTEXITCODE -eq 0)
} catch {
    $VMExists = $false
}

if ($VMExists) {
    if ($KeepOldVM) {
        Write-Error-Exit "VM '$VMName' já existe e -KeepOldVM foi usado. Escolha outro -VMName."
    }
    Write-Host "    VM existente encontrada, removendo..." -ForegroundColor Yellow
    try {
        $null = VBoxManage unregistervm $VMName --delete 2>&1
        Write-Host "    VM antiga removida com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "    Aviso: Falha ao remover VM antiga (pode não existir)" -ForegroundColor Yellow
    }
} else {
    Write-Host "    Nenhuma VM existente com esse nome" -ForegroundColor Green
}

Write-Host "==> Criando VM '$VMName'"
$output = VBoxManage createvm --name $VMName --ostype Debian_64 --register 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao criar VM. VBoxManage disse: $output"
}

Write-Host "==> Driver de áudio selecionado: $AudioDriverUsed"

# Configuração base: VM textual, áudio AC97 para acessibilidade, NAT com SSH forwarding
$output = VBoxManage modifyvm $VMName `
    --memory $RAM `
    --cpus $CPUs `
    --ioapic on `
    --boot1 disk --boot2 none --boot3 none --boot4 none `
    --audio-driver $AudioDriverUsed `
    --audio-controller ac97 `
    --audio-enabled on `
    --audio-out on `
    --nic1 nat `
    --natpf1 "ssh,tcp,127.0.0.1,$SSHPort,,22" `
    --graphicscontroller vmsvga `
    --vram 16 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao configurar VM. VBoxManage disse: $output"
}

$output = VBoxManage storagectl $VMName --name "SATA" --add sata --controller IntelAhci 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao adicionar controlador SATA. VBoxManage disse: $output"
}

# Converter caminho para formato absoluto
$VmdkAbsolutePath = (Resolve-Path $VmdkPath).Path

$output = VBoxManage storageattach $VMName `
    --storagectl "SATA" --port 0 --device 0 `
    --type hdd --medium $VmdkAbsolutePath 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao anexar disco VMDK. VBoxManage disse: $output"
}

Write-Host "==> Iniciando VM em modo headless"
$output = VBoxManage startvm $VMName --type headless 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao iniciar VM. VBoxManage disse: $output"
}

# Mensagem de sucesso
Write-Host ""
Write-Host "✔ VM criada e iniciada com sucesso." -ForegroundColor Green
Write-Host ""
Write-Host "Release: $Owner/$Repo ($ResolvedTag)"
Write-Host "Disco:   $VmdkPath"
Write-Host "VM:      $VMName"
Write-Host "SSH:     ssh -p $SSHPort a11ydevs@localhost"
Write-Host ""
Write-Host "Credenciais padrão esperadas (release atual):"
Write-Host "  usuário: a11ydevs"
Write-Host "  senha:   a11ydevs"
Write-Host ""

Pause-BeforeExit 0
