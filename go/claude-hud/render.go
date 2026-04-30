package main

import (
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/mattn/go-runewidth"
)

var ansiRegex = regexp.MustCompile("\x1b\\[[0-9;]*m")

func stripANSI(s string) string {
	return ansiRegex.ReplaceAllString(s, "")
}

// visualWidth returns the cell width of s, ignoring ANSI escape codes.
func visualWidth(s string) int {
	return runewidth.StringWidth(stripANSI(s))
}

// ---------------------------------------------------------------------------
// Per-element renderers
// ---------------------------------------------------------------------------

func renderProjectLine(ctx *RenderContext) string {
	parts := []string{}

	name := modelName(ctx.Stdin)
	provider := providerLabel(ctx.Stdin)
	hasAPIKey := os.Getenv("ANTHROPIC_API_KEY") != ""
	qualifier := ""
	if provider != "" {
		qualifier = provider
	} else if hasAPIKey {
		qualifier = cCritical("API")
	}
	display := name
	if qualifier != "" {
		display = name + " | " + qualifier
	}
	parts = append(parts, cModel("["+display+"]"))

	var projectPart, gitPart string
	if ctx.Stdin.Cwd != "" {
		segs := splitPath(ctx.Stdin.Cwd)
		var path string
		if len(segs) == 0 {
			path = "/"
		} else if pathLevels >= len(segs) {
			path = strings.Join(segs, "/")
		} else {
			path = strings.Join(segs[len(segs)-pathLevels:], "/")
		}
		projectPart = cProject(path)
	}

	if ctx.GitStatus != nil {
		g := ctx.GitStatus
		branch := g.Branch
		if g.IsDirty {
			branch += "*"
		}
		gitPart = cGit("git:(") + cGitBranch(branch) + cGit(")")
	}

	switch {
	case projectPart != "" && gitPart != "":
		parts = append(parts, projectPart+" "+gitPart)
	case projectPart != "":
		parts = append(parts, projectPart)
	case gitPart != "":
		parts = append(parts, gitPart)
	}

	if ctx.Transcript.SessionName != "" {
		parts = append(parts, cLabel(ctx.Transcript.SessionName))
	}
	if speed := getOutputSpeed(ctx.Stdin); speed != nil {
		parts = append(parts, cLabel(fmt.Sprintf("out: %.1f tok/s", *speed)))
	}
	if ctx.SessionDuration != "" {
		// U+23F1 + U+FE0F = emoji presentation of stopwatch.
		parts = append(parts, cLabel("⏱️  "+ctx.SessionDuration))
	}

	if len(parts) == 0 {
		return ""
	}
	return strings.Join(parts, " │ ")
}

func renderContextLine(ctx *RenderContext) string {
	percent := bufferedPercent(ctx.Stdin)
	color := contextColorANSI(percent)
	valueDisplay := color + fmt.Sprintf("%d%%", percent) + ansiReset

	line := cLabel("Context") + " " + contextBar(percent, getAdaptiveBarWidth()) + " " + valueDisplay

	if percent >= tokenBreakdownThreshold {
		u := ctx.Stdin.ContextWindow.CurrentUsage
		if u != nil {
			in := formatTokens(u.InputTokens)
			cache := formatTokens(u.CacheCreationInputTokens + u.CacheReadInputTokens)
			line += cLabel(fmt.Sprintf(" (in: %s, cache: %s)", in, cache))
		}
	}
	return line
}

func renderUsageLine(ctx *RenderContext) string {
	if ctx.UsageData == nil || providerLabel(ctx.Stdin) != "" {
		return ""
	}
	u := ctx.UsageData
	usageLabel := cLabel("Usage")

	if isLimitReached(u) {
		var resetAt = u.SevenDayReset
		if u.FiveHour != nil && *u.FiveHour == 100 {
			resetAt = u.FiveHourReset
		}
		rt := formatResetTime(resetAt)
		msg := "⚠ Limit reached"
		if rt != "" {
			msg += fmt.Sprintf(" (resets %s)", rt)
		}
		return usageLabel + " " + cCritical(msg)
	}

	five := u.FiveHour
	seven := u.SevenDay

	effective := 0
	if five != nil && *five > effective {
		effective = *five
	}
	if seven != nil && *seven > effective {
		effective = *seven
	}
	if effective < usageDisplayMinimum {
		return ""
	}

	barWidth := getAdaptiveBarWidth()

	if five == nil && seven != nil {
		part := formatUsageWindowPart("7d", seven, u.SevenDayReset, true, barWidth, true)
		return usageLabel + " " + part
	}

	fivePart := formatUsageWindowPart("5h", five, u.FiveHourReset, true, barWidth, false)

	if seven != nil && *seven >= sevenDayDisplayThreshold {
		sevenPart := formatUsageWindowPart("7d", seven, u.SevenDayReset, true, barWidth, false)
		return usageLabel + " " + fivePart + " | " + sevenPart
	}
	return usageLabel + " " + fivePart
}

