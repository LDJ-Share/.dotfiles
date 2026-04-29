# claude-hud (Go port)

Single-binary Claude Code statusline. Drop-in replacement for the upstream
[`claude-hud`](https://github.com/jarrodwatts/claude-hud) Node plugin, suitable
for locked-down machines where you can copy a self-built `.exe` but can't
install plugins through the marketplace.

Reads the same `~/.claude/plugins/claude-hud/config.json` upstream uses, so
configuration is portable between the home (Node) and work (Go) versions.

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
- `$CLAUDE_CONFIG_DIR/plugins/claude-hud-go/speed-cache/<sha256>.json` —
  previous output-token sample for `display.showSpeed`.
- `$CLAUDE_CONFIG_DIR/plugins/claude-hud-go/cc-version.txt` — cached
  `claude --version` output (24h TTL).

## Optional `--cmd` flag

Append a custom shell command label to the project line (mirrors upstream's
`extra-cmd` arg):

```json
"command": "C:/path/to/claude-hud.exe --cmd \"git rev-parse --short HEAD\""
```

## Performance

Cold ≈ 100 ms, warm ≈ 80 ms on a 1 MB transcript (Windows 11, NVMe). Roughly
6× faster than the PowerShell port and competitive with the upstream Node
runtime.
