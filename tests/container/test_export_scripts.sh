#!/usr/bin/env bash
set -uo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Export scripts: files exist ==="
check_file "image-export.sh"
check_file "image-export.ps1"
check_file "cuda-prep.sh"
check_file "cuda-prep.ps1"

echo ""
echo "=== Export scripts: archive contract ==="
check_contains "bash export writes manifest.json" "image-export.sh" "manifest.json"
check_contains "bash export writes SHA256SUMS" "image-export.sh" "SHA256SUMS"
check_contains "bash export uses local dev image default" "image-export.sh" "dotfiles-dev-env:local"
check_contains "bash export uses local ollama image default" "image-export.sh" "ollama/ollama:0.20.3"
check_contains "powershell export writes manifest.json" "image-export.ps1" "manifest.json"
check_contains "powershell export writes SHA256SUMS" "image-export.ps1" "SHA256SUMS"

echo ""
echo "=== CUDA prep scripts: discovery contract ==="
check_contains "bash cuda prep documents GPU discovery" "cuda-prep.sh" "nvidia-smi --query-gpu=name --format=csv,noheader"
check_contains "bash cuda prep documents OS discovery" "cuda-prep.sh" "lsb_release -rs"
check_contains "powershell cuda prep documents GPU discovery" "cuda-prep.ps1" "nvidia-smi --query-gpu=name --format=csv,noheader"
check_contains "powershell cuda prep writes metadata" "cuda-prep.ps1" "metadata.json"

echo ""
echo "=== README: export workflow documented ==="
check_contains "README includes export workflow" "README.md" "Transport Archive Workflow"
check_contains "README documents image-export.sh" "README.md" "image-export.sh"
check_contains "README documents cuda-prep.sh" "README.md" "cuda-prep.sh"

summary
