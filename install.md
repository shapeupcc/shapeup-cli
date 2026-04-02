I want you to install Agent Skills for ShapeUp for me. Execute all steps autonomously.

OBJECTIVE: Install ShapeUp agent skills so your agent can manage pitches, scopes, tasks, cycles, and more via the ShapeUp CLI.

DONE WHEN: `shapeup version` succeeds, `shapeup orgs` returns data, and the shapeup skill is installed in your agent.

## TODO

- [ ] Install ShapeUp CLI
- [ ] Authenticate with ShapeUp
- [ ] Set default organisation
- [ ] Install skills

## Step 0: Install ShapeUp CLI

Check if the ShapeUp CLI is available:

```bash
shapeup version
```

If `shapeup` is not found, clone the repo and add to PATH:

```bash
git clone https://github.com/shapeup-cc/shapeup-cli ~/.shapeup-cli
```

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
alias shapeup='ruby -I~/.shapeup-cli/cli/lib ~/.shapeup-cli/cli/bin/shapeup'
```

**Verify:**
```bash
shapeup version
# Expected: shapeup 0.1.0
```

## Step 1: Authenticate with ShapeUp

```bash
shapeup login
```

This opens a browser for OAuth. Grant access when prompted. Credentials are stored in `~/.config/shapeup/credentials.json`.

For local development:

```bash
shapeup login --host http://localhost:3000
```

**Verify:**
```bash
shapeup orgs
# Expected: List of organisations
```

## Step 2: Set default organisation

```bash
shapeup config set org "Your Org Name"
```

Or for per-project config:

```bash
shapeup config init "Your Org Name"
```

**Verify:**
```bash
shapeup config show
# Expected: org set to your organisation
```

## Step 3: Install skills

```bash
shapeup setup claude
```

This copies the ShapeUp skill into `~/.claude/skills/shapeup/SKILL.md` so Claude Code can use ShapeUp commands when triggered.

**Verify:**
```bash
cat ~/.claude/skills/shapeup/SKILL.md | head -5
# Expected: YAML frontmatter with name: shapeup
```

Restart your agent session to pick up the new skills. The shapeup skill provides full CLI coverage: pitches, scopes, tasks, cycles, search, assignments, and more.

EXECUTE NOW: Start with Step 0. Mark TODO items complete as you go. Stop when all steps succeed.
