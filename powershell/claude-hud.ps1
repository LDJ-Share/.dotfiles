#Requires -Version 7.0
<#
.SYNOPSIS
  Single-file PowerShell port of the claude-hud statusline plugin.

.DESCRIPTION
  Drop-in replacement for the claude-hud Node plugin, for locked-down
  machines where installing plugins is not possible. Reads Claude Code's
  statusline JSON from stdin and prints a multi-line HUD.

.NOTES
  Wire it up in ~/.claude/settings.json:

    "statusLine": {
      "type": "command",
      "command": "pwsh -NoProfile -File C:/Users/<you>/.../powershell/claude-hud.ps1"
    }

  Requires a UTF-8 capable terminal (Windows Terminal, WezTerm, VS Code).
  Glyphs used: ⏱ ◐ ✓ ▸ █ ░ │ ─. A Nerd Font is NOT required.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

# stdin and stdout default to the console code page on Windows; force UTF-8
# so the box-drawing and emoji glyphs survive the pipe to Claude Code.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding           = [System.Text.UTF8Encoding]::new($false)
} catch {}

# ============================================================================
# Configuration — edit here. Mirrors the upstream claude-hud defaults.
# ============================================================================
$Config = [ordered]@{
    PathLevels           = 1        # trailing cwd segments shown (1=basename)
    ShowSeparators       = $false   # divider line before activity lines
    ShowAheadBehind      = $false
    ShowFileStats        = $false
    ShowDirty            = $true
    ShowDuration         = $true
    ShowConfigCounts     = $true
    ShowTools            = $true
    ShowAgents           = $true
    ShowTodos            = $true
    ShowUsage            = $true
    ShowContextBar       = $true
    ShowTokenBreakdown   = $true
    UsageBarEnabled      = $true
    UsageThreshold       = 0
    SevenDayThreshold    = 80
    EnvironmentThreshold = 0
    AutocompactBuffer    = 'enabled'  # 'enabled' or 'disabled'
    AutocompactPercent   = 0.165
}

# ============================================================================
# ANSI helpers
# ============================================================================
# ANSI globals are uppercase-prefixed so they don't collide with locals like
# $reset/$dim. PowerShell variables are case-insensitive — $RESET and $reset
# refer to the same cell, which silently corrupts string interpolation.
$ANSI_ESC     = [char]27
$ANSI_RESET   = "$ANSI_ESC[0m"
$ANSI_DIM     = "$ANSI_ESC[2m"
$ANSI_RED     = "$ANSI_ESC[31m"
$ANSI_GREEN   = "$ANSI_ESC[32m"
$ANSI_YELLOW  = "$ANSI_ESC[33m"
$ANSI_MAGENTA = "$ANSI_ESC[35m"
$ANSI_CYAN    = "$ANSI_ESC[36m"
$ANSI_BBLUE   = "$ANSI_ESC[94m"
$ANSI_BMAG    = "$ANSI_ESC[95m"

function Color([string]$Text, [string]$Code) { "$Code$Text$ANSI_RESET" }
function Dim   ([string]$t) { Color $t $ANSI_DIM }
function Green ([string]$t) { Color $t $ANSI_GREEN }
function Yellow([string]$t) { Color $t $ANSI_YELLOW }
function Red   ([string]$t) { Color $t $ANSI_RED }
function Cyan  ([string]$t) { Color $t $ANSI_CYAN }
function Magenta([string]$t) { Color $t $ANSI_MAGENTA }

function Get-ContextColor([int]$Percent) {
    if ($Percent -ge 85) { return $ANSI_RED }
    if ($Percent -ge 70) { return $ANSI_YELLOW }
    return $ANSI_GREEN
}
function Get-QuotaColor([int]$Percent) {
    if ($Percent -ge 90) { return $ANSI_RED }
    if ($Percent -ge 75) { return $ANSI_BMAG }
    return $ANSI_BBLUE
}

function Make-Bar([int]$Percent, [int]$Width, [string]$Color) {
    $p = [Math]::Min(100, [Math]::Max(0, $Percent))
    $w = [Math]::Max(0, $Width)
    $filled = [int][Math]::Round(($p / 100.0) * $w)
    $empty  = $w - $filled
    "$Color$('█' * $filled)$ANSI_DIM$('░' * $empty)$ANSI_RESET"
}
function Colored-Bar([int]$Percent, [int]$Width = 10) {
    Make-Bar $Percent $Width (Get-ContextColor $Percent)
}
function Quota-Bar([int]$Percent, [int]$Width = 10) {
    Make-Bar $Percent $Width (Get-QuotaColor $Percent)
}

function Get-TerminalWidth {
    try { $w = [System.Console]::WindowWidth; if ($w -gt 0) { return $w } } catch {}
    try { $w = $Host.UI.RawUI.WindowSize.Width; if ($w -gt 0) { return $w } } catch {}
    if ($env:COLUMNS) { return [int]$env:COLUMNS }
    return 120
}
function Get-AdaptiveBarWidth {
    $cols = Get-TerminalWidth
    if ($cols -ge 100) { return 10 }
    if ($cols -ge 60)  { return 6 }
    return 4
}

# ============================================================================
# Stdin
# ============================================================================
function Read-Stdin {
    if ([Console]::IsInputRedirected -eq $false) { return $null }
    try {
        $raw = [Console]::In.ReadToEnd()
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        return $raw | ConvertFrom-Json
    } catch { return $null }
}

