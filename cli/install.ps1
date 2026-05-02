[CmdletBinding()]
param(
    [switch]$NoForceReinstall,
    # Mantido por compatibilidade; a partir de v0.1.13 a reinstalacao forcada e padrao.
    [switch]$Force,
    # Parâmetros legados (ignorados a partir de v0.1.6 — owner/repo/branch são constantes)
    [string]$Owner,
    [string]$Repo,
    [string]$Branch
)

$ErrorActionPreference = 'Stop'
$INSTALL_OWNER = 'A11yDevs'
$INSTALL_REPO = 'emacs-a11y-vm'
$INSTALL_BRANCH = 'main'

function Write-Info {
    param([string]$Message)
    Write-Host "[ea11ctl-install] $Message" -ForegroundColor Cyan
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[ea11ctl-install] $Message" -ForegroundColor Yellow
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

Assert-Windows

$installDir = Join-Path $env:LOCALAPPDATA 'ea11ctl\bin'
Ensure-Directory -Path $installDir

$baseRaw = "https://raw.githubusercontent.com/$INSTALL_OWNER/$INSTALL_REPO/$INSTALL_BRANCH/cli"
$files = @(
    @{ Name = 'ea11ctl.ps1'; Url = "$baseRaw/ea11ctl.ps1" },
    @{ Name = 'ea11ctl.cmd'; Url = "$baseRaw/ea11ctl.cmd" },
    @{ Name = 'VERSION'; Url = "$baseRaw/VERSION" }
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
}

$pathChanged = Add-ToUserPath -PathToAdd $installDir

if ($pathChanged) {
    Write-Info "Diretorio adicionado ao PATH do usuario: $installDir"
    Write-WarnMsg 'Feche e abra o terminal para o comando ea11ctl ficar disponivel em novas sessoes.'
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
Write-Host '  ea11ctl help' -ForegroundColor Green
Write-Host '  ea11ctl version --check-update' -ForegroundColor Green
Write-Host '  ea11ctl vm install' -ForegroundColor Green
