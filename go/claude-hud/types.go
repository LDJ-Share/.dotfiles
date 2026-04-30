package main

import (
	"encoding/json"
	"time"
)

// StdinData mirrors Claude Code's statusline JSON payload.
type StdinData struct {
	TranscriptPath string        `json:"transcript_path"`
	Cwd            string        `json:"cwd"`
	Model          ModelInfo     `json:"model"`
	ContextWindow  ContextWindow `json:"context_window"`
	RateLimits     *RateLimits   `json:"rate_limits"`
}

type ModelInfo struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
}

type ContextWindow struct {
	ContextWindowSize   int         `json:"context_window_size"`
	CurrentUsage        *TokenUsage `json:"current_usage"`
	UsedPercentage      *float64    `json:"used_percentage"`
	RemainingPercentage *float64    `json:"remaining_percentage"`
}

type TokenUsage struct {
	InputTokens              int `json:"input_tokens"`
	OutputTokens             int `json:"output_tokens"`
	CacheCreationInputTokens int `json:"cache_creation_input_tokens"`
	CacheReadInputTokens     int `json:"cache_read_input_tokens"`
}

type RateLimits struct {
	FiveHour *RateWindow `json:"five_hour"`
	SevenDay *RateWindow `json:"seven_day"`
}

type RateWindow struct {
	UsedPercentage *float64 `json:"used_percentage"`
	ResetsAt       *float64 `json:"resets_at"`
}

// Tool / agent / todo entries derived from transcript JSONL.

type ToolEntry struct {
	ID        string     `json:"id"`
	Name      string     `json:"name"`
	Target    string     `json:"target,omitempty"`
	Status    string     `json:"status"` // running | completed | error
	StartTime time.Time  `json:"startTime"`
	EndTime   *time.Time `json:"endTime,omitempty"`
}

type AgentEntry struct {
	ID          string     `json:"id"`
	Type        string     `json:"type"`
	Model       string     `json:"model,omitempty"`
	Description string     `json:"description,omitempty"`
	Status      string     `json:"status"` // running | completed
	StartTime   time.Time  `json:"startTime"`
	EndTime     *time.Time `json:"endTime,omitempty"`
}

type TodoItem struct {
	Content string `json:"content"`
	Status  string `json:"status"` // pending | in_progress | completed
}

type TranscriptData struct {
	Tools        []ToolEntry  `json:"tools"`
	Agents       []AgentEntry `json:"agents"`
	Todos        []TodoItem   `json:"todos"`
	SessionStart *time.Time   `json:"sessionStart,omitempty"`
	SessionName  string       `json:"sessionName,omitempty"`
}

type UsageData struct {
	FiveHour      *int
	SevenDay      *int
	FiveHourReset *time.Time
	SevenDayReset *time.Time
}

type GitFileStats struct {
	Modified  int
	Added     int
	Deleted   int
	Untracked int
}

type GitStatus struct {
	Branch    string
	IsDirty   bool
	Ahead     int
	Behind    int
	FileStats *GitFileStats
}

type ConfigCounts struct {
	ClaudeMd int
	Rules    int
	MCP      int
	Hooks    int
}

type RenderContext struct {
	Stdin           StdinData
	Transcript      TranscriptData
	Counts          ConfigCounts
	GitStatus       *GitStatus
	UsageData       *UsageData
	Config          *HudConfig
	SessionDuration string
	ExtraLabel      string
	ClaudeCodeVer   string
}

// TranscriptEntry — a single JSONL line.
type TranscriptEntry struct {
	Timestamp   string             `json:"timestamp"`
	Type        string             `json:"type"`
	Slug        string             `json:"slug"`
	CustomTitle string             `json:"customTitle"`
	Message     *TranscriptMessage `json:"message"`
}

type TranscriptMessage struct {
	Content []ContentBlock `json:"content"`
}

type ContentBlock struct {
	Type      string          `json:"type"`
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Input     json.RawMessage `json:"input"`
	ToolUseID string          `json:"tool_use_id"`
	IsError   bool            `json:"is_error"`
}