# ============================================================================
# Context / usage extraction
# ============================================================================
function Get-TotalTokens($stdin) {
    $u = $stdin.context_window.current_usage
    if (-not $u) { return 0 }
    return ([int]($u.input_tokens                ?? 0) +
            [int]($u.cache_creation_input_tokens ?? 0) +
            [int]($u.cache_read_input_tokens     ?? 0))
}
function Get-NativePercent($stdin) {
    $p = $stdin.context_window.used_percentage
    if ($null -ne $p -and $p -is [ValueType]) {
        return [int][Math]::Round([Math]::Min(100, [Math]::Max(0, [double]$p)))
    }
    return $null
}
function Get-RawContextPercent($stdin) {
    $native = Get-NativePercent $stdin
    if ($null -ne $native) { return $native }
    $size = [int]($stdin.context_window.context_window_size ?? 0)
    if ($size -le 0) { return 0 }
    return [int][Math]::Min(100, [Math]::Round(((Get-TotalTokens $stdin) / [double]$size) * 100))
}
function Get-BufferedContextPercent($stdin) {
    $native = Get-NativePercent $stdin
    if ($null -ne $native) { return $native }
    $size = [int]($stdin.context_window.context_window_size ?? 0)
    if ($size -le 0) { return 0 }
    $total = Get-TotalTokens $stdin
    $rawRatio = $total / [double]$size
    $LOW = 0.05; $HIGH = 0.50
    $scale = [Math]::Min(1, [Math]::Max(0, ($rawRatio - $LOW) / ($HIGH - $LOW)))
    $buffer = $size * $Config.AutocompactPercent * $scale
    return [int][Math]::Min(100, [Math]::Round((($total + $buffer) / [double]$size) * 100))
}
function Get-ModelName($stdin) {
    $name = $stdin.model.display_name
    if ($name) { return $name.Trim() }
    $id = $stdin.model.id
    if ($id) { return $id.Trim() }
    return 'Unknown'
}
function Get-UsageData($stdin) {
    $rl = $stdin.rate_limits
    if (-not $rl) { return $null }
    function _pct($v) {
        if ($null -ne $v -and $v -is [ValueType]) {
            return [int][Math]::Round([Math]::Min(100, [Math]::Max(0, [double]$v)))
        }
        return $null
    }
    function _resetAt($v) {
        if ($null -ne $v -and $v -is [ValueType] -and [double]$v -gt 0) {
            return [DateTimeOffset]::FromUnixTimeSeconds([long]$v).LocalDateTime
        }
        return $null
    }
    $five  = _pct $rl.five_hour.used_percentage
    $seven = _pct $rl.seven_day.used_percentage
    if ($null -eq $five -and $null -eq $seven) { return $null }
    return [pscustomobject]@{
        FiveHour          = $five
        SevenDay          = $seven
        FiveHourResetAt   = _resetAt $rl.five_hour.resets_at
        SevenDayResetAt   = _resetAt $rl.seven_day.resets_at
    }
}

# ============================================================================
# Transcript parsing (with mtime+size cache)
# ============================================================================
function Get-CachePath([string]$Path) {
    $resolved = [System.IO.Path]::GetFullPath($Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($resolved))
    $hash = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()
    $userHome = [Environment]::GetFolderPath('UserProfile')
    # Use a sibling directory so we don't fight the upstream node plugin's
    # cache (different field shape would cause both sides to miss).
    $dir = Join-Path $userHome '.claude/plugins/claude-hud-ps/transcript-cache'
    return (Join-Path $dir "$hash.json")
}

function Read-TranscriptCache([string]$Path, $State) {
    $cachePath = Get-CachePath $Path
    if (-not (Test-Path $cachePath)) { return $null }
    try {
        $raw = [System.IO.File]::ReadAllText($cachePath)
        $cached = $raw | ConvertFrom-Json
        if ($cached.transcriptPath -ne $State.Resolved) { return $null }
        if ($cached.mtimeTicks -ne $State.MTime) { return $null }
        if ($cached.size -ne $State.Size) { return $null }
        return $cached.data
    } catch { return $null }
}

function Write-TranscriptCache([string]$Path, $State, $Data) {
    try {
        $cachePath = Get-CachePath $Path
        $dir = Split-Path -Parent $cachePath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $payload = @{
            transcriptPath = $State.Resolved
            mtimeTicks     = $State.MTime
            size           = $State.Size
            data           = $Data
        }
        $json = $payload | ConvertTo-Json -Depth 8 -Compress
        [System.IO.File]::WriteAllText($cachePath, $json)
    } catch {
        if ($env:CLAUDE_HUD_DEBUG) { [Console]::Error.WriteLine("[claude-hud] cache write failed: $_") }
    }
}

