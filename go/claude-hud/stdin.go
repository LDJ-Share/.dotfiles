package main

import (
	"encoding/json"
	"io"
	"math"
	"os"
	"regexp"
	"strings"
	"time"
)

var bedrockSuffixStrips = []*regexp.Regexp{
	regexp.MustCompile(`-v\d+:\d+$`),
	regexp.MustCompile(`-\d{8}$`),
}

// readStdin parses Claude Code's statusline JSON. Returns nil if stdin is a TTY
// or empty (during setup verification).
func readStdin() *StdinData {
	stat, _ := os.Stdin.Stat()
	if stat != nil && (stat.Mode()&os.ModeCharDevice) != 0 {
		return nil
	}
	raw, err := io.ReadAll(os.Stdin)
	if err != nil {
		return nil
	}
	if len(strings.TrimSpace(string(raw))) == 0 {
		return nil
	}
	var s StdinData
	if err := json.Unmarshal(raw, &s); err != nil {
		return nil
	}
	return &s
}

// ---------------------------------------------------------------------------
// Context window math
// ---------------------------------------------------------------------------

// AutocompactBufferPercent is empirically derived from Claude Code's /context
// output and may need adjustment if Anthropic changes the buffer behavior.
const AutocompactBufferPercent = 0.165

func totalTokens(s StdinData) int {
	u := s.ContextWindow.CurrentUsage
	if u == nil {
		return 0
	}
	return u.InputTokens + u.CacheCreationInputTokens + u.CacheReadInputTokens
}

// nativePercent returns the v2.1.6+ pre-computed percentage when present.
func nativePercent(s StdinData) (int, bool) {
	if s.ContextWindow.UsedPercentage == nil {
		return 0, false
	}
	v := *s.ContextWindow.UsedPercentage
	if math.IsNaN(v) {
		return 0, false
	}
	return clampPercent(v), true
}

func contextPercent(s StdinData) int {
	if v, ok := nativePercent(s); ok {
		return v
	}
	size := s.ContextWindow.ContextWindowSize
	if size <= 0 {
		return 0
	}
	return clampPercent(float64(totalTokens(s)) / float64(size) * 100)
}

func bufferedPercent(s StdinData) int {
	if v, ok := nativePercent(s); ok {
		return v
	}
	size := s.ContextWindow.ContextWindowSize
	if size <= 0 {
		return 0
	}
	total := float64(totalTokens(s))
	rawRatio := total / float64(size)

	// Scale the autocompact buffer with usage — no buffer at <=5%, full at >=50%.
	const lo, hi = 0.05, 0.50
	scale := math.Min(1, math.Max(0, (rawRatio-lo)/(hi-lo)))
	buffer := float64(size) * AutocompactBufferPercent * scale
	return clampPercent((total + buffer) / float64(size) * 100)
}

func clampPercent(v float64) int {
	if math.IsNaN(v) {
		return 0
	}
	if v < 0 {
		return 0
	}
	if v > 100 {
		return 100
	}
	return int(math.Round(v))
}

// ---------------------------------------------------------------------------
// Model + provider labelling (mirrors upstream Bedrock normalization)
// ---------------------------------------------------------------------------

func modelName(s StdinData) string {
	if name := strings.TrimSpace(s.Model.DisplayName); name != "" {
		return name
	}
	id := strings.TrimSpace(s.Model.ID)
	if id == "" {
		return "Unknown"
	}
	if label := normalizeBedrockLabel(id); label != "" {
		return label
	}
	return id
}

func providerLabel(s StdinData) string {
	if isBedrockID(s.Model.ID) {
		return "Bedrock"
	}
	return ""
}

func isBedrockID(id string) bool {
	return strings.Contains(strings.ToLower(id), "anthropic.claude-")
}

func normalizeBedrockLabel(id string) string {
	lower := strings.ToLower(id)
	const prefix = "anthropic.claude-"
	idx := strings.Index(lower, prefix)
	if idx < 0 {
		return ""
	}
	suffix := lower[idx+len(prefix):]

	// Strip trailing version markers like -v1:0 or -20240620.
	for _, re := range bedrockSuffixStrips {
		suffix = re.ReplaceAllString(suffix, "")
	}

	tokens := []string{}
	for _, t := range strings.Split(suffix, "-") {
		if t != "" {
			tokens = append(tokens, t)
		}
	}
	if len(tokens) == 0 {
		return ""
	}
	familyIdx := -1
	for i, t := range tokens {
		if t == "haiku" || t == "sonnet" || t == "opus" {
			familyIdx = i
			break
		}
	}
	if familyIdx < 0 {
		return ""
	}
	family := tokens[familyIdx]

	before := readNumericVersion(tokens, familyIdx-1, -1)
	// reverse before
	for i, j := 0, len(before)-1; i < j; i, j = i+1, j-1 {
		before[i], before[j] = before[j], before[i]
	}
	after := readNumericVersion(tokens, familyIdx+1, +1)

	parts := before
	if len(after) > len(parts) {
		parts = after
	}
	familyLabel := strings.ToUpper(family[:1]) + family[1:]
	if len(parts) == 0 {
		return "Claude " + familyLabel
	}
	return "Claude " + familyLabel + " " + strings.Join(parts, ".")
}

func readNumericVersion(tokens []string, start, step int) []string {
	parts := []string{}
	for i := start; i >= 0 && i < len(tokens); i += step {
		if !isAllDigits(tokens[i]) {
			break
		}
		parts = append(parts, tokens[i])
		if len(parts) == 2 {
			break
		}
	}
	return parts
}

func isAllDigits(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < '0' || r > '9' {
			return false
		}
	}
	return true
}

// ---------------------------------------------------------------------------
// Rate-limit / usage extraction
// ---------------------------------------------------------------------------

func extractUsage(s StdinData) *UsageData {
	if s.RateLimits == nil {
		return nil
	}

	parsePct := func(p *float64) *int {
		if p == nil || math.IsNaN(*p) {
			return nil
		}
		v := clampPercent(*p)
		return &v
	}
	parseReset := func(p *float64) *time.Time {
		if p == nil || *p <= 0 || math.IsNaN(*p) {
			return nil
		}
		t := time.Unix(int64(*p), 0)
		return &t
	}

	var fh, sd *RateWindow
	if s.RateLimits.FiveHour != nil {
		fh = s.RateLimits.FiveHour
	}
	if s.RateLimits.SevenDay != nil {
		sd = s.RateLimits.SevenDay
	}

	var fhPct, sdPct *int
	var fhReset, sdReset *time.Time
	if fh != nil {
		fhPct = parsePct(fh.UsedPercentage)
		fhReset = parseReset(fh.ResetsAt)
	}
	if sd != nil {
		sdPct = parsePct(sd.UsedPercentage)
		sdReset = parseReset(sd.ResetsAt)
	}

	if fhPct == nil && sdPct == nil {
		return nil
	}
	return &UsageData{
		FiveHour:      fhPct,
		SevenDay:      sdPct,
		FiveHourReset: fhReset,
		SevenDayReset: sdReset,
	}
}

func isLimitReached(u *UsageData) bool {
	if u == nil {
		return false
	}
	return (u.FiveHour != nil && *u.FiveHour == 100) || (u.SevenDay != nil && *u.SevenDay == 100)
}
