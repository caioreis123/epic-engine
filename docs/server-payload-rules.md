# Server Payload Design Rules: GraphQL BFF & Client Contracts

Policy for API payload design across backend resolvers and frontend clients. `/epic-plan` enforces these rules when structuring tasks; executors follow them during implementation.

## New Schema Fields Are Exceptions, Not Defaults

Before introducing a new field, verify in the GraphQL schema—not from memory—whether the web client already reads the value from an existing field. A new payload exposing plan name, price, installments, renewal date, card token, or payment URL often duplicates what `CurrentPlan`, `SubscriptionService`, or `landingPageOffersViewer` already provide.

List field by field:
- **Which existing field covers the value**, or
- **Why no existing field covers it**.

Only fields carrying previously unavailable data survive—typically experiment variant assignments or computed server-side eligibility rules. Duplicate fields create permanent public API contracts that become divergence risks when data sources disagree.

**Include this table in the PR description**:
- Added field
- Why existing fields are insufficient
- Alternatives considered and rejected

Reviewers can verify the rationale without re-investigating the codebase.

### Three Traps Code Inspection Reveals

1. **Declared fields are not necessarily populated.** `CurrentPlan.installmentsText` may exist in the SDL type while the underlying resolver builder always returns `''`. Verify the resolver implementation, not just schema definitions.
2. **Formatted strings hide raw underlying values.** A formatted price string may represent an installment price rather than the total amount. Inspect raw values and units rather than relying on field names.
3. **Reference domain objects instead of duplicating scalars.** Referencing existing object types (e.g., `subscription: SubscriptionDetails!`) delivers necessary fields without minting redundant custom types.

## Copy Lives on the Server; Raw Numbers Too

The system adheres to server-driven UI principles: backend resolvers provide customer-facing copy while the web client renders incoming payloads.

Rule of thumb: If a frontend component would declare `const TITLE = '...'` to render on screen, that text belongs in the server payload. This applies to titles, subtitles, line item labels, button text, banner notices, and toast messages. Only structural constants remain client-side: CSS class names, test attributes (`data-testid`), and cookie identifiers.

This does not conflict with the deduplication rule. Copy does not exist in previous fields, so it passes the novelty check immediately. The boundary is clear:
- The client formats **numbers and dates** from raw values using locale formatters (`Intl.NumberFormat`, `Intl.DateTimeFormat`).
- The server provides the **copy and contextual labels** wrapping those numbers.
