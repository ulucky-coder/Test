---
description: Mark a phase as approved, unlock the next phase, record reviewer + timestamp.
argument-hint: <phase> [--reviewer <name>]
allowed-tools: Read, Write, Bash
---

# /approve

Advance the pipeline.

## Steps
1. Read `clients/<active>/phases.json` — verify phase is `ready-for-review`.
2. Update phase to `approved`, record `reviewer`, `approved_at`.
3. Mirror to Supabase `phases` table.
4. Trigger n8n `10_brandkit_gate` to notify the next agent owner.
5. Print: "Phase X approved. Next: /run-phase Y".
