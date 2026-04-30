package main

import (
	"bytes"
	"context"
	"os/exec"
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
		if strings.TrimSpace(statusOut) != "" {
			g.IsDirty = true
		}
	}
	return g
}
