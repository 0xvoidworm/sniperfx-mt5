[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Symbol = 'XAUUSD',
    [double]$Interval = 2.0,
    [string]$OutputRoot = 'C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5'
)

$ErrorActionPreference = 'Stop'
$python = Join-Path $ProjectRoot '.venv\Scripts\python.exe'
$stateDirectory = Join-Path $ProjectRoot 'data\phase1'
$pidFile = Join-Path $stateDirectory 'alpha_lab.pid'
$stdout = Join-Path $OutputRoot 'alpha-lab.stdout.log'
$stderr = Join-Path $OutputRoot 'alpha-lab.stderr.log'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Alpha Lab environment is missing. Run scripts\setup_alpha_lab.ps1 first.'
}
if (Test-Path -LiteralPath $pidFile) {
    $existingPid = [int](Get-Content -LiteralPath $pidFile -Raw)
    if (Get-Process -Id $existingPid -ErrorAction SilentlyContinue) {
        throw "Alpha Lab is already running with PID $existingPid."
    }
}
New-Item -ItemType Directory -Force -Path $stateDirectory,$OutputRoot | Out-Null
Remove-Item -LiteralPath $stdout,$stderr -Force -ErrorAction SilentlyContinue
$arguments = @('-m', 'alpha_lab.runner', '--symbol', $Symbol, '--interval', $Interval)
$process = Start-Process -FilePath $python -ArgumentList $arguments -WorkingDirectory $ProjectRoot `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
Set-Content -LiteralPath $pidFile -Value $process.Id -Encoding ascii
[pscustomobject]@{
    Status = 'STARTED'
    ProcessId = $process.Id
    Symbol = $Symbol
    Stdout = $stdout
    Stderr = $stderr
} | ConvertTo-Json
