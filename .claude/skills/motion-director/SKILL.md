---
name: motion-director
description: Choose GSAP vs Framer Motion vs Motion One per section. Author timelines with reduced-motion fallbacks. TRIGGER after section-composer drafts a section.
allowed-tools: Read, Write, Edit
---

# Motion Director

Motion that earns its bytes.

## Decision tree
- **Single declarative entry/exit, layout transitions** → Framer Motion
- **Scroll-driven, complex sequencing, SVG morphing** → GSAP + ScrollTrigger
- **Tiny inline gestures** → Motion One (8KB)
- **Complex pre-authored sequence** → Lottie (only if dotLottie ≤ 50KB)
- **Continuous ambient motion** → CSS `@property` + `view-timeline`

## Inputs
- `clients/<slug>/site/components/`
- `clients/<slug>/tokens.json` (motion section)
- `research/motion-libraries.md`

## Output
For each section: `motion.ts` adjacent to `Section.tsx` exporting:
```ts
export const motion = {
  enter: { /* timeline */ },
  exit:  { /* timeline */ },
  reducedMotion: { /* static fallback */ },
};
```

## Rules
1. **Reduced motion is a hard fork** — `useReducedMotion()` returns the `reducedMotion` branch with no `transform`/`opacity` animation > 200ms.
2. **No layout thrash** — animate only `transform` / `opacity` / `filter`.
3. **Budget**: combined motion JS ≤ 60KB gz per route.
4. **Easing tokens** from `tokens.motion` — never inline cubic-bezier strings.
5. **First frame**: hero motion must not delay LCP > 100ms.

## Quality bar
- Lighthouse Performance ≥ 95 on the section's host page.
- `prefers-reduced-motion: reduce` produces a usable, complete experience.
- DevTools "Performance" tab: every animation stays in the compositor (no layout/paint per frame).
