[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Symbol = 'XAUUSD',
    [double]$Interval = 2.0,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
$python = Join-Path $ProjectRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    throw 'Alpha Lab environment is missing. Run scripts\setup_alpha_lab.ps1 first.'
}
$arguments = @('-m', 'alpha_lab.runner', '--symbol', $Symbol, '--interval', $Interval)
if ($Once) { $arguments += '--once' }
& $python @arguments
