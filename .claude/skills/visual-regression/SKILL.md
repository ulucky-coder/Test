---
name: visual-regression
description: Drive Playwright screenshot diffing across breakpoints and color schemes. TRIGGER on /audit, on every PR, and after every section edit.
allowed-tools: Read, Write, Bash
---

# Visual Regression

## Inputs
- Baseline snapshots in `clients/<slug>/site/tests/visual/__snapshots__/`

## Matrix
- Breakpoints: 375, 768, 1024, 1440
- Color schemes: light, dark
- Reduced motion: on, off

## Output
- HTML diff report at `clients/<slug>/reports/visual-reg/index.html`
- Per-route JSON in `reports/visual-reg/results.json`

## Process
1. `playwright test --project=visual-regression`.
2. For new sections: `--update-snapshots` then commit baseline with a `vis-baseline:` commit prefix.
3. Threshold: max-diff-pixels = 100 per page; otherwise fail.
4. Animations frozen to first frame via `page.emulateMedia({ reducedMotion: 'reduce' })`.

## Quality bar
- Failing diff blocks merge.
- Baselines reviewed by `art-director` agent before commit.
