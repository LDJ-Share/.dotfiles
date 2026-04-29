package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// Internal cache file; not the same shape as the upstream node plugin so they
// can coexist without trampling each other's caches.
type transcriptCacheFile struct {
	TranscriptPath string         `json:"transcriptPath"`
	MtimeUnixNano  int64          `json:"mtimeUnixNano"`
	Size           int64          `json:"size"`
	Data           TranscriptData `json:"data"`
}

func parseTranscript(path string) TranscriptData {
	empty := TranscriptData{}
	if path == "" {
		return empty
	}
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		return empty
	}

	if cached, ok := readTranscriptCache(path, info); ok {
		return cached
	}

	data, ok := parseTranscriptFile(path)
	if ok {
		writeTranscriptCache(path, info, data)
	}
	return data
}

type orderedTool struct {
	entry ToolEntry
	ord   int
}
type orderedAgent struct {
	entry AgentEntry
	ord   int
}

func parseTranscriptFile(path string) (TranscriptData, bool) {
	f, err := os.Open(path)
	if err != nil {
		return TranscriptData{}, false
	}
	defer f.Close()

	tools := map[string]*orderedTool{}
	agents := map[string]*orderedAgent{}
	todos := []TodoItem{}
	taskIndex := map[string]int{}

	var sessionStart *time.Time
	var customTitle, latestSlug string
	cleanParse := true
	ord := 0

	scanner := bufio.NewScanner(f)
	// Some transcripts have very long lines (large tool inputs). Bump the buffer.
	scanner.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)

	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) == 0 {
			continue
		}
		var entry TranscriptEntry
		if err := json.Unmarshal(line, &entry); err != nil {
			continue // skip malformed lines, mirroring upstream
		}

		ts, hasTs := parseTimestamp(entry.Timestamp)
		if hasTs && sessionStart == nil {
			t := ts
			sessionStart = &t
		}

		if entry.Type == "custom-title" && entry.CustomTitle != "" {
			customTitle = entry.CustomTitle
		} else if entry.Slug != "" {
			latestSlug = entry.Slug
		}

		if entry.Message == nil {
			continue
		}

		for _, b := range entry.Message.Content {
			if b.Type == "tool_use" && b.ID != "" && b.Name != "" {
				processToolUse(b, ts, &ord, tools, agents, &todos, taskIndex)
			} else if b.Type == "tool_result" && b.ToolUseID != "" {
				if t, ok := tools[b.ToolUseID]; ok {
					if b.IsError {
						t.entry.Status = "error"
					} else {
						t.entry.Status = "completed"
					}
					et := ts
					t.entry.EndTime = &et
				}
				if a, ok := agents[b.ToolUseID]; ok {
					a.entry.Status = "completed"
					et := ts
					a.entry.EndTime = &et
				}
			}
		}
	}
	if err := scanner.Err(); err != nil {
		cleanParse = false
	}

	// Sort by insertion order, keep last 20 tools and 10 agents.
	toolList := make([]*orderedTool, 0, len(tools))
	for _, v := range tools {
		toolList = append(toolList, v)
	}
	sort.Slice(toolList, func(i, j int) bool { return toolList[i].ord < toolList[j].ord })
	if len(toolList) > 20 {
		toolList = toolList[len(toolList)-20:]
	}

	agentList := make([]*orderedAgent, 0, len(agents))
	for _, v := range agents {
		agentList = append(agentList, v)
	}
	sort.Slice(agentList, func(i, j int) bool { return agentList[i].ord < agentList[j].ord })
	if len(agentList) > 10 {
		agentList = agentList[len(agentList)-10:]
	}

	td := TranscriptData{
		Tools:        make([]ToolEntry, len(toolList)),
		Agents:       make([]AgentEntry, len(agentList)),
		Todos:        todos,
		SessionStart: sessionStart,
	}
	for i, t := range toolList {
		td.Tools[i] = t.entry
	}
	for i, a := range agentList {
		td.Agents[i] = a.entry
	}
	if customTitle != "" {
		td.SessionName = customTitle
	} else {
		td.SessionName = latestSlug
	}

	return td, cleanParse
}

func processToolUse(
	b ContentBlock, ts time.Time, ord *int,
	tools map[string]*orderedTool,
	agents map[string]*orderedAgent,
	todos *[]TodoItem,
	taskIndex map[string]int,
) {
	switch b.Name {
	case "Task":
		var in struct {
			SubagentType string `json:"subagent_type"`
			Model        string `json:"model"`
			Description  string `json:"description"`
		}
		_ = json.Unmarshal(b.Input, &in)
		ag := AgentEntry{
			ID:          b.ID,
			Type:        firstNonEmpty(in.SubagentType, "unknown"),
			Model:       in.Model,
			Description: in.Description,
			Status:      "running",
			StartTime:   ts,
		}
		*ord++
		agents[b.ID] = &orderedAgent{entry: ag, ord: *ord}
	case "TodoWrite":
		var in struct {
			Todos []TodoItem `json:"todos"`
		}
		if err := json.Unmarshal(b.Input, &in); err == nil && in.Todos != nil {
			*todos = (*todos)[:0]
			for k := range taskIndex {
				delete(taskIndex, k)
			}
			*todos = append(*todos, in.Todos...)
		}
	case "TaskCreate":
		var in struct {
			Subject     string `json:"subject"`
			Description string `json:"description"`
			Status      string `json:"status"`
			TaskID      any    `json:"taskId"`
		}
		_ = json.Unmarshal(b.Input, &in)
		content := firstNonEmpty(in.Subject, in.Description, "Untitled task")
		status := normalizeTaskStatus(in.Status)
		if status == "" {
			status = "pending"
		}
		*todos = append(*todos, TodoItem{Content: content, Status: status})
		key := stringOrEmpty(in.TaskID)
		if key == "" {
			key = b.ID
		}
		taskIndex[key] = len(*todos) - 1
	case "TaskUpdate":
		var in struct {
			TaskID      any    `json:"taskId"`
			Subject     string `json:"subject"`
			Description string `json:"description"`
			Status      string `json:"status"`
		}
		_ = json.Unmarshal(b.Input, &in)
		idx, ok := resolveTaskIndex(in.TaskID, taskIndex, len(*todos))
		if !ok {
			return
		}
		if s := normalizeTaskStatus(in.Status); s != "" {
			(*todos)[idx].Status = s
		}
		if c := firstNonEmpty(in.Subject, in.Description); c != "" {
			(*todos)[idx].Content = c
		}
	default:
		entry := ToolEntry{
			ID:        b.ID,
			Name:      b.Name,
			Target:    extractToolTarget(b.Name, b.Input),
			Status:    "running",
			StartTime: ts,
		}
		*ord++
		tools[b.ID] = &orderedTool{entry: entry, ord: *ord}
	}
}

