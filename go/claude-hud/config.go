package main

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// HudConfig mirrors the upstream config schema so a single
// ~/.claude/plugins/claude-hud/config.json works for both runtimes.
type HudConfig struct {
	PathLevels     int            `json:"pathLevels"`
	ElementOrder   []string       `json:"elementOrder"`
	GitStatus      GitStatusCfg   `json:"gitStatus"`
	Display        DisplayCfg     `json:"display"`
	Colors         map[string]any `json:"colors"`
}

type GitStatusCfg struct {
	Enabled         bool `json:"enabled"`
	ShowDirty       bool `json:"showDirty"`
}

type DisplayCfg struct {
	ShowModel             bool   `json:"showModel"`
	ShowProject           bool   `json:"showProject"`
	ShowContextBar        bool   `json:"showContextBar"`
	ContextValue          string `json:"contextValue"` // "percent" | "tokens" | "remaining" | "both"
	ShowConfigCounts      bool   `json:"showConfigCounts"`
	ShowDuration          bool   `json:"showDuration"`
	ShowSpeed             bool   `json:"showSpeed"`
	ShowTokenBreakdown    bool   `json:"showTokenBreakdown"`
	ShowUsage             bool   `json:"showUsage"`
	UsageBarEnabled       bool   `json:"usageBarEnabled"`
	ShowTools             bool   `json:"showTools"`
	ShowAgents            bool   `json:"showAgents"`
	ShowTodos             bool   `json:"showTodos"`
	ShowSessionName       bool   `json:"showSessionName"`
	AutocompactBuffer     string `json:"autocompactBuffer"` // "enabled" | "disabled"
	UsageThreshold        int    `json:"usageThreshold"`
	SevenDayThreshold     int    `json:"sevenDayThreshold"`
	EnvironmentThreshold  int    `json:"environmentThreshold"`
}

var defaultElementOrder = []string{
	"project", "context", "usage",
	"environment", "tools", "agents", "todos",
}

// defaultConfig returns the upstream defaults. Any user config is merged on top.
func defaultConfig() *HudConfig {
	return &HudConfig{
		PathLevels:     1,
		ElementOrder:   append([]string{}, defaultElementOrder...),
		GitStatus: GitStatusCfg{
			Enabled:         true,
			ShowDirty:       true,
		},
		Display: DisplayCfg{
			ShowModel:             true,
			ShowProject:           true,
			ShowContextBar:        true,
			ContextValue:          "percent",
			ShowConfigCounts:      true,
			ShowDuration:          true,
			ShowSpeed:             false,
			ShowTokenBreakdown:    true,
			ShowUsage:             true,
			UsageBarEnabled:       true,
			ShowTools:             true,
			ShowAgents:            true,
			ShowTodos:             true,
			ShowSessionName:       false,
			AutocompactBuffer:     "enabled",
			UsageThreshold:        0,
			SevenDayThreshold:     80,
			EnvironmentThreshold:  0,
		},
	}
}

// loadConfig reads the config file (if any) and overlays it on the defaults.
// File path: $CLAUDE_CONFIG_DIR/plugins/claude-hud/config.json (default ~/.claude/...)
func loadConfig() *HudConfig {
	cfg := defaultConfig()

	path := configPath()
	raw, err := os.ReadFile(path)
	if err != nil {
		return cfg
	}

	// We unmarshal into a partial-shape map so missing fields keep defaults.
	// json.Unmarshal into the struct directly would zero-out fields not present.
	overlay := map[string]any{}
	if err := json.Unmarshal(raw, &overlay); err != nil {
		return cfg
	}
	mergeConfig(cfg, overlay)

	if len(cfg.ElementOrder) == 0 {
		cfg.ElementOrder = append([]string{}, defaultElementOrder...)
	}
	if cfg.PathLevels < 1 {
		cfg.PathLevels = 1
	}
	if cfg.PathLevels > 3 {
		cfg.PathLevels = 3
	}
	return cfg
}

func configPath() string {
	dir := os.Getenv("CLAUDE_CONFIG_DIR")
	if dir == "" {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, ".claude")
	}
	return filepath.Join(dir, "plugins", "claude-hud", "config.json")
}

func mergeConfig(cfg *HudConfig, overlay map[string]any) {
	// Re-encode default to JSON, deep-merge overlay, decode back. Cheap and
	// correct; cfg is small.
	base, _ := json.Marshal(cfg)
	merged := map[string]any{}
	_ = json.Unmarshal(base, &merged)
	deepMerge(merged, overlay)
	out, _ := json.Marshal(merged)
	_ = json.Unmarshal(out, cfg)
}

func deepMerge(dst, src map[string]any) {
	for k, v := range src {
		if vm, ok := v.(map[string]any); ok {
			if dvm, ok := dst[k].(map[string]any); ok {
				deepMerge(dvm, vm)
				continue
			}
		}
		dst[k] = v
	}
}

// ---------------------------------------------------------------------------
// Color overrides — named, 256-color index, or hex string.
// ---------------------------------------------------------------------------

func (c *HudConfig) colorANSI(key, fallback string) string {
	if c == nil || c.Colors == nil {
		return fallback
	}
	v, ok := c.Colors[key]
	if !ok {
		return fallback
	}
	return resolveColor(v, fallback)
}

func resolveColor(v any, fallback string) string {
	switch x := v.(type) {
	case string:
		if len(x) == 7 && x[0] == '#' {
			return hexToANSI(x)
		}
		if a, ok := namedColors[x]; ok {
			return a
		}
		return fallback
	case float64:
		n := int(x)
		if n < 0 {
			n = 0
		}
		if n > 255 {
			n = 255
		}
		return ansiEsc + "[38;5;" + itoa(n) + "m"
	}
	return fallback
}

var namedColors = map[string]string{
	"dim":           ansiDim,
	"red":           ansiRed,
	"green":         ansiGreen,
	"yellow":        ansiYellow,
	"magenta":       ansiMagenta,
	"cyan":          ansiCyan,
	"brightBlue":    ansiBrightBlue,
	"brightMagenta": ansiBrightMagenta,
}
