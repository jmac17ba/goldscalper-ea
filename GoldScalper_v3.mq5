//+------------------------------------------------------------------+
//|  GoldScalper v3.4 — Straddle + Recovery + Remote Kill Switch     |
//|  Base lot 0.01 | Fib recovery | Runs continuously                |
//|  Runs continuously until stopped                                 |
//|  Telegram: /stop /pause /resume /status from your phone          |
//+------------------------------------------------------------------+
#property copyright "GoldScalper v3.4"
#property version   "3.40"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//──────────────────────────────────────────────────────────────────
//  INPUTS
//──────────────────────────────────────────────────────────────────

input group "== Core Settings =="
input double BaseLot           = 0.01;
input double TargetProfitUSD   = 0.45;
input int    MagicNumber       = 9000001;
input int    Slippage          = 10;

input group "== Straddle Settings =="
input double StopOffsetPips   = 5.0;
input int    OrderExpiryBars  = 0;
input int    MaxOpenPositions = 12;

input group "== Recovery (Fibonacci ladder, drawdown only) =="
input bool   UseRecovery      = true;
input double RecoveryGapPips  = 12.0;
input int    MaxRecoveryLevel = 7;

input group "== Frequency Control =="
input int    TradeGapSeconds  = 5;
input bool   TradeWeekends    = false;


input group "== Trend Filter =="
input int    TrendLookback     = 5;
input int    TrendMaxSame      = 4;    // Block if X same-color candles in a row
input double TrendMaxRangePips = 40.0; // Block if range > X pips over lookback

input group "== Risk Management =="
input double MaxDrawdownPct   = 20.0;
input double MaxDailyLossPct  = 5.0;
input bool   UseSpreadFilter  = true;
input int    MaxSpread        = 50;


input group "== Telegram Remote Control =="
input string TelegramToken  = "";   // Bot token from @BotFather
input string TelegramChatId = "";   // Your personal chat ID

input group "== Session & Volatility Filter =="
input bool   UseSessionFilter = false;
input int    SessionStartHour = 8;    // Server-time hour to START (default 8am = London open)
input int    SessionEndHour   = 17;   // Server-time hour to STOP  (default 5pm = NY close)
input bool   UseATRFilter     = true;
input double MinATR           = 0.50; // Min ATR(14) on M15 — skip straddle if market too dead

//──────────────────────────────────────────────────────────────────
//  GLOBALS
//──────────────────────────────────────────────────────────────────

CTrade        trade;
COrderInfo    orderInfo;
CPositionInfo posInfo;
CAccountInfo  account;

double   g_dayStartBalance   = 0;
datetime g_lastDayReset      = 0;
datetime g_lastTradeTime     = 0;
datetime g_lastRecoveryBuy   = 0, g_lastRecoverySell = 0;

int    g_totalTrades = 0, g_wins = 0, g_losses = 0;
double g_grossProfit = 0, g_grossLoss = 0;

double g_sessionStartEquity = 0;

// Track position counts to detect when a new level is added
int    g_lastBuyCount       = 0;
int    g_lastSellCount      = 0;

// Entry price of the most recently opened recovery level per side
// When price returns here the last added position breaks even → close all
double g_lastBuyEntry       = 0;
double g_lastSellEntry      = 0;

// Telegram remote control
long   g_telegramOffset     = -1;   // -1 = first poll (drain old messages, don't act on them)
bool   g_paused             = false; // /pause — halts new straddles, recovery still runs
bool   g_killSwitch         = false; // /stop  — closes all positions, halts everything

// ATR indicator handle (created once in OnInit)
int    g_atrHandle          = INVALID_HANDLE;


//──────────────────────────────────────────────────────────────────
//  TELEGRAM — send + poll (kill switch from phone)
//──────────────────────────────────────────────────────────────────

