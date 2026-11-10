# Quality & Test Coverage Review Checklist

Scope: test coverage, test quality, contract validation, and documentation integrity.

## Phase 1: Test Coverage Gap Audit

For every modified or newly introduced source file:
- Verify corresponding tests exist.
- Ensure integration tests exercise the changed code in its actual runtime context, not merely unit tests of isolated helper classes.
- A functional code modification without corresponding test verification represents a Critical finding.

## Phase 2: Test Rigor & Quality

- **Test names must reflect actual assertions:** If a test claims to verify behavior "regardless of flag status", ensure it runs assertions across both enabled and disabled flag states.
- **Changed contracts require caller integration tests:** When an API contract or method signature changes, verify that caller integration tests exercise the updated signature.
- **Avoid fragile mocks:** Assertions should verify observable behavior and state changes rather than internal implementation minutiae.

## Phase 3: Documentation and Comment Hygiene

- Verify docstring accuracy against actual runtime return paths.
- Remove obsolete comments (comment rot).
- Flag redundant comments that merely restate readable code.
