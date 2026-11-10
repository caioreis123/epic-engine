# Correctness Review Checklist

Scope: correctness bugs, race conditions, type safety, error handling, edge cases, and security vulnerabilities.

## Core Review Principles

- **Both sides of every comparison:** Analyze both operands independently. Verify runtime types, nullability, locale formatting, and unexpected string coercions (e.g., `"10,50"` coerced to `NaN`).
- **Conditional boundary cases:** Enumerate all boolean permutations for new guards. Ensure negations (`!(A && B)`) do not accidentally permit or suppress unrelated valid flows.
- **Async concurrency & race conditions:** Watch for non-atomic database read-modify-write patterns, missing transaction rollbacks, unhandled Promise rejections, and stale caches.
- **Magic literals:** Identify inline magic strings and numbers. Flag them to be extracted into named constants.
- **Server contract duplication:** Verify the client does not maintain local copies of server-owned enumerations or eligibility tables.

## Verification Against Worktree

Always inspect callers and downstream consumers in the detached worktree.
Check for:
- Method shadowing in subclasses or traits.
- Call sites that bypass the new validation check.
- Duplicate implementations across packages.
