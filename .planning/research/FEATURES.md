# Feature Research

**Domain:** Air-gapped Docker compose deployment workflow
**Researched:** 2026-04-08
**Confidence:** HIGH

## Summary

Comprehensive research answering 7 key questions about air-gapped Docker-compose dev environment deployment: image transport scripts, import scripts, tar strategy, workspace templates, VS Code devcontainer configuration, GPU handling, and verification steps.

## Question 1: Image Transport Script

**What must it do?**
- Verify images exist locally via docker images
- Execute docker save with images piped to gzip -9
- Generate SHA256 checksum of the tarball
- Create manifest.json with image names, tags, digests, checksums
- Log operations with timestamps
- Detect NVIDIA GPU presence (annotation only, non-blocking)
- Return proper exit codes
- Provide transport checklist

**Outputs:** combined-images.tar.gz (9-12GB), manifest-TIMESTAMP.json, export.log

**Variants:** image-export.sh (bash) and image-export.ps1 (PowerShell)

## Question 2: Import Script

**What must it do?**
- Accept tarball and manifest paths
- Verify SHA256 checksum against manifest
- Decompress and load images via docker load
- Verify images loaded successfully
- Validate docker-compose.yml syntax
- Verify compose references loaded images
- Start services and health check
- Detect NVIDIA GPU (warn if mismatch, do NOT fail)
- Report loaded images and service status

**Outputs:** import.log, image list, service status table

**Variants:** image-import.sh (bash) and image-import.ps1 (PowerShell)

## Question 3: Single Tar vs Per-Image

**RECOMMENDATION: Single combined tar with gzip**

Single combined approach:
- Command: docker save dev-env:latest ollama:latest | gzip > combined-images.tar.gz
- Size: ~9-12GB (dev-env 6GB + ollama 6GB with shared Ubuntu base)
- Advantages: Atomic, simple, gzip deduplicates layers, single checksum
- Disadvantages: All-or-nothing, can't load partial set

Why recommended:
1. Only 2 core images in scope
2. Air-gap = all-or-nothing deployment
3. Simpler export/import scripts
4. Easier checksumming and auditing
5. Matches reference impl (claude-code-try-again)

## Question 4: Workspace Template

Users copy template structure:
- .devcontainer/devcontainer.json (VS Code config)
- .devcontainer/docker-compose.yml (services definition)
- .devcontainer/Dockerfile (optional custom layer)
- docker-compose.yml (symlink to .devcontainer version)
- .workspace-template.md (user docs)

Services in compose:
- dev: image, volumes (workspace + home), environment, network
- ollama: image, volumes, ports (11434), GPU config, network

## Question 5: VS Code devcontainer.json for docker-compose

REQUIRED FIELDS:
- dockerComposeFile: path to compose file (e.g., 'docker-compose.yml')
- service: primary service name (e.g., 'dev', must exist in compose)
- workspaceFolder: absolute container path (e.g., '/workspace', must match compose mount)
- remoteUser: user to run as (e.g., 'dev', must exist in image)

OPTIONAL RECOMMENDED:
- runServices: array of services to start (e.g., ['dev', 'ollama'])

Key constraints:
- workspaceFolder MUST match compose volume mount target
- service MUST exist in docker-compose.yml
- remoteUser MUST exist in image
- Extensions must be pre-cached (no runtime marketplace)

## Question 6: GPU Detection Logic

Export phase:
- Detect: lspci | grep -i nvidia or nvidia-smi --list-gpus
- Annotate manifest with gpu_present flag (optional, informational)
- Do NOT fail if GPU absent

Compose configuration:
- Use deploy.resources.devices with nvidia driver
- Count: all (or specific device IDs)
- Capabilities: [gpu]

Import phase:
- Detect GPU on target: nvidia-smi or lspci
- If GPU config but no GPU: WARN (do NOT fail)
- Docker Compose degrades gracefully to CPU
- No dynamic config rewriting needed

## Question 7: Verification Steps

Export verification (user checklist):
- combined-images.tar.gz exists and > 8GB
- export-manifest-TIMESTAMP.json created
- No error messages in export.log
- All required images in manifest
- sha256sum -c manifest.json passes

Import verification (automated):
- SHA256 checksum verification
- docker image ls to confirm all loaded
- docker compose config --quiet for syntax validation
- docker compose ps for service status
- GPU detection with warnings
- Network and volume inspection

User verification (manual):
- Reopen in Dev Container
- Terminal: echo $HOME should show /home/dev
- curl http://ollama:11434/api/version should respond
- Pi/OpenCode network connectivity to Ollama

## MVP Definition

**Must Include v1.0:**
- image-export.sh and image-export.ps1
- image-import.sh and image-import.ps1
- .devcontainer/docker-compose.yml template
- .devcontainer/devcontainer.json template
- Single combined tar with gzip
- SHA256 checksum verification
- Compose config validation
- Service health checking
- GPU detection (optional, informational)
- Detailed logging and documentation

**Nice to Have (Phase 2):**
- Per-image tarball option
- zstd compression support
- Sigstore image signing
- Multi-architecture (ARM64 + x86)
- Corporate Harbor registry support

**Out of Scope:**
- Kubernetes/Helm deployment
- macOS/Linux host support
- Ollama inside dev container
- Automated model validation

---

**Last Updated:** 2026-04-08
**Researched by:** Claude Research Agent (Haiku 4.5)
**Confidence:** HIGH (official Docker/VS Code docs + 2026 research)
