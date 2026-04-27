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
    [ValidateSet("nat", "bridge")]
    [string]$NetworkMode = "bridge",
    [string]$BridgeAdapter = "",
    [switch]$PreserveUserData,
    [switch]$KeepOldVM,
    [switch]$ForceDownload,
    [switch]$Headless,
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
  -NetworkMode <nat|bridge> Modo de rede (padrao: nat)
  -BridgeAdapter <nome>   Adaptador para bridge (auto-detecta se vazio)
  -PreserveUserData       Preserva disco de dados de VM existente (padrao: auto)
  -KeepOldVM              Nao remove VM existente com o mesmo nome
  -ForceDownload          Forca re-download mesmo se arquivo ja existe
  -Headless               Inicia VM sem janela (background, acesso via SSH)
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

function Get-BridgeAdapter {
    if ($BridgeAdapter) {
        return $BridgeAdapter
    }
    
    # Auto-detectar primeiro adaptador bridge disponível
    # Usar método mais robusto: parsear linha por linha
    $output = & VBoxManage list bridgedifs 2>&1
    $currentName = $null
    
    foreach ($line in $output) {
        if ($line -match '^Name:\s+(.+)$') {
            $currentName = $matches[1].Trim()
            # Retornar o primeiro adaptador encontrado
            if ($currentName) {
                return $currentName
            }
        }
    }
    
    return $null
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
# Para caminhos relativos, usar o diretorio atual do usuario
if ($OutputDir.StartsWith(".\") -or $OutputDir.StartsWith("./") -or -not [System.IO.Path]::IsPathRooted($OutputDir)) {
    # Caminho relativo - usar diretório atual onde o usuário executou o script
    $OutputDirPath = Join-Path (Get-Location) $OutputDir
} else {
    # Caminho absoluto - usar como está
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

# Determinar configuracao de rede
if ($NetworkMode -eq "bridge") {
    $BridgeAdapterUsed = Get-BridgeAdapter
    if (-not $BridgeAdapterUsed) {
        Write-Error-Exit "Modo bridge selecionado mas nenhum adaptador bridge disponivel. Use -BridgeAdapter para especificar."
    }
    Write-Host "==> Modo de rede: Bridge (adaptador: $BridgeAdapterUsed)" -ForegroundColor Cyan
} else {
    Write-Host "==> Modo de rede: NAT (SSH port forwarding: localhost:$SSHPort -> VM:22)" -ForegroundColor Cyan
}

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

# Verificar se o arquivo está em subpasta duplicada (bug de versões antigas)
$possibleWrongPath = Join-Path $OutputDirPath "releases\$AssetName"
if (-not (Test-Path $VmdkPath) -and (Test-Path $possibleWrongPath)) {
    Write-Host "==> Arquivo encontrado em local incorreto (bug de versão antiga)" -ForegroundColor Yellow
    Write-Host "    Movendo de: $possibleWrongPath" -ForegroundColor Yellow
    Write-Host "    Para:       $VmdkPath" -ForegroundColor Yellow
    try {
        Move-Item -Path $possibleWrongPath -Destination $VmdkPath -Force
        Write-Host "    Arquivo movido com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "    Aviso: Não foi possível mover. Continuando com download..." -ForegroundColor Yellow
    }
}

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
    $null = & $VBoxManagePath showvminfo "$VMName" 2>&1
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
            $null = & $VBoxManagePath storageattach "$VMName" --storagectl "SATA" --port 1 --device 0 --medium none 2>&1
        } catch {
            Write-Host "    Aviso: Nao foi possivel desanexar disco de dados" -ForegroundColor Yellow
        }
    }
    
    Write-Host "    VM existente encontrada, removendo..." -ForegroundColor Yellow
    try {
        $null = & $VBoxManagePath unregistervm "$VMName" --delete 2>&1
        Write-Host "    VM antiga removida com sucesso" -ForegroundColor Green
    } catch {
        Write-Host "    Aviso: Falha ao remover VM antiga (pode nao existir)" -ForegroundColor Yellow
    }
} else {
    Write-Host "    Nenhuma VM existente com esse nome" -ForegroundColor Green
}

Write-Host "==> Criando VM '$VMName'"
$output = & $VBoxManagePath createvm --name "$VMName" --ostype Debian_64 --register 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao criar VM. VBoxManage disse: $output"
}

Write-Host "==> Driver de audio selecionado: $AudioDriverUsed"

# Configuracao base: VM textual, audio AC97 para acessibilidade
$modifyvmArgs = @(
    "modifyvm", "$VMName",
    "--memory", "$RAM",
    "--cpus", "$CPUs",
    "--ioapic", "on",
    "--boot1", "disk", "--boot2", "none", "--boot3", "none", "--boot4", "none",
    "--audio-driver", "$AudioDriverUsed",
    "--audio-controller", "ac97",
    "--audio-enabled", "on",
    "--audio-out", "on",
    "--audio-in", "on",
    "--graphicscontroller", "vmsvga",
    "--vram", "16"
)

# Configurar rede baseado no modo
if ($NetworkMode -eq "bridge") {
    $modifyvmArgs += "--nic1", "bridged"
    $modifyvmArgs += "--bridgeadapter1", "$BridgeAdapterUsed"
    Write-Host "    Rede configurada como bridge" -ForegroundColor Green
} else {
    $modifyvmArgs += "--nic1", "nat"
    $modifyvmArgs += "--natpf1", "ssh,tcp,127.0.0.1,$SSHPort,,22"
    Write-Host "    Rede configurada como NAT com port forwarding" -ForegroundColor Green
}

$output = & $VBoxManagePath @modifyvmArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao configurar VM. VBoxManage disse: $output"
}

