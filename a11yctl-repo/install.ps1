[CmdletBinding()]
param(
    [switch]$NoForceReinstall,
    # Mantido por compatibilidade; a partir de v0.1.13 a reinstalacao forcada e padrao.
    [switch]$Force,
    # Parametros legados (ignorados)
    [string]$Owner,
    [string]$Repo,
    [string]$Branch
)

$ErrorActionPreference = 'Stop'
$INSTALL_OWNER = 'A11yDevs'
$INSTALL_REPO = 'a11yctl'
$INSTALL_BRANCH = 'main'

function Write-Info {
    param([string]$Message)
    Write-Host "[a11yctl-install] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[a11yctl-install] $Message" -ForegroundColor Yellow
}

function Assert-Windows {
    $runningOnWindows = $false

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $runningOnWindows = [bool]$IsWindows
    }
    else {
        $runningOnWindows = ($env:OS -eq 'Windows_NT')
    }

    if (-not $runningOnWindows) {
        throw 'Este instalador foi feito para Windows (PowerShell).'
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Add-ToUserPath {
    param([string]$PathToAdd)

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) {
        $userPath = ''
    }

    $parts = $userPath.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
    foreach ($part in $parts) {
        if ($part.TrimEnd('\\') -ieq $PathToAdd.TrimEnd('\\')) {
            return $false
        }
    }

    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $PathToAdd
    }
    else {
        "$userPath;$PathToAdd"
    }

    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    return $true
}

function Test-QemuAvailable {
    $candidates = @(
        'qemu-system-x86_64.exe',
        'qemu-system-x86_64w.exe',
        'qemu-img.exe'
    )

    foreach ($candidate in $candidates) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $true
        }
    }

    $knownPaths = @(
        "$env:ProgramFiles\qemu\qemu-system-x86_64w.exe",
        "$env:ProgramFiles\qemu\qemu-system-x86_64.exe",
        "$env:ProgramFiles\qemu\qemu-img.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-system-x86_64w.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-system-x86_64.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-img.exe"
    )

    foreach ($path in $knownPaths) {
        if ($path -and (Test-Path $path)) {
            return $true
        }
    }

    return $false
}

function Ensure-QemuInstalled {
    if (Test-QemuAvailable) {
        Write-Info 'QEMU ja esta disponivel.'
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-WarnMsg 'winget nao encontrado; nao foi possivel instalar QEMU automaticamente.'
        Write-WarnMsg 'Instale manualmente com: winget install -e --id SoftwareFreedomConservancy.QEMU'
        return
    }

    Write-Info 'QEMU nao encontrado. Instalando via winget...'
    try {
        & winget install -e --id SoftwareFreedomConservancy.QEMU --accept-package-agreements --accept-source-agreements
    }
    catch {
        Write-WarnMsg "Falha ao instalar QEMU via winget: $($_.Exception.Message)"
        Write-WarnMsg 'Tente manualmente: winget install -e --id SoftwareFreedomConservancy.QEMU'
        return
    }

    # Atualiza PATH da sessao para pegar instalacao recente quando necessario.
    if (Test-Path "$env:ProgramFiles\qemu") {
        $sessionPathParts = $env:Path -split ';'
        if (-not ($sessionPathParts -contains "$env:ProgramFiles\qemu")) {
            $env:Path = "$env:ProgramFiles\qemu;$env:Path"
        }
    }

    if (Test-QemuAvailable) {
        Write-Info 'QEMU instalado e detectado com sucesso.'
    }
    else {
        Write-WarnMsg 'QEMU nao foi detectado apos a instalacao. Feche e abra o terminal e valide novamente.'
    }
}

function Invoke-LegacyMigration {
    param([string]$LegacyDir, [string]$NewDir)

    if (-not (Test-Path $LegacyDir)) {
        return
    }

    Write-Info "Instalacao legada detectada em: $LegacyDir"
    Write-Info "Copiando VMs e configuracoes para: $NewDir"

    $vmExtensions = @('.qcow2', '.vmdk', '.vdi', '.vhd', '.vhdx', '.iso', '.ova')
    $diskFiles = Get-ChildItem -Path $LegacyDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $vmExtensions -contains $_.Extension.ToLower() }

    foreach ($disk in $diskFiles) {
        $rel  = $disk.FullName.Substring($LegacyDir.Length).TrimStart('\', '/')
        $dest = Join-Path $NewDir $rel
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        if (-not (Test-Path $dest)) {
            Write-Info "Copiando disco: $($disk.Name)"
            Copy-Item -Path $disk.FullName -Destination $dest -Force
        } else {
            Write-WarnMsg "Disco ja existe no destino, pulando: $($disk.Name)"
        }
    }

    $configExt = @('.env', '.json')
    $configFiles = Get-ChildItem -Path $LegacyDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $configExt -contains $_.Extension.ToLower() }

    foreach ($cfg in $configFiles) {
        $rel  = $cfg.FullName.Substring($LegacyDir.Length).TrimStart('\', '/')
        $dest = Join-Path $NewDir $rel
        $destDir = Split-Path $dest -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        if (-not (Test-Path $dest)) {
            $cfgContent = Get-Content -Path $cfg.FullName -Raw -Encoding UTF8
            $cfgContent = $cfgContent -replace [regex]::Escape($LegacyDir), $NewDir
            $cfgContent = $cfgContent -replace '\.emacs-a11y-vm', '.a11yctl'
            Set-Content -Path $dest -Value $cfgContent -Encoding UTF8
            Write-Info "Config migrada: $($cfg.Name)"
        }
    }

    Write-WarnMsg "Diretorio antigo preservado (nao foi removido): $LegacyDir"
    Write-WarnMsg "Depois de validar, voce pode remove-lo manualmente."
}

