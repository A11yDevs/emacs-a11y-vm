# ==============================================================================
# install-release-vm.ps1 - Baixa release do GitHub e cria VM no VirtualBox
#
# Exemplo (ultima release):
#   .\scripts\install-release-vm.ps1
#
# Exemplo (tag especifica):
#   .\scripts\install-release-vm.ps1 -Tag v1.0.0
#
# Exemplo (outro repositorio):
#   .\scripts\install-release-vm.ps1 -Owner A11yDevs -Repo emacs-a11y-vm
#
# ==============================================================================
# SOLUCAO DE PROBLEMAS - "Script nao esta assinado digitalmente"
# ==============================================================================
# Se voce receber erro sobre assinatura digital, use uma dessas opcoes:
#
# Opcao 1 (mais simples):
#   PowerShell -ExecutionPolicy Bypass -File .\scripts\install-release-vm.ps1
#
# Opcao 2 (desbloquear arquivo):
#   Unblock-File .\scripts\install-release-vm.ps1
#   .\scripts\install-release-vm.ps1
#
# Opcao 3 (alterar politica permanentemente):
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
    [int]$UserDataSize = 10240,
    [switch]$PreserveUserData,
    [switch]$KeepOldVM,
    [switch]$ForceDownload,
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
    .\scripts\install-release-vm.ps1 [opcoes]

Opcoes:
  -Owner <owner>          Dono do repositorio no GitHub (padrao: A11yDevs)
  -Repo <repo>            Nome do repositorio (padrao: emacs-a11y-vm)
  -Tag <tag|latest>       Tag da release (padrao: latest)
  -VMName <nome>          Nome da VM no VirtualBox (padrao: debian-a11y)
  -RAM <mb>               RAM da VM em MB (padrao: 2048)
  -CPUs <n>               Numero de CPUs (padrao: 2)
  -SSHPort <porta>        Porta SSH no host (NAT PF host:guest 2222:22)
  -OutputDir <dir>        Pasta para baixar o VMDK (padrao: .\releases)
  -AudioDriver <driver>   Driver de audio do VirtualBox (auto por padrao)
  -UserDataSize <mb>      Tamanho do disco de dados em MB (padrao: 10240 = 10GB)
  -PreserveUserData       Preserva disco de dados de VM existente (padrao: auto)
  -KeepOldVM              Nao remove VM existente com o mesmo nome
  -ForceDownload          Forca re-download mesmo se arquivo ja existe
  -Help                   Mostra esta ajuda

Arquitetura de Discos:
  Disco 1 (Sistema): VMDK imutavel da release (substituido em upgrades)
  Disco 2 (Dados):   VDI persistente local em /home (preservado em upgrades)

Fluxo:
  1) Busca release via API GitHub
  2) Baixa asset .vmdk (disco de sistema)
  3) Cria VM VirtualBox (Debian_64)
  4) Anexa disco VMDK (sistema) e VDI (dados do usuario)
  5) Habilita NAT + SSH forwarding
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
    
    # Usar 'default' permite ao VirtualBox escolher o melhor driver automaticamente
    return "default"
}

if ($Help) {
    Show-Usage
    Pause-BeforeExit 0
}

