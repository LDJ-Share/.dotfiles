// Package main: claude-hud — single-binary statusline for Claude Code.
//
// Drop-in replacement for the upstream node plugin, suitable for locked-down
// machines where you can copy a self-built .exe but can't install plugins
// through the marketplace. Reads the same config file upstream uses
// (~/.claude/plugins/claude-hud/config.json).
package main

import (
	"fmt"
	"os"
	"runtime"
	"strings"
	"time"
)

func main() {
	stdin := readStdin()
	if stdin == nil {
		fmt.Println("[claude-hud] Initializing...")
		if runtime.GOOS == "darwin" {
			fmt.Println("[claude-hud] Note: On macOS, you may need to restart Claude Code for the HUD to appear.")
		}
		return
	}

	cfg := loadConfig()
	transcript := parseTranscript(stdin.TranscriptPath)
	counts := getConfigCounts(stdin.Cwd)

	var gitStatus *GitStatus
	if cfg.GitStatus.Enabled {
		gitStatus = getGitStatus(stdin.Cwd)
	}

	var usage *UsageData
	if cfg.Display.ShowUsage {
		usage = extractUsage(*stdin)
	}

	var memory *MemoryInfo
	if cfg.Display.ShowMemoryUsage && cfg.LineLayout == "expanded" {
		memory = getMemoryInfo()
	}

	extraCmd := parseExtraCmdArg()
	extraLabel := ""
	if extraCmd != "" {
		extraLabel = runExtraCmd(extraCmd)
	}

	ccVer := ""
	if cfg.Display.ShowClaudeCodeVersion {
		ccVer = getClaudeCodeVersion()
	}

	ctx := &RenderContext{
		Stdin:           *stdin,
		Transcript:      transcript,
		Counts:          counts,
		GitStatus:       gitStatus,
		UsageData:       usage,
		Memory:          memory,
		Config:          cfg,
		SessionDuration: formatSessionDuration(transcript.SessionStart, time.Now().UTC()),
		ExtraLabel:      extraLabel,
		ClaudeCodeVer:   ccVer,
	}

	var out strings.Builder
	render(ctx, &out)
	// Strip the trailing newline so the statusline doesn't add a blank row.
	rendered := strings.TrimRight(out.String(), "\n")
	if rendered != "" {
		fmt.Fprintln(os.Stdout, rendered)
	}
}
