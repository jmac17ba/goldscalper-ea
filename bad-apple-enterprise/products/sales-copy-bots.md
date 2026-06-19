# Bad Apple Enterprise — Bot Sales Page Copy
**Chakka EA + Quasheba EA | Sales copy ready for Gumroad / standalone page**

---

# CHAKKA EA — SALES PAGE

## Headline
**The bot that runs while you sleep.**

## Subheadline
Chakka EA is an automated trading Expert Advisor for MetaTrader 5 — built for XAUUSD (gold),
running a breakout + recovery strategy with no manual intervention required.

---

## The Strategy (Plain English)

Most traders lose because they either miss the move or hold a loser too long.
Chakka solves both.

**Step 1 — The Setup**
Chakka places two pending orders simultaneously — one above price, one below.
Whichever direction gold breaks, Chakka catches it. The other order cancels automatically.
No prediction. No guessing. Just the move.

**Step 2 — If It Works**
Trade hits target → profit locked → Chakka resets and waits for the next setup.

**Step 3 — If It Doesn't**
Chakka adds to the position at calculated intervals using a Fibonacci lot sequence.
As price recovers to the average entry, the entire basket closes in profit.
Not a gamble — a mathematical recovery.

**Step 4 — The Guard**
If the market moves hard against the basket, a 20% drawdown guard closes everything.
Losses are capped. Chakka resets. The game continues.

---

## What's Inside