void SendTelegram(string text)
{
   if (TelegramToken == "" || TelegramChatId == "") return;
   string body = text;
   StringReplace(body, "\n", "%0A");
   StringReplace(body, " ", "+");
   StringReplace(body, "$", "%24");
   string url     = "https://api.telegram.org/bot" + TelegramToken + "/sendMessage";
   string params  = "chat_id=" + TelegramChatId + "&text=" + body + "&parse_mode=HTML";
   string reqHdr  = "Content-Type: application/x-www-form-urlencoded\r\n";
   char post[], result[];
   int  len = StringToCharArray(params, post, 0, WHOLE_ARRAY) - 1;
   ArrayResize(post, len);
   string resHdr;
   int rc = WebRequest("POST", url, reqHdr, 5000, post, result, resHdr);
   Print("TG send rc=", rc, " resp=", CharArrayToString(result));
}

// Simple JSON field extractor — no library needed
string TgExtract(const string &src, const string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(src, search);
   if (pos < 0) return "";
   pos += StringLen(search);
   bool isStr = (StringGetCharacter(src, pos) == '"');
   if (isStr) pos++;
   int end = pos, srcLen = StringLen(src);
   while (end < srcLen)
   {
      ushort ch = StringGetCharacter(src, end);
      if ( isStr && ch == '"') break;
      if (!isStr && (ch == ',' || ch == '}' || ch == ']')) break;
      end++;
   }
   return StringSubstr(src, pos, end - pos);
}

string BuildStatus()
{
   double equity = account.Equity();
   double pnl    = equity - g_sessionStartEquity;
   string state  = g_killSwitch ? "STOPPED"
                 : g_paused     ? "PAUSED"
                 : "RUNNING";
   return StringFormat(
      "GoldScalper v3.4\nState: %s\nEquity: $%.2f  P&L: %+.2f\n"
      "Positions: BUY %d  SELL %d",
      state, equity, pnl,
      CountSide(POSITION_TYPE_BUY), CountSide(POSITION_TYPE_SELL));
}

void TelegramPoll()
{
   if (TelegramToken == "" || TelegramChatId == "") return;

   // g_telegramOffset == -1 on first poll: drain old messages without acting on them
   string offsetParam = (g_telegramOffset >= 0)
      ? "&offset=" + IntegerToString(g_telegramOffset + 1)
      : "";
   string url = "https://api.telegram.org/bot" + TelegramToken
              + "/getUpdates?limit=10&timeout=0" + offsetParam;

   char post[], result[];
   string resHdr;
   if (WebRequest("GET", url, "", 5000, post, result, resHdr) <= 0) return;

   string json = CharArrayToString(result);
   if (StringFind(json, "\"ok\":true") < 0) return;

   bool firstPoll = (g_telegramOffset < 0);
   int  from      = 0;

   while (true)
   {
      int uidPos = StringFind(json, "\"update_id\":", from);
      if (uidPos < 0) break;

      // Extract update_id
      long uid = StringToInteger(TgExtract(StringSubstr(json, uidPos), "update_id"));
      if (uid > g_telegramOffset) g_telegramOffset = uid;

      if (!firstPoll)
      {
         // Verify the message is from our authorised chat
         int chatPos = StringFind(json, "\"chat\":", uidPos);
         int idPos   = StringFind(json, "\"id\":", chatPos > 0 ? chatPos : uidPos);
         string fromId = TgExtract(StringSubstr(json, idPos), "id");

         if (fromId == TelegramChatId)
         {
            int textPos = StringFind(json, "\"text\":\"", uidPos);
            string cmd  = (textPos > 0) ? TgExtract(StringSubstr(json, textPos), "text") : "";
            StringToLower(cmd);
            // Strip bot username suffix (e.g. /stop@mybotname)
            int atPos = StringFind(cmd, "@");
            if (atPos > 0) cmd = StringSubstr(cmd, 0, atPos);

            if (cmd == "/stop")
            {
               g_killSwitch = true;
               CloseAllPositions();
               CancelPendings();
               SendTelegram("STOPPED — all positions closed.\nRemove and re-attach EA to restart.");
            }
            else if (cmd == "/pause")
            {
               g_paused = true;
               SendTelegram("PAUSED — no new straddles.\nRecovery and existing positions still active.\nSend /resume to continue.");
            }
            else if (cmd == "/resume")
            {
               if (g_killSwitch) SendTelegram("Cannot resume — EA was stopped. Remove and re-attach EA.");
               else { g_paused = false; SendTelegram("RESUMED — normal operation."); }
            }
            else if (cmd == "/status") { SendTelegram(BuildStatus()); }
            else if (StringLen(cmd) > 0) { SendTelegram("Commands:\n/status\n/pause\n/resume\n/stop"); }
         }
      }
      from = uidPos + 1;
   }
}

