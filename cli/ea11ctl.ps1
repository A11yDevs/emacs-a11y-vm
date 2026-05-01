[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$EA11CTL_FALLBACK_VERSION = '0.1.6'
$EA11CTL_OWNER = 'A11yDevs'
$EA11CTL_REPO = 'emacs-a11y-vm'
$EA11CTL_BRANCH = 'main'

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
  ea11ctl help|-h|--help
  ea11ctl version|--version [-c|--check-update]
  ea11ctl self-update|update [-f|--force]
  ea11ctl vm|vm install|-i [args-do-install-release-vm.ps1]
  ea11ctl vm list|-l
  ea11ctl vm start|-s [-n|--name VM] [-h|--headless]
  ea11ctl vm stop|-S [-n|--name VM] [-f|--force]
  ea11ctl vm close|-c [-n|--name VM] [-t|--timeout SEGUNDOS]
  ea11ctl vm diagnose|-d [-n|--name VM] [-T|--try-start] [-L|--lines N]
  ea11ctl vm status|-q [-n|--name VM]
  ea11ctl vm ssh|-x [-u|--user USER] [-p|--port PORT] [-- extra-args]
  ea11ctl vm share-folder|-F add [-n|--name VM] -p|--path CAMINHO [--name NOME] [-r|--readonly]
  ea11ctl vm share-folder|-F remove [-n|--name VM] --name NOME
  ea11ctl vm share-folder|-F list [-n|--name VM]

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
    $remoteVersionUrl = "https://raw.githubusercontent.com/$EA11CTL_OWNER/$EA11CTL_REPO/$EA11CTL_BRANCH/cli/VERSION"
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

    try {
        $remoteVersion = Get-RemoteCliVersion
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

    $force = Has-Flag -Tokens $Tokens -Flags @('--force', '-f')

    $updateArgs = @()
    if ($force) {
        $updateArgs += '-Force'
    }

    $localVersion = Get-LocalCliVersion
    if (-not $force) {
        try {
            $remoteVersion = Get-RemoteCliVersion
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

    $remote = "https://raw.githubusercontent.com/$EA11CTL_OWNER/$EA11CTL_REPO/$EA11CTL_BRANCH/cli/install.ps1"
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
    $type = if (Has-Flag -Tokens $Tokens -Flags @('--headless', '-h')) { 'headless' } else { 'gui' }

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

function Get-VMState {
    param([string]$VMName)

    $raw = & VBoxManage showvminfo $VMName --machinereadable 2>$null
    $line = $raw | Where-Object { $_ -like 'VMState=*' }
    if (-not $line) {
        return $null
    }

    return (($line -replace '^VMState="?', '' -replace '"$', '').ToLowerInvariant())
}

function Get-VMUUID {
    param([string]$VMName)

    $raw = & VBoxManage showvminfo $VMName --machinereadable 2>$null
    $line = $raw | Where-Object { $_ -like 'UUID=*' }
    if (-not $line) {
        return $null
    }

    return ($line -replace '^UUID="?', '' -replace '"$', '')
}

function Get-VMConfigFile {
    param([string]$VMName)

    $raw = & VBoxManage showvminfo $VMName --machinereadable 2>$null
    $line = $raw | Where-Object { $_ -like 'CfgFile=*' }
    if (-not $line) {
        return $null
    }

    return ($line -replace '^CfgFile="?', '' -replace '"$', '')
}

function Get-VMHardeningLogPath {
    param([string]$VMName)

    $cfgFile = Get-VMConfigFile -VMName $VMName
    if (-not [string]::IsNullOrWhiteSpace($cfgFile)) {
        $cfgDir = Split-Path -Path $cfgFile -Parent
        if (-not [string]::IsNullOrWhiteSpace($cfgDir)) {
            return (Join-Path $cfgDir 'Logs\VBoxHardening.log')
        }
    }

    return (Join-Path $env:USERPROFILE "VirtualBox VMs\$VMName\Logs\VBoxHardening.log")
}

function Show-HardeningLogSummary {
    param(
        [string]$LogPath,
        [int]$Lines = 80
    )

    if (-not (Test-Path $LogPath)) {
        Write-EA11Warn "VBoxHardening.log nao encontrado em: $LogPath"
        return
    }

    Write-EA11Info "Lendo log: $LogPath"
    Write-Host ''
    Write-Host '--- Ultimas linhas do VBoxHardening.log ---' -ForegroundColor Cyan
    Get-Content -Path $LogPath -Tail $Lines -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
    Write-Host '--- Fim ---' -ForegroundColor Cyan
    Write-Host ''

    $patterns = 'supR3Hardened', 'Error', 'error', 'rc=', 'dll', 'NtCreateSection', 'Signature', 'denied'
    $hits = Select-String -Path $LogPath -Pattern $patterns -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -Last 30

    if ($hits) {
        Write-Host '--- Linhas suspeitas (hardening) ---' -ForegroundColor Yellow
        foreach ($hit in $hits) {
            Write-Host ("{0}:{1}" -f $hit.LineNumber, $hit.Line)
        }
        Write-Host '--- Fim ---' -ForegroundColor Yellow
    }
    else {
        Write-EA11Info 'Nenhuma linha suspeita encontrada pelos padrões padrão.'
    }
}

function Invoke-VMDiagnose {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $tryStart = Has-Flag -Tokens $Tokens -Flags @('--try-start', '-T')

    $linesRaw = Get-OptionValue -Tokens $Tokens -Names @('--lines', '-L') -Default '80'
    $lines = 80
    if (-not [int]::TryParse($linesRaw, [ref]$lines)) {
        throw "Valor invalido para --lines: $linesRaw"
    }

    Write-EA11Info "Diagnostico da VM '$vmName'"
    $state = Get-VMState -VMName $vmName
    if ($state) {
        Write-Host "Estado atual: $state"
    }
    else {
        Write-EA11Warn "Nao foi possivel obter estado da VM via VBoxManage showvminfo."
    }

    if ($tryStart) {
        Write-EA11Info "Tentando start headless para reproduzir erro..."
        try {
            $startOut = & VBoxManage startvm $vmName --type headless 2>&1
            if ($startOut) {
                $startOut | ForEach-Object { Write-Host $_ }
            }
        }
        catch {
            Write-EA11Warn "Start headless retornou erro: $($_.Exception.Message)"
        }
    }

    $logPath = Get-VMHardeningLogPath -VMName $vmName
    Show-HardeningLogSummary -LogPath $logPath -Lines $lines

    Write-Host ''
    Write-Host 'Dicas rapidas:' -ForegroundColor Green
    Write-Host '1) Desative temporariamente antivirus/overlay que injete DLL no VirtualBox.'
    Write-Host '2) Reinstale VirtualBox + Extension Pack na mesma versao.'
    Write-Host '3) Atualize VC++ Redistributable e reinicie o Windows.'
}

function Close-VMWindowProcess {
    param([string]$VMName)

    $vmUuid = Get-VMUUID -VMName $VMName
    if ([string]::IsNullOrWhiteSpace($vmUuid)) {
        Write-EA11Warn "Nao foi possivel resolver UUID da VM '$VMName' para fechar janela."
        return
    }

    if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
        Write-EA11Warn "Get-CimInstance indisponivel; nao foi possivel identificar a janela da VM para fechamento automatico."
        return
    }

    $candidates = Get-CimInstance Win32_Process -Filter "Name='VirtualBoxVM.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -match [regex]::Escape($vmUuid) -or
                $_.CommandLine -match [regex]::Escape($VMName)
            )
        }

    if (-not $candidates) {
        Write-EA11Info "Nenhuma janela/processo VirtualBoxVM aberta para '$VMName'."
        return
    }

    foreach ($proc in $candidates) {
        Write-EA11Info "Solicitando fechamento da janela da VM '$VMName' (PID $($proc.ProcessId))"

        # Fechamento gracioso: evita corromper estado interno do VirtualBox.
        Stop-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue
    }
}

function Invoke-VMClose {
    param([string[]]$Tokens)
    Ensure-VBoxManage

    $vmName = Get-VMName -Tokens $Tokens
    $timeoutRaw = Get-OptionValue -Tokens $Tokens -Names @('--timeout', '-t') -Default '30'
    $timeout = 30
    if (-not [int]::TryParse($timeoutRaw, [ref]$timeout)) {
        throw "Valor invalido para --timeout: $timeoutRaw"
    }

    $state = Get-VMState -VMName $vmName
    if (-not $state) {
        throw "Nao foi possivel consultar o estado da VM '$vmName'."
    }

    if ($state -in @('running', 'paused', 'stuck')) {
        Write-EA11Info "VM '$vmName' esta '$state'. Solicitando encerramento gracioso (ACPI)..."
        & VBoxManage controlvm $vmName acpipowerbutton | Out-Null

        $start = Get-Date
        do {
            Start-Sleep -Seconds 2
            $state = Get-VMState -VMName $vmName
            if (-not $state) { break }
            $elapsed = ((Get-Date) - $start).TotalSeconds
        } while (($state -in @('running', 'paused', 'stuck')) -and ($elapsed -lt $timeout))

        if ($state -in @('running', 'paused', 'stuck')) {
            Write-EA11Warn "VM '$vmName' nao desligou em $timeout s. Forcando poweroff..."
            & VBoxManage controlvm $vmName poweroff | Out-Null
        }
    }
    else {
        Write-EA11Info "VM '$vmName' ja estava parada (estado: $state)."
    }

    Close-VMWindowProcess -VMName $vmName
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
    $path = Get-OptionValue -Tokens $Tokens -Names @('--path', '-p') -Default ''
    $name = Get-OptionValue -Tokens $Tokens -Names @('--name') -Default 'host-home'
    $readonly = Has-Flag -Tokens $Tokens -Flags @('--readonly', '-r')

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
        throw "Uso: ea11ctl vm <install|list|start|stop|close|diagnose|status|ssh|share-folder>"
    }

    $sub = $Tokens[0]
    $rest = @()
    if ($Tokens.Length -gt 1) {
        $rest = $Tokens[1..($Tokens.Length - 1)]
    }

    switch ($sub) {
        { $_ -in @('install', '-i') }      { Invoke-VMInstall -InstallArgs $rest }
        { $_ -in @('list', '-l') }          { Invoke-VMList }
        { $_ -in @('start', '-s') }         { Invoke-VMStart -Tokens $rest }
        { $_ -in @('stop', '-S') }          { Invoke-VMStop -Tokens $rest }
        { $_ -in @('close', '-c') }         { Invoke-VMClose -Tokens $rest }
        { $_ -in @('diagnose', '-d') }      { Invoke-VMDiagnose -Tokens $rest }
        { $_ -in @('status', '-q') }        { Invoke-VMStatus -Tokens $rest }
        { $_ -in @('ssh', '-x') }           { Invoke-VMSSH -Tokens $rest }
        { $_ -in @('share-folder', '-F') }  { Invoke-VMShareFolder -Tokens $rest }
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
