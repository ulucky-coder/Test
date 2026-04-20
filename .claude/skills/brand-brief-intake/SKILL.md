---
name: brand-brief-intake
description: Convert raw client input (form, transcript, doc, voice memo) into a normalized brief.json with audience, tone axes, competitors, constraints, success metrics. TRIGGER on /new-brief, on first uploaded brief artifact, or when user pastes client requirements.
allowed-tools: Read, Write, Grep
---

# Brand Brief Intake

Normalize unstructured client input into a single canonical brief that every downstream skill consumes.

## Output schema

Write to `clients/<slug>/brief.json` matching `templates/brief.template.json`:

```json
{
  "slug": "kebab-case",
  "name": "Display Name",
  "tagline": "one sentence",
  "industry": "fintech|saas|dtc|agency|creator|other",
  "stage": "pre-seed|seed|series-a|growth|enterprise",
  "audience": {
    "primary": "concise persona",
    "secondary": "optional",
    "geography": ["US", "EU"]
  },
  "tone_axes": {
    "serious_playful": 0.3,
    "classic_modern": 0.8,
    "minimal_expressive": 0.4,
    "warm_cool": 0.6,
    "premium_accessible": 0.7
  },
  "competitors": [{ "name": "", "url": "", "what_we_like": "", "what_to_avoid": "" }],
  "constraints": {
    "must_include": [],
    "must_avoid": [],
    "color_locked": null,
    "type_locked": null,
    "trademark_blockers": []
  },
  "deliverables": ["logo", "brand_system", "site", "guidelines", "social"],
  "success_metrics": ["conversion_rate", "time_on_page"],
  "deadline": "ISO date",
  "budget_tier": "standard|premium|flagship"
}
```

## Process

1. Detect input type (markdown doc, JSON, plain text, transcript with timestamps).
2. Extract entities greedily but conservatively — prefer null over guessed.
3. Score `tone_axes` 0–1 from adjective frequency + competitor analysis.
4. For each competitor URL, fetch and extract palette/type via `webgl-hero-builder` is NOT for this — just record observation notes here.
5. Validate against Zod schema in `packages/tokens/src/brief.schema.ts`.
6. Write `brief.json` and create the Supabase row via `src/pipeline/runner.ts:createClient`.

## Quality bar

- Reject if `name`, `audience.primary`, `industry`, or any tone axis missing.
- Surface ambiguities as TODO markers in `brief.json.notes[]` rather than guessing.
- Never overwrite an existing approved brief — bump to `brief.v2.json`.
