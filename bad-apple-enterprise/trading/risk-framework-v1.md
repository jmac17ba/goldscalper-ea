# 17BA Bad Apple Enterprise — Trading Division Risk & Performance Framework

**Version**: 1.0 | **Prepared by**: Financial Analyst | **Date**: June 19, 2026
**Scope**: Two-bot automated XAUUSD operation (Chakka EA v2.2 + Quasheba EA v3.0)

---

## STATED ASSUMPTIONS

| Assumption | Value | Source / Basis |
|---|---|---|
| XAUUSD price | $3,300/oz | Current market approximation |
| Standard lot size | 100 troy oz | MT5 XAUUSD contract spec |
| Pip value (1 lot) | ~$1.00 per $0.01 move | Standard broker contract |
| Margin per lot (1:100 leverage) | ~$3,300 | Varies by broker — verify yours |
| Margin per lot (1:500 leverage) | ~$660 | Varies by broker — verify yours |
| ATR reference | ~$20–25/day | XAUUSD historical daily ATR |
| Both bots run on separate MT5 accounts | Yes | Assumed for clean risk isolation |
| Worst-case scenario | All recovery levels hit simultaneously before guard fires | Conservative stress assumption |

**Critical note**: Verify your exact margin requirement with your broker before deploying capital. Some brokers compress gold margins during high-volatility periods. The numbers below use 1:100 leverage as the base case. If running 1:500, adjust but do not reduce buffer ratios.

---

## SECTION 1 — MINIMUM ACCOUNT SIZING

### Total lot exposure at each level

**Chakka EA (12 levels, cumulative):**

| Level | New Lot | Cumulative Open Lots |
|---|---|---|
| 1 | 0.01 | 0.01 |
| 2 | 0.02 | 0.03 |
| 3 | 0.03 | 0.06 |
| 4 | 0.05 | 0.11 |
| 5 | 0.08 | 0.19 |
| 6 | 0.13 | 0.32 |
| 7 | 0.22 | 0.54 |
| 8 | 0.37 | 0.91 |
| 9 | 0.59 | 1.50 |
| 10 | 0.96 | 2.46 |
| 11 | 1.55 | 4.01 |
| 12 | 2.51 | 6.52 |

**Chakka worst-case at full extension (all 12 levels open):**
- Cumulative lots: 6.52
- Margin required (1:100) = 6.52 × $3,300 = **~$21,516**
- Entry gap per level = $22 × 1.20 = $26.40
- Estimated floating drawdown at Level 12: **~$8,500–$10,000**

**Chakka Account Sizing:**

| Component | Amount |
|---|---|
| Margin requirement (6.52 lots at 1:100) | $21,516 |
| Floating drawdown buffer (estimated max) | $10,000 |
| Raw minimum to avoid margin call | $31,516 |
| Safety buffer (1.5×) | $47,274 |
| **Recommended minimum account size** | **$50,000** |
| **Absolute floor (do not run below)** | **$35,000** |

---

**Quasheba EA (5 levels, cumulative):**

| Level | New Lot | Cumulative Open Lots |
|---|---|---|
| 1 | 0.01 | 0.01 |
| 2 | 0.02 | 0.03 |
| 3 | 0.03 | 0.06 |
| 4 | 0.05 | 0.11 |
| 5 | 0.08 | 0.19 |

**Quasheba worst-case at full extension (all 5 levels open):**
- Cumulative lots: 0.19
- Margin required (1:100) = 0.19 × $3,300 = **~$627**
- Entry gap per level = $22 × 1.50 = $33
- Estimated floating drawdown at Level 5: **~$693**

**Quasheba Account Sizing:**

| Component | Amount |
|---|---|
| Margin requirement (0.19 lots at 1:100) | $627 |
| Floating drawdown buffer (estimated max) | $693 |
| Raw minimum to avoid margin call | $1,320 |
| Safety buffer (3×) | $3,960 |
| **Recommended minimum account size** | **$5,000** |
| **Absolute floor (do not run below)** | **$3,000** |

---

## SECTION 2 — CAPITAL ALLOCATION MODEL

### The Formula

Let X = total available trading capital.

**Step 1 — Reserve**
Reserve = max(20% of X, $5,000)

**Step 2 — Deployable Capital**
Deployable Capital (D) = X − Reserve

**Step 3 — Split**
- Chakka Account = 60% of D (never less than $50,000 if running Chakka)
- Quasheba Account = 40% of D (never less than $5,000)

**Step 4 — Hard Override**
If D × 60% < $50,000 → do NOT run Chakka. Run Quasheba only until capital is sufficient.

**Minimum total capital to run BOTH bots safely: ~$70,000**

**Example at $100,000 total:**
- Reserve: $20,000
- Deployable: $80,000
- Chakka: $50,000 (floor applied), Quasheba: $30,000

**Example at $150,000 total:**
- Reserve: $30,000
- Deployable: $120,000
- Chakka: $72,000, Quasheba: $48,000

---

## SECTION 3 — MONTHLY P&L TRACKING TEMPLATE

**Section A: Trade Activity**

| Metric | Chakka EA | Quasheba EA | Combined |
|---|---|---|---|
| Total baskets opened | | | |
| Winning baskets | | | |
| Losing baskets (guard or manual) | | | |
| Win rate (%) | | | |
| Avg recovery levels per basket | | | |
| Max levels reached (worst basket) | | | |
| Guard trigger events | | | |

**Section B: Financial Performance**

| Metric | Chakka EA | Quasheba EA | Combined |
|---|---|---|---|
| Gross profit | | | |
| Gross loss | | | |
| Net trading P&L | | | |
| Swap/rollover costs | | | |
| Net P&L after carry | | | |
| Return on equity (%) | | | |

