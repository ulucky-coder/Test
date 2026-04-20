---
name: site-scaffold
description: Bootstrap a Next.js 15 app router project with Tailwind v4, shadcn/ui registry, and the approved token set wired into CSS variables. TRIGGER on /site for a new client.
allowed-tools: Read, Write, Edit, Bash
---

# Site Scaffold

Clones the canonical `apps/web` template into `clients/<slug>/site/` and injects the brand tokens.

## Inputs
- `clients/<slug>/tokens.json`
- `clients/<slug>/logo/`
- `apps/web/` (template source)

## Output
`clients/<slug>/site/` containing:
- `app/` (App Router with `(marketing)` group: home, features, pricing, blog, contact)
- `components/ui/` (shadcn primitives)
- `components/brand/` (client-specific compositions)
- `lib/tokens.ts` (typed token export)
- `styles/globals.css` (Tailwind v4 `@theme` block populated from tokens)
- `public/` (logo variants, favicons)
- `next.config.mjs`, `tsconfig.json`, `package.json`, `biome.json`
- `playwright.config.ts`, `lighthouserc.json`

## Process
1. `cp -R apps/web clients/<slug>/site`.
2. Run `packages/tokens` codegen with `--client=<slug>` to write `globals.css` and `lib/tokens.ts`.
3. Copy logo variants to `public/`.
4. Update `package.json` name + metadata.
5. Run `pnpm install` from monorepo root, then `pnpm --filter ./clients/<slug>/site build` to verify.
6. Spin up dev server briefly to confirm compile.

## Quality bar
- Site builds without warnings.
- Lighthouse on the empty home page ≥ 95 across all categories.
- Tokens fully wired — no hardcoded colors/sizes anywhere outside tokens layer.
