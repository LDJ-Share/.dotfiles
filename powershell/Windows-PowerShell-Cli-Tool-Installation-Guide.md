# Windows Tool Installation & Profile Replication Guide

This guide documents the tools and configuration required to replicate a PowerShell environment on a new Windows machine.

## Prerequisites

1.  **PowerShell 7+**: Ensure you are using the latest version of PowerShell (Core).
2.  **Git for Windows**: Required for version control and some shell utilities.
3.  **Scoop** (Recommended): The preferred package manager for user-level installations (no admin required).
    - See: https://scoop.sh/
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    ```
4.  **Chocolatey** (Optional): Alternative package manager for system-wide tools.
    ```powershell
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    ```
5.  **Nerd Fonts**: Install a Nerd Font (e.g., MesloLGM Nerd Font) for icons in the prompt and `eza`.
    ```powershell
    scoop bucket add nerd-fonts
    scoop install Cascadia-Code
    ```

## Core Tools (Installed via Scoop)

Run the following in a PowerShell session:

```powershell
# Essential CLI Tools
scoop install bat eza xh fzf zoxide direnv ripgrep fd television just

# Network & Security Tools
scoop install nmap gobuster ffuf ngrok

# Kubernetes Tools
scoop install kubectl kubectx kubens

# Terminal Enhancements
scoop install oh-my-posh
```

## Python-based Tools

Some tools are better installed via `pip`:

```powershell
python -m pip install ranger-fm
```

## Post-Installation Verification

After installing, verify the tools are available and functioning correctly:

```powershell
# Check if binaries are in the PATH
$tools = @('bat', 'eza', 'xh', 'fzf', 'zoxide', 'direnv', 'ripgrep', 'fd', 'television', 'nmap', 'gobuster', 'ffuf', 'kubectl', 'kubectx', 'kubens', 'ngrok', 'oh-my-posh', 'ranger', 'just')
Get-Command $tools -ErrorAction SilentlyContinue | Select-Object Name, Source

# Detailed version/functionality checks
Write-Host "`n--- Version Checks ---" -ForegroundColor Cyan
try { bat --version } catch { Write-Warning "bat failed" }
try { eza --version } catch { Write-Warning "eza failed" }
try { xh --version } catch { Write-Warning "xh failed" }
try { fzf --version } catch { Write-Warning "fzf failed" }
try { zoxide --version } catch { Write-Warning "zoxide failed" }
try { direnv --version } catch { Write-Warning "direnv failed" }
try { rg --version } catch { Write-Warning "ripgrep failed" }
try { fd --version } catch { Write-Warning "fd failed" }
try { tv --version } catch { Write-Warning "television failed" }
try { just --version } catch { Write-Warning "just failed" }
try { nmap --version } catch { Write-Warning "nmap failed" }
try { gobuster version } catch { Write-Warning "gobuster failed" }
try { ffuf -V } catch { Write-Warning "ffuf failed" }
try { kubectl version --client } catch { Write-Warning "kubectl failed" }
try { kubectx --version } catch { Write-Warning "kubectx failed" }
try { kubens --version } catch { Write-Warning "kubens failed" }
try { ngrok --version } catch { Write-Warning "ngrok failed" }
try { oh-my-posh --version } catch { Write-Warning "oh-my-posh failed" }
try { ranger --version } catch { Write-Warning "ranger failed" }
```

## Module Management

The `MyProfileUtils` module is automatically loaded by the profile. It provides aliases and helper functions that bridge the gap between Linux/Zsh commands and PowerShell. This module also includes a PowerShell implementation of `stow` in `Stow.ps1` to manage dotfiles.

## Tools

- **gh-dash**: Extension for `gh`. `gh` is installed and available.
- **television**: Config exists in `.dotfiles/television`. `tv` binary installed via `scoop`.
- **nvim**: Fully integrated with environment variables and aliases.
- **bat**: A `cat` clone with syntax highlighting. Installed via `scoop`.
- **eza**: A modern replacement for `ls`. Installed via `scoop`.
- **xh**: Friendly and fast tool for sending HTTP requests. Installed via `scoop`.
- **fzf**: A general-purpose command-line fuzzy finder. Installed via `scoop`.
- **zoxide**: A smarter cd command. Installed via `scoop`.
- **direnv**: Unclutter your .profile. Installed via `scoop`.
- **nmap**: Port scanner. Installed via `scoop`.
- **gobuster**: Tool used to brute-force URIs. Installed via `scoop`.
- **ffuf**: Fast web fuzzer. Installed via `scoop`.
- **kubectx & kubens**: Power tools for kubectl. Installed via `scoop`.
- **ranger**: Terminal file manager. Installed via `pip` (`python -m pip install ranger-fm`).
- **ngrok**: Secure introspectable tunnels to localhost. Installed via `scoop`.
- **Stow (Windows implementation)**: [x] Checked box. Implement a PowerShell-based `stow` to manage dotfiles. [Reference](https://github.com/mattialancellotti/stow/blob/master/Main.ps1)