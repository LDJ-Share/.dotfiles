# claude-hud trim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trim ~600 lines of unused code from `go/claude-hud/`, drop the config-file system, hardcode preferred defaults, and bake the resulting binary into the air-gap dev container — without changing any kept behavior.

**Architecture:** Edit the existing Go binary in place (no rewrite). Phase 1 locks current behavior down with smoke tests. Phases 2–4 delete features and the config system, running tests after each delete to catch regressions. Phase 5 migrates one cache path. Phase 6 wires the binary into the Dockerfile. Phase 7 ships a bash deployment smoke. Phase 8 is manual verification.

**Tech Stack:** Go (existing module), bash (test scripts), Dockerfile (container bake). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-04-29-claude-hud-trim-design.md`

---

## File structure

**Modified:**
- `go/claude-hud/main.go` — drop config loading, extra-cmd, memory call, CC-version call, RenderContext fields
- `go/claude-hud/render.go` — drop renderCompact, renderMemoryLine, customLine/extraLabel/CC-version branches, separator path; strip cfg params
- `go/claude-hud/colors.go` — drop hexToANSI, clr, namedColors, resolveColor; cXxx become direct ANSI wrappers
- `go/claude-hud/system.go` — drop getClaudeCodeVersion, getMemoryInfo, formatBytes, parseExtraCmdArg, runExtraCmd; migrate speed-cache path
- `go/claude-hud/git.go` — drop parseFileStats; simplify getGitStatus
- `go/claude-hud/types.go` — drop MemoryInfo, GitFileStats; simplify GitStatus, RenderContext
- `Dockerfile` — add Go-toolchain build stage that compiles the binary; final stage COPYs `/usr/local/bin/claude-hud`

**Created:**
- `go/claude-hud/main_test.go` — table-driven smoke tests for kept behavior
- `go/claude-hud/consts.go` — hardcoded thresholds and modes (replaces `defaultConfig()`)
- `tests/container/test_claude_hud.sh` — bash deployment smoke
- `dot-claude/settings.json` — container-only Claude Code settings with `statusLine.command` pointing at `claude-hud` (NOT stowed to host; host owns its own settings)

**Deleted:**
- `go/claude-hud/config.go`
- `go/claude-hud/memory_windows.go`
- `go/claude-hud/memory_unix.go`
- `go/claude-hud/config.json` (untracked)

---

## Phase 1 — Baseline tests (lock current behavior)

These tests capture behavior the trimmed binary must still produce. They pass on the current binary AND must pass on the trimmed one. Each task adds tests, runs them, expects PASS, commits.

### Task 1: Add Go test scaffolding

**Files:**
- Create: `go/claude-hud/main_test.go`

- [ ] **Step 1: Write the test scaffolding with a stdin-piping helper**

```go
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

// runHud builds (if needed) and runs claude-hud with the given stdin payload,
// returning stripped (no ANSI) output. Tests assert on this.
func runHud(t *testing.T, stdinJSON string) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "claude-hud")
	if runtime.GOOS == "windows" {
		bin += ".exe"
	}
	build := exec.Command("go", "build", "-o", bin, ".")
	build.Stderr = os.Stderr
	if err := build.Run(); err != nil {
		t.Fatalf("go build failed: %v", err)
	}
	cmd := exec.Command(bin)
	cmd.Stdin = strings.NewReader(stdinJSON)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		t.Fatalf("claude-hud run failed: %v", err)
	}
	return stripANSI(out.String())
}

// minimalStdin returns a JSON payload that exercises the kept code paths.
func minimalStdin(t *testing.T) string {
	t.Helper()
	payload := map[string]any{
		"transcript_path": "",
		"cwd":             t.TempDir(),
		"model": map[string]any{
			"id":           "claude-sonnet-4-6",
			"display_name": "Sonnet",
		},
		"context_window": map[string]any{
			"context_window_size": 200000,
			"current_usage": map[string]any{
				"input_tokens":                 5000,
				"output_tokens":                500,
				"cache_creation_input_tokens":  1000,
				"cache_read_input_tokens":      2000,
			},
		},
	}
	b, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal stdin: %v", err)
	}
	return string(b)
}
```

- [ ] **Step 2: Run go vet to confirm the file compiles**

Run: `cd go/claude-hud && go vet ./...`
Expected: exits 0 with no output.

- [ ] **Step 3: Commit**

```bash
git add go/claude-hud/main_test.go
git commit -m "test(claude-hud): add test scaffolding with stdin-piping helper"
```

---

### Task 2: Tests for project line + git rendering

**Files:**
- Modify: `go/claude-hud/main_test.go`

- [ ] **Step 1: Append project + git tests**

Add these test functions to `main_test.go`:

```go
func TestProjectLineShowsModelName(t *testing.T) {
	out := runHud(t, minimalStdin(t))
	if !strings.Contains(out, "Sonnet") {
		t.Errorf("expected model name in output, got:\n%s", out)
	}
}

func TestProjectLineShowsGitBranchInRepo(t *testing.T) {
	repo := t.TempDir()
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"},
		{"-c", "user.email=t@t", "-c", "user.name=t",
			"commit", "--allow-empty", "-q", "-m", "init"},
	} {
		c := exec.Command("git", args...)
		c.Dir = repo
		if err := c.Run(); err != nil {
			t.Skipf("git unavailable in test env: %v", err)
		}
	}

	payload := map[string]any{
		"cwd": repo,
		"model": map[string]any{"id": "claude-sonnet-4-6", "display_name": "Sonnet"},
		"context_window": map[string]any{"context_window_size": 200000},
	}
	b, _ := json.Marshal(payload)
	out := runHud(t, string(b))
	if !strings.Contains(out, "git:(main") {
		t.Errorf("expected git branch in output, got:\n%s", out)
	}
}

