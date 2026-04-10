#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

DEFAULT_OUTPUT_DIR=".airgap-artifacts/export"
DEFAULT_CUDA_DIR=".airgap-artifacts/cuda"
DEFAULT_BUNDLE_NAME="airgap-dev-env"
DEFAULT_IMAGES=("${DEV_ENV_IMAGE:-dotfiles-dev-env:local}" "${OLLAMA_IMAGE:-ollama/ollama:0.20.3}")

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
Usage: bash image-export.sh [options]

Create a single transport archive for the Phase 4 compose image set.

Options:
  --image <ref>         Add an image reference to export (repeatable)
  --output-dir <path>   Write archive, manifest.json, and SHA256SUMS here
  --cuda-dir <path>     Bundle prepared CUDA artifacts from this directory
  --bundle-name <name>  Archive prefix (default: airgap-dev-env)
  --help                Show this help text

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

json_bool() {
  if [[ "$1" == true ]]; then
    printf 'true'
  else
    printf 'false'
  fi
}

image_repo() {
  local image="$1"
  if [[ "$image" == *:* ]]; then
    printf '%s' "${image%%:*}"
  else
    printf '%s' "$image"
  fi
}

image_tag() {
  local image="$1"
  if [[ "$image" == *:* ]]; then
    printf '%s' "${image##*:}"
  else
    printf 'latest'
  fi
}

OUTPUT_DIR="$DEFAULT_OUTPUT_DIR"
CUDA_DIR="$DEFAULT_CUDA_DIR"
BUNDLE_NAME="$DEFAULT_BUNDLE_NAME"
declare -a IMAGES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGES+=("$2")
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --cuda-dir)
      CUDA_DIR="$2"
      shift 2
      ;;
    --bundle-name)
      BUNDLE_NAME="$2"
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

if [[ ${#IMAGES[@]} -eq 0 ]]; then
  IMAGES=("${DEFAULT_IMAGES[@]}")
fi

require_cmd docker
require_cmd tar
require_cmd sha256sum
require_cmd mktemp
require_cmd cp

if ! docker info >/dev/null 2>&1; then
  err "Docker is not available. Start Docker and retry."
  exit 1
fi

for image in "${IMAGES[@]}"; do
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    err "Required local image is missing: $image"
    exit 1
  fi
done

mkdir -p "$OUTPUT_DIR"
WORKDIR=$(mktemp -d)
PAYLOAD_DIR="$WORKDIR/$BUNDLE_NAME"
mkdir -p "$PAYLOAD_DIR"

ARCHIVE_PATH="$OUTPUT_DIR/$BUNDLE_NAME.tar.gz"
MANIFEST_PATH="$OUTPUT_DIR/$BUNDLE_NAME-manifest.json"
CHECKSUM_PATH="$OUTPUT_DIR/$BUNDLE_NAME-SHA256SUMS"

log "Saving compose images to $PAYLOAD_DIR/images.tar"
docker save -o "$PAYLOAD_DIR/images.tar" "${IMAGES[@]}"

CUDA_PRESENT=false
if [[ -d "$CUDA_DIR" ]]; then
  CUDA_PRESENT=true
  mkdir -p "$PAYLOAD_DIR/cuda"
  cp -R "$CUDA_DIR/." "$PAYLOAD_DIR/cuda/"
else
  warn "CUDA staging directory not found at $CUDA_DIR; exporting images only"
fi

GPU_PRESENT=false
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --list-gpus >/dev/null 2>&1; then
  GPU_PRESENT=true
fi

IMAGES_JSON=""
for image in "${IMAGES[@]}"; do
  digest=$(docker image inspect "$image" --format '{{join .RepoDigests ","}}' 2>/dev/null || true)
  image_id=$(docker image inspect "$image" --format '{{.Id}}')
  if [[ -n "$IMAGES_JSON" ]]; then
    IMAGES_JSON+=","
  fi
  IMAGES_JSON+="{\"reference\":\"$(json_escape "$image")\",\"repository\":\"$(json_escape "$(image_repo "$image")")\",\"tag\":\"$(json_escape "$(image_tag "$image")")\",\"digest\":\"$(json_escape "$digest")\",\"image_id\":\"$(json_escape "$image_id")\"}"
done

CUDA_FILES_JSON=""
if [[ "$CUDA_PRESENT" == true ]]; then
  while IFS= read -r file; do
    rel_path="${file#"$PAYLOAD_DIR/"}"
    checksum=$(sha256sum "$file" | cut -d' ' -f1)
    if [[ -n "$CUDA_FILES_JSON" ]]; then
      CUDA_FILES_JSON+=","
    fi
    CUDA_FILES_JSON+="{\"path\":\"$(json_escape "$rel_path")\",\"sha256\":\"$checksum\"}"
  done < <(find "$PAYLOAD_DIR/cuda" -type f -print 2>/dev/null)
fi

cat > "$PAYLOAD_DIR/manifest.json" <<EOF
{
  "bundle_name": "$(json_escape "$BUNDLE_NAME")",
  "archive_name": "$(json_escape "$(basename "$ARCHIVE_PATH")")",
  "created_at_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "images": [${IMAGES_JSON}],
  "gpu_present_on_export_host": $(json_bool "$GPU_PRESENT"),
  "cuda_bundle": {
    "included": $(json_bool "$CUDA_PRESENT"),
    "source_directory": "$(json_escape "$CUDA_DIR")",
    "files": [${CUDA_FILES_JSON}]
  },
  "payload": {
    "image_archive": "images.tar",
    "manifest": "manifest.json"
  }
}
EOF

tar -czf "$ARCHIVE_PATH" -C "$WORKDIR" "$BUNDLE_NAME"
cp "$PAYLOAD_DIR/manifest.json" "$MANIFEST_PATH"
sha256sum "$ARCHIVE_PATH" > "$CHECKSUM_PATH"

archive_sha=$(cut -d' ' -f1 "$CHECKSUM_PATH")
tmp_manifest="$WORKDIR/manifest-with-archive.json"
cat > "$tmp_manifest" <<EOF
{
  "bundle_name": "$(json_escape "$BUNDLE_NAME")",
  "archive_name": "$(json_escape "$(basename "$ARCHIVE_PATH")")",
  "archive_sha256": "$archive_sha",
  "created_at_utc": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "images": [${IMAGES_JSON}],
  "gpu_present_on_export_host": $(json_bool "$GPU_PRESENT"),
  "cuda_bundle": {
    "included": $(json_bool "$CUDA_PRESENT"),
    "source_directory": "$(json_escape "$CUDA_DIR")",
    "files": [${CUDA_FILES_JSON}]
  },
  "payload": {
    "image_archive": "images.tar",
    "manifest": "manifest.json"
  }
}
EOF
mv "$tmp_manifest" "$MANIFEST_PATH"

log "Created archive: $ARCHIVE_PATH"
log "Created manifest.json: $MANIFEST_PATH"
log "Created SHA256SUMS: $CHECKSUM_PATH"

rm -rf "$WORKDIR"
