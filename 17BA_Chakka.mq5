//+------------------------------------------------------------------+
//|                                         17BA_Chakka.mq5          |
//|                  Bad Apple 17BA Enterprise — 17BA Chakka          |
//|  Reverse-engineered from account 600001050 trade history.        |
//|  v1.3: Exclusive mode — once one side enters recovery, the       |
//|         other side closes immediately. Fresh straddle only       |
//|         opens after the committed side hits basket TP.           |
//|  v1.4: OnInit rebuilds commit state from open positions instead  |
//|         of resetting to 0 (fixes restart/recompile desync where  |
//|         both sides ended up stacked). On a both-sides-stacked    |
//|         desync it flattens and restarts fresh.                   |
//|  v1.5: Emergency drawdown guard — committed basket is cut once    |
//|         its floating loss exceeds InpMaxLossPct of balance.       |
//|  v1.6: ATR auto-scaling (InpAutoScale) makes the gold-tuned       |
//|         distances adapt to any instrument's volatility, and a     |
//|         master InpUseGuard switch to disable the guard entirely.  |
//|  v1.7: Recovery ladder extended to 12 levels (InpMaxLevels max     |
//|         12) for deeper averaging on big retracements. Bigger size  |
//|         at deep levels — keep the drawdown guard on.               |
//|  v1.8: Volatility filter (InpUseVolFilter) — pauses NEW straddles   |
//|         when ATR is elevated vs its average (the violent regimes    |
//|         that stack a grid to blow-up). Existing baskets unaffected. |
//|  v2.0: DROPPED the hedged straddle (BUY+SELL together cancelled out  |
//|         and bled spread).                                            |
//|  v2.1: Pending OCO entry — two levels SET, not entered; first fill   |
//|         cancels the other. (v2.1 used limits = fade.)                |
//|  v2.2: Flipped to STOP orders (breakout) so each leg points its own  |
//|         way like the original: BUY STOP above (TP up), SELL STOP      |
//|         below (TP down). Price breaks one way → that leg fills and    |
//|         rides it; the other cancels. Single side then runs the        |
//|         Fibonacci recovery basket to TP or the drawdown guard.        |
//+------------------------------------------------------------------+
#property copyright "Bad Apple 17BA Enterprise"
#property link      "https://github.com/jmac17ba/goldscalper-ea"
#property description "17BA Chakka — XAUUSD pending-OCO breakout + Fibonacci recovery EA"
#property version   "2.20"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Core inputs
input double InpTPDist      = 0.40;  // TP distance in price units (gold-tuned; auto-scaled if InpAutoScale)
input double InpRecovGap    = 1.20;  // Gap between recovery levels (gold-tuned; auto-scaled if InpAutoScale)
input int    InpMaxLevels   = 12;    // Max recovery levels (1-12). More levels = deeper averaging but much bigger risk
input int    InpMagic       = 171717;
input int    InpSlippage    = 30;
input bool   InpEnableLogs  = true;

//--- Emergency drawdown guard
input bool   InpUseGuard    = true;  // Master switch — turn the drawdown guard off completely
input double InpMaxLossPct  = 20.0;  // Emergency-close committed basket at this % of balance floating loss

//--- Auto-scale (per-instrument). OFF = use the gold-tuned distances as-is.
//    ON = scale all distances by (current ATR / InpRefATR) so they fit any chart's volatility.
input bool   InpAutoScale   = false; // Turn ON when running on non-gold instruments
input int    InpATRPeriod   = 14;    // ATR period used for scaling
input double InpRefATR      = 4.00;  // Reference ATR (price) the fixed distances are tuned at (XAUUSD M15)

//--- Volatility filter. Evidence (Markov study): violent/high-ATR regimes precede
//    ~2x bigger one-way moves — the conditions that stack a grid to blow-up. When ON,
//    NEW straddles are paused while ATR is elevated; existing baskets keep recovering.
input bool   InpUseVolFilter = true;  // Don't OPEN new straddles when volatility is elevated
input double InpMaxATRMult   = 1.8;   // "Elevated" = current ATR > this × its recent average
input int    InpVolLookback  = 100;   // Bars to average ATR over for the volatility baseline