//──────────────────────────────────────────────────────────────────
//  INIT / DEINIT
//──────────────────────────────────────────────────────────────────

int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   g_dayStartBalance = account.Balance();
   g_lastDayReset    = iTime(_Symbol, PERIOD_D1, 0);

   g_sessionStartEquity = account.Equity();

   g_atrHandle = iATR(_Symbol, PERIOD_M15, 14);
   EventSetTimer(3);   // poll Telegram every 3 seconds

   Print("GoldScalper v3.4 ONLINE | Equity: $", DoubleToString(g_sessionStartEquity, 2));
   SendTelegram("GoldScalper v3.4 — ONLINE\n"
      "Equity: $" + DoubleToString(g_sessionStartEquity, 2) + "\n"
      "Commands: /status /pause /resume /stop");

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if (g_atrHandle != INVALID_HANDLE) { IndicatorRelease(g_atrHandle); g_atrHandle = INVALID_HANDLE; }
   CleanChartObjects();
   double wr = (g_totalTrades > 0) ? (double)g_wins / g_totalTrades * 100 : 0;
   double pf = (g_grossLoss  != 0) ? g_grossProfit / MathAbs(g_grossLoss) : 0;
   Print("=== v3.4 Session | Trades:", g_totalTrades,
         " WR:", DoubleToString(wr, 1), "%",
         " PF:", DoubleToString(pf, 2),
         " Net:", DoubleToString(g_grossProfit + g_grossLoss, 2));
}

//──────────────────────────────────────────────────────────────────
//  TIMER — Telegram poll every 3 s
//──────────────────────────────────────────────────────────────────

void OnTimer() { TelegramPoll(); }


//──────────────────────────────────────────────────────────────────
//  TICK
//──────────────────────────────────────────────────────────────────

void OnTick()
{
   ManageBaskets();

   int curBuy  = CountSide(POSITION_TYPE_BUY);
   int curSell = CountSide(POSITION_TYPE_SELL);
   if (curBuy  != g_lastBuyCount)  { UpdateBasketTPs(POSITION_TYPE_BUY);  g_lastBuyCount  = curBuy;  }
   if (curSell != g_lastSellCount) { UpdateBasketTPs(POSITION_TYPE_SELL); g_lastSellCount = curSell; }

   if (g_killSwitch) return;

   ResetDaily();

   CheckRecovery();

   if (g_paused) return;        // phone pause — no new straddles, recovery still runs above
   if (!PassFilters()) return;
   if (TimeCurrent() - g_lastTradeTime < TradeGapSeconds) return;
   if (CountPositions() > 0) return;
   if (CountPendings()  > 0) return;

   PlaceStraddle();
   g_lastTradeTime = TimeCurrent();
}

//──────────────────────────────────────────────────────────────────
//  PLACE STRADDLE
//──────────────────────────────────────────────────────────────────

