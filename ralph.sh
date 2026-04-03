#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|claude|kiro] [--branch <name>] [--timeout <minutes>] [max_iterations]
#
# Tracker mode is auto-detected:
#   - If .beads/ exists in the project root → uses bd (beads)
#   - Otherwise → uses prd.json (legacy)

set -e

# Parse arguments
TOOL="amp"
MAX_ITERATIONS=10
BRANCH=""
TIMEOUT_MINUTES=0
START_TIME=$(date +%s)

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --branch=*)
      BRANCH="${1#*=}"
      shift
      ;;
    --timeout)
      TIMEOUT_MINUTES="$2"
      shift 2
      ;;
    --timeout=*)
      TIMEOUT_MINUTES="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "kiro" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', or 'kiro'."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"

# Auto-detect tracker mode
if [ -d "$PROJECT_ROOT/.beads" ]; then
  TRACKER="bd"
else
  TRACKER="prd"
fi

# --- PRD.JSON (legacy) setup ---
if [[ "$TRACKER" == "prd" ]]; then
  PRD_FILE="$SCRIPT_DIR/prd.json"
  ARCHIVE_DIR="$SCRIPT_DIR/archive"
  LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

  # Archive previous run if branch changed
  if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
    CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
    LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

    if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
      DATE=$(date +%Y-%m-%d)
      FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
      ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

      echo "Archiving previous run: $LAST_BRANCH"
      mkdir -p "$ARCHIVE_FOLDER"
      [ -f "$PRD_FILE" ] && cp -f "$PRD_FILE" "$ARCHIVE_FOLDER/"
      [ -f "$PROGRESS_FILE" ] && cp -f "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
      echo "   Archived to: $ARCHIVE_FOLDER"

      echo "# Ralph Progress Log" > "$PROGRESS_FILE"
      echo "Started: $(date)" >> "$PROGRESS_FILE"
      echo "---" >> "$PROGRESS_FILE"
    fi
  fi

  # Track current branch
  if [ -f "$PRD_FILE" ]; then
    CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ]; then
      echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
    fi
  fi
fi

# --- BD (beads) setup ---
if [[ "$TRACKER" == "bd" ]]; then
  if [ -z "$BRANCH" ]; then
    echo "Error: --branch is required when using bd tracker."
    echo "Usage: ./ralph.sh --tool kiro --branch ralph/my-feature [max_iterations]"
    exit 1
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Select prompt file based on tracker mode
get_prompt_file() {
  local tool="$1"
  local tracker="$2"
  if [[ "$tracker" == "bd" ]]; then
    echo "$SCRIPT_DIR/${tool}-bd.md"
  else
    case "$tool" in
      amp)   echo "$SCRIPT_DIR/prompt.md" ;;
      claude) echo "$SCRIPT_DIR/CLAUDE.md" ;;
      kiro)  echo "$SCRIPT_DIR/KIRO.md" ;;
    esac
  fi
}

# Map tool name to prompt file name for bd mode
get_bd_prompt_name() {
  case "$1" in
    amp)    echo "amp-bd.md" ;;
    claude) echo "claude-bd.md" ;;
    kiro)   echo "kiro-bd.md" ;;
  esac
}

PROMPT_FILE=$(get_prompt_file "$TOOL" "$TRACKER")

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: Prompt file not found: $PROMPT_FILE"
  exit 1
fi

# Check if timeout has been exceeded
check_timeout() {
  if [ "$TIMEOUT_MINUTES" -gt 0 ]; then
    local elapsed=$(( ($(date +%s) - START_TIME) / 60 ))
    if [ "$elapsed" -ge "$TIMEOUT_MINUTES" ]; then
      echo ""
      echo "Ralph reached timeout (${TIMEOUT_MINUTES}m). Elapsed: ${elapsed}m."
      echo "Check $PROGRESS_FILE for status."
      exit 1
    fi
  fi
}

# Run one iteration with the selected tool
run_iteration() {
  local prompt_file="$1"
  local output=""

  if [[ "$TOOL" == "amp" ]]; then
    output=$(cat "$prompt_file" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "kiro" ]]; then
    output=$(kiro-cli chat --no-interactive --trust-all-tools "Read and follow the instructions in $prompt_file" 2>&1 | tee /dev/stderr) || true
  else
    output=$(claude --dangerously-skip-permissions --print < "$prompt_file" 2>&1 | tee /dev/stderr) || true
  fi

  echo "$output"
}

echo "Starting Ralph - Tool: $TOOL - Tracker: $TRACKER - Max iterations: $MAX_ITERATIONS"
if [ "$TIMEOUT_MINUTES" -gt 0 ]; then
  echo "Timeout: ${TIMEOUT_MINUTES} minutes"
fi
if [[ "$TRACKER" == "bd" ]]; then
  echo "Branch: $BRANCH"
fi

# ============================================================
# PHASE 1: IMPLEMENT
# ============================================================
echo ""
echo "=== PHASE 1: IMPLEMENT ==="

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL/$TRACKER)"
  echo "==============================================================="

  check_timeout

  OUTPUT=$(run_iteration "$PROMPT_FILE")

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all implementation tasks at iteration $i!"

    # If using bd, move to review phase
    if [[ "$TRACKER" == "bd" ]]; then
      echo ""
      echo "=== PHASE 2: PR REVIEW ==="

      # Create MR/PR (detect platform)
      echo "Creating merge/pull request..."
      if cd "$PROJECT_ROOT" && git remote -v 2>/dev/null | grep -q gitlab; then
        PR_URL=$(glab mr create --fill --source-branch "$BRANCH" 2>&1) || true
      else
        PR_URL=$(gh pr create --fill --head "$BRANCH" 2>&1) || true
      fi
      echo "MR/PR: $PR_URL"

      REVIEW_PROMPT="$SCRIPT_DIR/review-${TOOL}.md"
      if [ ! -f "$REVIEW_PROMPT" ]; then
        echo "No review prompt found at $REVIEW_PROMPT — skipping review phase."
        exit 0
      fi

      REVIEW_MAX=$((MAX_ITERATIONS - i))
      if [ "$REVIEW_MAX" -lt 1 ]; then
        REVIEW_MAX=1
      fi

      for j in $(seq 1 $REVIEW_MAX); do
        echo ""
        echo "==============================================================="
        echo "  Ralph Review Iteration $j of $REVIEW_MAX ($TOOL)"
        echo "==============================================================="

        check_timeout

        REVIEW_OUTPUT=$(run_iteration "$REVIEW_PROMPT")

        if echo "$REVIEW_OUTPUT" | grep -q "<promise>REVIEW_COMPLETE</promise>"; then
          echo ""
          echo "Ralph completed PR review!"
          exit 0
        fi

        echo "Review iteration $j complete. Continuing..."
        sleep 2
      done

      echo ""
      echo "Ralph reached max review iterations without completing review."
      exit 1
    fi

    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
