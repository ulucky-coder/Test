---
description: Execute one pipeline phase for the active client. Enforces prerequisites.
argument-hint: <phase> (intake|strategy|research|concepts|logo-system|brand-system|site-design|site-build|qa|guidelines|deploy|handoff)
allowed-tools: Read, Write, Edit, Bash, Grep
---

# /run-phase

Run a specific phase against the active client.

## Pre-checks
1. Read `.claude/state.json#activeClient` — error if unset.
2. Read `clients/<active>/phases.json` — verify previous phase = `approved`.
3. If gate violated, print blocker and stop.

## Phase routing
| Phase | Subagent | Skills |
|---|---|---|
| intake | brand-strategist | brand-brief-intake |
| strategy | brand-strategist | brand-archetype-mapper |
| research | art-director | visual-research-scout |
| concepts | art-director → logo-designer | moodboard-builder, logo-svg-generator |
| logo-system | logo-designer | logo-variant-forger |
| brand-system | art-director | color-system-architect, typography-pairing |
| site-design | frontend-engineer | site-scaffold, section-composer |
| site-build | frontend-engineer + motion-engineer | section-composer, motion-director, webgl-hero-builder, copy-polisher, seo-and-meta |
| qa | accessibility-auditor | a11y-auditor, lighthouse-harness, visual-regression |
| guidelines | art-director | brand-guidelines-writer, social-asset-export |
| deploy | release-manager | deploy-orchestrator |
| handoff | release-manager | (zip + Supabase Storage upload) |

## Post
1. Update `clients/<active>/phases.json#<phase> = "ready-for-review"`.
2. Trigger n8n `10_brandkit_gate` to notify reviewer.
