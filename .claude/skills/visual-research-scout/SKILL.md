---
name: visual-research-scout
description: Curate reference galleries from Awwwards, Behance, Siteinspire, Godly, Lapa, Landbook, Mobbin via web search. Tags each reference with pattern labels for downstream skills. TRIGGER after strategy.json is approved, before moodboard-builder.
allowed-tools: WebSearch, WebFetch, Write, Read
---

# Visual Research Scout

Build a tagged reference corpus per client so moodboards and concepts are grounded in current world-class work, not training-data averages.

## Inputs
- `clients/<slug>/strategy.json`
- `research/awwwards-teardowns/` (existing teardown corpus)

## Output
`clients/<slug>/research/references.json`:

```json
[
  {
    "url": "https://...",
    "source": "awwwards|godly|lapa|...",
    "title": "",
    "captured_at": "ISO",
    "screenshot_path": "research/shots/<hash>.png",
    "tags": ["swiss-grid", "monospace-display", "scroll-pinned-hero", "noise-texture"],
    "why_relevant": "1-2 sentences tied to strategy.visual_implications",
    "what_to_borrow": ["editorial type scale", "muted palette"],
    "what_to_avoid": ["3d hero (off-archetype)"]
  }
]
```

## Process

1. Build search queries from `strategy.visual_implications` + `industry` + current year.
2. Pull 30-50 candidates across 6+ sources; dedupe by domain.
3. For each candidate, fetch and tag using the controlled tag vocabulary in `research/tag-vocab.md`.
4. Score relevance against strategy; keep top 18 (6 per direction).
5. Emit summary table grouped by direction.

## Quality bar
- Every reference has a `why_relevant` — no orphan inspiration.
- Tags drawn from controlled vocabulary; new tags require updating `tag-vocab.md`.
- No more than 2 references per source domain per direction.
