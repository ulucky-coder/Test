---
description: Log feedback against a phase and re-run it with the new constraints.
argument-hint: <phase> "<feedback>"
allowed-tools: Read, Write, Bash
---

# /revise

Phase rejection with structured feedback.

## Steps
1. Append feedback to `clients/<active>/reviews/<phase>-<timestamp>.md`.
2. Insert row into Supabase `reviews` table with verdict=`revise`.
3. Set phase status back to `pending`.
4. Re-invoke `/run-phase <phase>` with the feedback injected as additional context.
5. Increment phase iteration counter; if > 5, escalate to human.