func TestProjectLineNoGitOutsideRepo(t *testing.T) {
	payload := map[string]any{
		"cwd": t.TempDir(),
		"model": map[string]any{"id": "claude-sonnet-4-6", "display_name": "Sonnet"},
		"context_window": map[string]any{"context_window_size": 200000},
	}
	b, _ := json.Marshal(payload)
	out := runHud(t, string(b))
	if strings.Contains(out, "git:(") {
		t.Errorf("expected no git segment outside repo, got:\n%s", out)
	}
}
```

- [ ] **Step 2: Run the new tests**

Run: `cd go/claude-hud && go test -run 'TestProjectLine' -v ./...`
Expected: 3 tests, all PASS.

- [ ] **Step 3: Commit**

```bash
git add go/claude-hud/main_test.go
git commit -m "test(claude-hud): cover project line and git rendering"
```

---

### Task 3: Tests for context line + token breakdown threshold

**Files:**
- Modify: `go/claude-hud/main_test.go`

- [ ] **Step 1: Append context tests**

```go
func TestContextLineShowsPercent(t *testing.T) {
	out := runHud(t, minimalStdin(t))
	if !strings.Contains(out, "Context") {
		t.Errorf("expected Context label in output, got:\n%s", out)
	}
	if !strings.Contains(out, "%") {
		t.Errorf("expected percent sign in output, got:\n%s", out)
	}
}

func TestTokenBreakdownAppearsAt85Percent(t *testing.T) {
	// 85% of 200_000 = 170_000 — pile usage above that and confirm the breakdown shows.
	payload := map[string]any{
		"cwd":   t.TempDir(),
		"model": map[string]any{"id": "claude-sonnet-4-6", "display_name": "Sonnet"},
		"context_window": map[string]any{
			"context_window_size": 200000,
			"used_percentage":     90.0,
			"current_usage": map[string]any{
				"input_tokens":                 100_000,
				"output_tokens":                500,
				"cache_creation_input_tokens":  20_000,
				"cache_read_input_tokens":      60_000,
			},
		},
	}
	b, _ := json.Marshal(payload)
	out := runHud(t, string(b))
	if !strings.Contains(out, "in:") || !strings.Contains(out, "cache:") {
		t.Errorf("expected token breakdown at 85%%+, got:\n%s", out)
	}
}

func TestTokenBreakdownAbsentBelow85Percent(t *testing.T) {
	out := runHud(t, minimalStdin(t)) // ~4% usage
	if strings.Contains(out, "in:") && strings.Contains(out, "cache:") {
		t.Errorf("token breakdown should not appear below 85%%, got:\n%s", out)
	}
}
```

- [ ] **Step 2: Run the new tests**

Run: `cd go/claude-hud && go test -run 'TestContextLine|TestTokenBreakdown' -v ./...`
Expected: 3 tests, all PASS.

- [ ] **Step 3: Commit**

```bash
git add go/claude-hud/main_test.go
git commit -m "test(claude-hud): cover context line and token-breakdown threshold"
```

---

### Task 4: Tests for usage line + format helpers

**Files:**
- Modify: `go/claude-hud/main_test.go`

- [ ] **Step 1: Append usage and formatter tests**

```go
func TestUsageLineHiddenWhenNoRateLimits(t *testing.T) {
	out := runHud(t, minimalStdin(t))
	if strings.Contains(out, "Usage") {
		t.Errorf("expected no Usage line without rate_limits, got:\n%s", out)
	}
}

func TestUsageLineShownWith5hRateLimit(t *testing.T) {
	payload := map[string]any{
		"cwd":   t.TempDir(),
		"model": map[string]any{"id": "claude-sonnet-4-6", "display_name": "Sonnet"},
		"context_window": map[string]any{"context_window_size": 200000},
		"rate_limits": map[string]any{
			"five_hour": map[string]any{
				"used_percentage": 50.0,
				"resets_at":       float64(2_000_000_000),
			},
		},
	}
	b, _ := json.Marshal(payload)
	out := runHud(t, string(b))
	if !strings.Contains(out, "Usage") {
		t.Errorf("expected Usage line with rate_limits, got:\n%s", out)
	}
	if !strings.Contains(out, "50%") {
		t.Errorf("expected 50%% in usage line, got:\n%s", out)
	}
}

func TestFormatTokens(t *testing.T) {
	cases := []struct {
		in   int
		want string
	}{
		{42, "42"},
		{1_000, "1k"},
		{12_500, "12k"},
		{1_200_000, "1.2M"},
	}
	for _, c := range cases {
		if got := formatTokens(c.in); got != c.want {
			t.Errorf("formatTokens(%d) = %q; want %q", c.in, got, c.want)
		}
	}
}
```

- [ ] **Step 2: Run the new tests**

Run: `cd go/claude-hud && go test -run 'TestUsageLine|TestFormatTokens' -v ./...`
Expected: 3 tests, all PASS.

- [ ] **Step 3: Run the full test suite to confirm baseline**

Run: `cd go/claude-hud && go test -v ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 4: Commit**

```bash
git add go/claude-hud/main_test.go
git commit -m "test(claude-hud): cover usage line and formatTokens helper"
```

---

## Phase 2 — Delete features

Each task verifies baseline tests pass before deleting, then verifies they still pass after.

### Task 5: Delete memory feature

**Files:**
- Delete: `go/claude-hud/memory_windows.go`
- Delete: `go/claude-hud/memory_unix.go`
- Modify: `go/claude-hud/types.go` (remove `MemoryInfo` struct, remove `Memory *MemoryInfo` from `RenderContext`)
- Modify: `go/claude-hud/system.go` (remove `getMemoryInfo()`, remove `formatBytes()`)
- Modify: `go/claude-hud/render.go` (remove `renderMemoryLine()`, remove `"memory"` case from `renderElement()`, remove `"memory"` from `defaultElementOrder`)
- Modify: `go/claude-hud/main.go` (remove `var memory *MemoryInfo` block and the `Memory: memory` field in RenderContext)
- Modify: `go/claude-hud/config.go` (remove `ShowMemoryUsage` from `DisplayCfg` — note: this file gets deleted entirely in Task 13; for now just remove the field)

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Delete the platform-specific memory files**

