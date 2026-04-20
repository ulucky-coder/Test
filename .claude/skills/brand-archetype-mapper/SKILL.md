---
name: brand-archetype-mapper
description: Map a normalized brief against the Jung/Pearson 12-archetype matrix and Aaker brand personality dimensions to emit a strategic positioning vector. TRIGGER after brief.json is approved.
allowed-tools: Read, Write
---

# Brand Archetype Mapper

Translate brief language into deterministic archetype scores so visual decisions become defensible, not vibes-based.

## Inputs
- `clients/<slug>/brief.json`
- `research/archetypes.md` (12 Jungian + 5 Aaker definitions with concrete cue-words)

## Output
`clients/<slug>/strategy.md` and `clients/<slug>/strategy.json`:

```json
{
  "archetypes": {
    "primary": { "name": "Sage", "score": 0.82 },
    "secondary": { "name": "Creator", "score": 0.61 }
  },
  "aaker": {
    "sincerity": 0.4, "excitement": 0.7, "competence": 0.85,
    "sophistication": 0.6, "ruggedness": 0.1
  },
  "voice": {
    "vocabulary": ["precise", "evidence-based"],
    "avoid": ["hype", "aspirational fluff"],
    "sentence_shape": "short declaratives",
    "humor": "dry"
  },
  "visual_implications": [
    "monospaced or geometric sans display",
    "high-contrast neutral palette with one cool accent",
    "diagrams over photography",
    "no gradients in body, gradients allowed for hero only"
  ]
}
```

## Process

1. Score each of 12 archetypes by matching brief tokens to cue-words.
2. Pick top 2; if delta < 0.1 between #2 and #3, output a blended secondary.
3. Compute Aaker scores from tone_axes + archetype mapping table in `research/archetypes.md`.
4. Translate to concrete `visual_implications` — these become hard constraints for `moodboard-builder` and `logo-svg-generator`.
5. Write strategy doc with rationale paragraphs (2-3 sentences per axis).

## Quality bar
- Visual implications must be specific enough to reject candidate designs (e.g., "no gradients in body" is testable).
- If archetype primary score < 0.55, surface as a brief gap and request `/revise strategy`.
