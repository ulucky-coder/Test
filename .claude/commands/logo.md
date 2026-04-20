---
description: Iterate the active logo or forge variants from an approved one.
argument-hint: [--variants] [--from <concept-id>]
allowed-tools: Read, Write, Edit, Bash
---

# /logo

Two modes:

## Mode 1: iterate (default)
- Re-runs `logo-svg-generator` with feedback from the latest review.

## Mode 2: variants (`--variants`)
- Pre-check: a primary concept is approved.
- Run `logo-variant-forger` to derive horizontal/stacked/monogram/favicon/monochrome/inverse + safe-area + construction.svg + raster exports.
- Hand off to `art-director` for final review.
