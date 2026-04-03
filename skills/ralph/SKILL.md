---
name: ralph
description: "Convert PRDs to tasks for the Ralph autonomous agent system. Creates bd (beads) issues if .beads/ exists, otherwise creates prd.json. Use when you have an existing PRD and need to convert it to Ralph's format. Triggers on: convert this prd, turn this into ralph format, create ralph tasks, ralph json."
user-invocable: true
---

# Ralph Task Converter

Converts existing PRDs to tasks that Ralph uses for autonomous execution. Auto-detects whether to create bd (beads) issues or a prd.json file.

---

## The Job

Take a PRD (markdown file or text) and convert it to tasks. Check the project root:
- If `.beads/` directory exists → create bd issues
- Otherwise → create `prd.json`

---

## Story Size: The Number One Rule

**Each story must be completable in ONE Ralph iteration (one context window).**

Ralph spawns a fresh AI instance per iteration with no memory of previous work. If a story is too big, the LLM runs out of context before finishing and produces broken code.

### Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

### Too big (split these):
- "Build the entire dashboard" - Split into: schema, queries, UI components, filters
- "Add authentication" - Split into: schema, middleware, login UI, session handling
- "Refactor the API" - Split into one story per endpoint or pattern

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is too big.

---

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

**Correct order:**
1. Schema/database changes (migrations)
2. Server actions / backend logic
3. UI components that use the backend
4. Dashboard/summary views that aggregate data

---

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something Ralph can CHECK, not something vague.

### Good criteria (verifiable):
- "Add `status` column to tasks table with default 'pending'"
- "Filter dropdown has options: All, Active, Completed"
- "Clicking delete shows confirmation dialog"
- "Typecheck passes"

### Bad criteria (vague):
- "Works correctly"
- "User can do X easily"
- "Good UX"

---

## Mode 1: Beads (bd) Output

When `.beads/` exists, create issues using bd commands.

### Setup custom statuses (if not already configured)

```bash
bd config set status.custom "refining:wip,refined:active"
```

### Create a parent epic

```bash
bd create "Epic: [Feature Name]" -t epic -p 1 --description="[PRD description]" --json
```

### Create child tasks with status=refining

For each user story, create a child task:

```bash
bd create "[US-ID]: [Title]" \
  -t task \
  -p [priority 0-4] \
  --parent [epic-id] \
  --description="[Description]\n\nAcceptance Criteria:\n- [criterion 1]\n- [criterion 2]" \
  --acceptance="[acceptance criteria as text]" \
  -s refining \
  --json
```

### Add dependency links between tasks

```bash
# UI task depends on schema task
bd dep add [ui-task-id] [schema-task-id]
```

### Priority mapping

| PRD Priority | bd Priority |
|---|---|
| 1 (first) | 0 (P0) |
| 2 | 1 (P1) |
| 3 | 2 (P2) |
| 4+ | 3 (P3) |

### After creating all tasks

List them for review:

```bash
bd list --parent [epic-id] --json
bd graph [epic-id]
```

Tasks are created with `status=refining`. They will NOT appear in `bd ready` until moved to `refined`:

```bash
# When a task is fully understood and ready for implementation:
bd update [task-id] -s refined
```

---

## Mode 2: prd.json Output (Legacy)

When no `.beads/` directory exists, create `prd.json`:

```json
{
  "project": "[Project Name]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Feature description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Conversion Rules for prd.json

1. Each user story becomes one JSON entry
2. IDs: Sequential (US-001, US-002, etc.)
3. Priority: Based on dependency order, then document order
4. All stories: `passes: false` and empty `notes`
5. branchName: Derive from feature name, kebab-case, prefixed with `ralph/`
6. Always add "Typecheck passes" to every story's acceptance criteria

---

## Splitting Large PRDs

If a PRD has big features, split them:

**Original:**
> "Add user notification system"

**Split into:**
1. Add notifications table to database
2. Create notification service for sending notifications
3. Add notification bell icon to header
4. Create notification dropdown panel
5. Add mark-as-read functionality
6. Add notification preferences page

---

## Checklist Before Saving

- [ ] Each story is completable in one iteration (small enough)
- [ ] Stories are ordered by dependency (schema → backend → UI)
- [ ] Acceptance criteria are verifiable (not vague)
- [ ] No story depends on a later story
- [ ] **bd mode:** Tasks created with `status=refining`, deps added
- [ ] **prd.json mode:** All stories have `passes: false`, "Typecheck passes" in criteria
