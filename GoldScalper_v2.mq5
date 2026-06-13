//+------------------------------------------------------------------+
//|  GoldScalper v2.0 — FixedVol80-Style M1 Ultra Scalper           |
//|  Reverse-engineered from: Abang Rimba 600001050 REAL report      |
//|  Profile: 7274 trades/week | 66% win | 1-min hold | 0.80 lot    |
//|  WARNING: Max drawdown on original = 55%. Use demo first.        |
//+------------------------------------------------------------------+
#property copyright "GoldScalper v2.0"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//──────────────────────────────────────────────────────────────────
//  INPUTS
//──────────────────────────────────────────────────────────────────

input group "== Core Settings =="
input double FixedLot         = 0.80;    // Fixed lot (original uses 0.80)
input int    TakeProfit       = 8;       // TP in points (~6-8pts reverse-engineered)
input int    StopLoss         = 14;      // SL in points (~13-15pts reverse-engineered)
input int    MagicNumber      = 8000001; // EA magic number
input int    Slippage         = 10;      // Slippage tolerance

input group "== Frequency Control =="
input int    MaxOpenTrades    = 5;       // Simultaneous positions (original: high load)
input int    TradeGapSeconds  = 15;      // Min seconds between new trades
input bool   TradeWeekends    = false;   // Skip Saturday/Sunday

input group "== Recovery (Grid) =="
input bool   UseRecovery      = true;    // Enable grid recovery on loss
input double RecoveryMultiply = 1.5;     // Lot multiplier on recovery trade
input int    RecoveryDistance = 10;      // Points away to place recovery order
input int    MaxRecoveryLevel = 4;       // Max recovery layers (safety cap)

input group "== Risk Management =="
input double MaxDrawdownPct   = 55.0;    // Match original (55%). Lower for safety!
input double MaxDailyLossPct  = 15.0;   // Daily loss % cap
input bool   UseBreakeven     = true;   // Breakeven at profit
input int    BreakevenTrigger = 5;      // Points to trigger breakeven
input bool   UseTrailingStop  = true;   // Trailing stop
input int    TrailStart       = 6;      // Points profit to start trailing
input int    TrailStep        = 2;      // Trail step points

input group "== Entry Filters =="
input bool   UseSpreadFilter  = true;   // Spread gate
input int    MaxSpread        = 20;     // Max spread (tight for M1 scalp)
input int    RSI_Period       = 7;      // RSI period (fast for M1)
input double RSI_OB           = 72.0;   // Overbought threshold
input double RSI_OS           = 28.0;   // Oversold threshold
input int    FastMA           = 3;      // Fast MA (very short for M1)
input int    SlowMA           = 8;      // Slow MA

//──────────────────────────────────────────────────────────────────
//  GLOBALS
//──────────────────────────────────────────────────────────────────

CTrade        trade;
CPositionInfo posInfo;
CAccountInfo  account;

int    hFastMA, hSlowMA, hRSI;
double g_dayStartBalance = 0;
datetime g_lastDayReset  = 0;
datetime g_lastTradeTime = 0;

// Stats
int    g_totalTrades = 0, g_wins = 0, g_losses = 0;
double g_grossProfit = 0, g_grossLoss = 0;

enum SIGNAL { SIG_NONE, SIG_BUY, SIG_SELL };

//──────────────────────────────────────────────────────────────────
//  INIT
//──────────────────────────────────────────────────────────────────

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // M1 indicators — fast periods to match 1-min scalp profile
   hFastMA = iMA(_Symbol, PERIOD_M1, FastMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowMA = iMA(_Symbol, PERIOD_M1, SlowMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);

   if (hFastMA == INVALID_HANDLE || hSlowMA == INVALID_HANDLE || hRSI == INVALID_HANDLE)
   { Print("ERROR: Indicator init failed"); return INIT_FAILED; }

   g_dayStartBalance = account.Balance();
   g_lastDayReset    = iTime(_Symbol, PERIOD_D1, 0);

   Print("GoldScalper v2.0 | TP:", TakeProfit, "pts | SL:", StopLoss,
         "pts | Lot:", FixedLot, " | Recovery:", UseRecovery);
   return INIT_SUCCEEDED;
}

//──────────────────────────────────────────────────────────────────
//  DEINIT
//──────────────────────────────────────────────────────────────────

void OnDeinit(const int reason)
{
   IndicatorRelease(hFastMA);
   IndicatorRelease(hSlowMA);
   IndicatorRelease(hRSI);

   double wr = (g_totalTrades > 0) ? (double)g_wins / g_totalTrades * 100 : 0;
   double pf = (g_grossLoss  != 0) ? g_grossProfit / MathAbs(g_grossLoss) : 0;
   Print("=== v2.0 Session | Trades:", g_totalTrades,
         " WR:", DoubleToString(wr,1), "%",
         " PF:", DoubleToString(pf,2),
         " Net:", DoubleToString(g_grossProfit + g_grossLoss, 2));
}