# Capturar erros nao tratados
trap {
    Write-Host ""
    Write-Host "Erro nao tratado: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    Pause-BeforeExit 1
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Instalador de VM Debian A11y via GitHub Release" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Informacoes do ambiente:"
Write-Host "  Usuario: $env:USERNAME"
Write-Host "  Diretorio atual: $(Get-Location)"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
Write-Host ""

# Verificar dependencias
Write-Host "==> Verificando dependencias..."
if (-not (Test-Command "VBoxManage")) {
    Write-Host "    VBoxManage nao encontrado no PATH, buscando nos locais comuns..." -ForegroundColor Yellow
    
    # Locais comuns de instalacao do VirtualBox no Windows
    $vboxPaths = @(
        "$env:ProgramFiles\Oracle\VirtualBox",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox",
        "$env:ProgramW6432\Oracle\VirtualBox"
    )
    
    $vboxFound = $false
    foreach ($path in $vboxPaths) {
        $vboxManagePath = Join-Path $path "VBoxManage.exe"
        if (Test-Path $vboxManagePath) {
            Write-Host "    VirtualBox encontrado em: $path" -ForegroundColor Green
            # Adicionar ao PATH da sessao atual
            $env:PATH = "$path;$env:PATH"
            $vboxFound = $true
            break
        }
    }
    
    if (-not $vboxFound) {
        Write-Host ""
        Write-Host "VirtualBox nao encontrado!" -ForegroundColor Red
        Write-Host ""
        Write-Host "O VBoxManage nao esta disponivel no PATH." -ForegroundColor Yellow
        Write-Host "Certifique-se de que o VirtualBox esta instalado." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Baixe em: https://www.virtualbox.org/wiki/Downloads" -ForegroundColor Cyan
        Write-Host ""
        Pause-BeforeExit 1
    }
}

$vboxVersion = VBoxManage --version 2>&1
Write-Host "    VirtualBox versao: $vboxVersion" -ForegroundColor Green


# Criar diretorio de saida se nao existir
# Tenta usar o caminho relativo ao script, senao usa o diretorio atual
if ($OutputDir.StartsWith(".\") -or $OutputDir.StartsWith("./") -or -not [System.IO.Path]::IsPathRooted($OutputDir)) {
    if ($PSScriptRoot) {
        # Executando de um arquivo .ps1 - usar pasta pai do script
        $ScriptParentDir = Split-Path $PSScriptRoot -Parent
        $OutputDirPath = Join-Path $ScriptParentDir $OutputDir
    } else {
        # Executando via iex/download direto
        $OutputDirPath = Join-Path (Get-Location) $OutputDir
    }
} else {
    $OutputDirPath = $OutputDir
}

# Converter para caminho absoluto
$OutputDirPath = [System.IO.Path]::GetFullPath($OutputDirPath)

Write-Host "==> Configurando diretorio de saida"
Write-Host "    Caminho: $OutputDirPath" -ForegroundColor Cyan

if (-not (Test-Path $OutputDirPath)) {
    Write-Host "    Diretorio nao existe, criando..." -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $OutputDirPath -Force -ErrorAction Stop | Out-Null
        Write-Host "    Diretorio criado com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "    Falha ao criar em: $OutputDirPath" -ForegroundColor Yellow
        Write-Host "    Tentando usar diretorio temporario..." -ForegroundColor Yellow
        
        # Fallback: usar pasta temporaria do usuario
        $OutputDirPath = Join-Path $env:USERPROFILE "Downloads\emacs-a11y-vm-releases"
        
        try {
            if (-not (Test-Path $OutputDirPath)) {
                New-Item -ItemType Directory -Path $OutputDirPath -Force -ErrorAction Stop | Out-Null
            }
            Write-Host "    Usando: $OutputDirPath" -ForegroundColor Green
        } catch {
            Write-Error-Exit "Sem permissao para criar diretorios. Erro: $($_.Exception.Message)"
        }
    }
} else {
    Write-Host "    Diretorio ja existe" -ForegroundColor Green
}

# Determinar driver de audio
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

# Verificar se arquivo ja existe
$skipDownload = $false
if ((Test-Path $VmdkPath) -and -not $ForceDownload) {
    $existingFile = Get-Item $VmdkPath
    $existingSizeMB = [math]::Round($existingFile.Length / 1MB, 2)
    $expectedSizeMB = [math]::Round($VmdkAsset.size / 1MB, 2)
    
    if ($existingFile.Length -eq $VmdkAsset.size) {
        Write-Host "==> Arquivo VMDK ja existe e esta completo" -ForegroundColor Green
        Write-Host "    Arquivo: $VmdkPath" -ForegroundColor Cyan
        Write-Host "    Tamanho: $existingSizeMB MB" -ForegroundColor Cyan
        Write-Host "    Pulando download..." -ForegroundColor Yellow
        $skipDownload = $true
    } else {
        Write-Host "==> Arquivo VMDK existe mas tamanho difere" -ForegroundColor Yellow
        Write-Host "    Esperado: $expectedSizeMB MB, Encontrado: $existingSizeMB MB" -ForegroundColor Yellow
        Write-Host "    Removendo arquivo antigo e baixando novamente..." -ForegroundColor Yellow
        Remove-Item $VmdkPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not $skipDownload) {
    Write-Host "==> Baixando asset: $AssetName"
    Write-Host "    URL: $AssetUrl"
    Write-Host "    Destino: $VmdkPath"

    try {
        # Verificar se temos permissao de escrita no diretorio
        $testFile = Join-Path $OutputDirPath ".test_write_permission"
        try {
            [System.IO.File]::WriteAllText($testFile, "test")
            Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        } catch {
            throw "Sem permissao de escrita no diretorio: $OutputDirPath"
        }
        
        # Obter tamanho do arquivo antes de baixar
        $assetSizeMB = [math]::Round($VmdkAsset.size / 1MB, 2)
        Write-Host "    Tamanho do arquivo: $assetSizeMB MB" -ForegroundColor Cyan
        Write-Host "    Baixando... (isso pode levar varios minutos)" -ForegroundColor Yellow
        Write-Host ""
    
    # Baixar o arquivo com monitoramento de progresso
    $job = Start-Job -ScriptBlock {
        param($url, $output)
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
    } -ArgumentList $AssetUrl, $VmdkPath
    
    # Monitorar progresso enquanto baixa
    $lastSize = 0
    while ($job.State -eq 'Running') {
        Start-Sleep -Seconds 3
        if (Test-Path $VmdkPath) {
            $currentSize = (Get-Item $VmdkPath).Length
            $currentSizeMB = [math]::Round($currentSize / 1MB, 2)
            $percent = [math]::Round(($currentSize / $VmdkAsset.size) * 100, 1)
            
            if ($currentSize -ne $lastSize) {
                Write-Host "    Progresso: $currentSizeMB MB / $assetSizeMB MB ($percent%)" -ForegroundColor Green
                $lastSize = $currentSize
            }
        }
    }
    
    # Aguardar conclusao do job
    $result = Receive-Job -Job $job -Wait
    Remove-Job -Job $job
    
    Write-Host ""
    
    if (-not (Test-Path $VmdkPath)) {
        Write-Error-Exit "Download falhou: arquivo nao foi criado em $VmdkPath"
    }
    
    $fileSize = (Get-Item $VmdkPath).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    Write-Host "    Download completo: $fileSizeMB MB" -ForegroundColor Green
    } catch {
        Write-Error-Exit "Download falhou: $($_.Exception.Message)"
    }
}

# Verificacao final: garantir que o arquivo VMDK existe antes de prosseguir
Write-Host "==> Verificando arquivo VMDK"
if (-not (Test-Path $VmdkPath)) {
    Write-Host ""
    Write-Host "Erro: Arquivo VMDK nao encontrado!" -ForegroundColor Red
    Write-Host "Caminho esperado: $VmdkPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possíveis causas:" -ForegroundColor Yellow
    Write-Host "  1. Download foi interrompido" -ForegroundColor Gray
    Write-Host "  2. Arquivo foi movido ou deletado" -ForegroundColor Gray
    Write-Host "  3. Permissões de arquivo impedem acesso" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Solução: Execute o script novamente com -ForceDownload" -ForegroundColor Cyan
    Pause-BeforeExit 1
}

$finalFileSize = (Get-Item $VmdkPath).Length
$finalFileSizeMB = [math]::Round($finalFileSize / 1MB, 2)
Write-Host "    Arquivo encontrado: $finalFileSizeMB MB" -ForegroundColor Green
Write-Host "    Caminho completo: $VmdkPath" -ForegroundColor Cyan

# Determinar caminho do disco de dados (VDI persistente)
$UserDataVdiPath = Join-Path $OutputDirPath "$VMName-userdata.vdi"
$UserDataVdiExists = Test-Path $UserDataVdiPath

# Auto-habilitar PreserveUserData se disco ja existir
if ($UserDataVdiExists -and -not $PSBoundParameters.ContainsKey('PreserveUserData')) {
    $PreserveUserData = $true
    Write-Host "==> Disco de dados detectado, preservacao automatica habilitada" -ForegroundColor Cyan
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
        Write-Error-Exit "VM '$VMName' ja existe e -KeepOldVM foi usado. Escolha outro -VMName."
    }
    
    # Se PreserveUserData ativo, desanexar disco de dados antes de remover VM
    if ($PreserveUserData -and $UserDataVdiExists) {
        Write-Host "    Desanexando disco de dados antes de remover VM..." -ForegroundColor Yellow
        try {
            # Tentar desanexar o disco da porta 1 (onde esperamos que esteja)
            $null = VBoxManage storageattach $VMName --storagectl "SATA" --port 1 --device 0 --medium none 2>&1
        } catch {
            Write-Host "    Aviso: Nao foi possivel desanexar disco de dados" -ForegroundColor Yellow
        }
    }
    
    Write-Host "    VM existente encontrada, removendo..." -ForegroundColor Yellow
    try {
        $null = VBoxManage unregistervm $VMName --delete 2>&1
        Write-Host "    VM antiga removida com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "    Aviso: Falha ao remover VM antiga (pode nao existir)" -ForegroundColor Yellow
    }
} else {
    Write-Host "    Nenhuma VM existente com esse nome" -ForegroundColor Green
}

Write-Host "==> Criando VM '$VMName'"
$output = VBoxManage createvm --name $VMName --ostype Debian_64 --register 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao criar VM. VBoxManage disse: $output"
}

