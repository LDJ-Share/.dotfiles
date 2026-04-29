package main

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

func getConfigCounts(cwd string) ConfigCounts {
	c := ConfigCounts{}

	claudeDir := userClaudeDir()
	userMcps := map[string]struct{}{}
	projMcps := map[string]struct{}{}

	if fileExists(filepath.Join(claudeDir, "CLAUDE.md")) {
		c.ClaudeMd++
	}
	c.Rules += countRulesDir(filepath.Join(claudeDir, "rules"))

	userSettings := filepath.Join(claudeDir, "settings.json")
	for k := range mcpServerNames(userSettings) {
		userMcps[k] = struct{}{}
	}
	c.Hooks += countHooksInFile(userSettings)

	userClaudeJson := claudeDir + ".json"
	for k := range mcpServerNames(userClaudeJson) {
		userMcps[k] = struct{}{}
	}
	for k := range disabledMcps(userClaudeJson, "disabledMcpServers") {
		delete(userMcps, k)
	}

	if cwd != "" {
		if fileExists(filepath.Join(cwd, "CLAUDE.md")) {
			c.ClaudeMd++
		}
		if fileExists(filepath.Join(cwd, "CLAUDE.local.md")) {
			c.ClaudeMd++
		}

		projClaudeDir := filepath.Join(cwd, ".claude")
		sameAsUser := pathsSame(projClaudeDir, claudeDir)

		if !sameAsUser && fileExists(filepath.Join(projClaudeDir, "CLAUDE.md")) {
			c.ClaudeMd++
		}
		if fileExists(filepath.Join(projClaudeDir, "CLAUDE.local.md")) {
			c.ClaudeMd++
		}
		if !sameAsUser {
			c.Rules += countRulesDir(filepath.Join(projClaudeDir, "rules"))
		}

		mcpJson := mcpServerNames(filepath.Join(cwd, ".mcp.json"))

		if !sameAsUser {
			projSettings := filepath.Join(projClaudeDir, "settings.json")
			for k := range mcpServerNames(projSettings) {
				projMcps[k] = struct{}{}
			}
			c.Hooks += countHooksInFile(projSettings)
		}

		localSettings := filepath.Join(projClaudeDir, "settings.local.json")
		for k := range mcpServerNames(localSettings) {
			projMcps[k] = struct{}{}
		}
		c.Hooks += countHooksInFile(localSettings)

		for k := range disabledMcps(localSettings, "disabledMcpjsonServers") {
			delete(mcpJson, k)
		}
		for k := range mcpJson {
			projMcps[k] = struct{}{}
		}
	}

	c.MCP = len(userMcps) + len(projMcps)
	return c
}

func userClaudeDir() string {
	dir := os.Getenv("CLAUDE_CONFIG_DIR")
	if dir == "" {
		home, _ := os.UserHomeDir()
		return filepath.Join(home, ".claude")
	}
	if strings.HasPrefix(dir, "~") {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, strings.TrimPrefix(strings.TrimPrefix(dir, "~/"), "~\\"))
	}
	return dir
}

func mcpServerNames(path string) map[string]struct{} {
	out := map[string]struct{}{}
	raw, err := os.ReadFile(path)
	if err != nil {
		return out
	}
	var cfg struct {
		McpServers map[string]json.RawMessage `json:"mcpServers"`
	}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return out
	}
	for k := range cfg.McpServers {
		out[k] = struct{}{}
	}
	return out
}

func disabledMcps(path, key string) map[string]struct{} {
	out := map[string]struct{}{}
	raw, err := os.ReadFile(path)
	if err != nil {
		return out
	}
	var cfg map[string]json.RawMessage
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return out
	}
	val, ok := cfg[key]
	if !ok {
		return out
	}
	var arr []string
	if err := json.Unmarshal(val, &arr); err != nil {
		return out
	}
	for _, s := range arr {
		out[s] = struct{}{}
	}
	return out
}

func countHooksInFile(path string) int {
	raw, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	var cfg struct {
		Hooks map[string]json.RawMessage `json:"hooks"`
	}
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return 0
	}
	return len(cfg.Hooks)
}

func countRulesDir(dir string) int {
	count := 0
	_ = filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() {
			return nil
		}
		if strings.HasSuffix(strings.ToLower(d.Name()), ".md") {
			count++
		}
		return nil
	})
	return count
}

func fileExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && !info.IsDir()
}

func pathsSame(a, b string) bool {
	abs := func(p string) string {
		ap, err := filepath.Abs(p)
		if err != nil {
			return p
		}
		return ap
	}
	a = filepath.Clean(abs(a))
	b = filepath.Clean(abs(b))
	if runtime.GOOS == "windows" {
		a = strings.ToLower(a)
		b = strings.ToLower(b)
	}
	return a == b
}
