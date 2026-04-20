---
description: Summarize what worked, update skill prompts and research corpus from this engagement's signal.
allowed-tools: Read, Write, Edit, Bash
---

# /retrospective

Close the feedback loop. Engagement signal → skill prompt edits → less drift over time.

## Steps
1. Aggregate `clients/<active>/reviews/*.md` (approved + revised).
2. Cluster feedback by skill (which skills had revisions).
3. For each clustered theme, draft a prompt-edit suggestion against the relevant `.claude/skills/*/SKILL.md`.
4. Open patches as proposed edits; require human review before applying.
5. Append a one-paragraph engagement summary to `research/retrospectives/<slug>-<date>.md`.
6. If a new visual pattern emerged, propose a tag for `research/tag-vocab.md`.
