---
name: scope-guard
description: >
  PROACTIVELY TRIGGER THIS SKILL. Prevents scope creep by decomposing work into focused Issues
  and branches. Trigger on ANY of these:
  - ANY task that involves writing/modifying code (even "small" changes)
  - User describes work: "I want to...", "...を作りたい", "...を追加", "...を修正", "...を変更"
  - Commit/PR: "commit", "push", "PR", "プルリク", "マージ", "コミット"
  - Planning: "what should I work on", "plan", "break down", "次何する", "タスク整理"
  - Scope creep signals: "while I'm at it", "ついでに", "あと...", "also", "one more thing"
  - When git diff shows changes spanning multiple concerns
  - When the conversation has produced >200 lines of changes without a commit
  - At the START of every new coding session
---

# Scope Guard — Focused Branch Discipline

You help developers keep branches focused and reviewable. You intervene **constantly and proactively**
at three stages: planning (before code), monitoring (during work), and completion (commit/PR time).

**IMPORTANT**: This skill should be invoked aggressively. When in doubt, trigger it.
It is better to over-check scope than to let a branch grow out of control.

## Core Principles

- One branch = one reviewable unit of work
- A PR should be understandable in under 15 minutes of review
- Prefer many small PRs over one large PR
- Unrelated changes belong on separate branches, even if discovered during work
- Always create a GitHub Issue before starting a branch

## Stage 1: Planning — Issue Decomposition

When the user describes work they want to do (e.g., "I want to add auth and a dashboard"),
BEFORE writing any code:

1. **Clarify scope**: Ask what the end goal looks like. What should work when they're done?
2. **Decompose into issues**: Break the work into the smallest shippable units.
   Each issue should be:
   - Independently deployable (passes CI, doesn't break main)
   - Reviewable in one sitting (aim for <400 lines of meaningful diff)
   - Clearly titled with acceptance criteria
3. **Suggest ordering**: Which issues depend on which? What's the best sequence?
4. **Present the plan**: Show the proposed issues as a numbered list with:
   - Title
   - 1-2 line scope description
   - Estimated complexity (S/M/L)
   - Dependencies on other issues
5. **Get confirmation**: Ask the user to confirm or adjust before proceeding.
6. **Create issues and branch**: After confirmation, use `gh issue create` and
   `git checkout -b <branch-name>` for the first issue only.

### Branch Naming Convention

```
<type>/<issue-number>-<short-description>
```

Types: `feat/`, `fix/`, `refactor/`, `docs/`, `chore/`

Example: `feat/42-add-login-form`

### Issue Template

```bash
gh issue create \
  --title "<concise title>" \
  --body "## What
<1-2 sentences describing the change>

## Acceptance Criteria
- [ ] <specific, testable criterion>
- [ ] <specific, testable criterion>

## Scope Boundaries
- NOT included: <explicitly list what's out of scope>

## Notes
- Part of: <link to parent issue or epic if applicable>"
```

## Stage 2: Monitoring — Early Scope Creep Detection

While working on a branch, ACTIVELY WATCH for these signals:

### Red Flags (Alert immediately)

- User asks to change files unrelated to the current issue
- User says "while I'm at it..." or "let me also..." or "ついでに..."
- Changes touch more than 3 unrelated directories
- The diff is growing beyond ~400 lines of meaningful changes
- A new feature or fix is being added that wasn't in the issue

### How to Intervene

When you detect scope creep, say something like:

> ⚠️ **Scope check**: This change (<describe it>) looks separate from the current
> issue (#N: <title>). I see a few options:
>
> 1. **Note it for later** — I'll create a new Issue for this and we stay focused
> 2. **Switch branches** — Stash current work, start a new branch for this
> 3. **Include it** — If you think it's tightly coupled, we keep it here
>
> What do you think?

If the user chooses option 1:
- Create a GitHub Issue capturing the idea with enough context
- Add a TODO comment in the code if helpful: `// TODO: see #<issue-number>`
- Continue on the current branch

If the user chooses option 2:
- `git stash` or commit current work-in-progress
- Create the new issue, checkout a new branch
- After completing the side-task, return to the original branch

If the user chooses option 3:
- Acknowledge and continue, but update the issue description to reflect expanded scope

### Proactive Check-ins

At natural breakpoints (after completing a logical unit of work, before starting
something new), briefly confirm:

> Still working on #N (<title>). Next up: <what you're about to do>.
> Does this still belong in this branch?

Keep this lightweight — one line, not a wall of text. Skip if the work clearly
fits the current scope.

## Stage 3: Completion — Commit & PR Discipline

### On Commit

When the user asks to commit:

1. Review staged changes with `git diff --cached --stat`
2. If changes look focused → proceed with a conventional commit message
3. If changes span multiple concerns → suggest splitting into multiple commits:
   - Use `git add -p` to stage related hunks together
   - Each commit should have a clear, single-purpose message

### Commit Message Format

```
<type>(#<issue>): <concise description>

<optional body explaining why, not what>
```

Example: `feat(#42): add email/password login form`

### On PR Creation

When the user asks to create a PR:

1. **Pre-flight checks**:
   - Run tests if a test command is available
   - Check diff size with `git diff main --stat | tail -1`
   - Verify branch is up-to-date with main

2. **If diff is small and focused** (<400 lines, single concern):
   - Create PR linking to the issue
   - Include a concise summary and test plan

3. **If diff is large or mixed** (>400 lines or multiple concerns):
   - Alert the user with specific stats
   - Suggest how to split (which files/changes belong together)
   - Offer to help create separate branches from the current work

### PR Template

```bash
gh pr create \
  --title "<type>(#<issue>): <description>" \
  --body "## Summary
Closes #<issue-number>

<2-3 bullet points of what changed and why>

## Changes
- <categorized list of changes>

## Test Plan
- [ ] <how to verify this works>

## Preview
<Vercel/AWS preview URL if available>

## Screenshots
<if UI changes>"
```

## Language & Tone

- Be concise and direct — developers don't want walls of text
- Use the user's language (Japanese or English) to match their input
- Frame interventions as options, not commands
- Acknowledge that small scope creep is normal — the goal is awareness, not rigidity
- It's OK to let minor, tightly related changes through without flagging

## What This Skill Does NOT Do

- Enforce rigid rules — this is guidance, not a linter
- Block the user from making decisions — always present options
- Manage releases or deployment — that's outside scope
- Handle merge conflicts — use git tools directly
