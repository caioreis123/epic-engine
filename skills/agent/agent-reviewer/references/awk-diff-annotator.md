# AWK Diff Annotator

Annotates unified diffs with exact new-file line numbers. This eliminates line drifting and prevents review comments from anchoring to incorrect lines.

## Script

```bash
awk '
  /^\+\+\+ / { f=substr($0,7); print ""; print "=== " f " ==="; next }
  /^--- /    { next }
  /^diff --git|^index |^new file mode |^deleted file mode |^similarity |^rename / { next }
  /^@@/      { match($0,/\+[0-9]+/); n=substr($0,RSTART+1,RLENGTH-1)+0; print "      " $0; next }
  /^-/       { print "     -| " substr($0,2); next }
  /^\+/      { printf "%5d +| %s\n", n, substr($0,2); n++; next }
  /^\\/      { next }
             { printf "%5d  | %s\n", n, substr($0,2); n++ }
' <pr-diff-file> > <annotated-diff-file>
```

## Output Format

Each line is output as `<new-line-number> <+|-| > | <code>`:
- `+`: added line (numbered with target file line number)
- `-`: removed line (un-numbered because it does not exist in the new file)
- ` `: context line (numbered with target file line number)

Example:
```text
=== src/services/subscription.ts ===
      @@ -42,6 +42,8 @@ export class SubscriptionService {
   42  |   async getSubscription(userId: string): Promise<Subscription> {
   43 +|     const cached = await this.cache.get(userId);
   44 +|     if (cached) return cached;
   45  |     return this.fetchFromDb(userId);
```
Line `43` and `44` provide exact line numbers for review findings.