void PlaceStraddle()
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pip    = 10 * point;
   double tpDist = TargetProfitUSD;

   long   stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double offset     = MathMax(StopOffsetPips * pip, (stopsLevel + 1) * point);

   datetime expiry  = (OrderExpiryBars > 0) ? TimeCurrent() + OrderExpiryBars * PeriodSeconds(PERIOD_M1) : 0;
   ENUM_ORDER_TYPE_TIME timeType = (expiry > 0) ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC;

   for (int attempt = 0; attempt < 2; attempt++)
   {
      double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double buyEntry = NormalizeDouble(ask + offset, _Digits);
      double buyTP    = NormalizeDouble(buyEntry + tpDist, _Digits);
      if (trade.BuyStop(BaseLot, buyEntry, _Symbol, 0, buyTP, timeType, expiry, "GS3_BS")) break;
   }

   for (int attempt = 0; attempt < 2; attempt++)
   {
      double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sellEntry = NormalizeDouble(bid - offset, _Digits);
      double sellTP    = NormalizeDouble(sellEntry - tpDist, _Digits);
      if (trade.SellStop(BaseLot, sellEntry, _Symbol, 0, sellTP, timeType, expiry, "GS3_SS")) break;
   }
}

//──────────────────────────────────────────────────────────────────
//  BASKET MANAGER
//──────────────────────────────────────────────────────────────────

void ManageBaskets()
{
   double buyPL = 0, sellPL = 0;
   int    buyN  = 0, sellN  = 0;

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      double pl = posInfo.Profit() + posInfo.Swap();
      if (posInfo.PositionType() == POSITION_TYPE_BUY) { buyPL += pl; buyN++; }
      else                                              { sellPL += pl; sellN++; }
   }

   // Close basket the moment total P&L turns positive
   if (buyN  > 1 && buyPL  > 0) { CloseSide(POSITION_TYPE_BUY,  buyPL);  g_lastBuyEntry  = 0; return; }
   if (sellN > 1 && sellPL > 0) { CloseSide(POSITION_TYPE_SELL, sellPL); g_lastSellEntry = 0; return; }

}

void CloseSide(ENUM_POSITION_TYPE side, double netPL)
{
   Print("BASKET CLOSE ", (side == POSITION_TYPE_BUY ? "BUY" : "SELL"),
         " side | Net: $", DoubleToString(netPL, 2));
   DeleteRecoveryLines(side);
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      if (posInfo.PositionType() != side) continue;
      trade.PositionClose(posInfo.Ticket());
   }
}

void CloseAllPositions()
{
   Print("CLOSING ALL POSITIONS — hard floor hit");
   DeleteRecoveryLines(POSITION_TYPE_BUY);
   DeleteRecoveryLines(POSITION_TYPE_SELL);
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      trade.PositionClose(posInfo.Ticket());
   }
}

//──────────────────────────────────────────────────────────────────
//  RECOVERY
//──────────────────────────────────────────────────────────────────

bool IsTrending()
{
   int    bull = 0, bear = 0;
   double pip  = 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   for (int i = 1; i <= TrendLookback; i++)
   {
      double o = iOpen(_Symbol, PERIOD_M1, i), c = iClose(_Symbol, PERIOD_M1, i);
      if (c > o) bull++; else if (c < o) bear++;
   }
   double hi    = iHigh(_Symbol, PERIOD_M1, iHighest(_Symbol, PERIOD_M1, MODE_HIGH, TrendLookback, 1));
   double lo    = iLow (_Symbol, PERIOD_M1, iLowest (_Symbol, PERIOD_M1, MODE_LOW,  TrendLookback, 1));
   double range = (hi - lo) / pip;
   return (bull >= TrendMaxSame || bear >= TrendMaxSame || range > TrendMaxRangePips);
}

double FibLot(int level)
{
   static const double fib[] = {0.01, 0.02, 0.03, 0.05, 0.08, 0.13, 0.22, 0.37};
   int idx = MathMin(level, ArraySize(fib) - 1);
   return NormalizeLot(fib[idx] * (BaseLot / 0.01));
}


