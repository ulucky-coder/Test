---
name: logo-variant-forger
description: Derive the full lockup system (horizontal, stacked, monogram, favicon, monochrome, inverse, safe-area rules) from an approved primary logo. TRIGGER after a primary concept is approved.
allowed-tools: Read, Write, Bash
---

# Logo Variant Forger

Turns one approved mark into the full delivery kit.

## Inputs
- `clients/<slug>/concepts/<approved>.svg`
- `clients/<slug>/strategy.json`

## Output
`clients/<slug>/logo/`:
```
primary.svg
horizontal.svg          (mark + wordmark side-by-side)
stacked.svg             (mark above wordmark)
monogram.svg            (initials only)
favicon.svg, favicon-32.png, favicon-16.png, apple-touch.png (180x180)
monochrome-black.svg, monochrome-white.svg
inverse.svg             (for dark backgrounds)
safe-area.svg           (clear-space spec drawing)
construction.svg        (geometry exposed for guidelines)
exports/
  png-{64,128,256,512,1024,2048}.png
  pdf/primary.pdf
  eps/primary.eps        (via svg2eps)
```

## Process
1. Reuse coordinate system from primary; snap variants to same grid.
2. Wordmark: outline an approved typeface, kern by hand to ±5 units.
3. Safe-area: derive from x-height of wordmark or 1/4 mark height.
4. Run all variants through SVGO + accessibility audit.
5. Generate raster exports via `resvg-js`.

## Quality bar
- All variants pixel-perfect at favicon scale.
- Inverse and monochrome maintain identical silhouette.
- Safe-area diagram is mathematically derived, not eyeballed.
