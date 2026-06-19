# 17BA Agent Overwatch — Seating Floor

Your personal command floor, laid out like a seating chart. The **Chief of Staff**
sits at the head desk up front; below is a floor of seats you fill with agents
and a task when you need them, then clear when the job is done.

## How to open

Just **double-click `index.html`**. Opens in any browser — no server, no
Python, nothing to install.

## How it works

- **Head desk** = Chief of Staff (permanent commanding authority). Click it to
  read the role.
- **The floor** = 36 seats (desk + chair). An empty seat shows a `+`.
- **Click an empty seat** → choose an agent from the bench and type the task you
  want them on → they take the seat, chair lights up in their team colour.
- **Click a filled seat** → update the task, or **Remove** the agent to free the seat.
- **Clear Floor** empties every seat at once.
- **Staffing Log** records every seat / dismiss / reassign action.

The chair colour marks the team:
- 🟡 Gold — Trading Division
- 🟤 Terra — Brand Division
- 🔵 Blue — Build / Tech
- 🟢 Green — Operations

## The bench

The agent picker is grouped by team and includes the core enterprise roles plus
a wider bench (developers, marketers, analysts, ops) you can pull in for one-off
tasks. Three agents are pre-seated because they've already filed work: Code
Reviewer, Financial Analyst, and Brand Guardian.

## Saving

Your seating arrangement and the log are saved in the browser on **this device**
(localStorage). Open it on the same machine and your floor is exactly as you
left it. To carry it between devices, host the file somewhere both can reach.

---

This is the **agent HQ**. The separate `dashboard/` folder is the **live trading
bot monitor** — different tool, different job.