void CheckRecovery()
{
   if (!UseRecovery) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pip   = 10 * point;
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double lowestBuyOpen  = DBL_MAX, highestSellOpen = 0;
   int    buyN = 0, sellN = 0;

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      if (posInfo.PositionType() == POSITION_TYPE_BUY)
      {
         buyN++;
         lowestBuyOpen = MathMin(lowestBuyOpen, posInfo.PriceOpen());
      }
      else
      {
         sellN++;
         highestSellOpen = MathMax(highestSellOpen, posInfo.PriceOpen());
      }
   }

   // Trigger next level only when price drops RecoveryGapPips below the LAST added level
   double buyDD  = (lowestBuyOpen  < DBL_MAX) ? (lowestBuyOpen  - bid) / pip : 0;
   double sellDD = (highestSellOpen > 0)       ? (ask - highestSellOpen) / pip : 0;

   int cooldown = 30;

   if (buyN > 0 && buyN <= MaxRecoveryLevel &&
       buyDD >= RecoveryGapPips &&
       TimeCurrent() - g_lastRecoveryBuy > cooldown)
   {
      double lot = FibLot(buyN);
      if (trade.Buy(lot, _Symbol, 0, 0, 0, "GS3_RB_" + IntegerToString(buyN)))
         { Print("RECOVERY BUY lvl", buyN, " lot:", lot); g_lastRecoveryBuy = TimeCurrent(); g_lastBuyEntry = ask; }
   }

   if (sellN > 0 && sellN <= MaxRecoveryLevel &&
       sellDD >= RecoveryGapPips &&
       TimeCurrent() - g_lastRecoverySell > cooldown)
   {
      double lot = FibLot(sellN);
      if (trade.Sell(lot, _Symbol, 0, 0, 0, "GS3_RS_" + IntegerToString(sellN)))
         { Print("RECOVERY SELL lvl", sellN, " lot:", lot); g_lastRecoverySell = TimeCurrent(); g_lastSellEntry = bid; }
   }
}

// ── Recovery line drawing ─────────────────────────────────────────────────────

struct PosEntry { double price; datetime t; };

int CollectSide(ENUM_POSITION_TYPE side, PosEntry &arr[])
{
   int n = 0;
   ArrayResize(arr, PositionsTotal());
   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      if (posInfo.PositionType() != side) continue;
      arr[n].price = posInfo.PriceOpen();
      arr[n].t     = posInfo.Time();
      n++;
   }
   ArrayResize(arr, n);
   for (int i = 0; i < n - 1; i++)
      for (int j = i + 1; j < n; j++)
         if (arr[j].t < arr[i].t) { PosEntry tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp; }
   return n;
}

void RedrawRecoveryLines(ENUM_POSITION_TYPE side)
{
   string prefix = "GS3_" + (side == POSITION_TYPE_BUY ? "B" : "S") + "_LN_";
   for (int i = 0; i <= MaxRecoveryLevel + 1; i++) ObjectDelete(0, prefix + IntegerToString(i));

   PosEntry arr[];
   int n = CollectSide(side, arr);
   if (n < 2) return;

   color clr = (side == POSITION_TYPE_BUY) ? clrDodgerBlue : clrCrimson;
   for (int i = 0; i < n - 1; i++)
   {
      string name = prefix + IntegerToString(i);
      if (ObjectCreate(0, name, OBJ_TREND, 0, arr[i].t, arr[i].price, arr[i+1].t, arr[i+1].price))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
         ObjectSetInteger(0, name, OBJPROP_STYLE,      STYLE_DOT);
         ObjectSetInteger(0, name, OBJPROP_WIDTH,      1);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT,  false);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
      }
   }
}

void DeleteRecoveryLines(ENUM_POSITION_TYPE side)
{
   string prefix = "GS3_" + (side == POSITION_TYPE_BUY ? "B" : "S") + "_LN_";
   for (int i = 0; i <= MaxRecoveryLevel + 1; i++) ObjectDelete(0, prefix + IntegerToString(i));
}

void DrawEntryArrow(ulong ticket, long dealType, double price, datetime t)
{
   string name = "GS3_ARROW_" + IntegerToString(ticket);
   bool   isBuy = (dealType == DEAL_TYPE_BUY);
   if (!ObjectCreate(0, name, isBuy ? OBJ_ARROW_BUY : OBJ_ARROW_SELL, 0, t, price)) return;
   ObjectSetInteger(0, name, OBJPROP_COLOR,      isBuy ? clrDodgerBlue : clrCrimson);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      2);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
}