```bash
rm go/claude-hud/memory_windows.go go/claude-hud/memory_unix.go
```

- [ ] **Step 3: Remove MemoryInfo from types.go**

In `go/claude-hud/types.go`, delete the entire `MemoryInfo` struct (the block starting `type MemoryInfo struct {`) AND remove the `Memory *MemoryInfo` field from `RenderContext`.

- [ ] **Step 4: Remove memory functions from system.go**

In `go/claude-hud/system.go`, delete `getMemoryInfo()` and `formatBytes()` (lines ~99–131 in current source). The `// Memory info — system RAM` and `// formatBytes` section comments come out too.

- [ ] **Step 5: Remove memory rendering from render.go**

In `go/claude-hud/render.go`:
- Delete the entire `renderMemoryLine()` function.
- Remove the `case "memory":` arm from `renderElement()`.
- Remove `"memory"` from `defaultElementOrder` (in `config.go`, so this part lands in Task 13 — for now just remove from `renderElement`).

- [ ] **Step 6: Remove memory wiring from main.go**

In `go/claude-hud/main.go`, delete the block:
```go
var memory *MemoryInfo
if cfg.Display.ShowMemoryUsage && cfg.LineLayout == "expanded" {
    memory = getMemoryInfo()
}
```
And remove `Memory: memory,` from the `RenderContext{...}` initializer.

- [ ] **Step 7: Remove ShowMemoryUsage from DisplayCfg**

In `go/claude-hud/config.go`, delete the `ShowMemoryUsage bool` field from `DisplayCfg` and the `ShowMemoryUsage: false` line from `defaultConfig()`. Also delete `"memory"` from `defaultElementOrder`.

- [ ] **Step 8: Verify build is clean**

Run: `cd go/claude-hud && go build ./...`
Expected: exits 0 with no output.

- [ ] **Step 9: Run tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 10: Commit**

```bash
git add go/claude-hud/
git commit -m "refactor(claude-hud): drop memory RAM bar feature"
```

---

### Task 6: Delete Claude Code version feature

**Files:**
- Modify: `go/claude-hud/system.go` (remove `getClaudeCodeVersion()`)
- Modify: `go/claude-hud/types.go` (remove `ClaudeCodeVer` field from `RenderContext`)
- Modify: `go/claude-hud/render.go` (remove `ShowClaudeCodeVersion` branch from `renderProjectLine`)
- Modify: `go/claude-hud/main.go` (remove `ccVer` block, remove `ClaudeCodeVer:` field)
- Modify: `go/claude-hud/config.go` (remove `ShowClaudeCodeVersion` from `DisplayCfg`)

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Remove getClaudeCodeVersion from system.go**

In `go/claude-hud/system.go`, delete the entire `getClaudeCodeVersion()` function and its section header comment.

- [ ] **Step 3: Remove ClaudeCodeVer from types.go**

In `go/claude-hud/types.go`, delete the `ClaudeCodeVer string` field from `RenderContext`.

- [ ] **Step 4: Remove the rendering branch**

In `go/claude-hud/render.go`, in `renderProjectLine()`, delete:
```go
if d.ShowClaudeCodeVersion && ctx.ClaudeCodeVer != "" {
    parts = append(parts, cLabel(cfg, "CC v"+ctx.ClaudeCodeVer))
}
```

- [ ] **Step 5: Remove main.go wiring**

In `go/claude-hud/main.go`, delete:
```go
ccVer := ""
if cfg.Display.ShowClaudeCodeVersion {
    ccVer = getClaudeCodeVersion()
}
```
And remove `ClaudeCodeVer: ccVer,` from the `RenderContext{...}` initializer.

- [ ] **Step 6: Remove ShowClaudeCodeVersion from config.go**

In `go/claude-hud/config.go`, delete `ShowClaudeCodeVersion bool` from `DisplayCfg` and `ShowClaudeCodeVersion: false` from `defaultConfig()`.

- [ ] **Step 7: Verify build + tests**

Run: `cd go/claude-hud && go build ./... && go test ./...`
Expected: build clean, 9 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add go/claude-hud/
git commit -m "refactor(claude-hud): drop Claude Code version display"
```

---

### Task 7: Delete custom line + extra-cmd

**Files:**
- Modify: `go/claude-hud/system.go` (remove `parseExtraCmdArg`, `runExtraCmd`)
- Modify: `go/claude-hud/types.go` (remove `ExtraLabel string` from `RenderContext`)
- Modify: `go/claude-hud/colors.go` (remove `cCustom`)
- Modify: `go/claude-hud/render.go` (remove customLine + extraLabel branches in `renderProjectLine`)
- Modify: `go/claude-hud/main.go` (remove `extraCmd`/`extraLabel` block)
- Modify: `go/claude-hud/config.go` (remove `CustomLine string` field)

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Remove extra-cmd functions from system.go**

In `go/claude-hud/system.go`, delete `parseExtraCmdArg()` and `runExtraCmd()` and their section comment header.

- [ ] **Step 3: Remove cCustom from colors.go**

In `go/claude-hud/colors.go`, delete:
```go
func cCustom(cfg *HudConfig, t string) string   { return clr(cfg, t, "custom", "\x1b[38;5;208m") }
```

- [ ] **Step 4: Remove ExtraLabel from types.go**

Delete `ExtraLabel string` from `RenderContext`.

- [ ] **Step 5: Remove rendering branches**

In `go/claude-hud/render.go`, in `renderProjectLine()`, delete:
```go
if ctx.ExtraLabel != "" {
    parts = append(parts, cLabel(cfg, ctx.ExtraLabel))
}
// ... and ...
if d.CustomLine != "" {
    parts = append(parts, cCustom(cfg, d.CustomLine))
}
```

- [ ] **Step 6: Remove main.go wiring**

In `go/claude-hud/main.go`, delete:
```go
extraCmd := parseExtraCmdArg()
extraLabel := ""
if extraCmd != "" {
    extraLabel = runExtraCmd(extraCmd)
}
```
And remove `ExtraLabel: extraLabel,` from the `RenderContext{...}` initializer.

- [ ] **Step 7: Remove CustomLine from config.go**

In `go/claude-hud/config.go`, delete `CustomLine string` field and `CustomLine: ""` default.

- [ ] **Step 8: Verify build + tests**

Run: `cd go/claude-hud && go build ./... && go test ./...`
Expected: build clean, 9 tests PASS.

- [ ] **Step 9: Commit**

```bash
git add go/claude-hud/
git commit -m "refactor(claude-hud): drop customLine and --cmd extra-command argument"
```

---

### Task 8: Delete git file stats + ahead/behind

**Files:**
- Modify: `go/claude-hud/git.go` (remove `parseFileStats`, simplify `getGitStatus`)
- Modify: `go/claude-hud/types.go` (remove `GitFileStats` struct, remove `Ahead`/`Behind`/`FileStats` from `GitStatus`)
- Modify: `go/claude-hud/render.go` (remove file-stats and ahead/behind branches in `renderProjectLine`)
- Modify: `go/claude-hud/config.go` (remove `ShowAheadBehind` and `ShowFileStats` from `GitStatusCfg`)

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Simplify getGitStatus and delete parseFileStats**

In `go/claude-hud/git.go`, replace `getGitStatus` and delete `parseFileStats`. Final shape:

```go
package main

