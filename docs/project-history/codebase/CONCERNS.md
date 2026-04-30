# Concerns & Technical Debt

## Security Concerns

### 1. Hardcoded Username Default (krawlz)
Location: firewall-enable.sh (line 53), firewall-disable.sh (line 39), setup.sh (line 35)

The scripts default to hardcoded username krawlz instead of requiring explicit input. While parameters are passable via arguments, the default is brittle for users with different dev account names.

Risk: Low-to-medium. The scripts validate the user exists before proceeding, but mismatches could leave a system in an inconsistent state.

Recommendation: Require explicit username parameter or detect the current non-root user automatically.

---

### 2. Sudo Access in Container (Dockerfile Line 120)
Location: Dockerfile, line 120

The container's dev user (UID 1000) is granted passwordless sudo for all commands. This is intentional for development but creates a gap: any process can escalate to root without a password.

Context: The firewall rules and account hardening (UFW + sudoers restrictions) live on the VM host, not inside the container. A compromised container cannot modify the host's firewall. However, within the container itself, an AI agent could theoretically misuse sudo to install tools or modify local files.

Risk: Medium. Contained by Hyper-V isolation and UFW on the host, but not ideal for an AI-assisted environment.

Recommendation: Document this trade-off explicitly. Consider running container as unprivileged user in production.

---

### 3. Windows Firewall Rule Is IP + Port Only
Location: README.md Windows Host Setup, step 2

The Windows Firewall rule for Ollama is scoped by local address (10.10.10.10) and port (11434), but there are no per-query rate limits, connection logging, or time-based revocation.

Risk: Low. Ollama is bound to a private IP with no external connectivity. However, full request visibility to Ollama exists.

Recommendation: Document that Ollama logs should be monitored. Consider adding iptables logging to UFW rules for observability.

## Reliability Concerns

### 1. Container Image Pull Fails Silently on Network Errors
Location: setup.sh, module_container (line 163)

No error handling. If the pull fails (network timeout, GHCR unavailable, auth issues), the error is printed but the script continues. Users may not realize the container didn't pull, and later attempts to run docker run will fail.

Risk: Medium. Users may proceed past setup.sh without realizing the critical step failed.

Recommendation: Add explicit error check to exit on pull failure.

---

### 2. Sudo Keepalive Loop May Fail Silently
Location: setup.sh, lines 93-98

This background loop renews sudo credentials every 60 seconds. The loop suppresses all output, making it invisible if it fails. If the loop exits, setup.sh will silently continue and later sudo commands will fail mid-script.

Risk: Medium. If the keepalive fails, sudo will prompt interactively, causing the script to hang or fail.

Recommendation: Add exit code checking or explicit logging.

---

### 3. Dockerfile Pre-Initialization Uses pipes to Silence Errors
Location: Dockerfile, lines 119-137

If Neovim lazy.nvim sync fails, if Pi fails to initialize, or if opencode fails, the error is suppressed and the build continues. The image will appear to build successfully but may be partially initialized.

Risk: Medium-to-high. The test suite will catch missing plugins/LSPs, but silent failures in initialization make debugging harder.

Recommendation: Log errors or change to conditional logic that fails the build on critical errors.

## Maintainability Concerns

### 1. Hardcoded IP Address (10.10.10.10) Appears in 6 Files
Locations: firewall-enable.sh, dot-pi/models.json, dot-opencode/config.json, setup.sh, README.md (multiple)

If the OllamaNet switch needs to change to a different IP, the configuration is scattered across multiple files and documentation. No central config file or environment variable.

Risk: Medium. Changing the architecture would require coordinating updates across many files, with high risk of omission.

Recommendation: Introduce a config.sh or .env file that is sourced by all scripts and stowed into the container.

---

### 2. Default Username Mismatch Between Scripts
Locations: setup.sh (krawlz), Dockerfile (dev), README.md (mixed)

setup.sh defaults to krawlz, but the Dockerfile creates a user named dev. The container runs as dev (UID 1000), but the VM firewall is hardened for krawlz by default.

Risk: Low. The scripts validate the username exists and are documented to accept parameters.

Recommendation: Standardize on one default username across all scripts.

---

### 3. Test Coverage Gaps
Locations: tests/container/

The test suite covers:
  - Binaries exist and are executable
  - Neovim plugins and LSP servers installed
  - Pi and opencode configuration files
  - Config URLs point to 10.10.10.10
  - tmux plugins installed

NOT covered:
  - Actual network connectivity test
  - Pi/opencode can actually reach Ollama
  - Docker image runs without errors
  - Firewall-enable.sh produces expected UFW rules
  - setup.sh is idempotent
  - Container can mount volumes without permission errors
  - SSH access from Windows host works

Risk: Medium. A build could pass all tests but fail when deployed.

