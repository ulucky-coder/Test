#!/usr/bin/env bash
# PreToolUse hook: block dangerous commands and out-of-scope paths.
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).tool_name||'')}catch(e){}})" 2>/dev/null || echo "")
CMD=$(echo "$INPUT" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).tool_input?.command||'')}catch(e){}})" 2>/dev/null || echo "")

# Only gate Bash
if [[ "$TOOL" != "Bash" ]]; then
  exit 0
fi

BLOCK_PATTERNS=(
  "rm -rf /"
  "rm -rf ~"
  "rm -rf \$HOME"
  "git push --force"
  "git push -f "
  "git reset --hard"
  "supabase db reset"
  "chmod -R 777"
  "curl.*\| *sh"
  "wget.*\| *sh"
)

for pat in "${BLOCK_PATTERNS[@]}"; do
  if [[ "$CMD" =~ $pat ]]; then
    echo "BLOCKED by PreToolUse: matches forbidden pattern: $pat" >&2
    echo '{"decision":"block","reason":"command matches forbidden pattern"}'
    exit 2
  fi
done

exit 0
