#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_COMPOSE_FILE="$SCRIPT_DIR/.devcontainer/docker-compose.yml"

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
Usage: bash image-import.sh [options] <bundle.tar.gz>

Verify a Phase 5 transport bundle, restore the compose images, and validate
the offline compose contract.

Options:
  --compose-file <path>  Compose file to validate (default: .devcontainer/docker-compose.yml)
  --keep-workdir         Do not delete the extracted temporary workspace
  --help                 Show this help text

Inputs:
  <bundle>.tar.gz
  <bundle>-manifest.json
  <bundle>-SHA256SUMS

Contract:
  1. Verify SHA256 before extraction or docker load
  2. Extract <bundle>/images.tar and load it with docker load
  3. Validate the compose stack with docker compose config
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Required command not found: $1"
    exit 1
  fi
}

json_field() {
  local file="$1"
  local expression="$2"
  node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); const value=${expression}; if (value === undefined || value === null) process.exit(1); if (typeof value === 'object') { process.stdout.write(JSON.stringify(value)); } else { process.stdout.write(String(value)); }" "$file"
}

run_elevated() {
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    "$@"
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  err "Elevated privileges are required to run: $*"
  exit 1
}

verify_cuda_checksums() {
  local cuda_dir="$1"
  local checksums="$cuda_dir/SHA256SUMS"

  if [[ ! -f "$checksums" ]]; then
    warn "CUDA payload is missing SHA256SUMS; skipping installer verification"
    return
  fi

  if [[ ! -s "$checksums" ]]; then
    warn "CUDA payload has no staged installer hashes; treating this as a metadata-only bundle"
    return
  fi

  log "Verifying CUDA payload checksums"
  (cd "$cuda_dir" && sha256sum -c "$(basename "$checksums")")
}

print_cuda_prep_guidance() {
  local metadata_file="$1"
  local gpu_model driver_version linux_os kernel_version windows_os

  gpu_model="$(json_field "$metadata_file" 'data.gpu_model')"
  driver_version="$(json_field "$metadata_file" 'data.driver_version')"
  linux_os="$(json_field "$metadata_file" 'data.linux_os')"
  kernel_version="$(json_field "$metadata_file" 'data.kernel_version')"
  windows_os="$(json_field "$metadata_file" 'data.windows_os')"

  warn "CUDA metadata.json is present but the required installers are missing. Re-run cuda-prep with the needed URLs on the connected staging machine."
  printf '  bash ./cuda-prep.sh --gpu-model %q --driver-version %q --linux-os %q --kernel-version %q --windows-os %q --linux-toolkit-url <url> --container-toolkit-url <url> --windows-driver-url <url>\n' \
    "$gpu_model" "$driver_version" "$linux_os" "$kernel_version" "$windows_os"
}

install_linux_artifact() {
  local label="$1"
  local path="$2"

  case "$path" in
    *.run)
      log "Running $label installer: $path"
      run_elevated sh "$path" --silent --toolkit
      ;;
    *.deb|*.pkg)
      log "Installing $label package: $path"
      run_elevated dpkg -i "$path"
      ;;
    *)
      warn "Unsupported Linux installer type for $label: $path"
      ;;
  esac
}

handle_cuda_payload() {
  local payload_dir="$1"
  local cuda_dir="$payload_dir/cuda"
  local metadata_file="$cuda_dir/metadata.json"
  local linux_toolkit="$cuda_dir/downloads/linux/cuda-toolkit.run"
  local container_toolkit="$cuda_dir/downloads/linux/nvidia-container-toolkit.pkg"
  local windows_driver="$cuda_dir/downloads/windows/nvidia-driver.exe"
  local installed_any=false

  if [[ ! -d "$cuda_dir" ]]; then
    log "No CUDA payload bundled; CPU-only import remains valid"
    return
  fi

  if [[ ! -f "$metadata_file" ]]; then
    warn "CUDA payload found without metadata.json; skipping installer execution"
    return
  fi

  verify_cuda_checksums "$cuda_dir"

  if [[ -f "$linux_toolkit" ]]; then
    install_linux_artifact "Linux CUDA toolkit" "$linux_toolkit"
    installed_any=true
  fi

  if [[ -f "$container_toolkit" ]]; then
    install_linux_artifact "NVIDIA container toolkit" "$container_toolkit"
    installed_any=true
  fi

  if [[ -f "$windows_driver" ]]; then
    warn "Windows NVIDIA driver installer is bundled at $windows_driver. Run it from the Windows host with image-import.ps1 if needed."
  fi

  if [[ "$installed_any" == false ]]; then
    print_cuda_prep_guidance "$metadata_file"
  fi
}

check_loaded_images() {
  local compose_file="$1"
  local images

  images=$(docker compose -f "$compose_file" config --images 2>/dev/null || true)
  if [[ -z "$images" ]]; then
    warn "Unable to enumerate compose images with 'docker compose config --images'; compose syntax still validated"
    return
  fi

  while IFS= read -r image; do
    [[ -z "$image" ]] && continue
    if docker image inspect "$image" >/dev/null 2>&1; then
      log "Image available locally: $image"
    else
      err "Compose image is still missing after docker load: $image"
      exit 1
    fi
  done <<< "$images"
}

