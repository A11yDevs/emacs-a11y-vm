[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$EA11CTL_FALLBACK_VERSION = '0.1.1'

function Write-EA11Info {
    param([string]$Message)
    Write-Host "[ea11ctl] $Message" -ForegroundColor Cyan
}

function Write-EA11Warn {
    param([string]$Message)
    Write-Host "[ea11ctl] $Message" -ForegroundColor Yellow
}

function Write-EA11Error {
    param([string]$Message)
    Write-Host "[ea11ctl] $Message" -ForegroundColor Red
}

function Show-Help {
    @"
ea11ctl - CLI do projeto emacs-a11y-vm

Uso:
  ea11ctl help
    ea11ctl version [--check-update] [--owner OWNER] [--repo REPO] [--branch BRANCH]
    ea11ctl self-update [--force] [--owner OWNER] [--repo REPO] [--branch BRANCH]
  ea11ctl vm install [args-do-install-release-vm.ps1]
  ea11ctl vm list
  ea11ctl vm start [--name VM] [--headless]
  ea11ctl vm stop [--name VM] [--force]
  ea11ctl vm status [--name VM]
  ea11ctl vm ssh [--user USER] [--port PORT] [-- vm-extra-args]
  ea11ctl vm share-folder add --path CAMINHO [--name NOME] [--vm VM] [--readonly]
  ea11ctl vm share-folder remove --name NOME [--vm VM]
  ea11ctl vm share-folder list [--vm VM]

Defaults:
  VM: debian-a11y
  SSH user: a11ydevs
  SSH port: 2222
"@
}

function Get-LocalCliVersion {
    $versionFile = Join-Path $PSScriptRoot 'VERSION'
    if (Test-Path $versionFile) {
        $v = (Get-Content -Path $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
        if (-not [string]::IsNullOrWhiteSpace($v)) {
            return $v
        }
    }
    return $EA11CTL_FALLBACK_VERSION
}

function Get-RemoteCliVersion {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Branch
    )

    $remoteVersionUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/cli/VERSION"
    $content = Invoke-WebRequest -Uri $remoteVersionUrl -UseBasicParsing
    return $content.Content.Trim()
}

function Invoke-VersionCommand {
    param([string[]]$Tokens)

    $localVersion = Get-LocalCliVersion
    Write-Host "ea11ctl v$localVersion"

    if (-not (Has-Flag -Tokens $Tokens -Flags @('--check-update', '-c'))) {
        return
    }

    $owner = Get-OptionValue -Tokens $Tokens -Names @('--owner') -Default 'A11yDevs'
    $repo = Get-OptionValue -Tokens $Tokens -Names @('--repo') -Default 'emacs-a11y-vm'
    $branch = Get-OptionValue -Tokens $Tokens -Names @('--branch') -Default 'main'

    try {
        $remoteVersion = Get-RemoteCliVersion -Owner $owner -Repo $repo -Branch $branch
        if ($remoteVersion -eq $localVersion) {
            Write-EA11Info "Voce ja esta na versao mais recente ($localVersion)."
        }
        else {
            Write-EA11Info "Nova versao disponivel: $remoteVersion (local: $localVersion)"
            Write-Host 'Use: ea11ctl self-update' -ForegroundColor Green
        }
    }
    catch {
        Write-EA11Warn "Nao foi possivel consultar versao remota: $($_.Exception.Message)"
    }
}

function Invoke-SelfUpdate {
    param([string[]]$Tokens)

    $owner = Get-OptionValue -Tokens $Tokens -Names @('--owner') -Default 'A11yDevs'
    $repo = Get-OptionValue -Tokens $Tokens -Names @('--repo') -Default 'emacs-a11y-vm'
    $branch = Get-OptionValue -Tokens $Tokens -Names @('--branch') -Default 'main'
    $force = Has-Flag -Tokens $Tokens -Flags @('--force', '-f')

    $updateArgs = @('-Owner', $owner, '-Repo', $repo, '-Branch', $branch)
    if ($force) {
        $updateArgs += '-Force'
    }

    $localVersion = Get-LocalCliVersion
    if (-not $force) {
        try {
            $remoteVersion = Get-RemoteCliVersion -Owner $owner -Repo $repo -Branch $branch
            if ($remoteVersion -eq $localVersion) {
                Write-EA11Info "ea11ctl ja esta atualizado (v$localVersion)."
                return
            }

            Write-EA11Info "Atualizando ea11ctl de v$localVersion para v$remoteVersion..."
        }
        catch {
            Write-EA11Warn "Nao foi possivel validar versao remota; prosseguindo com update."
        }
    }

    $repoRoot = Get-RepoRoot
    if ($repoRoot) {
        $localInstaller = Join-Path $repoRoot 'cli/install.ps1'
        if (Test-Path $localInstaller) {
            Write-EA11Info "Executando self-update via instalador local: $localInstaller"
            & powershell -NoProfile -ExecutionPolicy Bypass -File $localInstaller @updateArgs
            return
        }
    }

    $remote = "https://raw.githubusercontent.com/$owner/$repo/$branch/cli/install.ps1"
    $tmp = Join-Path $env:TEMP 'ea11ctl-install.ps1'

    Write-EA11Info "Baixando instalador da CLI: $remote"
    Invoke-WebRequest -Uri $remote -OutFile $tmp -UseBasicParsing

    try {
        Write-EA11Info 'Atualizando ea11ctl...'
        & powershell -NoProfile -ExecutionPolicy Bypass -File $tmp @updateArgs
    }
    finally {
        Remove-Item -Path $tmp -ErrorAction SilentlyContinue
    }
}

function Assert-Command {
    param([string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Comando '$Command' nao encontrado no PATH."
    }
}

function Get-OptionValue {
    param(
        [string[]]$Tokens,
        [string[]]$Names,
        [string]$Default
    )

    for ($i = 0; $i -lt $Tokens.Length; $i++) {
        foreach ($name in $Names) {
            if ($Tokens[$i] -eq $name -and ($i + 1) -lt $Tokens.Length) {
                return $Tokens[$i + 1]
            }
        }
    }

    return $Default
}

function Has-Flag {
    param(
        [string[]]$Tokens,
        [string[]]$Flags
    )

    foreach ($token in $Tokens) {
        foreach ($flag in $Flags) {
            if ($token -eq $flag) {
                return $true
            }
        }
    }

    return $false
}

function Get-RepoRoot {
    $candidate = Resolve-Path (Join-Path $PSScriptRoot "..")
    if (Test-Path (Join-Path $candidate "scripts/install-release-vm.ps1")) {
        return $candidate.Path
    }
    return $null
}

function Invoke-VMInstall {
    param([string[]]$InstallArgs)

    $repoRoot = Get-RepoRoot
    if ($repoRoot) {
        $localScript = Join-Path $repoRoot "scripts/install-release-vm.ps1"
        Write-EA11Info "Executando instalador local: $localScript"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $localScript @InstallArgs
        return
    }

    $remote = "https://raw.githubusercontent.com/A11yDevs/emacs-a11y-vm/main/scripts/install-release-vm.ps1"
    $tmp = Join-Path $env:TEMP "ea11-install-release-vm.ps1"

    Write-EA11Info "Baixando instalador remoto..."
    Invoke-WebRequest -Uri $remote -OutFile $tmp -UseBasicParsing

    try {
        Write-EA11Info "Executando instalador remoto..."
        & powershell -NoProfile -ExecutionPolicy Bypass -File $tmp @InstallArgs
    }
    finally {
        Remove-Item -Path $tmp -ErrorAction SilentlyContinue
    }
}

function Get-VMName {
    param([string[]]$Tokens)
    return (Get-OptionValue -Tokens $Tokens -Names @('--name', '-n') -Default 'debian-a11y')
}

function Ensure-VBoxManage {
    if (Get-Command VBoxManage -ErrorAction SilentlyContinue) {
        return
    }

    $candidates = @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "${env:ProgramFiles(x86)}\Oracle\VirtualBox\VBoxManage.exe",
        "$env:ProgramW6432\Oracle\VirtualBox\VBoxManage.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $dir = Split-Path -Path $candidate -Parent
            $env:PATH = "$dir;$env:PATH"
            break
        }
    }

    Assert-Command "VBoxManage"
}

