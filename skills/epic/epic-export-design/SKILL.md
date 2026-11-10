---
name: epic-export-design
description: >-
  Exports design frames from Figma into exported-design/ within an epic dossier using
  automated design extractors. Use when an epic receives new designs or when Figma frames are updated.
---

# Epic Export Design

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

Exports design frames from Figma URLs into `<epic>/exported-design/<frame-name>/`.
Extracts layout coordinates, typography tokens, color palettes, and rendered image assets for UI implementation and visual validation.

## Usage

```
/epic-export-design <epic-hint> <figma-url | key: figma-url>...
```

`<epic-hint>` represents the epic slug or card key.

## Workflow

### 1. Resolve Epic Dossier Path

```bash
EPIC="$(lib/epic-lib/epic-context.sh --path <epic-hint>)"
```

### 2. Output Structure

Exports are written to:
`<epic>/exported-design/<frame-name>/`
- `manifest.json`: Figma node ID, file key, and bounding box dimensions.
- `tokens.json`: Typography, colors, and layout spacing tokens.
- `frame.png`: Rendered reference image used by `implement-ui` for Pillow bounding-box and color comparison.

### 3. Verification

Inspect exported frame dimensions and ensure asset images are stored directly in the dossier, ready for `implement-ui` assertions.
