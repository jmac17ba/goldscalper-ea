# The Bots — Overview
**Bad Apple Enterprise | Branch: The Bots**

The bots are the engine. They run on MetaTrader 5, trade XAUUSD (gold), and generate
the income that funds every other branch of the ecosystem.

Bot purchase = member status. Member status = access to clothing drops.
The loop is intentional.

---

## The Two EAs

| | Chakka EA | Quasheba EA |
|---|---|---|
| Version | v2.2 | v3.0 |
| Character | Chakka — The Grind | Quasheba — The Legacy |
| File | `17BA_Chakka.mq5` | `17BA_Kwasheba.mq5` |
| Magic Number | 171717 | 8000002 |
| Primary Instrument | XAUUSD (Gold) | XAUUSD (Gold) |
| Strategy | Pending-OCO Breakout + Fibonacci Recovery | Pending-OCO Breakout + Fibonacci Recovery |
| Risk Profile | Aggressive | Disciplined |
| Max Recovery Levels | 12 | 5 |
| Drawdown Guard | 20% of balance | 15% of balance |
| Straddle Gap | 1.20× ATR | 1.50× ATR |
| Price | $297 | $197 |
| Bundle (Both) | $397 | — |

---

## The Strategy — How It Works

### Step 1 — Pending-OCO Breakout (The Setup)
Two STOP orders are placed simultaneously:
- **BUY STOP** above current price (expects breakout upward)
- **SELL STOP** below current price (expects breakout downward)

Distance from price = `Gap × ATR` (auto-scales to volatility).
First order to fill **cancels the other** (OCO = One Cancels Other).
This catches the move without predicting direction.

### Step 2 — Fibonacci Recovery Basket (The Recovery)
If the first trade moves against us, recovery positions are added at increasing lot sizes:

**Chakka basket (12 levels):**
`{0.01, 0.02, 0.03, 0.05, 0.08, 0.13, 0.22, 0.37, 0.59, 0.96, 1.55, 2.51}`

**Quasheba basket (5 levels):**
`{0.01, 0.02, 0.03, 0.05, 0.08}`

Lot sizes follow the Fibonacci sequence — each level recovers all previous losses
when price returns to the average entry. Quasheba uses fewer levels = less exposure.

### Step 3 — Drawdown Guard (The Protection)
If total floating loss exceeds the threshold (20% for Chakka, 15% for Quasheba),
the entire basket closes immediately. Stops the bleeding. Resets.

### Step 4 — Filters (What Keeps It Off)

| Filter | What It Does |
|---|---|
| ATR Volatility Filter | Pauses new straddles when market is too wild (ATR > MaxATRMult × avg ATR) |
| Order Block Detection | Skips entries near key institutional price levels |
| Liquidity Detection | Avoids stacking into areas where liquidity could trap entries |
| State Recovery | On restart/reinit, rebuilds active positions from live trades automatically |

---

## ATR Auto-Scaling

Both EAs are tuned for gold (XAUUSD) but automatically scale to any instrument
using Average True Range. The distances, SL, and TP all adapt proportionally.
Run it on anything with sufficient volatility — the math adjusts itself.

---

## Membership Mechanic

| Tier | How to Get It | What It Unlocks |
|---|---|---|
| Silver | Buy Quasheba EA ($197) | Quasheba Collection drops |
| Gold | Buy Chakka EA ($297) | Chakka Collection drops |
| Platinum | Buy both / Bundle ($397) | All drops + Academy access |

NFC/QR tag in every limited garment verifies membership status on scan.
No chip = no authentication = counterfeit.

---

## Files in This Repo

| File | Description |
|---|---|
| `17BA_Chakka.mq5` | Chakka EA source code — MQL5 |
| `17BA_Kwasheba.mq5` | Quasheba EA source code — MQL5 |
| `removed-eas/17BA_Kwasheba_scalper_v2.4_backup.mq5` | Old MA+RSI scalper (backup, not in use) |

See `bots/chakka-ea.md` and `bots/quasheba-ea.md` for full technical specs.
