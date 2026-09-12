[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$InstalledTerminal = 'C:\Program Files\MetaTrader 5',
    [string]$TerminalData = 'C:\Users\yuri\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075',
    [string]$BrokerBase = 'FBS-Real',
    [string]$OutputRoot = 'C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5'
)

$ErrorActionPreference = 'Stop'
$sandbox = Join-Path $OutputRoot 'mt5-scan-sandbox'
$sandboxExpert = Join-Path $sandbox 'MQL5\Experts\SniperFX'
$sandboxProfiles = Join-Path $sandbox 'MQL5\Profiles\Tester'
$sandboxReports = Join-Path $sandbox 'reports'
$sandboxConfigDirectory = Join-Path $sandbox 'config'
$sourceBrokerBase = Join-Path $TerminalData ("bases\" + $BrokerBase)
$sandboxBrokerBase = Join-Path $sandbox ("bases\" + $BrokerBase)
$sandboxSymbols = Join-Path $sandboxBrokerBase 'Symbols'
$sandboxHistory = Join-Path $sandboxBrokerBase 'History\EURUSD'
$sourceExpert = Join-Path $TerminalData 'MQL5\Experts\SniperFX\SniperFX.ex5'
$sourceConfig = Join-Path $ProjectRoot 'tester\integration-scan.ini'
$sourceSet = Join-Path $ProjectRoot 'tester\SniperFX_INTEGRATION_SCAN.set'
$sandboxConfig = Join-Path $sandbox 'integration-scan.ini'
$terminalExe = Join-Path $sandbox 'terminal64.exe'
$sandboxAccountDatabase = Join-Path $sandboxConfigDirectory 'accounts.dat'

$required = @(
    $sourceExpert,
    $sourceConfig,
    $sourceSet,
    (Join-Path $TerminalData 'config\accounts.dat'),
    (Join-Path $TerminalData 'config\terminal.ini'),
    (Join-Path $TerminalData 'config\servers.dat')
)
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath $item)) { throw "Integration test dependency not found: $item" }
}

New-Item -ItemType Directory -Force -Path $sandbox,$sandboxExpert,$sandboxProfiles,$sandboxReports,$sandboxConfigDirectory,$sandboxSymbols,$sandboxHistory | Out-Null
Copy-Item -LiteralPath (Join-Path $InstalledTerminal 'terminal64.exe') -Destination $terminalExe -Force
Copy-Item -LiteralPath (Join-Path $InstalledTerminal 'metatester64.exe') -Destination (Join-Path $sandbox 'metatester64.exe') -Force
Copy-Item -LiteralPath $sourceExpert -Destination (Join-Path $sandboxExpert 'SniperFX.ex5') -Force
Copy-Item -LiteralPath $sourceSet -Destination (Join-Path $sandboxProfiles 'SniperFX_INTEGRATION_SCAN.set') -Force
Copy-Item -LiteralPath (Join-Path $TerminalData 'config\terminal.ini') -Destination (Join-Path $sandboxConfigDirectory 'terminal.ini') -Force
Copy-Item -LiteralPath (Join-Path $TerminalData 'config\servers.dat') -Destination (Join-Path $sandboxConfigDirectory 'servers.dat') -Force
Copy-Item -Path (Join-Path $sourceBrokerBase 'Symbols\*') -Destination $sandboxSymbols -Force

$started = Get-Date
$process = $null
try {
    $liveTerminal = Get-Process -Name 'terminal64' -ErrorAction Stop |
        Where-Object { $_.Path -eq (Join-Path $InstalledTerminal 'terminal64.exe') } |
        Select-Object -First 1
    if (-not $liveTerminal -or $liveTerminal.MainWindowTitle -notmatch '^\s*(\d+)\s+-') {
        throw 'Could not derive the explicitly authorized tester account from the running MT5 title.'
    }
    $testerLogin = $Matches[1]
    $configText = (Get-Content -LiteralPath $sourceConfig -Raw).Replace('__TESTER_LOGIN__',$testerLogin)
    [System.IO.File]::WriteAllText($sandboxConfig,$configText,[System.Text.UTF8Encoding]::new($false))
    Copy-Item -LiteralPath (Join-Path $TerminalData 'config\accounts.dat') -Destination $sandboxAccountDatabase -Force
    $process = Start-Process -FilePath $terminalExe -ArgumentList @('/portable',"/config:$sandboxConfig") -WindowStyle Hidden -PassThru
    $finished = $process.WaitForExit(180000)
    if (-not $finished) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'Isolated MetaTrader integration scan timed out after 180 seconds.'
    }
}
finally {
    # This is an isolated temporary copy. Never retain the live terminal account database.
    Remove-Item -LiteralPath $sandboxAccountDatabase -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sandboxConfig -Force -ErrorAction SilentlyContinue
}

$journals = Get-ChildItem -LiteralPath (Join-Path $sandbox 'Tester') -Filter 'SNIPERFX_MTF_*_audit.csv' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $started.AddSeconds(-2) } |
    Sort-Object LastWriteTime
$journal = $journals | Select-Object -Last 1
$runRows = @()
if ($journal) {
    $allRows = @(Import-Csv -LiteralPath $journal.FullName)
    $startIndex = -1
    for ($index = 0; $index -lt $allRows.Count; $index++) {
        if ($allRows[$index].event -eq 'FSM' -and $allRows[$index].state_before -eq 'BOOT') {
            $startIndex = $index
        }
    }
    if ($startIndex -ge 0) {
        $runRows = @($allRows[$startIndex..($allRows.Count - 1)])
    }
}
$health = @($runRows | Where-Object event -eq 'HEALTH').Count
$scanEvents = @($runRows | Where-Object { $_.event -eq 'CANDIDATE_VALID' -or $_.event -eq 'CANDIDATE_REJECT' }).Count
$wouldSubmit = @($runRows | Where-Object event -eq 'WOULD_SUBMIT').Count
$submitEvents = @($runRows | Where-Object event -eq 'ORDER_SUBMIT').Count
$transactions = @($runRows | Where-Object event -eq 'TRADE_TRANSACTION').Count
$report = Join-Path $sandboxReports 'integration-scan.htm'

$result = [pscustomobject]@{
    Started = $started.ToString('o')
    TerminalExitCode = if ($process) { $process.ExitCode } else { $null }
    JournalFound = ($null -ne $journal)
    Journal = if ($journal) { $journal.FullName } else { $null }
    RowsThisRun = $runRows.Count
    HealthEvents = $health
    ScanEvents = $scanEvents
    WouldSubmitEvents = $wouldSubmit
    OrderSubmitEvents = $submitEvents
    TradeTransactions = $transactions
    ReportExists = Test-Path -LiteralPath $report
    Report = $report
    AccountDatabaseRemoved = -not (Test-Path -LiteralPath $sandboxAccountDatabase)
}
$result | ConvertTo-Json | Tee-Object (Join-Path $OutputRoot 'integration-scan-result.json')

if (-not $journal -or $health -lt 1 -or $scanEvents -lt 1 -or $submitEvents -ne 0 -or $transactions -ne 0 -or -not $result.ReportExists -or -not $result.AccountDatabaseRemoved) { exit 1 }
exit 0
