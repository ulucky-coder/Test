---
name: design-review
description: Critique output through Awwwards SOTY rubric and return structured rubric score + blocker list. TRIGGER between phases as a quality gate.
allowed-tools: Read, Write
---

# Design Review

## Rubric (each 0-10)

1. **Concept** — does it have a clear idea, or is it decoration?
2. **Craft** — pixel-level execution, optical balance, typographic hygiene
3. **Originality** — does it look like the rest of the year's output?
4. **Coherence** — single brand voice end-to-end
5. **Performance** — Lighthouse + INP + LCP
6. **Accessibility** — axe + manual heuristics
7. **Motion** — purposeful, on-budget, reduced-motion respected
8. **Content** — copy earns its space, no fluff
9. **Conversion** — clear primary CTA, no friction above the fold
10. **Detail** — favicon, 404, error states, empty states, micro-interactions

## Output
`clients/<slug>/reports/design-review-<phase>.md`:
- Scores table
- Blockers (must-fix)
- Improvements (should-fix)
- Praise (what to preserve)
- Reference comparisons (3 SOTY links)

## Quality bar
- Below 7 in any rubric row = blocker.
- Below 8 average = phase cannot be `/approve`d.
- Reviewer cites at least 2 references for each blocker.
