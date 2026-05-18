---
description: Create a Linear issue with interactive prompts for priority, status, size, and labels
argument-hint: [issue description or seed text]
---

The user ran `/linear-issue $ARGUMENTS`. Create a Linear issue, using `$ARGUMENTS` (if provided) and any attached images/screenshots as the seed for discovery.

If `$ARGUMENTS` is empty **and** no screenshots/attachments are present, ask the user what they want to file before doing anything else.

## Step 1: Discovery — understand the issue

Before creating the issue, gather enough context to write a precise title and description. Analyze `$ARGUMENTS`, any attached screenshots/images, and prior conversation to identify what information is missing. Then use **AskUserQuestion** to ask clarifying questions (up to 4 at a time). Tailor questions to what's actually unclear — skip questions where the answer is already obvious from context or visible in the screenshot.

Common discovery questions (pick the ones relevant to the specific issue):
- **What exactly should happen?** — the expected behavior or outcome
- **What's the current behavior?** — for bugs, what's broken and how to reproduce
- **Where in the app?** — which page, component, or flow is affected
- **Who is affected?** — specific user roles, plans, or conditions
- **Are there edge cases to consider?** — boundary conditions, error states
- **Any design/UX details?** — mockups, specific interactions, copy text
- **Dependencies or blockers?** — related issues, required API changes, etc.

After gathering answers, synthesize them into:
- A **concise imperative title** (e.g., "Show unread count badge in Master Inbox sidebar")
- A **structured markdown description** with: Context, Expected Behavior, Acceptance Criteria, and any relevant edge cases or notes

Present the drafted title and description to the user for confirmation before proceeding.

## Step 2: Determine the team

The default team is **Getmany: Development** (ID: `e84629f0-7223-4c8d-a39f-d08071bd0330`).

If the user specifies a different team, use that instead. Available teams:
- Getmany: Development
- Getmany: GTM
- Getmany: HR
- Getmany: Support
- Getmany: Strategy
- Getmany SDR

## Step 3: Ask the user for issue details

Use **AskUserQuestion** to ask ALL of the following in a single call (4 questions):

### Question 1: Priority
- header: "Priority"
- Options:
  - **No priority** (description: "No priority set")
  - **Urgent** (description: "Needs immediate attention")
  - **High** (description: "Important, should be done soon")
  - **Normal** (description: "Standard priority")

Note: There is also "Low" priority (value 4) — if the user picks "Other" and types "Low", use priority value 4.

Priority values: No priority=0, Urgent=1, High=2, Normal=3, Low=4

### Question 2: Status
- header: "Status"
- Options:
  - **Backlog** (description: "In the backlog for later")
  - **Ready for Development** (description: "Spec'd and ready to be picked up")
  - **In Development** (description: "Currently being worked on")
  - **Triage** (description: "Needs triage and prioritization")

Note: Other available statuses the user can type via "Other": Shaped, Shaping, Freezed, In Code Review, In Testing, Released, Ready for Release

### Question 3: Size (Estimate)
- header: "Size"
- Options:
  - **XS** (description: "Extra small — quick task, under an hour")
  - **S** (description: "Small — a few hours")
  - **M** (description: "Medium — 1-2 days")
  - **L** (description: "Large — 3-5 days")

Note: Other sizes via "Other": XL (8 points), XXL (13 points), XXXL (21 points)

Size values (Linear T-shirt to Fibonacci): XS=1, S=2, M=3, L=5, XL=8, XXL=13, XXXL=21

### Question 4: Labels (multi-select)
- header: "Labels"
- multiSelect: true
- Options (show the most common ones):
  - **feature** (description: "New feature or functionality")
  - **bug** (description: "Something is broken")
  - **frontend** (description: "Frontend/UI work")
  - **backend** (description: "Backend/API work")

Note: If the user picks "Other", they can type any label name. All available labels:
- Area: fullstack, mobile, data, non-technical, ai, n8n, infra, upwork-integration, legal, apify-actor, auth, billing, backend, frontend
- Type: spike, tech-debt, chore, bug, feature
- Process: needs-spec, qa-failed, blocked, discovery

## Step 4: Create the issue

Use `mcp__linear__save_issue` with:
- **title**: crafted from discovery (user-confirmed)
- **description**: structured markdown from discovery (user-confirmed)
- **team**: "Getmany: Development" (or specified team)
- **assignee**: ALWAYS `b564a759-a60e-4327-b872-7bf638269df5` (Maksym Omelchuk) — never omit this
- **priority**: mapped from user's choice (0-4)
- **state**: mapped from user's choice
- **estimate**: mapped from size (XS=1, S=2, M=3, L=5, XL=8, XXL=13, XXXL=21)
- **labels**: array of selected label names

## Step 5: Confirm

Show the user the created issue identifier (e.g., GETM-1234) and a brief summary.
