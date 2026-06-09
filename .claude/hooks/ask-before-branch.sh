#!/usr/bin/env bash
# PreToolUse (Bash) hook: prompt ("ask") before any git command that CREATES a branch.
# Matches: git branch <name>, git checkout -b/-B, git switch -c/-C/--create, git worktree add.
# Leaves every other command (including git branch -a / --show-current / -d / -m) untouched.
# On match it emits a PreToolUse permission decision of "ask"; otherwise it stays silent (allow).

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Fast exit for anything that isn't a git command.
[ -z "$cmd" ] && exit 0
case "$cmd" in
  *git*) ;;
  *) exit 0 ;;
esac

emit_ask() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

# Split the command on common shell separators so chained commands are each inspected.
segments=$(printf '%s' "$cmd" | sed -E 's/\&\&/\n/g; s/\|\|/\n/g; s/;/\n/g; s/\|/\n/g')

while IFS= read -r seg; do
  s=$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -z "$s" ] && continue

  # git checkout -b / -B <name>
  if printf '%s' "$s" | grep -Eq '\bgit[[:space:]]+checkout\b' \
     && printf '%s' "$s" | grep -Eq '(^|[[:space:]])-[bB]([[:space:]]|$)'; then
    emit_ask "This creates a git branch (git checkout -b). Confirm before branching."
  fi

  # git switch -c / -C / --create <name>
  if printf '%s' "$s" | grep -Eq '\bgit[[:space:]]+switch\b' \
     && printf '%s' "$s" | grep -Eq '((^|[[:space:]])-[cC]([[:space:]]|$)|--create)'; then
    emit_ask "This creates a git branch (git switch -c). Confirm before branching."
  fi

  # git worktree add <path> [<branch>]
  if printf '%s' "$s" | grep -Eq '\bgit[[:space:]]+worktree[[:space:]]+add\b'; then
    emit_ask "This creates a git worktree (git worktree add). Confirm before branching."
  fi

  # git branch <name>  -- creation only; skip delete/move/copy/list/inspection forms
  if printf '%s' "$s" | grep -Eq '\bgit[[:space:]]+branch\b'; then
    rest=$(printf '%s' "$s" | sed -E 's/.*\bgit[[:space:]]+branch[[:space:]]*//')
    if printf '%s' "$rest" | grep -Eq '(^|[[:space:]])(-d|-D|--delete|-m|-M|--move|--list|-l|-a|--all|-r|--remotes|-v|-vv|--show-current|--contains|--no-contains|--merged|--no-merged|--points-at|--format|--edit-description|--set-upstream-to|-u|--unset-upstream|--sort)([[:space:]=]|$)'; then
      : # management/inspection of existing branches -> allow
    elif printf '%s' "$rest" | grep -Eq '(^|[[:space:]])[^-[:space:]]'; then
      emit_ask "This creates a git branch (git branch <name>). Confirm before branching."
    fi
  fi
done <<EOF
$segments
EOF

exit 0
