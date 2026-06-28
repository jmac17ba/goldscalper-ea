# Bad Apple — Website

The public Bad Apple ecosystem site. Self-contained static HTML — no build step, no dependencies.

## Pages
- `index.html` — ecosystem homepage. Glowing tree grows as you scroll; reveals the four branches (Bots, Collections, Corefuel, Academy), the philosophy, and the community.
- `bots.html` — the sellable page: Chakka + Quasheba trading bots, how the engine works, a comparison table, getting-started steps, and pricing/access. Education-first, no profit promises.
- `risk.html` — full risk disclosure (linked from the README's `/risk` and from every trading mention).

## Deploy
Any static host. For **Vercel**: drop this folder in (or point the project's output at it) — no framework, no build command. Set the output/root to `site/` and it serves as-is.

```
# from the repo root
npx vercel deploy site --prod      # or connect the repo and set root dir = site
```

## Brand rules baked in
- Palette: black / gold (#c9a84c) / oxblood (#a83232) / teal accent (#3ad2e8).
- Voice: honest, education-first, teacher-not-pitchman.
- **Never promises trading returns.** The risk warning is visible, in oxblood, not hidden.

## Placeholders to fill before launch
- Bot pricing (`Price TBC` on `bots.html`).
- Real access / checkout flow (currently a `mailto:` "Request access").
- Real contact email (replace `hello@badapple.example`).
- Collections / Corefuel / Academy are presented on the homepage but not yet their own pages.
