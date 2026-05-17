[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

# Bootstrap UTF-8 BOM para Windows PowerShell 5.x
if ($PSVersionTable.PSVersion.Major -lt 6 -and $PSCommandPath) {
    $selfBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
    $hasBom = ($selfBytes.Length -ge 3 -and $selfBytes[0] -eq 0xEF -and $selfBytes[1] -eq 0xBB -and $selfBytes[2] -eq 0xBF)
    if (-not $hasBom) {
        $bom = [byte[]](0xEF, 0xBB, 0xBF)
        $withBom = New-Object byte[] ($bom.Length + $selfBytes.Length)
        [Array]::Copy($bom, $withBom, $bom.Length)
        [Array]::Copy($selfBytes, 0, $withBom, $bom.Length, $selfBytes.Length)
        [System.IO.File]::WriteAllBytes($PSCommandPath, $withBom)
        Write-Host '[ea11ctl] Arquivo atualizado para UTF-8. Execute o comando novamente.' -ForegroundColor Yellow
        exit 0
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# ea11ctl.ps1 - alias de compatibilidade para a11yctl
# Este script sera removido em versoes futuras.
Write-Host '[ea11ctl] Aviso: ea11ctl e um alias de compatibilidade. Use preferencialmente: a11yctl' -ForegroundColor Yellow

$a11yctlScript = Join-Path $PSScriptRoot 'a11yctl.ps1'
if (-not (Test-Path $a11yctlScript)) {
    Write-Host "[ea11ctl] ERRO: a11yctl.ps1 nao encontrado em $PSScriptRoot" -ForegroundColor Red
    exit 1
}

& $a11yctlScript @Args
exit $LASTEXITCODE
