[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$EA11CTL_FALLBACK_VERSION = '0.1.27'
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
    ea11ctl vm list|-l [--backend virtualbox|qemu]
    ea11ctl vm start|-s [-n|--name VM] [-h|--headless] [--backend virtualbox|qemu]
    ea11ctl vm stop|-S [-n|--name VM] [-f|--force] [--backend virtualbox|qemu]
    ea11ctl vm close|-c [-n|--name VM] [-t|--timeout SEGUNDOS] [--backend virtualbox|qemu]
    ea11ctl vm diagnose|-d [-n|--name VM] [-T|--try-start] [-L|--lines N] [--backend virtualbox|qemu]
    ea11ctl vm status|-q [-n|--name VM] [--backend virtualbox|qemu]
    ea11ctl vm ssh|-x [-u|--user USER] [-p|--port PORT] [--backend virtualbox|qemu] [-- extra-args]
  ea11ctl vm share-folder|-F add [-n|--name VM] -p|--path CAMINHO [--name NOME] [-r|--readonly]
  ea11ctl vm share-folder|-F remove [-n|--name VM] --name NOME
  ea11ctl vm share-folder|-F list [-n|--name VM]

Defaults:
    Backend: virtualbox
  VM: debian-a11y
  SSH user: a11ydevs
  SSH port: 2222

QEMU:
    Imagem de sistema: ~/.emacs-a11y-vm/debian-a11ydevs.qcow2
    Disco de dados: ~/.emacs-a11y-vm/<vm>-home.qcow2 (montado em /home na VM)
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
    $content = Invoke-WebRequest -Uri $remoteVersionUrl -Headers (Get-GitHubRawHeaders) -UseBasicParsing
    return $content.Content.Trim()
}

function Get-GitHubApiHeaders {
    return @{
        'User-Agent' = "ea11ctl/$($EA11CTL_FALLBACK_VERSION)"
        'Accept' = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
        'Cache-Control' = 'no-cache'
    }
}

function Get-GitHubRawHeaders {
    return @{
        'User-Agent' = "ea11ctl/$($EA11CTL_FALLBACK_VERSION)"
        'Cache-Control' = 'no-cache'
    }
}

function Get-TempDirectoryPath {
    if (-not [string]::IsNullOrWhiteSpace($env:TEMP)) {
        return $env:TEMP
    }

    $tmp = [System.IO.Path]::GetTempPath()
    if (-not [string]::IsNullOrWhiteSpace($tmp)) {
        return $tmp
    }

    throw 'Nao foi possivel determinar diretorio temporario para update.'
}

function Get-CacheBustValue {
    return [int64]([DateTime]::UtcNow - [DateTime]'1970-01-01').TotalSeconds
}

function Download-FileWithFallback {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Ref,
        [string]$File,
        [string]$Destination,
        [int64]$CacheBust
    )

    $attempts = @(
        @{ Uri = "https://raw.githubusercontent.com/$Owner/$Repo/$Ref/cli/$File?cb=$CacheBust"; Headers = (Get-GitHubRawHeaders); Label = 'raw+cb+headers' },
        @{ Uri = "https://raw.githubusercontent.com/$Owner/$Repo/$Ref/cli/$File"; Headers = (Get-GitHubRawHeaders); Label = 'raw+headers' },
        @{ Uri = "https://raw.githubusercontent.com/$Owner/$Repo/$Ref/cli/$File"; Headers = $null; Label = 'raw-sem-headers' },
        @{ Uri = "https://github.com/$Owner/$Repo/raw/$Ref/cli/$File"; Headers = $null; Label = 'github-raw-fallback' }
    )

    $lastErrorMessage = ''
    foreach ($attempt in $attempts) {
        try {
            Write-EA11Info "Download tentativa ($($attempt.Label)): $File"
            if ($null -ne $attempt.Headers) {
                Invoke-WebRequest -Uri $attempt.Uri -Headers $attempt.Headers -OutFile $Destination -UseBasicParsing
            }
            else {
                Invoke-WebRequest -Uri $attempt.Uri -OutFile $Destination -UseBasicParsing
            }

            return
        }
        catch {
            $lastErrorMessage = $_.Exception.Message
        }
    }

    throw "Falha ao baixar '$File' para ref '$Ref'. Ultimo erro: $lastErrorMessage"
}

