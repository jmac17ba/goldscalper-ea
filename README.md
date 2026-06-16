# Bad Apple 17BA — Trading EAs for MetaTrader 5

Two automated Expert Advisors for **MetaTrader 5**. Buy once from
[17ba-bad-apple-enterprise.vercel.app](https://17ba-bad-apple-enterprise.vercel.app), download your file, attach, and run.

Both run the same engine: a **pending one-cancels-other (OCO) breakout** entry — a BUY STOP above
price and a SELL STOP below are *set, not entered*; whichever the market reaches first fills and the
other is cancelled — followed by a **Fibonacci recovery basket** that closes at a combined take-profit.

| EA | File | Chart | Style |
|----|------|-------|-------|
| **17BA Chakka** | `17BA_Chakka.mq5` | XAUUSD **M15** | OCO breakout + 12-level Fibonacci recovery (aggressive) |
| **17BA Kwasheba** | `17BA_Kwasheba.mq5` | **any pair** | OCO breakout + 5-level recovery (tamer, multi-instrument) |

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
5. Open the correct chart (**Chakka → XAUUSD M15**, **Kwasheba → any pair, M1 or M15**).
6. Drag the EA onto the chart → tick **Allow Algo Trading** → **OK**.
7. Make sure the toolbar **Algo Trading** button is green. A smiley in the top-right of the chart means it's live.

> One EA per chart. To run both, use two separate charts. After attaching, you'll see a **BUY STOP line
> above price and a SELL STOP line below** — that's the pending breakout, set and waiting.

---

## 17BA Chakka — XAUUSD M15

When flat, Chakka sets a **BUY STOP above** price and a **SELL STOP below** (each with its own
take-profit). Price breaks one way → that order fills and rides the move; the opposite pending is
cancelled. The filled side then runs a **Fibonacci recovery basket** — adding lots on adverse moves —
until the basket closes at its combined take-profit or the drawdown guard cuts it. Only one direction
is ever live, so the legs never cancel each other out.

**Key settings**

| Setting | Default | Notes |
|---------|---------|-------|
| `InpEntryGap` | `0.50` | Distance from price to each pending BUY/SELL STOP |
| `InpTPDist` | `0.40` | Basket take-profit distance (price units) |
| `InpRecovGap` | `1.20` | Gap between recovery levels |
| `InpMaxLevels` | `12` | Max recovery levels, 1–12 (lots 0.01 → 2.51). More = deeper averaging but much bigger risk |
| `InpUseGuard` | `true` | Emergency drawdown guard on/off |
| `InpMaxLossPct` | `20.0` | Cut the basket if floating loss exceeds this % of balance |
| `InpUseVolFilter` | `true` | Pause setting NEW pendings when volatility (ATR) is elevated |
| `InpMaxATRMult` | `1.8` | "Elevated" = current ATR > this × its recent average |
| `InpUseOBLQ` | `true` | Order-block / liquidity recovery filter |
| `InpAutoScale` | `false` | Turn **on** only if running on a non-gold instrument |

> Risk dial: for a safer setup keep `InpUseGuard` and `InpUseVolFilter` on and lower `InpMaxLevels`
> (e.g. 6–8). For full-send, turn the guard off and run 12 levels — understand that with no guard a
> basket can ride all the way to margin call if price never retraces.

---

## 17BA Kwasheba — any pair

Same OCO breakout + Fibonacci recovery engine as Chakka, but **tamer** and **multi-instrument**. Drop
her on XAUUSD, EURUSD, USDJPY, GBPUSD — anything. On non-gold symbols her distances **auto-scale** to
that pair's volatility; on gold she keeps the fixed numbers. Stops clamp to your broker's minimum and
lots normalize to each symbol, so orders aren't rejected.

**Key settings**

| Setting | Default | Notes |
|---------|---------|-------|
| `InpEntryGap` | `0.50` | Distance from price to each pending stop (auto-scaled off gold) |
| `InpTPDist` | `0.40` | Basket take-profit distance |
| `InpRecovGap` | `1.50` | Gap between recovery levels (wider than Chakka — adds less often) |
| `InpMaxLevels` | `5` | Max recovery levels (lots 0.01 → 0.08). Far tamer than Chakka's 12 |
| `InpUseGuard` | `true` | Emergency drawdown guard on/off |
| `InpMaxLossPct` | `15.0` | Cut the basket if floating loss exceeds this % of balance |
| `InpUseVolFilter` | `true` | Pause setting NEW pendings when volatility is elevated |
| `InpAutoScale` | `false` | Non-gold pairs auto-scale anyway; set **on** to force scaling on gold too |

> Multi-chart: you can run Kwasheba on several pairs at once (one chart each) — each instance only
> manages its own symbol. Don't run two copies on the *same* symbol (they share one magic number).

---

## Updating

When a new version ships, re-download your file, replace it in `MQL5\Experts`, recompile (F7), then
**remove and re-attach** the EA on its chart so MT5 loads the new build.

---

© Bad Apple 17BA Enterprise. For your own use only — do not redistribute.
