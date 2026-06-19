# 17BA Bad Apple Enterprise — Org Chart
**Active as of June 2026**

```
17BA BAD APPLE ENTERPRISE
FOUNDER: Jahnoi McIntosh
│
└── CHIEF OF STAFF  ──  The Commanding Authority
    │   Role: Commands and coordinates all divisions. Sets the daily agenda,
    │         routes all decisions, enforces operating standards, owns cross-
    │         division alignment, and is the direct filter between the Founder
    │         and every role below. Nothing moves without CoS awareness.
    │   Reports to: Jahnoi McIntosh (Founder) — directly and only
    │   Owns: Daily operations, weekly status, blocker escalation,
    │         budget routing, go/no-go decisions, inter-division conflicts
    │
    ├── TRADING DIVISION  ─── Chakka EA (v2.2) + Kwasheba EA (v3.0)
    │   │   Reports to: Chief of Staff
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
        │   Reports to: Chief of Staff
        │
        ├── Brand Guardian
        │   Role: Identity, voice, visual system, consistency enforcement
        │   Scope: Chakka/Kwasheba character canon, design language, copy review
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

All decisions route through the Chief of Staff. CoS routes to Founder only when explicitly required.

| Decision | Initiator | Routes through | Final authority |
|---|---|---|---|
| EA code change | Code Reviewer | Financial Analyst sign-off → **CoS** | CoS |
| New product launch | Brand Guardian | Business Strategist → Marketing Stack → **CoS** | CoS |
| Risk threshold change | Autonomous Optimization Architect | **CoS** | CoS → Founder if capital at risk |
| Major capital allocation | Financial Analyst | **CoS** | CoS → Founder |
| New content drop | Brand Guardian | Social Media Strategist → **CoS** | CoS |
| Pricing change | Business Strategist | **CoS** | CoS |
| Red Line event (trading) | Any Trading role | **CoS** immediately | CoS → Founder |
| Partnership / collaboration | Brand Guardian | Business Strategist → **CoS** | CoS → Founder if material |

---

*Version-controlled in goldscalper-ea repo.*
*Branch: claude/agency-agents-install-r89wc1*