COMPOSE_FILE="$DEFAULT_COMPOSE_FILE"
KEEP_WORKDIR=false
POSITIONAL_BUNDLE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compose-file)
      COMPOSE_FILE="$2"
      shift 2
      ;;
    --keep-workdir)
      KEEP_WORKDIR=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      err "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -n "$POSITIONAL_BUNDLE" ]]; then
        err "Only one bundle path is supported"
        exit 1
      fi
      POSITIONAL_BUNDLE="$1"
      shift
      ;;
  esac
done

if [[ -z "$POSITIONAL_BUNDLE" ]]; then
  err "Bundle path is required"
  usage
  exit 1
fi

require_cmd docker
require_cmd tar
require_cmd sha256sum
require_cmd mktemp
require_cmd node

BUNDLE_PATH="$POSITIONAL_BUNDLE"
if [[ ! -f "$BUNDLE_PATH" ]]; then
  err "Bundle archive not found: $BUNDLE_PATH"
  exit 1
fi

if [[ ! -f "$COMPOSE_FILE" ]]; then
  err "Compose file not found: $COMPOSE_FILE"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  err "Docker is not available. Start Docker and retry."
  exit 1
fi

BUNDLE_DIR="$(cd "$(dirname "$BUNDLE_PATH")" && pwd)"
BUNDLE_FILE="$(basename "$BUNDLE_PATH")"
BUNDLE_STEM="${BUNDLE_FILE%.tar.gz}"
MANIFEST_PATH="$BUNDLE_DIR/$BUNDLE_STEM-manifest.json"
CHECKSUM_PATH="$BUNDLE_DIR/$BUNDLE_STEM-SHA256SUMS"

if [[ ! -f "$MANIFEST_PATH" ]]; then
  err "Sibling manifest not found: $MANIFEST_PATH"
  exit 1
fi

if [[ ! -f "$CHECKSUM_PATH" ]]; then
  err "Sibling SHA256SUMS not found: $CHECKSUM_PATH"
  exit 1
fi

MANIFEST_ARCHIVE_NAME="$(json_field "$MANIFEST_PATH" 'data.archive_name')"
MANIFEST_BUNDLE_NAME="$(json_field "$MANIFEST_PATH" 'data.bundle_name')"
PAYLOAD_IMAGE_ARCHIVE="$(json_field "$MANIFEST_PATH" 'data.payload.image_archive')"

if [[ "$MANIFEST_ARCHIVE_NAME" != "$BUNDLE_FILE" ]]; then
  err "Manifest archive_name '$MANIFEST_ARCHIVE_NAME' does not match '$BUNDLE_FILE'"
  exit 1
fi

log "Verifying SHA256 before extraction"
(cd "$BUNDLE_DIR" && sha256sum -c "$(basename "$CHECKSUM_PATH")")

MANIFEST_ARCHIVE_SHA="$(json_field "$MANIFEST_PATH" 'data.archive_sha256')"
ACTUAL_ARCHIVE_SHA="$(sha256sum "$BUNDLE_PATH" | cut -d' ' -f1)"
if [[ "$MANIFEST_ARCHIVE_SHA" != "$ACTUAL_ARCHIVE_SHA" ]]; then
  err "Manifest archive_sha256 does not match the actual archive checksum"
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() {
  if [[ "$KEEP_WORKDIR" == true ]]; then
    warn "Keeping extracted workspace at $WORKDIR"
  else
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

log "Extracting bundle to $WORKDIR"
tar -xzf "$BUNDLE_PATH" -C "$WORKDIR"

PAYLOAD_DIR="$WORKDIR/$MANIFEST_BUNDLE_NAME"
IMAGE_TAR_PATH="$PAYLOAD_DIR/$PAYLOAD_IMAGE_ARCHIVE"
PAYLOAD_MANIFEST_PATH="$PAYLOAD_DIR/manifest.json"

if [[ ! -f "$IMAGE_TAR_PATH" ]]; then
  err "Expected payload archive missing: $IMAGE_TAR_PATH"
  exit 1
fi

if [[ ! -f "$PAYLOAD_MANIFEST_PATH" ]]; then
  err "Expected payload manifest missing: $PAYLOAD_MANIFEST_PATH"
  exit 1
fi

log "Loading images from $IMAGE_TAR_PATH"
docker load -i "$IMAGE_TAR_PATH"

log "Validating compose syntax: $COMPOSE_FILE"
docker compose -f "$COMPOSE_FILE" config >/dev/null

SERVICES="$(docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null || true)"
if [[ -n "$SERVICES" ]]; then
  log "Compose services restored:"
  while IFS= read -r service; do
    [[ -z "$service" ]] && continue
    printf '  - %s\n' "$service"
  done <<< "$SERVICES"
fi

check_loaded_images "$COMPOSE_FILE"

handle_cuda_payload "$PAYLOAD_DIR"

log "Import workflow completed successfully"
