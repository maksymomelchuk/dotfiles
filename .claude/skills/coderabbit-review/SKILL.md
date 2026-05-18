---
name: coderabbit-review
description: Fetch CodeRabbit review comments from the current branch's PR, evaluate each finding against the actual code, and walk through them one at a time with the user — applying fixes as approved, committing per-finding, and replying to GitHub.
---

# CodeRabbit Review Command

Process CodeRabbit AI review on a PR by walking through every finding **one at a time** with the user. For each finding, evaluate it against the current code, present a concrete fix plan, apply as approved, then commit + push + reply to GitHub.

## Usage

Run `/coderabbit-review` on any branch with an open PR that has CodeRabbit review comments.

Optional argument: PR number (e.g. `/coderabbit-review 3020`). Otherwise the skill finds the open PR for the current branch.

## Workflow

### Phase 1: Find the PR

- If a PR number is provided, use it directly.
- Otherwise:
  ```
  gh pr list --head $(git branch --show-current) --state open --json number,title,url
  ```
- Extract owner/repo: `gh repo view --json nameWithOwner -q .nameWithOwner`
- Stop if no open PR.

### Phase 2: Fetch CodeRabbit comments

- Inline review comments:
  ```
  gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate \
    --jq '.[] | select(.user.login == "coderabbitai[bot]")'
  ```
- Issue-level comments:
  ```
  gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate \
    --jq '.[] | select(.user.login == "coderabbitai[bot]")'
  ```
- Bot username is `coderabbitai[bot]` (with brackets).
- Stop if no comments found.

### Phase 3: Parse each finding

From each comment, extract:

- Finding id (comment id), file path, line number
- Human-readable summary (bold text at top of body)
- Severity (Critical, Major, Minor)
- "Prompt for AI Agents" code block inside `<details><summary>🤖 Prompt for AI Agents</summary>…</details>` (if present)
- Note: nitpick findings may not have this section — still include them

Also detect `"✅ Addressed in commit <sha>"` markers — those findings can be auto-skipped with a reference to the commit.

### Phase 4: Evaluate each finding against current code

Don't just trust CodeRabbit's claim. Read the referenced file, surrounding context, and any related files needed to verify the finding. Key checks:

- **Is the scenario actually reachable?** UI guards (disabled states, early returns), schema defaults, upstream validation, type narrowing, etc. A bug that can't be triggered is not a bug.
- **Does the project override this?** Root `CLAUDE.md`, app-specific `CLAUDE.md` files (e.g. `apps/web/CLAUDE.md`), documented patterns. CodeRabbit often flags things that are intentional conventions (e.g. `zod/v4` vs `zod`, barrel-import rules).
- **Is the component even used?** Grep for imports. Dead code might warrant deletion instead of refactor.
- **Is the existing pattern legitimately correct?** MongoDB aggregation dot-notation, `hover:` utilities overriding variant defaults, etc. often have valid reasons — check surrounding code or `git log`.
- **Would fixing at a different layer be cleaner?** E.g. narrow at the serialization boundary once vs. casting in every consumer.

Classify each finding:

- **VALID** — clear bug or real improvement worth fixing
- **LOW PRIORITY** — real but marginal; user decides
- **SKIP** — not actually a bug (unreachable, convention override, dead code, design intent)

Record a one-sentence justification per verdict, grounded in what you found (specific file:line, schema default, CLAUDE.md passage, etc.).

Order findings by priority for the walkthrough:

1. Critical data/logic bugs
2. UX / state bugs
3. Accessibility
4. Style / defensive / refactors

### Phase 5: Orient, then walk through findings one at a time

#### Orientation message (once)

Before starting the walkthrough, give the user a one-shot summary. Keep it to one line per finding so scope is visible at a glance:

```
I evaluated all N findings. Walking through them one at a time.

Fix candidates (M):
- #3 (edit-modal stale rules)
- #5 (hardcoded .0 index)
- #7 (wrong source for checkedPrompt in A/B mode)
- ...

Skip candidates (K):
- #1 (zod/v4 is the project convention)
- #4 (already addressed in commit XYZ)
- ...
```

#### Per-finding presentation

For each finding, structure the message like this:

