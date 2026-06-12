# plugin-self-improvement

Continuous self-improvement for the Claude Code plugin collection. It turns
**"aha" moments** — realizations, epiphanies, contradictions-with-reality, "this
skill should have told me X" — into **durable, tracked work items** before they
evaporate, the same drive-by way you'd file a discovered bead or a `/notify`.

This is the portable, **beads-backed** variant (matt-dotfiles). Captured insights
become **beads labeled `plugin-improvement`**, filed under a long-lived
**self-improvement epic bead** (discovered by the `plugin-self-improvement` label).
The **ADS-backed** counterpart in the matt-plugins marketplace files User Stories
under Feature #310 instead.

## Contents

| Kind | Names |
|---|---|
| **skill** | `capture-plugin-insight` — triggers on a realization/epiphany/contradiction about a plugin (improve · correct · reinforce-shortcut · fix-contradiction · new-plugin · consolidate), applies a worth-it filter, dedups, and files one bead under the epic. |
| **command** | `/improve-plugin <insight>` — the deliberate, explicit entry point; runs the same capture/dedup/file flow. |
| **hook** | `SessionStart` → a one-line reminder that the capability exists (portable, so ungated; kept to a single line). Fail-open. |

## One-time setup

Create the epic bead once, in the beads database you use for plugin/meta work
(server-mode or a dedicated hub repo — **not** a throwaway `--stealth` work-repo db,
since this is long-term filing):

```bash
bd create "Plugin self-improvement (continuous)" -t epic -l plugin-self-improvement
```

The skill and command discover it by the `plugin-self-improvement` label, so its id
is never hard-coded. Each captured insight is a `plugin-improvement`-labeled bead
`bd dep add`'d under this epic.

## How it works

The skill's `description` is written to fire the moment you notice something about
the *plugins themselves* (not the current task's code). It then **filters** (durable
+ actionable + about the plugins), **classifies** (one reason tag), **dedups**
against existing `plugin-improvement` beads, and **files one bead** under the epic
with a structured body (insight / reason / affected / proposed change / evidence /
captured-from). Triage and execution happen later through the normal orchestrator
flow — capture never starts implementing.

The point is **capture without derailing**: file the bead, note its id, return to
what you were doing.

## Recommended permissions

This plugin only runs `bd` (read for dedup + the epic lookup, write to create/link
one bead). For an unattended session, allowlist `bd` so capture doesn't block on a
prompt; keep the **safety-net deny** in every tier. Rules evaluate
**deny → ask → allow**; *deny always wins*.

### Safety-net deny — include in EVERY tier

```json
{
  "permissions": {
    "deny": [
      "Read(.env)", "Edit(.env)",
      "Read(.env*)", "Edit(.env*)",
      "Read(**/secrets/**)", "Edit(**/secrets/**)",
      "Read(**/*.pem)", "Edit(**/*.pem)",
      "Read(**/*.key)", "Edit(**/*.key)",
      "Read(**/*.pfx)", "Edit(**/*.pfx)",
      "Read(**/id_rsa*)", "Edit(**/id_rsa*)",
      "Read(~/.ssh/**)", "Edit(~/.ssh/**)",
      "Read(~/.aws/**)", "Edit(~/.aws/**)",
      "Read(~/.config/gh/**)", "Edit(~/.config/gh/**)",
      "Edit(**/.git/**)",
      "Bash(rm -rf:*)", "Bash(rm -fr:*)",
      "Bash(sudo:*)",
      "Bash(curl:*)", "Bash(wget:*)",
      "Bash(git push --force:*)", "Bash(git push -f:*)"
    ]
  }
}
```

### Low risk — capture unattended

```json
{
  "permissions": {
    "allow": [
      "Bash(bd:*)"
    ]
  }
}
```

### Medium / High risk — review each capture

```json
{
  "permissions": {
    "allow": [
      "Bash(bd list:*)", "Bash(bd show:*)", "Bash(bd ready:*)"
    ],
    "ask": [
      "Bash(bd create:*)", "Bash(bd update:*)", "Bash(bd dep:*)"
    ]
  }
}
```

> Each tier = the safety-net `deny` **plus** the `allow`/`ask` shown; merge the two
> JSON blocks. Anything matched by no rule prompts by default.

## Install

Ships in the dotfiles `matt-dotfiles` marketplace
(`dot-claude/.claude-plugin/marketplace.json`).
