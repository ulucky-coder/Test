---
name: webgl-hero-builder
description: Scaffold Three.js / React Three Fiber or OGL hero scenes with strict performance budgets (bundle, fps, GPU memory). TRIGGER only when strategy specifies WebGL hero or for flagship tier.
allowed-tools: Read, Write, Edit, Bash
---

# WebGL Hero Builder

Optional, opinionated, budget-enforced.

## When to use
- `strategy.json` lists "shader" / "WebGL" in `visual_implications`, OR
- `brief.json.budget_tier === "flagship"` AND archetype ∈ {Magician, Creator, Explorer}

## Output
- `clients/<slug>/site/components/brand/Hero.tsx` (R3F or OGL)
- `clients/<slug>/site/shaders/*.glsl`
- `clients/<slug>/site/lib/scene/` (geometry, materials)

## Hard budgets
| Metric | Limit |
|---|---|
| JS bundle (hero route) | ≤ 170KB gz |
| First frame after LCP | ≤ 100ms |
| Sustained FPS (mid-tier mobile, throttled 4×) | ≥ 50 |
| GPU memory (mobile) | ≤ 50MB |
| Shader compile time | ≤ 200ms (warm-up only) |

## Process
1. Pick library: OGL for thin (≤30KB), R3F+drei for richer scenes.
2. Compose scene in modules: geometry → material → lighting → post.
3. Implement quality tiers (low/medium/high) keyed off `navigator.deviceMemory` and matchMedia.
4. Lazy-load behind `IntersectionObserver`; serve poster `<canvas>` snapshot for SSR.
5. Wire `prefers-reduced-motion` to a static gradient fallback.

## Quality bar
- Cumulative Layout Shift = 0 (poster has same dims as canvas).
- INP ≤ 200ms even mid-animation.
- Bundle analyzer screenshot in `clients/<slug>/reports/bundle.png`.
