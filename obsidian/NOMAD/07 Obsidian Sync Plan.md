---
tags: [nomad, project, obsidian]
created: 2026-07-14
---

# Obsidian Sync Plan — NOMAD ↔ This Vault

## Goal

Everything from NOMAD's Notes app lands in this vault automatically, organized — and notes I write here in the `NOMAD/` folder show up in NOMAD's web app too. True two-way.

## Why it's a natural fit

NOMAD's Notes app is **FlatNotes**, which stores notes as **plain Markdown files** — the exact same format as Obsidian. No conversion needed, just file syncing.

## The one limitation to design around

FlatNotes is **flat** — it doesn't understand folders. So:
- This `NOMAD/` folder = the shared space (flat, no subfolders inside it)
- The rest of my vault stays Obsidian-only, folders and all — FlatNotes never sees it

## Setup steps (Claude can do this with me — Friday or any session)

1. Find FlatNotes' storage folder inside NOMAD:
   ```bash
   sudo docker inspect nomad_admin | grep -i volume
   # or search for it:
   sudo find /opt/project-nomad -name "*.md" 2>/dev/null
   ```
2. The files are visible from Windows at `\\wsl.localhost\Ubuntu\opt\project-nomad\...`
3. Set up a small sync script (robocopy on a schedule) between that folder and this vault's `NOMAD/` folder — two-way
4. If Obsidian handles the network path well, an alternative is pointing directly at it — test first, it can be flaky
5. If I outgrow this: install **Syncthing** from NOMAD's Supply Depot for proper multi-device vault sync

## Status

- [x] This knowledge pack created and dropped into the vault (2026-07-14)
- [ ] FlatNotes storage folder located
- [ ] Two-way sync running
