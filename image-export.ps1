param(
  [string[]]$Image = @(),
  [string]$OutputDir = ".airgap-artifacts/export",
  [string]$CudaDir = ".airgap-artifacts/cuda",
  [string]$BundleName = "airgap-dev-env",
  [switch]$Help
)

$DefaultImages = @(
  $(if ($env:DEV_ENV_IMAGE) { $env:DEV_ENV_IMAGE } else { "dotfiles-dev-env:local" }),
  $(if ($env:OLLAMA_IMAGE) { $env:OLLAMA_IMAGE } else { "ollama/ollama:0.20.3" })
)

function Show-Usage {
  @"
Usage: pwsh -File .\image-export.ps1 [options]

Create a single transport archive for the Phase 4 compose image set.

Parameters:
  -Image <ref[]>       Add image references to export
  -OutputDir <path>    Write archive, manifest.json, and SHA256SUMS here
  -CudaDir <path>      Bundle prepared CUDA artifacts from this directory
  -BundleName <name>   Archive prefix (default: airgap-dev-env)
  -Help                Show this help text

Defaults:
  Images: dotfiles-dev-env:local, ollama/ollama:0.20.3
  Output: .airgap-artifacts/export
  CUDA:   .airgap-artifacts/cuda

Outputs:
  <bundle-name>.tar.gz
  <bundle-name>-manifest.json
  <bundle-name>-SHA256SUMS

Archive contents:
  <bundle-name>/images.tar
  <bundle-name>/manifest.json
  <bundle-name>/cuda/ (when cuda-prep artifacts exist)
"@
}

if ($Help) {
  Show-Usage
  exit 0
}

if (-not $Image -or $Image.Count -eq 0) {
  $Image = $DefaultImages
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw "Docker is not installed or not on PATH."
}

$dockerInfo = & docker info 2>$null
if ($LASTEXITCODE -ne 0) {
  throw "Docker is not available. Start Docker and retry."
}

foreach ($item in $Image) {
  & docker image inspect $item *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Required local image is missing: $item"
  }
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$payloadDir = Join-Path $workDir $BundleName
New-Item -ItemType Directory -Force -Path $payloadDir | Out-Null

$archivePath = Join-Path $OutputDir "$BundleName.tar.gz"
$manifestPath = Join-Path $OutputDir "$BundleName-manifest.json"
$checksumPath = Join-Path $OutputDir "$BundleName-SHA256SUMS"
$imageTarPath = Join-Path $payloadDir "images.tar"

Write-Host "Saving compose images to $imageTarPath" -ForegroundColor Green
& docker save @Image -o $imageTarPath
if ($LASTEXITCODE -ne 0) {
  throw "docker save failed."
}

$cudaPresent = Test-Path $CudaDir -PathType Container
if ($cudaPresent) {
  $payloadCudaDir = Join-Path $payloadDir "cuda"
  New-Item -ItemType Directory -Force -Path $payloadCudaDir | Out-Null
  Copy-Item -Recurse -Force (Join-Path $CudaDir '*') $payloadCudaDir -ErrorAction SilentlyContinue
} else {
  Write-Warning "CUDA staging directory not found at $CudaDir; exporting images only"
}

$gpuPresent = $false
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
  & nvidia-smi --list-gpus *> $null
  if ($LASTEXITCODE -eq 0) {
    $gpuPresent = $true
  }
}

$imageMetadata = foreach ($item in $Image) {
  $inspect = (& docker image inspect $item | ConvertFrom-Json)[0]
  $repo, $tag = if ($item.Contains(':')) { $item.Split(':', 2) } else { @($item, 'latest') }
  [ordered]@{
    reference = $item
    repository = $repo
    tag = $tag
    digest = (($inspect.RepoDigests ?? @()) -join ',')
    image_id = $inspect.Id
  }
}

$cudaFiles = @()
if ($cudaPresent) {
  $payloadCudaDir = Join-Path $payloadDir "cuda"
  if (Test-Path $payloadCudaDir) {
    Get-ChildItem -File -Recurse $payloadCudaDir | ForEach-Object {
      $relative = $_.FullName.Substring($payloadDir.Length + 1).Replace('\\', '/')
      $cudaFiles += [ordered]@{
        path = $relative
        sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      }
    }
  }
}

$payloadManifest = [ordered]@{
  bundle_name = $BundleName
  archive_name = [System.IO.Path]::GetFileName($archivePath)
  created_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  images = $imageMetadata
  gpu_present_on_export_host = $gpuPresent
  cuda_bundle = [ordered]@{
    included = $cudaPresent
    source_directory = $CudaDir
    files = $cudaFiles
  }
  payload = [ordered]@{
    image_archive = 'images.tar'
    manifest = 'manifest.json'
  }
}

$payloadManifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $payloadDir 'manifest.json') -Encoding utf8

tar -czf $archivePath -C $workDir $BundleName
Copy-Item -Force (Join-Path $payloadDir 'manifest.json') $manifestPath

$archiveHash = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -Path $checksumPath -Value "$archiveHash  $([System.IO.Path]::GetFileName($archivePath))" -Encoding utf8

$manifestWithArchive = [ordered]@{
  bundle_name = $BundleName
  archive_name = [System.IO.Path]::GetFileName($archivePath)
  archive_sha256 = $archiveHash
  created_at_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  images = $imageMetadata
  gpu_present_on_export_host = $gpuPresent
  cuda_bundle = [ordered]@{
    included = $cudaPresent
    source_directory = $CudaDir
    files = $cudaFiles
  }
  payload = [ordered]@{
    image_archive = 'images.tar'
    manifest = 'manifest.json'
  }
}

$manifestWithArchive | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding utf8

Write-Host "Created archive: $archivePath" -ForegroundColor Green
Write-Host "Created manifest.json: $manifestPath" -ForegroundColor Green
Write-Host "Created SHA256SUMS: $checksumPath" -ForegroundColor Green

Remove-Item -Recurse -Force $workDir
