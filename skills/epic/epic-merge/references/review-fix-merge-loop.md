# Autonomous Review-Fix-Merge Loop

Drives an approved pull request through automated code review cycles to completion.

## The Review Loop

```
1. Fetch automated review findings via gh api / review comments
2. Triage findings:
   - Valid suggestions: implement in a distinct commit and push to branch
   - False positives: reply with technical justification and dismiss/resolve thread
3. Re-trigger review evaluation
4. Verify review decision:
   - If APPROVED and checks green -> squash merge (gh pr merge --squash)
   - If CHANGES_REQUESTED -> repeat loop
   - If persistent stall -> escalate to human operator
```

## Best Practices

- Always implement each valid suggestion in its own atomic commit referencing the finding ID so reviewers can verify the fix.
- Do not perform destructive rebases while automated review cycles are active.
- Verify that CI test checks are green before triggering squash merges.
