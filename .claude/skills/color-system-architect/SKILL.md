---
name: color-system-architect
description: Generate OKLCH-based semantic palettes, check WCAG AA/AAA contrast, produce light/dark/high-contrast token sets. TRIGGER after logo system approved.
allowed-tools: Read, Write, Bash
---

# Color System Architect

Single source of truth for color, perceptually uniform, semantic-first.

## Inputs
- `clients/<slug>/moodboards/<approved>/palette.json`
- `clients/<slug>/strategy.json`

## Output
`clients/<slug>/tokens.json` (color section) + `tokens.css`:

```json
{
  "color": {
    "brand": {
      "primary":   { "light": "oklch(58% 0.18 250)", "dark": "oklch(72% 0.16 250)" },
      "secondary": { "light": "oklch(48% 0.14 30)",  "dark": "oklch(80% 0.12 30)" },
      "accent":    { "light": "oklch(85% 0.22 90)",  "dark": "oklch(88% 0.22 90)" }
    },
    "neutral": {
      "0":   { "light": "oklch(99% 0 0)",   "dark": "oklch(8% 0 0)" },
      "50":  { "light": "oklch(96% 0 0)",   "dark": "oklch(12% 0 0)" },
      "100": { "light": "oklch(92% 0 0)",   "dark": "oklch(18% 0 0)" }
    },
    "semantic": {
      "bg":         { "ref": "neutral.0" },
      "surface":    { "ref": "neutral.50" },
      "text":       { "ref": "neutral.900" },
      "text-muted": { "ref": "neutral.600" },
      "border":     { "ref": "neutral.200" },
      "success":    { "light": "oklch(60% 0.18 145)", "dark": "oklch(72% 0.16 145)" },
      "warning":    { "light": "oklch(75% 0.18 80)",  "dark": "oklch(82% 0.16 80)" },
      "danger":     { "light": "oklch(58% 0.22 25)",  "dark": "oklch(70% 0.20 25)" }
    }
  }
}
```

## Process
1. Use `culori` for OKLCH → all-format conversions.
2. Derive 11-step neutral ramp (0–1000) from a single L\* anchor; ensure even perceptual steps.
3. For brand colors, lock chroma; vary lightness for light/dark.
4. Verify WCAG: every `text` × `bg` combo ≥ AA (4.5:1); record results in `tokens.report.json`.
5. Generate Tailwind v4 `@theme` block, CSS vars, TS types via codegen.

## Quality bar
- All semantic combos pass AA, primary CTAs pass AAA.
- Dark mode is computed (not hand-flipped) — same hue, mirrored lightness.
- High-contrast mode bumps all contrast to ≥ 7:1.
