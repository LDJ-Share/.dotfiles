# Project State

**Project:** Air-Gapped AI Dev Environment — Compose-First Deployment
**Initialized:** 2026-04-08
**Current Phase:** Not started

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-08)

**Core value:** A developer on an air-gapped machine can open VS Code, reopen in devcontainer, and immediately have a full AI coding session — with no setup, no internet, and no firewall exceptions.
**Current focus:** Ready to start Phase 1

## Phase Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | Ollama Image | Pending |
| 2 | Compose Stack | Pending |
| 3 | Devcontainer Integration | Pending |
| 4 | Export Scripts + CUDA Prep | Pending |
| 5 | Import Scripts | Pending |
| 6 | Workspace Template | Pending |

## Active Context

None — project initialized, ready to start Phase 1.

## Key Decisions

| Decision | Outcome | Phase |
|----------|---------|-------|
| Single combined tar.gz for export | Atomic transport; gzip deduplicates shared layers between images | Phase 4 |
| Models baked into image at build time | Air-gap requirement; no runtime pulls; use `ollama serve & sleep 10` + retry loop in Dockerfile | Phase 1 |
| Compose file location: `.devcontainer/docker-compose.yml` | Paths in devcontainer.json resolve relative to `.devcontainer/`; co-location avoids path confusion | Phase 2 |
| Explicit named bridge network (`ai-net`) | Hyphenated auto-generated names break Podman; explicit name required for x-podman compatibility | Phase 2 |
| GPU config via `deploy.resources.reservations.devices` | `device_requests` is deprecated; this form works across Docker Compose v2 and podman-compose | Phase 2 |
| BuildKit GHA cache scoped per model layer | Prevents 30+ min full rebuilds on every CI run for 22GB+ image | Phase 1 |
| SHA256 verification before any image load | Fail-fast on corruption; prevents partial state on the offline machine | Phase 5 |
| CUDA prep as separate script bundled by export | Keeps export script general-purpose; CUDA prep is optional and offline-machine-specific | Phase 4 |