//──────────────────────────────────────────────────────────────────
//  TICK — fires on every price change (no new-bar wait for M1 scalp)
//──────────────────────────────────────────────────────────────────

void OnTick()
{
   ResetDaily();
   if (!PassFilters()) return;
   ManagePositions();

   // Trade gap — prevent spam
   if (TimeCurrent() - g_lastTradeTime < TradeGapSeconds) return;
   if (CountMagicPositions() >= MaxOpenTrades) return;

   SIGNAL sig = GetSignal();
   if (sig == SIG_BUY)  { OpenTrade(ORDER_TYPE_BUY,  FixedLot); g_lastTradeTime = TimeCurrent(); }
   if (sig == SIG_SELL) { OpenTrade(ORDER_TYPE_SELL, FixedLot); g_lastTradeTime = TimeCurrent(); }
}

//──────────────────────────────────────────────────────────────────
//  SIGNAL — M1 fast MA cross + RSI confirmation
//  Negative R:R (small TP / larger SL) → needs 66%+ win rate
//  Entry on ANY micro-trend impulse, RSI avoids extremes
//──────────────────────────────────────────────────────────────────

SIGNAL GetSignal()
{
   double fast[2], slow[2], rsi[1];
   if (CopyBuffer(hFastMA, 0, 0, 2, fast) < 2) return SIG_NONE;
   if (CopyBuffer(hSlowMA, 0, 0, 2, slow) < 2) return SIG_NONE;
   if (CopyBuffer(hRSI,    0, 0, 1, rsi)  < 1) return SIG_NONE;

   // Cross on current vs previous bar
   bool crossUp   = (fast[1] < slow[1]) && (fast[0] > slow[0]);
   bool crossDown = (fast[1] > slow[1]) && (fast[0] < slow[0]);

   // RSI confirms momentum, avoids chasing exhaustion
   if (crossUp   && rsi[0] > 35 && rsi[0] < RSI_OB) return SIG_BUY;
   if (crossDown && rsi[0] < 65 && rsi[0] > RSI_OS) return SIG_SELL;
   return SIG_NONE;
}

//──────────────────────────────────────────────────────────────────
//  OPEN TRADE
//──────────────────────────────────────────────────────────────────

void OpenTrade(ENUM_ORDER_TYPE type, double lot)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry, sl, tp;

   if (type == ORDER_TYPE_BUY)
   {
      entry = ask;
      sl    = NormalizeDouble(entry - StopLoss   * point, _Digits);
      tp    = NormalizeDouble(entry + TakeProfit * point, _Digits);
   }
   else
   {
      entry = bid;
      sl    = NormalizeDouble(entry + StopLoss   * point, _Digits);
      tp    = NormalizeDouble(entry - TakeProfit * point, _Digits);
   }

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));

   bool ok = (type == ORDER_TYPE_BUY)
      ? trade.Buy(lot, _Symbol, entry, sl, tp, "GS2_B")
      : trade.Sell(lot, _Symbol, entry, sl, tp, "GS2_S");

   if (!ok) Print("Open FAIL | ", trade.ResultRetcode(), " err:", GetLastError());
}

//──────────────────────────────────────────────────────────────────
//  MANAGE POSITIONS — breakeven, trail, recovery grid
//──────────────────────────────────────────────────────────────────

void ManagePositions()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;

      ulong  ticket    = posInfo.Ticket();
      double openPrice = posInfo.PriceOpen();
      double curSL     = posInfo.StopLoss();
      double curTP     = posInfo.TakeProfit();
      string comment   = posInfo.Comment();

      if (posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         double pts = (bid - openPrice) / point;
         if (UseBreakeven && pts >= BreakevenTrigger)
         {
            double beSL = NormalizeDouble(openPrice + point, _Digits);
            if (curSL < beSL) trade.PositionModify(ticket, beSL, curTP);
         }
         if (UseTrailingStop && pts >= TrailStart)
         {
            double tSL = NormalizeDouble(bid - TrailStep * point, _Digits);
            if (tSL > curSL) trade.PositionModify(ticket, tSL, curTP);
         }
      }
      else
      {
         double pts = (openPrice - ask) / point;
         if (UseBreakeven && pts >= BreakevenTrigger)
         {
            double beSL = NormalizeDouble(openPrice - point, _Digits);
            if (curSL > beSL || curSL == 0) trade.PositionModify(ticket, beSL, curTP);
         }
         if (UseTrailingStop && pts >= TrailStart)
         {
            double tSL = NormalizeDouble(ask + TrailStep * point, _Digits);
            if (tSL < curSL || curSL == 0) trade.PositionModify(ticket, tSL, curTP);
         }
      }
   }
}

//──────────────────────────────────────────────────────────────────
//  RECOVERY GRID — places a larger recovery trade when position
//  moves against us by RecoveryDistance points.
//  This is what drives the high trade frequency + 55% drawdown.
//──────────────────────────────────────────────────────────────────