void CleanChartObjects()
{
   for (int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if (StringFind(name, "GS3_") == 0) ObjectDelete(0, name);
   }
}

void UpdateBasketTPs(ENUM_POSITION_TYPE side)
{
   double totalLots = 0, lotPriceSum = 0;
   int    posCount  = 0;

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      if (posInfo.PositionType() != side) continue;
      totalLots   += posInfo.Volume();
      lotPriceSum += posInfo.Volume() * posInfo.PriceOpen();
      posCount++;
   }
   if (totalLots == 0) return;

   double newTP;
   if (posCount == 1)
   {
      // Single position: fixed profit target
      double sign = (side == POSITION_TYPE_BUY) ? 1.0 : -1.0;
      newTP = NormalizeDouble(lotPriceSum / totalLots + sign * TargetProfitUSD, _Digits);
   }
   else
   {
      // Recovery basket: TP = weighted average entry (breakeven point).
      // Only set on positions where this TP is valid (above entry for buys, below for sells).
      // OnTradeTransaction cascades the close to remaining positions when any TP fires.
      newTP = NormalizeDouble(lotPriceSum / totalLots, _Digits);
   }

   for (int i = 0; i < PositionsTotal(); i++)
   {
      if (!posInfo.SelectByIndex(i)) continue;
      if (posInfo.Magic() != MagicNumber || posInfo.Symbol() != _Symbol) continue;
      if (posInfo.PositionType() != side) continue;
      double entry = posInfo.PriceOpen();
      bool   valid = (posCount == 1) ||
                     (side == POSITION_TYPE_BUY  && newTP > entry + _Point) ||
                     (side == POSITION_TYPE_SELL && newTP < entry - _Point);
      double tp = valid ? newTP : 0;
      if (MathAbs(posInfo.TakeProfit() - tp) > _Point)
         trade.PositionModify(posInfo.Ticket(), posInfo.StopLoss(), tp);
   }
   Print("Basket TP → ", DoubleToString(newTP, _Digits),
         " (", (side == POSITION_TYPE_BUY ? "BUY" : "SELL"), ")");
   RedrawRecoveryLines(side);
}

double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   return MathMax(minLot, MathMin(maxLot, lot));
}

//──────────────────────────────────────────────────────────────────
//  HELPERS
//──────────────────────────────────────────────────────────────────

int CountPositions()
{
   int n = 0;
   for (int i = 0; i < PositionsTotal(); i++)
      if (posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber && posInfo.Symbol() == _Symbol) n++;
   return n;
}

int CountSide(ENUM_POSITION_TYPE side)
{
   int n = 0;
   for (int i = 0; i < PositionsTotal(); i++)
      if (posInfo.SelectByIndex(i) && posInfo.Magic() == MagicNumber && posInfo.Symbol() == _Symbol && posInfo.PositionType() == side) n++;
   return n;
}

int CountPendings()
{
   int n = 0;
   for (int i = 0; i < OrdersTotal(); i++)
      if (orderInfo.SelectByIndex(i) && orderInfo.Magic() == MagicNumber && orderInfo.Symbol() == _Symbol) n++;
   return n;
}

