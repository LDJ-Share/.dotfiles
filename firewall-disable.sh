#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
# firewall-disable.sh
#
# PURPOSE
#   Opens a maintenance window by disabling the VM's network isolation
#   firewall and optionally restoring sudo access to the dev account.
#
#   This script is the inverse of firewall-enable.sh. It should be run
#   whenever the VM needs to reach the internet — for example, to apply
#   system updates, pull new Ollama models into the VM, or re-run setup.sh.
#
# WHAT IT DOES
#   1. Prompts for explicit confirmation before making any changes.
#   2. Disables UFW (all network traffic is permitted again).
#   3. Optionally restores sudo access to the dev account so that setup.sh
#      and other maintenance tasks can be run.
#
# USAGE
#   sudo bash firewall-disable.sh [username]
#
#   username  The dev account to optionally restore sudo for.
#             Defaults to 'krawlz'.
#
# AFTER MAINTENANCE
#   Always re-apply isolation when the maintenance window is closed:
#     sudo bash firewall-enable.sh [username]
#
# REQUIREMENTS
#   - Must be run as root. Use the Hyper-V console or a separate admin account.
#   - The dev account must NOT be used to run this script — the entire point
#     of the firewall and account hardening is that the dev account (and any
#     AI agent running under it) cannot disable these controls.
# ═════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
DEV_USER="${1:-krawlz}"
SUDOERS_FILE="/etc/sudoers.d/99-restrict-dev"

# ── Color output ──────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
log()  { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }
err()  { echo -e "${RED}ERROR:${NC} $1" >&2; }

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  err "This script must be run as root."
  err "Use the Hyper-V console to log in as root, or switch to an admin account."
  exit 1
fi

# ── Validate dev user exists ──────────────────────────────────────────────────
if ! id "$DEV_USER" &>/dev/null; then
  err "User '$DEV_USER' does not exist."
  exit 1
fi

# ═════════════════════════════════════════════════════════════════════════════
# Confirmation prompt
#
# Disabling the firewall is a security-sensitive action. Require explicit
# typed confirmation to prevent accidental execution (e.g., if this script
# is run by mistake or as part of a misconfigured automated task).
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  WARNING — NETWORK ISOLATION WILL BE DISABLED                   ║${NC}"
echo -e "${RED}║                                                                  ║${NC}"
echo -e "${RED}║  The VM's firewall will be removed. Until firewall-enable.sh    ║${NC}"
echo -e "${RED}║  is run again, this VM will have unrestricted network access.   ║${NC}"
echo -e "${RED}║                                                                  ║${NC}"
echo -e "${RED}║  Intended use: maintenance windows only (updates, re-setup).    ║${NC}"
echo -e "${RED}║  Run firewall-enable.sh when maintenance is complete.           ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -r -p "Type CONFIRM to proceed: " response
if [ "$response" != "CONFIRM" ]; then
  echo "Aborted. No changes made."
  exit 0
fi

echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — Disable UFW
# ═════════════════════════════════════════════════════════════════════════════
log "Step 1/2 — Disabling UFW..."

if ufw status | grep -q "Status: active"; then
  ufw disable
  log "UFW disabled. All network traffic is now permitted."
else
  warn "UFW was already inactive. No change made."
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — Optionally restore sudo access to the dev account
#
# sudo access is needed to run setup.sh, apt-get, and other maintenance tasks.
# If the maintenance work does not require elevated privileges, leave sudo
# restricted for defense in depth.
# ═════════════════════════════════════════════════════════════════════════════
log "Step 2/2 — Dev account sudo access..."
echo ""
echo "  Does this maintenance window require running commands as sudo under the"
echo "  '$DEV_USER' account? (e.g., to re-run setup.sh or install packages)"
echo "  If you are only doing work that does not need sudo, answer 'no'."
echo ""
read -r -p "Restore sudo access for '$DEV_USER'? (yes/no): " restore

if [ "$restore" = "yes" ]; then
  # Remove the sudoers drop-in restriction
  if [ -f "$SUDOERS_FILE" ]; then
    rm -f "$SUDOERS_FILE"
    log "Removed sudoers restriction ($SUDOERS_FILE)."
  else
    warn "Sudoers restriction file not found (may already be removed)."
  fi

  # Re-add to sudo group
  if ! id -nG "$DEV_USER" | tr ' ' '\n' | grep -qx "sudo"; then
    usermod -aG sudo "$DEV_USER"
    log "$DEV_USER added back to the sudo group."
  else
    warn "$DEV_USER is already in the sudo group."
  fi

  echo ""
  warn "Sudo access has been restored for $DEV_USER."
  warn "The dev account can now run privileged commands."
else
  log "Sudo access for '$DEV_USER' remains restricted."
fi

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
warn "Maintenance window is open."
echo ""
echo "  Current state:"
echo "    [UFW]   Disabled — unrestricted network access"
if [ "$restore" = "yes" ]; then
echo "    [sudo]  RESTORED for $DEV_USER"
else
echo "    [sudo]  Still restricted for $DEV_USER"
fi
echo ""
warn "When maintenance is complete, restore isolation:"
warn "  sudo bash firewall-enable.sh ${DEV_USER}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
