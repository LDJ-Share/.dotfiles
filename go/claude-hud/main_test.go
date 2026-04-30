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
