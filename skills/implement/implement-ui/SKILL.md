---
name: implement-ui
description: >-
  Use when implementing or verifying user interfaces against Figma design specifications:
  enforces quantitative Pillow bounding-box alignment (<= 3pp) and icon RGB peak distance (< 40) gates.
---

# Implement UI

Read `docs/workflow-contract.md` for authorization, ownership, tracking, and repository boundaries.

A user interface is correct when element coordinates, relative dimensions, typography, and colors match Figma reference specifications quantitatively.
DOM assertions and visual inspection are insufficient: visual fidelity requires automated pixel measurements.

## Steps

### 1. Ingest Design Specifications
Reference artifacts in `<epic>/exported-design/<frame>/`:
- `manifest.json`: frame dimensions and node coordinates.
- `tokens.json`: typography, color values, and spacing tokens.
- `frame.png`: reference rendered image.

### 2. Element Inventory
Build a comprehensive inventory table of all visible elements:
- Text blocks, CTA buttons, icons, dividers, card containers.
- Normalized X coordinate and width as percentage of container.
- Typography size, font weight, line height, and color tokens.

### 3. Quantitative Measurement Gate (Pillow Verification)
Run an automated verification script (using Python Pillow) comparing the rendered screenshot against the Figma export:
- Crop identical sections from the reference frame and rendered output.
- Normalize measurements relative to container width.
- Measure:
  1. **Bounding-Box Alignment:** Bounding box relative X position and width delta must be **`<= 3pp`** (percentage points) per block.
  2. **Icon and Color Distance:** Peak RGB euclidean distance for icons and accents must be **`< 40`**. Peak color represents the pixel with maximum contrast from background.

Attach raw before-and-after measurement tables to the pull request description.
PRs with bounding box deltas `> 3pp` or icon color distances `>= 40` fail the UI quality gate.
