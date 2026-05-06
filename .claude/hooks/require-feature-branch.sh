#!/usr/bin/env bash
# PreToolUse hook: blocks Edit/Write on main branch outside a worktree.
# Ensures the feature-branch-in-worktree workflow is followed.

# Only check for Swift/project file edits (skip .claude/, config, etc.)
TOOL_INPUT=$(cat)
FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"//')

# If no file_path (e.g. Bash tool), skip
[ -z "$FILE_PATH" ] && exit 0

# Only guard source files in the project
case "$FILE_PATH" in
  */Blink/* | */BlinkWatch/* | */Shared/* | */BlinkTests/* | */BlinkWatchTests/* | */project.yml)
    ;;
  *)
    exit 0
    ;;
esac

BRANCH=$(git -C /Users/rachit/Work/personal/blink branch --show-current 2>/dev/null)
IS_WORKTREE=$(git -C /Users/rachit/Work/personal/blink rev-parse --is-inside-work-tree 2>/dev/null)
GIT_DIR=$(git -C /Users/rachit/Work/personal/blink rev-parse --git-dir 2>/dev/null)

# Detect if we're in a worktree (git-dir contains "/worktrees/")
IN_WORKTREE=false
if echo "$GIT_DIR" | grep -q "/worktrees/"; then
  IN_WORKTREE=true
fi

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "STOP: You're on the '$BRANCH' branch. Create a feature branch first."
  echo ""
  echo "  git checkout -b feature/<name>"
  echo ""
  echo "Or better, use a worktree:"
  echo ""
  echo "  git worktree add .claude/worktrees/<name> -b feature/<name>"
  exit 2
fi

if [ "$IN_WORKTREE" = "false" ] && [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  # On a feature branch but not in a worktree — warn but don't block
  echo "Note: You're on branch '$BRANCH' but not in a worktree. Consider using worktrees for isolation."
  echo ""
  exit 0
fi

exit 0
