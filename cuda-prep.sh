#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DEFAULT_OUTPUT_DIR=".airgap-artifacts/cuda"
DEFAULT_CUDA_VERSION="12.8.0"

log() {
  printf "%b%s%b\n" "$GREEN" "$1" "$NC"
}

warn() {
  printf "%b%s%b\n" "$YELLOW" "$1" "$NC"
}

err() {
  printf "%b%s%b\n" "$RED" "$1" "$NC" >&2
}

usage() {
  cat <<'EOF'
Usage: bash cuda-prep.sh [options]

Stage CUDA-related artifacts in a predictable directory for image-export.sh.

Required:
  --gpu-model <name>
  --driver-version <version>
  --linux-os <name>

Optional:
  --kernel-version <version>
  --windows-os <name>
  --cuda-version <version>
  --linux-toolkit-url <url>
  --container-toolkit-url <url>
  --windows-driver-url <url>
  --output-dir <path>
  --help

Default output:
  .airgap-artifacts/cuda

Offline-machine discovery commands to run before using this script:
  nvidia-smi --query-gpu=name --format=csv,noheader
  nvidia-smi --query-gpu=driver_version --format=csv,noheader
  uname -r
  lsb_release -rs
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    exit 1
  fi
}

json_escape() {
  local value="${1//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

download_if_set() {
  local label="$1"
  local url="$2"
  local destination="$3"

  if [[ -z "$url" ]]; then
    warn "No URL supplied for $label; metadata will record the missing artifact"
    return
  fi

  log "Downloading $label"
  curl -fsSL "$url" -o "$destination"
}

GPU_MODEL=""
DRIVER_VERSION=""
LINUX_OS=""
KERNEL_VERSION=""
WINDOWS_OS="Windows 11"
CUDA_VERSION="$DEFAULT_CUDA_VERSION"
LINUX_TOOLKIT_URL=""
CONTAINER_TOOLKIT_URL=""
WINDOWS_DRIVER_URL=""
OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gpu-model)
      GPU_MODEL="$2"
      shift 2
      ;;
    --driver-version)
      DRIVER_VERSION="$2"
      shift 2
      ;;
    --linux-os)
      LINUX_OS="$2"
      shift 2
      ;;
    --kernel-version)
      KERNEL_VERSION="$2"
      shift 2
      ;;
    --windows-os)
      WINDOWS_OS="$2"
      shift 2
      ;;
    --cuda-version)
      CUDA_VERSION="$2"
      shift 2
      ;;
    --linux-toolkit-url)
      LINUX_TOOLKIT_URL="$2"
      shift 2
      ;;
    --container-toolkit-url)
      CONTAINER_TOOLKIT_URL="$2"
      shift 2
      ;;
    --windows-driver-url)
      WINDOWS_DRIVER_URL="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$GPU_MODEL" || -z "$DRIVER_VERSION" || -z "$LINUX_OS" ]]; then
  err "--gpu-model, --driver-version, and --linux-os are required"
  usage
  exit 1
fi

require_cmd curl
require_cmd sha256sum

mkdir -p "$OUTPUT_DIR/downloads/linux" "$OUTPUT_DIR/downloads/windows"

cat > "$OUTPUT_DIR/OFFLINE-DISCOVERY.txt" <<'EOF'
Run these commands on the offline machine before preparing CUDA artifacts:

GPU model:
  nvidia-smi --query-gpu=name --format=csv,noheader

Driver version:
  nvidia-smi --query-gpu=driver_version --format=csv,noheader

Kernel version:
  uname -r

OS release:
  lsb_release -rs
EOF

download_if_set "Linux CUDA toolkit" "$LINUX_TOOLKIT_URL" "$OUTPUT_DIR/downloads/linux/cuda-toolkit.run"
download_if_set "NVIDIA container toolkit" "$CONTAINER_TOOLKIT_URL" "$OUTPUT_DIR/downloads/linux/nvidia-container-toolkit.pkg"
download_if_set "Windows NVIDIA driver" "$WINDOWS_DRIVER_URL" "$OUTPUT_DIR/downloads/windows/nvidia-driver.exe"

cat > "$OUTPUT_DIR/metadata.json" <<EOF
{
  "gpu_model": "$(json_escape "$GPU_MODEL")",
  "driver_version": "$(json_escape "$DRIVER_VERSION")",
  "linux_os": "$(json_escape "$LINUX_OS")",
  "kernel_version": "$(json_escape "$KERNEL_VERSION")",
  "windows_os": "$(json_escape "$WINDOWS_OS")",
  "cuda_version": "$(json_escape "$CUDA_VERSION")",
  "downloads": {
    "linux_toolkit_url": "$(json_escape "$LINUX_TOOLKIT_URL")",
    "container_toolkit_url": "$(json_escape "$CONTAINER_TOOLKIT_URL")",
    "windows_driver_url": "$(json_escape "$WINDOWS_DRIVER_URL")"
  }
}
EOF

(
  cd "$OUTPUT_DIR"
  if compgen -G "downloads/linux/*" >/dev/null || compgen -G "downloads/windows/*" >/dev/null; then
    find downloads -type f -print0 | xargs -0 sha256sum > SHA256SUMS
  else
    : > SHA256SUMS
  fi
)

log "Prepared CUDA staging directory: $OUTPUT_DIR"
log "Bundle this directory with image-export.sh using --cuda-dir $OUTPUT_DIR"
