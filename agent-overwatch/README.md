# 17BA Agent Overwatch

Your personal command floor — see every agent in the enterprise, their status,
and read what they've delivered.

## How to open

Just **double-click `index.html`**. It opens in any browser. No server, no
Python, nothing to install. It's fully self-contained.

(On a phone/tablet: open the file in a browser app, or push it to any free
static host like GitHub Pages and visit the link.)

## What you see

- **Founder → Chief of Staff** at the top — CoS is the commanding authority
  over both divisions.
- **Trading Division** (left): Code Reviewer, Financial Analyst, Autonomous
  Optimization Architect.
- **Brand Division** (right): Brand Guardian, Business Strategist, Marketing Stack.
- **Status dots**: green = working, gold = deliverable filed, grey = standby.
- **Stat bar**: roster count, active, deliverables filed, on standby.
- **Activity log**: recent agent actions.

**Click any desk** to open a brief: that agent's mission, current standing,
what they've delivered, and the files holding their actual work.

## How it stays current

This is a roster + deliverables view, not a live process monitor — your agents
run on command and file their work into `bad-apple-enterprise/`. When an agent
completes a new task, its entry in `index.html` (the `AGENTS` object near the
top of the `<script>`) gets updated: status, delivered list, and file links.
The activity log is the `ACTIVITY` array right below it.

This is different from `dashboard/` — that one is the live trading bot monitor.
This one is the agent HQ.
