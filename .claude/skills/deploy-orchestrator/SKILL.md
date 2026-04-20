---
name: deploy-orchestrator
description: Coordinate Vercel/Netlify preview, Docker VPS image, Supabase migration, and asset sync in the correct order. TRIGGER on /ship.
allowed-tools: Read, Write, Bash
---

# Deploy Orchestrator

## Inputs
- `clients/<slug>/site/` (must pass `/audit`)
- Environment: `VERCEL_TOKEN`, `DOCKER_REGISTRY_TOKEN`, `SUPABASE_ACCESS_TOKEN`

## Order
1. **Pre-flight**: `/audit` green, tests green, typecheck green.
2. **DB**: `supabase db push` against target project.
3. **Assets**: upload `social/` and `logo/exports/` to Supabase Storage via `src/supabase/storage.js`.
4. **Build**: `pnpm --filter ./clients/<slug>/site build`.
5. **Vercel**: `vercel deploy --prod --token $VERCEL_TOKEN`.
6. **Docker (parallel)**: build image `brand-<slug>:$SHA`, push to registry.
7. **DNS/Alias**: `vercel alias set` to apex domain.
8. **Smoke**: Playwright smoke test against prod URL.
9. **Changelog**: append to `clients/<slug>/CHANGELOG.md`.
10. **Handoff**: zip `handoff/` (logo, guidelines, social) and push to Supabase Storage.

## Rollback
- Any step fails → halt, trigger n8n `rollback-brandkit` workflow, re-alias previous prod.

## Quality bar
- All 10 steps logged to `reports/deploy-<timestamp>.json`.
- Zero-downtime cutover.
- Prod smoke test passes before handoff zip is made public.
