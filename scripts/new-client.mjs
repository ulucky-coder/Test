#!/usr/bin/env node
// Bootstrap a new client workspace. Mirror of /new-brief command for CLI use.
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const args = process.argv.slice(2);
const slug = args[0];
const name = args.find((a, i) => args[i - 1] === "--name") ?? slug;

if (!slug) {
  console.error(
    'usage: node scripts/new-client.mjs <slug> [--name "Display Name"]',
  );
  process.exit(1);
}

if (!/^[a-z][a-z0-9-]*$/.test(slug)) {
  console.error(
    `invalid slug "${slug}" (kebab-case, lowercase, start with letter)`,
  );
  process.exit(1);
}

const root = process.cwd();
const dir = path.join(root, "clients", slug);

if (fs.existsSync(dir)) {
  console.error(`client workspace already exists: ${dir}`);
  process.exit(1);
}

const subs = [
  "moodboards",
  "concepts",
  "logo",
  "site",
  "social",
  "reports",
  "research",
  "reviews",
];
for (const s of subs) fs.mkdirSync(path.join(dir, s), { recursive: true });

const briefTemplate = JSON.parse(
  fs.readFileSync(
    path.join(root, ".claude/templates/brief.template.json"),
    "utf8",
  ),
);
briefTemplate.slug = slug;
briefTemplate.name = name;
fs.writeFileSync(
  path.join(dir, "brief.json"),
  JSON.stringify(briefTemplate, null, 2),
);

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
const phases = Object.fromEntries(
  PHASES.map((k) => [k, { kind: k, status: "pending", iteration: 0 }]),
);
fs.writeFileSync(
  path.join(dir, "phases.json"),
  JSON.stringify(phases, null, 2),
);

const state = JSON.parse(
  fs.readFileSync(path.join(root, ".claude/state.json"), "utf8"),
);
state.activeClient = slug;
fs.writeFileSync(
  path.join(root, ".claude/state.json"),
  JSON.stringify(state, null, 2),
);

console.log(`created clients/${slug}/ and set as active.`);
console.log(
  `next: fill in clients/${slug}/brief.json, then run /run-phase strategy`,
);
