# Review Size Gates & Diff Boundaries

Review bots and human reviewers reject or stall on pull requests with excessively large diffs. When splitting pull requests, adhere to these **four independent review gates**:

## The Four Review Gates

1. **File-Count Gate (Hard Limit: 300 Files):**
   A pull request touching more than 300 changed files cannot be processed by automated review endpoints (returns HTTP 406). This count is evaluated **before** path filters run; generated files, lockfiles, and assets still count toward the 300-file threshold.
2. **Line-Count Gate (Hard Limit: 20,000 Diff Lines):**
   Pull requests with more than 20,000 unified diff lines fail deterministic review ingestion.
3. **Byte Gate (Max 50 KB Filtered Diff):**
   The raw filtered diff payload should not exceed 50 KB.
4. **Token Gate (Max 15,000 Tokens):**
   The estimated token count of the filtered diff (`len(diff) / 4`) must stay below 15k tokens. Exceeding this triggers automated `too_large` review rejection.

## Excluded Paths (Dropped by Filters)

Standard path filters drop these files before evaluating byte and token limits:
- **Lockfiles:** `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `go.sum`, `Cargo.lock`
- **Generated Code:** `*.pb.go`, `*.generated.*`, `__generated__/`, `**/generated/**`
- **Vendor:** `node_modules/`, `vendor/`
- **Build Output:** `dist/`, `build/`, `.next/`, `target/`
- **Snapshots:** `*.snap`, `*.snapshot`

## Splitting Rules

- Split PRs along atomic functional boundaries using commit-grouped slicing.
- Keep individual child PRs under 15 changed files and 500 diff lines whenever possible.
- If a generated schema or mock update is unavoidably large, separate it into a dedicated artifact PR.