func formatUsageWindowPart(label string, percent *int, reset *time.Time, useBar bool, barWidth int, forceLabel bool) string {
	var valueDisplay string
	if percent == nil {
		valueDisplay = cLabel("--")
	} else {
		valueDisplay = quotaColorANSI(*percent) + fmt.Sprintf("%d%%", *percent) + ansiReset
	}
	resetStr := formatResetTime(reset)

	if useBar {
		p := 0
		if percent != nil {
			p = *percent
		}
		var body string
		if resetStr != "" {
			body = quotaBar(p, barWidth) + " " + valueDisplay + fmt.Sprintf(" (resets in %s)", resetStr)
		} else {
			body = quotaBar(p, barWidth) + " " + valueDisplay
		}
		if forceLabel {
			return label + ": " + body
		}
		return body
	}
	if resetStr != "" {
		return fmt.Sprintf("%s: %s (resets in %s)", label, valueDisplay, resetStr)
	}
	return fmt.Sprintf("%s: %s", label, valueDisplay)
}

func renderEnvironmentLine(ctx *RenderContext) string {
	c := ctx.Counts
	total := c.ClaudeMd + c.Rules + c.MCP + c.Hooks
	if total == 0 || total < environmentDisplayMinimum {
		return ""
	}
	parts := []string{}
	if c.ClaudeMd > 0 {
		parts = append(parts, fmt.Sprintf("%d CLAUDE.md", c.ClaudeMd))
	}
	if c.Rules > 0 {
		parts = append(parts, fmt.Sprintf("%d rules", c.Rules))
	}
	if c.MCP > 0 {
		parts = append(parts, fmt.Sprintf("%d MCPs", c.MCP))
	}
	if c.Hooks > 0 {
		parts = append(parts, fmt.Sprintf("%d hooks", c.Hooks))
	}
	if len(parts) == 0 {
		return ""
	}
	return cLabel(strings.Join(parts, " | "))
}

func renderToolsLine(ctx *RenderContext) string {
	tools := ctx.Transcript.Tools
	if len(tools) == 0 {
		return ""
	}
	parts := []string{}
	running := []ToolEntry{}
	completed := []ToolEntry{}
	for _, t := range tools {
		if t.Status == "running" {
			running = append(running, t)
		} else {
			completed = append(completed, t)
		}
	}
	// Show last 2 running tools, with target if any.
	startRun := 0
	if len(running) > 2 {
		startRun = len(running) - 2
	}
	for _, t := range running[startRun:] {
		tgt := truncateToolPath(t.Target, 20)
		if tgt != "" {
			parts = append(parts, yellow("◐")+" "+cyan(t.Name)+cLabel(": "+tgt))
		} else {
			parts = append(parts, yellow("◐")+" "+cyan(t.Name))
		}
	}
	// Top 4 most-used completed tools.
	counts := map[string]int{}
	for _, t := range completed {
		counts[t.Name]++
	}
	type kv struct {
		name string
		n    int
	}
	pairs := make([]kv, 0, len(counts))
	for k, v := range counts {
		pairs = append(pairs, kv{k, v})
	}
	sort.Slice(pairs, func(i, j int) bool { return pairs[i].n > pairs[j].n })
	if len(pairs) > 4 {
		pairs = pairs[:4]
	}
	for _, p := range pairs {
		parts = append(parts, green("✓")+" "+p.name+" "+cLabel(fmt.Sprintf("×%d", p.n)))
	}
	if len(parts) == 0 {
		return ""
	}
	return strings.Join(parts, " | ")
}

func truncateToolPath(p string, max int) string {
	if p == "" {
		return ""
	}
	p = strings.ReplaceAll(p, "\\", "/")
	if len(p) <= max {
		return p
	}
	parts := strings.Split(p, "/")
	last := parts[len(parts)-1]
	if len(last) >= max {
		if max <= 3 {
			return last[:max]
		}
		return last[:max-3] + "..."
	}
	return ".../" + last
}