import (
	"bytes"
	"context"
	"os/exec"
	"strings"
	"time"
)

func runGit(cwd string, args ...string) (string, bool) {
	if cwd == "" {
		return "", false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = cwd
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return "", false
	}
	return out.String(), true
}

func getGitStatus(cwd string) *GitStatus {
	if cwd == "" {
		return nil
	}
	branchOut, ok := runGit(cwd, "rev-parse", "--abbrev-ref", "HEAD")
	if !ok {
		return nil
	}
	branch := strings.TrimSpace(branchOut)
	if branch == "" {
		return nil
	}

	g := &GitStatus{Branch: branch}

	if statusOut, ok := runGit(cwd, "--no-optional-locks", "status", "--porcelain"); ok {
		if strings.TrimSpace(statusOut) != "" {
			g.IsDirty = true
		}
	}
	return g
}
```

The `strconv` import is no longer needed.

- [ ] **Step 3: Slim GitStatus and delete GitFileStats in types.go**

In `go/claude-hud/types.go`:

Replace the `GitFileStats` struct + `GitStatus` struct with just:

```go
type GitStatus struct {
	Branch  string
	IsDirty bool
}
```

Delete the entire `GitFileStats` struct.

- [ ] **Step 4: Remove rendering branches**

In `go/claude-hud/render.go`, in `renderProjectLine()`, delete the `cfg.GitStatus.ShowAheadBehind` block and the `cfg.GitStatus.ShowFileStats` block (everything between the `if cfg.GitStatus.ShowAheadBehind { ... }` and the `gitPart = ...` assignment that follows the file-stats branch).

After deletion, the git block in `renderProjectLine` reduces to:
```go
if cfg.GitStatus.Enabled && ctx.GitStatus != nil {
    g := ctx.GitStatus
    branch := g.Branch
    if cfg.GitStatus.ShowDirty && g.IsDirty {
        branch += "*"
    }
    gitPart = cGit(cfg, "git:(") + cGitBranch(cfg, branch) + cGit(cfg, ")")
}
```

- [ ] **Step 5: Remove ShowAheadBehind and ShowFileStats from config.go**

In `go/claude-hud/config.go`, delete `ShowAheadBehind bool` and `ShowFileStats bool` from `GitStatusCfg`. Remove their entries from `defaultConfig()`'s `GitStatus:` block.

- [ ] **Step 6: Verify build + tests**

Run: `cd go/claude-hud && go build ./... && go test ./...`
Expected: build clean, 9 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add go/claude-hud/
git commit -m "refactor(claude-hud): drop git file stats and ahead/behind"
```

---

### Task 9: Delete compact layout + separator drawing

**Files:**
- Modify: `go/claude-hud/render.go` (delete `renderCompact`, simplify `render` to call `renderExpanded` only, drop separator path)
- Modify: `go/claude-hud/config.go` (remove `LineLayout` and `ShowSeparators` fields)

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Delete renderCompact**

In `go/claude-hud/render.go`, delete the entire `renderCompact()` function (the section from `// --- Compact layout ---` header through the closing brace of `renderCompact`).

- [ ] **Step 3: Simplify the top-level render function**

In `go/claude-hud/render.go`, replace `render()` with:

```go
func render(ctx *RenderContext, out *strings.Builder) {
	lines := renderExpanded(ctx)
	termWidth := getTerminalWidth()

	for _, l := range lines {
		for _, physical := range strings.Split(l.line, "\n") {
			for _, wrapped := range wrapLineToWidth(physical, termWidth) {
				out.WriteString(ansiReset)
				out.WriteString(wrapped)
				out.WriteByte('\n')
			}
		}
	}
}
```

This drops both the layout dispatch (no more `if cfg.LineLayout == "compact"`) and the separator drawing block.

- [ ] **Step 4: Remove LineLayout and ShowSeparators from config.go**

In `go/claude-hud/config.go`, delete `LineLayout string` and `ShowSeparators bool` fields from `HudConfig`. Remove their entries from `defaultConfig()`.

- [ ] **Step 5: Verify build + tests**

Run: `cd go/claude-hud && go build ./... && go test ./...`
Expected: build clean, 9 tests PASS.

- [ ] **Step 6: Commit**

