#!/usr/bin/env bash
set -uo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Import scripts: files exist ==="
check_file "image-import.sh"
check_file "image-import.ps1"

echo ""
echo "=== Import scripts: help output ==="
check "bash import help mentions docker load" bash -lc 'bash ./image-import.sh --help | grep -q "docker load"'
check "bash import help mentions SHA256" bash -lc 'bash ./image-import.sh --help | grep -q "SHA256"'

echo ""
echo "=== Import scripts: contract ==="
check_contains "bash import verifies SHA256SUMS" "image-import.sh" "SHA256SUMS"
check_contains "bash import loads images" "image-import.sh" "docker load"
check_contains "bash import validates compose" "image-import.sh" "docker compose"
check_contains "powershell import verifies SHA256SUMS" "image-import.ps1" "SHA256SUMS"
check_contains "powershell import loads images" "image-import.ps1" "docker load"
check_contains "powershell import validates compose" "image-import.ps1" "docker compose"

echo ""
echo "=== README: import workflow documented ==="
check_contains "README includes import step" "README.md" "image-import.sh"
check_contains "README mentions compose validation" "README.md" "docker compose config"

summary
