# SVG Internals & Logo Geometry

## Summary
Logo SVG must be mathematically composed, optically corrected, and legally "hand-drawn" so it survives scale, animation, and trademark scrutiny. Rules below are enforced by `pre-write-svg.js` hook.

## Grid & viewBox
- Marks: `0 0 1000 1000`. Wordmarks: `0 0 1000 250`.
- Snap all coords to 0.5 px or align to 25-unit golden grid (40 cells).
- Construction baseline at y=900; cap height at y=200 for wordmarks.

## Optical correction library
- Circle next to square of same nominal height → make circle ~102% tall (baseline overshoot).
- Triangle same nominal height → centroid up 3% (visual centering).
- "O" wider than "H" by 2–4%.
- Diagonal strokes 85–90% of vertical stroke width (optical weight match).
- Pointed corners (A, V, W) extend past baseline/cap by 1–2%.

## Path hygiene
- Boolean ops in code, not via filters. Output single `<path>` per silhouette where possible.
- No `stroke-width` on final; outline strokes to paths.
- `fill-rule="evenodd"` for holes; never rely on non-zero with self-intersections.
- `id` attributes prefixed `g-` (e.g., `g-mark`, `g-wordmark`) for motion targeting.

## Accessibility
- `<title>` + `<desc>` immediately after `<svg>`.
- `role="img"` on `<svg>`; `aria-labelledby` referencing title id.

## Forbidden
- `<script>`, `<foreignObject>`, `on*` handlers, external `xlink:href`.
- `<text>` in final marks (except type specimens).
- Filters/gradients in the primary lockup (variants only).

## Favicon test
Primary must remain legible at 16×16. If not, the concept is disqualified.

## Updated
2026-04-20