```bash
git add go/claude-hud/
git commit -m "refactor(claude-hud): drop compact layout and separator drawing"
```

---

## Phase 3 — Drop config system

### Task 10: Add hardcoded constants block (`consts.go`)

**Files:**
- Create: `go/claude-hud/consts.go`

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Create the constants file**

Create `go/claude-hud/consts.go`:

```go
package main

// Hardcoded thresholds and modes for claude-hud. These were previously
// HudConfig fields; collapsed to package-level constants per the
// claude-hud-trim spec (2026-04-29).

const (
	pathLevels               = 1
	tokenBreakdownThreshold  = 85
	sevenDayDisplayThreshold = 80
	usageDisplayMinimum      = 0
	environmentDisplayMinimum = 0

	contextWarnPercent     = 70
	contextCriticalPercent = 85
	quotaWarnPercent       = 75
	quotaCriticalPercent   = 90
)

// elementOrder is the fixed top-to-bottom order for the expanded layout.
var elementOrder = []string{
	"project", "context", "usage", "environment", "tools", "agents", "todos",
}
```

- [ ] **Step 3: Verify build still clean (the constants aren't referenced yet)**

Run: `cd go/claude-hud && go build ./...`
Expected: exits 0.

- [ ] **Step 4: Commit**

```bash
git add go/claude-hud/consts.go
git commit -m "refactor(claude-hud): add hardcoded constants block (pre-config-deletion)"
```

---

### Task 11: Strip cfg parameter from cXxx color helpers

**Files:**
- Modify: `go/claude-hud/colors.go`

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Replace the cXxx helpers**

In `go/claude-hud/colors.go`, replace the `clr(...)` helper and the `cXxx(cfg, t string)` helpers with direct ANSI wrappers. Final shape of the helpers section:

```go
func cModel(t string) string     { return wrapColor(t, ansiCyan) }
func cProject(t string) string   { return wrapColor(t, ansiYellow) }
func cGit(t string) string       { return wrapColor(t, ansiMagenta) }
func cGitBranch(t string) string { return wrapColor(t, ansiCyan) }
func cLabel(t string) string     { return wrapColor(t, ansiDim) }
func cWarning(t string) string   { return wrapColor(t, ansiYellow) }
func cCritical(t string) string  { return wrapColor(t, ansiRed) }
```

Also delete `clr()`, `hexToANSI()`, `namedColors`, and `resolveColor()` (in `config.go` — that function moves out in Task 13; for now leave it untouched).

Wait: `resolveColor` is referenced from `config.go`'s `colorANSI` method. We're keeping it for one more task (until config.go goes). Leave `hexToANSI`, `namedColors`, `resolveColor` in place for now — they get deleted along with `config.go` in Task 13.

- [ ] **Step 3: Update the threshold-based color functions**

In `go/claude-hud/colors.go`, replace `contextColorANSI` and `quotaColorANSI` to drop their `cfg` parameter and use the new constants:

```go
func contextColorANSI(percent int) string {
	if percent >= contextCriticalPercent {
		return ansiRed
	}
	if percent >= contextWarnPercent {
		return ansiYellow
	}
	return ansiGreen
}

func quotaColorANSI(percent int) string {
	if percent >= quotaCriticalPercent {
		return ansiRed
	}
	if percent >= quotaWarnPercent {
		return ansiBrightMagenta
	}
	return ansiBrightBlue
}
```

- [ ] **Step 4: Update the bar functions to drop cfg**

In `go/claude-hud/colors.go`:

```go
func contextBar(percent, width int) string {
	return makeBar(percent, width, contextColorANSI(percent))
}

func quotaBar(percent, width int) string {
	return makeBar(percent, width, quotaColorANSI(percent))
}
```

- [ ] **Step 5: Verify build fails (cfg-passing callsites in render.go are now broken)**

Run: `cd go/claude-hud && go build ./...`
Expected: BUILD FAILS with errors about wrong number of arguments to cModel/cProject/contextColorANSI/etc. This is intentional — Task 12 fixes the callsites.

- [ ] **Step 6: Commit (tests will not run — expected for this checkpoint)**

```bash
git add go/claude-hud/colors.go
git commit -m "refactor(claude-hud): drop cfg parameter from color and bar helpers"
```

Note: this commit intentionally leaves the build broken; Task 12 fixes the callsites. If you'd rather keep history bisectable, combine Tasks 11+12 into a single commit by skipping this commit step.

---

### Task 12: Update render.go callsites to drop cfg parameter

**Files:**
- Modify: `go/claude-hud/render.go`

- [ ] **Step 1: Update all callsites**

Search-and-replace patterns in `go/claude-hud/render.go`:

| Find | Replace |
|---|---|
| `cModel(cfg, ` | `cModel(` |
| `cProject(cfg, ` | `cProject(` |
| `cGit(cfg, ` | `cGit(` |
| `cGitBranch(cfg, ` | `cGitBranch(` |
| `cLabel(cfg, ` | `cLabel(` |
| `cWarning(cfg, ` | `cWarning(` |
| `cCritical(cfg, ` | `cCritical(` |
| `contextColorANSI(percent, cfg)` | `contextColorANSI(percent)` |
| `contextColorANSI(p, cfg)` | `contextColorANSI(p)` |
| `quotaColorANSI(percent, cfg)` | `quotaColorANSI(percent)` |
| `quotaColorANSI(*percent, cfg)` | `quotaColorANSI(*percent)` |
| `quotaColorANSI(m.UsedPercent, cfg)` | (removed in Task 5; ignore) |
| `contextBar(percent, getAdaptiveBarWidth(), cfg)` | `contextBar(percent, getAdaptiveBarWidth())` |
| `quotaBar(p, barWidth, cfg)` | `quotaBar(p, barWidth)` |
| `quotaBar(m.UsedPercent, getAdaptiveBarWidth(), cfg)` | (removed in Task 5) |

After the replacements, verify no `cfg` param is being passed to color helpers anywhere in `render.go`.

- [ ] **Step 2: Verify build is clean**

Run: `cd go/claude-hud && go build ./...`
Expected: exits 0.

- [ ] **Step 3: Run tests**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add go/claude-hud/render.go
git commit -m "refactor(claude-hud): update render callsites for cfg-less color helpers"
```

---

### Task 13: Delete config.go and config-loading from main.go

**Files:**
- Delete: `go/claude-hud/config.go`
- Delete: `go/claude-hud/config.json` (untracked working-dir file)
- Modify: `go/claude-hud/types.go` (remove `Config *HudConfig` field from `RenderContext`)
- Modify: `go/claude-hud/main.go` (remove `cfg := loadConfig()`; replace remaining cfg-conditional branches with unconditional behavior)
- Modify: `go/claude-hud/render.go` (remove `cfg` param threading throughout; replace `cfg.Display.X` references with their hardcoded equivalents or unconditional behavior)

- [ ] **Step 1: Run baseline tests, expect green**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests, all PASS.

- [ ] **Step 2: Delete config.go and any working-dir config.json**

```bash
rm go/claude-hud/config.go
rm -f go/claude-hud/config.json
```

- [ ] **Step 3: Remove Config field from RenderContext**

In `go/claude-hud/types.go`, delete `Config *HudConfig` from the `RenderContext` struct.

- [ ] **Step 4: Strip cfg loading from main.go**

In `go/claude-hud/main.go`, the trimmed `main()` function looks like this:

```go
func main() {
	stdin := readStdin()
	if stdin == nil {
		fmt.Println("[claude-hud] Initializing...")
		if runtime.GOOS == "darwin" {
			fmt.Println("[claude-hud] Note: On macOS, you may need to restart Claude Code for the HUD to appear.")
		}
		return
	}

	transcript := parseTranscript(stdin.TranscriptPath)
	counts := getConfigCounts(stdin.Cwd)
	gitStatus := getGitStatus(stdin.Cwd)
	usage := extractUsage(*stdin)

	ctx := &RenderContext{
		Stdin:           *stdin,
		Transcript:      transcript,
		Counts:          counts,
		GitStatus:       gitStatus,
		UsageData:       usage,
		SessionDuration: formatSessionDuration(transcript.SessionStart, time.Now().UTC()),
	}

	var out strings.Builder
	render(ctx, &out)
	rendered := strings.TrimRight(out.String(), "\n")
	if rendered != "" {
		fmt.Fprintln(os.Stdout, rendered)
	}
}
```

- [ ] **Step 5: Strip cfg threading from render.go**

In `go/claude-hud/render.go`, remove every `cfg := ctx.Config` and replace `cfg.Display.X` / `cfg.GitStatus.X` / `cfg.PathLevels` references with their hardcoded equivalents:

| Old reference | Replacement |
|---|---|
| `cfg.Display.ShowModel` | `true` (always show) |
| `cfg.Display.ShowProject` | `true` |
| `cfg.Display.ShowContextBar` | `true` |
| `cfg.Display.ContextValue` | `"percent"` literal |
| `cfg.Display.AutocompactBuffer` | `"enabled"` literal |
| `cfg.Display.ShowConfigCounts` | `true` |
| `cfg.Display.ShowDuration` | `true` |
| `cfg.Display.ShowSpeed` | `true` (per Q5 — speed always on) |
| `cfg.Display.ShowTokenBreakdown` | `true` |
| `cfg.Display.ShowUsage` | `true` |
| `cfg.Display.UsageBarEnabled` | `true` |
| `cfg.Display.ShowTools` | `true` |
| `cfg.Display.ShowAgents` | `true` |
| `cfg.Display.ShowAgents` | `true` |
| `cfg.Display.ShowTodos` | `true` |
| `cfg.Display.ShowSessionName` | `true` |
| `cfg.Display.UsageThreshold` | `usageDisplayMinimum` constant |
| `cfg.Display.SevenDayThreshold` | `sevenDayDisplayThreshold` constant |
| `cfg.Display.EnvironmentThreshold` | `environmentDisplayMinimum` constant |
| `cfg.GitStatus.Enabled` | `true` |
| `cfg.GitStatus.ShowDirty` | `true` |
| `cfg.PathLevels` | `pathLevels` constant |
| `cfg.ElementOrder` | `elementOrder` (the variable in `consts.go`) |

For literal `true` replacements, simplify the surrounding `if true { ... }` blocks by removing the `if` and dedenting.

After the replacements: `renderExpanded` no longer takes/uses cfg; `renderProjectLine` no longer takes/uses cfg; `render` doesn't extract cfg.

- [ ] **Step 6: Verify build is clean**

Run: `cd go/claude-hud && go build ./...`
Expected: exits 0. If unresolved cfg references remain, the compiler will name them — fix and re-run.

- [ ] **Step 7: Run tests**

Run: `cd go/claude-hud && go test ./...`
Expected: 9 tests PASS. The output should be visually identical to before (we only collapsed config indirections).

- [ ] **Step 8: Commit**

```bash
git add go/claude-hud/
git commit -m "refactor(claude-hud): delete config system; behavior baked at compile time"
```

---

## Phase 4 — Speed-cache path migration

### Task 14: Migrate speed-cache path

**Files:**
- Modify: `go/claude-hud/system.go`

- [ ] **Step 1: Update speedCachePath**

In `go/claude-hud/system.go`, replace the existing `speedCachePath` body. New shape:

```go
func speedCachePath(s StdinData) string {
	key := s.TranscriptPath
	if key == "" {
		key = s.Cwd
	}
	if key == "" {
		key = "default"
	}
	sum := sha256.Sum256([]byte(key))
	hash := hex.EncodeToString(sum[:])
	return filepath.Join(userClaudeDir(), "cache", "claude-hud", "speed-cache", hash+".json")
}
```

- [ ] **Step 2: Verify build + tests**

Run: `cd go/claude-hud && go build ./... && go test ./...`
Expected: build clean, 9 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add go/claude-hud/system.go
git commit -m "refactor(claude-hud): migrate speed-cache to ~/.claude/cache/claude-hud/"
```

---

## Phase 5 — Container deployment

### Task 15: Add Go build stage and binary COPY to Dockerfile

**Files:**
- Modify: `Dockerfile`

- [ ] **Step 1: Inspect existing Dockerfile structure**

Run: `grep -n 'FROM\|COPY --from=builder-go' Dockerfile`
Expected: a `builder-go` stage is already present at line ~187. The `assembler` stage (~line 229) collects builder outputs.

- [ ] **Step 2: Add a new builder stage compiling claude-hud**

In `Dockerfile`, add this stage AFTER `builder-go` and BEFORE `assembler`:

```dockerfile
# ─────────────────────────────────────────────────────────────────────────────
# claude-hud — statusline binary, built from in-repo Go source
# ─────────────────────────────────────────────────────────────────────────────
FROM base AS builder-claude-hud
COPY --from=builder-go /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
COPY go/claude-hud /src/claude-hud
WORKDIR /src/claude-hud
RUN go build -trimpath -ldflags="-s -w" -o /out/claude-hud .
```

- [ ] **Step 3: Add the COPY into the assembler or final stage**

In `Dockerfile`, find the `final` stage (~line 284) and add this `COPY` directive (place it among the other `COPY --from=builder-...` lines):

```dockerfile
COPY --from=builder-claude-hud /out/claude-hud /usr/local/bin/claude-hud
```

- [ ] **Step 4: Verify the Dockerfile parses (no actual build needed yet)**

Run: `docker build --no-cache=false --target builder-claude-hud -t test-claude-hud-build .`
Expected: builds the new stage successfully and produces `/out/claude-hud` inside the image.

If Docker isn't available locally, skip this step and rely on CI to catch parse errors on push.

- [ ] **Step 5: Commit**

```bash
git add Dockerfile
git commit -m "feat(container): bake claude-hud statusline binary into image"
```

---

### Task 16: Container settings.json points to claude-hud

**Files:**
- Create: `dot-claude/settings.json`
- Modify: `Dockerfile` (add COPY for the settings file)

- [ ] **Step 1: Create the container settings.json**

Create `dot-claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "claude-hud"
  }
}
```

- [ ] **Step 2: Add the COPY to Dockerfile final stage**

In `Dockerfile`'s `final` stage, add (alongside the binary COPY):

```dockerfile
COPY dot-claude/settings.json /home/dev/.claude/settings.json
RUN chown dev:dev /home/dev/.claude/settings.json
```

- [ ] **Step 3: Note for superpowers-lite later**

This `dot-claude/settings.json` is currently container-only. When `superpowers-lite` lands, the same file may grow with skill-related entries. The host's existing `~/.claude/settings.json` is NOT touched (per the spec's "host CLAUDE.md conflict" decision: container-only).

