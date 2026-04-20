---
description: Scaffold or advance the Next.js site for the active client.
argument-hint: [--scaffold] [--add-section <archetype>] [--polish-copy]
allowed-tools: Read, Write, Edit, Bash, Glob
---

# /site

Compose the marketing site.

## Modes

### `--scaffold`
Run `site-scaffold` skill: clone `apps/web`, inject tokens from `clients/<active>/tokens.json`, copy logo to public/, install deps, build once.

### `--add-section <archetype>`
Run `section-composer` to add a section from the catalog (hero-pinned-text, features-bento, etc.) to the active page. Then `motion-director` for entry animation.

### `--polish-copy`
Run `copy-polisher` over `content.json`. Reports rejected phrases and rewrites.

### default (no flag)
Run full site-build phase: scaffold (if missing) → compose home/features/pricing/about/contact → motion → seo → copy polish.
