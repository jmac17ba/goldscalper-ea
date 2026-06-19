# 17BA Bad Apple Enterprise — Org Chart
**Active as of June 2026**

```
17BA BAD APPLE ENTERPRISE
│
├── CHIEF OF STAFF
│   Role: Daily coordination, cross-division alignment, priority filter
│   Reports to: Jahnoi McIntosh (Founder)
│   Owns: Weekly status, task routing, blocker escalation
│
├── TRADING DIVISION  ─── Chakka EA (v2.2) + Quasheba EA (v3.0)
│   │
│   ├── Code Reviewer
│   │   Role: Bug detection, improvement recommendations, code quality
│   │   Scope: 17BA_Chakka.mq5, 17BA_Kwasheba.mq5, dashboard/
│   │   Cadence: On every EA change + weekly audit
│   │
│   ├── Financial Analyst
│   │   Role: Risk/performance framework, capital allocation, P&L tracking
│   │   Scope: Position sizing, drawdown analysis, monthly P&L reporting
│   │   Cadence: Monthly report + on-demand scenario analysis
│   │
│   └── Autonomous Optimization Architect
│       Role: Circuit breakers, guardrails, safety rules, system resilience
│       Scope: Guard thresholds, volatility filter tuning, kill switch design
│       Cadence: Quarterly review + triggered by drawdown events
│
└── CLOTHING BRAND DIVISION  ─── The Collections + Corefuel + Pod Apple
    │
    ├── Brand Guardian
    │   Role: Identity, voice, visual system, consistency enforcement
    │   Scope: Chakka/Quasheba character canon, design language, copy review
    │   Cadence: On every new product/content before publish
    │
    ├── Business Strategist
    │   Role: Market positioning, competitive analysis, growth planning
    │   Scope: Pricing, launch sequencing, ecosystem expansion strategy
    │   Cadence: Quarterly strategy + on demand for major decisions
    │
    └── Marketing Stack
        ├── Content Creator      — long-form, brand storytelling
        ├── Social Media Strategist — platform strategy, scheduling
        ├── Email Marketing      — lifecycle sequences, member comms
        └── Growth Hacker        — acquisition channels, viral mechanics
```

---

## Daily CoS Checklist

**Trading Division (run daily):**
- [ ] Check dashboard — both bots WATCHING or RUNNING
- [ ] Note any guard triggers from prior session (check logs)
- [ ] Review floating P&L vs guard thresholds
- [ ] Any EA updates pending? → route to Code Reviewer

**Brand Division (run weekly):**
- [ ] Social content published per pillar schedule?
- [ ] Any drop approaching? → alert Brand Guardian for review
- [ ] POD sales update — any SKU near 50-unit graduation?
- [ ] Academy content progress?

**Cross-division:**
- [ ] Trading income this week → confirm surplus available for brand spend
- [ ] Any new member sign-ups → verify tier unlock working

---

## Decision Routing

| Decision | Routes to |
|---|---|
| EA code change | Code Reviewer → Financial Analyst sign-off → push |
| New product launch | Brand Guardian → Business Strategist → Marketing Stack |
| Risk threshold change | Autonomous Optimization Architect → CoS approval |
| Major capital allocation | Financial Analyst → CoS → Founder |
| New content drop | Brand Guardian → Social Media Strategist |
| Pricing change | Business Strategist → CoS |

---

*Version-controlled in goldscalper-ea repo.*
*Branch: claude/agency-agents-install-r89wc1*