function Parse-Transcript([string]$Path) {
    $empty = [pscustomobject]@{
        Tools = @(); Agents = @(); Todos = @()
        SessionStart = $null; SessionName = $null
    }
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $empty }

    $item = Get-Item -LiteralPath $Path
    if (-not $item -or $item.PSIsContainer) { return $empty }
    $state = [pscustomobject]@{
        Resolved = $item.FullName
        MTime    = $item.LastWriteTimeUtc.Ticks
        Size     = $item.Length
    }

    $cached = Read-TranscriptCache $Path $state
    if ($cached) { return ConvertTo-Transcript $cached }

    $toolMap   = [ordered]@{}
    $agentMap  = [ordered]@{}
    $todos     = [System.Collections.Generic.List[object]]::new()
    $taskIndex = @{}
    $sessionStart = $null
    $sessionName  = $null
    $customTitle  = $null
    $latestSlug   = $null
    $cleanParse = $true

    try {
        foreach ($line in [System.IO.File]::ReadLines($Path)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $entry = $line | ConvertFrom-Json
            } catch { continue }

            if ($entry.type -eq 'custom-title' -and $entry.customTitle) {
                $customTitle = [string]$entry.customTitle
            } elseif ($entry.slug) {
                $latestSlug = [string]$entry.slug
            }

            $ts = _ParseDate $entry.timestamp
            if (-not $sessionStart -and $ts) { $sessionStart = $ts }

            $content = $entry.message.content
            if (-not $content) { continue }
            if ($content -isnot [System.Collections.IEnumerable] -or $content -is [string]) { continue }

            foreach ($block in $content) {
                if (-not $block) { continue }

                if ($block.type -eq 'tool_use' -and $block.id -and $block.name) {
                    $toolName = [string]$block.name
                    $target   = Get-ToolTarget $toolName $block.input

                    if ($toolName -eq 'Task') {
                        $agentMap[[string]$block.id] = [pscustomobject]@{
                            id          = [string]$block.id
                            type        = ($block.input.subagent_type ?? 'unknown')
                            model       = $block.input.model
                            description = $block.input.description
                            status      = 'running'
                            startTime   = $ts
                            endTime     = $null
                        }
                    }
                    elseif ($toolName -eq 'TodoWrite') {
                        if ($block.input.todos) {
                            $todos.Clear()
                            $taskIndex.Clear()
                            foreach ($t in $block.input.todos) {
                                $todos.Add([pscustomobject]@{
                                    content = [string]$t.content
                                    status  = [string]$t.status
                                })
                            }
                        }
                    }
                    elseif ($toolName -eq 'TaskCreate') {
                        $subject     = [string]($block.input.subject     ?? '')
                        $description = [string]($block.input.description ?? '')
                        $content2    = if ($subject) { $subject } elseif ($description) { $description } else { 'Untitled task' }
                        $status      = (Normalize-TaskStatus $block.input.status) ?? 'pending'
                        $todos.Add([pscustomobject]@{ content = $content2; status = $status })

                        $taskId = $block.input.taskId
                        $key = if ($null -ne $taskId) { [string]$taskId } else { [string]$block.id }
                        if ($key) { $taskIndex[$key] = $todos.Count - 1 }
                    }
                    elseif ($toolName -eq 'TaskUpdate') {
                        $idx = Resolve-TaskIndex $block.input.taskId $taskIndex $todos
                        if ($null -ne $idx) {
                            $newStatus = Normalize-TaskStatus $block.input.status
                            if ($newStatus) { $todos[$idx].status = $newStatus }
                            $subject     = [string]($block.input.subject     ?? '')
                            $description = [string]($block.input.description ?? '')
                            $newContent  = if ($subject) { $subject } else { $description }
                            if ($newContent) { $todos[$idx].content = $newContent }
                        }
                    }
                    else {
                        $toolMap[[string]$block.id] = [pscustomobject]@{
                            id        = [string]$block.id
                            name      = $toolName
                            target    = $target
                            status    = 'running'
                            startTime = $ts
                            endTime   = $null
                        }
                    }
                }

                if ($block.type -eq 'tool_result' -and $block.tool_use_id) {
                    $tid = [string]$block.tool_use_id
                    if ($toolMap.Contains($tid)) {
                        $toolMap[$tid].status  = if ($block.is_error) { 'error' } else { 'completed' }
                        $toolMap[$tid].endTime = $ts
                    }
                    if ($agentMap.Contains($tid)) {
                        $agentMap[$tid].status  = 'completed'
                        $agentMap[$tid].endTime = $ts
                    }
                }
            }
        }
    } catch { $cleanParse = $false }

    $tools  = @($toolMap.Values  | Select-Object -Last 20)
    $agents = @($agentMap.Values | Select-Object -Last 10)

    $data = [pscustomobject]@{
        tools        = $tools
        agents       = $agents
        todos        = $todos.ToArray()
        sessionStart = if ($sessionStart) { $sessionStart.ToString('o') } else { $null }
        sessionName  = ($customTitle ?? $latestSlug)
    }

    if ($cleanParse) { Write-TranscriptCache $Path $state $data }
    return ConvertTo-Transcript $data
}

function _ParseDate($v) {
    if (-not $v) { return $null }
    # ConvertFrom-Json auto-parses ISO 8601 with Z into a DateTime(Kind=Utc).
    # Re-stringifying then re-parsing loses Kind and shifts by tz offset, so
    # short-circuit when we already have a DateTime.
    if ($v -is [datetime]) {
        if ($v.Kind -eq [DateTimeKind]::Unspecified) {
            return [datetime]::SpecifyKind($v, [DateTimeKind]::Utc)
        }
        return $v.ToUniversalTime()
    }
    try {
        return [datetime]::Parse(
            [string]$v, $null,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
            [System.Globalization.DateTimeStyles]::AdjustToUniversal)
    } catch { return $null }
}

