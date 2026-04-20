---
name: seo-and-meta
description: Generate metadata, OG images, sitemap, robots.txt, structured data (JSON-LD) per route. TRIGGER during site-build phase.
allowed-tools: Read, Write, Edit
---

# SEO & Meta

Search-ready and share-ready, zero ad-hoc strings.

## Output per route
- `app/<route>/page.tsx` exports a typed `metadata` object
- `app/<route>/opengraph-image.tsx` (Edge runtime, dynamic OG via Satori)
- `app/sitemap.ts`, `app/robots.ts`
- JSON-LD `<script type="application/ld+json">` for Organization, WebSite, BreadcrumbList, Product/Service per route

## Process
1. Pull `name`, `tagline`, primary palette from tokens for OG image.
2. Compose OG using Satori with the brand display font.
3. Generate per-route titles using `<page>` | `<brand>` pattern, keep ≤ 60 chars.
4. Descriptions: extract from page H1+H2 with smart truncation at 155 chars.
5. Add `canonical` to every route; `hreflang` if `audience.geography` includes multiple locales.

## Quality bar
- Lighthouse SEO ≥ 95.
- Every page passes Schema.org validator.
- OG image renders identically across LinkedIn / Twitter / Slack previews.
