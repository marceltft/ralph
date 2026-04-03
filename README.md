# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Amp](https://ampcode.com), [Claude Code](https://docs.anthropic.com/en/docs/claude-code), or [Kiro CLI](https://kiro.dev/docs/cli/)) repeatedly until all tasks are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and the task tracker.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com) (default)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
  - [Kiro CLI](https://kiro.dev/docs/cli/) (`kiro-cli`)
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project
- **Optional:** [bd (beads)](https://github.com/steveyegge/beads) for dependency-aware task tracking

## Task Tracking Modes

Ralph supports two task tracking backends:

### Beads (bd) — Recommended

If your project has a `.beads/` directory (from `bd init`), Ralph automatically uses bd for task tracking. This gives you:
- Dependency-aware task ordering (`bd ready` only surfaces unblocked tasks)
- Atomic task claiming (prevents conflicts in multi-agent setups)
- Custom statuses (`refining` → `refined` → `in_progress` → `closed`)
- Full audit trail via Dolt history

### prd.json — Legacy

If no `.beads/` directory exists, Ralph falls back to the original `prd.json` file format.

## Setup

### Option 1: Copy to your project

```bash
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/

# Copy the prompt template for your AI tool of choice:
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md    # For Amp (prd.json mode)
cp /path/to/ralph/CLAUDE.md scripts/ralph/CLAUDE.md    # For Claude Code (prd.json mode)
cp /path/to/ralph/KIRO.md scripts/ralph/KIRO.md        # For Kiro CLI (prd.json mode)

# For beads mode, also copy:
cp /path/to/ralph/amp-bd.md scripts/ralph/             # For Amp (bd mode)
cp /path/to/ralph/claude-bd.md scripts/ralph/          # For Claude Code (bd mode)
cp /path/to/ralph/kiro-bd.md scripts/ralph/            # For Kiro CLI (bd mode)

# Review prompts (for PR review phase):
cp /path/to/ralph/review-amp.md scripts/ralph/
cp /path/to/ralph/review-claude.md scripts/ralph/
cp /path/to/ralph/review-kiro.md scripts/ralph/

chmod +x scripts/ralph/ralph.sh
```

### Option 2: Install skills globally

For Amp:
```bash
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/
```

For Claude Code:
```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

For Kiro CLI:
```bash
cp -r skills/prd ~/.kiro/skills/
cp -r skills/ralph ~/.kiro/skills/
```

### Project-specific quality checks

Create a `ralph-checks.sh` at your project root with your lint/test/typecheck commands:

```bash
cp /path/to/ralph/ralph-checks.sh.example ./ralph-checks.sh
chmod +x ralph-checks.sh
# Edit with your project's commands
```

Ralph runs this script before each commit. If the file is empty or missing, checks are skipped.

### Configure beads (if using bd mode)

```bash
# Initialize beads in your project
bd init

# Add custom statuses for the refine workflow
bd config set status.custom "refining:wip,refined:active"
```

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to tasks

Use the Ralph skill to convert the markdown PRD to tasks:

```
Load the ralph skill and convert tasks/prd-[feature-name].md
```

- **bd mode:** Creates an epic with child tasks (status=`refining`). Review and move to `refined` when ready.
- **prd.json mode:** Creates `prd.json` with user stories.

### 3. Run Ralph

```bash
# Using Amp (default) with prd.json
./scripts/ralph/ralph.sh [max_iterations]

# Using Kiro CLI with beads
./scripts/ralph/ralph.sh --tool kiro --branch ralph/my-feature [max_iterations]

# Using Claude Code with beads
./scripts/ralph/ralph.sh --tool claude --branch ralph/my-feature [max_iterations]
```

Use `--tool amp`, `--tool claude`, or `--tool kiro` to select your AI coding tool. The `--branch` flag is required in bd mode.

### What Ralph does

**Phase 1 — Implement:**
1. Pick the highest priority ready task
2. Claim it (`bd update --claim` or pick from `prd.json`)
3. Implement that single task
4. Run quality checks (`ralph-checks.sh`)
5. Commit if checks pass
6. Mark task as done
7. Append learnings to `progress.txt`
8. Repeat until all tasks complete

**Phase 2 — PR Review (bd mode only):**
1. Create a pull request via `gh pr create`
2. Check for review comments
3. Address code comments with fixes
4. Respond to discussion comments in `review-responses.md`
5. Push and repeat until all comments addressed

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop (supports `--tool amp\|claude\|kiro`, auto-detects bd vs prd.json) |
| `prompt.md` | Prompt template for Amp (prd.json mode) |
| `CLAUDE.md` | Prompt template for Claude Code (prd.json mode) |
| `KIRO.md` | Prompt template for Kiro CLI (prd.json mode) |
| `amp-bd.md` | Prompt template for Amp (bd mode) |
| `claude-bd.md` | Prompt template for Claude Code (bd mode) |
| `kiro-bd.md` | Prompt template for Kiro CLI (bd mode) |
| `review-*.md` | PR review prompt templates |
| `ralph-checks.sh.example` | Template for project quality checks |
| `prd.json` | User stories with `passes` status (legacy mode) |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs |
| `skills/ralph/` | Skill for converting PRDs to tasks (bd or prd.json) |

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (Amp, Claude Code, or Kiro CLI) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- Task tracker state (`bd` issues or `prd.json`)

### Small Tasks

Each task should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

### Feedback Loops

Ralph only works if there are feedback loops:
- `ralph-checks.sh` catches lint/type/test errors
- Tests verify behavior
- CI must stay green

### Custom Statuses (bd mode)

| Status | Category | Meaning |
|--------|----------|---------|
| `refining` | wip | Being analyzed, not ready for implementation |
| `refined` | active | Fully understood, ready for `bd ready` to surface |
| `in_progress` | wip | Claimed by Ralph, being implemented |
| `closed` | done | Completed |

### Stop Condition

When all tasks are done, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits. In bd mode, it then creates a PR and enters the review phase.

## Debugging

```bash
# bd mode: see task status
bd list --pretty
bd ready --json
bd graph [epic-id]

# prd.json mode: see which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Kiro CLI documentation](https://kiro.dev/docs/cli/)
- [bd (beads) documentation](https://github.com/steveyegge/beads)
