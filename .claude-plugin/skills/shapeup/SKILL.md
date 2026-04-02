---
name: shapeup
description: |
  Manage ShapeUp via the ShapeUp CLI. Full coverage: pitches, scopes, tasks, cycles,
  hill charts, assignments, comments, search, tickets, and streams.
  Use for ANY ShapeUp question or action.
triggers:
  # Direct invocations
  - shapeup
  - /shapeup
  # Resource actions
  - shapeup pitch
  - shapeup scope
  - shapeup task
  - shapeup cycle
  - shapeup ticket
  # Common actions
  - create pitch
  - create scope
  - create task
  - complete task
  - mark done
  - move ticket
  # Shape Up concepts
  - hill chart
  - betting table
  - appetite
  - cooldown
  - shaped
  - framed
  # My work
  - my work
  - my tasks
  - my scopes
  - assigned to me
  - my pitches
  # Search and discovery
  - search shapeup
  - find in shapeup
  - check shapeup
  - list pitches
  - list cycles
  - show cycle
  # Questions
  - what's in shapeup
  - what cycle
  - cycle progress
  - pitch status
  - scope progress
invocable: true
argument-hint: "[action] [args...]"
---

# /shapeup - ShapeUp Workflow Command

Full CLI coverage: pitches (packages), scopes, tasks, cycles, hill charts, assignments, comments, reactions, search, tickets, streams, and notifications.

## Agent Invariants

**MUST follow these rules:**

1. **Choose the right output mode** — `--json` for full JSON envelope with breadcrumbs; `--md` when presenting to a human; `--agent` for raw data in automation scripts. Piped output auto-switches to `--json`.
2. **Set organisation context** — most commands require an org. Set once with `shapeup config set org "Name"` or pass `--org <name|id>` per command. Or set `SHAPEUP_ORG` env var.
3. **Use `--agent --help` for introspection** — returns structured JSON describing any command, its subcommands, flags, and examples. Walk the tree starting from `shapeup --agent --help`.
4. **Follow breadcrumbs** — JSON responses include a `breadcrumbs` array with suggested next commands. Use these to chain workflows.
5. **"Pitch" = "Package" in code** — users say "pitch", the API uses "package". The CLI uses "pitch" everywhere.
6. **Use 'me' for current user** — `--assignee me` resolves to the authenticated user.
7. **Check exit codes** — 0=OK, 2=not found, 3=auth error, 4=permission denied, 5=API error, 6=rate limited. Branch on exit code without parsing error text.

### Output Modes

| Goal | Flag | Format |
|------|------|--------|
| Full JSON with breadcrumbs | `--json` | `{ok, data, summary, breadcrumbs}` |
| Show results to a user | `--md` / `-m` | Markdown tables |
| Automation / scripting | `--agent` / `--quiet` | Raw JSON data only |
| Just the IDs | `--ids-only` | One ID per line |
| Piped output | _(auto)_ | Auto-switches to `--json` |