function ConvertTo-Transcript($data) {
    return [pscustomobject]@{
        Tools        = @($data.tools)
        Agents       = @($data.agents)
        Todos        = @($data.todos)
        SessionStart = (_ParseDate $data.sessionStart)
        SessionName  = $data.sessionName
    }
}

function Get-ToolTarget([string]$Name, $ToolInput) {
    if (-not $ToolInput) { return $null }
    switch ($Name) {
        'Read'  { return ($ToolInput.file_path ?? $ToolInput.path) }
        'Write' { return ($ToolInput.file_path ?? $ToolInput.path) }
        'Edit'  { return ($ToolInput.file_path ?? $ToolInput.path) }
        'Glob'  { return $ToolInput.pattern }
        'Grep'  { return $ToolInput.pattern }
        'Bash'  {
            $cmd = [string]$ToolInput.command
            if (-not $cmd) { return $null }
            if ($cmd.Length -gt 30) { return $cmd.Substring(0, 30) + '...' }
            return $cmd
        }
    }
    return $null
}

function Normalize-TaskStatus($status) {
    if ($status -isnot [string]) { return $null }
    switch ($status) {
        'pending'      { return 'pending' }
        'not_started'  { return 'pending' }
        'in_progress'  { return 'in_progress' }
        'running'      { return 'in_progress' }
        'completed'    { return 'completed' }
        'complete'     { return 'completed' }
        'done'         { return 'completed' }
    }
    return $null
}

function Resolve-TaskIndex($taskId, $taskIndex, $todos) {
    if ($null -eq $taskId) { return $null }
    $key = [string]$taskId
    if ($taskIndex.ContainsKey($key)) { return $taskIndex[$key] }
    if ($key -match '^\d+$') {
        $n = [int]$key - 1
        if ($n -ge 0 -and $n -lt $todos.Count) { return $n }
    }
    return $null
}

# ============================================================================
# Git status
# ============================================================================
function Run-Git([string]$Cwd, [string[]]$GitArgs, [int]$TimeoutMs = 1000) {
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = 'git'
        foreach ($a in $GitArgs) { [void]$psi.ArgumentList.Add($a) }
        $psi.WorkingDirectory       = $Cwd
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $p = [System.Diagnostics.Process]::Start($psi)
        if (-not $p.WaitForExit($TimeoutMs)) {
            try { $p.Kill() } catch {}
            return $null
        }
        if ($p.ExitCode -ne 0) { return $null }
        return $p.StandardOutput.ReadToEnd()
    } catch { return $null }
}

function Get-GitStatus([string]$Cwd) {
    if (-not $Cwd) { return $null }
    $branch = Run-Git $Cwd @('rev-parse', '--abbrev-ref', 'HEAD')
    if (-not $branch) { return $null }
    $branch = $branch.Trim()
    if (-not $branch) { return $null }

    $isDirty = $false
    $stats   = $null
    $statusOut = Run-Git $Cwd @('--no-optional-locks', 'status', '--porcelain')
    if ($null -ne $statusOut) {
        $trimmed = $statusOut.Trim()
        if ($trimmed.Length -gt 0) {
            $isDirty = $true
            $stats = Parse-FileStats $trimmed
        }
    }

    $ahead = 0; $behind = 0
    $rev = Run-Git $Cwd @('rev-list', '--left-right', '--count', '@{upstream}...HEAD')
    if ($rev) {
        $parts = $rev.Trim() -split '\s+'
        if ($parts.Length -eq 2) {
            $behind = [int]$parts[0]
            $ahead  = [int]$parts[1]
        }
    }

    return [pscustomobject]@{
        Branch    = $branch
        IsDirty   = $isDirty
        Ahead     = $ahead
        Behind    = $behind
        FileStats = $stats
    }
}

function Parse-FileStats([string]$Porcelain) {
    $s = [pscustomobject]@{ Modified = 0; Added = 0; Deleted = 0; Untracked = 0 }
    foreach ($line in $Porcelain -split "`n") {
        if ($line.Length -lt 2) { continue }
        if ($line.StartsWith('??')) { $s.Untracked++; continue }
        $idx = $line[0]; $wt = $line[1]
        if     ($idx -eq 'A') { $s.Added++ }
        elseif ($idx -eq 'D' -or $wt -eq 'D') { $s.Deleted++ }
        elseif ($idx -eq 'M' -or $wt -eq 'M' -or $idx -eq 'R' -or $idx -eq 'C') { $s.Modified++ }
    }
    return $s
}

# ============================================================================
# Config counts (CLAUDE.md, rules, MCPs, hooks)
# ============================================================================
function Read-Json([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json } catch { return $null }
}
function Get-McpServerNames([string]$Path) {
    $cfg = Read-Json $Path
    if (-not $cfg -or -not $cfg.mcpServers) { return @() }
    return @($cfg.mcpServers.PSObject.Properties.Name)
}
function Get-DisabledMcps([string]$Path, [string]$Key) {
    $cfg = Read-Json $Path
    if (-not $cfg) { return @() }
    $val = $cfg.$Key
    if ($val -is [System.Collections.IEnumerable] -and -not ($val -is [string])) {
        return @($val | Where-Object { $_ -is [string] })
    }
    return @()
}
function Count-HooksInFile([string]$Path) {
    $cfg = Read-Json $Path
    if (-not $cfg -or -not $cfg.hooks) { return 0 }
    return @($cfg.hooks.PSObject.Properties.Name).Count
}
function Count-RulesDir([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir)) { return 0 }
    return @(Get-ChildItem -LiteralPath $Dir -Recurse -File -Filter *.md -ErrorAction SilentlyContinue).Count
}