function Invoke-VMList {
    Ensure-VBoxManage
    & VBoxManage list vms
}

function Invoke-VMStart {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $type = if (Has-Flag -Tokens $Tokens -Flags @('--headless', '-H')) { 'headless' } else { 'gui' }

    Write-EA11Info "Iniciando VM '$vmName' ($type)..."
    & VBoxManage startvm $vmName --type $type
}

function Invoke-VMStop {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $force = Has-Flag -Tokens $Tokens -Flags @('--force', '-f')

    if ($force) {
        Write-EA11Warn "Forcando desligamento da VM '$vmName'..."
        & VBoxManage controlvm $vmName poweroff
        return
    }

    Write-EA11Info "Solicitando desligamento ACPI da VM '$vmName'..."
    & VBoxManage controlvm $vmName acpipowerbutton
}

function Invoke-VMStatus {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $raw = & VBoxManage showvminfo $vmName --machinereadable
    $line = $raw | Where-Object { $_ -like 'VMState=*' }

    if (-not $line) {
        Write-EA11Warn "Nao foi possivel obter estado da VM '$vmName'."
        return
    }

    $state = $line -replace '^VMState="?', '' -replace '"$', ''
    Write-Host "VM: $vmName"
    Write-Host "State: $state"
}

function Invoke-VMSSH {
    param([string[]]$Tokens)

    Assert-Command "ssh"

    $user = Get-OptionValue -Tokens $Tokens -Names @('--user', '-u') -Default 'a11ydevs'
    $port = Get-OptionValue -Tokens $Tokens -Names @('--port', '-p') -Default '2222'

    $extraStart = [Array]::IndexOf($Tokens, '--')
    $extra = @()
    if ($extraStart -ge 0 -and ($extraStart + 1) -lt $Tokens.Length) {
        $extra = $Tokens[($extraStart + 1)..($Tokens.Length - 1)]
    }

    Write-EA11Info "Abrindo SSH para $user@localhost:$port"
    & ssh -p $port "$user@localhost" @extra
}