//--- Pending OCO entry. Instead of a live hedged straddle (the two legs
//    cancel out + bleed spread), Chakka SETS two pending STOP orders around
//    price, each pointing its own way like the original bot's legs:
//    BUY STOP above price (TP further up), SELL STOP below (TP further down).
//    Price breaks one way → that order fills and rides the move; the other
//    is cancelled immediately (one-cancels-other). Breakout / momentum entry.
input double InpEntryGap      = 0.50;  // Distance from price to each pending stop (price units)

//--- Session filter (live data shows 24/5 — off by default)
input bool   InpUseSession = false;
input int    InpStartHour  = 1;
input int    InpStopHour   = 23;

//--- Order Block + Liquidity filter
input bool   InpUseOBLQ      = true;
input int    InpOBLookback   = 60;
input double InpOBBodyRatio  = 0.55;
input double InpOBBuffer     = 0.60;
input int    InpLQLookback   = 40;
input int    InpLQSwingLen   = 4;
input double InpLQBuffer     = 0.50;

// Fibonacci recovery lots, extended to 12 levels. Deeper levels grow fast — the
// last few add real size, so keep the drawdown guard on when running many levels.
const double FIBLOTS[12] = {0.01, 0.02, 0.03, 0.05, 0.08, 0.13, 0.22, 0.37, 0.59, 0.96, 1.55, 2.51};

// Active direction:  0 = flat  |  1 = long basket  |  -1 = short basket
int g_committed = 0;

int    g_atrHandle = INVALID_HANDLE;
// Effective (possibly auto-scaled) distances — refreshed every tick by UpdateScaling().
double g_tp, g_gap, g_obBuf, g_lqBuf, g_gap_entry;

void UpdateScaling() {
   g_tp = InpTPDist; g_gap = InpRecovGap; g_obBuf = InpOBBuffer; g_lqBuf = InpLQBuffer;
   g_gap_entry = InpEntryGap;
   if (!InpAutoScale || g_atrHandle == INVALID_HANDLE || InpRefATR <= 0) return;
   double atr[];
   if (CopyBuffer(g_atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0) {
      double scale = atr[0] / InpRefATR;
      g_tp        = InpTPDist    * scale;
      g_gap       = InpRecovGap  * scale;
      g_obBuf     = InpOBBuffer  * scale;
      g_lqBuf     = InpLQBuffer  * scale;
      g_gap_entry = InpEntryGap  * scale;
   }
}

// TRUE when current ATR is elevated vs its recent average — i.e. a violent regime
// where new grids are most likely to get trapped. Only gates NEW straddle entries.
bool VolElevated() {
   if (!InpUseVolFilter || g_atrHandle == INVALID_HANDLE) return false;
   double atr[];
   if (CopyBuffer(g_atrHandle, 0, 0, InpVolLookback, atr) < InpVolLookback) return false;
   double sum = 0;
   for (int i = 0; i < InpVolLookback; i++) sum += atr[i];
   double avg = sum / InpVolLookback;
   return (avg > 0 && atr[0] > InpMaxATRMult * avg);
}

//+------------------------------------------------------------------+
//  PENDING ORDER HELPERS (the OCO entry straddle)
//+------------------------------------------------------------------+
int CountPending() {
   int n = 0;
   for (int i = OrdersTotal()-1; i >= 0; i--) {
      ulong t = OrderGetTicket(i);
      if (t == 0 || !OrderSelect(t)) continue;
      if (OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      n++;
   }
   return n;
}

void CancelAllPending() {
   for (int i = OrdersTotal()-1; i >= 0; i--) {
      ulong t = OrderGetTicket(i);
      if (t == 0 || !OrderSelect(t)) continue;
      if (OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      trade.OrderDelete(t);
   }
}

// Set the two OCO stops: BUY STOP above price, SELL STOP below — each with
// its TP in its own direction (buy up, sell down), like the original legs.
// Levels are CLAMPED to the broker's minimum stop distance so the orders
// aren't rejected for sitting too close to price.
void PlaceStraddle(double ask, double bid) {
   double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1)
                    * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double gap = MathMax(g_gap_entry, minDist);
   double tp  = MathMax(g_tp,        minDist);
   double buyPrice  = NormalizeDouble(ask + gap, _Digits);   // above → BUY STOP
   double sellPrice = NormalizeDouble(bid - gap, _Digits);   // below → SELL STOP
   bool b = trade.BuyStop (FIBLOTS[0], buyPrice,  _Symbol, 0,
                           NormalizeDouble(buyPrice  + tp, _Digits), ORDER_TIME_GTC, 0, "17BA Chakka");
   bool s = trade.SellStop(FIBLOTS[0], sellPrice, _Symbol, 0,
                           NormalizeDouble(sellPrice - tp, _Digits), ORDER_TIME_GTC, 0, "17BA Chakka");
   if (InpEnableLogs)
      PrintFormat("[17BA Chakka] Pending breakout set — BUY STOP %.2f (%s) / SELL STOP %.2f (%s)",
         buyPrice, b ? "ok" : "FAIL", sellPrice, s ? "ok" : "FAIL");
}

//+------------------------------------------------------------------+
int CountPos(ENUM_POSITION_TYPE type) {
   int n = 0;
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type) n++;
   }
   return n;
}

