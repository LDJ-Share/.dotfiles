# claude-hud — trim pass

**Status:** Design approved 2026-04-29
**Successor:** implementation plan via `superpowers:writing-plans`
**Companion spec:** `superpowers-lite` — sibling effort, brainstormed in the
same session.

## Why

`go/claude-hud/` is the in-house Go re-implementation of the upstream Node
statusline plugin. It works, but it carries features we don't use: a memory
RAM bar, a Claude Code version display, a custom-line escape hatch, an
arbitrary-shell `--extra-cmd` argument, ahead/behind arrows, file-stat
counts, a compact-vs-expanded layout switch, a JSON config file with
named/256-color/hex override resolution, and several thresholds nobody
turns. KISS / YAGNI says delete it.

This is a trim pass: same binary, same purpose, narrower feature set, no
config file. After the trim, configuration lives in Go constants — to
change behavior, edit a const and rebuild. Builds are sub-second.

## Scope

**In:**

- Edit existing files at `go/claude-hud/` in place — no rewrite, no file
  collapsing, no architectural reshape.
- Delete `config.go`, `memory_windows.go`, `memory_unix.go`, and the
  untracked `config.json`.
- Strip dead code paths from `main.go`, `render.go`, `colors.go`,
  `system.go`, `git.go`, `types.go`.
- Migrate the speed-cache path from
  `~/.claude/plugins/claude-hud-go/speed-cache/` to
  `~/.claude/cache/claude-hud/speed-cache/`.
- Add `go/claude-hud/main_test.go` — light Go smoke tests.
- Add `tests/test_claude_hud.sh` — bash deployment smoke alongside the
  existing `test_*.sh` files.
- Add a Dockerfile stage that compiles the trimmed binary at image build
  time and drops it on PATH inside the air-gap dev container.

**Out of scope:**

- Rewriting from scratch. Existing structure stays.
- Collapsing files (e.g., merging `colors.go` into `render.go`). The current
  decomposition maps cleanly to functional areas.
- Build-flag-based theme selection. One palette, hardcoded.
- A `--version` / `--help` flag. The binary takes JSON on stdin, prints a
  statusline, exits.
- Backwards compatibility with old `config.json` files. They're ignored.
- Performance benchmarking. Go binaries run in milliseconds.
- Cross-compilation matrix in CI. The container builds in its own Go
  toolchain stage; the host you build natively.

## Architecture & deployment

### Build

`go build` from `go/claude-hud/` produces a single binary. No new
dependencies, no new tooling.

### Deployment paths

1. **Host workstation** — you build on demand and point Claude Code's
   `~/.claude/settings.json` `statusLine.command` at the resulting binary.
   Existing setup, no spec-level change.

2. **Air-gap dev container** — Dockerfile gains a stage:

   ```dockerfile
   # Go-toolchain build stage:
   COPY go/claude-hud /src/claude-hud
   WORKDIR /src/claude-hud
   RUN go build -trimpath -ldflags="-s -w" -o /out/claude-hud .

   # Final stage:
   COPY --from=<gostage> /out/claude-hud /usr/local/bin/claude-hud
   ```

   The final stage doesn't need the Go toolchain — the trimmed binary is
   statically linked. The container's `~/.claude/settings.json` (laid down
   via the same dotfiles bake we use for skills) points
   `statusLine.command` at `/usr/local/bin/claude-hud`.

### Configuration

None at runtime. No `config.json`, no `~/.claude/plugins/...` path
resolution, no env-var lookup for layout / colors / thresholds. All
decisions baked at compile time.

### Update flow

- Host: edit Go source → `go build` → restart Claude Code session.
- Container: edit Go source → image rebuild fires automatically on dotfile
  change → next container start uses the new binary.

### What does NOT change

- Stdin contract — same JSON shape Claude Code already pipes.
- Output contract — same multi-line ANSI text.
- Transcript parsing logic (`transcript.go`).
- Git branch + dirty detection (the `getGitStatus` simplification keeps the
  call patterns).
