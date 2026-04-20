export const PHASE_ORDER = [
  "intake",
  "strategy",
  "research",
  "concepts",
  "logo_system",
  "brand_system",
  "site_design",
  "site_build",
  "qa",
  "guidelines",
  "deploy",
  "handoff",
] as const;

export type PhaseKind = (typeof PHASE_ORDER)[number];

export type PhaseStatus =
  | "pending"
  | "in_progress"
  | "ready_for_review"
  | "approved"
  | "revise"
  | "blocked";

export interface Phase {
  kind: PhaseKind;
  status: PhaseStatus;
  iteration: number;
  reviewer?: string | null;
  approved_at?: string | null;
  started_at?: string | null;
  context?: Record<string, unknown>;
}

export const PHASE_OWNERS: Record<PhaseKind, string> = {
  intake: "brand-strategist",
  strategy: "brand-strategist",
  research: "art-director",
  concepts: "art-director",
  logo_system: "logo-designer",
  brand_system: "art-director",
  site_design: "frontend-engineer",
  site_build: "frontend-engineer",
  qa: "accessibility-auditor",
  guidelines: "art-director",
  deploy: "release-manager",
  handoff: "release-manager",
};

export const PHASE_SKILLS: Record<PhaseKind, string[]> = {
  intake: ["brand-brief-intake"],
  strategy: ["brand-archetype-mapper"],
  research: ["visual-research-scout"],
  concepts: ["moodboard-builder", "logo-svg-generator"],
  logo_system: ["logo-variant-forger"],
  brand_system: ["color-system-architect", "typography-pairing"],
  site_design: ["site-scaffold", "section-composer"],
  site_build: [
    "section-composer",
    "motion-director",
    "webgl-hero-builder",
    "copy-polisher",
    "seo-and-meta",
  ],
  qa: ["a11y-auditor", "lighthouse-harness", "visual-regression"],
  guidelines: ["brand-guidelines-writer", "social-asset-export"],
  deploy: ["deploy-orchestrator"],
  handoff: [],
};

export function priorPhase(kind: PhaseKind): PhaseKind | null {
  const idx = PHASE_ORDER.indexOf(kind);
  return idx > 0 ? PHASE_ORDER[idx - 1] : null;
}

export function nextPhase(kind: PhaseKind): PhaseKind | null {
  const idx = PHASE_ORDER.indexOf(kind);
  return idx >= 0 && idx < PHASE_ORDER.length - 1 ? PHASE_ORDER[idx + 1] : null;
}
