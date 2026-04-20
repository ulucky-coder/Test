import fs from "node:fs";
import path from "node:path";
import {
  PHASE_ORDER,
  PHASE_OWNERS,
  PHASE_SKILLS,
  type Phase,
  type PhaseKind,
} from "./phases.js";
import { canStart, canApprove, canShip, type GateResult } from "./gates.js";
import { supabase, supabaseAdmin } from "../supabase/client.js";

const ROOT = process.cwd();
const CLIENTS_DIR = path.join(ROOT, "clients");
const STATE_FILE = path.join(ROOT, ".claude", "state.json");

export interface CreateClientInput {
  slug: string;
  name: string;
  industry?: string;
  stage?: string;
  budgetTier?: "standard" | "premium" | "flagship";
  ownerUserId?: string;
}

export interface ClientRow {
  id: string;
  slug: string;
  name: string;
  industry: string | null;
  budget_tier: string;
  created_at: string;
}

function readJson<T>(p: string, fallback: T): T {
  try {
    return JSON.parse(fs.readFileSync(p, "utf8")) as T;
  } catch {
    return fallback;
  }
}

function writeJson(p: string, data: unknown): void {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify(data, null, 2) + "\n");
}

export function setActiveClient(slug: string): void {
  const state = readJson<Record<string, unknown>>(STATE_FILE, {});
  state.activeClient = slug;
  writeJson(STATE_FILE, state);
}

export function getActiveClient(): string | null {
  const state = readJson<{ activeClient?: string | null }>(STATE_FILE, {});
  return state.activeClient ?? null;
}

export function readPhases(slug: string): Record<PhaseKind, Phase> {
  const file = path.join(CLIENTS_DIR, slug, "phases.json");
  const empty = Object.fromEntries(
    PHASE_ORDER.map((k) => [
      k,
      { kind: k, status: "pending", iteration: 0 } as Phase,
    ]),
  ) as Record<PhaseKind, Phase>;
  return { ...empty, ...readJson<Record<PhaseKind, Phase>>(file, empty) };
}

export function writePhases(
  slug: string,
  phases: Record<PhaseKind, Phase>,
): void {
  writeJson(path.join(CLIENTS_DIR, slug, "phases.json"), phases);
}

export async function createClient(
  input: CreateClientInput,
): Promise<ClientRow> {
  const slug = input.slug.toLowerCase();
  if (!/^[a-z][a-z0-9-]*$/.test(slug)) {
    throw new Error(
      `invalid slug "${slug}" (kebab-case, lowercase, start with letter)`,
    );
  }

  const dir = path.join(CLIENTS_DIR, slug);
  if (fs.existsSync(dir))
    throw new Error(`client workspace already exists at ${dir}`);

  for (const sub of [
    "moodboards",
    "concepts",
    "logo",
    "site",
    "social",
    "reports",
    "research",
    "reviews",
  ]) {
    fs.mkdirSync(path.join(dir, sub), { recursive: true });
  }

  const phases = Object.fromEntries(
    PHASE_ORDER.map((k) => [k, { kind: k, status: "pending", iteration: 0 }]),
  ) as Record<PhaseKind, Phase>;
  writePhases(slug, phases);

  const db = supabaseAdmin ?? supabase;
  const { data, error } = await db
    .from("clients")
    .insert({
      slug,
      name: input.name,
      industry: input.industry ?? null,
      stage: input.stage ?? null,
      budget_tier: input.budgetTier ?? "standard",
      owner_user_id: input.ownerUserId ?? null,
    })
    .select()
    .single();

  if (error) throw new Error(`supabase insert failed: ${error.message}`);
  const row = data as ClientRow;

  const { error: bootErr } = await db.rpc("bootstrap_phases", {
    p_client_id: row.id,
  });
  if (bootErr) throw new Error(`bootstrap_phases failed: ${bootErr.message}`);

  setActiveClient(slug);
  return row;
}

export interface RunPhaseResult {
  phase: PhaseKind;
  status: Phase["status"];
  owner: string;
  skills: string[];
  gate: GateResult;
}

export async function runPhase(
  slug: string,
  kind: PhaseKind,
): Promise<RunPhaseResult> {
  const phases = readPhases(slug);
  const gate = canStart(kind, phases);
  if (!gate.ok) {
    return {
      phase: kind,
      status: phases[kind].status,
      owner: PHASE_OWNERS[kind],
      skills: PHASE_SKILLS[kind],
      gate,
    };
  }

  phases[kind] = {
    ...phases[kind],
    status: "in_progress",
    started_at: new Date().toISOString(),
    iteration: (phases[kind].iteration ?? 0) + 1,
  };
  writePhases(slug, phases);

  const db = supabaseAdmin ?? supabase;
  await db
    .from("phases")
    .update({ status: "in_progress", started_at: new Date().toISOString() })
    .match({ kind });

  return {
    phase: kind,
    status: "in_progress",
    owner: PHASE_OWNERS[kind],
    skills: PHASE_SKILLS[kind],
    gate: { ok: true, blockers: [] },
  };
}

export async function markReadyForReview(
  slug: string,
  kind: PhaseKind,
): Promise<void> {
  const phases = readPhases(slug);
  phases[kind] = { ...phases[kind], status: "ready_for_review" };
  writePhases(slug, phases);

  const db = supabaseAdmin ?? supabase;
  await db
    .from("phases")
    .update({ status: "ready_for_review" })
    .match({ kind });
}

export async function approvePhase(
  slug: string,
  kind: PhaseKind,
  reviewer: string,
): Promise<GateResult> {
  const phases = readPhases(slug);
  const gate = canApprove(kind, phases);
  if (!gate.ok) return gate;

  const approvedAt = new Date().toISOString();
  phases[kind] = {
    ...phases[kind],
    status: "approved",
    reviewer,
    approved_at: approvedAt,
  };
  writePhases(slug, phases);

  const db = supabaseAdmin ?? supabase;
  const { data: client } = await db
    .from("clients")
    .select("id")
    .eq("slug", slug)
    .single();
  if (client?.id) {
    await db.rpc("advance_phase", {
      p_client_id: client.id,
      p_kind: kind,
      p_reviewer: reviewer,
    });
  }

  return { ok: true, blockers: [] };
}

export async function requestShip(
  slug: string,
  auditPassed: boolean,
): Promise<GateResult> {
  const phases = readPhases(slug);
  return canShip(phases, auditPassed);
}
