# Bad Apple 17BA — Trading EAs for MetaTrader 5

Two automated Expert Advisors for **XAUUSD (gold)** on **MetaTrader 5**. Buy once from
[17ba-bad-apple-enterprise.vercel.app](https://17ba-bad-apple-enterprise.vercel.app), download your file, attach, and run.

| EA | File | Chart | Style |
|----|------|-------|-------|
| **17BA Chakka** | `17BA_Chakka.mq5` | XAUUSD **M15** | Exclusive straddle + 8-level Fibonacci recovery |
| **17BA Kwasheba** | `17BA_Kwasheba.mq5` | XAUUSD **M1** | Fast scalper + 4-level recovery grid |

> ⚠️ **Risk warning.** Trading gold is high-risk and can lose money. These EAs use grid/recovery
> methods that can draw down heavily in strong trends. **No profit is guaranteed.** Test on a **demo
> account** and backtest in the Strategy Tester before risking real funds. Full disclaimer:
> [/risk](https://17ba-bad-apple-enterprise.vercel.app/risk).

---

## Quick Setup

1. Install **MetaTrader 5** from your broker (Deriv recommended for low XAUUSD spreads).
2. In MT5: **File → Open Data Folder → MQL5 → Experts**, and copy your `.mq5` file there.
3. In **MetaEditor**, open the file and press **Compile (F7)** — should be 0 errors.
4. Back in MT5, in the **Navigator**, right-click **Expert Advisors → Refresh**.
5. Open the correct chart (**Chakka → XAUUSD M15**, **Kwasheba → XAUUSD M1**).
6. Drag the EA onto the chart → tick **Allow Algo Trading** → **OK**.
7. Make sure the toolbar **Algo Trading** button is green. A smiley in the top-right of the chart means it's live.

> One EA per chart. To run both, use two separate charts.

---

## 17BA Chakka — XAUUSD M15

Opens a BUY and SELL straddle. The moment one side needs recovery it **commits to that side and closes
the other** (no both-sides stacking). Recovery adds Fibonacci lots until the basket closes in profit.
Order-block & liquidity filters avoid poor entries.

**Key settings**

| Setting | Default | Notes |
|---------|---------|-------|
| `InpTPDist` | `0.40` | Basket take-profit distance (price units) |
| `InpRecovGap` | `1.20` | Gap between recovery levels |
| `InpMaxLevels` | `12` | Max recovery levels, 1–12 (lots 0.01 → 2.51). More = deeper averaging but much bigger risk |
| `InpUseGuard` | `true` | Emergency drawdown guard on/off |
| `InpMaxLossPct` | `20.0` | Cut the basket if floating loss exceeds this % of balance |
| `InpUseVolFilter` | `true` | Pause opening NEW straddles when volatility (ATR) is elevated — keeps the grid out of violent trends |
| `InpMaxATRMult` | `1.8` | "Elevated" = current ATR > this × its recent average |
| `InpUseOBLQ` | `true` | Order-block / liquidity entry filter |
| `InpAutoScale` | `false` | Turn **on** only if running on a non-gold instrument |

> Risk dial: for a safer setup keep `InpUseGuard` and `InpUseVolFilter` on and lower `InpMaxLevels`
> (e.g. 6–8). For full-send, turn the guard off and run 12 levels — understand that with no guard a
> basket can ride all the way to margin call if price never retraces.

---

## 17BA Kwasheba — XAUUSD M1

Fast M1 scalper: MA-cross + RSI entries, breakeven + trailing stops, with a shallow 4-level recovery grid.
Stops auto-widen to your broker's minimum, and lot size is capped so the grid can't balloon.

**Key settings**

| Setting | Default | Notes |
|---------|---------|-------|
| `FixedLot` | `0.01` | Base lot. **Keep this small** — 0.80 on gold is huge |
| `RiskPercent` | `0.0` | Optional: auto-size base lot to % of balance per trade (0 = use FixedLot) |
| `MaxLot` | `0.50` | Hard cap on **every** order incl. recovery |
| `MaxRecoveryLevel` | `4` | Max grid layers |
| `RecoveryMultiply` | `1.5` | Lot multiplier per recovery level |
| `UseRiskGuard` | `true` | Drawdown + daily-loss guards on/off |
| `MaxDrawdownPct` | `55.0` | Lower this for safety |
| `InpAutoScale` | `false` | Scale point distances to chart volatility (non-gold) |

> Sizing note: on gold, **1 lot = 100 oz** (~$80 P/L per $1 move). Start at `FixedLot = 0.01` and only
> increase once you've tested on demo.

---

## Updating

When a new version ships, re-download your file, replace it in `MQL5\Experts`, recompile (F7), then
**remove and re-attach** the EA on its chart so MT5 loads the new build.

---

© Bad Apple 17BA Enterprise. For your own use only — do not redistribute.
