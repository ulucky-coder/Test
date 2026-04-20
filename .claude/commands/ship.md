---
description: Deploy the brand kit. Vercel prod + Docker image + Supabase migration + handoff zip.
argument-hint: [--target vercel|docker|both=both]
allowed-tools: Read, Write, Bash
---

# /ship

Production cut-over.

## Pre-flight (all required)
- `/audit` returned PASS in the last 24h
- All phases ≤ guidelines `approved`
- `release-manager` is the invoking agent

## Steps
1. Hand off to `release-manager` agent.
2. Run `deploy-orchestrator` skill (10-step pipeline).
3. Smoke test prod URL.
4. Tag `brand-<active>-v<semver>`.
5. Build handoff zip (logo/, guidelines.pdf, social/, tokens.json, README.md).
6. Upload to Supabase Storage `handoff/<active>-v<semver>.zip`; create signed URL.
7. Notify client via n8n `11_client_notify` with the signed URL.
8. Print release URL + handoff URL.