func renderAgentsLine(ctx *RenderContext) string {
	agents := ctx.Transcript.Agents
	if len(agents) == 0 {
		return ""
	}
	running := []AgentEntry{}
	completed := []AgentEntry{}
	for _, a := range agents {
		if a.Status == "running" {
			running = append(running, a)
		} else if a.Status == "completed" {
			completed = append(completed, a)
		}
	}
	if len(completed) > 2 {
		completed = completed[len(completed)-2:]
	}
	show := append(running, completed...)
	if len(show) > 3 {
		show = show[len(show)-3:]
	}
	if len(show) == 0 {
		return ""
	}
	lines := make([]string, 0, len(show))
	for _, a := range show {
		icon := green("✓")
		if a.Status == "running" {
			icon = yellow("◐")
		}
		typ := magenta(a.Type)
		modelPart := ""
		if a.Model != "" {
			modelPart = " " + cLabel("["+a.Model+"]")
		}
		desc := ""
		if a.Description != "" {
			d := a.Description
			if len(d) > 40 {
				d = d[:37] + "..."
			}
			desc = cLabel(": " + d)
		}
		elapsed := formatElapsed(a.StartTime, a.EndTime)
		lines = append(lines, icon+" "+typ+modelPart+desc+" "+cLabel("("+elapsed+")"))
	}
	return strings.Join(lines, "\n")
}

func renderTodosLine(ctx *RenderContext) string {
	todos := ctx.Transcript.Todos
	if len(todos) == 0 {
		return ""
	}
	var inProgress *TodoItem
	completed := 0
	for i := range todos {
		if todos[i].Status == "in_progress" && inProgress == nil {
			inProgress = &todos[i]
		}
		if todos[i].Status == "completed" {
			completed++
		}
	}
	total := len(todos)
	if inProgress == nil {
		if completed == total && total > 0 {
			return green("✓") + " All todos complete " + cLabel(fmt.Sprintf("(%d/%d)", completed, total))
		}
		return ""
	}
	content := inProgress.Content
	if len(content) > 50 {
		content = content[:47] + "..."
	}
	return yellow("▸") + " " + content + " " + cLabel(fmt.Sprintf("(%d/%d)", completed, total))
}

// ---------------------------------------------------------------------------
// Layout — expanded only (compact was removed during the trim).
// ---------------------------------------------------------------------------

func renderElement(ctx *RenderContext, name string) string {
	switch name {
	case "project":
		return renderProjectLine(ctx)
	case "context":
		return renderContextLine(ctx)
	case "usage":
		return renderUsageLine(ctx)
	case "environment":
		return renderEnvironmentLine(ctx)
	case "tools":
		return renderToolsLine(ctx)
	case "agents":
		return renderAgentsLine(ctx)
	case "todos":
		return renderTodosLine(ctx)
	}
	return ""
}

func renderExpanded(ctx *RenderContext) []string {
	order := elementOrder
	seen := map[string]bool{}
	out := []string{}

	for i := 0; i < len(order); i++ {
		el := order[i]
		if seen[el] {
			continue
		}
		// Merge context+usage when adjacent.
		if i+1 < len(order) {
			next := order[i+1]
			merge := (el == "context" && next == "usage" && !seen["usage"]) ||
				(el == "usage" && next == "context" && !seen["context"])
			if merge {
				seen[el] = true
				seen[next] = true
				a := renderElement(ctx, el)
				b := renderElement(ctx, next)
				switch {
				case a != "" && b != "":
					out = append(out, a+" │ "+b)
				case a != "":
					out = append(out, a)
				case b != "":
					out = append(out, b)
				}
				continue
			}
		}
		seen[el] = true
		line := renderElement(ctx, el)
		if line == "" {
			continue
		}
		out = append(out, line)
	}
	return out
}

// ---------------------------------------------------------------------------
// Top-level render — handles width-aware wrapping/truncation.
// ---------------------------------------------------------------------------

func render(ctx *RenderContext, out *strings.Builder) {
	lines := renderExpanded(ctx)
	termWidth := getTerminalWidth()

	for _, line := range lines {
		for _, physical := range strings.Split(line, "\n") {
			for _, wrapped := range wrapLineToWidth(physical, termWidth) {
				out.WriteString(ansiReset)
				out.WriteString(wrapped)
				out.WriteByte('\n')
			}
		}
	}
}

