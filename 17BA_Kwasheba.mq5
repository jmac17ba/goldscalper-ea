//+------------------------------------------------------------------+
//|                                       17BA_Kwasheba.mq5          |
//|                  Bad Apple 17BA Enterprise — 17BA Kwasheba        |
//|  Kwasheba now shares CHAKKA'S engine: pending-OCO breakout entry  |
//|  + Fibonacci recovery basket — but tuned LESS AGGRESSIVE (fewer    |
//|  levels, wider gap, tighter guard) and MULTI-INSTRUMENT (auto-     |
//|  scales on any non-gold symbol; gold keeps its fixed numbers).     |
//|                                                                    |
//|  Entry: BUY STOP above price (TP up) + SELL STOP below (TP down).  |
//|  Price breaks one way → that leg fills and rides it; the other is  |
//|  cancelled (one-cancels-other). The filled side then runs the      |
//|  recovery basket to its TP or the drawdown guard. Single side only.|
//|                                                                    |
//|  NOTE: her old MA+RSI scalper is backed up at                      |
//|  removed-eas/17BA_Kwasheba_scalper_v2.4_backup.mq5                 |
//+------------------------------------------------------------------+
#property copyright "Bad Apple 17BA Enterprise"
#property link      "https://github.com/jmac17ba/goldscalper-ea"
#property description "17BA Kwasheba — pending-OCO breakout + Fibonacci recovery, multi-instrument"
#property version   "3.00"

#include <Trade\Trade.mqh>
CTrade trade;

//--- Core inputs (LESS AGGRESSIVE than Chakka)
input double InpTPDist      = 0.40;  // Basket TP distance in price units (gold-tuned; auto-scaled off gold)
input double InpRecovGap    = 1.50;  // Gap between recovery levels (wider than Chakka = adds less often)
input int    InpMaxLevels   = 5;     // Max recovery levels (1-12). Tamer than Chakka's 12 → smaller max exposure
input int    InpMagic       = 8000002; // Distinct from Chakka (171717) — never touches Chakka's trades
input int    InpSlippage    = 30;
input bool   InpEnableLogs  = true;

//--- Emergency drawdown guard (tighter than Chakka)
input bool   InpUseGuard    = true;  // Master switch — turn the drawdown guard off completely
input double InpMaxLossPct  = 15.0;  // Emergency-close committed basket at this % of balance floating loss

//--- Auto-scale (per-instrument). Auto-ON for any NON-gold symbol so the
//    distances fit that chart's volatility; gold keeps the fixed numbers.
//    InpAutoScale = force scaling even on gold.
input bool   InpAutoScale   = false; // Force scaling on gold too (non-gold scales automatically)
input int    InpATRPeriod   = 14;    // ATR period used for scaling
input double InpRefATR      = 4.00;  // Reference ATR (price) the fixed distances are tuned at (XAUUSD M15)

//--- Volatility filter — pauses NEW straddles when ATR is elevated vs its
//    recent average (the violent regimes that trap a grid). Baskets unaffected.
input bool   InpUseVolFilter = true;  // Don't OPEN new straddles when volatility is elevated
input double InpMaxATRMult   = 1.8;   // "Elevated" = current ATR > this × its recent average
input int    InpVolLookback  = 100;   // Bars to average ATR over for the volatility baseline

//--- Pending OCO entry. Two STOP orders are SET, not entered: BUY STOP above
//    price (TP up), SELL STOP below (TP down). Price breaks one way → that
//    leg fills and rides it; the other is cancelled immediately.
input double InpEntryGap      = 0.50;  // Distance from price to each pending stop (price units)

//--- Session filter (off by default)
input bool   InpUseSession = false;
input int    InpStartHour  = 1;
input int    InpStopHour   = 23;

//--- Order Block + Liquidity filter (gold microstructure; no-op on forex)
input bool   InpUseOBLQ      = true;
input int    InpOBLookback   = 60;
input double InpOBBodyRatio  = 0.55;
input double InpOBBuffer     = 0.60;
input int    InpLQLookback   = 40;
input int    InpLQSwingLen   = 4;
input double InpLQBuffer     = 0.50;

// Fibonacci recovery lots. With InpMaxLevels=5 only the first 5 are used
// (max single add 0.08) — far tamer than running all 12.
const double FIBLOTS[12] = {0.01, 0.02, 0.03, 0.05, 0.08, 0.13, 0.22, 0.37, 0.59, 0.96, 1.55, 2.51};

// Active direction:  0 = flat  |  1 = long basket  |  -1 = short basket
int g_committed = 0;

int    g_atrHandle = INVALID_HANDLE;
// Effective (possibly auto-scaled) distances — refreshed every tick by UpdateScaling().
double g_tp, g_gap, g_obBuf, g_lqBuf, g_gap_entry;

