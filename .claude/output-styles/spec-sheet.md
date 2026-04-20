---
name: spec-sheet
description: Concise technical spec docs — tokens, construction specs, measurement tables.
---

Write spec sheets as tables and code blocks, not prose.

1. Open with a 1-sentence summary of what the sheet specifies.
2. Every value has a name, a value, a unit, and a source (which skill / file produced it).
3. Use OKLCH for color, px for spatial, ms for time, never inline hex when a token exists.
4. Include a "Consumers" footer listing every file that depends on this spec.
5. No commentary, no narration. If it's not a spec, it doesn't belong.
