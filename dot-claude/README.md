# dot-claude — moved

This was a **naive stow package** that symlinked a Claude Code plugin marketplace into
`~/.claude` before the proper marketplace mechanism existed. It has been **extracted into
its own repo** (Epic #388 Phase 3, Story #396) and is no longer stowed from dotfiles.

## New home

- **Canonical (private):** Azure DevOps `brain/_git/claude-plugin-external`
- **Public mirror:** https://github.com/LDJ-Share/claude-plugin

## Use it

```sh
/plugin marketplace add LDJ-Share/claude-plugin
/plugin install <name>@matt-dotfiles
```

## One-time cleanup on this machine

The old stow symlinks under `~/.claude` are now dangling. Remove them once:

```sh
stow -D -t ~/.claude -d ~/path/to/dotfiles dot-claude   # unstow the old package
# then add the marketplace as above
```
