---
name: section-composer
description: Draft React/TSX for hero, features, social proof, pricing, CTA, footer using shadcn primitives and the approved design system. TRIGGER after site-scaffold or for adding new sections.
allowed-tools: Read, Write, Edit, Bash
---

# Section Composer

Section-level page modules with strong opinions, derived from teardown patterns.

## Inputs
- `clients/<slug>/site/`
- `clients/<slug>/strategy.json` (voice + visual implications)
- `research/awwwards-teardowns/` (pattern catalog)
- `research/conversion-patterns.md` (above-fold rules)

## Available section archetypes
| Slug | Use | Key pattern |
|---|---|---|
| `hero-pinned-text` | wordmark-led brands | scroll-pinned title with letter-by-letter reveal |
| `hero-product-shot` | SaaS | parallax product surface with scroll-driven sequence |
| `hero-shader` | creative tools, agencies | full-screen WebGL with content overlay |
| `hero-editorial` | content brands | huge title + small intro + cover image |
| `features-bento` | feature-rich SaaS | asymmetric 6-cell grid |
| `features-tabbed` | platform stories | sticky-tab horizontal scroller |
| `social-proof-marquee` | logo wall | infinite marquee with hover pause |
| `pricing-comparison` | SaaS | side-by-side with feature toggle |
| `cta-conversation` | premium services | text input that submits to qualifier |
| `footer-sitemap` | content-heavy | columnar with newsletter signup |

## Process
1. Read voice + tone_axes; pick section archetypes that match.
2. Compose each section from shadcn primitives in `apps/web/components/ui/`.
3. Apply tokens — never hardcoded values.
4. Wire motion via `motion-director` for entry animations.
5. Add Playwright `data-testid` markers for visual-regression.

## Quality bar
- Each section is responsive across 320, 768, 1024, 1440, 1920.
- Server components by default; client only where interactivity demands.
- All copy comes from `content.json`, not inline strings.
