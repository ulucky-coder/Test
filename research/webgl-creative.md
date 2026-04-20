# WebGL Creative Coding Reference

## Libraries
- **R3F + drei**: richest API, React tree integration. 80–120KB gz with drei helpers.
- **OGL**: 30KB thin alternative. No ecosystem, build everything yourself.
- **Theatre.js**: authoring for scenes; optional runtime.

## Technique catalog
- **Ambient shader plane**: fullscreen quad with glsl-noise → worley noise → step. Near-zero geometry load.
- **Low-poly displaced mesh**: IcoSphere with vertex shader noise displacement. Readable silhouette.
- **Particle system**: instanced points, sampled from GPGPU texture. Cap at 100k.
- **Post-processing**: prefer one pass (vignette + chromatic) over stacks.
- **SDF rendering**: raymarching fullscreen; limit to 2 primitives.

## Quality tiers
```
if (deviceMemory >= 8 && connection.effectiveType === '4g') → HIGH
else if (deviceMemory >= 4) → MEDIUM (halve resolution, disable post)
else → LOW (static poster image, no WebGL)
```

## SSR strategy
1. Serve a `<picture>` poster sized identically to the canvas.
2. Lazy-load scene only on `IntersectionObserver` enter.
3. Never mount R3F above the fold without the poster swap.

## Rules
- Shader files in `shaders/` with `.glsl` extension; parsed via `vite-plugin-glsl`.
- Profile on real mid-tier mobile before ship — never trust dev-machine fps.
- `prefers-reduced-motion: reduce` → freeze on poster frame; no exceptions.

## Updated
2026-04-20