function Invoke-ShareFolderAdd {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $path = Get-OptionValue -Tokens $Tokens -Names @('--path') -Default ''
    $name = Get-OptionValue -Tokens $Tokens -Names @('--name') -Default 'host-home'
    $readonly = Has-Flag -Tokens $Tokens -Flags @('--readonly')

    if ([string]::IsNullOrWhiteSpace($path)) {
        throw "Use --path para informar a pasta do host."
    }

    $args = @('sharedfolder', 'add', $vmName, '--name', $name, '--hostpath', $path, '--automount')
    if ($readonly) {
        $args += '--readonly'
    }

    Write-EA11Info "Adicionando shared folder '$name' na VM '$vmName'"
    & VBoxManage @args
}

function Invoke-ShareFolderRemove {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $name = Get-OptionValue -Tokens $Tokens -Names @('--name') -Default ''

    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Use --name para remover uma shared folder."
    }

    Write-EA11Info "Removendo shared folder '$name' da VM '$vmName'"
    & VBoxManage sharedfolder remove $vmName --name $name
}

function Invoke-ShareFolderList {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    & VBoxManage showvminfo $vmName | Select-String 'Shared folders:' -Context 0,20
}

function Invoke-VMShareFolder {
    param([string[]]$Tokens)

    if ($Tokens.Length -eq 0) {
        throw "Uso: ea11ctl vm share-folder <add|remove|list> [opcoes]"
    }

    $action = $Tokens[0]
    $rest = @()
    if ($Tokens.Length -gt 1) {
        $rest = $Tokens[1..($Tokens.Length - 1)]
    }

    switch ($action) {
        'add' { Invoke-ShareFolderAdd -Tokens $rest }
        'remove' { Invoke-ShareFolderRemove -Tokens $rest }
        'list' { Invoke-ShareFolderList -Tokens $rest }
        default { throw "Acao desconhecida de share-folder: $action" }
    }
}

function Invoke-VMCommand {
    param([string[]]$Tokens)

    if ($Tokens.Length -eq 0) {
        throw "Uso: ea11ctl vm <install|list|start|stop|status|ssh|share-folder>"
    }

    $sub = $Tokens[0]
    $rest = @()
    if ($Tokens.Length -gt 1) {
        $rest = $Tokens[1..($Tokens.Length - 1)]
    }

    switch ($sub) {
        'install' { Invoke-VMInstall -InstallArgs $rest }
        'list' { Invoke-VMList }
        'start' { Invoke-VMStart -Tokens $rest }
        'stop' { Invoke-VMStop -Tokens $rest }
        'status' { Invoke-VMStatus -Tokens $rest }
        'ssh' { Invoke-VMSSH -Tokens $rest }
        'share-folder' { Invoke-VMShareFolder -Tokens $rest }
        default { throw "Subcomando vm desconhecido: $sub" }
    }
}

try {
    if ($Args.Length -eq 0) {
        Show-Help
        exit 0
    }

    $root = $Args[0]
    $rest = @()
    if ($Args.Length -gt 1) {
        $rest = $Args[1..($Args.Length - 1)]
    }

    switch ($root) {
        'help' { Show-Help }
        '--help' { Show-Help }
        '-h' { Show-Help }
        'version' { Invoke-VersionCommand -Tokens $rest }
        '--version' { Invoke-VersionCommand -Tokens $rest }
        'self-update' { Invoke-SelfUpdate -Tokens $rest }
        'update' { Invoke-SelfUpdate -Tokens $rest }
        'vm' { Invoke-VMCommand -Tokens $rest }
        default {
            throw "Comando desconhecido: $root"
        }
    }
}
catch {
    Write-EA11Error $_.Exception.Message
    Write-Host ''
    Show-Help
    exit 1
}