Use `--json` when chaining commands (breadcrumbs guide next steps). Use `--agent` for headless scripts. When piping to `jq`, output is JSON automatically — no flag needed.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error (bad command/flags) |
| 2 | Not found |
| 3 | Authentication error |
| 4 | Permission denied |
| 5 | API error |
| 6 | Rate limited |
| 130 | Interrupted (Ctrl-C) |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `SHAPEUP_TOKEN` | Bearer token (skips OAuth — for CI/scripts) |
| `SHAPEUP_ORG` | Default organisation ID |
| `SHAPEUP_HOST` | API host URL (default: https://shapeup.cc) |

### CLI Introspection

Navigate commands with `--agent --help`:

```bash
shapeup --agent --help
```

```json
{"command":"shapeup","version":"0.1.0","short":"...","commands":[...],
 "shortcuts":{...},"inherited_flags":[...]}
```

Drill into any command:

```bash
shapeup --agent --help tasks
```

```json
{"command":"tasks","path":"shapeup tasks","short":"...","aliases":{"todo":"tasks create","done":"tasks complete"},
 "subcommands":[...],"flags":[...],"examples":[...]}
```

Walk the tree: start at `shapeup --agent --help` for all commands, then drill into any subcommand.

## Quick Reference

| Task | Command |
|------|---------|
| **Auth** | |
| Login | `shapeup login` |
| Login to local dev | `shapeup login --host http://localhost:3000` |
| Logout | `shapeup logout` |
| **Discovery** | |
| List organisations | `shapeup orgs --json` |
| Set default org | `shapeup config set org "Org Name"` |
| Per-directory config | `shapeup config init "Org Name"` |
| Show config | `shapeup config show` |
| **Pitches** | |
| List all pitches | `shapeup pitches list --json` |
| List shaped pitches | `shapeup pitches list --status shaped --json` |
| List pitches in a cycle | `shapeup pitches list --cycle <id> --json` |
| Show pitch details | `shapeup pitch <id> --json` |
| **Cycles** | |
| List all cycles | `shapeup cycles --json` |
| List active cycles | `shapeup cycles --status active --json` |
| Show cycle details | `shapeup cycle show <id> --json` |
| **Scopes** | |
| List scopes for a pitch | `shapeup scopes list --pitch <id> --json` |
| Create scope | `shapeup scopes create --pitch <id> "Title" --json` |
| Update scope | `shapeup scopes update <id> --title "New" --json` |
| **Tasks** | |
| List tasks for a pitch | `shapeup tasks list --pitch <id> --json` |
| List tasks for a scope | `shapeup tasks list --scope <id> --json` |
| List my tasks | `shapeup tasks list --assignee me --json` |
| Create task | `shapeup todo "Description" --pitch <id> --json` |
| Create task in scope | `shapeup todo "Description" --pitch <id> --scope <id> --json` |
| Complete task | `shapeup done <id>` |
| Complete multiple | `shapeup done <id> <id> <id>` |
| **My Work** | |
| My assignments | `shapeup me --json` |
| Someone's work | `shapeup my-work --user <id> --json` |
| **Search** | |
| Search everything | `shapeup search "query" --json` |
| **Shortcuts** | |
| `shapeup pitch <id>` | Same as `shapeup pitches show <id>` |
| `shapeup cycles` | Same as `shapeup cycle list` |
| `shapeup todo "..."` | Same as `shapeup tasks create "..."` |
| `shapeup done <id>` | Same as `shapeup tasks complete <id>` |
| `shapeup me` | Same as `shapeup my-work` |

## Decision Trees

### Finding Content

```
Need to find something?
├── My assigned work? → shapeup me --json
├── Know the pitch? → shapeup pitch <id> --json
├── List shaped pitches? → shapeup pitches list --status shaped --json
├── Cycle progress? → shapeup cycle show <id> --json
├── Tasks in a scope? → shapeup tasks list --scope <id> --json
├── Full-text search? → shapeup search "query" --json
└── Don't know the org? → shapeup orgs --json
```

### Modifying Content

```
Want to change something?
├── Add work to a pitch? → shapeup scopes create --pitch <id> "Title"
├── Add a task? → shapeup todo "Description" --pitch <id>
├── Complete a task? → shapeup done <id>
├── Update a scope? → shapeup scopes update <id> --title "New"
└── Multiple tasks done? → shapeup done <id1> <id2> <id3>
```

### Setting Up Context

```
First time?
├── shapeup login
├── shapeup orgs --json  (find your org)
├── shapeup config set org "Org Name"  (set default)
└── Now all commands work without --org
```

## Common Workflows

### Check Cycle Health

```bash
# Show active cycle with all pitches and progress
shapeup cycles --status active --json
# Drill into the cycle
shapeup cycle show <id> --json
# Check a specific pitch
shapeup pitch <id> --json
```

### Add Work to a Pitch

```bash
# Create a scope
shapeup scopes create --pitch 42 "User onboarding" --json
# Add tasks to the scope (use the scope ID from the response)
shapeup todo "Design signup flow" --pitch 42 --scope <scope_id>
shapeup todo "Build email verification" --pitch 42 --scope <scope_id>
shapeup todo "Write tests" --pitch 42 --scope <scope_id>
```

### End-of-Day Standup

```bash
# See all my work
shapeup me --md
# Complete finished tasks
shapeup done 123 124 125
# Check what's left
shapeup me --md
```

### Link Code to ShapeUp

```bash
# After implementing a feature, complete the task
shapeup done <task_id>
# Check remaining work in the scope
shapeup tasks list --scope <scope_id> --json
```

## Shape Up Concepts

For agents unfamiliar with Shape Up methodology:

- **Pitch** (Package): A product initiative with a defined appetite. Progresses through: idea → framed → shaped.
- **Appetite**: Time budget — small batch (1-2 weeks) or big batch (6 weeks). NOT an estimate.
- **Cycle**: A 6-week development period. Pitches are "bet" on a cycle.
- **Scope**: A meaningful vertical slice of work within a pitch (1-2 weeks). Max 9 per pitch.
- **Task**: An individual work item within a scope.
- **Hill Chart**: Progress tracker. 0-50 = figuring things out (unknown). 50 = peak (understood). 50-100 = execution (known).
- **Betting Table**: Where shaped pitches are reviewed and assigned to cycles.
- **Cool-down**: 2-week period after a cycle for bugs, exploration, prep.

## Configuration

### Global Config

Stored in `~/.config/shapeup/config.json`:

```bash
shapeup config set org "Acme Corp"   # Set default org (name or ID)
shapeup config set host https://shapeup.cc  # Set host
```

### Per-Directory Config

Creates `.shapeup/config.json` in the current directory:

```bash
shapeup config init "Acme Corp"
```

### Resolution Order

`--org` flag > `.shapeup/config.json` > `~/.config/shapeup/config.json`

### Organisation Names

`--org` accepts both IDs and names (case-insensitive exact match):

```bash
shapeup pitches list --org "Acme Corp" --json
shapeup pitches list --org 42 --json
```
