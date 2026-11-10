# The Integration PR Model

Canonical reference for **why** this SDLC architecture uses integration PRs. `epic-plan`, `epic-implement`, `epic-split`, and `executor.md` declare their operational rules based on this model.

## The Rules

1. **One integration PR per repository, not per task.** Each repository in the epic uses a dedicated worktree and an `epic/<slug>` branch based on `main`. All tasks for that repository iterate on this single branch.
2. **One commit per task**, stamped with the issue key and task identifier (`task-<N>, EPIC-101`). No squash, no amend on prior commits, and no rebasing while in flight.
3. **Cross-repo dependencies do not stack in git.** Branches in different repositories never stack in git. Their dependency is an order of review and deployment, declared in PR descriptions and synchronized via the review-wave table.
4. **Target validation suites close the queue.** Baselines and end-to-end assertions run against finalized upstream changes, so validation tasks never run in parallel with the code changes they verify.
5. **The integration PR never merges directly.** It serves as an iterative development workspace. Once implementation stabilizes, `/epic-split` breaks the integration branch into small, focused, reviewable PRs and closes the integration PR.

## The Rationale

The dominant cost of software implementation is **changing design midway**. While requirements and UI details settle, making a mid-stream change costs:

- In an integration PR: **one additional commit**;
- In stacked atomic branches: **a cascading restack** of every downstream branch on every revision.

Slicing code into small PRs is therefore the **final** mechanical step, not the first. During code review, forces invert: large PRs stall review cycles, automated linters hit diff thresholds, and humans cannot review 40 files effectively. That is where `/epic-split` steps in: when iteration is finished and review begins.

One commit per task makes splitting mechanical and reliable: it groups commits rather than performing risky manual patch surgery. Stamped commit messages become PR titles and serve as deterministic task delivery criteria for the orchestrator.
