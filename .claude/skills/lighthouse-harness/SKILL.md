---
name: lighthouse-harness
description: Run Lighthouse CI against preview URLs, fail gate if any Core Web Vital or category score < 95. TRIGGER on /audit and on every PR via CI.
allowed-tools: Read, Write, Bash
---

# Lighthouse Harness

## Inputs
- Preview URL or local `pnpm start`

## Config
`clients/<slug>/site/lighthouserc.json`:
```json
{
  "ci": {
    "collect": { "numberOfRuns": 5, "settings": { "preset": "desktop" } },
    "assert": {
      "assertions": {
        "categories:performance": ["error", { "minScore": 0.95 }],
        "categories:accessibility": ["error", { "minScore": 0.95 }],
        "categories:best-practices": ["error", { "minScore": 1.0 }],
        "categories:seo": ["error", { "minScore": 0.95 }],
        "largest-contentful-paint": ["error", { "maxNumericValue": 2000 }],
        "cumulative-layout-shift": ["error", { "maxNumericValue": 0.05 }],
        "interaction-to-next-paint": ["error", { "maxNumericValue": 200 }],
        "total-blocking-time": ["error", { "maxNumericValue": 150 }]
      }
    }
  }
}
```

## Process
1. Run desktop + mobile passes.
2. Capture median of 5 runs.
3. Diff against previous run; flag regressions > 2 pts.
4. Append to `clients/<slug>/reports/lighthouse.json` (timeseries).

## Quality bar
- Hard fails block `/ship`.
- Regressions > 2pts open a P1 task in Linear via n8n.