Add `--ignore=settings.json` to `dot-claude/.stowrc` when that file is created in the superpowers-lite plan. For now, since `dot-claude/.stowrc` doesn't exist yet, no stow conflict can occur.

- [ ] **Step 4: Commit**

```bash
git add dot-claude/settings.json Dockerfile
git commit -m "feat(container): wire claude-hud into container's claude-code settings"
```

---

## Phase 6 — Bash deployment smoke

### Task 17: Add `tests/container/test_claude_hud.sh`

**Files:**
- Create: `tests/container/test_claude_hud.sh`

- [ ] **Step 1: Create the test script**

Create `tests/container/test_claude_hud.sh`:

```bash
#!/usr/bin/env bash
# test_claude_hud.sh — verify the trimmed claude-hud statusline binary
set -uo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== claude-hud: binary exists and runs ==="

check_cmd claude-hud

# Without stdin, claude-hud prints an init banner and exits 0.
check "no-stdin path exits 0" claude-hud

echo "=== claude-hud: renders minimal stdin ==="

# Build a minimal stdin payload.
read -r -d '' STDIN <<'JSON' || true
{"transcript_path":"","cwd":"/tmp","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"context_window_size":200000}}
JSON

OUTPUT=$(printf '%s' "$STDIN" | claude-hud 2>&1)
RC=$?

if [[ $RC -ne 0 ]]; then
  echo "  FAIL: claude-hud exited $RC on minimal stdin"
  ((FAIL++)) || true
else
  echo "  PASS: claude-hud exits 0 on minimal stdin"
  ((PASS++)) || true
fi

if [[ -z "$OUTPUT" ]]; then
  echo "  FAIL: claude-hud produced no output"
  ((FAIL++)) || true
else
  echo "  PASS: claude-hud produced output"
  ((PASS++)) || true
fi

if echo "$OUTPUT" | grep -q "Sonnet"; then
  echo "  PASS: output contains model name"
  ((PASS++)) || true
else
  echo "  FAIL: output missing model name"
  ((FAIL++)) || true
fi

echo "=== claude-hud: handles non-git cwd without crashing ==="

NON_GIT_CWD=$(mktemp -d)
read -r -d '' STDIN_NOGIT <<JSON || true
{"transcript_path":"","cwd":"$NON_GIT_CWD","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"context_window_size":200000}}
JSON
printf '%s' "$STDIN_NOGIT" | claude-hud >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo "  PASS: handles non-git cwd"
  ((PASS++)) || true
else
  echo "  FAIL: crashed on non-git cwd"
  ((FAIL++)) || true
fi
rm -rf "$NON_GIT_CWD"

echo "=== claude-hud: handles missing transcript path ==="

# transcript_path = "" already covered above; also test when it's set but bogus.
read -r -d '' STDIN_BADXP <<JSON || true
{"transcript_path":"/nonexistent/path.jsonl","cwd":"/tmp","model":{"id":"claude-sonnet-4-6","display_name":"Sonnet"},"context_window":{"context_window_size":200000}}
JSON
printf '%s' "$STDIN_BADXP" | claude-hud >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  echo "  PASS: handles missing transcript path"
  ((PASS++)) || true
else
  echo "  FAIL: crashed on missing transcript path"
  ((FAIL++)) || true
fi

summary
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/container/test_claude_hud.sh
```