function Get-ConfigCounts([string]$Cwd) {
    $userHome = [Environment]::GetFolderPath('UserProfile')
    $claudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $userHome '.claude' }
    if ($claudeDir -like '~*') { $claudeDir = Join-Path $userHome $claudeDir.Substring(2) }

    $claudeMd = 0; $rules = 0; $hooks = 0
    $userMcps = New-Object System.Collections.Generic.HashSet[string]
    $projMcps = New-Object System.Collections.Generic.HashSet[string]

    if (Test-Path (Join-Path $claudeDir 'CLAUDE.md')) { $claudeMd++ }
    $rules += Count-RulesDir (Join-Path $claudeDir 'rules')

    $userSettings = Join-Path $claudeDir 'settings.json'
    foreach ($n in Get-McpServerNames $userSettings) { [void]$userMcps.Add($n) }
    $hooks += Count-HooksInFile $userSettings

    $userClaudeJson = "$claudeDir.json"
    foreach ($n in Get-McpServerNames $userClaudeJson) { [void]$userMcps.Add($n) }
    foreach ($d in Get-DisabledMcps $userClaudeJson 'disabledMcpServers') { [void]$userMcps.Remove($d) }

    if ($Cwd) {
        if (Test-Path (Join-Path $Cwd 'CLAUDE.md'))       { $claudeMd++ }
        if (Test-Path (Join-Path $Cwd 'CLAUDE.local.md')) { $claudeMd++ }

        $projClaudeDir = Join-Path $Cwd '.claude'
        $sameAsUser = $false
        try {
            if ((Test-Path -LiteralPath $projClaudeDir) -and (Test-Path -LiteralPath $claudeDir)) {
                $a = (Resolve-Path -LiteralPath $projClaudeDir).Path.TrimEnd('\','/').ToLower()
                $b = (Resolve-Path -LiteralPath $claudeDir).Path.TrimEnd('\','/').ToLower()
                if ($a -eq $b) { $sameAsUser = $true }
            }
        } catch {}

        if (-not $sameAsUser) {
            if (Test-Path (Join-Path $projClaudeDir 'CLAUDE.md'))       { $claudeMd++ }
        }
        if (Test-Path (Join-Path $projClaudeDir 'CLAUDE.local.md')) { $claudeMd++ }
        if (-not $sameAsUser) {
            $rules += Count-RulesDir (Join-Path $projClaudeDir 'rules')
        }

        $mcpJson = @(Get-McpServerNames (Join-Path $Cwd '.mcp.json'))

        $projSettings = Join-Path $projClaudeDir 'settings.json'
        if (-not $sameAsUser) {
            foreach ($n in Get-McpServerNames $projSettings) { [void]$projMcps.Add($n) }
            $hooks += Count-HooksInFile $projSettings
        }

        $localSettings = Join-Path $projClaudeDir 'settings.local.json'
        foreach ($n in Get-McpServerNames $localSettings) { [void]$projMcps.Add($n) }
        $hooks += Count-HooksInFile $localSettings

        $disabled = Get-DisabledMcps $localSettings 'disabledMcpjsonServers'
        $mcpJson  = @($mcpJson | Where-Object { $disabled -notcontains $_ })
        foreach ($n in $mcpJson) { [void]$projMcps.Add($n) }
    }

    return [pscustomobject]@{
        ClaudeMd = $claudeMd
        Rules    = $rules
        Mcp      = $userMcps.Count + $projMcps.Count
        Hooks    = $hooks
    }
}

# ============================================================================
# Formatting helpers
# ============================================================================
function Format-Tokens([int]$N) {
    if ($N -ge 1000000) { return ('{0:N1}M' -f ($N / 1000000.0)) }
    if ($N -ge 1000)    { return ('{0:N0}k' -f ($N / 1000.0)) }
    return $N.ToString()
}
function Format-SessionDuration($Start) {
    if (-not $Start) { return '' }
    $ms = ([datetime]::UtcNow - $Start).TotalMilliseconds
    if ($ms -lt 0) { return '' }
    $mins = [int][Math]::Floor($ms / 60000)
    if ($mins -lt 1)  { return '<1m' }
    if ($mins -lt 60) { return "${mins}m" }
    $h = [int][Math]::Floor($mins / 60)
    $m = $mins % 60
    return "${h}h ${m}m"
}
function Format-ResetTime($ResetAt) {
    if (-not $ResetAt) { return '' }
    $diffMs = ([datetime]$ResetAt - (Get-Date)).TotalMilliseconds
    if ($diffMs -le 0) { return '' }
    $mins = [int][Math]::Ceiling($diffMs / 60000)
    if ($mins -lt 60) { return "${mins}m" }
    $hours = [int][Math]::Floor($mins / 60)
    $m = $mins % 60
    if ($hours -ge 24) {
        $days = [int][Math]::Floor($hours / 24)
        $rh = $hours % 24
        if ($rh -gt 0) { return "${days}d ${rh}h" }
        return "${days}d"
    }
    if ($m -gt 0) { return "${hours}h ${m}m" }
    return "${hours}h"
}
function Format-ElapsedSince($Start, $End) {
    if (-not $Start) { return '?' }
    $endTime = if ($End) { [datetime]$End } else { [datetime]::UtcNow }
    $ms = ($endTime - [datetime]$Start).TotalMilliseconds
    if ($ms -lt 1000)  { return '<1s' }
    if ($ms -lt 60000) { return ('{0}s' -f [int][Math]::Round($ms / 1000)) }
    $mins = [int][Math]::Floor($ms / 60000)
    $secs = [int][Math]::Round(($ms % 60000) / 1000)
    return "${mins}m ${secs}s"
}

# ============================================================================
# Line renderers
# ============================================================================
function Render-ProjectLine($ctx) {
    $parts = [System.Collections.Generic.List[string]]::new()

    $modelName = Get-ModelName $ctx.Stdin
    $hasApiKey = [bool]$env:ANTHROPIC_API_KEY
    $modelDisplay = if ($Config.ShowUsage -and $hasApiKey) { "$modelName | $(Red 'API')" } else { $modelName }
    $parts.Add((Cyan "[$modelDisplay]"))

    $projectPart = $null
    if ($ctx.Stdin.cwd) {
        $segments = $ctx.Stdin.cwd -split '[\\/]+' | Where-Object { $_ }
        $levels = [Math]::Max(1, [int]$Config.PathLevels)
        if ($segments.Count -gt 0) {
            $take = $segments | Select-Object -Last $levels
            $projectPath = ($take -join '/')
        } else { $projectPath = '/' }
        $projectPart = (Yellow $projectPath)
    }

    $gitPart = ''
    if ($ctx.GitStatus) {
        $g = $ctx.GitStatus
        $branchText = $g.Branch
        if ($Config.ShowDirty -and $g.IsDirty) { $branchText += '*' }
        if ($Config.ShowAheadBehind) {
            if ($g.Ahead  -gt 0) { $branchText += " ↑$($g.Ahead)" }
            if ($g.Behind -gt 0) { $branchText += " ↓$($g.Behind)" }
        }
        if ($Config.ShowFileStats -and $g.FileStats) {
            $fs = $g.FileStats
            $sp = @()
            if ($fs.Modified  -gt 0) { $sp += "!$($fs.Modified)" }
            if ($fs.Added     -gt 0) { $sp += "+$($fs.Added)" }
            if ($fs.Deleted   -gt 0) { $sp += "✘$($fs.Deleted)" }
            if ($fs.Untracked -gt 0) { $sp += "?$($fs.Untracked)" }
            if ($sp.Count -gt 0) { $branchText += ' ' + ($sp -join ' ') }
        }
        # NOTE: PowerShell's parser miscounts parens inside `$(... '(' ...)`,
        # so build via concatenation instead of inline subexpressions.
        $gitOpen  = Magenta 'git:('
        $gitClose = Magenta ')'
        $gitMid   = Cyan $branchText
        $gitPart  = "${gitOpen}${gitMid}${gitClose}"
    }

    if ($projectPart -and $gitPart) { $parts.Add("$projectPart $gitPart") }
    elseif ($projectPart)            { $parts.Add($projectPart) }
    elseif ($gitPart)                { $parts.Add($gitPart) }

    if ($Config.ShowDuration -and $ctx.SessionDuration) {
        # U+23F1 + U+FE0F (variation selector) requests the emoji presentation.
        $parts.Add((Dim "⏱️  $($ctx.SessionDuration)"))
    }

    if ($parts.Count -eq 0) { return $null }
    return ($parts -join ' │ ')
}

function Render-ContextLine($ctx) {
    $raw = Get-RawContextPercent $ctx.Stdin
    $buf = Get-BufferedContextPercent $ctx.Stdin
    $percent = if ($Config.AutocompactBuffer -eq 'disabled') { $raw } else { $buf }
    $color = Get-ContextColor $percent
    $valueDisplay = "$color$percent%$ANSI_RESET"
    $bar = Colored-Bar $percent (Get-AdaptiveBarWidth)

    $line = if ($Config.ShowContextBar) {
        "$(Dim 'Context') $bar $valueDisplay"
    } else {
        "$(Dim 'Context') $valueDisplay"
    }

    if ($Config.ShowTokenBreakdown -and $percent -ge 85) {
        $u = $ctx.Stdin.context_window.current_usage
        if ($u) {
            $in    = Format-Tokens ([int]($u.input_tokens ?? 0))
            $cache = Format-Tokens ([int](($u.cache_creation_input_tokens ?? 0) + ($u.cache_read_input_tokens ?? 0)))
            $line += (Dim " (in: $in, cache: $cache)")
        }
    }
    return $line
}

function Render-UsageLine($ctx) {
    if (-not $Config.ShowUsage) { return $null }
    if (-not $ctx.UsageData)    { return $null }

    $u = $ctx.UsageData
    $usageLabel = Dim 'Usage'

    if (($u.FiveHour -eq 100) -or ($u.SevenDay -eq 100)) {
        $resetAt = if ($u.FiveHour -eq 100) { $u.FiveHourResetAt } else { $u.SevenDayResetAt }
        $rt = Format-ResetTime $resetAt
        $msg = if ($rt) { "⚠ Limit reached (resets $rt)" } else { '⚠ Limit reached' }
        return "$usageLabel $(Red $msg)"
    }

    $five  = $u.FiveHour
    $seven = $u.SevenDay
    $effective = [Math]::Max(($five ?? 0), ($seven ?? 0))
    if ($effective -lt $Config.UsageThreshold) { return $null }

    $barWidth = Get-AdaptiveBarWidth
    $fivePart = Format-UsagePart '5h' $five $u.FiveHourResetAt $barWidth $false

    if ($null -eq $five -and $null -ne $seven) {
        $part = Format-UsagePart '7d' $seven $u.SevenDayResetAt $barWidth $true
        return "$usageLabel $part"
    }

    if ($null -ne $seven -and $seven -ge $Config.SevenDayThreshold) {
        $sevenPart = Format-UsagePart '7d' $seven $u.SevenDayResetAt $barWidth $false
        return "$usageLabel $fivePart | $sevenPart"
    }

    return "$usageLabel $fivePart"
}

function Format-UsagePart([string]$Label, $Percent, $ResetAt, [int]$BarWidth, [bool]$ForceLabel) {
    $valueDisplay = if ($null -eq $Percent) {
        Dim '--'
    } else {
        "$(Get-QuotaColor $Percent)$Percent%$ANSI_RESET"
    }
    $reset = Format-ResetTime $ResetAt

    if ($Config.UsageBarEnabled) {
        $body = if ($reset) {
            "$(Quota-Bar ($Percent ?? 0) $BarWidth) $valueDisplay (resets in $reset)"
        } else {
            "$(Quota-Bar ($Percent ?? 0) $BarWidth) $valueDisplay"
        }
        if ($ForceLabel) { return "${Label}: $body" }
        return $body
    }
    if ($reset) { return "${Label}: $valueDisplay (resets in $reset)" }
    return "${Label}: $valueDisplay"
}

function Render-EnvironmentLine($ctx) {
    if (-not $Config.ShowConfigCounts) { return $null }
    $c = $ctx.Counts
    $total = $c.ClaudeMd + $c.Rules + $c.Mcp + $c.Hooks
    if ($total -eq 0 -or $total -lt $Config.EnvironmentThreshold) { return $null }

    $parts = @()
    if ($c.ClaudeMd -gt 0) { $parts += "$($c.ClaudeMd) CLAUDE.md" }
    if ($c.Rules    -gt 0) { $parts += "$($c.Rules) rules" }
    if ($c.Mcp      -gt 0) { $parts += "$($c.Mcp) MCPs" }
    if ($c.Hooks    -gt 0) { $parts += "$($c.Hooks) hooks" }
    if ($parts.Count -eq 0) { return $null }
    return Dim ($parts -join ' | ')
}

function Render-ToolsLine($ctx) {
    if (-not $Config.ShowTools) { return $null }
    $tools = $ctx.Transcript.Tools
    if (-not $tools -or $tools.Count -eq 0) { return $null }

    $parts = @()
    $running   = @($tools | Where-Object { $_.status -eq 'running' })
    $completed = @($tools | Where-Object { $_.status -eq 'completed' -or $_.status -eq 'error' })

    foreach ($t in ($running | Select-Object -Last 2)) {
        $tgt = if ($t.target) { Truncate-ToolPath $t.target 20 } else { '' }
        if ($tgt) {
            $parts += "$(Yellow '◐') $(Cyan $t.name)$(Dim ": $tgt")"
        } else {
            $parts += "$(Yellow '◐') $(Cyan $t.name)"
        }
    }

    $counts = @{}
    foreach ($t in $completed) {
        if (-not $counts.ContainsKey($t.name)) { $counts[$t.name] = 0 }
        $counts[$t.name]++
    }
    $sorted = $counts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 4
    foreach ($e in $sorted) {
        $parts += "$(Green '✓') $($e.Key) $(Dim "×$($e.Value)")"
    }
    if ($parts.Count -eq 0) { return $null }
    return ($parts -join ' | ')
}

function Truncate-ToolPath([string]$Path, [int]$MaxLen = 20) {
    $p = $Path -replace '\\', '/'
    if ($p.Length -le $MaxLen) { return $p }
    $segments = $p -split '/'
    $file = $segments[-1]
    if ($file.Length -ge $MaxLen) { return $file.Substring(0, [Math]::Max(0, $MaxLen - 3)) + '...' }
    return ".../$file"
}

function Render-AgentsLine($ctx) {
    if (-not $Config.ShowAgents) { return $null }
    $agents = $ctx.Transcript.Agents
    if (-not $agents -or $agents.Count -eq 0) { return $null }

    $running = @($agents | Where-Object { $_.status -eq 'running' })
    $recent  = @($agents | Where-Object { $_.status -eq 'completed' } | Select-Object -Last 2)
    $show    = @(@($running) + @($recent)) | Select-Object -Last 3

    if (-not $show -or $show.Count -eq 0) { return $null }

    $lines = foreach ($a in $show) {
        $icon  = if ($a.status -eq 'running') { Yellow '◐' } else { Green '✓' }
        $type  = Magenta $a.type
        $model = if ($a.model) { Dim "[$($a.model)]" } else { '' }
        $desc  = if ($a.description) {
            $d = [string]$a.description
            if ($d.Length -gt 40) { $d = $d.Substring(0, 37) + '...' }
            Dim ": $d"
        } else { '' }
        $elapsed = Format-ElapsedSince $a.startTime $a.endTime
        $modelPart = if ($model) { " $model" } else { '' }
        "$icon $type$modelPart$desc $(Dim "($elapsed)")"
    }
    return ($lines -join "`n")
}

function Render-TodosLine($ctx) {
    if (-not $Config.ShowTodos) { return $null }
    $todos = $ctx.Transcript.Todos
    if (-not $todos -or $todos.Count -eq 0) { return $null }

    $inProgress = @($todos | Where-Object { $_.status -eq 'in_progress' })[0]
    $completed  = @($todos | Where-Object { $_.status -eq 'completed' }).Count
    $total      = $todos.Count

    if (-not $inProgress) {
        if ($completed -eq $total -and $total -gt 0) {
            return "$(Green '✓') All todos complete $(Dim "($completed/$total)")"
        }
        return $null
    }

    $content = [string]$inProgress.content
    if ($content.Length -gt 50) { $content = $content.Substring(0, 47) + '...' }
    return "$(Yellow '▸') $content $(Dim "($completed/$total)")"
}

function Render-Separator([int]$Width) {
    Dim ('─' * [Math]::Max(1, $Width))
}

# ============================================================================
# Width-aware truncation (visible-length aware: ignores ANSI escapes)
# ============================================================================
$AnsiPattern = "$ANSI_ESC\[[0-9;]*m"

function Visual-Length([string]$s) {
    if (-not $s) { return 0 }
    return ($s -replace $AnsiPattern, '').Length
}

function Truncate-ToWidth([string]$Line, [int]$MaxWidth) {
    if ($MaxWidth -le 0) { return '' }
    if ((Visual-Length $Line) -le $MaxWidth) { return $Line }
    $sb = [System.Text.StringBuilder]::new()
    $visible = 0
    $i = 0
    $suffix = if ($MaxWidth -ge 3) { '...' } else { '.' * $MaxWidth }
    $keep = [Math]::Max(0, $MaxWidth - $suffix.Length)
    while ($i -lt $Line.Length -and $visible -lt $keep) {
        if ($Line[$i] -eq $ANSI_ESC) {
            $end = $Line.IndexOf('m', $i)
            if ($end -ge 0) {
                [void]$sb.Append($Line.Substring($i, $end - $i + 1))
                $i = $end + 1
                continue
            }
        }
        [void]$sb.Append($Line[$i])
        $visible++
        $i++
    }
    [void]$sb.Append($suffix)
    [void]$sb.Append($ANSI_RESET)
    return $sb.ToString()
}

# ============================================================================
# Main
# ============================================================================
$stdin = Read-Stdin
if (-not $stdin) {
    Write-Output '[claude-hud] Initializing...'
    return
}

$transcript = Parse-Transcript ([string]$stdin.transcript_path)
$counts     = Get-ConfigCounts ([string]$stdin.cwd)
$gitStatus  = Get-GitStatus    ([string]$stdin.cwd)
$usageData  = if ($Config.ShowUsage) { Get-UsageData $stdin } else { $null }
$duration   = Format-SessionDuration $transcript.SessionStart

$ctx = [pscustomobject]@{
    Stdin           = $stdin
    Transcript      = $transcript
    Counts          = $counts
    GitStatus       = $gitStatus
    UsageData       = $usageData
    SessionDuration = $duration
}

# Build expanded layout, mirroring the upstream default element order:
#   project, context+usage (merged), environment, tools, agents, todos
$projectLine = Render-ProjectLine $ctx
$contextLine = Render-ContextLine $ctx
$usageLine   = Render-UsageLine   $ctx
$envLine     = Render-EnvironmentLine $ctx
$toolsLine   = Render-ToolsLine   $ctx
$agentsLine  = Render-AgentsLine  $ctx
$todosLine   = Render-TodosLine   $ctx

$output = [System.Collections.Generic.List[object]]::new()

if ($projectLine) { $output.Add(@{ Line = $projectLine; IsActivity = $false }) }
if ($contextLine -and $usageLine) {
    $output.Add(@{ Line = "$contextLine │ $usageLine"; IsActivity = $false })
} elseif ($contextLine) {
    $output.Add(@{ Line = $contextLine; IsActivity = $false })
} elseif ($usageLine) {
    $output.Add(@{ Line = $usageLine; IsActivity = $false })
}
if ($envLine)    { $output.Add(@{ Line = $envLine;    IsActivity = $false }) }
if ($toolsLine)  { $output.Add(@{ Line = $toolsLine;  IsActivity = $true  }) }
if ($agentsLine) { $output.Add(@{ Line = $agentsLine; IsActivity = $true  }) }
if ($todosLine)  { $output.Add(@{ Line = $todosLine;  IsActivity = $true  }) }

if ($Config.ShowSeparators) {
    $firstActivity = -1
    for ($i = 0; $i -lt $output.Count; $i++) {
        if ($output[$i].IsActivity) { $firstActivity = $i; break }
    }
    if ($firstActivity -gt 0) {
        $maxW = 20
        for ($i = 0; $i -lt $firstActivity; $i++) {
            $w = Visual-Length $output[$i].Line
            if ($w -gt $maxW) { $maxW = $w }
        }
        $tw = Get-TerminalWidth
        $sw = [Math]::Min($maxW, $tw)
        $output.Insert($firstActivity, @{ Line = (Render-Separator $sw); IsActivity = $false })
    }
}

$termWidth = Get-TerminalWidth
foreach ($entry in $output) {
    foreach ($physical in ($entry.Line -split "`n")) {
        Write-Output ($ANSI_RESET + (Truncate-ToWidth $physical $termWidth))
    }
}
