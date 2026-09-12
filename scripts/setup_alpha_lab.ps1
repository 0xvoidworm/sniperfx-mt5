[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$BasePython = 'C:\Users\yuri\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
)

$ErrorActionPreference = 'Stop'
$venv = Join-Path $ProjectRoot '.venv'
$python = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $python)) {
    & $BasePython -m venv $venv
}
& $python -m pip install --disable-pip-version-check -r (Join-Path $ProjectRoot 'requirements-alpha-lab.txt')
& $python -c "import MetaTrader5; print('MetaTrader5', MetaTrader5.__version__)"