Write-Host "==> Driver de audio selecionado: $AudioDriverUsed"

# Configuracao base: VM textual, audio AC97 para acessibilidade, NAT com SSH forwarding
$output = VBoxManage modifyvm $VMName `
    --memory $RAM `
    --cpus $CPUs `
    --ioapic on `
    --boot1 disk --boot2 none --boot3 none --boot4 none `
    --audio-driver $AudioDriverUsed `
    --audio-controller ac97 `
    --audio-enabled on `
    --audio-out on `
    --audio-in on `
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

Write-Host "==> Anexando disco de sistema (VMDK)"
$output = VBoxManage storageattach $VMName `
    --storagectl "SATA" --port 0 --device 0 `
    --type hdd --medium $VmdkAbsolutePath 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao anexar disco VMDK. VBoxManage disse: $output"
}

Write-Host "    Disco de sistema anexado na porta SATA 0" -ForegroundColor Green

# Criar ou reutilizar disco de dados do usuario (VDI persistente)
Write-Host "==> Configurando disco de dados do usuario"

if ($UserDataVdiExists) {
    $existingVdi = Get-Item $UserDataVdiPath
    $existingSizeMB = [math]::Round($existingVdi.Length / 1MB, 2)
    Write-Host "    Disco de dados existente encontrado: $existingSizeMB MB" -ForegroundColor Green
    Write-Host "    Reutilizando: $UserDataVdiPath" -ForegroundColor Cyan
} else {
    Write-Host "    Criando novo disco de dados VDI: $UserDataSize MB" -ForegroundColor Yellow
    
    try {
        $output = VBoxManage createmedium disk `
            --filename $UserDataVdiPath `
            --size $UserDataSize `
            --format VDI `
            --variant Standard 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    Aviso: Falha ao criar disco de dados: $output" -ForegroundColor Yellow
            Write-Host "    Continuando sem disco de dados separado" -ForegroundColor Yellow
            $UserDataVdiExists = $false
        } else {
            Write-Host "    Disco de dados criado com sucesso" -ForegroundColor Green
            $UserDataVdiExists = $true
        }
    } catch {
        Write-Host "    Aviso: Erro ao criar disco de dados: $_" -ForegroundColor Yellow
        Write-Host "    Continuando sem disco de dados separado" -ForegroundColor Yellow
        $UserDataVdiExists = $false
    }
}

