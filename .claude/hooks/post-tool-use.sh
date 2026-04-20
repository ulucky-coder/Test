#!/usr/bin/env bash
# PostToolUse hook: format edited files, SVGO optimize SVGs, mirror to Supabase.
set -euo pipefail

INPUT=$(cat)
PATH_EDITED=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const j=JSON.parse(d);console.log(j.tool_input?.file_path||'')}catch(e){}})" 2>/dev/null || echo "")

if [[ -z "$PATH_EDITED" ]]; then
  exit 0
fi

case "$PATH_EDITED" in
  *.svg)
    if command -v svgo >/dev/null 2>&1; then
      svgo --multipass --quiet "$PATH_EDITED" 2>/dev/null || true
    fi
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs)
    if command -v biome >/dev/null 2>&1; then
      biome format --write "$PATH_EDITED" 2>/dev/null || true
    elif command -v prettier >/dev/null 2>&1; then
      prettier --write --log-level silent "$PATH_EDITED" 2>/dev/null || true
    fi
    ;;
  *.css)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write --log-level silent "$PATH_EDITED" 2>/dev/null || true
    fi
    ;;
esac

# If the edit lives inside clients/<slug>/, enqueue a Supabase mirror job
if [[ "$PATH_EDITED" =~ clients/([^/]+)/ ]]; then
  SLUG="${BASH_REMATCH[1]}"
  QUEUE=".claude/state/sync-queue.jsonl"
  mkdir -p "$(dirname "$QUEUE")"
  node -e "
    const fs=require('fs');
    const entry={slug:'$SLUG',path:'$PATH_EDITED',ts:Date.now()};
    fs.appendFileSync('$QUEUE', JSON.stringify(entry)+'\n');
  " 2>/dev/null || true
fi

exit 0
