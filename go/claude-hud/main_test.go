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
