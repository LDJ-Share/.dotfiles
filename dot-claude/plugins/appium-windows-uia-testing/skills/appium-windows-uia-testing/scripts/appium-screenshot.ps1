<#
.SYNOPSIS
  Drive a Windows app through the Appium REST API to a target UI state and save
  a screenshot — for VISUAL verification of a UI fix (icon renders, control
  moved) that you can't assert from the element tree.

.REQUIRES
  An Appium server already running on 127.0.0.1:4723 with the Windows driver
  (NovaWindows or WinAppDriver). Uses Invoke-RestMethod (no jq needed).

.USAGE
  Edit $Exe, optional $AppArgs (e.g. a preloaded-state flag), the $Steps list
  of AccessibilityIds to click in order, and $Out. Run.
#>

param(
  [string]  $Base    = 'http://127.0.0.1:4723',
  [string]  $Exe     = 'C:\path\to\YourApp.exe',
  [string]  $AppArgs = '',                                   # e.g. '--load-snapshot=C:\...\snap.json'
  [string[]]$Steps   = @('NavSomewhere','OpenThing','ExpandCombo'),  # AccessibilityIds clicked in order
  [string]  $Out     = (Join-Path $env:TEMP 'appium-verify.png')
)

$ErrorActionPreference = 'Stop'
$EK = 'element-6066-11e4-a52e-4f735466cecf'   # W3C element-id key

$fm = @{
  platformName            = 'Windows'
  'appium:automationName' = 'NovaWindows'      # or 'Windows' for WinAppDriver
  'appium:deviceName'     = 'WindowsPC'
  'appium:app'            = $Exe
}
if ($AppArgs) { $fm['appium:appArguments'] = $AppArgs }
$caps = @{ capabilities = @{ firstMatch = @($fm) } } | ConvertTo-Json -Depth 6

$sid = (Invoke-RestMethod -Method Post -Uri "$Base/session" -ContentType 'application/json' -Body $caps).value.sessionId
Write-Host "session: $sid"

function Find-El($aid) {
  for ($i = 0; $i -lt 20; $i++) {
    try {
      $b = @{ using = 'accessibility id'; value = $aid } | ConvertTo-Json
      $r = Invoke-RestMethod -Method Post -Uri "$Base/session/$sid/element" -ContentType 'application/json' -Body $b
      if ($r.value.$EK) { return $r.value.$EK }
    } catch {}
    Start-Sleep -Seconds 1
  }
  throw "element not found: $aid"
}
function Click-El($eid) {
  Invoke-RestMethod -Method Post -Uri "$Base/session/$sid/element/$eid/click" -ContentType 'application/json' -Body '{}' | Out-Null
}

try {
  foreach ($s in $Steps) { Write-Host "click $s"; Click-El (Find-El $s); Start-Sleep -Seconds 2 }
  $shot = Invoke-RestMethod -Method Get -Uri "$Base/session/$sid/screenshot"
  [IO.File]::WriteAllBytes($Out, [Convert]::FromBase64String($shot.value))
  Write-Host ("saved: {0} ({1} bytes)" -f $Out, (Get-Item $Out).Length)
}
finally {
  Invoke-RestMethod -Method Delete -Uri "$Base/session/$sid" | Out-Null
}
