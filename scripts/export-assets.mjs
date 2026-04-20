#!/usr/bin/env node
// Export social/marketing assets from the active client's logo + tokens.
// Minimal spec-mode implementation; wire resvg-js for rasterization when the
// skill runs end-to-end. Today it emits the target manifest.
import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = process.cwd();
const state = JSON.parse(
  fs.readFileSync(path.join(root, ".claude/state.json"), "utf8"),
);
const slug = state.activeClient;
if (!slug) {
  console.error("no active client.");
  process.exit(1);
}

const out = path.join(root, "clients", slug, "social");
fs.mkdirSync(out, { recursive: true });

const manifest = {
  slug,
  generated_at: new Date().toISOString(),
  assets: [
    { path: "og/default.png", w: 1200, h: 630, context: "Open Graph default" },
    {
      path: "og/twitter-card.png",
      w: 1200,
      h: 600,
      context: "Twitter summary card",
    },
    { path: "favicon/favicon.ico", w: 32, h: 32, context: "legacy favicon" },
    { path: "favicon/favicon-32.png", w: 32, h: 32, context: "modern favicon" },
    {
      path: "favicon/apple-touch-icon.png",
      w: 180,
      h: 180,
      context: "iOS touch",
    },
    { path: "favicon/icon-192.png", w: 192, h: 192, context: "PWA" },
    { path: "favicon/icon-512.png", w: 512, h: 512, context: "PWA" },
    { path: "linkedin/banner.png", w: 1584, h: 396, context: "LinkedIn cover" },
    {
      path: "linkedin/company-logo.png",
      w: 400,
      h: 400,
      context: "LinkedIn logo",
    },
    { path: "twitter/header.png", w: 1500, h: 500, context: "X header" },
    { path: "twitter/profile.png", w: 400, h: 400, context: "X profile" },
    { path: "instagram/square.png", w: 1080, h: 1080, context: "IG square" },
    { path: "instagram/story.png", w: 1080, h: 1920, context: "IG story" },
    { path: "instagram/reel-cover.png", w: 1080, h: 1920, context: "IG reel" },
    {
      path: "youtube/channel-art.png",
      w: 2560,
      h: 1440,
      context: "YT channel",
    },
    { path: "youtube/thumbnail.png", w: 1280, h: 720, context: "YT thumbnail" },
  ],
};

fs.writeFileSync(
  path.join(out, "manifest.json"),
  JSON.stringify(manifest, null, 2),
);
console.log(
  `social manifest written for ${slug} (${manifest.assets.length} targets).`,
);
console.log(
  "TODO: run social-asset-export skill to rasterize SVGs via resvg-js.",
);
