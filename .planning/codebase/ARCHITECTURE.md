# Architecture

## System Overview

This is an air-gapped local AI development environment designed to run entirely on a single Windows machine with no external network dependencies after deployment. The system enables AI-assisted coding via Pi and OpenCode agents while keeping all data, models, and operations isolated within the host hardware.

The core design splits functionality across three layers:
1. Windows Host - GPU-accelerated Ollama service
2. Hyper-V Virtual Network - OllamaNet internal switch
3. Ubuntu VM plus Docker Container - Pre-built dev environment

## Summary

The system achieves air-gapped, secure AI-assisted development through:
1. Pre-built container distribution (ghcr.io only)
2. Four independent security layers
3. Model governance (enumerated, no pull mechanism)
4. Reproducible environment (git SHA pinning)
5. Security-in-depth (requires defeating all four layers)

Breaking the network boundary requires defeating all four isolation layers simultaneously, making it impossible without physical host access.
