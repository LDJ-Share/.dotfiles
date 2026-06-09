#!/usr/bin/env pwsh
# Local convenience runner for the Flight Finder demo UI smokes.
#
# Mirrors what CI does in a single step, because Windows tears down a
# backgrounded Appium when the launching shell exits: build the solution, ensure
# the driver is installed, start Appium, wait for the port, run the UiSmoke
# filter, then stop Appium — all in one process.
#
# Usage (from the sample root):
#   pwsh -NoProfile -File scripts/run-ui-smokes.ps1
#
# NOTE: UI smokes are happiest on a clean, idle machine. On a loaded dev box a
# UIA scan can run slow; that is environmental, not a test regression.

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$testDir = Join-Path $root 'tests/FlightFinder.UiTests'
$solution = Join-Path $root 'FlightFinder.sln'

Write-Host '==> Building solution (Debug)...'
dotnet build $solution --configuration Debug

Write-Host '==> Fast gate (non-UI tests, no Appium)...'
dotnet test $solution --configuration Debug --no-build `
  --filter 'Category!=UiSmoke&Category!=DocsCapture'

Write-Host '==> Ensuring Appium + NovaWindows driver are installed...'
Push-Location $testDir
try {
    if (-not (Test-Path (Join-Path $testDir 'node_modules/appium/index.js'))) {
        npm install   # auto-discovers the local driver; do NOT 'appium driver install'
    }

    $appiumJs = Join-Path $testDir 'node_modules/appium/index.js'
    $log = Join-Path $testDir 'appium.log'

    Write-Host '==> Starting Appium...'
    $proc = Start-Process node -ArgumentList $appiumJs, '--log-level', 'info' `
        -WorkingDirectory $testDir -NoNewWindow `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err" -PassThru

    $deadline = (Get-Date).AddSeconds(60)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        try { (New-Object Net.Sockets.TcpClient).Connect('127.0.0.1', 4723); $ready = $true; break }
        catch { Start-Sleep 2 }
    }
    if (-not $ready) {
        Get-Content $log, "$log.err" -ErrorAction SilentlyContinue | Write-Host
        throw 'Appium did not start within 60s.'
    }

    Write-Host '==> Running UI smokes...'
    Pop-Location
    dotnet test $solution --configuration Debug --no-build `
        --filter 'Category=UiSmoke' `
        --logger 'console;verbosity=detailed'
    $code = $LASTEXITCODE
}
finally {
    if ($proc) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    if ((Get-Location).Path -eq $testDir) { Pop-Location }
}

exit $code
