<#
.SYNOPSIS
  Run NUnit/xUnit Appium UI fixtures one-at-a-time, each as its own `dotnet
  test` process with a hard WALL-CLOCK kill. The only reliable way to cap a
  hung Appium command (NUnit [Timeout] can't interrupt a blocked HTTP call).

.WHY
  - Per-fixture isolation: one app launch per fixture, clean process state.
  - Wall-clock kill: if a fixture overruns its budget, kill the dotnet tree +
    the app + the test host and record TIMEOUT — the run never hangs.
  - Precise filter: namespace-qualified + trailing dot avoids the substring
    trap where `~SmokeTests` also matches `PlanRunSmokeTests`.

.USAGE
  Edit $Proj, $Ns, $AppProcName, and the $Fixtures map (fixture class -> test
  count, for budget scaling), then run. Results land in <out>\results.tsv.
#>

param(
  [string]$Proj        = 'C:\path\to\Your.UiTests.csproj',
  [string]$Ns          = 'Your.UiTests.',           # namespace prefix (trailing dot)
  [string]$AppProcName = 'YourApp',                  # app exe process name (no .exe)
  [int]   $PerTestSec  = 20,                          # wall budget per [Test]
  [int]   $OverheadSec = 20,                          # + host/launch overhead per fixture
  [string]$OutDir      = (Join-Path (Split-Path $Proj) 'TestResults\isolated')
)

# fixture class name => number of [Test] methods (scales the kill budget)
$Fixtures = [ordered]@{
  'FixtureA' = 1
  'FixtureB' = 2
  # 'SmokeTests' = 3
}

$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$results = Join-Path $OutDir 'results.tsv'
"fixture`tstatus`twall_s`tduration`tdetail" | Set-Content $results

function Kill-Run {
  foreach ($n in @($AppProcName, 'testhost', 'vstest.console')) {
    Get-Process $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  }
  Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match [regex]::Escape((Split-Path $Proj -Leaf)) } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

foreach ($fx in $Fixtures.Keys) {
  $n = [int]$Fixtures[$fx]
  $budget = ($PerTestSec * $n) + $OverheadSec
  $filter = "FullyQualifiedName~$Ns$fx."     # trailing dot = exact class
  Kill-Run; Start-Sleep -Milliseconds 500
  $log = Join-Path $OutDir "$fx.log"
  $sw  = [System.Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process dotnet `
        -ArgumentList @('test', $Proj, '--no-build', '--nologo', '--filter', $filter) `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru -WindowStyle Hidden
  $exited = $p.WaitForExit($budget * 1000)
  $sw.Stop()
  $wall = [math]::Round($sw.Elapsed.TotalSeconds, 1)
  if (-not $exited) {
    Kill-Run; try { $p.WaitForExit(5000) | Out-Null } catch {}
    "$fx`tTIMEOUT`t$wall`t-`tKILLED at ${budget}s budget (n=$n)" | Add-Content $results
    Write-Host "$fx  TIMEOUT ${wall}s" -ForegroundColor Red
    continue
  }
  $body = Get-Content $log -Raw -ErrorAction SilentlyContinue
  $status = 'UNKNOWN'; $dur = '-'; $detail = ''
  if     ($body -match 'Passed!\s+-\s+Failed:\s+0') { $status = 'PASS' }
  elseif ($body -match 'Failed!\s')                 { $status = 'FAIL' }
  if ($body -match 'Duration:\s+([0-9hms <]+?)\s+-\s+\S+\.dll') { $dur = $Matches[1].Trim() }
  if ($status -eq 'FAIL') {
    $lines = $body -split "`n"
    $i = [Array]::FindIndex($lines, [Predicate[string]]{ param($l) $l -match 'Error Message:' })
    if ($i -ge 0 -and $i + 1 -lt $lines.Count) { $detail = $lines[$i + 1].Trim() }
  }
  "$fx`t$status`t$wall`t$dur`t$detail" | Add-Content $results
  Write-Host ("{0}  {1} {2}s  {3}" -f $fx, $status, $wall, $detail) `
    -ForegroundColor ($(if ($status -eq 'PASS') {'Green'} else {'Yellow'}))
}
Kill-Run
"=== DONE ===" | Add-Content $results
Write-Host "results: $results"