function Get-RemoteBranchHeadSha {
    $apiUrl = "https://api.github.com/repos/$EA11CTL_OWNER/$EA11CTL_REPO/commits/$EA11CTL_BRANCH"
    $response = Invoke-WebRequest -Uri $apiUrl -Headers (Get-GitHubApiHeaders) -UseBasicParsing
    $json = $response.Content | ConvertFrom-Json

    if (-not $json -or -not $json.sha) {
        throw 'Resposta invalida da API do GitHub ao resolver SHA da branch.'
    }

    return ([string]$json.sha).Trim()
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

    # Atualiza os arquivos diretamente no diretorio de instalacao,
    # sem depender do install.ps1 (evita quebra por mudanca de assinatura entre versoes).
    # Usa SHA do commit da branch para evitar inconsistencias de cache no raw/main.
    $installDir = $PSScriptRoot
    $resolvedRef = $EA11CTL_BRANCH
    try {
        $resolvedRef = Get-RemoteBranchHeadSha
        Write-EA11Info "Ref remoto resolvido para commit $resolvedRef"
    }
    catch {
        Write-EA11Warn "Nao foi possivel resolver SHA da branch; usando ref '$EA11CTL_BRANCH'."
    }

    $files = @('ea11ctl.ps1', 'ea11ctl.cmd', 'VERSION')

    $cacheBust = Get-CacheBustValue
    $refsToTry = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($resolvedRef)) {
        [void]$refsToTry.Add($resolvedRef)
    }
    if ($resolvedRef -ne $EA11CTL_BRANCH) {
        [void]$refsToTry.Add($EA11CTL_BRANCH)
    }

    $tmpDir = Join-Path (Get-TempDirectoryPath) ("ea11ctl-update-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    $downloadOk = $false
    $lastErrorMessage = ''

    try {
        foreach ($ref in $refsToTry) {
            try {
                Write-EA11Info "Tentando download dos arquivos via ref '$ref'..."

                foreach ($file in $files) {
                    $dest = Join-Path $tmpDir $file
                    Write-EA11Info "Baixando $file..."
                    Download-FileWithFallback -Owner $EA11CTL_OWNER -Repo $EA11CTL_REPO -Ref $ref -File $file -Destination $dest -CacheBust $cacheBust
                }

                $downloadedVersion = (Get-Content -Path (Join-Path $tmpDir 'VERSION') -Raw -ErrorAction Stop).Trim()
                if ([string]::IsNullOrWhiteSpace($downloadedVersion)) {
                    throw 'Arquivo VERSION baixado vazio.'
                }

                $downloadOk = $true
                break
            }
            catch {
                $lastErrorMessage = $_.Exception.Message
                Write-EA11Warn "Falha no download via ref '$ref': $lastErrorMessage"
            }
        }

        if (-not $downloadOk) {
            throw "Nao foi possivel baixar arquivos de update. Ultimo erro: $lastErrorMessage"
        }

        foreach ($file in $files) {
            Copy-Item -Path (Join-Path $tmpDir $file) -Destination (Join-Path $installDir $file) -Force
        }
    }
    finally {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    $newVersion = (Get-Content -Path (Join-Path $installDir 'VERSION') -Raw -ErrorAction SilentlyContinue).Trim()
    Write-Host "ea11ctl atualizado para v$newVersion" -ForegroundColor Green
}

function Assert-Command {
    param([string]$Command)
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Comando '$Command' nao encontrado no PATH."
    }
}

function Ensure-CommandWithCandidates {
    param(
        [string]$Command,
        [string[]]$Candidates,
        [string]$Hint
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        return
    }

    foreach ($candidate in $Candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-Path $candidate) {
            $dir = Split-Path -Path $candidate -Parent
            if (-not [string]::IsNullOrWhiteSpace($dir)) {
                $env:PATH = "$dir;$env:PATH"
            }

            break
        }
    }

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Comando '$Command' nao encontrado no PATH. $Hint"
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

function Has-OptionName {
    param(
        [string[]]$Tokens,
        [string[]]$Names
    )

    foreach ($token in $Tokens) {
        foreach ($name in $Names) {
            if ($token -eq $name) {
                return $true
            }
        }
    }

    return $false
}

function Get-IntOptionValue {
    param(
        [string[]]$Tokens,
        [string[]]$Names,
        [int]$Default,
        [string]$OptionName
    )

    $raw = Get-OptionValue -Tokens $Tokens -Names $Names -Default ([string]$Default)
    $value = 0
    if (-not [int]::TryParse($raw, [ref]$value)) {
        throw ("Valor invalido para {0}: {1}" -f $OptionName, $raw)
    }

    return $value
}

function Resolve-VMBackend {
    param(
        [string[]]$Tokens,
        [string]$DefaultBackend = 'virtualbox'
    )

    $backend = $DefaultBackend
    $cleanTokens = New-Object System.Collections.Generic.List[string]

    for ($i = 0; $i -lt $Tokens.Length; $i++) {
        $token = $Tokens[$i]

        if ($token -in @('--backend', '-b')) {
            if (($i + 1) -ge $Tokens.Length) {
                throw "Use --backend com um valor (virtualbox ou qemu)."
            }

            $backend = $Tokens[$i + 1]
            $i++
            continue
        }

        if ($token -eq '--qemu') {
            $backend = 'qemu'
            continue
        }

        if ($token -eq '--virtualbox') {
            $backend = 'virtualbox'
            continue
        }

        [void]$cleanTokens.Add($token)
    }

    $normalized = $backend.ToLowerInvariant()
    switch ($normalized) {
        'virtualbox' { }
        'vbox' { $normalized = 'virtualbox' }
        'qemu' { }
        default { throw "Backend desconhecido: $backend (use virtualbox ou qemu)." }
    }

    return @{
        Backend = $normalized
        Tokens = $cleanTokens.ToArray()
    }
}

function Get-HomeDirectoryPath {
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        return $env:HOME
    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        return $env:USERPROFILE
    }

    throw "Nao foi possivel detectar o diretorio HOME do usuario."
}

