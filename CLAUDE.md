# CLAUDE.md - AI Assistant Guidelines

> This file provides context and guidelines for AI assistants working with this repository.

## Repository Overview

**Project Name:** Atelier (repo: Test)
**Status:** Active — brand-kit factory foundation laid
**Last Updated:** 2026-04-20

Atelier is a Claude Code-native brand-kit factory: from client brief to Awwwards-caliber deliverable (logo, multi-page Next.js site, brand guidelines, social assets), with an approval-gated pipeline driven by Supabase + n8n.

**Purpose:** Agency with AI enhancement — turn briefs into full brand kits in days, not months.
**Audience:** Small business and startups, corporations/brands, freelancers and personal brands.
**Key features:**
- Claude generates logos as hand-authored SVG under mathematical constraints (no image model).
- Gated pipeline: Intake → Strategy → Research → Concepts → Logo System → Brand System → Site Design → Site Build → QA → Guidelines → Deploy → Handoff.
- Hard quality gates: Lighthouse ≥ 95, axe clean, visual regression zero diffs, design review ≥ 8/10.
- Client portal for review and approval via Supabase auth + realtime.

## Project Structure

```
/home/user/Test/
├── .claude/                 # Claude Code config: skills, agents, commands, hooks
│   ├── settings.json
│   ├── skills/              # 18 custom skills (brand-brief-intake ... deploy-orchestrator)
│   ├── agents/              # 7 subagents (brand-strategist, art-director, ...)
│   ├── commands/            # 10 slash commands (/new-brief, /run-phase, /ship, ...)
│   ├── hooks/               # SessionStart, PreToolUse, PostToolUse, Stop
│   ├── output-styles/
│   ├── templates/           # brief.json, tokens.json, guidelines.mdx templates
│   └── state.json           # {activeClient}
├── .mcp.json.example        # MCP servers template (actual .mcp.json is gitignored)
├── .github/workflows/       # CI (ci, lhci, visual-regression, deploy)
├── apps/
│   ├── web/                 # Next.js 15 + Tailwind v4 + shadcn template (cloned per client)
│   └── portal/              # Client review portal (Next.js + Supabase auth + realtime)
├── packages/
│   ├── tokens/              # Token schema + codegen (JSON → CSS vars + TS + Tailwind)
│   ├── svg-kit/             # SVG primitives, golden grid, optical corrections, linter
│   ├── motion-kit/          # GSAP/Framer presets, reduced-motion helpers
│   └── ui-kit/              # shadcn registry mirror
├── clients/<slug>/          # Per-client workspaces (brief, moodboards, concepts, site, reports)
├── research/                # Live research corpus consumed by skills
├── sql/brandkit_schema.sql  # Clients, briefs, phases, moodboards, concepts, tokens, assets, reviews
├── src/
│   ├── supabase/            # Existing Supabase modules (auth, data, storage, realtime) — reused as-is
│   ├── n8n/                 # Existing n8n client
│   └── pipeline/            # Orchestration (phases, gates, runner)
├── workflows/n8n/           # Workflows incl. 10_brandkit_gate, 11_client_notify, 12_asset_sync
├── scripts/                 # CLI: new-client, run-phase, export-assets
├── package.json             # Root (pnpm workspace, Turbo)
├── pnpm-workspace.yaml
└── turbo.json
```

### Directory Conventions

| Directory | Purpose |
|-----------|---------|
| `.claude/skills/` | Custom skills consumed per-phase (SKILL.md per directory) |
| `.claude/agents/` | Subagent definitions with tool allow-lists |
| `apps/web/` | Canonical Next.js template cloned to `clients/<slug>/site/` |
| `apps/portal/` | Client-facing review dashboard |
| `packages/tokens/` | Design token schema + codegen |
| `packages/svg-kit/` | SVG constraints and linter shared by logo skills |
| `packages/motion-kit/` | Motion presets (easing, durations, reduced-motion branch) |
| `packages/ui-kit/` | shadcn registry shared across client sites |
| `clients/<slug>/` | One tree per engagement; phases.json mirrors Supabase phases |
| `research/` | Living knowledge base consumed by skills; topics in research/README.md |
| `src/pipeline/` | Phase runner, gate enforcement, state mirroring to Supabase |
| `src/supabase/` | Existing Supabase client and operation modules (reused, unchanged) |
| `tests/` | Test files (to be added) |
| `docs/` | Documentation |
| `scripts/` | Utility scripts |

## Technology Stack

