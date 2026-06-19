# Chakka EA — Technical Specification
**17BA_Chakka.mq5 | Version 2.2 | Magic Number: 171717**
**Character: Chakka — Male honey badger. Aggressive. Precise. Built in the dark.**

---

## Quick Reference

| Parameter | Value |
|---|---|
| File | `17BA_Chakka.mq5` |
| Version | 2.2 |
| Magic Number | 171717 |
| Primary Instrument | XAUUSD (Gold) |
| Risk Profile | Aggressive |
| Max Recovery Levels | 12 |
| Drawdown Guard | 20% of balance |
| Straddle Gap Multiplier | 1.20× ATR |
| Max ATR Multiplier | 2.0× (volatility filter) |
| Lines of Code | ~464 |

---

## Strategy: Pending-OCO Breakout + Fibonacci Recovery

### Phase 1 — The Setup (Straddle)
- Places BUY STOP + SELL STOP simultaneously around current price
- Distance = `1.20 × ATR` (ATR calculated fresh each tick)
- First fill triggers → second order cancelled immediately (OCO logic)
- No prediction of direction — catches the move whichever way it breaks

### Phase 2 — Normal Exit
- If filled trade hits TP → profit taken, straddle resets after cooldown
- Standard ATR-based TP and SL applied to first entry

### Phase 3 — Recovery (If Trade Goes Wrong)
If trade moves against the initial entry, recovery basket activates:

**Fibonacci lot sequence (12 levels):**
```
Level  1:  0.01 lots
Level  2:  0.02 lots
Level  3:  0.03 lots
Level  4:  0.05 lots
Level  5:  0.08 lots
Level  6:  0.13 lots
Level  7:  0.22 lots
Level  8:  0.37 lots
Level  9:  0.59 lots
Level 10:  0.96 lots
Level 11:  1.55 lots
Level 12:  2.51 lots
```
Each new position added at Fibonacci spacing — when price recovers to basket average,
all positions close in profit. Larger lots at deeper levels accelerate recovery.

### Phase 4 — Emergency Guard
If total basket floating loss > 20% of account balance:
- **Full basket closes immediately**
- Prevents catastrophic drawdown
- EA resets and waits for next valid setup

---

## Key Functions

| Function | What It Does |
|---|---|
| `UpdateScaling()` | Recalculates ATR-based distances each tick |
| `VolElevated()` | Returns true if ATR > MaxATRMult × average — pauses straddles |
| `PlaceStraddle()` | Places the BUY STOP + SELL STOP pair |
| `RecoverState()` | On EA restart, rebuilds g_committed from live open positions |
| `OnTick()` | Main loop: Guard → OCO cancel → Set straddle → Recovery |

---

## Filters

**Volatility Filter**
- Checks if current ATR > (MaxATRMult × average ATR)
- When elevated: no new straddles placed, existing positions managed normally
- Prevents entering during news spikes or abnormal volatility

**Order Block Check**
```mql5
if (range < 0.01) continue;  // Chakka threshold
```
Skips order blocks with range < 0.01 — avoids micro-range traps

**Liquidity Detection**
- Checks proximity to key liquidity levels before entry
- Avoids stacking orders where stops would be swept

---

## State Recovery
`RecoverState()` runs on `OnInit()`:
- Scans all live positions with Magic Number 171717
- Reconstructs `g_committed` (the lot commitment tracker)
- Means EA survives MT5 restart, VPS reboot, or reconnect without losing basket state
- Critical for uninterrupted recovery basket management

---

## Risk Notes

Chakka is the aggressive bot. The 12-level Fibonacci basket means:
- Level 12 position is 2.51 lots
- Total maximum exposure across all 12 levels is significant
- Requires adequate account capital for the basket to breathe
- Recommended minimum account: **$1,000+ for safe operation**
- The 20% drawdown guard is your last line — do not disable it

**This EA is an educational tool. Past performance does not guarantee future results.
Automated trading involves substantial risk of loss.**

---

## Membership & Pricing

| Price | Tier Unlocked |
|---|---|
| $297 | Gold — Chakka Collection clothing drops |
| $397 (bundle with Quasheba) | Platinum — All drops + Academy |

---

## Version History

| Version | Notes |
|---|---|
| v2.2 (current) | Pending-OCO breakout + Fibonacci recovery, OB/liquidity filters, state recovery |
| v2.1 | Earlier OCO implementation |
| v1.x | Predecessor scalper logic (see backup file) |
