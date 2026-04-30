# Stack Research
**Domain:** Docker Compose + Ollama air-gap deployment
**Researched:** 2026-04-08
**Confidence:** HIGH

## Recommended Stack

### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|---|---|---|---|
| Docker | 24.x+ | Container runtime | Native compose integration |
| Docker Compose | v2 | Orchestrate services | Single YAML file |
| Ollama | latest | LLM inference | REST API on port 11434 |
| Ubuntu | 24.04 LTS | Dev container base | Matches existing Dockerfile |
| Podman Compose | 1.1.x+ | Optional alternative | Drop-in replacement |

## Pre-baking Ollama Models

Models are cached in image layer (/root/.ollama) at build time.

Key pattern: Use entrypoint script to pull models during docker build

Storage location inside container: /root/.ollama

Mount this path as a Docker volume for persistence across restarts.

## Compose Network Pattern

Internal bridge network with service discovery via Docker DNS.

Service name (ollama) resolves to 11434 automatically within containers.

No host port mappings needed - internal only.

Health check on GET /api/tags ensures Ollama ready before dev container starts.

## GPU Optional Pattern

NVIDIA GPU passthrough via deploy.resources.reservations.devices

Use count OR device_ids (mutually exclusive, not both)

CPU fallback: Remove deploy section or set devices: []

Ollama auto-fallbacks to CPU if GPU unavailable.

## Podman Compatibility

Add to compose.yaml:
```
x-podman:
  docker_compose_compat: true
  in_pod: false
```

Key differences:
- Podman shares network namespace (use in_pod: false)
- Volume locations differ but behavior same
- Service DNS resolution works in both
- Avoid: localhost for inter-container comms (use service name)
- Avoid: network_mode: host (breaks Podman)

## Image Save/Load Workflow

Connected machine:
docker pull ghcr.io/ldj-share/.dotfiles/dev-env:latest
docker pull ollama/ollama:latest
docker image save <img1> <img2> | gzip > airgap-stack.tar.gz

Air-gapped machine:
docker image load < airgap-stack.tar.gz
docker compose up

## What NOT to Use

✗ Image refs without pre-caching on air-gapped machine
✗ Hardcoded localhost for inter-container comms
✗ Port exposures for sidecars (wastes resources)
✗ Both count and device_ids in GPU deploy
✗ Anonymous volumes (use named or bind mounts)
✗ Skipping health checks
✗ network_mode: host
✗ Assuming CPU fallback without testing

## Sources

- https://docs.docker.com/compose/how-tos/gpu-support/
- https://docs.docker.com/reference/compose-file/deploy/
- https://docs.ollama.com/docker
- https://docs.ollama.com/modelfile
- https://docs.podman.io/en/latest/markdown/podman-compose.1.html
- https://medium.com/@jared.ratner2/setting-up-docker-and-docker-compose-with-nvidia-gpu-support-on-linux-716db95c0f7c
- https://docs.nvidia.com/ai-workbench/user-guide/latest/projects/compose.html

---

## Detailed Implementation Guide

### 1. Pre-baking Ollama Models - Dockerfile Pattern

```dockerfile
FROM ollama/ollama:latest

# Set environment for offline operation
ENV OLLAMA_HOST=127.0.0.1:11434 \
    OLLAMA_KEEP_ALIVE=24h

# Copy model pull entrypoint script
COPY scripts/pull-models.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Pre-pull models during build (requires internet access during build only)
RUN /bin/sh -c '/entrypoint.sh serve &' && \
    sleep 5 && \
    /bin/ollama pull gemma4:26b && \
    /bin/ollama pull gemma4:e4b

EXPOSE 11434
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
```

### 2. Complete docker-compose.yml Pattern

```yaml
version: '3.9'

# For Podman compatibility
x-podman:
  docker_compose_compat: true
  in_pod: false

services:
  dev:
    image: ghcr.io/ldj-share/.dotfiles/dev-env:latest
    container_name: dev-env
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - OLLAMA_HOST=ollama:11434
    volumes:
      - /workspace:/workspace
      - dev-cache:/home/dev/.cache
    networks:
      - airgap-net
    depends_on:
      ollama:
        condition: service_healthy

  ollama:
    build:
      context: ./docker/ollama
      dockerfile: Dockerfile
    container_name: ollama-service
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_KEEP_ALIVE=24h
    volumes:
      - ollama-cache:/root/.ollama
    networks:
      - airgap-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              capabilities: [gpu]
              count: 1

networks:
  airgap-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  ollama-cache:
    driver: local
  dev-cache:
    driver: local
```

### 3. GPU vs CPU Fallback Pattern

For CPU-only fallback, create compose.override.yml:

```yaml
services:
  ollama:
    deploy: {}  # Empty - removes GPU config
```

Run with:
```bash
# With GPU
docker compose up

# Without GPU  
docker compose -f compose.yaml -f compose.cpu.yml up
```

### 4. Service Discovery Inside Containers

From dev container, reach Ollama:
```bash
# Environment variable
export OLLAMA_BASE_URL=http://ollama:11434

# Direct HTTP call
curl -s http://ollama:11434/api/tags

# Python
import requests
resp = requests.post('http://ollama:11434/api/chat', json={...})
```

### 5. Air-Gapped Image Transfer

Connected machine workflow:
```bash
# Build custom Ollama image with pre-baked models
docker build -t ollama:with-models ./docker/ollama

# Save both images
docker image save \
  ghcr.io/ldj-share/.dotfiles/dev-env:latest \
  ollama:with-models \
  | gzip > airgap-bundle.tar.gz

# Transfer to USB/SCP/etc
scp airgap-bundle.tar.gz user@air-gapped-machine:/tmp/
```

Air-gapped machine workflow:
```bash
# Load images
docker image load < airgap-bundle.tar.gz

# Verify
docker image ls | grep ollama

# Start stack (no internet needed)
cd /path/to/compose
docker compose up -d

# Test Ollama is accessible
curl http://ollama:11434/api/tags
```

### 6. Ollama Modelfile Reference

For custom models with parameters:

```
FROM gemma4:26b
PARAMETER temperature 0.7
PARAMETER top_k 40
PARAMETER top_p 0.9
PARAMETER num_ctx 4096
SYSTEM "You are a helpful coding assistant..."
```

Bake into image:
```dockerfile
RUN /bin/ollama create my-custom-model -f /path/to/Modelfile
```

### 7. Port Configuration Details

**Inside Container:**
- Ollama listens on `OLLAMA_HOST=0.0.0.0:11434`
- Services on same network access via: `http://ollama:11434`

**Host Access (if needed):**
- Add `ports: ["11434:11434"]` to service (but not needed for air-gap)
- Access as: `http://localhost:11434`

**Health Check:**
- Endpoint: `GET http://localhost:11434/api/tags`
- Returns JSON list of loaded models
- Used by depends_on to wait for readiness

