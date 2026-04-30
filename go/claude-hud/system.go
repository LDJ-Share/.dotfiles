package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"golang.org/x/term"
)

// ---------------------------------------------------------------------------
// Terminal width
// ---------------------------------------------------------------------------

func getTerminalWidth() int {
	for _, fd := range []int{int(os.Stdout.Fd()), int(os.Stderr.Fd())} {
		if w, _, err := term.GetSize(fd); err == nil && w > 0 {
			return w
		}
	}
	if v := os.Getenv("COLUMNS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return 120
}

func getAdaptiveBarWidth() int {
	w := getTerminalWidth()
	switch {
	case w >= 100:
		return 10
	case w >= 60:
		return 6
	default:
		return 4
	}
}

// ---------------------------------------------------------------------------
// itoa helper used across files
// ---------------------------------------------------------------------------

func itoa(n int) string { return strconv.Itoa(n) }

// ---------------------------------------------------------------------------
// Claude Code version (best-effort, cached)
// ---------------------------------------------------------------------------

func getClaudeCodeVersion() string {
	cachePath := filepath.Join(userClaudeDir(), "plugins", "claude-hud-go", "cc-version.txt")
	if raw, err := os.ReadFile(cachePath); err == nil {
		parts := strings.SplitN(strings.TrimSpace(string(raw)), "|", 2)
		if len(parts) == 2 {
			ts, err := strconv.ParseInt(parts[0], 10, 64)
			// Cache for 24h.
			if err == nil && time.Now().Unix()-ts < 24*3600 {
				return parts[1]
			}
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 1500*time.Millisecond)
	defer cancel()
	cmd := exec.CommandContext(ctx, "claude", "--version")
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return ""
	}
	v := strings.TrimSpace(out.String())
	// Output looks like "1.0.0 (Claude Code)" — first whitespace-delimited token.
	if i := strings.IndexByte(v, ' '); i > 0 {
		v = v[:i]
	}
	if v != "" {
		_ = os.MkdirAll(filepath.Dir(cachePath), 0o755)
		_ = os.WriteFile(cachePath, []byte(fmt.Sprintf("%d|%s", time.Now().Unix(), v)), 0o644)
	}
	return v
}

// ---------------------------------------------------------------------------
// Speed tracker — persists between invocations to compute output tok/s
// ---------------------------------------------------------------------------

type speedSample struct {
	Output    int       `json:"output"`
	Timestamp time.Time `json:"timestamp"`
}

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
	return filepath.Join(userClaudeDir(), "plugins", "claude-hud-go", "speed-cache", hash+".json")
}

// getOutputSpeed returns tokens/second for output, or nil if not enough data.
func getOutputSpeed(s StdinData) *float64 {
	if s.ContextWindow.CurrentUsage == nil {
		return nil
	}
	current := s.ContextWindow.CurrentUsage.OutputTokens
	now := time.Now().UTC()

	path := speedCachePath(s)
	prev := speedSample{}
	if raw, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(raw, &prev)
	}

	defer func() {
		out := speedSample{Output: current, Timestamp: now}
		if data, err := json.Marshal(out); err == nil {
			_ = os.MkdirAll(filepath.Dir(path), 0o755)
			_ = os.WriteFile(path, data, 0o644)
		}
	}()

	if prev.Timestamp.IsZero() || prev.Output <= 0 {
		return nil
	}
	deltaTokens := current - prev.Output
	deltaSec := now.Sub(prev.Timestamp).Seconds()
	if deltaSec <= 0 || deltaTokens <= 0 {
		return nil
	}
	speed := float64(deltaTokens) / deltaSec
	return &speed
}

// ---------------------------------------------------------------------------
// Custom shell command label (extra-cmd)
// ---------------------------------------------------------------------------

func parseExtraCmdArg() string {
	for i, a := range os.Args {
		if (a == "--cmd" || a == "-c") && i+1 < len(os.Args) {
			return os.Args[i+1]
		}
		if strings.HasPrefix(a, "--cmd=") {
			return strings.TrimPrefix(a, "--cmd=")
		}
	}
	return ""
}

func runExtraCmd(cmdLine string) string {
	if cmdLine == "" {
		return ""
	}
	ctx, cancel := context.WithTimeout(context.Background(), 1500*time.Millisecond)
	defer cancel()

	var c *exec.Cmd
	if runtime.GOOS == "windows" {
		c = exec.CommandContext(ctx, "cmd", "/c", cmdLine)
	} else {
		c = exec.CommandContext(ctx, "sh", "-c", cmdLine)
	}
	var out bytes.Buffer
	c.Stdout = &out
	if err := c.Run(); err != nil {
		return ""
	}
	return strings.TrimSpace(out.String())
}

// ---------------------------------------------------------------------------
// Session duration / reset / elapsed formatters
// ---------------------------------------------------------------------------

func formatSessionDuration(start *time.Time, now time.Time) string {
	if start == nil {
		return ""
	}
	diff := now.Sub(*start)
	mins := int(diff / time.Minute)
	if mins < 1 {
		return "<1m"
	}
	if mins < 60 {
		return fmt.Sprintf("%dm", mins)
	}
	h := mins / 60
	m := mins % 60
	return fmt.Sprintf("%dh %dm", h, m)
}

func formatResetTime(reset *time.Time) string {
	if reset == nil {
		return ""
	}
	diff := time.Until(*reset)
	if diff <= 0 {
		return ""
	}
	mins := int((diff + 59*time.Second) / time.Minute) // ceil to minutes
	if mins < 60 {
		return fmt.Sprintf("%dm", mins)
	}
	hours := mins / 60
	m := mins % 60
	if hours >= 24 {
		days := hours / 24
		rh := hours % 24
		if rh > 0 {
			return fmt.Sprintf("%dd %dh", days, rh)
		}
		return fmt.Sprintf("%dd", days)
	}
	if m > 0 {
		return fmt.Sprintf("%dh %dm", hours, m)
	}
	return fmt.Sprintf("%dh", hours)
}

func formatElapsed(start time.Time, end *time.Time) string {
	endT := time.Now()
	if end != nil {
		endT = *end
	}
	d := endT.Sub(start)
	if d < time.Second {
		return "<1s"
	}
	if d < time.Minute {
		return fmt.Sprintf("%ds", int(d.Seconds()+0.5))
	}
	mins := int(d / time.Minute)
	secs := int((d % time.Minute) / time.Second)
	return fmt.Sprintf("%dm %ds", mins, secs)
}

func formatTokens(n int) string {
	if n >= 1_000_000 {
		return fmt.Sprintf("%.1fM", float64(n)/1_000_000)
	}
	if n >= 1000 {
		return fmt.Sprintf("%dk", n/1000)
	}
	return fmt.Sprintf("%d", n)
}