Assert-Windows

Ensure-QemuInstalled

# Diretorio de instalacao: %USERPROFILE%\.a11yctl\bin
$installDir = Join-Path $env:USERPROFILE '.a11yctl\bin'
$vmsDir     = Join-Path $env:USERPROFILE '.a11yctl\vms'
Ensure-Directory -Path $installDir
Ensure-Directory -Path $vmsDir

# Migrar instalacao legada de ea11ctl (~/.emacs-a11y-vm)
$legacyStateDir = Join-Path $env:USERPROFILE '.emacs-a11y-vm'
$newStateDir    = Join-Path $env:USERPROFILE '.a11yctl'
Invoke-LegacyMigration -LegacyDir $legacyStateDir -NewDir $newStateDir

$baseRaw = "https://raw.githubusercontent.com/$INSTALL_OWNER/$INSTALL_REPO/$INSTALL_BRANCH"
$files = @(
    @{ Name = 'a11yctl.ps1'; Url = "$baseRaw/a11yctl.ps1" },
    @{ Name = 'a11yctl.cmd'; Url = "$baseRaw/a11yctl.cmd" },
    @{ Name = 'ea11ctl.ps1'; Url = "$baseRaw/ea11ctl.ps1" },
    @{ Name = 'ea11ctl.cmd'; Url = "$baseRaw/ea11ctl.cmd" },
    @{ Name = 'VERSION';     Url = "$baseRaw/VERSION" }
)

$forceReinstall = $true
if ($NoForceReinstall) {
    $forceReinstall = $false
}
if ($Force) {
    $forceReinstall = $true
}

if ($forceReinstall) {
    Write-Info 'Modo padrao: reinstalacao forcada habilitada.'
}
else {
    Write-Info 'Reinstalacao forcada desabilitada por --NoForceReinstall.'
}

foreach ($file in $files) {
    $dest = Join-Path $installDir $file.Name

    if ((Test-Path $dest) -and $forceReinstall) {
        Write-Info "Removendo arquivo existente: $($file.Name)"
        Remove-Item -Path $dest -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $dest) {
        Write-Info "Atualizando $($file.Name)"
    }
    else {
        Write-Info "Baixando $($file.Name)"
    }

    Invoke-WebRequest -Uri $file.Url -OutFile $dest -UseBasicParsing

    # Garante UTF-8 BOM em .ps1 para Windows PowerShell 5.x
    if ($file.Name -like '*.ps1') {
        $bom = [byte[]](0xEF, 0xBB, 0xBF)
        $bytes = [System.IO.File]::ReadAllBytes($dest)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        if (-not $hasBom) {
            $withBom = New-Object byte[] ($bom.Length + $bytes.Length)
            [Array]::Copy($bom, $withBom, $bom.Length)
            [Array]::Copy($bytes, 0, $withBom, $bom.Length, $bytes.Length)
            [System.IO.File]::WriteAllBytes($dest, $withBom)
        }
    }
}

$pathChanged = Add-ToUserPath -PathToAdd $installDir

if ($pathChanged) {
    Write-Info "Diretorio adicionado ao PATH do usuario: $installDir"
    Write-WarnMsg 'Feche e abra o terminal para o comando a11yctl ficar disponivel em novas sessoes.'
}
else {
    Write-Info 'Diretorio ja estava no PATH do usuario.'
}

# Disponibiliza no terminal atual tambem
if (-not (($env:Path -split ';') -contains $installDir)) {
    $env:Path = "$installDir;$env:Path"
}

Write-Host ''
Write-Host 'Instalacao concluida.' -ForegroundColor Green
$installedVersion = 'desconhecida'
$versionFile = Join-Path $installDir 'VERSION'
if (Test-Path $versionFile) {
    $installedVersion = (Get-Content -Path $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
}
Write-Host "Versao instalada: $installedVersion" -ForegroundColor Green
Write-Host 'Teste agora com:' -ForegroundColor Green
Write-Host '  a11yctl help' -ForegroundColor Green
Write-Host ''
Write-Host 'Compatibilidade: ea11ctl tambem esta disponivel como alias temporario.' -ForegroundColor Yellow
