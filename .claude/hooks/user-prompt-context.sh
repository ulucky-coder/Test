#!/usr/bin/env bash
# UserPromptSubmit hook: inject active client context (brief, tokens, current phase).
set -euo pipefail

STATE_FILE=".claude/state.json"
[[ -f "$STATE_FILE" ]] || exit 0

ACTIVE=$(node -e "try{console.log(require('./$STATE_FILE').activeClient||'')}catch(e){}" 2>/dev/null || echo "")
[[ -n "$ACTIVE" ]] || exit 0

CLIENT_DIR="clients/$ACTIVE"
[[ -d "$CLIENT_DIR" ]] || exit 0

CONTEXT="## Active Client Context: $ACTIVE\n"

if [[ -f "$CLIENT_DIR/brief.json" ]]; then
  NAME=$(node -e "try{console.log(require('./$CLIENT_DIR/brief.json').name||'')}catch(e){}" 2>/dev/null || echo "")
  INDUSTRY=$(node -e "try{console.log(require('./$CLIENT_DIR/brief.json').industry||'')}catch(e){}" 2>/dev/null || echo "")
  CONTEXT+="Brand: $NAME ($INDUSTRY)\n"
fi

if [[ -f "$CLIENT_DIR/phases.json" ]]; then
  CURRENT=$(node -e "
    try {
      const p=require('./$CLIENT_DIR/phases.json');
      const next=Object.entries(p).find(([k,v])=>v.status!=='approved');
      console.log(next?next[0]+' ('+next[1].status+')':'all approved');
    } catch(e){}
  " 2>/dev/null || echo "")
  CONTEXT+="Current phase: $CURRENT\n"
fi

printf "%b" "$CONTEXT"
exit 0
