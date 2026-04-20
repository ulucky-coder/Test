import { z } from "zod";

const ColorValue = z.union([
  z.string(),
  z.object({ light: z.string(), dark: z.string() }),
  z.object({ ref: z.string() }),
]);

export const TokensSchema = z.object({
  $schema: z.string().optional(),
  version: z.string().default("1.0.0"),
  color: z.object({
    brand: z.record(ColorValue),
    neutral: z.record(ColorValue),
    semantic: z.record(ColorValue),
  }),
  type: z.object({
    families: z.record(
      z.object({
        name: z.string(),
        source: z.enum(["fontsource", "adobe", "foundry", "self-host"]),
        license: z.string(),
        axes: z.record(z.tuple([z.number(), z.number()])).optional(),
      }),
    ),
    scale: z.object({ ratio: z.number(), base_px: z.number() }),
    leading: z.record(z.number()),
    tracking: z.record(z.string()),
  }),
  space: z.record(z.string()),
  radius: z.record(z.string()),
  shadow: z.record(z.string()),
  motion: z.object({
    duration: z.record(z.string()),
    easing: z.record(z.string()),
  }),
});

export type Tokens = z.infer<typeof TokensSchema>;
