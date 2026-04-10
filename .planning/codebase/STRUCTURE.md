# Repository Structure

## Top-Level Layout

The repository root follows a dotfiles structure using GNU Stow for symlink-based configuration management.

Key directories:
- .devcontainer/ - VS Code remote container
- .github/workflows/ - GitHub Actions CI/CD
- nvim/ - Neovim configuration
- dot-pi/ - Pi agent configuration
- dot-opencode/ - OpenCode agent configuration
- tmux/ - tmux configuration
- zshrc/ - Zsh shell configuration
- tests/container/ - 6 test scripts

Key files:
- Dockerfile - Multi-stage container build
- setup.sh - Ubuntu bootstrap
- firewall-enable.sh - UFW and hardening
- firewall-disable.sh - Maintenance window
- justfile - Common commands
- README.md - Comprehensive guide
- PLAN-container.md - Implementation phases
- TODO.md - Project status

## Stow Layout

Root package (.): -> ~/.config
- nvim/, tmux/, zshrc/, ssh/, television/

Pi package (dot-pi/): -> ~/.pi/agent
- models.json, settings.json

OpenCode package (dot-opencode/): -> ~/.opencode
- config.json, oh-my-opencode.json

## Generated vs Source

Hand-Written (Source):
- All shell scripts: setup.sh, firewall-*.sh
- All dotfiles: nvim/init.lua, tmux/tmux.conf, zshrc/.zshrc
- Config JSONs: models.json, settings.json, config.json
- GitHub Actions workflows
- Dockerfile, justfile, README, PLAN, TODO

Generated (Auto-Built):
- .p10k.zsh - by oh-my-posh
- oh-my-opencode.json - by oh-my-opencode
- .local/share/nvim/lazy/ - by lazy.nvim
- .local/share/nvim/mason/ - by Mason LSP
- .tmux/plugins/tpm/ - by TPM
- .opencode/agents/ - by oh-my-opencode
- .cargo/, .bun/, .dotnet/ - by installers

## Summary

The repository follows a clean dotfiles plus container pattern. All infrastructure-as-code is version-controlled. The entire environment is reproducible via git SHA.