double AvgEntry(ENUM_POSITION_TYPE type) {
   double sumLots = 0, sumVal = 0;
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
      double lots = PositionGetDouble(POSITION_VOLUME);
      sumLots += lots;
      sumVal  += lots * PositionGetDouble(POSITION_PRICE_OPEN);
   }
   return sumLots > 0 ? sumVal / sumLots : 0;
}

double BasketProfit(ENUM_POSITION_TYPE type) {
   double p = 0;
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

double LastEntry(ENUM_POSITION_TYPE type) {
   double   price = 0;
   datetime lastT = 0;
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if (t >= lastT) { lastT = t; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
}

void SetBasketTP(ENUM_POSITION_TYPE type) {
   double avg = AvgEntry(type);
   if (avg == 0) return;
   double tp = (type == POSITION_TYPE_BUY) ? avg + g_tp : avg - g_tp;
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      ulong ticket = PositionGetTicket(i);
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
      trade.PositionModify(ticket, 0, tp);
   }
   if (InpEnableLogs)
      PrintFormat("[17BA Chakka] %s basket TP → %.2f (avg %.2f)",
         type == POSITION_TYPE_BUY ? "BUY" : "SELL", tp, avg);
}

void Open(ENUM_ORDER_TYPE orderType, double lots) {
   double price = (orderType == ORDER_TYPE_BUY)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = (orderType == ORDER_TYPE_BUY) ? price + g_tp : price - g_tp;
   bool ok = trade.PositionOpen(_Symbol, orderType, lots, price, 0, tp, "17BA Chakka");
   if (InpEnableLogs && ok)
      PrintFormat("[17BA Chakka] Open %s %.2f @ %.2f  TP %.2f",
         orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", lots, price, tp);
}

void CloseAllOfType(ENUM_POSITION_TYPE type) {
   for (int i = PositionsTotal()-1; i >= 0; i--) {
      if (!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == type)
         trade.PositionClose(PositionGetTicket(i));
   }
}

//+------------------------------------------------------------------+
//  ORDER BLOCK DETECTION
//+------------------------------------------------------------------+
double NearestBearishOB(double refPrice) {
   for (int i = 2; i < InpOBLookback - 2; i++) {
      double o = iOpen(_Symbol,0,i), c = iClose(_Symbol,0,i);
      double hi = iHigh(_Symbol,0,i), lo = iLow(_Symbol,0,i);
      double range = hi - lo;
      if (range < 0.01) continue;
      if (c > o && (c-o)/range >= InpOBBodyRatio
         && (iClose(_Symbol,0,i-1) < iOpen(_Symbol,0,i-1)
          || iClose(_Symbol,0,i+1) < iOpen(_Symbol,0,i+1))
         && hi > refPrice) return hi;
   }
   return 0;
}

double NearestBullishOB(double refPrice) {
   for (int i = 2; i < InpOBLookback - 2; i++) {
      double o = iOpen(_Symbol,0,i), c = iClose(_Symbol,0,i);
      double hi = iHigh(_Symbol,0,i), lo = iLow(_Symbol,0,i);
      double range = hi - lo;
      if (range < 0.01) continue;
      if (c < o && (o-c)/range >= InpOBBodyRatio
         && (iClose(_Symbol,0,i-1) > iOpen(_Symbol,0,i-1)
          || iClose(_Symbol,0,i+1) > iOpen(_Symbol,0,i+1))
         && lo < refPrice) return lo;
   }
   return 0;
}

//+------------------------------------------------------------------+
//  LIQUIDITY DETECTION
//+------------------------------------------------------------------+
double NearestSwingHigh(double refPrice) {
   int limit = InpLQLookback - InpLQSwingLen;
   for (int i = InpLQSwingLen; i < limit; i++) {
      double hi = iHigh(_Symbol,0,i);
      if (hi <= refPrice) continue;
      bool isSwing = true;
      for (int j = 1; j <= InpLQSwingLen && isSwing; j++)
         if (iHigh(_Symbol,0,i-j) >= hi || iHigh(_Symbol,0,i+j) >= hi) isSwing = false;
      if (isSwing) return hi;
   }
   return 0;
}

double NearestSwingLow(double refPrice) {
   int limit = InpLQLookback - InpLQSwingLen;
   for (int i = InpLQSwingLen; i < limit; i++) {
      double lo = iLow(_Symbol,0,i);
      if (lo >= refPrice) continue;
      bool isSwing = true;
      for (int j = 1; j <= InpLQSwingLen && isSwing; j++)
         if (iLow(_Symbol,0,i-j) <= lo || iLow(_Symbol,0,i+j) <= lo) isSwing = false;
      if (isSwing) return lo;
   }
   return 0;
}

bool BuyBlocked(double ask) {
   if (!InpUseOBLQ) return false;
   double ob = NearestBearishOB(ask);
   if (ob > 0 && ask >= ob - g_obBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Chakka] BUY blocked — bearish OB @ %.2f", ob);
      return true;
   }
   double lq = NearestSwingHigh(ask);
   if (lq > 0 && ask >= lq - g_lqBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Chakka] BUY blocked — swing high LQ @ %.2f", lq);
      return true;
   }
   return false;
}

