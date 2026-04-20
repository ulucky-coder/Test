---
name: moodboard-builder
description: Assemble 3 divergent visual directions (Swiss minimalism, brutalism/anti-design, glass/neumorphism by default) with rationale, color seeds, type seeds, motion tone. TRIGGER after visual-research-scout completes.
allowed-tools: Read, Write, Bash
---

# Moodboard Builder

Translate references + strategy into 3 *intentionally divergent* directions so the client picks based on direction rather than refinement.

## Inputs
- `clients/<slug>/strategy.json`
- `clients/<slug>/research/references.json`
- `research/trends-2026.md` for current visual vocabulary

## Output
`clients/<slug>/moodboards/{01,02,03}/` each containing:
- `direction.md` — name, one-paragraph manifesto, do/don't list
- `palette.json` — 5 OKLCH seeds + 1 accent
- `type.json` — display + text + mono triad with licensing notes
- `motion.json` — easing curve, durations, mood word
- `references.md` — grid of 6 references with captions
- `preview.svg` — composed moodboard preview (use `packages/svg-kit`)

## Process

1. Cluster references by tag similarity to derive 3 distinct centers of mass.
2. If clusters collapse (too similar), force-diverge by adopting Swiss / Brutalist / Glass anchors.
3. For each direction, draft palette via `color-system-architect` (preview only — no token freeze yet).
4. For each direction, draft type triad via `typography-pairing`.
5. Render `preview.svg` showing palette swatches, type specimen, and 3 thumbnail references.
6. Write `direction.md` with a manifesto that the client can adopt verbatim.

## Quality bar
- 3 directions must score >0.5 distance on tag-Jaccard.
- Each direction must defensibly serve the primary archetype (no off-strategy moodboards).
- Preview SVG renders crisply at 1200×630 (OG-image friendly for client review).
