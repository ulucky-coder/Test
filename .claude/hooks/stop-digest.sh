#!/usr/bin/env bash
# Stop hook: flush sync queue, post session digest via n8n webhook.
set -euo pipefail

QUEUE=".claude/state/sync-queue.jsonl"
WEBHOOK="${N8N_DIGEST_WEBHOOK:-}"

if [[ -f "$QUEUE" && -n "$WEBHOOK" ]]; then
  COUNT=$(wc -l < "$QUEUE" 2>/dev/null || echo "0")
  if [[ "$COUNT" -gt 0 ]]; then
    # Best-effort POST; never block the session teardown on network
    ( timeout 5 node -e "
      const fs=require('fs');
      const https=require('https');
      const url=require('url');
      const lines=fs.readFileSync('$QUEUE','utf8').trim().split('\n').filter(Boolean);
      const payload=JSON.stringify({event:'session_stop',edits:lines.map(JSON.parse)});
      const u=url.parse('$WEBHOOK');
      const req=(u.protocol==='https:'?https:require('http')).request({
        hostname:u.hostname,port:u.port,path:u.path,method:'POST',
        headers:{'content-type':'application/json','content-length':Buffer.byteLength(payload)}
      });
      req.on('error',()=>{});
      req.write(payload);req.end();
    " 2>/dev/null || true ) &
    # Rotate the queue
    mv "$QUEUE" "$QUEUE.$(date +%s).done" 2>/dev/null || true
  fi
fi

exit 0
