# 17BA Project Brain — Progress Tree

A single-file, offline dashboard that shows the whole enterprise as a growing tree:
the **17BA Bad Apple** core at the root, six numbered **pillars** as branches (in
roadmap order), and every project + connected file hanging off them as sub-nodes.

## How to open it
Double-click **`index.html`**. It opens in any browser. No internet, no install,
nothing to run — everything is inside the one file.

What you can do:
- **Click a pillar pin** (the numbered circle) → see its projects.
- **Click a project dot** → see its agent, status, files, and next step.
- **Hover a branch** → it highlights, the rest dim.
- **Filter chips** (top-right): All · Next steps · Done · Active.
- The branch with a **pulsing amber ring** is what to grow next.

## Colors
🟢 Done / Live · 🟡 Active · ⚪ Draft · 🔵 Idea · 🟩 Next step

## Who keeps it updated
**Claude maintains this.** You just do the work assigned each session — when we open
and close, Claude updates the tree (adds, expands, or prunes branches; flips a project
from idea → active → done; moves the next-step marker), commits it, and hands you the
refreshed file. You never have to edit it by hand.

> The single source of truth is the `DATA` block at the top of the `<script>` in
> `index.html`. If you ever *want* to tweak it yourself, that's the only place to look —
> change a `status`, add a project, save, refresh.
