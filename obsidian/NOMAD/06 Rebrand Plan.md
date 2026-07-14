---
tags: [nomad, project, rebrand]
created: 2026-07-14
due: 2026-07-17
---

# Rebrand Plan — Making NOMAD Mine

**📅 Scheduled: Friday 2026-07-17, ~8:00 pm.**
To start: open Claude and say *"Do the NOMAD rebrand — the plan is in docs/project-nomad.md in my goldscalper-ea repo."*

## Goal

The Command Center with **my logo, my name, my colors** — and published on my brand page.

## What I need to bring Friday

- [ ] **Logo file** — PNG with transparent background works best
- [ ] **Brand colors** (hex codes if I have them, or just describe the vibe)
- [ ] Answer: what does *"push it to the brand page"* mean exactly — my website? social? (Claude will ask)

## How it will work (Claude does the heavy lifting)

1. Fork the open-source NOMAD code
2. Swap logo, product name, and theme colors in the web interface
3. Build a custom Docker image
4. Point my NOMAD at the custom image using an **override file** (so official updates don't erase the branding)

## The rules that keep it legit

- Apache 2.0 license **allows** modifying and rebranding — fully legal ✅
- Keep the license/attribution notice in the code
- Show "Powered by Project N.O.M.A.D." somewhere — honest and safe
- Don't claim the underlying system as my own invention when publishing

## Related

- [[01 What is Project NOMAD]]
- [[03 Daily Routine — Start and Stop]] (update caution after rebranding)
