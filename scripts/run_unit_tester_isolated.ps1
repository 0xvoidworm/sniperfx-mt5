[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$InstalledTerminal = 'C:\Program Files\MetaTrader 5',
    [string]$TerminalData = 'C:\Users\yuri\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075',
    [string]$OutputRoot = 'C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5'
)

$ErrorActionPreference = 'Stop'
$sandbox = Join-Path $OutputRoot 'mt5-unit-sandbox'
$sandboxExperts = Join-Path $sandbox 'MQL5\Experts\SniperFX\Tests'
$sandboxReports = Join-Path $sandbox 'reports'
$sourceEx5 = Join-Path $TerminalData 'MQL5\Experts\SniperFX\Tests\TestSniperFX.ex5'
$sourceConfig = Join-Path $ProjectRoot 'tester\unit-test.ini'
$sandboxConfig = Join-Path $sandbox 'unit-test.ini'
$terminalExe = Join-Path $sandbox 'terminal64.exe'

if (-not (Test-Path -LiteralPath $sourceEx5)) { throw "Compiled unit harness not found: $sourceEx5" }
if (-not (Test-Path -LiteralPath $sourceConfig)) { throw "Unit tester config not found: $sourceConfig" }

New-Item -ItemType Directory -Force -Path $sandbox,$sandboxExperts,$sandboxReports | Out-Null
Copy-Item -LiteralPath (Join-Path $InstalledTerminal 'terminal64.exe') -Destination $terminalExe -Force
Copy-Item -LiteralPath (Join-Path $InstalledTerminal 'metatester64.exe') -Destination (Join-Path $sandbox 'metatester64.exe') -Force
Copy-Item -LiteralPath $sourceEx5 -Destination (Join-Path $sandboxExperts 'TestSniperFX.ex5') -Force
Copy-Item -LiteralPath $sourceConfig -Destination $sandboxConfig -Force

$started = Get-Date
$process = Start-Process -FilePath $terminalExe -ArgumentList @('/portable',"/config:$sandboxConfig") -WindowStyle Hidden -PassThru
$finished = $process.WaitForExit(120000)
if (-not $finished) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw 'Isolated MetaTrader unit test timed out after 120 seconds.'
}

$logs = Get-ChildItem -LiteralPath $sandbox -Filter '*.log' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $started.AddSeconds(-2) } |
    Sort-Object LastWriteTime
$summaryMatches = foreach ($item in $logs) {
    $text = Get-Content -LiteralPath $item.FullName -Raw -ErrorAction SilentlyContinue
    $matchList = [regex]::Matches($text, 'TEST_SUMMARY,passed=(\d+),failed=(\d+)')
    if ($matchList.Count -gt 0) {
        $lastMatch = $matchList[$matchList.Count - 1]
        [pscustomobject]@{
            Log = $item.FullName
            Passed = [int]$lastMatch.Groups[1].Value
            Failed = [int]$lastMatch.Groups[2].Value
        }
    }
}

$latest = $summaryMatches | Select-Object -Last 1
$result = [pscustomobject]@{
    Started = $started.ToString('o')
    TerminalExitCode = $process.ExitCode
    HarnessFound = ($null -ne $latest)
    Passed = if ($latest) { $latest.Passed } else { 0 }
    Failed = if ($latest) { $latest.Failed } else { -1 }
    HarnessLog = if ($latest) { $latest.Log } else { $null }
    Report = Join-Path $sandboxReports 'unit-test.htm'
    NoAccountDatabase = -not (Test-Path -LiteralPath (Join-Path $sandbox 'config\accounts.dat'))
}
$result | ConvertTo-Json | Tee-Object (Join-Path $OutputRoot 'unit-test-result.json')

if (-not $latest -or $latest.Failed -ne 0) { exit 1 }
exit 0