// Gold keeps its proven fixed numbers; everything else auto-scales so the
// distances fit that instrument's volatility. InpAutoScale can force gold too.
bool IsGoldSymbol() {
   string s = _Symbol;
   StringToUpper(s);
   return (StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0);
}

void UpdateScaling() {
   g_tp = InpTPDist; g_gap = InpRecovGap; g_obBuf = InpOBBuffer; g_lqBuf = InpLQBuffer;
   g_gap_entry = InpEntryGap;
   bool useScale = (InpAutoScale || !IsGoldSymbol());
   if (!useScale || g_atrHandle == INVALID_HANDLE || InpRefATR <= 0) return;
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

// TRUE when current ATR is elevated vs its recent average — only gates NEW entries.
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
// its TP in its own direction (buy up, sell down). Levels are CLAMPED to the
// broker's minimum stop distance so the orders aren't rejected.
void PlaceStraddle(double ask, double bid) {
   double minDist = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) + 1)
                    * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double gap = MathMax(g_gap_entry, minDist);
   double tp  = MathMax(g_tp,        minDist);
   double buyPrice  = NormalizeDouble(ask + gap, _Digits);   // above → BUY STOP
   double sellPrice = NormalizeDouble(bid - gap, _Digits);   // below → SELL STOP
   bool b = trade.BuyStop (FIBLOTS[0], buyPrice,  _Symbol, 0,
                           NormalizeDouble(buyPrice  + tp, _Digits), ORDER_TIME_GTC, 0, "17BA Kwasheba");
   bool s = trade.SellStop(FIBLOTS[0], sellPrice, _Symbol, 0,
                           NormalizeDouble(sellPrice - tp, _Digits), ORDER_TIME_GTC, 0, "17BA Kwasheba");
   if (InpEnableLogs)
      PrintFormat("[17BA Kwasheba] Pending breakout set — BUY STOP %.5f (%s) / SELL STOP %.5f (%s)",
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
      PrintFormat("[17BA Kwasheba] %s basket TP → %.5f (avg %.5f)",
         type == POSITION_TYPE_BUY ? "BUY" : "SELL", tp, avg);
}

void Open(ENUM_ORDER_TYPE orderType, double lots) {
   double price = (orderType == ORDER_TYPE_BUY)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp = (orderType == ORDER_TYPE_BUY) ? price + g_tp : price - g_tp;
   bool ok = trade.PositionOpen(_Symbol, orderType, lots, price, 0, tp, "17BA Kwasheba");
   if (InpEnableLogs && ok)
      PrintFormat("[17BA Kwasheba] Open %s %.2f @ %.5f  TP %.5f",
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
      if (range <= 0) continue;
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
      if (range <= 0) continue;
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
      if (InpEnableLogs) PrintFormat("[17BA Kwasheba] BUY blocked — bearish OB @ %.5f", ob);
      return true;
   }
   double lq = NearestSwingHigh(ask);
   if (lq > 0 && ask >= lq - g_lqBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Kwasheba] BUY blocked — swing high LQ @ %.5f", lq);
      return true;
   }
   return false;
}

