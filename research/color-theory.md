# Color for Brand Systems

## Summary
OKLCH is the correct color space for brand systems — perceptually uniform, hue-stable across lightness, gamut-aware. Every palette is defined in OKLCH and rendered to HEX/RGB/P3 at build time.

## OKLCH primer
- **L** (0–1): perceptual lightness.
- **C** (0–0.4 in sRGB): chroma.
- **h** (0–360): hue angle.
- Dark-mode = mirror L around 0.5, keep C and h stable for hue-identity.

## Industry color bias (seeds, not rules)
- Fintech: navy + trust-blue + green accent
- Wellness: terracotta + sage + cream
- DevTools: off-black + electric accent
- DTC: hero color + cream neutral
- Gov/Legal: deep neutral + conservative accent
- Creator tools: iridescent capable (flagship only)

## Contrast rules (enforced)
- Body text on bg: ≥ AA (4.5:1).
- Primary CTA text on CTA bg: ≥ AAA (7:1).
- Placeholder, disabled, captions: ≥ 3:1 (AA large).
- High-contrast theme: all combos ≥ 7:1.

## Gamut & display
- Default palette must be in sRGB gamut; P3 extensions tagged `color(display-p3 ...)`.
- Avoid ultra-saturated OKLCH beyond C=0.25 (breaks on low-gamut displays).

## Tools
- `culori` for OKLCH → sRGB/P3/HEX conversions and contrast math.
- `polychrome` for interactive exploration during moodboard phase.

## Updated
2026-04-20