void CheckRecovery()
{
   if (!UseRecovery) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;

      string comment  = posInfo.Comment();
      int    level    = GetRecoveryLevel(comment);
      if (level >= MaxRecoveryLevel) continue;

      double openPrice = posInfo.PriceOpen();
      double lossPoints;
      ENUM_ORDER_TYPE recovType;

      if (posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         lossPoints = (openPrice - bid) / point;
         recovType  = ORDER_TYPE_BUY;
      }
      else
      {
         lossPoints = (ask - openPrice) / point;
         recovType  = ORDER_TYPE_SELL;
      }

      if (lossPoints >= RecoveryDistance)
      {
         double recovLot = NormalizeDouble(posInfo.Volume() * RecoveryMultiply, 2);
         double minLot   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         recovLot = MathMax(minLot, recovLot);

         // Add recovery tag to distinguish levels
         string tag = (recovType == ORDER_TYPE_BUY) ? "GS2_RB_" : "GS2_RS_";
         tag += IntegerToString(level + 1);

         double entry = (recovType == ORDER_TYPE_BUY) ? ask : bid;
         double sl, tp;
         if (recovType == ORDER_TYPE_BUY)
         {
            sl = NormalizeDouble(entry - StopLoss   * point * (level + 2), _Digits);
            tp = NormalizeDouble(entry + TakeProfit * point, _Digits);
            trade.Buy(recovLot, _Symbol, entry, sl, tp, tag);
         }
         else
         {
            sl = NormalizeDouble(entry + StopLoss   * point * (level + 2), _Digits);
            tp = NormalizeDouble(entry - TakeProfit * point, _Digits);
            trade.Sell(recovLot, _Symbol, entry, sl, tp, tag);
         }
         g_lastTradeTime = TimeCurrent();
      }
   }
}

int GetRecoveryLevel(string comment)
{
   if (StringFind(comment, "GS2_RB_") >= 0 || StringFind(comment, "GS2_RS_") >= 0)
   {
      string lvl = StringSubstr(comment, StringLen(comment) - 1, 1);
      return (int)StringToInteger(lvl);
   }
   return 0;
}

//──────────────────────────────────────────────────────────────────
//  FILTERS
//──────────────────────────────────────────────────────────────────

bool PassFilters()
{
   // Weekend guard
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if (!TradeWeekends && (dt.day_of_week == 0 || dt.day_of_week == 6)) return false;

   // Drawdown guard
   double balance = account.Balance();
   double equity  = account.Equity();
   double dd      = (balance > 0) ? (balance - equity) / balance * 100 : 0;
   if (dd >= MaxDrawdownPct)
   {
      static datetime lw = 0;
      if (TimeCurrent() - lw > 300) { Print("PAUSED: DD ", DoubleToString(dd,1), "%"); lw = TimeCurrent(); }
      return false;
   }

   // Daily loss guard
   double dailyDD = (g_dayStartBalance > 0) ? (g_dayStartBalance - equity) / g_dayStartBalance * 100 : 0;
   if (dailyDD >= MaxDailyLossPct)
   {
      static datetime lw2 = 0;
      if (TimeCurrent() - lw2 > 300) { Print("PAUSED: DailyLoss ", DoubleToString(dailyDD,1), "%"); lw2 = TimeCurrent(); }
      return false;
   }

   // Spread guard
   if (UseSpreadFilter && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread) return false;

   return true;
}

//──────────────────────────────────────────────────────────────────
//  HELPERS
//──────────────────────────────────────────────────────────────────

int CountMagicPositions()
{
   int n = 0;
   for (int i = 0; i < PositionsTotal(); i++)
      if (posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber && posInfo.Symbol() == _Symbol) n++;
   return n;
}

void ResetDaily()
{
   datetime curDay = iTime(_Symbol, PERIOD_D1, 0);
   if (curDay != g_lastDayReset)
   {
      g_dayStartBalance = account.Balance();
      g_lastDayReset    = curDay;
      Print("Day reset | Balance: ", g_dayStartBalance);
   }
}

//──────────────────────────────────────────────────────────────────
//  TRADE EVENTS
//──────────────────────────────────────────────────────────────────

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest     &req,
                        const MqlTradeResult      &res)
{
   if (trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal = trans.deal;
   if (!HistoryDealSelect(deal)) return;
   if (HistoryDealGetInteger(deal, DEAL_MAGIC) != MagicNumber) return;
   if (HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
   g_totalTrades++;
   if (profit >= 0) { g_wins++;   g_grossProfit += profit; }
   else             { g_losses++; g_grossLoss   += profit; }

   // After a loss, check if recovery grid needed
   if (profit < 0 && UseRecovery) CheckRecovery();

   double wr = (double)g_wins / g_totalTrades * 100;
   double pf = (g_grossLoss != 0) ? g_grossProfit / MathAbs(g_grossLoss) : 0;

   if (g_totalTrades % 50 == 0)  // Print every 50 trades (high frequency)
      Print("Trades:", g_totalTrades, " WR:", DoubleToString(wr,1), "% PF:", DoubleToString(pf,2),
            " Net:", DoubleToString(g_grossProfit + g_grossLoss,2));
}
//+------------------------------------------------------------------+
