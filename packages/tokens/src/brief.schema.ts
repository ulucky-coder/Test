import { z } from "zod";

export const BriefSchema = z.object({
  slug: z.string().regex(/^[a-z][a-z0-9-]*$/, "kebab-case lowercase"),
  name: z.string().min(1),
  tagline: z.string().default(""),
  industry: z.enum([
    "fintech",
    "saas",
    "dtc",
    "agency",
    "creator",
    "infra",
    "health",
    "edu",
    "gov",
    "other",
  ]),
  stage: z
    .enum(["pre-seed", "seed", "series-a", "series-b", "growth", "enterprise"])
    .optional(),
  audience: z.object({
    primary: z.string().min(1),
    secondary: z.string().optional().nullable(),
    geography: z.array(z.string()).default(["US"]),
  }),
  tone_axes: z.object({
    serious_playful: z.number().min(0).max(1),
    classic_modern: z.number().min(0).max(1),
    minimal_expressive: z.number().min(0).max(1),
    warm_cool: z.number().min(0).max(1),
    premium_accessible: z.number().min(0).max(1),
  }),
  competitors: z
    .array(
      z.object({
        name: z.string(),
        url: z.string().url().optional(),
        what_we_like: z.string().optional(),
        what_to_avoid: z.string().optional(),
      }),
    )
    .default([]),
  constraints: z
    .object({
      must_include: z.array(z.string()).default([]),
      must_avoid: z.array(z.string()).default([]),
      color_locked: z.string().nullable().default(null),
      type_locked: z.string().nullable().default(null),
      trademark_blockers: z.array(z.string()).default([]),
    })
    .default({
      must_include: [],
      must_avoid: [],
      color_locked: null,
      type_locked: null,
      trademark_blockers: [],
    }),
  deliverables: z
    .array(z.string())
    .default(["logo", "brand_system", "site", "guidelines", "social"]),
  success_metrics: z.array(z.string()).default([]),
  deadline: z.string().nullable().default(null),
  budget_tier: z.enum(["standard", "premium", "flagship"]).default("standard"),
  notes: z.array(z.string()).default([]),
});

export type Brief = z.infer<typeof BriefSchema>;