func extractToolTarget(name string, raw json.RawMessage) string {
	if len(raw) == 0 {
		return ""
	}
	var obj map[string]any
	if err := json.Unmarshal(raw, &obj); err != nil {
		return ""
	}
	switch name {
	case "Read", "Write", "Edit":
		if v, ok := obj["file_path"].(string); ok {
			return v
		}
		if v, ok := obj["path"].(string); ok {
			return v
		}
	case "Glob", "Grep":
		if v, ok := obj["pattern"].(string); ok {
			return v
		}
	case "Bash":
		if cmd, ok := obj["command"].(string); ok {
			if len(cmd) > 30 {
				return cmd[:30] + "..."
			}
			return cmd
		}
	}
	return ""
}

func normalizeTaskStatus(s string) string {
	switch s {
	case "pending", "not_started":
		return "pending"
	case "in_progress", "running":
		return "in_progress"
	case "completed", "complete", "done":
		return "completed"
	}
	return ""
}

func resolveTaskIndex(raw any, taskIndex map[string]int, todoCount int) (int, bool) {
	key := stringOrEmpty(raw)
	if key == "" {
		return 0, false
	}
	if idx, ok := taskIndex[key]; ok {
		return idx, true
	}
	if isAllDigits(key) {
		var n int
		_, err := fmtScanInt(key, &n)
		if err == nil && n >= 1 && n <= todoCount {
			return n - 1, true
		}
	}
	return 0, false
}

func parseTimestamp(s string) (time.Time, bool) {
	if s == "" {
		return time.Time{}, false
	}
	if t, err := time.Parse(time.RFC3339Nano, s); err == nil {
		return t.UTC(), true
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t.UTC(), true
	}
	return time.Time{}, false
}

// ---------------------------------------------------------------------------
// Cache I/O
// ---------------------------------------------------------------------------

func transcriptCachePath(path string) string {
	abs, err := filepath.Abs(path)
	if err != nil {
		abs = path
	}
	sum := sha256.Sum256([]byte(abs))
	hash := hex.EncodeToString(sum[:])

	dir := os.Getenv("CLAUDE_CONFIG_DIR")
	if dir == "" {
		home, _ := os.UserHomeDir()
		dir = filepath.Join(home, ".claude")
	}
	// Sibling directory so we don't fight upstream's cache format.
	return filepath.Join(dir, "plugins", "claude-hud-go", "transcript-cache", hash+".json")
}

func readTranscriptCache(path string, info os.FileInfo) (TranscriptData, bool) {
	cachePath := transcriptCachePath(path)
	raw, err := os.ReadFile(cachePath)
	if err != nil {
		return TranscriptData{}, false
	}
	var c transcriptCacheFile
	if err := json.Unmarshal(raw, &c); err != nil {
		return TranscriptData{}, false
	}
	abs, _ := filepath.Abs(path)
	if c.TranscriptPath != abs {
		return TranscriptData{}, false
	}
	if c.MtimeUnixNano != info.ModTime().UnixNano() {
		return TranscriptData{}, false
	}
	if c.Size != info.Size() {
		return TranscriptData{}, false
	}
	return c.Data, true
}

func writeTranscriptCache(path string, info os.FileInfo, data TranscriptData) {
	cachePath := transcriptCachePath(path)
	if err := os.MkdirAll(filepath.Dir(cachePath), 0o755); err != nil {
		return
	}
	abs, _ := filepath.Abs(path)
	payload := transcriptCacheFile{
		TranscriptPath: abs,
		MtimeUnixNano:  info.ModTime().UnixNano(),
		Size:           info.Size(),
		Data:           data,
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		return
	}
	tmp := cachePath + ".tmp"
	if err := os.WriteFile(tmp, raw, 0o644); err != nil {
		return
	}
	if err := os.Rename(tmp, cachePath); err != nil {
		_ = os.Remove(tmp)
	}
}

// fmtScanInt avoids importing fmt in this file; tiny helper.
func fmtScanInt(s string, out *int) (int, error) {
	n := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c < '0' || c > '9' {
			return i, errors.New("non-digit")
		}
		n = n*10 + int(c-'0')
	}
	*out = n
	return len(s), nil
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func stringOrEmpty(v any) string {
	switch x := v.(type) {
	case string:
		return x
	case float64:
		// JSON numbers come through as float64; convert to integer-like string.
		return itoa(int(x))
	case int:
		return itoa(x)
	}
	return ""
}
