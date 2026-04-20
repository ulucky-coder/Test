---
description: Run full QA pass — accessibility, Lighthouse, visual regression, design review.
allowed-tools: Read, Write, Bash
---

# /audit

QA gate. Blocks `/ship` if any check fails.

## Steps
1. Build site: `pnpm --filter ./clients/<active>/site build`.
2. Start preview: `pnpm --filter ./clients/<active>/site start &`.
3. `a11y-auditor` skill against preview URL × {light, dark, reduced-motion}.
4. `lighthouse-harness` skill, 5 runs, median scores.
5. `visual-regression` skill, all breakpoints × themes.
6. `design-review` skill against the rubric.
7. Compose `clients/<active>/reports/audit-summary.md` with PASS/FAIL verdict and blocker list.
8. Stop preview server.

## Verdict logic
- Lighthouse < 95 anywhere → FAIL
- Critical/serious axe violations → FAIL
- Visual diff > 100px on any page → FAIL
- Design review < 8/10 average → FAIL
- All green → PASS, unblocks `/ship`
