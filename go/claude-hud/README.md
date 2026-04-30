# claude-hud (Go port — trimmed)

Single-binary Claude Code statusline. Drop-in replacement for the upstream
[`claude-hud`](https://github.com/jarrodwatts/claude-hud) Node plugin, suitable
for locked-down machines where you can copy a self-built `.exe` but can't
install plugins through the marketplace.

Behavior is hardcoded at compile time — no config file is read at runtime.
To change behavior (thresholds, palette, layout), edit the constants in
`consts.go` or the helpers in `colors.go` and rebuild.

## Build

```sh
cd go/claude-hud
go build -o claude-hud.exe .                       # for the host platform
GOOS=windows GOARCH=amd64 go build -o claude-hud.exe -ldflags="-s -w" .
GOOS=linux   GOARCH=amd64 go build -o claude-hud   -ldflags="-s -w" .
```

`-s -w` strips debug info; the binary drops from ~4.4 MB to ~3 MB.

## Install

Copy the resulting binary anywhere on the work box, then point Claude Code at
it in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "C:/path/to/claude-hud.exe"
  }
}
```

## Caches

- `$CLAUDE_CONFIG_DIR/plugins/claude-hud-go/transcript-cache/<sha256>.json` —
  parsed transcript, keyed by mtime+size. Different shape than upstream's so
  both runtimes can coexist without invalidating each other.
- `$CLAUDE_CONFIG_DIR/cache/claude-hud/speed-cache/<sha256>.json` — previous
  output-token sample for the always-on speed display.

## Performance

Cold ≈ 100 ms, warm ≈ 80 ms on a 1 MB transcript (Windows 11, NVMe). Roughly
6× faster than the PowerShell port and competitive with the upstream Node
runtime.
