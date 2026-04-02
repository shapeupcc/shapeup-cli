---
name: shapeup
description: |
  Manage ShapeUp via the ShapeUp CLI. Full coverage: pitches, scopes, tasks, cycles,
  hill charts, assignments, comments, search, issues, and streams.
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
  - shapeup issue
  - shapeup issues
  # Common actions
  - create pitch
  - create scope
  - create task
  - create issue
  - complete task
  - mark done
  - move issue
  - icebox issue
  - defrost issue
  - assign issue
  - unassign issue
  - watch issue
  - triage
  - triage issues
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
  - my issues
  - watched issues
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

Manage pitches, scopes, tasks, issues, and cycles via the ShapeUp CLI. Columns and streams accept names (not just IDs) — use `--column triage`, `--stream "Platform"`, etc.

## Agent Invariants

**MUST follow these rules:**

0. **Show context first** — before executing any command, run `shapeup config show` and tell the user which organisation and host is active. This avoids confusion when working across multiple orgs.
1. **Choose the right output mode** — `--json` for chaining and automation; `--md` when presenting results to a human in conversation.
2. **Set organisation context** — most commands require an org. Set once with `shapeup config set org "Name"` or pass `--org <name|id>` per command. Per-directory config via `shapeup config init "Name"`.
3. **Use names, not IDs** — columns (`--column triage`), streams (`--stream "Platform"`), and orgs (`--org "Compass Labs"`) all accept names.
4. **Follow breadcrumbs** — JSON responses include a `breadcrumbs` array with suggested next commands. Use these to chain workflows.
5. **"Pitch" = "Package" in code** — users say "pitch", the API uses "package". The CLI uses "pitch" everywhere.
6. **Use 'me' and 'none'** — `--assignee me` for current user, `--assignee none` for unassigned items.
7. **Check exit codes** — 0=OK, 2=not found, 3=auth error, 4=permission denied, 5=API error. Branch on exit code without parsing error text.

### Output Modes

| Goal | Flag |
|------|------|
| Chain commands / automation | `--json` |
| Show results to a human | `--md` |
| Raw data for scripts | `--agent` / `--quiet` |
| Just IDs | `--ids-only` |
| Piped output | auto-switches to `--json` |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Usage error |
| 2 | Not found |
| 3 | Auth error |
| 4 | Permission denied |
| 5 | API error |
| 6 | Rate limited |
| 130 | Interrupted (Ctrl-C) |

## Quick Reference