// wrapLineToWidth splits long lines at " | " or " │ " separators so the HUD
// stays visible when it would otherwise overflow the terminal. Falls back to
// hard truncation only when no separator fits.
func wrapLineToWidth(line string, max int) []string {
	if max <= 0 || visualWidth(line) <= max {
		return []string{line}
	}
	parts := splitWrapParts(line)
	if len(parts) <= 1 {
		return []string{fitToWidth(line, max)}
	}
	out := []string{}
	current := parts[0].segment
	for _, p := range parts[1:] {
		candidate := current + p.separator + p.segment
		if visualWidth(candidate) <= max {
			current = candidate
			continue
		}
		out = append(out, fitToWidth(current, max))
		current = p.segment
	}
	if current != "" {
		out = append(out, fitToWidth(current, max))
	}
	return out
}

type wrapPart struct {
	separator string
	segment   string
}

// splitWrapParts breaks a line on " | " / " │ " separators. The leading
// `[model | provider]` block (which contains its own `|`) is kept intact —
// otherwise we'd wrap inside the model badge.
func splitWrapParts(line string) []wrapPart {
	type kv struct{ start, sepLen int }
	hits := []kv{}
	i := 0
	for i < len(line) {
		if loc := ansiRegex.FindStringIndex(line[i:]); loc != nil && loc[0] == 0 {
			i += loc[1]
			continue
		}
		if strings.HasPrefix(line[i:], " | ") {
			hits = append(hits, kv{start: i, sepLen: 3})
			i += 3
			continue
		}
		if strings.HasPrefix(line[i:], " │ ") {
			hits = append(hits, kv{start: i, sepLen: len(" │ ")})
			i += len(" │ ")
			continue
		}
		i++
	}
	if len(hits) == 0 {
		return []wrapPart{{segment: line}}
	}
	parts := []wrapPart{}
	prev := 0
	prevSep := ""
	for _, h := range hits {
		parts = append(parts, wrapPart{separator: prevSep, segment: line[prev:h.start]})
		prevSep = line[h.start : h.start+h.sepLen]
		prev = h.start + h.sepLen
	}
	parts = append(parts, wrapPart{separator: prevSep, segment: line[prev:]})

	// If the first segment opens a `[` model badge but doesn't close it within
	// itself, glue subsequent parts onto it until the `]` closes.
	first := stripANSI(parts[0].segment)
	if strings.HasPrefix(strings.TrimLeft(first, " "), "[") && !strings.Contains(first, "]") && len(parts) > 1 {
		merged := parts[0].segment
		consume := 1
		for consume < len(parts) {
			merged += parts[consume].separator + parts[consume].segment
			consume++
			if strings.Contains(stripANSI(parts[consume-1].segment), "]") {
				break
			}
		}
		parts = append([]wrapPart{{segment: merged}}, parts[consume:]...)
	}
	return parts
}

// fitToWidth truncates a line to width N, ignoring ANSI escape codes.
func fitToWidth(line string, max int) string {
	if max <= 0 {
		return line
	}
	if visualWidth(line) <= max {
		return line
	}
	suffix := "..."
	if max < 3 {
		suffix = strings.Repeat(".", max)
	}
	keep := max - visualWidth(suffix)
	if keep < 0 {
		keep = 0
	}

	var b strings.Builder
	width := 0
	i := 0
	for i < len(line) {
		// Pass-through ANSI escape sequences.
		if loc := ansiRegex.FindStringIndex(line[i:]); loc != nil && loc[0] == 0 {
			b.WriteString(line[i : i+loc[1]])
			i += loc[1]
			continue
		}
		// One rune at a time.
		r, size := decodeRune(line[i:])
		w := runewidth.RuneWidth(r)
		if width+w > keep {
			break
		}
		b.WriteString(line[i : i+size])
		width += w
		i += size
	}
	b.WriteString(suffix)
	b.WriteString(ansiReset)
	return b.String()
}

func decodeRune(s string) (rune, int) {
	for _, r := range s {
		// First rune in the string.
		size := len(string(r))
		return r, size
	}
	return 0, 1
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func splitPath(p string) []string {
	parts := strings.FieldsFunc(p, func(r rune) bool {
		return r == '/' || r == '\\'
	})
	return parts
}
