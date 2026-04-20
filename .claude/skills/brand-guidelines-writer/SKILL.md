---
name: brand-guidelines-writer
description: Emit MDX brand guidelines doc (logo rules, clear space, color, type, voice, imagery, motion) plus PDF export. TRIGGER after brand system locked.
allowed-tools: Read, Write, Bash
---

# Brand Guidelines Writer

Produces a guidelines doc the client can hand to any vendor and get on-brand work.

## Inputs
- `clients/<slug>/strategy.json`
- `clients/<slug>/logo/`
- `clients/<slug>/tokens.json`
- `templates/guidelines.template.mdx`

## Output
- `clients/<slug>/guidelines.mdx`
- `clients/<slug>/guidelines.pdf` (rendered via headless Chromium print)

## Sections (mandatory)
1. **Brand Story** (1 page): mission, archetype, voice
2. **Logo System**: primary, lockups, monogram, favicon, clear space, minimum sizes, do/don't
3. **Color**: palette swatches with OKLCH/HEX/RGB, semantic mapping, contrast matrix
4. **Typography**: triad with specimens, scale, leading/tracking, do/don't
5. **Voice & Tone**: vocabulary do/don't, sentence shape, examples
6. **Imagery & Iconography**: style direction, treatment rules
7. **Motion**: easing curves, durations, reduced-motion behavior
8. **Application**: web, social, print, merchandise examples
9. **Do/Don't Gallery**: 8+ paired wrong/right examples

## Quality bar
- Every section has at least one visual example rendered from real assets.
- PDF prints crisply on A4 portrait.
- Searchable text (no flattened images of body copy).