- Config-counts reading (`counts.go`).
- ANSI-aware width calculations and line wrapping (`wrapLineToWidth`,
  `splitWrapParts`, `fitToWidth`).
- `go.mod` dependencies (`golang.org/x/term`,
  `github.com/mattn/go-runewidth`).

## Trim manifest

### Removed

**Layout**

- Compact layout — `renderCompact()` and the layout dispatcher;
  `renderExpanded` becomes the only path.
- Show-separators logic — was off by default; the separator-drawing code
  in `render()` goes.

**Display elements**

- Memory line — the RAM bar feature in its entirety. `MemoryInfo`,
  `getMemoryInfo()`, `formatBytes()`, `memory_windows.go`, and
  `memory_unix.go` deleted.
- Claude Code version — `getClaudeCodeVersion()` + render line + cached
  version file at `~/.claude/plugins/claude-hud-go/cc-version.txt`.
- Custom line — `CustomLine` field, `cCustom()` helper.
- Extra-command argument — `parseExtraCmdArg()` + `runExtraCmd()` + the
  `--cmd=<shell>` / `-c <shell>` flag (foot-gun: arbitrary shell exec from
  statusline).
- Git file stats — `!N +N ✘N ?N` counts and the `git status --porcelain`
  parsing in `parseFileStats()`.
- Git ahead/behind — `↑N ↓N` arrows; the `rev-list --left-right --count`
  call in `getGitStatus`.

**Configurability**

- Entire config file system: `config.go`, `config.json`, `loadConfig()`,
  `mergeConfig()`, `deepMerge()`, `configPath()`, the `CLAUDE_CONFIG_DIR`
  env-var lookup.
- Color override system: `cfg.colorANSI()`, `resolveColor()`,
  `namedColors`, `hexToANSI()`.
- `pathLevels` knob — collapsed to hardcoded `1`.
- `environmentThreshold` knob — always show env counts when total > 0.
- `usageThreshold` knob — always show usage bars when data is present.

### Stays (the trimmed binary still renders these)

**Project line**

- Model badge — `[Sonnet]` or `[Sonnet | Ollama]` or `[Sonnet | API]`
  when `ANTHROPIC_API_KEY` is set.
- Project path (one level).
- Git branch + dirty marker — `git:(master*)`.
- Session name (when transcript supplies one).
- Speed (`out: 12.3 tok/s`) — always-on.
- Duration (`⏱️ 3m21s`).

**Context line**

- Bar + percent.
- Token breakdown `(in: 12k, cache: 45k)` appended when context ≥ 85%.
- Buffered (auto-compact-aware) percent — the existing default.

**Usage line**

- Full 5h / 7d usage bars with reset times.
- "⚠ Limit reached" message when at 100%.
- Auto-hides when `providerLabel` is set (Ollama / local).

**Environment line**

- Counts: `2 CLAUDE.md | 4 rules | 1 MCPs | 3 hooks` when present.

**Activity lines (below the project/context block)**

- Tools — last 2 running + top 4 most-used completed.
- Agents — running + last 2 completed, max 3 shown.
- Todos — current in-progress + completed count, or "All todos complete"
  sweep.

### Hardcoded thresholds and modes

| Constant | Value | Origin |
|---|---|---|
| `pathLevels` | 1 | Original default |
| `lineLayout` | "expanded" | Q3 |
| `contextValueMode` | "percent" | Original default |
| `autocompactBuffer` | "enabled" | Original default |
| `tokenBreakdownThreshold` | 85 | Q6 (kept) |
| `sevenDayDisplayThreshold` | 80 | Original default |
| `usageDisplayMinimum` | 0 | Always show usage bars when data present |
| `environmentDisplayMinimum` | 0 | Always show env counts when total > 0 |
| `contextWarnPercent` | 70 | Yellow at 70% |
| `contextCriticalPercent` | 85 | Red at 85% |
| `quotaWarnPercent` | 75 | brightMagenta at 75% |
| `quotaCriticalPercent` | 90 | Red at 90% |

### Color palette (hardcoded)

