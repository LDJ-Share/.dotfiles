#requires -Version 7
# Changed-files-only .NET style pass: ReSharper CleanupCode -> dotnet format ->
# XAML Styler, scoped to files changed vs HEAD (tracked ACMR + untracked).
#
# -Verify  : non-mutating check. NOTE: ReSharper CleanupCode has no passive mode,
#            so it is SKIPPED under -Verify. A green run does NOT prove
#            ReSharper-clean — run without -Verify and inspect the diff.
# -Solution: the .sln to target. Defaults to the single *.sln at the repo root.
#
# GOTCHA: this diffs vs HEAD, so a fully-committed branch styles NOTHING (false
# "clean"). Style before committing, or diff vs `master...HEAD` and run manually.
param(
    [switch] $Verify,
    [string] $Solution
)

$ErrorActionPreference = "Stop"

$repoRoot = (& git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

dotnet tool restore

if (-not $Solution) {
    $Solution = (Get-ChildItem -Path $repoRoot -Filter *.sln -File | Select-Object -First 1).Name
    if (-not $Solution) { throw "No .sln found at $repoRoot; pass -Solution explicitly." }
}

$tracked = & git diff --name-only --diff-filter=ACMR HEAD --
$untracked = & git ls-files --others --exclude-standard
$changed = @($tracked + $untracked) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Sort-Object -Unique

if (-not $changed) {
    Write-Host "No changed files to style."
    exit 0
}

$dotnetExtensions = @(".cs", ".csx", ".csproj", ".props", ".targets")
$dotnetFiles = @(
    $changed |
        Where-Object { $dotnetExtensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant() }
)

# 1. ReSharper CleanupCode (mutating only; skipped under -Verify).
if (-not $Verify -and $dotnetFiles.Count -gt 0) {
    $resharperInclude = [string]::Join(";", $dotnetFiles)
    # Quote --include: the semicolon list must arrive as ONE token.
    & dotnet tool run jb -- cleanupcode $Solution --profile="Built-in: Full Cleanup" --no-build "--include=$resharperInclude"
}

# 2. dotnet format (EditorConfig).
if ($dotnetFiles.Count -gt 0) {
    $formatArgs = @("format", $Solution, "--include") + $dotnetFiles
    if ($Verify) { $formatArgs += "--verify-no-changes" }
    & dotnet @formatArgs
}

# 3. XAML Styler (per changed .xaml file).
$xamlFiles = @(
    $changed |
        Where-Object { [System.IO.Path]::GetExtension($_).Equals(".xaml", [System.StringComparison]::OrdinalIgnoreCase) }
)
foreach ($xamlFile in $xamlFiles) {
    $xstylerArgs = @("--")
    if ($Verify) { $xstylerArgs += "--passive" }
    $xstylerArgs += @("-f", $xamlFile, "-c", "Settings.XamlStyler")
    & dotnet tool run xstyler @xstylerArgs
}

if ($Verify) {
    Write-Host "Changed-file style verification complete. ReSharper CleanupCode has no passive mode; run without -Verify and inspect the diff before pushing."
} else {
    Write-Host "Changed-file styling complete. Review the diff before pushing."
}
