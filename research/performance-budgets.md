# Performance Budgets

## Targets (enforced by lighthouse-harness)
| Metric | Desktop | Mobile (Moto G4 / 4× CPU throttle) |
|---|---|---|
| Performance score | ≥ 95 | ≥ 90 |
| LCP | ≤ 1.8s | ≤ 2.5s |
| INP | ≤ 150ms | ≤ 200ms |
| CLS | ≤ 0.05 | ≤ 0.05 |
| TBT | ≤ 100ms | ≤ 200ms |
| Route JS bundle (gz) | ≤ 120KB | ≤ 120KB |
| Hero-route JS bundle (gz) | ≤ 170KB | ≤ 170KB |
| Fonts (gz) | ≤ 80KB across triad | ≤ 80KB |
| Hero images (above fold) | ≤ 100KB | ≤ 100KB |

## WebGL hero additional budgets
- First frame ≤ 100ms after LCP
- Sustained 50fps on mid-tier mobile
- GPU memory ≤ 50MB on mobile
- Shader compile ≤ 200ms warm-up

## Guardrails
- Ship all hero assets as AVIF primary, WebP fallback.
- Preload the display font file used above the fold; text font lazy.
- No blocking third-party JS above the fold. Analytics loads after interactive.
- `next/image` mandatory; no raw `<img>` above the fold.

## Updated
2026-04-20