bool SellBlocked(double bid) {
   if (!InpUseOBLQ) return false;
   double ob = NearestBullishOB(bid);
   if (ob > 0 && bid <= ob + g_obBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Chakka] SELL blocked — bullish OB @ %.2f", ob);
      return true;
   }
   double lq = NearestSwingLow(bid);
   if (lq > 0 && bid <= lq + g_lqBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Chakka] SELL blocked — swing low LQ @ %.2f", lq);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//  STATE RECOVERY — rebuild g_committed from live positions.
//  g_committed lives only in memory, so any reinit (restart, recompile,
//  timeframe/symbol change, VPS reconnect) would otherwise reset it to 0
//  while a basket is still open — desyncing into both-sides-stacked.
//+------------------------------------------------------------------+
void RecoverState() {
   int nB = CountPos(POSITION_TYPE_BUY);
   int nS = CountPos(POSITION_TYPE_SELL);

   // Flat → fresh.
   if (nB == 0 && nS == 0) { g_committed = 0; return; }

   // One side only → that side is the committed basket. Re-assert its TP.
   if (nB > 0 && nS == 0) { g_committed = 1;  SetBasketTP(POSITION_TYPE_BUY);  return; }
   if (nS > 0 && nB == 0) { g_committed = -1; SetBasketTP(POSITION_TYPE_SELL); return; }

   // Exactly one each → genuine fresh straddle.
   if (nB == 1 && nS == 1) { g_committed = 0; return; }

   // Both sides stacked → invalid desync. Flatten and restart fresh.
   if (InpEnableLogs)
      PrintFormat("[17BA Chakka] Desync on init (%d BUY / %d SELL) — flattening to restart fresh", nB, nS);
   CloseAllOfType(POSITION_TYPE_BUY);
   CloseAllOfType(POSITION_TYPE_SELL);
   g_committed = 0;
}

