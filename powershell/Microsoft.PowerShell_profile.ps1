# PowerShell Profile — cross-platform (Linux/macOS/Windows)

Write-Host "Loading PowerShell Profile from $PSScriptRoot..." -ForegroundColor Cyan

# ── Home (cross-platform) ────────────────────────────────────────────────────
$UserHome = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }

# ── Prompt (oh-my-posh) ──────────────────────────────────────────────────────
$poshConfig = Join-Path $PSScriptRoot "oh-my-posh-tokyo-night-storm.toml"
if ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -and (Test-Path $poshConfig)) {
    oh-my-posh init pwsh --config $poshConfig | Invoke-Expression
}

# ── Modules ──────────────────────────────────────────────────────────────────
Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
if ($host.Name -eq 'ConsoleHost') {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
}
Import-Module PSWriteColor -ErrorAction SilentlyContinue

# ── Environment Variables ────────────────────────────────────────────────────
$env:EDITOR             = "nvim"
$env:POSH_GIT_ENABLED   = $true
$env:GOPATH             = Join-Path $UserHome "go"
$env:KUBECONFIG         = Join-Path $UserHome ".kube/config"
$env:XDG_CONFIG_HOME    = Join-Path $UserHome ".config"
$env:XDG_CACHE_HOME     = Join-Path $UserHome ".cache"
$env:XDG_DATA_HOME      = Join-Path $UserHome ".local/share"
$env:MYVIMRC            = Join-Path $env:XDG_CONFIG_HOME "nvim/init.lua"
$env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow'

# ── Aliases ──────────────────────────────────────────────────────────────────
Set-Alias vi    nvim
Set-Alias v     nvim
Set-Alias cl    Clear-Host
Set-Alias j     just    -ErrorAction SilentlyContinue

if (Get-Command xh -ErrorAction SilentlyContinue)  { Set-Alias http xh }
if (Get-Command bat -ErrorAction SilentlyContinue) { Set-Alias cat bat }

# `which` — use platform-appropriate binary
if ($IsWindows) {
    Set-Alias which where.exe
} else {
    Set-Alias which (Get-Command which).Source -ErrorAction SilentlyContinue
}

# ── Load PSReadLine config ───────────────────────────────────────────────────
$psReadLinePath = Join-Path $PSScriptRoot "Microsoft.PowerShell_profile-PSReadLine.ps1"
if (Test-Path $psReadLinePath) {
    . $psReadLinePath
}

# ── Load custom module (co-located with profile) ─────────────────────────────
$ModulePath = Join-Path $PSScriptRoot "Modules/MyProfileUtils"
if (Test-Path $ModulePath) {
    Import-Module -Name (Join-Path $ModulePath "MyProfileUtils.psd1") -Force
}

# ── Tool Initialisations ─────────────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    zoxide init powershell | Invoke-Expression
}
if (Get-Command direnv -ErrorAction SilentlyContinue) {
    direnv hook pwsh | Invoke-Expression
}