- [ ] **Step 3: Run it locally if `claude-hud` is on PATH (skip otherwise)**

Run: `bash tests/container/test_claude_hud.sh`
Expected: all checks PASS, exit 0. If `claude-hud` isn't on host PATH yet, this is fine — the test runs inside the container post-bake.

- [ ] **Step 4: Commit**

```bash
git add tests/container/test_claude_hud.sh
git commit -m "test(claude-hud): add bash deployment smoke for container"
```

---

### Task 18: Wire test_claude_hud.sh into run_all.sh

**Files:**
- Modify: `tests/container/run_all.sh`

- [ ] **Step 1: Read the current runner**

Run: `cat tests/container/run_all.sh`
Expected: a shell script that sources or invokes each `test_*.sh` in sequence and aggregates results.

- [ ] **Step 2: Add test_claude_hud.sh to the runner**

Append (or insert alongside the existing `test_*.sh` invocations) a line invoking the new test. The exact pattern depends on what `run_all.sh` looks like — preserve its existing convention (e.g., if other tests are listed in a TESTS=( ... ) array, add `test_claude_hud.sh`; if each is invoked in a sequential block, add another invocation block).

- [ ] **Step 3: Run the full test suite**

Run: `bash tests/container/run_all.sh`
Expected: all existing tests plus the new claude-hud test PASS.

