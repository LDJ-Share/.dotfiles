# PSReadLine Configuration
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -ShowTooltips

# Key Handlers
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# F7 — Show command history in a selectable list
Set-PSReadLineKeyHandler -Key F7 `
    -BriefDescription History `
    -LongDescription 'Show command history' `
    -ScriptBlock {
    $pattern = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
    if ($pattern) { $pattern = [regex]::Escape($pattern) }

    $history = [System.Collections.ArrayList]@(
        $last = ''
        $lines = ''
        foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath)) {
            if ($line.EndsWith('`')) {
                $line = $line.Substring(0, $line.Length - 1)
                $lines = if ($lines) { "$lines`n$line" } else { $line }
                continue
            }
            if ($lines) { $line = "$lines`n$line"; $lines = '' }
            if (($line -cne $last) -and (!$pattern -or ($line -match $pattern))) {
                $last = $line; $line
            }
        }
    )
    $history.Reverse()

    $command = $history | Out-GridView -Title History -PassThru
    if ($command) {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
    }
}

# Ctrl+b — Build the current directory
Set-PSReadLineKeyHandler -Key Ctrl+b `
    -BriefDescription BuildCurrentDirectory `
    -LongDescription "Build the current directory" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("dotnet build")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

# F1 — Navigate to repos directory
Set-PSReadLineKeyHandler -Key F1 `
    -BriefDescription NavigateToRepos `
    -LongDescription "Navigate to the repos directory" `
    -ScriptBlock {
    $reposPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) "source/repos"
    if (-not (Test-Path $reposPath)) { $reposPath = "~/source/repos" }
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("cd $reposPath")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

# F5 — Reload the profile
Set-PSReadLineKeyHandler -Key F5 `
    -BriefDescription ReloadProfile `
    -LongDescription "Reload the PowerShell profile" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    Write-Host "Reloading Profile..." -ForegroundColor Cyan
    . $PROFILE
}

# F10 — Print profile component contents to console
Set-PSReadLineKeyHandler -Key F10 `
    -BriefDescription PrintProfile `
    -LongDescription "Print PowerShell profile components to the console" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    $profileFiles = @(
        "Microsoft.PowerShell_profile.ps1",
        "Microsoft.PowerShell_profile-PSReadLine.ps1",
        "Modules/MyProfileUtils/MyProfileUtils.psm1"
    )
    foreach ($file in $profileFiles) {
        $filePath = Join-Path $PSScriptRoot $file
        if (Test-Path $filePath) {
            Write-Host "--- $file ---" -ForegroundColor Cyan
            Get-Content -Path $filePath | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }
    }
}

# F12 — Open profile components in nvim
Set-PSReadLineKeyHandler -Key F12 `
    -BriefDescription OpenProfile `
    -LongDescription "Open PowerShell profile components in nvim" `
    -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    $filesToOpen = @(
        $PROFILE,
        (Join-Path $PSScriptRoot "Microsoft.PowerShell_profile-PSReadLine.ps1"),
        (Join-Path $PSScriptRoot "Modules/MyProfileUtils/MyProfileUtils.psm1")
    )
    $existing = $filesToOpen | Where-Object { Test-Path $_ }
    if ($existing) { nvim $existing }
}

# Alt+p — Toggle path display between powerlevel (truncated) and full
Set-PSReadLineKeyHandler -Chord "Alt+p" `
    -BriefDescription TogglePathStyle `
    -LongDescription "Toggle oh-my-posh path between powerlevel (truncated) and full" `
    -ScriptBlock {
    $env:POSH_PATH_FULL = if ($env:POSH_PATH_FULL -eq "1") { "0" } else { "1" }
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}
