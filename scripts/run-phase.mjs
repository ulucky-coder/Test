#!/usr/bin/env node
// CLI mirror of /run-phase. Advances the active client's pipeline one phase.
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const PHASES = [
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
];

const kind = process.argv[2];
if (!kind || !PHASES.includes(kind)) {
  console.error(`usage: node scripts/run-phase.mjs <${PHASES.join("|")}>`);
  process.exit(1);
}

const root = process.cwd();
const state = JSON.parse(
  fs.readFileSync(path.join(root, ".claude/state.json"), "utf8"),
);
const slug = state.activeClient;
if (!slug) {
  console.error("no active client. run scripts/new-client.mjs <slug> first.");
  process.exit(1);
}

const phasesPath = path.join(root, "clients", slug, "phases.json");
const phases = JSON.parse(fs.readFileSync(phasesPath, "utf8"));

const priorIdx = PHASES.indexOf(kind) - 1;
if (priorIdx >= 0) {
  const priorKind = PHASES[priorIdx];
  if (phases[priorKind]?.status !== "approved") {
    console.error(
      `blocked: prior phase "${priorKind}" is ${phases[priorKind]?.status ?? "missing"}`,
    );
    console.error(
      `fix with: node scripts/run-phase.mjs ${priorKind} && node scripts/approve.mjs ${priorKind}`,
    );
    process.exit(2);
  }
}

phases[kind] = {
  ...phases[kind],
  status: "in_progress",
  started_at: new Date().toISOString(),
  iteration: (phases[kind]?.iteration ?? 0) + 1,
};
fs.writeFileSync(phasesPath, JSON.stringify(phases, null, 2));

console.log(
  `phase ${kind} -> in_progress (iteration ${phases[kind].iteration}) for ${slug}.`,
);
console.log("next: do the work, then set status=ready_for_review.");
