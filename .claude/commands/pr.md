---
description: Commit pending changes, push, and open a PR targeting the given base branch
argument-hint: <base-branch>
---

The user ran `/pr $ARGUMENTS`. Commit any pending changes, push the current branch, and open a pull request targeting **`$ARGUMENTS`** as the base — even if the repo's default base on GitHub is something else (e.g. `dev`). Always honor the argument.

If `$ARGUMENTS` is empty, ask the user which base branch to target before doing anything else.

## Step 1 — Inspect state

Run in parallel:

- `git status` (never with `-uall`)
- `git diff` (unstaged + staged)
- `git diff --cached`
- `git branch --show-current`
- `git log --oneline -20` (to match commit-message style)

If the current branch equals `$ARGUMENTS`, stop and tell the user — they can't PR a branch into itself.

## Step 2 — Commit (only if there are uncommitted changes)

- Stage relevant files **by name**. Never use `git add .` or `git add -A`.
- Skip anything that looks like secrets (`.env`, `credentials*`, keys). Warn if the user explicitly staged them.
- Write a Conventional Commits message: `type: lowercase description`, lowercase subject. Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `ci`, `perf`, `style`, `build`.
- Focus the message on _why_, not _what_ (1–2 sentences).
- Commit via HEREDOC:
  ```bash
  git commit -m "$(cat <<'EOF'
  type: short description
  EOF
  )"
  ```
- **NEVER** use `--no-verify`, `--amend`, or `--no-gpg-sign` unless the user explicitly asked for it.
- If a pre-commit hook fails: fix the underlying issue, re-stage, and create a **NEW** commit (the failed commit did not happen, so `--amend` would clobber the previous one).

If there are **no** uncommitted changes _and_ no commits ahead of origin, stop and tell the user there's nothing to PR.

## Step 3 — Optional project checks

If the repo has a `CLAUDE.md` that requires a pre-push check (e.g. `pnpm typecheck`), run it before pushing. If it fails, surface the error and stop — do not push broken code.

## Step 4 — Push

- If the branch has no upstream: `git push -u origin <current-branch>`
- Otherwise: `git push`
- Never force-push unless the user explicitly asked for it, and never force-push to `main`/`master`/`dev`.

## Step 5 — Understand the full PR diff

Before drafting the PR body, inspect **all** commits going into it, not just the latest:

- `git log origin/$ARGUMENTS..HEAD --oneline`
- `git diff origin/$ARGUMENTS...HEAD --stat`
- `git diff origin/$ARGUMENTS...HEAD` (read selectively if large)

If `origin/$ARGUMENTS` doesn't exist locally, `git fetch origin $ARGUMENTS` first.

## Step 6 — Create the PR

```bash
gh pr create --base $ARGUMENTS --title "<pr-title>" --body "$(cat <<'EOF'
## Summary
- <1–3 bullet points>

## Test plan
- [ ] <what you/the reviewer should verify>
EOF
)"
```

PR title rules:

- Under 70 characters.
- Conventional format: `type: lowercase description` (the subject after `type:` must start lowercase — the `semantic-pull-request` check enforces this).
- Put details in the body, not the title.

## Step 7 — Report

Return the PR URL to the user on a single line so it's easy to click.

## Guardrails

- **Never** use the TodoWrite or Agent tools for this flow.
- **Never** push to the remote before the commit step succeeds.
- **Never** skip hooks or signing.
- **Never** create an empty commit if there's nothing to commit.
- Do **not** run any code-exploration commands beyond what's listed here — the goal is a tight commit→push→PR cycle, not a full review.
