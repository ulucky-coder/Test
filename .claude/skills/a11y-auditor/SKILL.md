---
name: a11y-auditor
description: Run axe-core + Pa11y + manual heuristics (focus order, aria, motion-triggers, color-contrast). Emits prioritized fix list. TRIGGER on /audit and after every section composition.
allowed-tools: Read, Write, Bash
---

# Accessibility Auditor

Blocks `/ship`. Not optional.

## Inputs
- Built site at `clients/<slug>/site/.next/` (or preview URL)

## Process
1. `playwright test --project=a11y` runs axe-core on every route × {light, dark, reduced-motion}.
2. `pa11y-ci` over the same routes for second-opinion coverage.
3. Manual heuristics:
   - Focus order matches reading order (Tab through whole site).
   - Skip-link present and visible on focus.
   - Form labels associated; errors announced via `aria-live`.
   - Motion respects `prefers-reduced-motion: reduce`.
   - Video has captions, audio has transcript.
4. Severity-rank: critical / serious / moderate / minor.

## Output
`clients/<slug>/reports/axe.json` and `reports/a11y-summary.md`:
- Each violation: rule id, selector, severity, suggested fix, code patch suggestion.
- Top-of-doc verdict: `PASS` / `BLOCKING_FAIL`.

## Quality bar
- Zero critical or serious violations to pass.
- WCAG 2.2 AA conformance by default; AAA if brief specifies.