bool PassFilters()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if (!TradeWeekends && (dt.day_of_week == 0 || dt.day_of_week == 6)) return false;

   // Session filter — only trade between StartHour and EndHour (server time)
   if (UseSessionFilter)
   {
      int  h         = dt.hour;
      bool inSession = (SessionStartHour <= SessionEndHour)
                     ? (h >= SessionStartHour && h < SessionEndHour)
                     : (h >= SessionStartHour || h < SessionEndHour);
      if (!inSession)
      {
         static datetime lwSess = 0;
         if (TimeCurrent() - lwSess > 300) { Print("PAUSED: outside session (", h, "h)"); lwSess = TimeCurrent(); }
         return false;
      }
   }

   // ATR filter — skip straddle if market is too quiet
   if (UseATRFilter && g_atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      if (CopyBuffer(g_atrHandle, 0, 1, 1, atrBuf) > 0 && atrBuf[0] < MinATR)
      {
         static datetime lwATR = 0;
         if (TimeCurrent() - lwATR > 60)
         {
            Print("PAUSED: ATR ", DoubleToString(atrBuf[0], 3), " < min ", DoubleToString(MinATR, 3));
            lwATR = TimeCurrent();
         }
         return false;
      }
   }

   double balance = account.Balance();
   double equity  = account.Equity();
   double dd      = (balance > 0) ? (balance - equity) / balance * 100 : 0;
   if (dd >= MaxDrawdownPct)
   {
      static datetime lw = 0;
      if (TimeCurrent() - lw > 300) { Print("PAUSED: DD ", DoubleToString(dd,1), "%"); lw = TimeCurrent(); }
      return false;
   }

   double dailyDD = (g_dayStartBalance > 0) ? (g_dayStartBalance - equity) / g_dayStartBalance * 100 : 0;
   if (dailyDD >= MaxDailyLossPct)
   {
      static datetime lw2 = 0;
      if (TimeCurrent() - lw2 > 300) { Print("PAUSED: DailyLoss ", DoubleToString(dailyDD,1), "%"); lw2 = TimeCurrent(); }
      return false;
   }

   if (UseSpreadFilter && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > MaxSpread) return false;

   if (TrendLookback > 1 && IsTrending())
   {
      static datetime lwTrend = 0;
      if (TimeCurrent() - lwTrend > 60)
         { Print("PAUSED: trend filter"); lwTrend = TimeCurrent(); }
      return false;
   }

   return true;
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

   if (HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
   {
      long     dealType  = HistoryDealGetInteger(deal, DEAL_TYPE);
      double   dealPrice = HistoryDealGetDouble(deal,  DEAL_PRICE);
      datetime dealTime  = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      DrawEntryArrow(deal, dealType, dealPrice, dealTime);
      if (dealType == DEAL_TYPE_BUY)  UpdateBasketTPs(POSITION_TYPE_BUY);
      if (dealType == DEAL_TYPE_SELL) UpdateBasketTPs(POSITION_TYPE_SELL);
      CancelPendings(); // kill opposite straddle leg so next bracket can fire
      return;
   }

   if (HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   // Cascade close: if other positions remain on the same side, a basket TP just fired — close them all
   long dealType2 = HistoryDealGetInteger(deal, DEAL_TYPE);
   ENUM_POSITION_TYPE closedSide = (dealType2 == DEAL_TYPE_SELL) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   if (CountSide(closedSide) > 0)
   {
      CloseSide(closedSide, 0);
      if (closedSide == POSITION_TYPE_BUY)  g_lastBuyEntry  = 0;
      else                                   g_lastSellEntry = 0;
   }

   double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
   g_totalTrades++;
   if (profit >= 0) { g_wins++;   g_grossProfit += profit; }
   else             { g_losses++; g_grossLoss   += profit; }

   double wr = (double)g_wins / g_totalTrades * 100;
   Print("CLOSED | P&L: $", DoubleToString(profit, 2),
         " | WR:", DoubleToString(wr, 1), "%",
         " | Net: $", DoubleToString(g_grossProfit + g_grossLoss, 2));

   if (profit >= 0 && !g_paused && !g_killSwitch && PassFilters())
   {
      if (CountPositions() == 0 && CountPendings() == 0)
      {
         PlaceStraddle();
         g_lastTradeTime = TimeCurrent();
      }
   }
}

void CancelPendings()
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!orderInfo.SelectByIndex(i)) continue;
      if (orderInfo.Magic() != MagicNumber || orderInfo.Symbol() != _Symbol) continue;
      trade.OrderDelete(orderInfo.Ticket());
   }
}
//+------------------------------------------------------------------+