| Task | Command |
|------|---------|
| **Auth & Context** | |
| Login | `shapeup login` |
| Auth status | `shapeup auth status` |
| List orgs | `shapeup orgs --json` |
| Show current org | `shapeup config show` |
| Set default org | `shapeup config set org "Compass Labs"` |
| Per-directory config | `shapeup config init "Compass Labs"` |
| Install skill | `shapeup setup claude` |
| **Issues** | |
| List open issues | `shapeup issues --json` |
| Include done/closed | `shapeup issues --all --json` |
| Triage queue | `shapeup issues --column triage --json` |
| Unassigned triage | `shapeup issues --column triage --assignee none --json` |
| My issues | `shapeup issues --assignee me --json` |
| Filter by tag | `shapeup issues --tag seo --json` |
| Filter by stream | `shapeup issues --stream "Platform" --json` |
| Show issue detail | `shapeup issue <id> --json` |
| Create issue | `shapeup issues create "Title" --stream "Platform"` |
| Move to column | `shapeup issues move <id> --column doing` |
| Mark issue done | `shapeup issues done <id>` |
| Close issue (won't fix) | `shapeup issues close <id>` |
| Reopen issue | `shapeup issues reopen <id>` |
| Icebox / defrost | `shapeup issues icebox <id>` / `defrost <id>` |
| Assign to issue | `shapeup issues assign <id>` (self) / `--user <id>` |
| Unassign from issue | `shapeup issues unassign <id>` (self) / `--user <id>` |
| Watch / unwatch | `shapeup issues watch <id>` / `unwatch <id>` |
| My watched issues | `shapeup watching --json` |
| **Comments** | |
| List comments on issue | `shapeup comments list --issue <id> --json` |
| List comments on pitch | `shapeup comments list --pitch <id> --json` |
| Add comment to issue | `shapeup comments add --issue <id> "Comment text"` |
| Add comment to pitch | `shapeup comments add --pitch <id> "Comment text"` |
| **Pitches** | |
| List pitches | `shapeup pitches list --json` |
| List shaped only | `shapeup pitches list --status shaped --json` |
| Show pitch detail | `shapeup pitch <id> --json` |
| Create pitch | `shapeup pitches create "Title" --stream "Name"` |
| Create with appetite | `shapeup pitches create "Title" --stream "Name" --appetite small_batch` |
| **Cycles** | |
| List cycles | `shapeup cycles --json` |
| Active cycles | `shapeup cycles --status active --json` |
| Show cycle | `shapeup cycle show <id> --json` |
| **Scopes & Tasks** | |
| List scopes | `shapeup scopes list --pitch <id> --json` |
| Create scope | `shapeup scopes create --pitch <id> "Title"` |
| Update hill position | `shapeup scopes position <id> <0-100>` |
| List tasks | `shapeup tasks list --pitch <id> --json` |
| Create task | `shapeup todo "Description" --pitch <id>` |
| Complete task(s) | `shapeup done <id> [<id>...]` |
| **My Work** | |
| All my assignments | `shapeup me --json` |
| My work (alias) | `shapeup my-work --json` |
| Search everything | `shapeup search "query" --json` |

## Common Workflows

### Triage Issues

The most common workflow. Review unassigned issues in the triage column.

```bash
# 1. Check context
shapeup config show

# 2. Get unassigned triage issues
shapeup issues --column triage --assignee none --json

# 3. Review the top issue
shapeup issue <id> --json

# 4. If it has a github_url, check the GitHub issue for more detail

# 5. Search the codebase for related code if it's a bug

# 6. Either:
#    - Fix it and mark done
shapeup issues done <id>
#    - Close it (won't fix)
shapeup issues close <id>
#    - Assign to someone
shapeup issues assign <id> --user <id>
#    - Icebox if not actionable
shapeup issues icebox <id>
#    - Promote to a pitch if it's too big for an issue
```

### Review a Pitch

```bash
# Show the pitch with all scopes and tasks
shapeup pitch <id> --json

# Check scope progress
shapeup scopes list --pitch <id> --json

# List open tasks
shapeup tasks list --pitch <id> --json
```

### Check Cycle Health

```bash
shapeup cycles --status active --json
shapeup cycle show <id> --json
shapeup pitch <id> --json
```

### Daily Standup

```bash
shapeup me --md
shapeup done 123 124 125
shapeup me --md
```

### Fix and Close Issue

When you fix a bug or resolve an issue from ShapeUp, close the loop by commenting and marking it done.

```bash
# 1. Get the commit hash and GitHub remote
git log --oneline -1
git remote get-url origin

# 2. Comment on the issue with what was done, linking the commit
shapeup comments add --issue <id> "Summary of changes. Commit: https://github.com/<owner>/<repo>/commit/<hash> — Resolved by Claude Code."

# 3. Mark the issue done
shapeup issues done <id>
```

Always include: what changed, the commit link (full GitHub URL, not markdown — markdown links get escaped), and that it was resolved by Claude Code.

### Create Work

```bash
# Create a pitch
shapeup pitches create "Redesign Search" --stream "Platform"
shapeup pitches create "Auth Overhaul" --stream "Platform" --appetite small_batch

# Add scope to a pitch
shapeup scopes create --pitch 42 "User onboarding"

# Update hill chart position
shapeup scopes position 7 50    # peak — fully understood
shapeup scopes position 7 80    # descending — executing

# Add tasks
shapeup todo "Design signup flow" --pitch 42 --scope <scope_id>

# Report a bug
shapeup issues create "Login timeout" --stream "Platform" --kind bug
```

## Decision Trees

### Finding Content

```
├── My work? → shapeup me --json
├── Triage queue? → shapeup issues --column triage --json
├── Issues I'm watching? → shapeup watching --json
├── Pitch detail? → shapeup pitch <id> --json
├── Cycle progress? → shapeup cycle show <id> --json
├── Search? → shapeup search "query" --json
└── Which org? → shapeup config show
```

### Acting on Issues

```
├── Mark issue done → shapeup issues done <id>
├── Close (won't fix) → shapeup issues close <id>
├── Reopen → shapeup issues reopen <id>
├── Move to column → shapeup issues move <id> --column doing
├── Icebox stale issue → shapeup issues icebox <id>
├── Defrost from icebox → shapeup issues defrost <id>
├── Assign to me → shapeup issues assign <id>
├── Assign to user → shapeup issues assign <id> --user <id>
├── Unassign me → shapeup issues unassign <id>
├── Watch for updates → shapeup issues watch <id>
├── Create new issue → shapeup issues create "Title" --stream "Name"
└── Triage unassigned → shapeup issues --column triage --assignee none --json
```

## Shape Up Concepts

- **Pitch** (Package): Product initiative. Progresses: idea → framed → shaped.
- **Appetite**: Time budget (1 week, 2 weeks, 6 weeks). NOT an estimate.
- **Cycle**: 6-week development period. Pitches are "bet" on a cycle.
- **Scope**: Vertical slice of work within a pitch (1-2 weeks). Max 9 per pitch.
- **Task**: Individual work item within a scope.
- **Hill Chart**: Progress tracker. 0-50 = unknown, 50 = peak, 50-100 = known.
- **Issue**: Bug or small request. Managed on a kanban board. Mark as done or closed when resolved.
- **Icebox**: Archive for stale issues. Auto-archives after 30 days of inactivity.
- **Horizon**: Speculative planning view for future cycles.

## Configuration

### Resolution Order

`--org` flag > `.shapeup/config.json` (per-directory) > `~/.config/shapeup/config.json` (global)

### Per-Directory Config (Recommended)

```bash
shapeup config init "Compass Labs"
```

Creates `.shapeup/config.json` in the current directory. All commands in this directory use this org.

### Global Config

```bash
shapeup config set org "Compass Labs"
shapeup config set host https://shapeup.cc
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `SHAPEUP_TOKEN` | Bearer token (skips OAuth) |
| `SHAPEUP_ORG` | Default organisation ID |
| `SHAPEUP_HOST` | API host URL (default: https://shapeup.cc) |
