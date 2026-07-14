---
tags: [nomad, reference]
created: 2026-07-14
---

# What is Project N.O.M.A.D.

**N.O.M.A.D.** = **N**ode for **O**ffline **M**edia, **A**rchives, and **D**ata.

An offline-first knowledge server by [Crosstalk Solutions](https://github.com/Crosstalk-Solutions/project-nomad). After setup, it works **without internet** — the whole point is having knowledge available when the network is down or unavailable. Licensed Apache 2.0 (open source, free to modify and rebrand — see [[06 Rebrand Plan]]).

## What it gives me

| App | What it does |
|-----|-------------|
| **Information Library** (Kiwix) | Offline Wikipedia, medical references, how-to guides, encyclopedias |
| **Maps** | Downloadable offline maps (grab Jamaica — see [[08 Content Downloads]]) |
| **Notes** (FlatNotes) | Markdown note-taking — connects to this vault, see [[07 Obsidian Sync Plan]] |
| **Data Tools** (CyberChef) | Encoding, encryption, data analysis Swiss Army knife |
| **AI Chat** (Ollama, via Supply Depot) | Local AI chat with document upload — needs decent RAM |
| **Supply Depot** | App store for adding more Docker apps |
| **Easy Setup** | First-run wizard for configuring everything |

## How it's built

Everything runs as **Docker containers** on my laptop inside **WSL2 Ubuntu** (a full Linux system living inside Windows). The main pieces: the Command Center web app, MySQL database, Redis, Dozzle (log viewer), plus updater/disk-monitor helpers.

Any device on my Wi-Fi can use it through a browser — nothing to install on phones/tablets. See [[04 Phone Access]].
