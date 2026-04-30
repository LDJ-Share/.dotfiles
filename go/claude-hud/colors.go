package main

import (
	"fmt"
	"math"
	"strconv"
)

const (
	ansiEsc           = "\x1b"
	ansiReset         = "\x1b[0m"
	ansiDim           = "\x1b[2m"
	ansiRed           = "\x1b[31m"
	ansiGreen         = "\x1b[32m"
	ansiYellow        = "\x1b[33m"
	ansiMagenta       = "\x1b[35m"
	ansiCyan          = "\x1b[36m"
	ansiBrightBlue    = "\x1b[94m"
	ansiBrightMagenta = "\x1b[95m"
)

func wrapColor(text, code string) string { return code + text + ansiReset }

func dim(t string) string     { return wrapColor(t, ansiDim) }
func red(t string) string     { return wrapColor(t, ansiRed) }
func green(t string) string   { return wrapColor(t, ansiGreen) }
func yellow(t string) string  { return wrapColor(t, ansiYellow) }
func magenta(t string) string { return wrapColor(t, ansiMagenta) }
func cyan(t string) string    { return wrapColor(t, ansiCyan) }

func hexToANSI(hex string) string {
	if len(hex) != 7 || hex[0] != '#' {
		return ansiReset
	}
	r, err1 := strconv.ParseInt(hex[1:3], 16, 0)
	g, err2 := strconv.ParseInt(hex[3:5], 16, 0)
	b, err3 := strconv.ParseInt(hex[5:7], 16, 0)
	if err1 != nil || err2 != nil || err3 != nil {
		return ansiReset
	}
	return fmt.Sprintf("%s[38;2;%d;%d;%dm", ansiEsc, r, g, b)
}

// ---------------------------------------------------------------------------
// Color helpers that respect HudConfig.Colors overrides
// ---------------------------------------------------------------------------

func clr(cfg *HudConfig, text, key, fallback string) string {
	return wrapColor(text, cfg.colorANSI(key, fallback))
}

func cModel(cfg *HudConfig, t string) string   { return clr(cfg, t, "model", ansiCyan) }
func cProject(cfg *HudConfig, t string) string { return clr(cfg, t, "project", ansiYellow) }
func cGit(cfg *HudConfig, t string) string     { return clr(cfg, t, "git", ansiMagenta) }
func cGitBranch(cfg *HudConfig, t string) string {
	return clr(cfg, t, "gitBranch", ansiCyan)
}
func cLabel(cfg *HudConfig, t string) string   { return clr(cfg, t, "label", ansiDim) }
func cWarning(cfg *HudConfig, t string) string { return clr(cfg, t, "warning", ansiYellow) }
func cCritical(cfg *HudConfig, t string) string { return clr(cfg, t, "critical", ansiRed) }

// Threshold-based colors. The fallback path mirrors upstream.

func contextColorANSI(percent int, cfg *HudConfig) string {
	if percent >= 85 {
		return cfg.colorANSI("critical", ansiRed)
	}
	if percent >= 70 {
		return cfg.colorANSI("warning", ansiYellow)
	}
	return cfg.colorANSI("context", ansiGreen)
}

func quotaColorANSI(percent int, cfg *HudConfig) string {
	if percent >= 90 {
		return cfg.colorANSI("critical", ansiRed)
	}
	if percent >= 75 {
		return cfg.colorANSI("usageWarning", ansiBrightMagenta)
	}
	return cfg.colorANSI("usage", ansiBrightBlue)
}

// ---------------------------------------------------------------------------
// Bars
// ---------------------------------------------------------------------------

func makeBar(percent, width int, color string) string {
	p := math.Min(100, math.Max(0, float64(percent)))
	w := width
	if w < 0 {
		w = 0
	}
	filled := int(math.Round(p / 100 * float64(w)))
	if filled > w {
		filled = w
	}
	empty := w - filled
	return color + repeat("█", filled) + ansiDim + repeat("░", empty) + ansiReset
}

func contextBar(percent, width int, cfg *HudConfig) string {
	return makeBar(percent, width, contextColorANSI(percent, cfg))
}

func quotaBar(percent, width int, cfg *HudConfig) string {
	return makeBar(percent, width, quotaColorANSI(percent, cfg))
}

func repeat(s string, n int) string {
	if n <= 0 {
		return ""
	}
	out := make([]byte, 0, len(s)*n)
	for i := 0; i < n; i++ {
		out = append(out, s...)
	}
	return string(out)
}
