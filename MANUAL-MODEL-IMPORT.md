# Manual Ollama Model Import Procedure

This document provides instructions for importing Ollama models into the shared container volume (`ollama_data`) on the target offline machine. This approach allows multiple docker-compose configurations to share the same model data while keeping the core Ollama container lightweight.

## Overview

Instead of pre-baking models into the Ollama container image (which caused GitHub Actions disk space issues), we now:
1. Pull models on the Windows host Ollama instance
2. Export the model data from the host's Ollama storage
3. Import that data into the shared `ollama-data` volume used by the containerized Ollama service

This enables:
- Multiple project-specific docker-compose files sharing the same models
- Easy model updates without rebuilding images
- Smaller, faster-to-transfer container images
- Compatibility with air-gap requirements

## Prerequisites on Windows Host

1. Ollama for Windows installed and running
2. Ollama bound to `10.10.10.10:11434` via `OLLAMA_HOST` environment variable
3. Required models pulled using `ollama pull <model>` commands
4. OllamaNet Internal Switch configured with IP `10.10.10.10`

## Step 1: Verify Models on Windows Host

First, confirm the required models are available on the Windows host:

```powershell
# List all available models
ollama list

# Verify specific models (adjust based on dot-pi/models.json)
ollama show gemma4:26b
ollama show gemma4:e4b
```

## Step 2: Locate Ollama Model Storage on Windows Host

Ollama stores model data in:
```
%USERPROFILE%\.ollama\models
```

Typical path: `C:\Users\<username>\.ollama\models`

## Step 3: Export Model Data from Windows Host

Create a portable archive of the model data:

```powershell
# Create export directory
$exportDir = "$env:USERPROFILE\ollama-model-export"
New-Item -ItemType Directory -Force -Path $exportDir

# Copy model files (preserving directory structure)
Copy-Item -Path "$env:USERPROFILE\.ollama\models\*" -Destination $exportDir -Recurse -Force

# Create manifest of exported models
Get-ChildItem -Path $exportDir -Directory | ForEach-Object {
    $modelName = $_.Name
    $manifestPath = Join-Path $_.FullName "manifest.json"
    if (Test-Path $manifestPath) {
        Get-Content $manifestPath | ConvertFrom-Json | Select-Object @{Name="model";Expression={$modelName}}, *
    }
} | ConvertTo-Json -Depth 10 | Set-Path "$exportDir\models-manifest.json"

# Create compressed archive
Compress-Archive -Path $exportDir\* -DestinationPath "$env:USERPROFILE\ollama-models.tar.gz"
```

## Step 4: Transfer to Target Machine

Copy `ollama-models.tar.gz` to removable media and transfer to the target offline machine.

## Step 5: Import Model Data on Target Machine

On the target machine (inside the VM or via WSL), import the model data into the shared Ollama volume:

```bash
# Extract the model archive
mkdir -p ~/ollama-model-import
tar -xzf ollama-models.tar.gz -C ~/ollama-model-import

# Stop any running Ollama containers to avoid conflicts
docker compose -f .devcontainer/docker-compose.yml stop ollama

# Create a temporary container to copy data into the volume
docker run --rm \
  -v ollama-data:/destination \
  -v $HOME/ollama-model-import:/source:ro \
  alpine:latest \
  sh -c "cp -r /source/* /destination/ && chown -R root:root /destination"

# Clean up temporary files
rm -rf ~/ollama-model-import
rm ollama-models.tar.gz

# Verify the import
docker run --rm -v ollama-data:/data alpine:latest ls -la /data
```

## Step 6: Verify Model Availability

Start the Ollama service and verify models are accessible:

```bash
# Start Ollama service
docker compose -f .devcontainer/docker-compose.yml up -d ollama

# Wait for service to be healthy (check with docker compose ps)
# Then verify models are listed
docker compose -f .devcontainer/docker-compose.yml exec ollama ollama list

# Test model inference (optional)
docker compose -f .devcontainer/docker-compose.yml exec ollama ollama run gemma4:26b "Hello, how are you?"
```

## Alternative: Direct Volume Import (Single Machine)

If working directly on the target machine with direct volume access:

```bash
# Stop Ollama service
docker compose -f .devcontainer/docker-compose.yml stop ollama

# Extract models directly into the volume
docker run --rm \
  -v ollama-data:/destination \
  -v $HOME/ollama-model-import:/source:ro \
  alpine:latest \
  sh -c "cp -r /source/* /destination/"

# Start service and verify
docker compose -f .devcontainer/docker-compose.yml up -d ollama
docker compose -f .devcontainer/docker-compose.yml exec ollama ollama list
```

## Updating Models

To update models:
1. Repeat Steps 1-3 on Windows host to get latest model data
2. Transfer new archive to target machine
3. Repeat Steps 5-6 to refresh the shared volume

## Benefits of This Approach

1. **Smaller Images**: Ollama container image remains small (~500MB vs ~22GB+)
2. **Faster CI**: GitHub Actions workflows complete quickly without large model downloads
3. **Flexible Updates**: Models can be updated without rebuilding/republishing images
4. **Shared Resources**: Multiple projects can share the same model data
5. **Air-Gap Compliant**: All model data transferred via physical media before deployment

## Troubleshooting

### "Model not found" errors
- Verify the model directories exist in the volume: `docker run --rm -v ollama-data:/data alpine:ls /data`
- Check that manifest.json files are present in each model directory
- Ensure proper ownership: `chown -R root:root /root/.ollama` inside the container

### Permission issues
The Ollama container runs as root, so extracted files should be owned by root:root

### Volume not updating
- Ensure Ollama service is stopped before importing
- Verify you're importing to the correct volume name (`ollama-data`)

## Integration with Existing Workflow

This manual model import complements the existing:
- `image-export.sh`/`image-import.sh` for container images
- `cuda-prep.sh`/`cuda-prep.ps1` for GPU artifacts
- `workspace-template` for project onboarding

The model data import is now a separate step that handles the large model blobs efficiently.