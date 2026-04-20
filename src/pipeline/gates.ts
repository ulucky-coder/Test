import {
  PHASE_ORDER,
  priorPhase,
  type Phase,
  type PhaseKind,
} from "./phases.js";

export interface GateResult {
  ok: boolean;
  reason?: string;
  blockers: string[];
}

export function canStart(
  target: PhaseKind,
  phases: Record<PhaseKind, Phase>,
): GateResult {
  const prior = priorPhase(target);
  if (!prior) return { ok: true, blockers: [] };
  const p = phases[prior];
  if (!p || p.status !== "approved") {
    return {
      ok: false,
      reason: `prior phase "${prior}" is ${p?.status ?? "missing"}`,
      blockers: [`/run-phase ${prior}`, `/approve ${prior}`],
    };
  }
  return { ok: true, blockers: [] };
}

export function canShip(
  phases: Record<PhaseKind, Phase>,
  auditPassed: boolean,
): GateResult {
  const blockers: string[] = [];
  if (!auditPassed) blockers.push("/audit must return PASS within 24h");

  for (const kind of PHASE_ORDER) {
    if (kind === "deploy" || kind === "handoff") break;
    const p = phases[kind];
    if (!p || p.status !== "approved")
      blockers.push(`phase ${kind} is ${p?.status ?? "missing"}`);
  }

  return blockers.length === 0
    ? { ok: true, blockers: [] }
    : { ok: false, reason: "ship gate blocked", blockers };
}

export function canApprove(
  target: PhaseKind,
  phases: Record<PhaseKind, Phase>,
): GateResult {
  const p = phases[target];
  if (!p) return { ok: false, reason: "phase not found", blockers: [] };
  if (p.status !== "ready_for_review") {
    return {
      ok: false,
      reason: `phase status is ${p.status}, expected ready_for_review`,
      blockers: [],
    };
  }
  return canStart(target, phases);
}
