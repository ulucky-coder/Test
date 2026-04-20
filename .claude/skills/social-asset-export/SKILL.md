---
name: social-asset-export
description: Render the logo and key visuals into OG images, favicons, Apple touch, PWA icons, LinkedIn banner, Twitter header, Instagram 1:1 and 9:16. TRIGGER on /run-phase guidelines.
allowed-tools: Read, Write, Bash
---

# Social Asset Export

## Output
`clients/<slug>/social/`:
```
og/
  default.png        1200x630
  twitter-card.png   1200x600
favicon/
  favicon.ico, favicon-16.png, favicon-32.png
  apple-touch-icon.png  180x180
  icon-192.png, icon-512.png  (PWA)
  manifest.json
linkedin/
  banner.png         1584x396
  company-logo.png   400x400
twitter/
  header.png         1500x500
  profile.png        400x400
instagram/
  square.png         1080x1080
  story.png          1080x1920
  reel-cover.png     1080x1920
youtube/
  channel-art.png    2560x1440
  thumbnail.png      1280x720
```

## Process
1. Read `tokens.json` + `logo/`.
2. Compose layouts in SVG via `packages/svg-kit`.
3. Rasterize via `resvg-js` at exact target dims.
4. Generate `manifest.json` and `browserconfig.xml`.
5. Validate every asset's checksum into `social/manifest.lock.json`.

## Quality bar
- Logos render crisply at every size (favicon test).
- OG images preview correctly on LinkedIn/Twitter/Slack/Discord.
- File sizes optimized via `oxipng` and `svgo`.