- **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Frontend:** Next.js 15 + Tailwind CSS v4 + shadcn/ui + Radix
- **Motion:** GSAP 3 + Framer Motion 11 + Motion One + optional R3F
- **MCP Integration:** n8n-mcp, Supabase MCP, Playwright MCP, Context7, Chrome DevTools, Filesystem, Vercel, Exa
- **Automation:** n8n workflow automation (https://ulucky.app.n8n.cloud)
- **Language:** TypeScript 5.6 (TSX) + JavaScript for existing modules
- **Package Manager:** pnpm 9 (workspaces) + Turborepo
- **QA:** Lighthouse CI, axe-core, Pa11y, Playwright (visual regression)
- **Deploy:** Vercel (default), Docker VPS (optional), Supabase Edge/Storage

## Development Workflow

### Getting Started

```bash
# Clone the repository
git clone https://github.com/ulucky-coder/Test.git
cd Test

# Install dependencies
npm install

# Set environment variables
export SUPABASE_URL="your-supabase-url"
export SUPABASE_ANON_KEY="your-anon-key"
export SUPABASE_SERVICE_KEY="your-service-key"  # Optional, for admin operations
```

### Common Commands

| Command | Description |
|---------|-------------|
| `pnpm install` | Install monorepo deps |
| `pnpm dev:web` | Start Next.js template dev server |
| `pnpm dev:portal` | Start client portal dev server |
| `pnpm typecheck` | Typecheck all packages |
| `pnpm lint` | Lint all packages |
| `pnpm build` | Turbo build across workspace |
| `pnpm new-client <slug>` | Bootstrap a client workspace (CLI mirror of /new-brief) |
| `pnpm run-phase <phase>` | Advance active client's pipeline |
| `pnpm export-assets` | Write social asset manifest for active client |
| `pnpm workflows` | List n8n workflows |

### Slash commands (inside Claude Code)

| Command | Purpose |
|---------|---------|
| `/new-brief <slug>` | Start a new engagement |
| `/run-phase <phase>` | Execute one pipeline phase |
| `/concept` | Generate 3 logo concepts |
| `/logo [--variants]` | Iterate logo or forge the full variant kit |
| `/site [--add-section X]` | Scaffold/advance Next.js site |
| `/audit` | Run a11y + Lighthouse + visual regression |
| `/approve <phase>` | Advance pipeline (records reviewer) |
| `/revise <phase> "feedback"` | Reject and re-run with constraints |
| `/ship` | Deploy to Vercel + Docker + Supabase; zip handoff |
| `/retrospective` | Close loop: update skills from engagement signal |

### Usage Example

```javascript
const { read, insert, auth, storage } = require('./src/supabase');

// Read data
const users = await read('users', { limit: 10 });

// Insert data
await insert('users', { name: 'John', email: 'john@example.com' });

// Authentication
await auth.signIn('user@example.com', 'password');

// Storage
await storage.upload('avatars', 'user1.png', fileBuffer);
```

### Git Workflow

1. **Branch Naming:**
   - Feature branches: `feature/<description>`
   - Bug fixes: `fix/<description>`
   - AI-assisted branches: `claude/<description>`

2. **Commit Messages:** Use clear, descriptive messages
   - Format: `<type>: <description>`
   - Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

3. **Pull Requests:**
   - Provide clear description of changes
   - Reference related issues
   - Ensure tests pass before merging

## Code Conventions

> Establish and document coding standards here as the project develops.

### General Guidelines

- Write clean, readable, self-documenting code
- Follow language-specific best practices
- Keep functions/methods focused and small
- Add comments only when logic is not self-evident
- Avoid over-engineering - implement only what's needed

### File Naming

- Use consistent naming conventions (to be established)
- Keep file names descriptive and concise

### Documentation

- Maintain up-to-date README.md
- Document public APIs
- Include usage examples where helpful

## Testing Guidelines

> Update when testing framework is established.

- Write tests for new features
- Ensure existing tests pass before committing
- Aim for meaningful test coverage
- Test edge cases and error conditions

## AI Assistant Instructions

### When Working on This Repository

1. **Always read before modifying:** Understand existing code before making changes
2. **Maintain consistency:** Follow established patterns and conventions
3. **Keep changes focused:** Make only the requested changes, avoid over-engineering
4. **Test your changes:** Run existing tests and add new ones as appropriate
5. **Document significant changes:** Update relevant documentation

### Things to Avoid

- Don't introduce security vulnerabilities (XSS, SQL injection, etc.)
- Don't add unnecessary dependencies
- Don't make breaking changes without explicit approval
- Don't commit sensitive data (API keys, passwords, etc.)
- Don't ignore existing code patterns without good reason

### Helpful Context

- This repository uses Git for version control
- The main development branch is tracked via Git
- Check `.gitignore` for files that should not be committed

## Environment Setup

> Document environment requirements and setup steps here.

### Prerequisites

- Git installed
- (Add language runtime requirements)
- (Add other dependencies)

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `SUPABASE_URL` | Supabase project URL | Yes |
| `SUPABASE_ANON_KEY` | Supabase anonymous/public key | Yes |
| `SUPABASE_SERVICE_KEY` | Supabase service role key (admin) | No |
| `N8N_API_KEY` | API key for n8n cloud instance | Yes |

**Note:** Never commit API keys to the repository. Set environment variables locally or use a secrets manager.

### MCP Configuration

The project uses Model Context Protocol (MCP) for AI tool integration. Configuration is in `.mcp.json`:

```bash
# Quick setup with Claude CLI
claude mcp add n8n-mcp

# Set your API key as environment variable
export N8N_API_KEY="your-api-key-here"
```

The n8n-mcp server provides workflow automation capabilities through the n8n platform.

## Troubleshooting

> Document common issues and solutions here.

### Common Issues

1. **Issue:** TBD
   - **Solution:** TBD

## Resources

- Repository: [ulucky-coder/Test](https://github.com/ulucky-coder/Test)
- n8n Cloud Instance: https://ulucky.app.n8n.cloud
- n8n Documentation: https://docs.n8n.io
- n8n-mcp: MCP server for n8n integration
- Supabase Documentation: https://supabase.com/docs
- Supabase JS Client: https://supabase.com/docs/reference/javascript

---

*This CLAUDE.md file should be updated as the project evolves to reflect current structure, conventions, and workflows.*
