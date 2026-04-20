# Legal Pre-flight — Trademarks, Licensing, Provenance

## Name check
1. USPTO TESS search on exact + phonetic matches in the relevant Nice classes.
2. EUIPO eSearch for EU coverage.
3. Domain availability: .com, .app, .io, .ai + country TLDs relevant to audience.geography.
4. Social handles: X/Twitter, LinkedIn, Instagram, GitHub, YouTube.
5. Surface conflicts in `strategy.json#constraints.trademark_blockers`.

## Logo originality
- Reverse-image search on the rendered mark (first 3 concept candidates).
- Brand-New archive scan for prior uses of the same glyph concept.
- Document construction geometry — proves non-derivative nature.

## Typography licensing
- Record license, seat count, web-use flag, self-host rights.
- No fonts pulled from "free fonts" aggregators unless the upstream source is confirmed.
- Google Fonts OFL: safe default.
- Adobe Fonts: webfont-only license, cannot be self-hosted.
- Commercial foundries (GT, Dinamo, Pangram, Colophon): confirm CJK/cyrillic coverage if needed.

## Asset provenance
- Stock imagery: record source and license in `assets.metadata`.
- Generative imagery from diffusion models: disallow in final deliverables (provenance risk). Use only for mood/ideation with license flagged.
- Logo must be Claude-authored SVG — provenance clean by design.

## Client handoff
- Handoff zip includes `LICENSES.md` listing every font, icon, asset with license terms.
- Record all license keys in Supabase `clients.metadata.licenses[]`.

## Updated
2026-04-20
