#!/usr/bin/env bash
# SessionStart hook: load active client, verify env, warm MCP servers.
set -euo pipefail

STATE_FILE=".claude/state.json"
ACTIVE_CLIENT=""

if [[ -f "$STATE_FILE" ]]; then
  ACTIVE_CLIENT=$(node -e "try{console.log(require('./$STATE_FILE').activeClient||'')}catch(e){}" 2>/dev/null || echo "")
fi

echo "## Atelier Session"

if [[ -n "$ACTIVE_CLIENT" ]]; then
  echo "Active client: $ACTIVE_CLIENT"
  if [[ -f "clients/$ACTIVE_CLIENT/phases.json" ]]; then
    CURRENT=$(node -e "
      const p = require('./clients/$ACTIVE_CLIENT/phases.json');
      const next = Object.entries(p).find(([k,v]) => v.status !== 'approved');
      console.log(next ? next[0] + ' (' + next[1].status + ')' : 'all approved');
    " 2>/dev/null || echo "unknown")
    echo "Current phase: $CURRENT"
  fi
else
  echo "No active client. Run /new-brief <slug> to start."
fi

# Env check
MISSING=()
for var in SUPABASE_URL SUPABASE_ANON_KEY N8N_API_KEY; do
  if [[ -z "${!var:-}" ]]; then
    MISSING+=("$var")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Missing env vars: ${MISSING[*]}"
fi

exit 0
