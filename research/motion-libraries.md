# Motion Libraries — Decision Reference

## GSAP 3
Best for: scroll-driven sequencing, SVG morphing, timeline orchestration, complex layouts.
Bundle: 45KB core; ScrollTrigger +15KB; SplitText/Flip are Business Green plugins.
Licensing: MIT for basic; Business Green ($99/yr dev) required for some plugins.
Use when: hero has scroll story, text reveal, or chained reveals.

## Framer Motion 11
Best for: declarative React transitions, layout animations (`layout` prop), shared element transitions.
Bundle: 35–50KB gz (tree-shakable).
Licensing: MIT.
Use when: single-page React app, card reveals, modal transitions, route-level.

## Motion One
Best for: micro-interactions where size matters. CSS-adjacent API.
Bundle: 8KB.
Licensing: MIT.
Use when: hover/press gestures, tiny inline motion.

## Lottie (dotLottie)
Best for: pre-authored, hand-crafted sequences.
Bundle: `@lottiefiles/dotlottie-web` 30KB + lottie payload.
Licensing: MIT.
Use when: AE-authored sequence can't be reasonably coded; payload ≤ 50KB.

## anime.js v4
Best for: tweening non-React canvas/DOM; smaller than GSAP.
Bundle: 17KB.
Licensing: MIT.
Use when: no timeline complexity; no React tree concerns.

## CSS `@property` + `view-timeline`
Best for: scroll-driven ambient effects with zero JS.
Bundle: 0.
Caveat: Safari/Firefox parity in 2026 — safe for progressive enhancement only.

## Default tree (in order of preference)
1. CSS tokens + `@property` for ambient.
2. Motion One for inline gestures.
3. Framer Motion for React section transitions.
4. GSAP for scroll sequences only when CSS/FM can't do it.
5. Lottie only when hand-authored AE sequence is required.

## Updated
2026-04-20
