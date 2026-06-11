# GoldScalper v3 — XAUUSD Straddle + Fibonacci Recovery EA

MQL5 Expert Advisor for **Deriv MT5**, trading XAUUSD on the M1 timeframe.

## Strategy Overview

1. **Straddle entry** — places a BUY STOP above and SELL STOP below current price at the start of each bar
2. **Fibonacci recovery ladder** — if the triggered position moves against you, new positions are added at increasing lot sizes (0.01 → 0.02 → 0.03 → 0.05 → 0.08 → 0.13 → 0.21 …) every `RecoveryGapPips`
3. **Basket TP** — when recovery is active (2+ positions on one side), all positions close together when price returns to the entry level of the **most recently added** recovery position (the last-added trade breaks even, and the basket exits at a controlled loss rather than waiting for full recovery)
4. **Trend filter** — blocks new straddless when the last N candles are trending strongly in one direction
5. **Recovery pause** — stops adding levels 3+ when the trend is running hard against the basket

---

## Current Input Parameters (recommended settings)

| Group | Parameter | Value | Description |
|-------|-----------|-------|-------------|
| Core | `BaseLot` | `0.01` | Lot size for initial straddle entries |
| Core | `TargetProfitUSD` | `0.45` | Profit target for single-position closes (price units) |
| Core | `MagicNumber` | `9000001` | EA identifier |
| Core | `Slippage` | `10` | Max slippage in points |
| Straddle | `StopOffsetPips` | `5.0` | Distance from current price to place stop orders |
| Straddle | `OrderExpiryBars` | `0` | 0 = GTC (never expire) |
| Straddle | `MaxOpenPositions` | `12` | Maximum simultaneous positions |
| Recovery | `UseRecovery` | `true` | Enable Fibonacci recovery ladder |
| Recovery | `RecoveryGapPips` | `12.0` | Gap between recovery levels |
| Recovery | `MaxRecoveryLevel` | `6` | Max number of recovery levels |
| Frequency | `TradeGapSeconds` | `5` | Minimum seconds between trades |
| Frequency | `TradeWeekends` | `false` | Skip weekend trading |
| Trend Filter | `TrendLookback` | `5` | Candles to look back for trend detection |
| Trend Filter | `TrendMaxSame` | `4` | Block straddle if X same-direction candles |
| Trend Filter | `TrendMaxRangePips` | `20.0` | Block straddle if range > X pips over lookback |
| Risk | `MaxDrawdownPct` | `20.0` | Max drawdown % before EA stops |
| Risk | `MaxDailyLossPct` | `5.0` | Max daily loss % |
| Risk | `UseSpreadFilter` | `true` | Skip trades when spread is too wide |
| Risk | `MaxSpread` | `20` | Max allowed spread in points |
| Lifecycle | `SessionProfitTarget` | `100.0` | Stop EA when session profit reaches $100 |
| Lifecycle | `SessionLossLimit` | `-150.0` | Stop EA when session loss reaches -$150 |
| Lifecycle | `HardFloorUSD` | `-200.0` | Close ALL positions if equity drops $200 |
| Telegram | `TelegramToken` | `""` | Optional: paste your bot token |
| Telegram | `TelegramChatId` | `""` | Optional: paste your chat ID |

---

## Installation on Deriv MT5

1. Open **MetaTrader 5** (Deriv)
2. Go to **File → Open Data Folder**
3. Navigate to `MQL5/Experts/`
4. Copy `GoldScalper_v3.mq5` into that folder
5. In MT5: go to **Navigator** panel → **Expert Advisors** → right-click → **Refresh**
6. Double-click `GoldScalper_v3` to open the EA settings dialog
7. Enter the parameters from the table above
8. Attach to an **XAUUSD M1** chart
9. Enable **AutoTrading** (the green play button at the top)

---

## Key Logic Notes for AI Setup

### TP Strategy (Recovery Baskets)
When a recovery basket has 2+ positions:
- **Close trigger**: `ManageBaskets()` fires every tick — closes the basket when `bid ≤ g_lastSellEntry` (SELL) or `ask ≥ g_lastBuyEntry` (BUY)
- `g_lastSellEntry` / `g_lastBuyEntry` are set each time a new recovery level opens
- Fallback: basket also closes via individual position TPs (set to weighted average entry in `UpdateBasketTPs`)

### Trend Filter
`PassFilters()` checks the last `TrendLookback` M1 candles:
- Counts bullish vs bearish candles → blocks straddle if `≥ TrendMaxSame` same-color
- Measures high–low range → blocks if `> TrandMaxRangePips` pips

### Recovery Pause
`CheckRecovery()` calls `TrendingAgainst()` before opening level 3+:
- Counts candles running against the basket direction
- If `≥ TrendMaxSame` candles against → skips adding the next level

### Session Lifecycle
- Session state persists across EA restarts via `GoldScalper_session.csv`
- Skipped in backtesting (detected via `MQLInfoInteger(MQL_TESTER)`)
- `ClearSession()` resets `g_lastBuyEntry` and `g_lastSellEntry`

### Chart Visuals
- **Dotted recovery lines** — `OBJ_TREND` connecting each recovery level (prefix `GS3_`)
- **Entry arrows** — `OBJ_ARROW_BUY` / `OBJ_ARROW_SELL` drawn via `OnTradeTransaction`

---

## Files

| File | Purpose |
|------|---------|
| `GoldScalper_v3.mq5` | Main EA source code |

---

## Broker / Account Requirements

- **Broker**: Deriv (MT5)
- **Symbol**: XAUUSD
- **Timeframe**: M1
- **Account type**: Real or Demo (both supported)
- **Minimum balance recommended**: $500+