- Pending-OCO breakout engine (catches moves in either direction)
- 12-level Fibonacci recovery basket
- ATR auto-scaling (adapts to any instrument's volatility automatically)
- Volatility filter (pauses during news spikes — no entering during chaos)
- Order block + liquidity detection (avoids institutional trap zones)
- Emergency 20% drawdown guard (your last line of defence)
- State recovery (survives MT5 restarts and VPS reboots without losing basket position)
- Magic number: 171717 (isolates Chakka trades from anything else on your account)

---

## Specifications

| | |
|---|---|
| Platform | MetaTrader 5 |
| Primary Instrument | XAUUSD (Gold) |
| Version | 2.2 |
| Max Recovery Levels | 12 |
| Drawdown Guard | 20% of account balance |
| Straddle Gap | 1.20× ATR |
| Multi-instrument | Yes (ATR auto-scales) |
| Recommended Minimum | $1,000+ |

---

## Who This Is For

- You run MT5 and trade gold (or want to)
- You want an automated strategy you can understand (not a black box)
- You're building — the EA is the engine, not the whole plan
- You move in silence. You don't need permission.

## Who This Is NOT For

- People expecting guaranteed profits (no EA guarantees anything — this is a tool)
- Complete beginners with no risk capital (have a plan before you run it)
- Anyone looking for a get-rich shortcut

---

## The Membership

**Buy Chakka EA → unlock Gold member status.**

Gold members get:
- 24hr early access to every Chakka Collection clothing drop
- Members-only pricing on future Academy content
- NFC-authenticated garments (limited drops only available to members)

The bots fund the brand. The brand is for the people who run the bots.

---

## Price

**$297 — one-time payment**
Includes: Chakka EA .ex5 file + setup guide + Gold membership

**Bundle with Quasheba EA: $397** (save $97)
Includes: Both EAs + setup guides + Platinum membership

---

## What You Get

✓ Chakka EA v2.2 (.ex5 file, ready to attach in MT5)
✓ Setup guide (step-by-step from download to first trade)
✓ Strategy breakdown document (so you know exactly what it's doing)
✓ Gold member status (Chakka Collection drop access)
✓ Future updates included

---

## Legal / Risk Disclosure

Chakka EA is an educational and experimental trading tool. Automated trading involves
substantial risk of loss. Past performance — simulated or live — does not guarantee future results.
Only trade with capital you can afford to lose. This is not financial advice.

---
---

# QUASHEBA EA — SALES PAGE

## Headline
**Five levels of patience. Zero emotions.**

## Subheadline
Quasheba EA is a disciplined automated trading Expert Advisor for MetaTrader 5 —
same breakout engine as Chakka, built tighter, exits sooner, runs on gold and beyond.

---

## The Strategy (Plain English)

Quasheba runs the same core engine as Chakka. The difference is discipline.

Where Chakka goes 12 levels deep and holds hard —
Quasheba uses 5 levels, exits at 15%, and waits for cleaner entries.

**The widened straddle gap (1.50× ATR vs Chakka's 1.20×)** means Quasheba
only enters when the move is more decisive. Less noise. Fewer, cleaner trades.

Same outcome — breakout caught, recovery if needed, guard if it gets ugly.
Different temperament.

**Quasheba knows when to fold. That's the strategy.**

---

## What's Inside

- Pending-OCO breakout engine (same as Chakka)
- 5-level Fibonacci recovery basket (max exposure capped earlier)
- 1.50× ATR straddle gap (wider entry — filters out noise)
- ATR auto-scaling with `IsGoldSymbol()` detection (explicit multi-instrument support)
- Volatility filter (pauses in elevated ATR environments)
- Order block + liquidity detection
- Emergency 15% drawdown guard (exits sooner than Chakka)
- State recovery on restart
- Magic number: 8000002

---

## Specifications

| | |
|---|---|
| Platform | MetaTrader 5 |
| Primary Instrument | XAUUSD (Gold) + multi-instrument |
| Version | 3.0 |
| Max Recovery Levels | 5 |
| Drawdown Guard | 15% of account balance |
| Straddle Gap | 1.50× ATR |
| Multi-instrument | Yes (IsGoldSymbol auto-detection) |
| Recommended Minimum | $300+ |

---

## Chakka vs Quasheba — Which One?

| | Chakka | Quasheba |
|---|---|---|
| Risk profile | Aggressive | Disciplined |
| Recovery depth | 12 levels | 5 levels |
| Drawdown guard | 20% | 15% |
| Entry filter | 1.20× ATR | 1.50× ATR |
| Recommended account | $1,000+ | $300+ |
| Best for | Larger accounts, higher risk tolerance | Smaller accounts, conservative approach |
| Price | $297 | $197 |

**Run both:** They use different magic numbers and don't interfere with each other.
The bundle ($397) gives you both + Platinum membership.

---

## The Membership

**Buy Quasheba EA → unlock Silver member status.**

Silver members get:
- 24hr early access to every Quasheba Collection clothing drop
- Members-only pricing on Academy content
- NFC-authenticated garments on limited drops

---

## Price

**$197 — one-time payment**
Includes: Quasheba EA .ex5 file + setup guide + Silver membership

**Bundle with Chakka EA: $397** (save $97)
Includes: Both EAs + setup guides + Platinum membership (all drops + Academy)

---

## What You Get

✓ Quasheba EA v3.0 (.ex5 file, ready to attach in MT5)
✓ Setup guide (step-by-step from download to first trade)
✓ Strategy breakdown document
✓ Silver member status (Quasheba Collection drop access)
✓ Future updates included

---

## Legal / Risk Disclosure

Quasheba EA is an educational and experimental trading tool. Automated trading involves
substantial risk of loss. Past performance — simulated or live — does not guarantee future results.
Only trade with capital you can afford to lose. This is not financial advice.

---
---

# SETUP GUIDE — BOTH EAs

## Requirements
- MetaTrader 5 installed (download from your broker)
- A broker account that supports MT5 (XAUUSD must be available)
- Minimum account balance per EA (see specs above)
- VPS recommended for 24/7 operation (optional but better)

## Installation Steps

1. **Download** the .ex5 file from your purchase confirmation
2. **Open MT5** → File → Open Data Folder
3. **Navigate to:** MQL5 → Experts
4. **Drop the .ex5 file** into the Experts folder
5. **Restart MT5** (or refresh the Navigator panel)
6. **Open a XAUUSD chart** (H1 timeframe recommended to start)
7. **Drag the EA** from the Navigator onto the chart
8. **Enable "Allow Algo Trading"** in the EA settings dialog
9. **Set your lot sizes and risk parameters** (start conservative — see settings guide)
10. **Click OK** — Chakka/Quasheba is now live

## Recommended Starting Settings

| Setting | Conservative Start | Notes |
|---|---|---|
| Starting lot | 0.01 | Let it run a few cycles before increasing |
| Max ATR mult | 2.0 | Default — don't raise this early |
| Enable guard | Yes | Always on |
| Timeframe | H1 | Reduces noise vs lower timeframes |

---

*This document is the source copy for all bot sales pages.*
*Update here first, then update the live page.*
*Branch: claude/agency-agents-install-r89wc1*
