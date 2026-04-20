# Typography Pairing

## Summary
Pick a display + text + mono triad that's (a) legally usable, (b) available as variable fonts, (c) tonally aligned to archetype.

## Triads by archetype
| Archetype | Display | Text | Mono |
|---|---|---|---|
| Sage | Söhne / Inter | Inter | JetBrains Mono |
| Creator | PP Editorial / Migra | ABC Diatype | Commit Mono |
| Ruler | GT Sectra / Signifier | Inter | IBM Plex Mono |
| Outlaw | Neue Machina / Monument | Inter | Berkeley Mono |
| Jester | Migra / Gimlet | Inter | Commit Mono |
| Magician | Tobias / Söhne Schmal | Inter | JetBrains Mono |

## Licensing lanes
1. **OFL / SIL:** Inter, JetBrains Mono, IBM Plex — default safe choice.
2. **Fontshare (free):** Cabinet Grotesk, Satoshi, Clash Display — good for budget_tier=standard.
3. **Paid foundry:** GT, Dinamo, Pangram, Colophon — premium/flagship only. Always confirm license.
4. **Adobe Fonts:** serve only via self-host after confirming license terms.

## Rules
- Triad must cover every weight used (400/500/600/700 minimum).
- Variable axes preferred; `opsz` gives free optical sizing.
- Max 200KB woff2 per axis combination loaded on first paint.
- Display font may load async; text font must be preloaded.
- Never substitute fallback for display — prefer absence over substitution.

## Updated
2026-04-20
