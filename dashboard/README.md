# 17BA Bad Apple Command Center

Real-time dashboard for Chakka EA + Quasheba EA. Reads MT5 status files
and serves a Jarvis-style browser dashboard.

## Setup (3 steps)

### Step 1 — Recompile the EAs in MetaEditor
Both EA files now include `WriteDashboardStatus()` which writes a JSON file
to your MT5 Common Files folder every 3 seconds.

In MetaEditor: open each file → F7 to compile → reattach to chart.

Files written to:
```
%APPDATA%\MetaQuotes\Terminal\Common\Files\17ba_chakka_status.json
%APPDATA%\MetaQuotes\Terminal\Common\Files\17ba_quasheba_status.json
```

### Step 2 — Start the server
Python 3 required (already installed on most machines).

**Windows:** double-click `start.bat`

**Mac/Linux/VPS:**
```bash
cd dashboard
python3 server.py
```

The server auto-detects the MT5 Common Files path on Windows.
If it can't find it, set `MT5_PATH_OVERRIDE` at the top of `server.py`.

### Step 3 — Open the dashboard
```
http://localhost:8888
```
Refreshes automatically every 3 seconds.

---

## What You See

**Header:** Server time + scanning line animation

**Stats bar:** Combined balance / equity / floating P&L across both bots

**Chakka card (left):**
- Status dot (green=WATCHING, gold=LONG/SHORT, amber=PAUSED, red=GUARD)
- Balance, equity, float P&L, basket P&L
- Recovery ladder — visual bars for each Fibonacci level (0–12)
- Drawdown arc — fills as drawdown approaches the 20% guard
- ATR reading + ELEVATED warning if vol filter is active
- BID / ASK / pending order count
- Last data timestamp + file age

**Quasheba card (right):** Same layout, terra/amber colours, 5-level ladder, 15% guard

**Activity log:** Detects status changes, recovery level adds, basket closures in real-time

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Both cards show OFFLINE | EAs not running, or MT5 path not found — check console output |
| Cards show STALE | MT5 running but EAs not attached / algo trading disabled |
| Python not found | Install Python 3 from python.org |
| Wrong MT5 path | Set `MT5_PATH_OVERRIDE` in server.py |
| Can't reach localhost:8888 | Check firewall, or change `PORT` in server.py |

## Testing Without MT5 (Mock Mode)
Drop mock JSON files into the same folder as server.py:
```json
{"ea":"Chakka","version":"2.2","magic":171717,"symbol":"XAUUSD",
 "timestamp":"2026-06-19 14:00:00","status":"WATCHING","committed":0,
 "balance":5000,"equity":5000,"floating_pl":0,"drawdown_pct":0,
 "guard_pct":20,"atr_current":12.5,"vol_elevated":false,
 "bid":2350.50,"ask":2350.70,"recovery_level":0,"max_levels":12,
 "pending_count":2,"basket_profit":0}
```
The server will serve them as if MT5 wrote them.