# Anexar disco de dados na porta SATA 1
if ($UserDataVdiExists) {
    $UserDataVdiAbsolutePath = (Resolve-Path $UserDataVdiPath).Path
    
    $output = VBoxManage storageattach $VMName `
        --storagectl "SATA" --port 1 --device 0 `
        --type hdd --medium $UserDataVdiAbsolutePath 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Aviso: Falha ao anexar disco de dados: $output" -ForegroundColor Yellow
        Write-Host "    VM continuara funcionando, mas sem disco de dados separado" -ForegroundColor Yellow
        $UserDataVdiExists = $false
    } else {
        Write-Host "    Disco de dados anexado na porta SATA 1" -ForegroundColor Green
    }
}

Write-Host "==> Iniciando VM em modo headless"
$output = VBoxManage startvm $VMName --type headless 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao iniciar VM. VBoxManage disse: $output"
}

# Mensagem de sucesso
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "  VM criada e iniciada com sucesso!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Release: $Owner/$Repo ($ResolvedTag)"
Write-Host "VM:      $VMName"
Write-Host "SSH:     ssh -p $SSHPort a11ydevs@localhost"
Write-Host ""
Write-Host "Arquitetura de Discos:"
Write-Host "  Sistema (SATA 0): $VmdkPath" -ForegroundColor Cyan
if ($UserDataVdiExists) {
    Write-Host "  Dados (SATA 1):   $UserDataVdiPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "O disco de dados sera montado automaticamente em /home" -ForegroundColor Yellow
    Write-Host "no primeiro boot. Suas configuracoes do Emacs e arquivos" -ForegroundColor Yellow
    Write-Host "pessoais serao preservados em upgrades futuros." -ForegroundColor Yellow
} else {
    Write-Host "  Dados: Nao configurado (tudo em disco unico)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Credenciais padrao esperadas (release atual):"
Write-Host "  usuario: a11ydevs"
Write-Host "  senha:   a11ydevs"
Write-Host ""
if ($UserDataVdiExists) {
    Write-Host "Para mais informacoes sobre customizacao e upgrades, veja:" -ForegroundColor Cyan
    Write-Host "  https://github.com/$Owner/$Repo/blob/main/docs/architecture.md"
}
Write-Host ""

Pause-BeforeExit 0