Recommendation: Add integration tests that verify Ollama connectivity.

---

### 4. No Version Pinning for Installer Scripts
Locations: Dockerfile, setup.sh, PLAN-container.md

Many installer commands use loose versions (latest releases). If a new version has a breaking change, builds will silently break.

Risk: Medium. Builds are reproducible within a GitHub Actions run, but re-running a month later may pull incompatible versions.

Recommendation: Pin versions explicitly and document in a VERSION or LOCK file.

## Known TODOs and Gaps

From TODO.md:

  - Infrastructure: Configure Windows host with OllamaNet, static IP, firewall rules
  - VM Setup: Attach OllamaNet, assign static IP, pull container
  - End-to-end test: Verify Pi can send prompts to Ollama and receive responses
  - Pre-export hardening: Run firewall-enable.sh, verify UFW rules

Note: Phase 0 TODO about fixing dot-opencode/config.json baseURL is already resolved.

---

## Portability Concerns

### 1. Hyper-V Internal Switch Assumption
Locations: README.md Architecture, Windows Host Setup

The entire design assumes Hyper-V on Windows. The setup is NOT portable to VirtualBox, KVM/Qemu on Linux, Docker Desktop on macOS, or Bare-metal Linux.

Risk: Low for intended use case, but blocks reuse on other platforms.

Recommendation: Document this as a hard requirement.

---

### 2. Windows-Specific Paths and Firewall Commands
Locations: README.md Windows Host Setup

Setup includes PowerShell-specific commands (New-VMSwitch, New-NetFirewallRule). These cannot run on Linux or macOS.

Risk: Low. The project is explicitly Windows + Linux (VM).

Recommendation: Document Windows + Hyper-V as a hard requirement.

---

### 3. Dockerfile Ubuntu-Specific Commands
Locations: Dockerfile

Uses apt-get, dpkg keyrings, and Ubuntu package repositories. Not portable to Alpine, CentOS, or other distributions.

Risk: Low. Container is explicitly Ubuntu 24.04 LTS.

Recommendation: Document Ubuntu 24.04 as the base OS.

---

### 4. Hardcoded File Paths and Assumptions
Locations: setup.sh, firewall-enable.sh, Dockerfile

Examples: HOME/.dotfiles, ~/.tmux/plugins/tpm/, /etc/sudoers.d/99-restrict-dev, /usr/local/bin/fd symlink

If a user installs dotfiles to a non-standard location or has read-only system directories, some setup steps will fail.

Risk: Low-to-medium.

Recommendation: Add guards for symlink creation, allow overriding dotfiles path.

## Performance Concerns

### 1. Dockerfile Size Not Documented
Locations: Dockerfile

No indication of final image size. Could be 2+ GB.

Risk: Low-to-medium. Corporate environments may have bandwidth constraints.

Recommendation: Document expected image size in README.

---

### 2. Neovim Lazy.nvim Full Sync in Docker Build
Location: Dockerfile, line 119

Downloading and compiling 50+ plugins during build adds 2-5 minutes.

Risk: Low. Build time is acceptable for one-time CI.

Recommendation: Document build time expectations.

---

### 3. Mason LSP Install in Docker Build
Location: Dockerfile, line 121

Downloading and compiling 8 LSP servers during build adds significant time.

Risk: Low. Acceptable for one-time CI build.

Recommendation: Document build time expectations.

---

## Summary of Critical Issues

| Concern | Severity | Impact |
|---------|----------|--------|
| Container pull fails silently in setup.sh | HIGH | Deployment will fail without clear error message |
| Test coverage missing network connectivity | HIGH | May deploy with broken Ollama access |
| Hardcoded IP (10.10.10.10) in 6 files | MEDIUM | Architecture changes require coordinating updates |
| Dockerfile errors silenced with pipes | MEDIUM | Partially initialized images pass tests |
| Sudo keepalive loop may fail silently | MEDIUM | setup.sh may hang or fail mid-execution |
| No version pinning for tools | MEDIUM | Builds may break with incompatible updates |
| Hardcoded username defaults mismatch | LOW | User confusion; mismatch between VM and container |
| Windows Firewall scoped to IP only | LOW | Contained by architecture, no request logging |

---

## Top Priority Actions

1. IMMEDIATE: Add error handling to module_container pull
2. IMMEDIATE: Add integration test for Ollama connectivity
3. SOON: Extract hardcoded IP to a central config file
4. SOON: Standardize username across scripts
5. SOON: Remove error suppression from critical Dockerfile steps
6. SOON: Add exit code check to sudo keepalive loop
7. LATER: Pin tool versions explicitly
8. DOCS: Clarify Windows + Hyper-V + Ubuntu 24.04 requirement
9. DOCS: Document expected Docker image size and build time
