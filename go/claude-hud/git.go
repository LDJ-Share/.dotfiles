package main

import (
	"bytes"
	"context"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

func runGit(cwd string, args ...string) (string, bool) {
	if cwd == "" {
		return "", false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = cwd
	var out bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return "", false
	}
	return out.String(), true
}

func getGitStatus(cwd string) *GitStatus {
	if cwd == "" {
		return nil
	}
	branchOut, ok := runGit(cwd, "rev-parse", "--abbrev-ref", "HEAD")
	if !ok {
		return nil
	}
	branch := strings.TrimSpace(branchOut)
	if branch == "" {
		return nil
	}

	g := &GitStatus{Branch: branch}

	if statusOut, ok := runGit(cwd, "--no-optional-locks", "status", "--porcelain"); ok {
		trimmed := strings.TrimSpace(statusOut)
		if trimmed != "" {
			g.IsDirty = true
			g.FileStats = parseFileStats(trimmed)
		}
	}

	if revOut, ok := runGit(cwd, "rev-list", "--left-right", "--count", "@{upstream}...HEAD"); ok {
		parts := strings.Fields(strings.TrimSpace(revOut))
		if len(parts) == 2 {
			if b, err := strconv.Atoi(parts[0]); err == nil {
				g.Behind = b
			}
			if a, err := strconv.Atoi(parts[1]); err == nil {
				g.Ahead = a
			}
		}
	}
	return g
}

func parseFileStats(porcelain string) *GitFileStats {
	stats := &GitFileStats{}
	for _, line := range strings.Split(porcelain, "\n") {
		if len(line) < 2 {
			continue
		}
		if strings.HasPrefix(line, "??") {
			stats.Untracked++
			continue
		}
		idx := line[0]
		wt := line[1]
		switch {
		case idx == 'A':
			stats.Added++
		case idx == 'D' || wt == 'D':
			stats.Deleted++
		case idx == 'M' || wt == 'M' || idx == 'R' || idx == 'C':
			stats.Modified++
		}
	}
	return stats
}
