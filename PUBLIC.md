# This repo is PUBLIC

The canonical home of these dotfiles is **private** Azure DevOps
(`TestOrganizationMK/brain/_git/dotfiles`), but `master` is **mirrored verbatim to a public
GitHub repo**: <https://github.com/LDJ-Share/.dotfiles>. Anything committed here can become
public the next time the mirror is pushed.

This is intentional — the dotfiles + the air-gapped AI dev-environment project are a public
showcase. The boundary is therefore a **"no secrets" rule**, not a content split.

## The rule

- **Never commit secrets** — tokens, PATs, private keys, passwords, real internal hostnames/IPs.
- Secret-bearing paths are gitignored and must stay that way: `.mcp.json`, `.serena/`,
  `.claude/settings.local.json`. (`.mcp.json` references `${ADS_PAT}` by env var — never inline it.)
- Keep sample configs templated (e.g. `ssh/ssh-config` uses placeholders like `bastion.domain.com`).

## The guard

A `pre-commit` hook (in `git-hooks/`) runs [gitleaks](https://github.com/gitleaks/gitleaks)
on staged changes and **blocks commits that introduce secrets**. Enable it once per clone:

```sh
git config core.hooksPath "$(pwd)/git-hooks"
```

Install gitleaks so the scan actually runs (otherwise the hook warns and skips):

```sh
# choose one
brew install gitleaks
winget install gitleaks
go install github.com/gitleaks/gitleaks/v8@latest
```

Override the guard only rarely and intentionally: `git commit --no-verify`.

## If a secret does land here

Treat it as compromised: rotate the credential first, then rewrite history
(`git filter-repo`) on **both** the ADS canonical and the public mirror, and force-push.
Deleting the file in a new commit is **not** enough — it stays in history and on the mirror.
