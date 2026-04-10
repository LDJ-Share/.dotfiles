param(
  [string]$BundlePath = "",
  [string]$ComposeFile = ".devcontainer/docker-compose.yml",
  [switch]$KeepWorkdir,
  [switch]$Help
)

function Show-Usage {
  @"
Usage: pwsh -File .\image-import.ps1 -BundlePath <bundle.tar.gz> [options]

Verify a Phase 5 transport bundle, restore the compose images, and validate
the offline compose contract.

Parameters:
  -BundlePath <path>     Path to <bundle>.tar.gz
  -ComposeFile <path>    Compose file to validate (default: .devcontainer/docker-compose.yml)
  -KeepWorkdir           Do not delete the extracted temporary workspace
  -Help                  Show this help text

Inputs:
  <bundle>.tar.gz
  <bundle>-manifest.json
  <bundle>-SHA256SUMS

Contract:
  1. Verify SHA256 before extraction or docker load
  2. Extract <bundle>/images.tar and load it with docker load
  3. Validate the compose stack with docker compose config
"@
}

function Get-ComposeImages {
  param([string]$ComposePath)

  $images = & docker compose -f $ComposePath config --images 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Unable to enumerate compose images with 'docker compose config --images'; compose syntax still validated"
    return @()
  }

  return @($images | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

if ($Help) {
  Show-Usage
  exit 0
}

if ([string]::IsNullOrWhiteSpace($BundlePath)) {
  throw "BundlePath is required."
}

if (-not (Test-Path $BundlePath -PathType Leaf)) {
  throw "Bundle archive not found: $BundlePath"
}

if (-not (Test-Path $ComposeFile -PathType Leaf)) {
  throw "Compose file not found: $ComposeFile"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not on PATH."
}

& docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Docker is not available. Start Docker and retry."
}

$bundleItem = Get-Item $BundlePath
$bundleDir = $bundleItem.Directory.FullName
$bundleFile = $bundleItem.Name
$bundleStem = if ($bundleFile.EndsWith('.tar.gz')) { $bundleFile.Substring(0, $bundleFile.Length - 7) } else { [System.IO.Path]::GetFileNameWithoutExtension($bundleFile) }

$manifestPath = Join-Path $bundleDir "$bundleStem-manifest.json"
$checksumPath = Join-Path $bundleDir "$bundleStem-SHA256SUMS"

if (-not (Test-Path $manifestPath -PathType Leaf)) {
  throw "Sibling manifest not found: $manifestPath"
}

if (-not (Test-Path $checksumPath -PathType Leaf)) {
  throw "Sibling SHA256SUMS not found: $checksumPath"
}

$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
if ($manifest.archive_name -ne $bundleFile) {
  throw "Manifest archive_name '$($manifest.archive_name)' does not match '$bundleFile'"
}

Write-Host "Verifying SHA256 before extraction" -ForegroundColor Green
$checksumLine = (Get-Content $checksumPath | Where-Object { $_ -match '\S' } | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($checksumLine)) {
  throw "SHA256SUMS is empty: $checksumPath"
}

$checksumParts = $checksumLine -split '\s+', 2
$expectedHash = $checksumParts[0].ToLowerInvariant()
$checksumFileName = $checksumParts[1].Trim()
if ($checksumFileName -ne $bundleFile) {
  throw "SHA256SUMS references '$checksumFileName' instead of '$bundleFile'"
}

$actualHash = (Get-FileHash $BundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expectedHash -ne $actualHash) {
  throw "Bundle checksum mismatch. Expected $expectedHash but got $actualHash"
}

if ($manifest.archive_sha256.ToLowerInvariant() -ne $actualHash) {
  throw "Manifest archive_sha256 does not match the actual archive checksum"
}

$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

try {
  Write-Host "Extracting bundle to $workDir" -ForegroundColor Green
  tar -xzf $BundlePath -C $workDir
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to extract bundle archive."
  }

  $payloadDir = Join-Path $workDir $manifest.bundle_name
  $imageTarPath = Join-Path $payloadDir $manifest.payload.image_archive
  $payloadManifestPath = Join-Path $payloadDir 'manifest.json'

  if (-not (Test-Path $imageTarPath -PathType Leaf)) {
    throw "Expected payload archive missing: $imageTarPath"
  }

  if (-not (Test-Path $payloadManifestPath -PathType Leaf)) {
    throw "Expected payload manifest missing: $payloadManifestPath"
  }

  Write-Host "Loading images from $imageTarPath" -ForegroundColor Green
  & docker load -i $imageTarPath
  if ($LASTEXITCODE -ne 0) {
    throw "docker load failed."
  }

  Write-Host "Validating compose syntax: $ComposeFile" -ForegroundColor Green
  & docker compose -f $ComposeFile config *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "docker compose config failed."
  }

  $services = & docker compose -f $ComposeFile config --services 2>$null
  if ($LASTEXITCODE -eq 0 -and $services) {
    Write-Host "Compose services restored:" -ForegroundColor Green
    $services | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
      Write-Host "  - $_"
    }
  }

  foreach ($image in (Get-ComposeImages -ComposePath $ComposeFile)) {
    & docker image inspect $image *> $null
    if ($LASTEXITCODE -ne 0) {
      throw "Compose image is still missing after docker load: $image"
    }

    Write-Host "Image available locally: $image" -ForegroundColor Green
  }

  Write-Host "Import workflow completed successfully" -ForegroundColor Green
}
finally {
  if ($KeepWorkdir) {
    Write-Warning "Keeping extracted workspace at $workDir"
  } elseif (Test-Path $workDir) {
    Remove-Item -Recurse -Force $workDir
  }
}
