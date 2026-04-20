---
description: Generate or iterate logo concepts for the active client.
argument-hint: [--iterate <concept-id>] [--n <count=3>]
allowed-tools: Read, Write, Edit, Bash
---

# /concept

Generate three logo concepts (default) or iterate an approved one.

## Pre-checks
- Active client set
- Moodboard approved
- Strategy approved

## Steps
1. Hand off to `logo-designer` agent.
2. Run `logo-svg-generator` with construction strategies: monogram / abstract symbol / wordmark.
3. Render preview PNGs at 64/256/1024.
4. Compose comparison sheet `clients/<active>/concepts/comparison.md`.
5. Run `design-review` on the set; below 8/10 = abort and log blockers.
