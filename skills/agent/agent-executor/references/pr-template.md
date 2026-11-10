# Pull Request Template & Opening Guidelines

Guidelines and template for pull requests opened by `agent-executor`.

## Workflow

1. **Verify template:** Read `.github/pull_request_template.md` (or `PULL_REQUEST_TEMPLATE.md`) if present. Retain all standard sections.
2. **Review wave table:** If part of a multi-PR or multi-repo delivery wave, place the `<!-- review-wave:start -->` table at the very top of the PR body.
3. **Summary block:** Place an executive summary quote directly under the wave table:
   ```markdown
   > **Summary:** Implements server-side eligibility check for annual upgrade popover.
   > Reads existing subscription status without adding duplicate schema fields.
   > Prevents showing upgrade offers to already annual subscribers.
   ```
4. **Draft PR:** Always open implementation PRs in **draft** status (`gh pr create --draft`).
5. **Assignee & Links:** Assign to `@me` and link the corresponding Jira issue key (`EPIC-101`).

## Standard PR Body Template

```markdown
<!-- review-wave:start -->
<!-- review-wave:end -->

> **Summary:** <Three to four concise sentences describing what changed, why, and impact.>

## Why

<Problem statement or business driver. Cite the issue key: EPIC-nnn.>

## What It Does

- <Concrete change 1>
- <Concrete change 2>
- <Concrete change 3>

## Verification & Testing

- <Commands run to verify the change>
- <Unit / integration test results>
- <Evidence links or local execution outputs>

## Review Notes

- Dependent on: <Upstream PR or schema change if applicable>
```
