[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$InstalledTerminal = 'C:\Program Files\MetaTrader 5',
    [string]$TerminalData = 'C:\Users\yuri\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075',
    [string]$BrokerBase = 'FBS-Real',
    [string]$OutputRoot = 'C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5',
    [string]$ConfigFile = 'backtest-eurusd.ini',
    [string]$SetFile = 'SniperFX_BACKTEST_EURUSD.set',
    [string]$SandboxName = 'mt5-backtest-sandbox',
    [string]$ReportFile = 'backtest-eurusd.htm',
    [string]$ResultFile = 'backtest-eurusd-result.json',
    [ValidateRange(60,3600)]
    [int]$TimeoutSeconds = 300
)

$ErrorActionPreference = 'Stop'
$sandbox = Join-Path $OutputRoot $SandboxName
$sandboxExpert = Join-Path $sandbox 'MQL5\Experts\SniperFX'
$sandboxProfiles = Join-Path $sandbox 'MQL5\Profiles\Tester'
$sandboxReports = Join-Path $sandbox 'reports'
$sandboxConfigDirectory = Join-Path $sandbox 'config'
$sandboxSymbols = Join-Path $sandbox ("bases\" + $BrokerBase + '\Symbols')
$sourceExpert = Join-Path $TerminalData 'MQL5\Experts\SniperFX\SniperFX.ex5'
$sourceConfig = Join-Path (Join-Path $ProjectRoot 'tester') $ConfigFile
$sourceSet = Join-Path (Join-Path $ProjectRoot 'tester') $SetFile
$sandboxConfig = Join-Path $sandbox $ConfigFile
$terminalExe = Join-Path $sandbox 'terminal64.exe'
$sandboxAccountDatabase = Join-Path $sandboxConfigDirectory 'accounts.dat'
$report = Join-Path $sandboxReports $ReportFile

if ([System.IO.Path]::GetFileName($ReportFile) -ne $ReportFile) {
    throw 'ReportFile must be a file name without a directory component.'
}

$required = @($sourceExpert,$sourceConfig,$sourceSet,(Join-Path $TerminalData 'config\accounts.dat'),(Join-Path $TerminalData 'config\terminal.ini'),(Join-Path $TerminalData 'config\servers.dat'))
foreach ($item in $required) {
    if (-not (Test-Path -LiteralPath $item)) { throw "Backtest dependency not found: $item" }
}

New-Item -ItemType Directory -Force -Path $sandbox,$sandboxExpert,$sandboxProfiles,$sandboxReports,$sandboxConfigDirectory,$sandboxSymbols | Out-Null
Copy-Item -LiteralPath (Join-Path $InstalledTerminal 'terminal64.exe') -Destination $terminalExe -Force
Copy-Item -LiteralPath (Join-Path $InstalledTerminal 'metatester64.exe') -Destination (Join-Path $sandbox 'metatester64.exe') -Force
Copy-Item -LiteralPath $sourceExpert -Destination (Join-Path $sandboxExpert 'SniperFX.ex5') -Force
Copy-Item -LiteralPath $sourceSet -Destination (Join-Path $sandboxProfiles $SetFile) -Force
Copy-Item -LiteralPath (Join-Path $TerminalData 'config\terminal.ini') -Destination (Join-Path $sandboxConfigDirectory 'terminal.ini') -Force
Copy-Item -LiteralPath (Join-Path $TerminalData 'config\servers.dat') -Destination (Join-Path $sandboxConfigDirectory 'servers.dat') -Force
Copy-Item -Path (Join-Path $TerminalData ("bases\" + $BrokerBase + '\Symbols\*')) -Destination $sandboxSymbols -Force
Remove-Item -LiteralPath $report -Force -ErrorAction SilentlyContinue

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
    $finished = $process.WaitForExit($TimeoutSeconds*1000)
    if (-not $finished) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "Isolated MetaTrader backtest timed out after $TimeoutSeconds seconds."
    }
}
finally {
    Remove-Item -LiteralPath $sandboxAccountDatabase -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $sandboxConfig -Force -ErrorAction SilentlyContinue
}

$freshThreshold = $started.AddSeconds(-2)
$journals = Get-ChildItem -LiteralPath (Join-Path $sandbox 'Tester') -Filter 'SNIPERFX_MTF_*_audit.csv' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $freshThreshold } | Sort-Object LastWriteTime
$journal = $journals | Select-Object -Last 1
$runRows = @()
if ($journal) {
    $allRows = @(Import-Csv -LiteralPath $journal.FullName)
    $startIndex = -1
    for ($index = 0; $index -lt $allRows.Count; $index++) {
        if ($allRows[$index].event -eq 'FSM' -and $allRows[$index].state_before -eq 'BOOT') { $startIndex = $index }
    }
    if ($startIndex -ge 0) { $runRows = @($allRows[$startIndex..($allRows.Count - 1)]) }
}

$testerLogs = Get-ChildItem -LiteralPath (Join-Path $sandbox 'Tester') -Filter '*.log' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $freshThreshold } | Sort-Object LastWriteTime
$testerLog = $testerLogs | Select-Object -Last 1
$metricsText = $null
if ($testerLog) {
    $logText = Get-Content -LiteralPath $testerLog.FullName -Raw
    $metricMatches = [regex]::Matches($logText,'SNIPERFX_TEST_METRICS,trades=([^\r\n]+)')
    if ($metricMatches.Count -gt 0) { $metricsText = $metricMatches[$metricMatches.Count - 1].Groups[1].Value }
}

$reportInfo = if (Test-Path -LiteralPath $report) { Get-Item -LiteralPath $report } else { $null }
$result = [pscustomobject]@{
    Started = $started.ToString('o')
    TerminalExitCode = if ($process) { $process.ExitCode } else { $null }
    JournalFound = ($null -ne $journal)
    Journal = if ($journal) { $journal.FullName } else { $null }
    RowsThisRun = $runRows.Count
    ScanEvents = @($runRows | Where-Object { $_.event -eq 'CANDIDATE_VALID' -or $_.event -eq 'CANDIDATE_REJECT' }).Count
    ValidCandidates = @($runRows | Where-Object event -eq 'CANDIDATE_VALID').Count
    OrderSubmits = @($runRows | Where-Object event -eq 'ORDER_SUBMIT').Count
    TradeTransactions = @($runRows | Where-Object event -eq 'TRADE_TRANSACTION').Count
    TimeExits = @($runRows | Where-Object event -eq 'TIME_EXIT_SUBMIT').Count
    Metrics = $metricsText
    TesterLog = if ($testerLog) { $testerLog.FullName } else { $null }
    ReportExists = Test-Path -LiteralPath $report
    ReportFresh = ($null -ne $reportInfo -and $reportInfo.LastWriteTime -ge $freshThreshold)
    Report = $report
    AccountDatabaseRemoved = -not (Test-Path -LiteralPath $sandboxAccountDatabase)
}
$result | ConvertTo-Json | Tee-Object (Join-Path $OutputRoot $ResultFile)

if (-not $journal -or $result.ScanEvents -lt 1 -or -not $metricsText -or -not $result.ReportFresh -or -not $result.AccountDatabaseRemoved) { exit 1 }
exit 0
