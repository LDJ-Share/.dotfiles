# Architecture Research

**Domain:** Docker Compose + devcontainer for air-gapped AI dev environment
**Researched:** 2026-04-08
**Confidence:** HIGH

---

## Standard Architecture

### System Overview

The devcontainer.json references a docker-compose.yml file. VS Code starts both dev-env and ollama-models services on a named internal network where they discover each other by service name.

**Services:**
- **dev-env**: Main development container with tooling (Neovim, Pi, OpenCode, etc.)
- **ollama-models**: Ollama service for LLM inference

**Network:** Isolated bridge network (dev-compose) where services discover each other by name.

**Volumes:**
- **ollama-data**: Named volume for persistent model storage
- **workspace**: Bind mount for live code editing on host

### Component Responsibilities

**dev-env container:**
- User-facing dev environment with all tooling
- Mounts workspace directory from host for editing
- Connects to ollama-models service via internal network
- Environment variable OLLAMA_HOST=http://ollama-models:11434 for discovery

**ollama-models container:**
- Isolated Ollama service in same compose network
- Stores downloaded models in named volume (persists across restarts)
- Exposes port 11434 for internal dev-env access
- GPU reservation handled via docker-compose deploy.resources.reservations.devices

---

## Compose File Structure

### File Placement: .devcontainer/docker-compose.yml

**Best practice:** Place docker-compose.yml in .devcontainer/ directory

Rationale:
- Keeps devcontainer-specific files together
- VS Code extension looks in .devcontainer/ by default
- Makes it clear this compose is for dev environment
- Easier to locate all devcontainer assets in one directory

### Naming Conventions

- **Compose service names:** dev-env, ollama-models
- **Named volumes:** ollama-data, dev-state
- **Network name:** dev-compose or dev-network

---

## devcontainer.json Fields for Compose

### Critical Fields Required

Essential fields to define in devcontainer.json:

- **dockerComposeFile**: Relative path to docker-compose file from .devcontainer/
- **service**: Which service VS Code opens a terminal in (the dev-env service)
- **runServices**: All services to bring up with compose up (dev-env and ollama-models)
- **workspaceFolder**: Directory inside dev-env where workspace is mounted
- **remoteUser**: User account to run terminal as (must exist in image)
- **postCreateCommand**: Script to run once after first container start
- **waitFor**: Block terminal opening until command completes

---

## Network Design

### Internal Compose Bridge Network

Docker Compose creates an isolated bridge network where services discover each other by name.

**Service names become hostnames:**

Inside dev-env, reference ollama-models as: http://ollama-models:11434

Docker Embedded DNS (127.0.0.11:53) automatically resolves service names to container IPs.

**Network configuration:**

Use driver: bridge with internal: false (default) to allow dev-env to reach host and external networks.

### Service Discovery Mechanics

- Docker Embedded DNS resolves service names transparently
- Service name equals container name equals hostname
- Works across multiple containers on same network
- No manual /etc/hosts or DNS config needed

---

## Volume Design

### Ollama Model Storage

**Named volume for models (RECOMMENDED):**

Use ollama-data mounted to /root/.ollama inside ollama-models container.

**Why named volume over bind mount?**

Named volumes provide:
- Native Docker speed (important for large model files)
- Portability across machines
- Survival of container deletion
- Easy backup capability

Bind mounts are slower on Windows/Mac and path-dependent.

### dev-env Workspace Mount

Bind mount for live editing on host.

Use :cached flag on Docker Desktop for performance.

---

## Ollama Host Configuration

### Service Discovery Via Environment Variable

Ollama tools auto-detect OLLAMA_HOST:

```yaml
dev-env:
  environment:
    OLLAMA_HOST: http://ollama-models:11434
```

**Tools using this:**
- ollama list
- pi-coding-agent
- Shell scripts

---

## Windows Host Fallback Architecture

### Solution: Environment Variable Override

In docker-compose.yml:

```yaml
dev-env:
  environment:
    OLLAMA_HOST: ${OLLAMA_HOST:-http://ollama-models:11434}
```

Allows:
- Use OLLAMA_HOST if set by user
- Otherwise use internal service

**Usage:**
```bash
# Use internal (default)
docker-compose up

# Use Windows host
OLLAMA_HOST=http://10.10.10.10:11434 docker-compose up
```

---

## File Layout

```
.dotfiles/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── post-create.sh
│   └── init-firewall.sh
├── .planning/
│   └── research/
│       └── ARCHITECTURE.md
├── Dockerfile
└── [workspace files...]
```

---

## Anti-Patterns to Avoid

- DO NOT: Set internal: true if you need host access
- DO NOT: Hardcode host IPs in environment
- DO NOT: Use bind mounts for Ollama models on Windows
- DO NOT: Define workspaceFolder in docker-compose.yml
- DO NOT: Use localhost from host perspective

---

## Best Practices

1. Service names as hostnames
2. Named volumes for persistence
3. Environment variable overrides
4. devcontainer.json in .devcontainer/
5. docker-compose.yml in .devcontainer/
6. Explicit network name
7. runServices includes all services
8. GPU config via deploy.resources
9. Post-create script for initialization
10. Named volumes descriptively

---

## Sources

### Examined Files

- claude-code-try-again/.devcontainer/devcontainer.json
- claude-code-try-again/.devcontainer/docker-compose.yml
- claude-code-try-again/.devcontainer/Dockerfile
- claude-code-try-again/.devcontainer/post-create.sh
- _ldj-share/.dotfiles/.devcontainer/devcontainer.json
- _ldj-share/.dotfiles/Dockerfile

### Reference Documentation

- Docker Compose Networking: https://docs.docker.com/compose/networking/
- VS Code Remote Containers: https://code.visualstudio.com/docs/remote/remote-overview
- Docker Service Discovery: https://docs.docker.com/config/containers/container-networking/
- Docker Named Volumes: https://docs.docker.com/storage/volumes/
- Ollama: https://github.com/ollama/ollama
