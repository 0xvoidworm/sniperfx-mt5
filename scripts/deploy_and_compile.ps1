[CmdletBinding()]
param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$TerminalData = 'C:\Users\yuri\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075',
    [string]$MetaEditor = 'C:\Program Files\MetaTrader 5\metaeditor64.exe',
    [string]$OutputRoot = 'C:\Users\yuri\Desktop\Workspace\outputs\sniperfx-mt5'
)
$ErrorActionPreference = 'Stop'
$source = Join-Path $ProjectRoot 'src\SniperFX'
$deploy = Join-Path $TerminalData 'MQL5\Experts\SniperFX'
$log = Join-Path $OutputRoot 'compile.log'
$buildStarted = Get-Date
New-Item -ItemType Directory -Force -Path $OutputRoot,$deploy | Out-Null
Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $OutputRoot 'test-compile.log') -Force -ErrorAction SilentlyContinue
Get-ChildItem -LiteralPath $source -File -Recurse | ForEach-Object {
    $relative = $_.FullName.Substring($source.Length).TrimStart('\')
    $target = Join-Path $deploy $relative
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $target -Force
}
$main = Join-Path $deploy 'SniperFX.mq5'
$mainProcess = Start-Process -FilePath $MetaEditor -ArgumentList @("/compile:$main","/log:$log") -WindowStyle Hidden -Wait -PassThru
$exit = $mainProcess.ExitCode
$ex5 = Join-Path $deploy 'SniperFX.ex5'
$testSource = Join-Path $deploy 'Tests\TestSniperFX.mq5'
$testLog = Join-Path $OutputRoot 'test-compile.log'
$testProcess = Start-Process -FilePath $MetaEditor -ArgumentList @("/compile:$testSource","/log:$testLog") -WindowStyle Hidden -Wait -PassThru
$testExit = $testProcess.ExitCode
$logText = if (Test-Path $log) { Get-Content -LiteralPath $log -Raw } else { '' }
$testLogText = if (Test-Path $testLog) { Get-Content -LiteralPath $testLog -Raw } else { '' }
$mainClean = $logText -match 'Result:\s+0\s+errors,\s+0\s+warnings'
$testClean = $testLogText -match 'Result:\s+0\s+errors,\s+0\s+warnings'
$hasErrors = -not $mainClean
$testHasErrors = -not $testClean
$testEx5 = Join-Path $deploy 'Tests\TestSniperFX.ex5'
$mainInfo = if (Test-Path $ex5) { Get-Item -LiteralPath $ex5 } else { $null }
$testInfo = if (Test-Path $testEx5) { Get-Item -LiteralPath $testEx5 } else { $null }
$result = [pscustomobject]@{
    BuildStarted=$buildStarted.ToString('o')
    ExitCode=$exit
    TestExitCode=$testExit
    MainSource=$main
    Ex5=$ex5
    Ex5Exists=($null -ne $mainInfo)
    Ex5Fresh=($null -ne $mainInfo -and $mainInfo.LastWriteTime -ge $buildStarted.AddSeconds(-2))
    Ex5Sha256=if ($mainInfo) { (Get-FileHash -LiteralPath $ex5 -Algorithm SHA256).Hash } else { $null }
    TestEx5Exists=($null -ne $testInfo)
    TestEx5Fresh=($null -ne $testInfo -and $testInfo.LastWriteTime -ge $buildStarted.AddSeconds(-2))
    TestEx5Sha256=if ($testInfo) { (Get-FileHash -LiteralPath $testEx5 -Algorithm SHA256).Hash } else { $null }
    HasErrors=$hasErrors
    TestHasErrors=$testHasErrors
    Log=$log
    TestLog=$testLog
}
$result | ConvertTo-Json | Tee-Object (Join-Path $OutputRoot 'build-result.json')
if ($hasErrors -or $testHasErrors -or -not $result.Ex5Fresh -or -not $result.TestEx5Fresh) { exit 1 }
exit 0
