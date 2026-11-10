---
name: implement-skill-improvements
description: >-
  Automated meta-learning engine for the entire repository. Scans session conversation transcripts
  after user corrections, failed execution steps, or discovered edge cases, and proposes surgical
  before/after updates across all epic-*, agent-*, and implement-* skills.
---

# Implement Skill Improvements

## Overview

The self-evolution engine of Epic Engine. Discovers systematic operational learnings from conversation transcripts and updates skill playbooks directly, ensuring the multi-agent system continuously refines its capabilities.

## Systematic Learning Categories

1. **User Corrections:** The human operator corrected an assumption, adjusted a workflow, or refined an execution boundary.
2. **Failed Skill Steps:** A command, flag, path, or assertion failed during execution, accompanied by the verified workaround that resolved it.
3. **Repository Invariants:** Newly discovered build steps, migration quirks, port conflicts, or schema constraints.
4. **Coverage Gaps:** Missing domain specializations that required improvisation during the session.

## Systematic Quality Gate

Encode **reusable operational checks**, never one-off code fixes:
- Drop transient network retries or session typos.
- Formulate instructions as deterministic rules that prevent future agents from repeating the mistake.
- Target the exact section of the relevant skill.

## Workflow

### 1. Harvest Transcript Learnings
Inspect conversation history for corrections, command failures, and operator directives.

### 2. Map Learnings to Target Skills
Identify matching skill playbooks across the three namespaces:
- `skills/epic/`: Control plane, state transitions, dossier management, validation gates.
- `skills/agent/`: Multi-agent runtime, role routing, Herdr topologies, watchdog policies.
- `skills/implement/`: Domain implementation playbooks, UI pixel verification, analytics contracts.

### 3. Generate Surgical Before / After Proposals
Draft the minimal necessary markdown changes:
```markdown
| Target Skill | Observed Failure / Correction | Proposed Diff (Before / After) |
|---|---|---|
| skills/implement/implement-ui/SKILL.md | Icon color false-positive on gradients | Added peak contrast threshold rule |
```

### 4. Operator Approval Gate
Present the proposed improvements table to the operator.
Apply updates only upon explicit operator confirmation.