**Section C: Risk Metrics**

| Metric | Chakka EA | Quasheba EA |
|---|---|---|
| Maximum drawdown this month (%) | | |
| Times drawdown exceeded 10% | | |
| Times drawdown exceeded 15% | | |
| Lowest equity point ($) | | |
| Margin utilization at peak (%) | | |

**Section D: Capital Flow**

| Item | Amount |
|---|---|
| Opening combined equity | |
| Net trading P&L | |
| Transfer to clothing brand | |
| Withdrawal/injection | |
| Closing combined equity | |
| Reserve fund balance | |

---

## SECTION 4 — PERFORMANCE BENCHMARKS

### Normal operating ranges (healthy system):

| Metric | Chakka EA | Quasheba EA |
|---|---|---|
| Monthly net return | 3%–8% | 2%–5% |
| Win rate (basket close) | 80%–90% | 85%–95% |
| Avg levels per basket | 1.5–3.0 | 1.0–2.5 |
| Max drawdown in month | Below 12% | Below 10% |
| Guard triggers per month | 0–1 | 0–1 |
| Swap cost as % of gross profit | Below 10% | Below 8% |

### Warning flags:

**Yellow — Monitor Closely (1 occurrence = data point, 2 in a row = trend):**
- Avg levels per basket above 4 (Chakka) or 3 (Quasheba)
- Win rate below 80% for two consecutive months
- Swap costs exceeding 15% of gross profit
- Any month where max drawdown exceeds 15% (Chakka) or 12% (Quasheba) — even if recovered

**Orange — Pause and Diagnose:**
- Any guard trigger event — reconstruct the basket, understand why it fired
- Three consecutive months of net return below 1%
- Two guard triggers in 30 days on the same bot

**Red — Stop Trading, Emergency Review:**
- Combined monthly drawdown exceeds 20% of total deployed capital
- Guard triggers and equity doesn't recover within 5 business days
- Either account drops below absolute floor ($35,000 Chakka / $3,000 Quasheba)
- Any loss requiring clothing brand funds to recapitalize trading

---

## SECTION 5 — REVENUE ALLOCATION RULE

### "Profit Above High Water Mark, Quarterly Transfer"

**Step 1 — Set High Water Mark (HWM)**
At the start of each quarter, record combined equity. HWM only moves upward.

**Step 2 — Define Transferable Profit**
Transferable = (current equity) − (HWM) − (reserve top-up needed)

**Step 3 — Transfer Limit**
Transfer ≤ 50% of transferable profit to the clothing brand. Retain 50% to compound.

**Step 4 — Minimum Retained Equity**
After any transfer, combined equity must stay at or above 110% of combined account floors.
- Combined floors: $50,000 + $5,000 = $55,000
- 110% = $60,500 minimum post-transfer

**Worked Example:**
- HWM: $120,000 | End-of-quarter equity: $138,000 | Reserve needed: $2,000 top-up
- Transferable: $138,000 − $120,000 − $2,000 = $16,000
- Max transfer to brand: 50% × $16,000 = **$8,000**
- Post-transfer equity: $128,000 — above $60,500 floor ✓

**Additional Rule:**
No transfers during any month where either account triggered the drawdown guard. Wait one full calendar month after the last guard trigger before resuming transfers. Non-negotiable.

---

## SECTION 6 — THE FIVE RED LINES

**Red Line 1: Never run Chakka below $35,000 account equity.**
Below this, a broker margin call can fire before the drawdown guard does. If the broker fires first, you've lost control of the exit. Fund properly or turn Chakka off.

**Red Line 2: Never add external funds to cover a guard-triggered loss.**
Recapitalization must come from the reserve only. Taking money from the clothing brand, personal accounts, or external sources to keep a losing bot running compounds a bad situation into a catastrophic one. If the reserve is depleted, pause both bots and rebuild through profits only.

**Red Line 3: Never disable or override a drawdown guard mid-basket.**
The guard is a pre-commitment device. Overriding it under pressure with a running loss is not risk management — it is gambling with money you have already decided you can't afford to lose.

**Red Line 4: No quarterly transfer when combined equity is below 120% of combined account minimums.**
120% of $55,000 = $66,000. Below this, the brand does not eat. The factory comes first.

**Red Line 5: A single month with losses exceeding 15% of combined deployed capital triggers a mandatory 5-business-day pause.**
During the pause: review every guard-triggered basket, check for regime change, and make a written go/no-go decision before resuming. No written review = no resumption.

---

## QUICK REFERENCE CARD

| Parameter | Chakka EA | Quasheba EA |
|---|---|---|
| Account minimum (recommended) | **$50,000** | **$5,000** |
| Account floor (absolute) | $35,000 | $3,000 |
| Drawdown guard | 20% | 15% |
| Max levels | 12 | 5 |
| Max cumulative lots | 6.52 | 0.19 |
| Estimated max margin (1:100) | ~$21,500 | ~$630 |
| Estimated max floating DD | ~$9,000 | ~$700 |
| Transfer pause after guard trigger | 30 calendar days | 30 calendar days |

**Total minimum to run both safely: $70,000**
**Capital formula: Reserve = max(20% of X, $5,000). Chakka = 60% of remainder (min $50K). Quasheba = 40% (min $5K).**
**Transfer rule: Quarterly, 50% of profit above HWM, only if post-transfer equity ≥ $60,500.**

---

*Prepared by Financial Analyst — Trading Division, 17BA Bad Apple Enterprise.*
*Review quarterly or after any red line event. Version-controlled in goldscalper-ea repo.*