The existing fallback values, inlined:

| Element | ANSI |
|---|---|
| model | cyan |
| project | yellow |
| git delimiters | magenta |
| git branch | cyan |
| label / dim text | dim |
| warning | yellow |
| critical | red |
| context bar | green ≤70%, yellow 70–85%, red ≥85% |
| usage bar | brightBlue ≤75%, brightMagenta 75–90%, red ≥90% |
| running activity icon (◐) | yellow |
| completed activity icon (✓) | green |
| agent type | magenta |
| in-progress todo (▸) | yellow |

## Code structure changes

### Files deleted

| File | Reason |
|---|---|
| `config.go` (~210 lines) | Hardcode-everything — no `HudConfig`, no merge |
| `memory_windows.go` | Memory feature scrapped |
| `memory_unix.go` | Memory feature scrapped |
| `config.json` (untracked) | No runtime config file |

12 .go files → 9.

### Files modified

**`main.go`** — drops config loading, the extra-cmd parse, the memory call,
the CC-version call, and all conditional `if cfg.X.Y { ... }` branches.
`RenderContext` init shrinks from ~10 fields to 6.

**`render.go`** — biggest delta:

- `renderCompact()` deleted.
- Layout dispatcher in `render()` collapses; `renderExpanded` becomes the
  only path (or its body folds into `render` directly — implementation
  choice).
- `renderMemoryLine()` deleted.
- In `renderProjectLine()`: drop the customLine, extraLabel, CC-version,
  file-stats, and ahead/behind branches.
- Separator-drawing branch in `render()` deleted.
- All `cModel(cfg, …)`, `cProject(cfg, …)`, `cLabel(cfg, …)` etc. lose
  their `cfg` parameter.
- `contextColorANSI(percent, cfg)`, `quotaColorANSI(percent, cfg)`,
  `contextBar(…, cfg)`, `quotaBar(…, cfg)` lose their `cfg` parameter.

**`colors.go`** — deletes:

- `hexToANSI()`.
- `clr(cfg, …)`.
- `namedColors` map.
- `resolveColor()`.

The `cXxx()` helpers become direct ANSI wrappers:

```go
func cModel(t string) string   { return wrapColor(t, ansiCyan) }
func cProject(t string) string { return wrapColor(t, ansiYellow) }
// ... etc.
```

**`system.go`** — deletes:

- `getClaudeCodeVersion()` (~33 lines).
- `getMemoryInfo()` (~12 lines).
- `formatBytes()` (~20 lines, only used by memory rendering).
- `parseExtraCmdArg()` (~11 lines).
- `runExtraCmd()` (~20 lines).

Keeps: `getTerminalWidth`, `getAdaptiveBarWidth`, `itoa`, `getOutputSpeed`
+ helpers, the four time/duration formatters, `formatTokens`. ~96 lines
drop; the file stays as a grab-bag of small utilities.

**`git.go`** — simplifies:

- `parseFileStats()` deleted.
- In `getGitStatus()`: drop the file-stats call and the upstream rev-list
  block. Result: just branch + `IsDirty` boolean.

**`types.go`** — slimmed:

- `MemoryInfo` deleted.
- `GitFileStats` deleted.
- `GitStatus` loses `Ahead`, `Behind`, `FileStats` fields.
- `RenderContext` loses `Config`, `Memory`, `ExtraLabel`, `ClaudeCodeVer`
  fields.

**`transcript.go`, `counts.go`, `stdin.go`** — unchanged or trivial
unused-import cleanup.

### Speed-cache path migration

`getOutputSpeed()` writes a per-session cache to compute tokens/sec across
invocations. Today the path is
`~/.claude/plugins/claude-hud-go/speed-cache/<hash>.json`. The
"plugins/claude-hud-go" segment is a leftover from when this called itself
a plugin. Migrate to:

```
~/.claude/cache/claude-hud/speed-cache/<hash>.json
```

Old caches become orphans (a few KB total); no migration needed —
`getOutputSpeed` simply reports nil until enough new samples accumulate.

