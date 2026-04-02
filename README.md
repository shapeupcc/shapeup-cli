# ShapeUp CLI

Command-line interface for [ShapeUp](https://shapeup.cc), the Shape Up methodology platform. Works as a standalone tool and with any AI agent that can execute shell commands.

Zero dependencies — pure Ruby stdlib.

## Install

Clone the repo and add to your PATH:

```bash
git clone https://github.com/shapeup-cc/shapeup-cli ~/.shapeup-cli
```

Add to `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="$HOME/.shapeup-cli/bin:$PATH"
```

Verify:

```bash
shapeup version
```

## Quick Start

```bash
# Authenticate (opens browser for OAuth)
shapeup login

# Set your default organisation
shapeup orgs
shapeup config set org "Your Org"

# You're ready
shapeup me              # Show my work
shapeup pitches list    # List pitches
shapeup pitch 42        # Show pitch details
shapeup cycles          # List cycles
```

## Commands

```
Auth:       login, logout
Discovery:  orgs, commands, config
Pitches:    pitches list/show, pitch <id>
Cycles:     cycles, cycle show <id>
Scopes:     scopes list/create/update
Tasks:      tasks list, todo "...", done <id>
My Work:    me, my-work
Search:     search "query"
Setup:      setup claude/cursor/project
```

### Shortcuts

| Shortcut | Expands to |
|----------|-----------|
| `shapeup pitch 42` | `shapeup pitches show 42` |
| `shapeup cycles` | `shapeup cycle list` |
| `shapeup todo "Fix bug" --pitch 42` | `shapeup tasks create "Fix bug" --pitch 42` |
| `shapeup done 123` | `shapeup tasks complete 123` |
| `shapeup me` | `shapeup my-work` |

## Output Modes

Append to any command:

| Flag | Use case |
|------|----------|
| `--json` | Full JSON envelope with breadcrumbs (for chaining) |
| `--md` | Markdown tables (for humans) |
| `--agent` / `--quiet` | Raw JSON data (for AI agents) |
| `--ids-only` | One ID per line (for piping) |
| _(piped)_ | Auto-switches to `--json` when stdout is not a TTY |

```bash
shapeup pitches list --json
shapeup me --md
shapeup cycle show 5 --agent
shapeup pitches list | jq '.data'       # auto-JSON when piped
shapeup tasks list --pitch 42 --ids-only | xargs -I{} shapeup done {}
```

## Agent Integration

### For AI agents (Claude, Codex, Cursor, etc.)

The CLI is designed for AI agent use. Agents can:

1. **Discover commands** via structured introspection:
   ```bash
   shapeup --agent --help          # All commands
   shapeup --agent --help tasks    # Drill into tasks
   ```

2. **Chain commands** via breadcrumbs in `--json` output:
   ```bash
   shapeup pitch 42 --json
   # Response includes: breadcrumbs: [{cmd: "shapeup scopes list --pitch 42", ...}]
   ```

3. **Install skills** for automatic triggering:
   ```bash
   shapeup setup claude    # Installs SKILL.md into ~/.claude/skills/
   shapeup setup cursor    # For Cursor
   shapeup setup project   # Per-project (.claude/skills/)
   ```

### MCP (Model Context Protocol)

ShapeUp also provides a native MCP server. Agents that support MCP (Claude, Cursor, etc.) can connect directly:

```bash
claude mcp add --transport http shapeup https://shapeup.cc/mcp
```

The CLI and MCP server share the same backend — use whichever fits your agent.

## Configuration

### Global (all commands)

```bash
shapeup config set org "Acme Corp"
shapeup config set host https://shapeup.cc
```

Stored in `~/.config/shapeup/config.json`.

### Per-directory

```bash
shapeup config init "Acme Corp"
```

Creates `.shapeup/config.json` in the current directory. The CLI walks up the directory tree looking for this file, so it works from subdirectories too.

Resolution order: `--org` flag > env var > `.shapeup/config.json` > global config.

### Environment Variables

For CI, scripts, or when you don't want to store credentials on disk:

| Variable | Purpose |
|----------|---------|
| `SHAPEUP_TOKEN` | Bearer token (skips OAuth login) |
| `SHAPEUP_ORG` | Default organisation ID |
| `SHAPEUP_HOST` | API host URL |

```bash
SHAPEUP_TOKEN=abc123 SHAPEUP_ORG=42 shapeup me --json
```

### Organisation names

`--org` accepts both names and IDs (case-insensitive exact match):

```bash
shapeup pitches list --org "Acme Corp"
shapeup pitches list --org 42
```

## How It Works

The CLI is a thin HTTP client over ShapeUp's [MCP server](https://shapeup.cc/pages/mcp). Every command maps to an MCP tool call via JSON-RPC:

```
shapeup pitch 42 --json
  → POST https://shapeup.cc/mcp
  → {"jsonrpc":"2.0","method":"tools/call","params":{"name":"show_package","arguments":{"organisation":"1","package":"42"}}}
  ← {ok: true, data: {...}, breadcrumbs: [...]}
```

Authentication uses OAuth 2.1 with PKCE. Tokens are stored in `~/.config/shapeup/credentials.json`.

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error |
| 2 | Not found |
| 3 | Authentication error |
| 4 | Permission denied |
| 5 | API error |
| 6 | Rate limited |
| 130 | Interrupted |
