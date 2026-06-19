# Quasheba EA — Technical Specification
**17BA_Kwasheba.mq5 | Version 3.0 | Magic Number: 8000002**
**Character: Quasheba — Female honey badger. Disciplined. Heritage. Feminine power.**

---

## Quick Reference

| Parameter | Value |
|---|---|
| File | `17BA_Kwasheba.mq5` |
| Version | 3.0 |
| Magic Number | 8000002 |
| Primary Instrument | XAUUSD (Gold) — with multi-instrument support |
| Risk Profile | Disciplined |
| Max Recovery Levels | 5 |
| Drawdown Guard | 15% of balance |
| Straddle Gap Multiplier | 1.50× ATR (wider than Chakka's 1.20) |
| Max ATR Multiplier | 2.0× (volatility filter) |
| Lines of Code | ~441 |

---

## How Quasheba Differs From Chakka

Quasheba and Chakka run the same core engine. Quasheba is the disciplined version:

| Setting | Chakka | Quasheba | Effect |
|---|---|---|---|
| Max recovery levels | 12 | 5 | Smaller max exposure |
| Drawdown guard | 20% | 15% | Exits sooner, more conservative |
| Straddle gap | 1.20× ATR | 1.50× ATR | Wider entry — less noise, cleaner signals |
| Multi-instrument | No explicit check | `IsGoldSymbol()` function | Auto-scales on non-gold instruments |
| OB range check | `range < 0.01` | `range <= 0` | Different threshold logic |

---

## Strategy: Pending-OCO Breakout + Fibonacci Recovery

### Phase 1 — The Setup (Straddle)
- Places BUY STOP + SELL STOP simultaneously around current price
- Distance = `1.50 × ATR` (wider than Chakka — waits for more conviction)
- First fill triggers → second order cancelled immediately
- Catches the directional move without prediction

### Phase 2 — Normal Exit
- TP and SL scaled to ATR
- If TP hit → profit locked, reset after cooldown

### Phase 3 — Recovery (If Trade Goes Wrong)
If trade moves against initial entry, recovery basket activates:

**Fibonacci lot sequence (5 levels):**
```
Level 1:  0.01 lots
Level 2:  0.02 lots
Level 3:  0.03 lots
Level 4:  0.05 lots
Level 5:  0.08 lots
```
Maximum 5 levels — Quasheba does not chase as deep as Chakka.
When price recovers to basket average, all positions close in profit.

### Phase 4 — Emergency Guard
If total basket floating loss > 15% of account balance:
- **Full basket closes immediately** (triggers sooner than Chakka's 20%)
- EA resets and waits for next valid setup

---

## Key Functions

| Function | What It Does |
|---|---|
| `IsGoldSymbol()` | Detects if current symbol is gold — enables auto-scaling for other instruments |
| `UpdateScaling()` | Recalculates ATR-based distances each tick |
| `VolElevated()` | Returns true if ATR > MaxATRMult × average — pauses straddles |
| `PlaceStraddle()` | Places the BUY STOP + SELL STOP pair |
| `RecoverState()` | On EA restart, rebuilds basket state from live positions |
| `OnTick()` | Main loop: Guard → OCO cancel → Set straddle → Recovery |

---

## Filters

**Volatility Filter**
- Same as Chakka: pauses when ATR is elevated
- Prevents entry during news spikes

**Order Block Check**
```mql5
if (range <= 0) continue;  // Quasheba threshold (vs Chakka's < 0.01)
```
Quasheba's OB check accepts any positive range — slightly more permissive than Chakka
on order block filtering, but compensated by the wider straddle gap.

**Liquidity Detection**
- Same logic as Chakka — avoids key liquidity levels before entry

---

## Multi-Instrument Support (IsGoldSymbol)

Quasheba v3.0 includes explicit multi-instrument awareness:
- `IsGoldSymbol()` checks if current chart is a gold pair
- If NOT gold: ATR scaling factors adjust automatically for the instrument's volatility
- This means Quasheba can run on forex, indices, or other commodities
  without manual parameter adjustment

---

## State Recovery
`RecoverState()` runs on `OnInit()`:
- Scans all live positions with Magic Number 8000002
- Reconstructs basket state from open trades
- EA survives MT5 restart or VPS reboot without losing basket context

---

## Version History

| Version | Notes |
|---|---|
| v3.0 (current) | Pending-OCO + Fibonacci recovery, `IsGoldSymbol()`, multi-instrument ATR |
| v2.4 (backup) | Old MA+RSI scalper — archived at `removed-eas/17BA_Kwasheba_scalper_v2.4_backup.mq5` |

---

## Risk Notes

Quasheba is the disciplined bot. She does not go 12 levels deep:
- Max 5 levels means maximum basket lot is 0.08
- 15% drawdown guard triggers earlier — protects capital faster
- Suitable for smaller account sizes than Chakka
- **Recommended minimum account: $300+ for safe operation**

**This EA is an educational tool. Past performance does not guarantee future results.
Automated trading involves substantial risk of loss.**

---

## Membership & Pricing

| Price | Tier Unlocked |
|---|---|
| $197 | Silver — Quasheba Collection clothing drops |
| $397 (bundle with Chakka) | Platinum — All drops + Academy |