### New constants block

The hardcoded thresholds and mode strings land as a single `const ( … )`
block, replacing what `defaultConfig()` used to compute. Location is an
implementation detail (`main.go`, `render.go`, or a new tiny `consts.go`)
— the plan picks one.

### Estimated diff

~600 lines deleted, ~30 lines modified, ~10 lines added. Net ~−590.

## Testing & verification

### Layer 1 — Go smoke test (`go/claude-hud/main_test.go`)

Table-driven tests that pipe known stdin JSON and assert *structural*
properties of the output, never byte-exact ANSI. Asserts on stripped
output via the existing `stripANSI()` helper. Cases:

- Output non-empty for minimal valid stdin.
- Model name appears when present in stdin.
- Git branch appears when cwd is a git repo.
- Usage line absent when `providerLabel` is set.
- Token-breakdown `(in: …, cache: …)` appears when context ≥ 85%.
- `formatTokens(12000)` → `"12k"`, `formatTokens(1_200_000)` → `"1.2M"`.
- `formatSessionDuration` / `formatResetTime` / `formatElapsed` round
  correctly at minute/hour/day boundaries.

Roughly 100–150 lines. Runs via `go test ./...` from `go/claude-hud/`.

### Layer 2 — Bash deployment smoke (`tests/test_claude_hud.sh`)

Same pattern as `test_neovim.sh`, `test_pi.sh`. Uses
`tests/container/helpers.sh` (`check_cmd`, `check_file`, `check_contains`,
`summary`). Coverage:

1. `claude-hud` exists at expected path and is executable.
2. `claude-hud` runs without arguments and exits 0 (the "no stdin → print
   init banner" path).
3. `printf '<minimal valid JSON>' | claude-hud` exits 0 and produces
   non-empty output containing the model name.
4. The binary handles a non-git cwd without crashing (`cd /tmp` first).
5. The binary handles a missing transcript path without crashing.

Wires into the existing test runner alongside the other `test_*.sh`
files.

### Layer 3 — Manual verification checklist

Run once after the trim lands; rerun whenever you touch render logic.

- Start a real Claude Code session in a known git repo. Confirm the
  statusline renders all kept elements: model badge, project, git, session
  duration, speed (when there's been output), context bar, tools / agents
  / todos lines.
- Run a session that approaches the context limit (>85%). Confirm the
  token-breakdown `(in: …, cache: …)` appears and the bar turns red.
- Run with `ANTHROPIC_API_KEY` set. Confirm the model badge shows
  `[Sonnet | API]` and usage bars appear.
- Run with `ANTHROPIC_API_KEY` unset and Ollama provider configured.
  Confirm the model badge shows the local provider qualifier and usage
  bars are hidden.
- Resize the terminal narrow. Confirm wrapping at separator boundaries
  works (the existing `wrapLineToWidth` machinery is preserved by the
  trim, but worth confirming it didn't break).
- Run in a directory that's not a git repo. Confirm no git segment
  appears and no errors occur.

### What we explicitly do NOT test

- Byte-exact ANSI output. Fragile; tests assert on stripped output only.
- Cross-platform memory display. Feature is gone.
- Color override resolution. No override system post-trim.
- Performance / latency. Statusline binary runs in milliseconds.
- Backwards compatibility with old `config.json` files. They're ignored.

## Failure modes the tests catch

- Crash on minimal stdin → Layer 2 trips (exit code or empty output).
- Missing kept element after refactor (e.g., forgot to keep `showTools`
  rendering) → Layer 1 trips for that element.
- `formatTokens` regression on K/M boundaries → Layer 1 trips.
- `getOutputSpeed` cache-path bug after migration → Layer 2 trips, or
  manual check trips when speed never appears.
- Build failure after deletion → Layer 1 / Layer 2 both fail to even run.

## Open questions

None at design time. Implementation plan will pin concrete details: the
exact location of the new constants block, the exact Dockerfile stage
placement (which build stage feeds the COPY), and final wording of the
help/banner text printed when stdin is absent.
