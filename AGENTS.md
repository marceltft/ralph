# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding tools (Amp, Claude Code, or Kiro CLI) repeatedly until all tasks are complete. Each iteration is a fresh instance with clean context.

## Task Tracking

Ralph auto-detects the tracker:
- `.beads/` directory exists → uses **bd** (beads) for dependency-aware task tracking
- Otherwise → uses **prd.json** (legacy flat file)

## Commands

```bash
# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build

# Run Ralph with Amp (default, prd.json mode)
./ralph.sh [max_iterations]

# Run Ralph with Kiro CLI (bd mode)
./ralph.sh --tool kiro --branch ralph/my-feature [max_iterations]

# Run Ralph with Claude Code (bd mode)
./ralph.sh --tool claude --branch ralph/my-feature [max_iterations]
```

## Key Files

- `ralph.sh` - The bash loop (supports `--tool amp|claude|kiro`, auto-detects bd vs prd.json)
- `prompt.md` - Instructions for Amp (prd.json mode)
- `CLAUDE.md` - Instructions for Claude Code (prd.json mode)
- `KIRO.md` - Instructions for Kiro CLI (prd.json mode)
- `amp-bd.md` - Instructions for Amp (bd mode)
- `claude-bd.md` - Instructions for Claude Code (bd mode)
- `kiro-bd.md` - Instructions for Kiro CLI (bd mode)
- `review-amp.md` / `review-claude.md` / `review-kiro.md` - PR review prompts
- `ralph-checks.sh.example` - Template for project quality checks
- `prd.json.example` - Example PRD format (legacy mode)
- `flowchart/` - Interactive React Flow diagram explaining how Ralph works

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh AI instance (Amp, Claude Code, or Kiro CLI) with clean context
- Memory persists via git history, `progress.txt`, and task tracker (bd or prd.json)
- Tasks should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- In bd mode: `--branch` is required, PR review phase runs automatically after implementation
