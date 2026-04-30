package main

// Hardcoded thresholds and modes for claude-hud. These were previously
// HudConfig fields; collapsed to package-level constants per the
// claude-hud-trim spec (2026-04-29).

const (
	pathLevels                = 1
	tokenBreakdownThreshold   = 85
	sevenDayDisplayThreshold  = 80
	usageDisplayMinimum       = 0
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