//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   if (InpMaxLevels < 1 || InpMaxLevels > 12) {
      Alert("17BA Chakka: InpMaxLevels must be 1-12"); return INIT_PARAMETERS_INCORRECT;
   }
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if (InpAutoScale && g_atrHandle == INVALID_HANDLE)
      Print("[17BA Chakka] WARN: ATR handle failed — auto-scale falls back to fixed distances");
   UpdateScaling();
   RecoverState();
   PrintFormat("[17BA Chakka] v2.2 pending-breakout — EntryGap=%.2f  MaxLevels=%d  OB/LQ=%s  Guard=%s(%.1f%%)  VolFilter=%s  AutoScale=%s  (state=%d)",
      InpEntryGap, InpMaxLevels, InpUseOBLQ ? "ON" : "OFF",
      InpUseGuard ? "ON" : "OFF", InpMaxLossPct,
      InpUseVolFilter ? "ON" : "OFF", InpAutoScale ? "ON" : "OFF", g_committed);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
   if (g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
}

//+------------------------------------------------------------------+
void OnTick() {
   if (InpUseSession) {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if (dt.hour < InpStartHour || dt.hour >= InpStopHour) return;
   }

   UpdateScaling();

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int nB = CountPos(POSITION_TYPE_BUY);
   int nS = CountPos(POSITION_TYPE_SELL);
   int nPend = CountPending();
   g_committed = (nB > 0) ? 1 : (nS > 0) ? -1 : 0;

   // ── STEP 0: Emergency drawdown guard ──────────────────────────────
   // Once the active basket's floating loss exceeds InpMaxLossPct of
   // balance, cut it and go flat (and clear any leftover pending).
   if (g_committed != 0 && InpUseGuard && InpMaxLossPct > 0) {
      ENUM_POSITION_TYPE side = (g_committed == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      double maxLoss = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxLossPct / 100.0;
      if (BasketProfit(side) <= -maxLoss) {
         if (InpEnableLogs)
            PrintFormat("[17BA Chakka] EMERGENCY close %s basket — loss %.2f exceeded cap %.2f (%.1f%% of balance)",
               side == POSITION_TYPE_BUY ? "BUY" : "SELL", BasketProfit(side), maxLoss, InpMaxLossPct);
         CloseAllOfType(side);
         CancelAllPending();
         g_committed = 0;
         return;
      }
   }

   // ── STEP 1: One leg filled → cancel the opposite pending (OCO) ─────
   if (g_committed != 0 && nPend > 0) {
      CancelAllPending();
      if (InpEnableLogs) Print("[17BA Chakka] Entry filled — opposite pending cancelled");
   }

   // ── STEP 2: Flat → make sure the pending OCO straddle is set ───────
   // Both levels are SET, not entered. The market fills whichever it
   // reaches first; STEP 1 then cancels the other. Nothing is hedged.
   if (g_committed == 0 && nB == 0 && nS == 0) {
      if (nPend == 0 && !VolElevated()) PlaceStraddle(ask, bid);
      return;
   }

   // ── STEP 3: Recovery — add to the active basket on an adverse move ─
   if (nB > 0 && nB < InpMaxLevels) {
      if (ask <= LastEntry(POSITION_TYPE_BUY) - g_gap && !BuyBlocked(ask)) {
         Open(ORDER_TYPE_BUY, FIBLOTS[nB]);
         SetBasketTP(POSITION_TYPE_BUY);
      }
   } else if (nS > 0 && nS < InpMaxLevels) {
      if (bid >= LastEntry(POSITION_TYPE_SELL) + g_gap && !SellBlocked(bid)) {
         Open(ORDER_TYPE_SELL, FIBLOTS[nS]);
         SetBasketTP(POSITION_TYPE_SELL);
      }
   }
}
//+------------------------------------------------------------------+