If running in the host (not container), skip — this gates on the post-bake container.

- [ ] **Step 4: Commit**

```bash
git add tests/container/run_all.sh
git commit -m "test(claude-hud): wire claude-hud test into run_all.sh"
```

---

## Phase 7 — Final verification

### Task 19: Manual verification checklist

**Files:** none (manual run-through)

This is a manual gate. Run each item, mark complete only when verified.

- [ ] **Step 1: Run the full Go test suite**

Run: `cd go/claude-hud && go vet ./... && go test ./...`
Expected: 9 tests PASS, no vet warnings.

- [ ] **Step 2: Build a release binary and inspect size**

Run: `cd go/claude-hud && go build -trimpath -ldflags="-s -w" -o /tmp/claude-hud .`
Expected: builds; binary size should be modestly smaller than pre-trim (the trim removed ~600 LOC, but most of the binary is the runtime; expect a few hundred KB delta).

- [ ] **Step 3: Smoke the binary against real Claude Code**

Point `~/.claude/settings.json`'s `statusLine.command` at `/tmp/claude-hud` and start a Claude Code session in a known git repo.

Verify visually:
- Project line shows model badge, project path, git branch + dirty marker, session name (if present), speed (after some output), duration.
- Context line shows bar and percent.
- Token breakdown `(in: …, cache: …)` appears when context ≥ 85%.
- Usage line appears when `ANTHROPIC_API_KEY` is set; hidden when running on Ollama/local.
- Environment counts appear when there are CLAUDE.md files / rules / MCPs / hooks in the project.
- Tools / agents / todos lines render when activity exists.

- [ ] **Step 4: Smoke narrow terminal**

Resize terminal to ~60 columns. Verify lines wrap at `│` separators rather than mid-token.

- [ ] **Step 5: Smoke non-git directory**

`cd /tmp && claude-code` — verify no git segment appears, no errors.

- [ ] **Step 6: If everything passed, this plan is done.** No commit needed for manual verification.

---

## Self-review

**Spec coverage:**
- ✓ Trim manifest "Removed" → Tasks 5–9, 13.
- ✓ Trim manifest "Stays" → preserved by tests in Tasks 1–4 + the deletion plan touching only the removed paths.
- ✓ Hardcoded thresholds → Task 10 (constants block) + Task 13 (replacement of cfg references).
- ✓ Color palette → Task 11 (cXxx direct wrappers).
- ✓ File deletions → Tasks 5 (memory_*.go), 13 (config.go, config.json).
- ✓ Speed-cache path migration → Task 14.
- ✓ Container deployment → Tasks 15, 16.
- ✓ Layer 1 Go smoke tests → Tasks 1–4.
- ✓ Layer 2 bash deployment smoke → Tasks 17, 18.
- ✓ Layer 3 manual verification → Task 19.
- ✓ "What does NOT change" — preserved implicitly (no task touches transcript.go, counts.go, stdin.go, the wrap/fit logic in render.go, or go.mod).

**Placeholder scan:** None found. Every code-modifying step shows the actual code; every command shows the actual command. The Task 18 "preserve its existing convention" wording is the closest thing to vagueness — that's because `run_all.sh` may be a list, a loop, or a sequence of explicit calls; the engineer should match whatever's there. The spec for Task 18 is honest about that.

**Type consistency:** `GitStatus` is simplified consistently in Task 8 (drop `Ahead`, `Behind`, `FileStats`). `RenderContext` shrinks consistently across Tasks 5, 6, 7, 13. The `cXxx()` helpers consistently lose the `cfg` parameter in Tasks 11+12.

**Known cross-task ordering hazard:** Task 11 leaves the build broken intentionally (color helpers' signatures changed; render.go callsites still use the old signature). Task 12 fixes the callsites. The plan flags this in Task 11 Step 6. Bisect-discipline workers should fold Tasks 11+12 into one commit; the plan accommodates either choice.

---

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-29-claude-hud-trim.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task; review between tasks; fast iteration. Per Matt's `feedback_subagent_workflow.md`, most of these tasks are mechanical-tier (haiku candidates) — small batched dispatches.

**2. Inline Execution** — execute tasks in this session using `executing-plans`; batch execution with checkpoints for review.

Which approach?
