---
description: Start a new client engagement. Creates Supabase row, scaffolds clients/<slug>/ workspace, sets active client.
argument-hint: <client-slug> [--from <path-to-brief.md>]
allowed-tools: Read, Write, Bash
---

# /new-brief

Start a new brand-kit engagement.

## Inputs
- `$1`: kebab-case slug (required)
- `--from <path>`: optional source doc to ingest immediately

## Steps
1. Validate slug (lowercase, kebab-case, unique against `clients/` and `clients` table).
2. Create directory tree: `clients/$1/{moodboards,concepts,logo,site,social,reports,research}`.
3. Insert row in Supabase `clients` table via `src/pipeline/runner.ts:createClient`.
4. Initialize `clients/$1/phases.json` with all phases at `pending`.
5. If `--from` provided, invoke `brand-brief-intake` skill on that file.
6. Set `.claude/state.json#activeClient = "$1"` so downstream commands target this client.
7. Print next-step suggestion: `/run-phase strategy`.