$output = & $VBoxManagePath storagectl "$VMName" --name "SATA" --add sata --controller IntelAhci 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Falha ao adicionar controlador SATA. VBoxManage disse: $output"
}

# Converter caminho para formato absoluto (verificar novamente antes de converter)
if (-not (Test-Path $VmdkPath)) {
    Write-Error-Exit "Arquivo VMDK desapareceu antes de ser anexado: $VmdkPath`nO arquivo pode ter sido movido, deletado ou bloqueado por antivirus."
}

try {
    $VmdkAbsolutePath = (Resolve-Path $VmdkPath -ErrorAction Stop).Path
} catch {
    Write-Error-Exit "Falha ao resolver caminho do VMDK: $VmdkPath`nErro: $_"
}

Write-Host "==> Anexando disco de sistema (VMDK)"
$output = & $VBoxManagePath storageattach "$VMName" `
    --storagectl "SATA" --port 0 --device 0 `
    --type hdd --medium "$VmdkAbsolutePath" 2>&1

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
        # Garantir que o diretorio existe
        $userDataDir = Split-Path -Parent $UserDataVdiPath
        if (-not (Test-Path $userDataDir)) {
            New-Item -ItemType Directory -Path $userDataDir -Force | Out-Null
        }
        
        # Criar disco com caminho entre aspas
        $output = & $VBoxManagePath createmedium disk `
            --filename "$UserDataVdiPath" `
            --size $UserDataSize `
            --format VDI `
            --variant Standard 2>&1
        
        # VBoxManage pode retornar progresso (0%...10%...) mesmo em sucesso
        # Verificar se arquivo foi criado com sucesso
        if ($LASTEXITCODE -eq 0 -and (Test-Path $UserDataVdiPath)) {
            Write-Host "    Disco de dados criado com sucesso" -ForegroundColor Green
            $UserDataVdiExists = $true
        } else {
            $errorMsg = $output -join "`n"
            Write-Host "" -ForegroundColor Yellow
            Write-Host "    Aviso: Falha ao criar disco de dados" -ForegroundColor Yellow
            Write-Host "    Exit code: $LASTEXITCODE" -ForegroundColor Gray
            if ($output) {
                Write-Host "    Output: $errorMsg" -ForegroundColor Gray
            }
            Write-Host "    Continuando sem disco de dados separado" -ForegroundColor Yellow
            Write-Host "" -ForegroundColor Yellow
            Write-Host "    NOTA: Suas configuracoes serao perdidas em upgrades" -ForegroundColor Yellow
            Write-Host "    Para resolver:" -ForegroundColor Yellow
            Write-Host "      - Verifique permissoes de escrita em: $OutputDirPath" -ForegroundColor Gray
            Write-Host "      - Certifique-se de que o VirtualBox esta instalado corretamente" -ForegroundColor Gray
            Write-Host "      - Teste: VBoxManage createmedium disk --filename test.vdi --size 10240" -ForegroundColor Gray
            Write-Host "" -ForegroundColor Yellow
            $UserDataVdiExists = $false
        }
    } catch {
        Write-Host "" -ForegroundColor Yellow
        Write-Host "    Aviso: Erro ao criar disco de dados" -ForegroundColor Yellow
        Write-Host "    Detalhes: $_" -ForegroundColor Gray
        Write-Host "    Continuando sem disco de dados separado" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor Yellow
        $UserDataVdiExists = $false
    }
}

# Anexar disco de dados na porta SATA 1
if ($UserDataVdiExists) {
    $UserDataVdiAbsolutePath = (Resolve-Path $UserDataVdiPath).Path
    
    $output = & $VBoxManagePath storageattach "$VMName" `
        --storagectl "SATA" --port 1 --device 0 `
        --type hdd --medium "$UserDataVdiAbsolutePath" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Aviso: Falha ao anexar disco de dados: $output" -ForegroundColor Yellow
        Write-Host "    VM continuara funcionando, mas sem disco de dados separado" -ForegroundColor Yellow
        $UserDataVdiExists = $false
    } else {
        Write-Host "    Disco de dados anexado na porta SATA 1" -ForegroundColor Green
    }
}

# Determinar modo de inicializacao
$vmType = if ($Headless) { "headless" } else { "gui" }
$vmTypeDesc = if ($Headless) { "headless (sem janela, acesso via SSH)" } else { "GUI (console visivel)" }

Write-Host "==> Iniciando VM em modo $vmTypeDesc"
$output = & $VBoxManagePath startvm "$VMName" --type $vmType 2>&1

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
Write-Host "Modo:    $vmTypeDesc"
Write-Host ""

if ($Headless) {
    Write-Host "VM rodando em background (modo headless)" -ForegroundColor Yellow
    Write-Host "Para acessar, conecte via SSH:" -ForegroundColor Cyan
    Write-Host "  ssh -p $SSHPort a11ydevs@localhost" -ForegroundColor Green
} else {
    Write-Host "VM iniciada com console visivel!" -ForegroundColor Green
    Write-Host "A janela do VirtualBox deve estar aberta." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Use o console TUI para login direto:" -ForegroundColor Cyan
    Write-Host "  usuario: a11ydevs" -ForegroundColor Green
    Write-Host "  senha:   a11ydevs" -ForegroundColor Green
    Write-Host ""
    Write-Host "Acesso SSH tambem disponivel:" -ForegroundColor Cyan
    Write-Host "  ssh -p $SSHPort a11ydevs@localhost" -ForegroundColor Gray
}
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

if ($UserDataVdiExists) {
    Write-Host "Para mais informacoes sobre customizacao e upgrades, veja:" -ForegroundColor Cyan
    Write-Host "  https://github.com/$Owner/$Repo/blob/main/docs/architecture.md"
}
Write-Host ""

Pause-BeforeExit 0
