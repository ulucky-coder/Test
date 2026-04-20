---
name: typography-pairing
description: Select display + text + mono triads with licensing data, variable axis ranges, and a computed modular scale. TRIGGER alongside color-system-architect.
allowed-tools: Read, Write, WebFetch
---

# Typography Pairing

Pick three typefaces that solve the brief, are legally usable, and ship as variable fonts.

## Inputs
- `clients/<slug>/strategy.json`
- `clients/<slug>/moodboards/<approved>/type.json`
- `research/typography.md` (curated foundries + licensing)

## Output
`clients/<slug>/tokens.json` (typography section):

```json
{
  "type": {
    "families": {
      "display": { "name": "Inter Display", "source": "fontsource", "axes": { "wght": [100,900], "opsz": [14,32] }, "license": "OFL" },
      "text":    { "name": "Inter",         "source": "fontsource", "axes": { "wght": [400,700] }, "license": "OFL" },
      "mono":    { "name": "JetBrains Mono","source": "fontsource", "axes": { "wght": [400,700] }, "license": "OFL" }
    },
    "scale": {
      "ratio": 1.250,
      "base_px": 16,
      "steps": ["xs","sm","base","md","lg","xl","2xl","3xl","4xl","5xl","6xl"]
    },
    "leading": { "tight": 1.1, "snug": 1.25, "normal": 1.5, "loose": 1.7 },
    "tracking": { "tight": "-0.02em", "normal": "0", "wide": "0.05em" }
  }
}
```

## Process
1. Map archetype to type vocabulary (Sage→serif/grotesk, Jester→display/quirky, Ruler→Didone, etc.).
2. Pick 3 candidate triads, score by licensing accessibility (OFL > paid foundry > Adobe Fonts).
3. Verify variable axes — prefer fonts with `wght` and `opsz` ranges.
4. Compute modular scale; emit Tailwind v4 utilities.
5. Render specimen sheet via `packages/svg-kit`.

## Quality bar
- All three families must have a clear license path documented in `tokens.report.json`.
- Display + text must have a contrast strategy (size, weight, or genre).
- No font with > 200KB woff2 per axis combination loaded by default.