function Get-EA11StateDirectory {
    $base = Join-Path (Get-HomeDirectoryPath) '.emacs-a11y-vm'
    if (-not (Test-Path $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
    }

    return $base
}

function Get-QemuStateDirectory {
    $stateDir = Join-Path (Get-EA11StateDirectory) 'qemu'
    if (-not (Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }

    return $stateDir
}

function Get-QemuStateFilePath {
    param([string]$VMName)

    return (Join-Path (Get-QemuStateDirectory) "$VMName.json")
}

function Load-QemuState {
    param([string]$VMName)

    $filePath = Get-QemuStateFilePath -VMName $VMName
    if (-not (Test-Path $filePath)) {
        return $null
    }

    $raw = Get-Content -Path $filePath -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $null
    }

    return ($raw | ConvertFrom-Json)
}

function Save-QemuState {
    param(
        [string]$VMName,
        [hashtable]$State
    )

    $filePath = Get-QemuStateFilePath -VMName $VMName
    $State | ConvertTo-Json -Depth 5 | Set-Content -Path $filePath -Encoding utf8
}

function Get-ProcessByIdSafe {
    param([int]$ProcessId)

    try {
        return (Get-Process -Id $ProcessId -ErrorAction Stop)
    }
    catch {
        return $null
    }
}

function Ensure-QemuSystem {
    $candidates = @(
        "$env:ProgramFiles\qemu\qemu-system-x86_64w.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-system-x86_64w.exe",
        "$env:ProgramFiles\qemu\qemu-system-x86_64.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-system-x86_64.exe",
        "$env:ChocolateyInstall\bin\qemu-system-x86_64.exe",
        "$env:USERPROFILE\scoop\apps\qemu\current\qemu-system-x86_64.exe",
        '/opt/homebrew/bin/qemu-system-x86_64',
        '/usr/local/bin/qemu-system-x86_64',
        '/usr/bin/qemu-system-x86_64'
    )

    Ensure-CommandWithCandidates -Command 'qemu-system-x86_64' -Candidates $candidates -Hint "Instale o QEMU e garanta qemu-system-x86_64 no PATH."
}

function Resolve-QemuSystemExecutable {
    param([bool]$Headless)

    if ((Test-IsWindowsHost) -and (-not $Headless)) {
        $guiCandidates = @(
            "$env:ProgramFiles\qemu\qemu-system-x86_64w.exe",
            "${env:ProgramFiles(x86)}\qemu\qemu-system-x86_64w.exe",
            "$env:ChocolateyInstall\bin\qemu-system-x86_64w.exe",
            "$env:USERPROFILE\scoop\apps\qemu\current\qemu-system-x86_64w.exe"
        )

        $cmd = Get-Command 'qemu-system-x86_64w.exe' -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }

        foreach ($candidate in $guiCandidates) {
            if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
                return $candidate
            }
        }
    }

    $normalCmd = Get-Command 'qemu-system-x86_64' -ErrorAction SilentlyContinue
    if ($normalCmd) {
        return $normalCmd.Source
    }

    return 'qemu-system-x86_64'
}

function Resolve-HostUserName {
    if (-not [string]::IsNullOrWhiteSpace($env:USER)) {
        return $env:USER
    }

    if (-not [string]::IsNullOrWhiteSpace($env:USERNAME)) {
        return $env:USERNAME
    }

    return $null
}

function Get-QemuHostHomeShareConfig {
    $hostUser = Resolve-HostUserName
    if ([string]::IsNullOrWhiteSpace($hostUser)) {
        return $null
    }

    $candidatePaths = @(
        "/Users/$hostUser",
        "/home/$hostUser"
    )

    $hostPath = $null
    foreach ($candidate in $candidatePaths) {
        if (Test-Path $candidate) {
            $hostPath = $candidate
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($hostPath)) {
        return $null
    }

    $safeUser = ($hostUser -replace '[^a-zA-Z0-9_-]', '_')
    return @{
        HostUser = $hostUser
        HostPath = $hostPath
        MountTag = "hosthome_$safeUser"
        GuestMountPoint = "/home/$hostUser"
    }
}

function Get-QemuAvailableAudioDrivers {
    param([string]$QemuExecutable)

    try {
        $output = & $QemuExecutable -audiodev help 2>&1
    }
    catch {
        return @()
    }

    if (-not $output) {
        return @()
    }

    $drivers = New-Object System.Collections.Generic.List[string]
    $capture = $false

    foreach ($line in $output) {
        $text = [string]$line
        if ($text -match 'Available audio drivers') {
            $capture = $true
            continue
        }

        if (-not $capture) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        foreach ($token in ($text -split '\s+')) {
            if ([string]::IsNullOrWhiteSpace($token)) {
                continue
            }

            $normalized = $token.Trim().ToLowerInvariant()
            if (-not $drivers.Contains($normalized)) {
                [void]$drivers.Add($normalized)
            }
        }
    }

    return $drivers.ToArray()
}

function Test-QemuVirtfsSupport {
    param([string]$QemuExecutable)

    try {
        $helpOutput = & $QemuExecutable -help 2>&1
    }
    catch {
        return $false
    }

    if (-not $helpOutput) {
        return $false
    }

    $text = ($helpOutput | Out-String)
    if (-not ($text -match '(?i)\-virtfs|virtfs')) {
        return $false
    }

    # Alguns builds listam -virtfs no help, mas desabilitam o recurso em runtime.
    # Fazemos um probe real com uma execucao minima para confirmar suporte efetivo.
    try {
        $probeOut = & $QemuExecutable -S -machine none -nodefaults -nographic -virtfs 'local,path=.,mount_tag=ea11probe,security_model=none,id=ea11probe' 2>&1
        $probeText = ($probeOut | Out-String)

        if ($probeText -match '(?i)virtfs support is disabled|there is no option group virtfs') {
            return $false
        }

        # Se nao retornou mensagens de desabilitado, consideramos suportado.
        return $true
    }
    catch {
        $errText = $_.Exception.Message
        if ($errText -match '(?i)virtfs support is disabled|there is no option group virtfs') {
            return $false
        }

        # Erros nao relacionados ao virtfs nao invalidam necessariamente o suporte.
        return $true
    }
}

function Test-QemuUserNetSmbSupport {
    param([string]$QemuExecutable)

    try {
        $helpOutput = & $QemuExecutable -help 2>&1
    }
    catch {
        return $false
    }

    if (-not $helpOutput) {
        return $false
    }

    $text = ($helpOutput | Out-String)
    return ($text -match '(?i)smb=')
}

function New-QemuBaseArgs {
    param(
        [int]$Memory,
        [int]$Cpus,
        [string]$SystemDisk,
        [string]$UserDataDisk,
        [string]$NetdevValue,
        [hashtable]$HostHomeShare,
        [string]$HostHomeShareMode
    )

    $args = @(
        '-m', "$Memory",
        '-smp', "$Cpus",
        '-drive', "file=$SystemDisk,format=qcow2,if=virtio",
        '-drive', "file=$UserDataDisk,format=qcow2,if=virtio",
        '-netdev', $NetdevValue,
        '-device', 'virtio-net,netdev=net0',
        '-serial', 'none',
        '-monitor', 'none'
    )

    if (($HostHomeShareMode -eq '9p') -and $HostHomeShare) {
        $args += @(
            '-virtfs',
            "local,path=$($HostHomeShare.HostPath),mount_tag=$($HostHomeShare.MountTag),security_model=none,id=$($HostHomeShare.MountTag)"
        )
    }

    return $args
}

function Ensure-QemuImg {
    $candidates = @(
        "$env:ProgramFiles\qemu\qemu-img.exe",
        "${env:ProgramFiles(x86)}\qemu\qemu-img.exe",
        "$env:ChocolateyInstall\bin\qemu-img.exe",
        "$env:USERPROFILE\scoop\apps\qemu\current\qemu-img.exe",
        '/opt/homebrew/bin/qemu-img',
        '/usr/local/bin/qemu-img',
        '/usr/bin/qemu-img'
    )

    Ensure-CommandWithCandidates -Command 'qemu-img' -Candidates $candidates -Hint "Instale o QEMU e garanta qemu-img no PATH."
}

function Test-IsWindowsHost {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return [bool]$IsWindows
    }

    return ($env:OS -eq 'Windows_NT')
}

