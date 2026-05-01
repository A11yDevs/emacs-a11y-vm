[CmdletBinding()]
param(
    [string]$Owner = 'A11yDevs',
    [string]$Repo = 'emacs-a11y-vm',
    [string]$Branch = 'main',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

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

$baseRaw = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/cli"
$files = @(
    @{ Name = 'ea11ctl.ps1'; Url = "$baseRaw/ea11ctl.ps1" },
    @{ Name = 'ea11ctl.cmd'; Url = "$baseRaw/ea11ctl.cmd" }
)

foreach ($file in $files) {
    $dest = Join-Path $installDir $file.Name

    if ((Test-Path $dest) -and -not $Force) {
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
Write-Host 'Teste agora com:' -ForegroundColor Green
Write-Host '  ea11ctl help' -ForegroundColor Green
Write-Host '  ea11ctl vm install' -ForegroundColor Green