bool SellBlocked(double bid) {
   if (!InpUseOBLQ) return false;
   double ob = NearestBullishOB(bid);
   if (ob > 0 && bid <= ob + g_obBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Kwasheba] SELL blocked — bullish OB @ %.5f", ob);
      return true;
   }
   double lq = NearestSwingLow(bid);
   if (lq > 0 && bid <= lq + g_lqBuf) {
      if (InpEnableLogs) PrintFormat("[17BA Kwasheba] SELL blocked — swing low LQ @ %.5f", lq);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//  STATE RECOVERY — rebuild g_committed from live positions.
//+------------------------------------------------------------------+
void RecoverState() {
   int nB = CountPos(POSITION_TYPE_BUY);
   int nS = CountPos(POSITION_TYPE_SELL);

   if (nB == 0 && nS == 0) { g_committed = 0; return; }
   if (nB > 0 && nS == 0) { g_committed = 1;  SetBasketTP(POSITION_TYPE_BUY);  return; }
   if (nS > 0 && nB == 0) { g_committed = -1; SetBasketTP(POSITION_TYPE_SELL); return; }
   if (nB == 1 && nS == 1) { g_committed = 0; return; }

   // Both sides stacked → invalid desync. Flatten and restart fresh.
   if (InpEnableLogs)
      PrintFormat("[17BA Kwasheba] Desync on init (%d BUY / %d SELL) — flattening to restart fresh", nB, nS);
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
      Alert("17BA Kwasheba: InpMaxLevels must be 1-12"); return INIT_PARAMETERS_INCORRECT;
   }
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);
   if ((InpAutoScale || !IsGoldSymbol()) && g_atrHandle == INVALID_HANDLE)
      Print("[17BA Kwasheba] WARN: ATR handle failed — auto-scale falls back to fixed distances");
   UpdateScaling();
   RecoverState();
   bool scaling = (InpAutoScale || !IsGoldSymbol());
   PrintFormat("[17BA Kwasheba] v3.0 pending-breakout — %s  EntryGap=%.5f  MaxLevels=%d  Scale=%s  Guard=%s(%.1f%%)  VolFilter=%s  (state=%d)",
      _Symbol, g_gap_entry, InpMaxLevels, scaling ? "ON(auto)" : "OFF(gold)",
      InpUseGuard ? "ON" : "OFF", InpMaxLossPct,
      InpUseVolFilter ? "ON" : "OFF", g_committed);
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
   if (g_committed != 0 && InpUseGuard && InpMaxLossPct > 0) {
      ENUM_POSITION_TYPE side = (g_committed == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      double maxLoss = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxLossPct / 100.0;
      if (BasketProfit(side) <= -maxLoss) {
         if (InpEnableLogs)
            PrintFormat("[17BA Kwasheba] EMERGENCY close %s basket — loss %.2f exceeded cap %.2f (%.1f%% of balance)",
               side == POSITION_TYPE_BUY ? "BUY" : "SELL", BasketProfit(side), maxLoss, InpMaxLossPct);
         CloseAllOfType(side);
         CancelAllPending();
         g_committed = 0;
         WriteDashboardStatus();
         return;
      }
   }

   // ── STEP 1: One leg filled → cancel the opposite pending (OCO) ─────
   if (g_committed != 0 && nPend > 0) {
      CancelAllPending();
      if (InpEnableLogs) Print("[17BA Kwasheba] Entry filled — opposite pending cancelled");
   }

   // ── STEP 2: Flat → make sure the pending OCO straddle is set ───────
   if (g_committed == 0 && nB == 0 && nS == 0) {
      if (nPend == 0 && !VolElevated()) PlaceStraddle(ask, bid);
      WriteDashboardStatus();
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
   WriteDashboardStatus();
}

//+------------------------------------------------------------------+
//  DASHBOARD — writes JSON to MT5 Common Files for 17BA Command Center
//+------------------------------------------------------------------+
void WriteDashboardStatus() {
   static datetime s_lastWrite = 0;
   if (TimeCurrent() - s_lastWrite < 3) return;
   s_lastWrite = TimeCurrent();

   int nB    = CountPos(POSITION_TYPE_BUY);
   int nS    = CountPos(POSITION_TYPE_SELL);
   int nPend = CountPending();
   bool volEl = VolElevated();

   ENUM_POSITION_TYPE side = (g_committed == 1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double basketPL = (g_committed != 0) ? BasketProfit(side) : 0;
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLoss  = (InpUseGuard && InpMaxLossPct > 0) ? balance * InpMaxLossPct / 100.0 : 1;
   double ddPct    = (g_committed != 0 && basketPL < 0 && maxLoss > 0)
                     ? MathMin(MathAbs(basketPL) / maxLoss * 100.0, 100.0) : 0;

   string st;
   if      (volEl && g_committed == 0)      st = "PAUSED";
   else if (g_committed == 0 && nPend > 0)  st = "WATCHING";
   else if (g_committed == 0)               st = "IDLE";
   else if (g_committed ==  1)              st = "LONG";
   else                                     st = "SHORT";

   int recovLevel = (g_committed == 1) ? nB : (g_committed == -1) ? nS : 0;

   double atrBuf[]; double atrNow = 0;
   if (g_atrHandle != INVALID_HANDLE && CopyBuffer(g_atrHandle, 0, 0, 1, atrBuf) > 0)
      atrNow = atrBuf[0];

   string json = StringFormat(
      "{\"ea\":\"Quasheba\",\"version\":\"3.0\",\"magic\":%d,"
      "\"symbol\":\"%s\",\"timestamp\":\"%s\",\"status\":\"%s\","
      "\"committed\":%d,\"balance\":%.2f,\"equity\":%.2f,"
      "\"floating_pl\":%.2f,\"drawdown_pct\":%.2f,\"guard_pct\":%.1f,"
      "\"atr_current\":%.5f,\"vol_elevated\":%s,"
      "\"bid\":%.5f,\"ask\":%.5f,"
      "\"recovery_level\":%d,\"max_levels\":%d,"
      "\"pending_count\":%d,\"basket_profit\":%.2f}",
      InpMagic, _Symbol,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      st, g_committed, balance, equity, equity - balance,
      ddPct, InpMaxLossPct, atrNow, volEl ? "true" : "false",
      SymbolInfoDouble(_Symbol, SYMBOL_BID),
      SymbolInfoDouble(_Symbol, SYMBOL_ASK),
      recovLevel, InpMaxLevels, nPend, basketPL);

   int fh = FileOpen("17ba_quasheba_status.json",
                     FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if (fh != INVALID_HANDLE) { FileWriteString(fh, json); FileClose(fh); }
}
//+------------------------------------------------------------------+