1. **Heading**: `**Finding N: <short title>**`
2. **File & line**: absolute or repo-relative path with line number
3. **Current code**: the relevant snippet (enough context to be meaningful, not the whole file)
4. **Issue**: what CodeRabbit flagged, in plain language
5. **Analysis**: what _you_ found in the code — reachability, caveats CodeRabbit missed, dead-code detection, schema defaults, etc.
6. **Planned fix**: exact diff or unambiguous pseudo-diff. For non-trivial fixes, present multiple approaches (Option A/B/C) and state your recommendation.
7. **Ask**: concise final question — "Apply, skip, or adjust the approach?"

**Never batch findings.** Never use `AskUserQuestion` with `multiSelect` to collect bulk decisions — the user loses context and can't react to the concrete fix plan.

#### Handle user responses

- **"Apply"** / **"yes"** / **"go"** → Apply the fix (Phase 6). Commit, push, and reply unless the user asked to test first.
- **"Apply but don't commit — let me test"** / **"let me check first"** → Apply + typecheck only. Do not commit. Wait for "ok" / "lgtm" / "commit it" before proceeding.
- **"Skip"** → Reply to CodeRabbit with _specific_ reasoning citing evidence (schema line, CLAUDE.md passage, UI guard, design intent). Move on.
- **"Show me the diff"** / **"How would this look?"** → Show the exact diff without applying. Then wait for decision.
- **"Propose another approach"** / **"show me X"** → Revise the plan and re-present. Iterate until approved.
- **"How do I reproduce this?"** → Walk through a concrete reproduction path (single-tab, multi-tab, race condition, etc.). If the scenario turns out unreachable, reclassify as SKIP and explain.
- **"Stop"** → Revert any uncommitted changes from the in-flight finding. Report current state (what was committed vs. reverted) before halting.

#### Design-intent decisions

If the user says a flagged behavior is intentional (e.g. "this mimics Upwork's UI on purpose", "the hover: is overriding the Button ghost variant"), offer to add a short WHY-comment in the code so future reviewers (human or bot) don't re-flag it. Still reply on GitHub with the reasoning.

### Phase 6: Apply a single fix

For each approved fix:

1. **Read** the target file for exact context (satisfies Edit tool pre-read requirement).
2. **Edit** minimally — match the presented plan. No scope creep.
3. **Typecheck** affected packages: `pnpm typecheck --filter @evora/{package}` (add more filters if the change touches multiple packages). Re-run after fixing errors.
4. **Pause** if the user requested UI testing. Do not commit until the user confirms.
5. **Commit** with a conventional type:
   - `fix:` — bug fixes
   - `refactor:` — type narrowing, dead-code removal, pattern alignment
   - `docs:` — comment-only changes
     Description lowercase, focused on _why_ over _what_. Include the ticket key (from branch name) if present.
6. **Push**: `git push`
7. **Reply** to the CodeRabbit comment via threaded reply endpoint:
   ```
   gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
     -f body="Fixed in {short-sha} — {what and why}"
   ```

For skips:

```
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  -f body="Skipping — {specific reasoning with code/schema/convention citation}"
```

### Phase 7: Wrap up

After the last finding, give a final tally:

```
All N CodeRabbit findings handled.

Fixed (M): #3, #5, #7, …
Skipped with reasoning (K): #1, #4, …

Last commit on `feature/branch-name`: {sha}
```

## Rules

- **One finding at a time.** Never batch via `AskUserQuestion` multiSelect.
- **Show the fix plan before applying.** Users review the plan, not just the outcome.
- **Evidence-based skips.** Generic "not a real issue" replies are not acceptable. Cite schema line, CLAUDE.md passage, UI guard, or design decision.
- **Priority order**: critical data/logic bugs → UX → a11y → style/defensive.
- **Commit per accepted fix** — not in batch. Enables clean per-finding revert if something regresses.
- **Respect explicit preferences**: "don't commit yet", "don't change this file", "show me the diff first". If the user says "don't change X", revert any staged changes to X immediately.
- **Add WHY-comments for intentional design** when a future reviewer would re-flag the same thing (e.g. intentional-inert affordances, deliberate overrides of component defaults).
- **When proposing refactors that touch shared code** (schemas, shared utilities), present scoped alternatives first and let the user choose scope before applying.

## Technical notes

- Bot username: `coderabbitai[bot]` (with brackets)
- Inline review comments (on lines) vs. issue-level comments (on the PR thread) both need checking
- Threaded replies use `/pulls/.../comments/{comment_id}/replies` (not `/pulls/.../comments/{id}`)
- Use `gh api` for all GitHub interactions
- Extract owner/repo via `gh repo view --json nameWithOwner -q .nameWithOwner`
