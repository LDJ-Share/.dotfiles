# What do you want to build?

In this project, I wanted to build a all-in-one hardened environment for using an AI agentic coding harness offline with local Ollama models that is deployable via a Docker container or build script, in many different scenarios, depending on the level of isolation you need.

  1. Inside a Container inside WSL2
  2. Inside a Container inside a Linux VM
  3. Directly inside an Ubuntu VM

The docker containers will be deployed directly into an air-gapped environment, so we need to make absolutely sure that everything is pre-installed and initialized correctly.

The exposed ports for Ollama came about due to the need to run Ollama on the Windows host due to Hyper-V not being able to utilize the GPU. I would ideally like to support this an option later on, but I am also realistic, and want to get the easiest path accomplished first.

I believe the easiest path forward would be to build a docker-compose file to create a network between the main container with the coding agent installed (where the workspace will be mounted) and an Ollama container, with an internal network to bridge them, to remove the need for a hole in the firewall. So, due to the constraints of being portable to an air-gapped machine, I would like to create an additional Docker container to publish that is based off of ollama/ollama:latest, but will have a couple of opinionated models pre-installed (primarily gemma4 variants: `gemma4:e4b` and `gemma4:e4b`).

I would also like to run the docker-compose file through a dev container.

> Note: The Windows host will have Podman Desktop installed, but not Docker Desktop.

The current, primary use case we want to target for this project is the docker-compose deployment via a dev container. An example use case would go like this:

  1. Copy the example `docker-compose.yml` and `.devcontainer` from this repo
  2. Use `docker pull` to pull down each container from the registry
  3. Use `docker image save` to export the containers as image tar archives to transport them onto the air-gapped machine
  4. Transport docker-compose.yml and the image tar archives to an air-gapped machine
  5. Use `docker image load` to load the images into the local docker instance. (NOTE: this air-gapped machine will not have Docker Desktop installed; we import straight into WSL2)
  6. Place the example `docker-compose.yml` and `.devcontainer` in a workspace for the AI coding agent
  7. Open VS Code on the host, in the workspace, then choose "Reopen in Dev Container" when prompted
  8. Launch `OpenCode` or `Pi` from a terminal within VS Code
  
> Note: after the process is established, we can host a corporate-level harbor server to host the images for other developers to pull from, but let's take this one step at a time.

## References

| Path | Description |
| --- | --- |
| C:\Users\matth\source\repos\claude-code-try-again | An example of an implementation using a dev container with docker compose to launch a dev container with a coding agent with access to ollama. |
| <https://github.com/anthropics/claude-code/tree/main/.devcontainer> | is the original implementation the claude-code-try-again repo was based off of. |
| <https://github.com/anthropics/claude-code/blob/main/Script/run_devcontainer_claude_code.ps1> | An example of running a dev container via powershell, if the user wants to only use a TUI |
