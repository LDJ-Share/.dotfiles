param(
  [string]$GpuModel,
  [string]$DriverVersion,
  [string]$LinuxOs,
  [string]$KernelVersion = "",
  [string]$WindowsOs = "Windows 11",
  [string]$CudaVersion = "12.8.0",
  [string]$LinuxToolkitUrl = "",
  [string]$ContainerToolkitUrl = "",
  [string]$WindowsDriverUrl = "",
  [string]$OutputDir = ".airgap-artifacts/cuda",
  [switch]$Help
)

function Show-Usage {
  @"
Usage: pwsh -File .\cuda-prep.ps1 -GpuModel <name> -DriverVersion <version> -LinuxOs <name> [options]

Stage CUDA-related artifacts in a predictable directory for image-export.ps1.

Offline-machine discovery commands to run before using this script:
  nvidia-smi --query-gpu=name --format=csv,noheader
  nvidia-smi --query-gpu=driver_version --format=csv,noheader
  uname -r
  lsb_release -rs
"@
}

if ($Help) {
  Show-Usage
  exit 0
}

if (-not $GpuModel -or -not $DriverVersion -or -not $LinuxOs) {
  throw "GpuModel, DriverVersion, and LinuxOs are required."
}

New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir 'downloads/linux') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir 'downloads/windows') | Out-Null

@"
Run these commands on the offline machine before preparing CUDA artifacts:

GPU model:
  nvidia-smi --query-gpu=name --format=csv,noheader

Driver version:
  nvidia-smi --query-gpu=driver_version --format=csv,noheader

Kernel version:
  uname -r

OS release:
  lsb_release -rs
"@ | Set-Content -Path (Join-Path $OutputDir 'OFFLINE-DISCOVERY.txt') -Encoding utf8

function Get-Artifact {
  param(
    [string]$Label,
    [string]$Url,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Url)) {
    Write-Warning "No URL supplied for $Label; metadata will record the missing artifact"
    return
  }

  Write-Host "Downloading $Label" -ForegroundColor Green
  Invoke-WebRequest -Uri $Url -OutFile $Path
}

Get-Artifact -Label 'Linux CUDA toolkit' -Url $LinuxToolkitUrl -Path (Join-Path $OutputDir 'downloads/linux/cuda-toolkit.run')
Get-Artifact -Label 'NVIDIA container toolkit' -Url $ContainerToolkitUrl -Path (Join-Path $OutputDir 'downloads/linux/nvidia-container-toolkit.pkg')
Get-Artifact -Label 'Windows NVIDIA driver' -Url $WindowsDriverUrl -Path (Join-Path $OutputDir 'downloads/windows/nvidia-driver.exe')

$metadata = [ordered]@{
  gpu_model = $GpuModel
  driver_version = $DriverVersion
  linux_os = $LinuxOs
  kernel_version = $KernelVersion
  windows_os = $WindowsOs
  cuda_version = $CudaVersion
  downloads = [ordered]@{
    linux_toolkit_url = $LinuxToolkitUrl
    container_toolkit_url = $ContainerToolkitUrl
    windows_driver_url = $WindowsDriverUrl
  }
}

$metadata | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $OutputDir 'metadata.json') -Encoding utf8

$hashLines = @()
Get-ChildItem -File -Recurse (Join-Path $OutputDir 'downloads') -ErrorAction SilentlyContinue | ForEach-Object {
  $relative = $_.FullName.Substring($OutputDir.Length + 1).Replace('\\', '/')
  $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  $hashLines += "$hash  $relative"
}

if ($hashLines.Count -eq 0) {
  Set-Content -Path (Join-Path $OutputDir 'SHA256SUMS') -Value '' -Encoding utf8
} else {
  $normalized = foreach ($line in $hashLines) {
    $parts = $line.Split(' ', 2)
    "$(($parts[0]).ToLowerInvariant())  $($parts[1].Trim())"
  }
  Set-Content -Path (Join-Path $OutputDir 'SHA256SUMS') -Value $normalized -Encoding utf8
}

Write-Host "Prepared CUDA staging directory: $OutputDir" -ForegroundColor Green
Write-Host "Bundle this directory with image-export.ps1 using -CudaDir $OutputDir" -ForegroundColor Green
