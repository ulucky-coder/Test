---
name: copy-polisher
description: Rewrite section copy to match the brand voice extracted by brand-archetype-mapper. Cuts marketing fluff, enforces sentence shape rules, runs Hemingway-style scoring. TRIGGER on /run-phase site-build and after every content edit.
allowed-tools: Read, Write, Edit
---

# Copy Polisher

The brand voice is a constraint, not a suggestion.

## Inputs
- `clients/<slug>/strategy.json` (voice section)
- `clients/<slug>/site/content/*.json`

## Process
1. For each string, score against `voice.vocabulary` (do/avoid lists).
2. Reject sentences > `voice.sentence_shape` length budget.
3. Replace cliché phrases ("revolutionary", "game-changing", "world-class") with concrete claims.
4. Keep numbers, proper nouns, and CTAs untouched.
5. Run Hemingway-equivalent scoring; flag passive voice and adverb density.

## Output
Rewritten `content.json` + `clients/<slug>/reports/copy-review.md` showing before/after diffs and rejected phrases with rationale.

## Quality bar
- Reading grade ≤ 9 unless brief specifies otherwise.
- Zero cliché phrases from the global blocklist (`research/cliches.md`).
- Every CTA has a verb + outcome (not "Learn more").
