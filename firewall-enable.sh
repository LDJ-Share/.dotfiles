#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
# firewall-enable.sh
#
# PURPOSE
#   Applies the VM's network isolation policy and hardens the dev account so
#   that neither the developer nor any AI agent running under that account can
#   disable or bypass the firewall.
#
# WHAT IT DOES
#   1. Installs and configures UFW with a default-deny policy.
#      The only permitted outbound connection is to the Ollama service on the
#      Hyper-V host (10.10.10.10:11434). All other inbound and outbound traffic
#      is blocked.
#
#   2. Removes the dev account from the 'sudo' group so that unprivileged
#      processes (including AI agents like Pi) cannot use 'sudo' to modify
#      firewall rules, install software, or otherwise escalate privileges.
#
#   3. Writes a sudoers drop-in (/etc/sudoers.d/99-restrict-dev) that denies
#      all sudo access for the dev account even if it is later re-added to the
#      sudo group. This is a belt-and-suspenders control.
#
# USAGE
#   sudo bash firewall-enable.sh [username]
#
#   username  The dev account to harden. Defaults to 'krawlz'.
#             This should be the account that runs Pi and day-to-day work.
#
# WHEN TO RUN
#   Run this as the final step before exporting the VM for air-gapped
#   deployment. The VM must have internet access during setup.sh, so do not
#   run this until all software installation is complete.
#
# TO UNDO
#   Run firewall-disable.sh as root. That script will disable UFW and
#   optionally restore sudo access to the dev account for maintenance.
#
# REQUIREMENTS
#   - Must be run as root (not via sudo from the dev account — use a separate
#     admin account or the Hyper-V console root session).
#   - The OllamaNet Hyper-V Internal Switch must be configured on the host
#     with the static IP 10.10.10.10 before this script is run.
# ═════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
# The account that runs Pi and development work. Sudo will be removed from
# this account to prevent AI-driven privilege escalation.
DEV_USER="${1:-krawlz}"

# The Hyper-V host IP and Ollama port. These must match the OllamaNet switch
# configuration on the Windows host. See README.md § "Windows Host Setup".
OLLAMA_HOST_IP="10.10.10.10"
OLLAMA_PORT="11434"

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
  err "Use the Hyper-V console to log in as root, or switch to an admin account:"
  err "  sudo bash firewall-enable.sh [username]"
  exit 1
fi

# ── Validate dev user exists ──────────────────────────────────────────────────
if ! id "$DEV_USER" &>/dev/null; then
  err "User '$DEV_USER' does not exist."
  err "Usage: sudo bash firewall-enable.sh [username]"
  exit 1
fi

echo ""
log "Applying firewall and account hardening for dev user: $DEV_USER"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — UFW installation and rule configuration
# ═════════════════════════════════════════════════════════════════════════════
log "Step 1/3 — Configuring UFW firewall..."

apt-get install -y -qq ufw 2>&1 | grep -v "^$" || true

# Reset to a guaranteed-clean state. --force suppresses the interactive prompt.
ufw --force reset

# Default policy: deny everything unless explicitly permitted.
# This applies to both inbound (external → VM) and outbound (VM → external).
ufw default deny incoming
ufw default deny outgoing

# Loopback traffic must always be permitted — many local services depend on it.
ufw allow in  on lo
ufw allow out on lo

# The only permitted outbound path: the Ollama API on the Hyper-V host.
# All AI inference traffic flows through this single, controlled channel.
ufw allow out to "${OLLAMA_HOST_IP}" port "${OLLAMA_PORT}" proto tcp

ufw --force enable

log "UFW active. Permitted traffic:"
log "  → Outbound: ${OLLAMA_HOST_IP}:${OLLAMA_PORT}/tcp  (Ollama on Hyper-V host)"
log "  ↔ Loopback: unrestricted"
log "  ✗ All other inbound and outbound: DENIED"
echo ""
ufw status verbose
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — Remove dev account from the 'sudo' group
#
# Without sudo group membership, the dev account cannot run any command as
# root. This prevents Pi or any other process running as the dev user from
# executing ufw, iptables, nft, systemctl, apt-get, or any other privileged
# command — regardless of what the AI is instructed to do.
# ═════════════════════════════════════════════════════════════════════════════
log "Step 2/3 — Removing $DEV_USER from the sudo group..."

if id -nG "$DEV_USER" | tr ' ' '\n' | grep -qx "sudo"; then
  gpasswd -d "$DEV_USER" sudo
  log "$DEV_USER removed from sudo group."
else
  warn "$DEV_USER was not in the sudo group (already restricted)."
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — Write a sudoers drop-in to deny all sudo for the dev account
#
# Removing the user from the sudo group is the primary control. This drop-in
# is a secondary, belt-and-suspenders measure. Even if the account is re-added
# to the sudo group (e.g., by another misconfigured script), this file will
# prevent any sudo execution by the dev account.
#
# The file is named 99-restrict-dev so it sorts last alphabetically and
# therefore takes precedence over any other sudoers entries that might grant
# access.
# ═════════════════════════════════════════════════════════════════════════════
log "Step 3/3 — Writing sudoers restriction for $DEV_USER..."

SUDOERS_FILE="/etc/sudoers.d/99-restrict-dev"

cat > "$SUDOERS_FILE" << EOF
# ─────────────────────────────────────────────────────────────────────────────
# Managed by firewall-enable.sh — do not edit manually.
#
# This file denies ALL sudo access for the dev account. It is a secondary
# control; the primary control is removing the account from the sudo group
# (Step 2 of firewall-enable.sh).
#
# Purpose: prevent AI agents (e.g., Pi) running under the dev account from
# gaining elevated privileges to modify firewall rules, install software, or
# otherwise alter the system's security configuration.
#
# To perform maintenance:
#   1. Log in as root via the Hyper-V console (or a separate admin account).
#   2. Run: bash firewall-disable.sh
#   3. The disable script will offer to restore sudo access for this account.
#   4. When maintenance is complete, run: bash firewall-enable.sh
# ─────────────────────────────────────────────────────────────────────────────
${DEV_USER} ALL=(ALL:ALL) !ALL
EOF

# Validate the file syntax before activating it (a broken sudoers file can
# lock out all sudo access on the system).
if ! visudo -cf "$SUDOERS_FILE"; then
  err "sudoers file validation failed. Removing $SUDOERS_FILE to avoid lockout."
  rm -f "$SUDOERS_FILE"
  exit 1
fi

chmod 440 "$SUDOERS_FILE"
log "Sudoers restriction written and validated: $SUDOERS_FILE"

# ═════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "Firewall enabled and dev account hardened."
echo ""
echo "  Security controls applied:"
echo "    [UFW]     Active — only ${OLLAMA_HOST_IP}:${OLLAMA_PORT}/tcp permitted outbound"
echo "    [sudo]    Removed $DEV_USER from sudo group"
echo "    [sudoers] $SUDOERS_FILE — denies all sudo for $DEV_USER"
echo ""
echo "  The VM is ready for air-gapped export."
echo ""
warn "To open a maintenance window, run as root:"
warn "  bash $(realpath "$0" 2>/dev/null || echo "firewall-disable.sh" | sed 's/enable/disable/')"
warn "  → or: bash firewall-disable.sh"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