function Test-IsMacOSHost {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return [bool]$IsMacOS
    }

    return $false
}

function Get-QemuAccelerationArgs {
    param([string]$Mode = 'auto')

    $normalizedMode = $Mode.ToLowerInvariant()

    if ($normalizedMode -eq 'tcg') {
        return @('-accel', 'tcg,thread=multi', '-cpu', 'qemu64')
    }

    if (Test-IsMacOSHost) {
        return @('-accel', 'hvf', '-accel', 'tcg,thread=multi', '-cpu', 'host,-svm')
    }

    if (Test-IsWindowsHost) {
        return @('-accel', 'whpx', '-accel', 'tcg,thread=multi', '-cpu', 'qemu64')
    }

    if (Test-Path '/dev/kvm') {
        return @('-enable-kvm', '-cpu', 'host')
    }

    return @('-accel', 'tcg,thread=multi', '-cpu', 'max')
}

function Get-QemuAudioArgs {
    param(
        [string]$Backend = 'auto',
        [string[]]$SupportedDrivers = @()
    )

    $normalizedBackend = $Backend.ToLowerInvariant()

    if (Test-IsMacOSHost) {
        return @(
            '-audiodev', 'coreaudio,id=audio0,out.frequency=44100,out.mixing-engine=on,in.mixing-engine=off',
            '-device', 'intel-hda',
            '-device', 'hda-duplex,audiodev=audio0'
        )
    }

    if (Test-IsWindowsHost) {
        $supported = @($SupportedDrivers | ForEach-Object { ([string]$_).ToLowerInvariant() })

        $driver = 'dsound'
        if ($normalizedBackend -eq 'auto') {
            $preferred = @('wasapi', 'dsound', 'sdl')
            if ($supported.Count -gt 0) {
                foreach ($candidate in $preferred) {
                    if ($supported -contains $candidate) {
                        $driver = $candidate
                        break
                    }
                }
            }
        }
        else {
            $driver = $normalizedBackend
            if (($supported.Count -gt 0) -and (-not ($supported -contains $driver))) {
                throw "Backend de audio '$driver' nao suportado por este QEMU. Disponiveis: $($supported -join ', ')"
            }
        }

        Write-EA11Info "Backend de audio selecionado (Windows): $driver"

        return @(
            '-audiodev', "$driver,id=audio0",
            '-device', 'intel-hda',
            '-device', 'hda-duplex,audiodev=audio0'
        )
    }

    return @(
        '-audiodev', 'pa,id=audio0',
        '-device', 'intel-hda',
        '-device', 'hda-duplex,audiodev=audio0'
    )
}

function Resolve-QemuSystemDiskPath {
    $stateDir = Get-EA11StateDirectory
    $defaultDisk = Join-Path $stateDir 'debian-a11ydevs.qcow2'
    if (Test-Path $defaultDisk) {
        return $defaultDisk
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    $repoRoot = Get-RepoRoot
    if ($repoRoot) {
        [void]$candidates.Add((Join-Path (Join-Path $repoRoot 'output') 'debian-a11ydevs.qcow2'))
        [void]$candidates.Add((Join-Path (Join-Path $repoRoot 'output-hvf-build') 'debian-a11ydevs.qcow2'))
    }

    $cwd = (Get-Location).Path
    [void]$candidates.Add((Join-Path (Join-Path $cwd 'output') 'debian-a11ydevs.qcow2'))
    [void]$candidates.Add((Join-Path (Join-Path $cwd 'output-hvf-build') 'debian-a11ydevs.qcow2'))

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            Write-EA11Info "Copiando imagem de sistema para consistencia em $defaultDisk"
            Copy-Item -Path $candidate -Destination $defaultDisk -Force
            return $defaultDisk
        }
    }

    throw "Imagem de sistema QEMU nao encontrada. Coloque debian-a11ydevs.qcow2 em $stateDir"
}

