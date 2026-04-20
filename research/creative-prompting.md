# Creative Prompting for Claude Skills

## Why this exists
Generative AI regresses to the mean. These techniques keep outputs sharp and off the center of the training distribution.

## Techniques

### 1. Forced difference
Produce N candidates, then explicitly enumerate pairwise differences. Reject any pair where differences are cosmetic (spacing, single hue shift).

### 2. Negative examples
Every skill prompt ends with 2–3 examples of what NOT to produce, citing concrete outputs from recent client history.

### 3. Constraint compounding
Stack 3+ hard constraints from strategy (archetype + industry + tone_axes). Loose constraints produce generic outputs.

### 4. Reference anchoring
When generating, cite 1-2 references by id from `references.json` that the output draws from. Forbid direct copying but require lineage.

### 5. Rubric self-scoring
Before emitting, each generator grades itself against the `design-review` rubric. If avg < 8, regenerate with the lowest-scoring axis as focus.

### 6. Structured slot-filling
Outputs come as explicit JSON, not prose. Skills fill slots; the narrative shell is templated.

### 7. Critique pass
After initial draft, Claude re-reads its own output with a "hostile art director" role and lists 3 problems before shipping. Problems must be addressed or explicitly waived.

## Banned phrases / structures in generator outputs
- "sleek and modern", "cutting-edge", "seamless", "innovative"
- gradient + rounded + drop-shadow combo (the SaaS default)
- mascot illustrations (unless brief demands)
- hero section with "faded-in text reveal" as the only motion idea

## Updated
2026-04-20
