[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$pidFile = Join-Path $ProjectRoot 'data\phase1\alpha_lab.pid'
if (-not (Test-Path -LiteralPath $pidFile)) {
    [pscustomobject]@{ Status = 'NOT_RUNNING' } | ConvertTo-Json
    exit 0
}
$processId = [int](Get-Content -LiteralPath $pidFile -Raw)
$process = Get-Process -Id $processId -ErrorAction SilentlyContinue
if ($process) {
    Stop-Process -Id $processId
    $process.WaitForExit(10000) | Out-Null
}
Remove-Item -LiteralPath $pidFile -Force
[pscustomobject]@{ Status = 'STOPPED'; ProcessId = $processId } | ConvertTo-Json
