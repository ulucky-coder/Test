---
name: logo-svg-generator
description: Author logo candidates as hand-coded SVG with mathematical constraints — golden ratio grid, ±0.5px pixel-snapping, optical corrections. Use this skill instead of any image-generation model. TRIGGER after moodboard is approved.
allowed-tools: Read, Write, Bash
---

# Logo SVG Generator

Claude composes vector logos directly. This produces editable, accessible, animation-ready, license-clean marks.

## Inputs
- `clients/<slug>/strategy.json` (archetype + visual implications)
- `clients/<slug>/moodboards/<approved>/` (locked direction)
- `research/svg-geometry.md` (constructive geometry primitives)
- `research/golden-ratio.md` (composition rules)

## Output
`clients/<slug>/concepts/{01,02,03}.svg` plus `concepts/{01,02,03}.md` with rationale.

## Hard rules

1. **viewBox**: `0 0 1000 1000` for marks, `0 0 1000 250` for wordmarks.
2. **Snap**: every coordinate to 0.5px or align to a 25-unit golden grid.
3. **Optical correction**: circles overshoot baseline by ~2%, triangles shift centroid up ~3%, "O" wider than "H".
4. **Stroke**: vectorize all strokes (`<path>` only, no `stroke-width` on final). Booleans done in code.
5. **No filters, no gradients in the primary mark** (gradients allowed only for variants).
6. **No `<text>` elements** — outline all glyphs into paths.
7. **No `<script>`, `<foreignObject>`, no external `xlink:href`**.
8. **Accessibility**: include `<title>` and `<desc>` immediately after `<svg>`.

## Process

1. Pick 3 distinct construction strategies (e.g., monogram, abstract symbol, wordmark).
2. For each: draft on the 25-unit golden grid, write commentary mapping each shape to a strategy concept.
3. Run `pre-write-svg.js` hook to enforce rules above.
4. SVGO-lint silently (config: keep viewBox, IDs starting with `g-`).
5. Render PNG previews at 64/256/1024 with `resvg-js` for the rationale doc.

## Quality bar
- Each concept survives the "favicon test" (recognizable at 16×16).
- Each concept has a clear semantic anchor (not arbitrary geometry).
- Optical corrections applied — verify by overlaying a perfect circle/triangle in the rationale.
