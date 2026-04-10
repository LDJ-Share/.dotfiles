# Air-Gapped Local AI Development Environment

This repository contains the dotfiles and automated setup script for a
secure, self-contained AI-assisted development environment. The environment
is designed to run entirely on a single machine with no external network
dependencies once deployed.

---

## Table of Contents

1. [For Business Leaders](#for-business-leaders)
2. [Architecture Overview](#architecture-overview)
3. [Security Design](#security-design)
4. [Windows Host Setup](#windows-host-setup)
5. [Corporate Environment Setup](#corporate-environment-setup)
6. [VM Setup](#vm-setup)
7. [Firewall and Account Hardening](#firewall-and-account-hardening)
8. [Pre-Export Checklist](#pre-export-checklist)
9. [Deploying to an Air-Gapped Machine](#deploying-to-an-air-gapped-machine)
10. [Maintenance](#maintenance)
11. [VM Operations Reference](#vm-operations-reference)

---

## For Business Leaders

### What This Is

This environment provides an AI coding assistant that runs **entirely on your
own hardware**, with no data leaving the machine. Developers get the
productivity benefits of AI-assisted coding — code suggestions, explanations,
refactoring help — while the organization retains full control over what data
the AI can access.

### Why It Matters

| Concern | How This Addresses It |
|---|---|
| **Data confidentiality** | All AI inference runs locally. Source code, queries, and responses never leave the machine or the local network. |
| **Air-gap compatibility** | The environment is fully operational with no internet connection, making it suitable for classified, regulated, or otherwise restricted networks. |
| **No cloud subscription required** | The AI models run on commodity hardware you already own. There are no per-query API costs and no vendor lock-in. |
| **Controlled model selection** | IT controls exactly which AI models are available. Models are approved, downloaded, and packaged before deployment — no developer can pull unapproved models from the internet. |
| **Minimal attack surface** | The developer workstation (VM) is isolated from the broader network. Its only permitted outbound connection is to the local AI service. It cannot be used as a pivot point to reach other systems. |

### How It Works (Non-Technical)

Think of it as two compartments inside a single computer:

- **The AI Engine** runs directly on the Windows host and uses the machine's
  GPU for fast responses. It listens for requests on a dedicated private
  network that only exists inside the computer.

- **The Developer Workspace** runs inside a Linux virtual machine. Developers
  work here. The workspace can ask the AI for help, but it cannot reach the
  internet, the corporate network, or any other system — only the AI engine.

This means a compromised development tool, a malicious package, or a
misbehaving process inside the VM has nowhere to send data except the AI
service, which is also local.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Physical Machine (Windows Host)                                         │
│                                                                          │
│   NVIDIA RTX GPU                                                         │
│        │                                                                 │
│        ▼                                                                 │
│   ┌─────────────────────┐      OllamaNet (Internal Switch)              │
│   │   Ollama Service    │      10.10.10.0/24                            │
│   │   GPU-accelerated   │◄────────────────────────────────┐             │
│   │   10.10.10.10:11434 │                                 │             │
│   └─────────────────────┘                                 │             │
│        ▲                                          ┌────────┴──────────┐ │
│        │ Windows Firewall:                        │  Ubuntu 24.04 VM  │ │
│        │ port 11434 on                            │  10.10.10.20      │ │
│        │ 10.10.10.10 only                         │                   │ │
│        │                                          │  ┌─────────────┐  │ │
│        │                                          │  │   Docker    │  │ │
│        │                                          │  │  Container  │  │ │
│        │                                          │  │  dev-env    │  │ │
│        │                                          │  │             │  │ │
│        │                                          │  │  Pi / nvim  │  │ │
│        │                                          │  │  opencode   │  │ │
│        └──────────────────────────────────────────│  └─────────────┘  │ │
│                                                   │  ufw: DENY ALL    │ │
│                                                   │  except →         │ │
│                                                   │  10.10.10.10:11434│ │
│                                                   └───────────────────┘ │
│                                                                          │
│  No physical network adapter is connected to the OllamaNet switch.      │
│  Traffic on 10.10.10.0/24 is fully contained within the host machine.   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Location | Purpose |
|---|---|---|
| **Ollama** | Windows host | Serves AI model inference via HTTP. Bound exclusively to `10.10.10.10:11434`. Uses the NVIDIA GPU for fast responses. |
| **OllamaNet** | Hyper-V Internal Switch | A virtual network that exists only inside the host machine. Provides a communication channel between the VM and Ollama. Has no connection to physical network adapters. |
| **Ubuntu VM** | Hyper-V guest | The developer workspace OS layer. Runs Docker and enforces network policy via UFW. Has no internet access once deployed. |
| **dev-env container** | Docker inside the VM | Pre-built image (`ghcr.io/ldj-share/.dotfiles/dev-env:latest`) containing all dev tools fully initialized. Pulled once from GHCR; runs without any internet access thereafter. |
| **Pi / OpenCode / Neovim** | dev-env container | AI coding agents and editor. Send prompts to Ollama over the OllamaNet switch and return responses to the developer. |
| **ufw** | Ubuntu VM | Linux firewall. Enforces the VM's network isolation policy at the OS level. The container inherits the VM's network namespace, so UFW rules apply to all container traffic. |

---

## Security Design

### Layered Isolation

Security is enforced at four independent layers. All four must be
circumvented for the AI to affect anything outside the intended boundary.

```
Layer 1 — Hyper-V Switch Type
  OllamaNet is an "Internal" switch. Hyper-V Internal switches have
  no connection to physical network adapters by design. Traffic cannot
  leave the host machine at the hypervisor level regardless of any
  software configuration inside the VM.

Layer 2 — Windows Firewall (host)
  Ollama is bound to 10.10.10.10 (the OllamaNet adapter IP only).
  The Windows Firewall inbound rule is scoped to that IP and port.
  Ollama is unreachable from the physical LAN, Wi-Fi, or any other
  adapter on the host.

Layer 3 — UFW (VM guest)
  The VM's firewall default policy denies all inbound and outbound
  traffic at the kernel level. Two rules are permitted: inbound SSH
  (port 22/tcp) from the Windows host (10.10.10.10) for operator
  access, and outbound TCP to 10.10.10.10:11434 for Ollama. A
  compromised process inside the VM cannot initiate connections to any
  other destination. Because UFW uses kernel-level iptables/nftables
  rules, no userspace process can bypass this regardless of what tools
  are installed in the VM.

Layer 4 — Account hardening (VM guest)
  The dev account (which runs Pi) is removed from the sudo group and
  is denied all sudo access via a sudoers drop-in. Without root or sudo,
  no process running under the dev account can modify UFW rules, run
  iptables, manage systemd services, or install software. The firewall
  is structurally immutable from the dev account's perspective.
```

### What the VM Can and Cannot Do

| Action | Permitted | Enforced By |
|---|---|---|
| Send a prompt to Ollama | Yes | UFW allow rule |
| Accept SSH from Windows host (10.10.10.10) | Yes | UFW allow rule — operator access only |
| Access the internet | No | Hyper-V switch type + UFW default deny |
| Reach other machines on the LAN | No | Hyper-V switch type + UFW default deny |
| Receive inbound connections from any other source | No | UFW default deny incoming |
| Communicate with other VMs | No | Hyper-V Internal switch (no VM-to-VM without host routing) |
| Disable or modify the firewall | No | Account hardening (no sudo) + UFW kernel enforcement |
| Install network tunneling software | No | Account hardening (no sudo / no apt-get) |
| Escalate to root | No | Account hardening (sudo group removed + sudoers deny) |

### What Ollama Exposes

Ollama's HTTP API is bound to `10.10.10.10:11434` only. It is not
accessible from:

- The physical LAN or Wi-Fi
- Any other VM or container on the host
- The public internet

The Windows Firewall inbound rule explicitly scopes allowed traffic to
the `10.10.10.10` local address, so even if Ollama's bind address were
misconfigured, the firewall provides a backstop.

### Model Governance

AI models are enumerated in `dot-pi/models.json`. Only models listed in
that file are available to Pi. Models must be pulled onto the host machine
before the VM is exported — there is no mechanism for the VM to pull
additional models after deployment.

---

## Windows Host Setup

These steps are performed once on the machine that will run the environment.
All PowerShell commands require an elevated (Administrator) session.

### 1. Create the OllamaNet Internal Switch

```powershell
# Create the switch (Internal type = host + VMs only, no physical NIC)
New-VMSwitch -Name "OllamaNet" -SwitchType Internal

# Assign the static IP 10.10.10.10/24 to the host's virtual adapter
$ifIndex = (Get-NetAdapter | Where-Object { $_.Name -match "OllamaNet" }).ifIndex
New-NetIPAddress -IPAddress 10.10.10.10 -PrefixLength 24 -InterfaceIndex $ifIndex
```

### 2. Configure the Windows Firewall

```powershell
# Allow inbound to Ollama on the OllamaNet IP only.
# Scoping to -LocalAddress 10.10.10.10 ensures this rule does not apply
# to any other adapter (LAN, Wi-Fi, etc.).
New-NetFirewallRule `
  -DisplayName "Ollama (OllamaNet)" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 11434 `
  -LocalAddress 10.10.10.10 `
  -Action Allow
```

### 3. Install Ollama for Windows

Download and run the Ollama installer from https://ollama.com.

### 4. Bind Ollama to the OllamaNet IP

Set the following as a **System** environment variable (not User-level),
then restart Ollama:

```
Variable name:  OLLAMA_HOST
Variable value: 10.10.10.10:11434
```

Via PowerShell:

```powershell
[System.Environment]::SetEnvironmentVariable(
  "OLLAMA_HOST", "10.10.10.10:11434", "Machine"
)
# Restart Ollama (if running as a service)
Restart-Service ollama -ErrorAction SilentlyContinue
# Or restart it from the system tray
```

### 5. Pull the Required Models

Pull all models listed in `dot-pi/models.json` on the host machine before
exporting the VM. This is the only opportunity to download models before
the air-gap.

```powershell
# Example — pull each model listed in models.json
ollama pull bcluzel/LFM2.5-1.2B-Instruct:Q4_K_M
ollama pull lfm2.5-thinking:1.2b
ollama pull phi3:mini
ollama pull qwen2.5-coder:0.5b
ollama pull qwen3:1.7b
ollama pull qwen3:4b
ollama pull deepseek-coder-v2:16b
ollama pull deepseek-r1:8b
ollama pull qwen3.5:9b
# Add any additional models from models.json here
```

Verify Ollama is listening on the correct address:

```powershell
# Should return a response from Ollama
Invoke-WebRequest -Uri http://10.10.10.10:11434 -UseBasicParsing
```

---

## Corporate Environment Setup

### Why a Container?

Installing development tools from source requires contact with many different
package registries (apt, npm, cargo, GitHub releases, etc.). On a corporate
network, each of those sources needs its own firewall approval — a slow,
error-prone process.

The solution: **build the entire environment once in GitHub Actions** and
publish it as a single pre-built container image. The corporate machine only
ever talks to one address.

| Approach | URLs to whitelist |
|---|---|
| Running `setup.sh` directly | apt repos, npm, crates.io, github.com, golang.org, … (20+) |
| **Container pull (this approach)** | **`ghcr.io` only** |

### For IT: What Gets Whitelisted

```
ghcr.io          — GitHub Container Registry (HTTPS/443)
```

Docker Engine must already be installed on the VM. If it isn't, install it
once (requires `download.docker.com`) before the environment is moved to the
corporate network.

### For Developers: Using the Container

After the VM is set up, all development work happens inside the container:

```bash
# Pull the latest image (only needs ghcr.io)
docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest

# Start a session with your workspace mounted
docker run -it --rm \
  -v ~/workspace:/workspace \
  ghcr.io/ldj-share/.dotfiles/dev-env:latest

# Or pin to a specific version for reproducibility
docker run -it --rm \
  -v ~/workspace:/workspace \
  ghcr.io/ldj-share/.dotfiles/dev-env:<git-sha>
```

Everything inside the container is pre-initialized at build time:
- Neovim plugins (lazy.nvim) and all Mason LSP servers are already installed
- tmux plugins (TPM) are already installed
- Pi and OpenCode are ready to use without any first-run downloads
- All configs already point to `10.10.10.10:11434`

### VS Code Remote Development

The repo includes `.devcontainer/devcontainer.json`, which lets VS Code open
the project directly inside the pre-built container image without any manual
`docker run` commands.

**One-time setup on the Windows host:**

1. Install the **Remote - SSH** extension in VS Code.
2. Install the **Dev Containers** extension in VS Code.
3. Add the VM to your SSH config:
   ```
   Host ollamanet-vm
     HostName 10.10.10.20
     User dev
   ```

**Daily workflow:**

1. In VS Code, open the Remote Explorer and connect to `ollamanet-vm` via SSH.
2. Once connected, VS Code will detect `.devcontainer/devcontainer.json` and
   offer to **Reopen in Container**. Accept it.
3. VS Code attaches to the running `dev-env:latest` container. All extensions,
   terminals, and the integrated editor run inside the container.

The container is already fully initialized — Neovim, LSP servers, Pi, and
OpenCode are ready to use without any first-run downloads.

### How Images Are Built

Every push to `master` that touches a dotfile or the `Dockerfile` triggers
`.github/workflows/build-container.yml`:

1. **Lint** — ShellCheck runs against all test scripts
2. **Build and Test** — Image is built, then the full test suite in
   `tests/container/` runs against it to verify every tool is installed and
   pre-initialized correctly
3. **Publish** — If tests pass, the image is pushed to GHCR as both
   `:latest` and `:<git-sha>`

---

## VM Setup

### Initial Build (with Internet Access)

The VM needs internet access during initial setup to download packages.
Attach it to the **Default Switch** (or any internet-connected switch)
during this phase in addition to OllamaNet.

1. Create a new Generation 2 Ubuntu 24.04 VM in Hyper-V Manager.
2. Attach two network adapters: Default Switch (internet) and OllamaNet.
3. Configure the OllamaNet adapter with a static IP inside the VM:

```bash
# Find the OllamaNet adapter name (it will be the one on the 10.10.10.0/24 subnet)
ip link show

# Configure static IP using NetworkManager (replace eth1 with your adapter name)
sudo nmcli con mod "Wired connection 2" \
  ipv4.addresses 10.10.10.20/24 \
  ipv4.method manual \
  ipv4.gateway "" \
  ipv4.dns ""
sudo nmcli con up "Wired connection 2"
```

4. Clone this repository and run setup:

```bash
sudo apt-get update && sudo apt --fix-broken install && sudo apt install git
git clone <repo-url> ~/.dotfiles
cd ~/.dotfiles
bash setup.sh
```

`setup.sh` installs Docker Engine and pulls the pre-built dev container image
from GHCR. All development tooling (Neovim, Pi, OpenCode, tmux, etc.) lives
inside the container — `setup.sh` no longer installs them directly on the VM.

The setup script does not apply the firewall or account hardening — those
are handled separately by `firewall-enable.sh` as the final step before
export. The VM retains full internet access during the entire build phase.

### What setup.sh Installs

The setup script is modular. Each module can be run independently using
`--only <module>` or skipped with `--skip <module>`.

The default run (`bash setup.sh`) installs only what the VM host needs.
All dev tooling lives in the container image pulled by the `container` module.
For a full non-containerized install, use `just install-full`.

| Module | Default | What It Installs |
|---|---|---|
| `system` | ✓ | Minimal VM host packages: git, curl, stow, openssh-server, etc. Enables SSH server for Remote-SSH workflows. |
| `docker` | ✓ | Docker CE and Docker Compose |
| `container` | ✓ | Pulls `ghcr.io/ldj-share/.dotfiles/dev-env:latest` from GHCR |
| `shell` | | Base dev packages (zsh, fzf, bat, ripgrep, tmux, etc.) plus Zoxide, Eza, WezTerm, Oh My Posh, Lazygit, Television |
| `neovim` | | Latest Neovim (tarball) if the installed version is too old |
| `kubernetes` | | kubectl, kubectx, kubens |
| `languages` | | Go, Rust/Cargo, Node.js, Bun, PowerShell Core, .NET SDK |
| `dev-tools` | | GitHub CLI, devcontainer CLI, Ollama CLI |
| `vscode` | | VS Code and extensions from `vsc-extensions.txt` |
| `opencode` | | opencode CLI and oh-my-opencode |
| `pi` | | Pi coding agent (npm) |
| `dotfiles` | | Applies all dotfiles via stow, sets zsh as default shell, installs fonts |
| `podman` | | Podman and Podman Desktop (via Flatpak) |
| `nvidia` | | NVIDIA drivers + CUDA — only needed if running Ollama inside the VM rather than on the host |
| `claude` | | Claude Code CLI — for non-air-gapped environments only |

---

## Firewall and Account Hardening

Firewall configuration and account hardening are intentionally separated from
`setup.sh` into two dedicated scripts. This separation enforces a clear
boundary between the build phase (where internet access is needed) and the
deployment phase (where the VM is locked down).

### firewall-enable.sh

Applies the network isolation policy and removes elevated privileges from the
dev account. **Must be run as root.** This is the final step before exporting
the VM.

```bash
# Run as root — use the Hyper-V console or a separate admin account
sudo bash ~/.dotfiles/firewall-enable.sh [username]
# username defaults to 'krawlz' if omitted
```

**What it does:**

1. Installs UFW and applies a default-deny policy with two rules:
   - Inbound SSH (port 22/tcp) from `10.10.10.10` only — for Remote-SSH and
     devcontainer access from the Windows host.
   - Outbound TCP to `10.10.10.10:11434` — Ollama on the host.
2. Removes the dev account from the `sudo` group. Without sudo, no process
   running under the dev account — including Pi — can modify firewall rules,
   manage services, or install software.
3. Writes `/etc/sudoers.d/99-restrict-dev` to deny all sudo for the dev
   account even if it is re-added to the sudo group in the future.

### firewall-disable.sh

Opens a maintenance window by reversing the above. **Must be run as root.**

```bash
sudo bash ~/.dotfiles/firewall-disable.sh [username]
```

The script requires typing `CONFIRM` before making any changes, then:

1. Disables UFW.
2. Prompts whether to restore sudo access to the dev account (needed to
   re-run `setup.sh` or perform package updates).

Always run `firewall-enable.sh` again when the maintenance window is closed.

### Why These Scripts Cannot Be Run by the Dev Account

The dev account has no sudo access after `firewall-enable.sh` runs. This
means:

- `sudo bash firewall-disable.sh` → fails (no sudo)
- `sudo ufw disable` → fails (no sudo)
- `sudo iptables -F` → fails (no sudo)
- Modifying `/etc/ufw/` directly → fails (root-owned files, no write access)
- Running `iptables` without sudo → fails (requires `CAP_NET_ADMIN`, a root
  capability)

An AI agent instructed to "disable the firewall" has no mechanism to do so.
The only path to changing the network configuration is a root session, which
is inaccessible from within the dev account.

---

## Pre-Export Checklist

Complete these steps on the **build machine** before exporting the VM image.
Once exported, the VM will have no internet access on the target machine.

- [ ] All models listed in `dot-pi/models.json` have been pulled on the
      Windows host (`ollama list` shows all expected models)
- [ ] Ollama is responding at `http://10.10.10.10:11434` from within the VM:
      `curl http://10.10.10.10:11434` returns a response
- [ ] Pi can successfully reach Ollama from inside the VM:
      launch `pi` and send a test prompt
- [ ] Default Switch adapter has been removed from the VM
      (Hyper-V Manager → VM Settings → remove the Default Switch NIC)
- [ ] Firewall and account hardening applied (run as root, final step):
      `sudo bash ~/.dotfiles/firewall-enable.sh`
- [ ] UFW status confirms the expected rules:
      `sudo ufw status verbose` shows loopback, SSH inbound from `10.10.10.10`, and `10.10.10.10:11434` outbound
- [ ] Dev account no longer has sudo: log in as the dev user and confirm
      `sudo echo test` is denied
- [ ] VM has been shut down cleanly before export

### Apply the Firewall (Final Step Before Export)

```bash
# Must be run as root
sudo bash ~/.dotfiles/firewall-enable.sh

# Verify firewall rules
sudo ufw status verbose
```

Expected UFW output:
```
Status: active
Default: deny (incoming), deny (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
Anywhere on lo             ALLOW IN    Anywhere
22/tcp                     ALLOW IN    10.10.10.10
10.10.10.10 11434/tcp      ALLOW OUT   Anywhere
Anywhere on lo             ALLOW OUT   Anywhere
```

---

## Deploying to an Air-Gapped Machine

### Prerequisites on the Target Machine

- Windows 10/11 Pro or Enterprise with Hyper-V enabled
- NVIDIA RTX GPU with the latest Windows driver installed
- Ollama for Windows installed and configured as described in
  [Windows Host Setup](#windows-host-setup)
- The OllamaNet Internal Switch created with IP `10.10.10.10`
- All required AI models already pulled (no internet available on target)

### Import the VM

```powershell
# Import the exported VM (adjust paths as needed)
Import-VM -Path "C:\Path\To\ExportedVM\VM.vmcx" -Copy -GenerateNewId

# Verify the VM's network adapter is connected to OllamaNet
# (Hyper-V Manager → VM Settings → Network Adapter → OllamaNet)
```

### Verify After Import

1. Start the VM.
2. From inside the VM, confirm Ollama is reachable:
   ```bash
   curl http://10.10.10.10:11434
   # Expected: {"status":"Ollama is running"}
   ```
3. Launch Pi and confirm it responds:
   ```bash
   pi
   ```
4. Confirm no other outbound traffic is possible:
   ```bash
   # Should time out / be refused
   curl --max-time 5 http://8.8.8.8
   ```

---

## Maintenance

### Adding or Updating AI Models

All model management is performed on the **Windows host** (not inside the VM).

```powershell
# Pull a new model
ollama pull <model-name>

# List installed models
ollama list

# Remove a model
ollama rm <model-name>
```

To make a new model available to Pi, add it to `dot-pi/models.json` and
re-run `bash setup.sh --only dotfiles` inside the VM to re-stow the config.

### Updating VM Software

Software updates require temporarily opening a maintenance window. The
procedure is:

1. **On the host (Hyper-V Manager):** re-attach the Default Switch adapter
   to the VM.
2. **On the host (as root), open the maintenance window:**
   ```bash
   sudo bash ~/.dotfiles/firewall-disable.sh
   # Type CONFIRM when prompted
   # Answer 'yes' to restore sudo for the dev account if re-running setup.sh
   ```
3. **Inside the VM, perform updates:**
   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   bash ~/.dotfiles/setup.sh   # re-run setup if needed (idempotent)
   ```
4. **On the host (as root), re-apply isolation:**
   ```bash
   sudo bash ~/.dotfiles/firewall-enable.sh
   ```
5. **On the host (Hyper-V Manager):** remove the Default Switch adapter.

### Re-running the Setup Script

The setup script is fully idempotent — every module checks whether its
software is already installed before acting. Firewall and hardening are
never applied by `setup.sh`; they are always managed separately.

```bash
# Re-run everything (safe to run multiple times)
bash ~/.dotfiles/setup.sh

# Re-run a specific module only
bash ~/.dotfiles/setup.sh --only dotfiles
bash ~/.dotfiles/setup.sh --only shell
```

---

## VM Operations Reference

### Setting Up a New VM from Scratch

1. Create a new VM in Hyper-V (tested on Ubuntu 24.04 LTS).
2. Install git:

    ```bash
    sudo apt-get update \
        && sudo apt --fix-broken install \
        && sudo apt install git
    ```

3. Clone this repository and run setup:

    ```bash
    git clone <repo-url> ~/.dotfiles
    cd ~/.dotfiles
    bash ./setup.sh
    ```

### Expanding the Ubuntu Disk

Hyper-V Quick Create VMs often come with a small disk. To expand it:

1. Delete all VM checkpoints in Hyper-V Manager (required before editing the disk).
2. Power down the VM.
3. In Hyper-V Manager, go to VM Settings → SCSI Controller → Hard Drive → Edit.
4. Expand the disk to the desired size (128 GB recommended).
5. Start the VM and install the resize utility:

    ```bash
    sudo apt install cloud-guest-utils
    ```

6. If using a non-English locale, override it to avoid locale errors:

    ```bash
    LC_ALL=C
    ```

7. Expand the partition into the free space:

    ```bash
    sudo growpart /dev/sda 1
    ```

    > Note the space between `sda` and `1`.

8. Resize the filesystem:

    ```bash
    sudo resize2fs /dev/sda1
    ```

    > No space between `sda` and `1` here.

The Ubuntu partition now uses the full allocated disk size.
