# https://just.systems

default:
	@just --list

synclocal:
	git push local master

stow:
	stow .

# ── Setup ─────────────────────────────────────────────────────────────────────

# Bootstrap VM host environment (docker + container pull)
install:
	bash setup.sh

# Full install for non-containerized use — installs all dev tools locally (skips container pull)
install-full:
	bash setup.sh --only system docker podman neovim shell kubernetes languages dev-tools vscode claude opencode pi dotfiles

# Run specific modules only (e.g. just install-only docker neovim)
install-only *modules:
	bash setup.sh --only {{modules}}

# ── Container ─────────────────────────────────────────────────────────────────

# Build the container image locally
build:
	docker build -t dev-env:local .

# Build then run the full test suite
test: build
	docker run --rm \
		-v "$(pwd)/tests/container:/tests/container:ro" \
		dev-env:local \
		bash /tests/container/run_all.sh

# Run a single test script against the locally built image (e.g. just test-one test_neovim.sh)
test-one script: build
	docker run --rm \
		-v "$(pwd)/tests/container:/tests/container:ro" \
		dev-env:local \
		bash /tests/container/{{script}}

# Open an interactive shell in the locally built container with workspace mounted
dev:
	docker run -it --rm \
		-v "$(pwd):/workspace" \
		dev-env:local