function Ensure-QemuUserDataDisk {
    param(
        [string]$VMName,
        [int]$SizeGB = 10
    )

    $stateDir = Get-EA11StateDirectory
    $diskPath = Join-Path $stateDir "$VMName-home.qcow2"
    if (Test-Path $diskPath) {
        return $diskPath
    }

    Ensure-QemuImg
    Write-EA11Info "Criando disco de dados do usuario ($SizeGB`G): $diskPath"
    & qemu-img create -f qcow2 $diskPath "$SizeGB`G" | Out-Null

    return $diskPath
}

function Get-QemuLogsDirectory {
    $logsDir = Join-Path (Get-QemuStateDirectory) 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    return $logsDir
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

function Invoke-QemuVMList {
    $stateDir = Get-QemuStateDirectory
    $files = Get-ChildItem -Path $stateDir -Filter '*.json' -File -ErrorAction SilentlyContinue

    if (-not $files) {
        Write-EA11Info 'Nenhuma VM QEMU registrada em ~/.emacs-a11y-vm.'
        return
    }

    foreach ($file in $files) {
        $state = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        $vmPid = 0
        if ($state.pid) {
            $vmPid = [int]$state.pid
        }

        $running = $false
        if ($vmPid -gt 0) {
            $running = $null -ne (Get-ProcessByIdSafe -ProcessId $vmPid)
        }

        $status = if ($running) { 'running' } else { 'stopped' }
        Write-Host "$($state.name) (qemu) - $status - ssh:$($state.sshPort)"
    }
}

function Invoke-QemuVMStart {
    param([string[]]$Tokens)

    Ensure-QemuSystem

    $vmName = Get-VMName -Tokens $Tokens
    $sshPort = Get-IntOptionValue -Tokens $Tokens -Names @('--port', '--ssh-port', '-p') -Default 2222 -OptionName '--ssh-port'
    $memory = Get-IntOptionValue -Tokens $Tokens -Names @('--memory', '-m') -Default 1536 -OptionName '--memory'
    $cpus = Get-IntOptionValue -Tokens $Tokens -Names @('--cpus') -Default 1 -OptionName '--cpus'
    $userDataSize = Get-IntOptionValue -Tokens $Tokens -Names @('--user-data-size') -Default 10 -OptionName '--user-data-size'
    $headless = Has-Flag -Tokens $Tokens -Flags @('--headless', '-h')
    $audioBackend = Get-OptionValue -Tokens $Tokens -Names @('--audio-backend') -Default 'auto'
    $disableHostHomeShare = Has-Flag -Tokens $Tokens -Flags @('--no-host-home-share')
    $qemuExecutable = Resolve-QemuSystemExecutable -Headless:$headless
    $supportedAudioDrivers = Get-QemuAvailableAudioDrivers -QemuExecutable $qemuExecutable

    $existing = Load-QemuState -VMName $vmName
    if ($existing -and $existing.pid) {
        $existingPid = [int]$existing.pid
        if ($existingPid -gt 0 -and (Get-ProcessByIdSafe -ProcessId $existingPid)) {
            throw "VM QEMU '$vmName' ja esta em execucao (PID $existingPid)."
        }
    }

    $systemDisk = Resolve-QemuSystemDiskPath
    $userDataDisk = Ensure-QemuUserDataDisk -VMName $vmName -SizeGB $userDataSize
    $logsDir = Get-QemuLogsDirectory
    $stdoutLog = Join-Path $logsDir "$vmName-stdout.log"
    $stderrLog = Join-Path $logsDir "$vmName-stderr.log"

    $hostHomeShare = $null
    $hostHomeShareMode = $null
    $qemuSmbShare = $null
    $netdevValue = "user,id=net0,hostfwd=tcp::$sshPort-:22"

    if (-not $disableHostHomeShare) {
        $hostHomeShare = Get-QemuHostHomeShareConfig
        if ($hostHomeShare) {
            if (Test-QemuVirtfsSupport -QemuExecutable $qemuExecutable) {
                $hostHomeShareMode = '9p'
                Write-EA11Info "Compartilhando host home via 9p: $($hostHomeShare.HostPath) -> $($hostHomeShare.GuestMountPoint)"
            }
            elseif (Test-QemuUserNetSmbSupport -QemuExecutable $qemuExecutable) {
                $hostHomeShareMode = 'smb'
                $netdevValue = "user,id=net0,hostfwd=tcp::$sshPort-:22,smb=$($hostHomeShare.HostPath)"
                $qemuSmbShare = @{
                    Server = '10.0.2.4'
                    Share = 'qemu'
                    GuestMountPoint = '/home/hosthome'
                }
                Write-EA11Warn 'virtfs/9p indisponivel neste QEMU. Usando fallback SMB (//10.0.2.4/qemu -> /home/hosthome).'
            }
            else {
                Write-EA11Warn 'Este binario QEMU nao suporta virtfs/9p nem SMB usernet. VM iniciada sem compartilhamento automatico da home do host.'
                $hostHomeShare = $null
            }
        }
        else {
            Write-EA11Warn 'Nao foi possivel resolver pasta home do host para compartilhamento 9p automatico.'
        }
    }

    $qemuArgs = New-QemuBaseArgs -Memory $memory -Cpus $cpus -SystemDisk $systemDisk -UserDataDisk $userDataDisk -NetdevValue $netdevValue -HostHomeShare $hostHomeShare -HostHomeShareMode $hostHomeShareMode

    $accelMode = Get-OptionValue -Tokens $Tokens -Names @('--accel') -Default 'auto'
    $qemuArgs += Get-QemuAccelerationArgs -Mode $accelMode

    if ($headless) {
        $qemuArgs += @('-nographic', '-serial', 'stdio')
    }
    else {
        if (Test-IsMacOSHost) {
            $qemuArgs += @('-vga', 'virtio', '-display', 'cocoa,zoom-to-fit=on,full-screen=on', '-k', 'en-us')
        }
        elseif (Test-IsWindowsHost) {
            $qemuArgs += @('-vga', 'virtio', '-display', 'sdl')
        }
        else {
            $qemuArgs += @('-vga', 'virtio')
        }

        $qemuArgs += Get-QemuAudioArgs -Backend $audioBackend -SupportedDrivers $supportedAudioDrivers
    }

    Write-EA11Info "Iniciando VM QEMU '$vmName'..."
    $startParams = @{
        FilePath = $qemuExecutable
        ArgumentList = $qemuArgs
        PassThru = $true
        RedirectStandardOutput = $stdoutLog
        RedirectStandardError = $stderrLog
    }

    if ((Test-IsWindowsHost) -and $headless) {
        $startParams.WindowStyle = 'Hidden'
    }

    $proc = Start-Process @startParams

    Start-Sleep -Seconds 2
    $alive = Get-ProcessByIdSafe -ProcessId $proc.Id

    if ((-not $alive) -and (Test-IsWindowsHost) -and ($accelMode -eq 'auto')) {
        $lastError = ''
        if (Test-Path $stderrLog) {
            $lastError = (Get-Content -Path $stderrLog -Tail 80 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
        }

        if ($lastError -match 'WHPX|Unexpected VP exit code|APX|MPX') {
            Write-EA11Warn 'WHPX falhou no host atual. Retentando automaticamente com aceleracao TCG (modo compatibilidade)...'

            $qemuArgs = New-QemuBaseArgs -Memory $memory -Cpus $cpus -SystemDisk $systemDisk -UserDataDisk $userDataDisk -NetdevValue $netdevValue -HostHomeShare $hostHomeShare -HostHomeShareMode $hostHomeShareMode

            $qemuArgs += Get-QemuAccelerationArgs -Mode 'tcg'

            if ($headless) {
                $qemuArgs += @('-nographic', '-serial', 'stdio')
            }
            else {
                if (Test-IsMacOSHost) {
                    $qemuArgs += @('-vga', 'virtio', '-display', 'cocoa,zoom-to-fit=on,full-screen=on', '-k', 'en-us')
                }
                elseif (Test-IsWindowsHost) {
                    $qemuArgs += @('-vga', 'virtio', '-display', 'sdl')
                }
                else {
                    $qemuArgs += @('-vga', 'virtio')
                }

                $qemuArgs += Get-QemuAudioArgs
            }

            $startParams.ArgumentList = $qemuArgs
            $proc = Start-Process @startParams
            Start-Sleep -Seconds 2
            $alive = Get-ProcessByIdSafe -ProcessId $proc.Id
        }
    }

    if ((-not $alive) -and (Test-IsWindowsHost) -and ($audioBackend -eq 'auto')) {
        $lastError = ''
        if (Test-Path $stderrLog) {
            $lastError = (Get-Content -Path $stderrLog -Tail 120 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
        }

        if ($lastError -match 'audiodev|wasapi|dsound|audio') {
            $fallbackAudio = 'dsound'
            if (($supportedAudioDrivers -contains 'sdl') -and (-not ($supportedAudioDrivers -contains 'dsound'))) {
                $fallbackAudio = 'sdl'
            }
            Write-EA11Warn "Backend de audio automatico falhou. Retentando com '$fallbackAudio'..."

            $qemuArgs = New-QemuBaseArgs -Memory $memory -Cpus $cpus -SystemDisk $systemDisk -UserDataDisk $userDataDisk -NetdevValue $netdevValue -HostHomeShare $hostHomeShare -HostHomeShareMode $hostHomeShareMode

            $qemuArgs += Get-QemuAccelerationArgs -Mode $accelMode

            if ($headless) {
                $qemuArgs += @('-nographic', '-serial', 'stdio')
            }
            else {
                if (Test-IsMacOSHost) {
                    $qemuArgs += @('-vga', 'virtio', '-display', 'cocoa,zoom-to-fit=on,full-screen=on', '-k', 'en-us')
                }
                elseif (Test-IsWindowsHost) {
                    $qemuArgs += @('-vga', 'virtio', '-display', 'sdl')
                }
                else {
                    $qemuArgs += @('-vga', 'virtio')
                }

                $qemuArgs += Get-QemuAudioArgs -Backend $fallbackAudio -SupportedDrivers $supportedAudioDrivers
            }

            $startParams.ArgumentList = $qemuArgs
            $proc = Start-Process @startParams
            Start-Sleep -Seconds 2
            $alive = Get-ProcessByIdSafe -ProcessId $proc.Id
        }
    }

    if (-not $alive) {
        $lastError = ''
        if (Test-Path $stderrLog) {
            $lastError = (Get-Content -Path $stderrLog -Tail 20 -ErrorAction SilentlyContinue) -join [Environment]::NewLine
        }
        throw "Falha ao iniciar QEMU para '$vmName'. Log: $stderrLog`n$lastError"
    }

    Save-QemuState -VMName $vmName -State @{
        name = $vmName
        backend = 'qemu'
        pid = $proc.Id
        sshPort = $sshPort
        sshUser = 'a11ydevs'
        systemDisk = $systemDisk
        userDataDisk = $userDataDisk
        homeMount = '/home'
        stdoutLog = $stdoutLog
        stderrLog = $stderrLog
        hostHomeSharePath = if ($hostHomeShare) { $hostHomeShare.HostPath } else { $null }
        hostHomeShareTag = if ($hostHomeShare) { $hostHomeShare.MountTag } else { $null }
        hostHomeShareMode = if ($hostHomeShareMode) { $hostHomeShareMode } else { $null }
        hostHomeSmbServer = if ($qemuSmbShare) { $qemuSmbShare.Server } else { $null }
        hostHomeSmbShare = if ($qemuSmbShare) { $qemuSmbShare.Share } else { $null }
        hostHomeGuestMountPoint = if ($hostHomeShare) { $hostHomeShare.GuestMountPoint } else { $null }
        startedAt = (Get-Date).ToString('o')
        lastStatus = 'running'
    }

    Write-Host "VM: $vmName"
    Write-Host "Backend: qemu"
    Write-Host "PID: $($proc.Id)"
    Write-Host "SSH: localhost:$sshPort"
    Write-Host "Sistema: $systemDisk"
    Write-Host "Dados (/home): $userDataDisk"
    if (($hostHomeShareMode -eq '9p') -and $hostHomeShare) {
        Write-Host "Host home (9p): $($hostHomeShare.HostPath) -> $($hostHomeShare.GuestMountPoint)"
    }
    elseif (($hostHomeShareMode -eq 'smb') -and $hostHomeShare -and $qemuSmbShare) {
        Write-Host "Host home (SMB): $($hostHomeShare.HostPath) -> //$($qemuSmbShare.Server)/$($qemuSmbShare.Share) -> $($qemuSmbShare.GuestMountPoint)"
    }
}

function Invoke-QemuVMStop {
    param([string[]]$Tokens)

    $vmName = Get-VMName -Tokens $Tokens
    $force = Has-Flag -Tokens $Tokens -Flags @('--force', '-f')
    $timeout = Get-IntOptionValue -Tokens $Tokens -Names @('--timeout', '-t') -Default 30 -OptionName '--timeout'

    $state = Load-QemuState -VMName $vmName
    if (-not $state) {
        Write-EA11Warn "VM QEMU '$vmName' nao possui estado registrado em ~/.emacs-a11y-vm."
        return
    }

    $vmPid = 0
    if ($state.pid) {
        $vmPid = [int]$state.pid
    }

    if ($vmPid -le 0) {
        Write-EA11Warn "Estado da VM QEMU '$vmName' nao possui PID ativo."
        return
    }

    $proc = Get-ProcessByIdSafe -ProcessId $vmPid
    if (-not $proc) {
        Write-EA11Warn "Processo da VM QEMU '$vmName' (PID $vmPid) nao esta mais em execucao."
        Save-QemuState -VMName $vmName -State @{
            name = $vmName
            backend = 'qemu'
            pid = $null
            sshPort = $state.sshPort
            sshUser = $state.sshUser
            systemDisk = $state.systemDisk
            userDataDisk = $state.userDataDisk
            homeMount = '/home'
            stdoutLog = $state.stdoutLog
            stderrLog = $state.stderrLog
            startedAt = $state.startedAt
            stoppedAt = (Get-Date).ToString('o')
            lastStatus = 'stopped'
        }
        return
    }

    if ($force) {
        Write-EA11Warn "Forcando encerramento da VM QEMU '$vmName' (PID $vmPid)..."
        Stop-Process -Id $vmPid -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-EA11Info "Encerrando VM QEMU '$vmName' de forma graciosa (PID $vmPid)..."
        Stop-Process -Id $vmPid -ErrorAction SilentlyContinue

        $start = Get-Date
        do {
            Start-Sleep -Seconds 1
            $stillRunning = $null -ne (Get-ProcessByIdSafe -ProcessId $vmPid)
            $elapsed = ((Get-Date) - $start).TotalSeconds
        } while ($stillRunning -and ($elapsed -lt $timeout))

        if ($stillRunning) {
            Write-EA11Warn "VM QEMU '$vmName' nao encerrou em $timeout s. Aplicando force kill."
            Stop-Process -Id $vmPid -Force -ErrorAction SilentlyContinue
        }
    }

    Save-QemuState -VMName $vmName -State @{
        name = $vmName
        backend = 'qemu'
        pid = $null
        sshPort = $state.sshPort
        sshUser = $state.sshUser
        systemDisk = $state.systemDisk
        userDataDisk = $state.userDataDisk
        homeMount = '/home'
        stdoutLog = $state.stdoutLog
        stderrLog = $state.stderrLog
        startedAt = $state.startedAt
        stoppedAt = (Get-Date).ToString('o')
        lastStatus = 'stopped'
    }
}

function Invoke-QemuVMStatus {
    param([string[]]$Tokens)

    $vmName = Get-VMName -Tokens $Tokens
    $state = Load-QemuState -VMName $vmName
    if (-not $state) {
        Write-EA11Warn "VM QEMU '$vmName' nao registrada em ~/.emacs-a11y-vm."
        return
    }

    $vmPid = 0
    if ($state.pid) {
        $vmPid = [int]$state.pid
    }

    $running = $false
    if ($vmPid -gt 0) {
        $running = $null -ne (Get-ProcessByIdSafe -ProcessId $vmPid)
    }

    $status = if ($running) { 'running' } else { 'stopped' }
    Write-Host "VM: $vmName"
    Write-Host 'Backend: qemu'
    Write-Host "State: $status"
    Write-Host "PID: $vmPid"
    Write-Host "SSH: localhost:$($state.sshPort)"
    Write-Host "Sistema: $($state.systemDisk)"
    Write-Host "Dados (/home): $($state.userDataDisk)"
    if ($state.hostHomeShareMode -eq '9p' -and $state.hostHomeSharePath -and $state.hostHomeGuestMountPoint) {
        Write-Host "Host home (9p): $($state.hostHomeSharePath) -> $($state.hostHomeGuestMountPoint)"
    }
    elseif ($state.hostHomeShareMode -eq 'smb' -and $state.hostHomeSmbServer -and $state.hostHomeSmbShare) {
        $guestMount = if ($state.hostHomeGuestMountPoint) { [string]$state.hostHomeGuestMountPoint } else { '/home/hosthome' }
        Write-Host "Host home (SMB): $($state.hostHomeSharePath) -> //$($state.hostHomeSmbServer)/$($state.hostHomeSmbShare) -> $guestMount"
    }
    Write-Host "Estado: $(Get-QemuStateFilePath -VMName $vmName)"
}

function Invoke-QemuVMSSH {
    param([string[]]$Tokens)

    Assert-Command 'ssh'

    $vmName = Get-VMName -Tokens $Tokens
    $state = Load-QemuState -VMName $vmName

    $user = Get-OptionValue -Tokens $Tokens -Names @('--user', '-u') -Default 'a11ydevs'
    $portFromState = '2222'
    if ($state -and $state.sshPort) {
        $portFromState = [string]$state.sshPort
    }

    $port = if (Has-OptionName -Tokens $Tokens -Names @('--port', '-p')) {
        Get-OptionValue -Tokens $Tokens -Names @('--port', '-p') -Default $portFromState
    }
    else {
        $portFromState
    }

    $extraStart = [Array]::IndexOf($Tokens, '--')
    $extra = @()
    if ($extraStart -ge 0 -and ($extraStart + 1) -lt $Tokens.Length) {
        $extra = $Tokens[($extraStart + 1)..($Tokens.Length - 1)]
    }

    Write-EA11Info "Abrindo SSH para $user@localhost:$port"
    & ssh -p $port "$user@localhost" @extra
}

function Invoke-QemuVMDiagnose {
    param([string[]]$Tokens)

    $vmName = Get-VMName -Tokens $Tokens
    $state = Load-QemuState -VMName $vmName
    if (-not $state) {
        Write-EA11Warn "VM QEMU '$vmName' nao registrada."
        return
    }

    Invoke-QemuVMStatus -Tokens $Tokens

    $lines = Get-IntOptionValue -Tokens $Tokens -Names @('--lines', '-L') -Default 80 -OptionName '--lines'
    if ($state.stderrLog -and (Test-Path $state.stderrLog)) {
        Write-Host ''
        Write-Host '--- Ultimas linhas do log de erro do QEMU ---' -ForegroundColor Cyan
        Get-Content -Path $state.stderrLog -Tail $lines -ErrorAction SilentlyContinue | ForEach-Object { Write-Host $_ }
        Write-Host '--- Fim ---' -ForegroundColor Cyan
    }
    else {
        Write-EA11Warn 'Log de erro do QEMU nao encontrado.'
    }
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
    param(
        [string[]]$Tokens,
        [string]$DefaultBackend = 'virtualbox'
    )

    $resolved = Resolve-VMBackend -Tokens $Tokens -DefaultBackend $DefaultBackend
    $backend = $resolved.Backend
    $cleanTokens = $resolved.Tokens

    if ($cleanTokens.Length -eq 0) {
        throw "Uso: ea11ctl vm <install|list|start|stop|close|diagnose|status|ssh|share-folder>"
    }

    $sub = $cleanTokens[0]
    $rest = @()
    if ($cleanTokens.Length -gt 1) {
        $rest = $cleanTokens[1..($cleanTokens.Length - 1)]
    }

    switch ($sub) {
        { $_ -in @('install', '-i') } {
            if ($backend -eq 'qemu') {
                throw 'Comando vm install ainda nao suporta backend qemu. Use vm start --backend qemu para bootstrap automatico da imagem padrao.'
            }
            Invoke-VMInstall -InstallArgs $rest
        }
        { $_ -in @('list', '-l') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMList
            }
            else {
                Invoke-VMList
            }
        }
        { $_ -in @('start', '-s') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMStart -Tokens $rest
            }
            else {
                Invoke-VMStart -Tokens $rest
            }
        }
        { $_ -in @('stop', '-S') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMStop -Tokens $rest
            }
            else {
                Invoke-VMStop -Tokens $rest
            }
        }
        { $_ -in @('close', '-c') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMStop -Tokens $rest
            }
            else {
                Invoke-VMClose -Tokens $rest
            }
        }
        { $_ -in @('diagnose', '-d') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMDiagnose -Tokens $rest
            }
            else {
                Invoke-VMDiagnose -Tokens $rest
            }
        }
        { $_ -in @('status', '-q') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMStatus -Tokens $rest
            }
            else {
                Invoke-VMStatus -Tokens $rest
            }
        }
        { $_ -in @('ssh', '-x') } {
            if ($backend -eq 'qemu') {
                Invoke-QemuVMSSH -Tokens $rest
            }
            else {
                Invoke-VMSSH -Tokens $rest
            }
        }
        { $_ -in @('share-folder', '-F') } {
            if ($backend -eq 'qemu') {
                throw 'Comando vm share-folder nao se aplica ao backend qemu.'
            }
            Invoke-VMShareFolder -Tokens $rest
        }
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
