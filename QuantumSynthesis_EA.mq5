//+------------------------------------------------------------------+
//|                                        QuantumSynthesis_EA.mq5   |
//|                      Quantum Synthesis Trading System  v1.0       |
//|                   Candlestick Pattern Intelligence Engine          |
//|                       quantum-synthesis.com                       |
//+------------------------------------------------------------------+
#property copyright   "Quantum Synthesis Trading Systems"
#property link        "https://quantum-synthesis.com"
#property version     "1.00"
#property description "16-Pattern Candlestick Recognition | ATR Risk Engine | Animated HUD"

#include <Trade\Trade.mqh>

//──────────────────────────────────────────────────────────────────────────────
//  Constants
//──────────────────────────────────────────────────────────────────────────────
#define MAGIC_QS        202401
#define PANEL_PREFIX    "QS_"
#define PANEL_W         286
#define PANEL_H         348

//──────────────────────────────────────────────────────────────────────────────
//  Enums
//──────────────────────────────────────────────────────────────────────────────
enum ENUM_SIGNAL_TYPE  { SIG_NONE = 0, SIG_BUY = 1, SIG_SELL = -1 };

enum ENUM_PATTERN_ID
{
   PAT_NONE           = 0,
   PAT_DOJI           = 1,
   PAT_HAMMER         = 2,
   PAT_SHOOTING_STAR  = 3,
   PAT_BULL_ENGULF    = 4,
   PAT_BEAR_ENGULF    = 5,
   PAT_MORNING_STAR   = 6,
   PAT_EVENING_STAR   = 7,
   PAT_PIN_BAR_BULL   = 8,
   PAT_PIN_BAR_BEAR   = 9,
   PAT_INSIDE_BAR     = 10,
   PAT_THREE_SOLDIERS = 11,
   PAT_THREE_CROWS    = 12,
   PAT_HARAMI_BULL    = 13,
   PAT_HARAMI_BEAR    = 14,
   PAT_TWEEZER_BOTTOM = 15,
   PAT_TWEEZER_TOP    = 16
};

//──────────────────────────────────────────────────────────────────────────────
//  Inputs
//──────────────────────────────────────────────────────────────────────────────
input group "=== QUANTUM SYNTHESIS ENGINE ==="
input bool   InpAutoTrade      = true;          // Enable Auto-Trading
input double InpRiskPercent    = 1.0;           // Risk Per Trade (% balance)
input int    InpMaxPositions   = 3;             // Max Concurrent Positions
input double InpMinLot         = 0.01;          // Minimum Lot Size
input double InpMaxLot         = 5.0;           // Maximum Lot Size

input group "=== PATTERN DETECTION ==="
input double InpDojiRatio      = 0.05;          // Doji Body/Range Threshold (5%)
input double InpPinWickRatio   = 2.0;           // Pin Bar Wick:Body Ratio
input double InpEngulfBuffer   = 0.0;           // Engulfing Buffer (pips)
input int    InpMinConfidence  = 60;            // Min Confidence to Trade (%)

input group "=== INDICATOR FILTERS ==="
input bool   InpUseTrendFilter = true;          // Trend Filter (EMA)
input int    InpEMAPeriod      = 200;           // Trend EMA Period
input bool   InpUseRSIFilter   = true;          // RSI Confirmation Filter
input int    InpRSIPeriod      = 14;            // RSI Period
input int    InpRSIOB          = 70;            // RSI Overbought Level
input int    InpRSIOS          = 30;            // RSI Oversold Level

input group "=== RISK MANAGEMENT ==="
input int    InpATRPeriod      = 14;            // ATR Period
input double InpSLMultiplier   = 1.5;           // Stop Loss  (x ATR)
input double InpTPMultiplier   = 2.5;           // Take Profit (x ATR)
input bool   InpUseTrailing    = true;          // Use Trailing Stop
input double InpTrailATR       = 1.0;           // Trail Distance (x ATR)
input bool   InpUseBreakeven   = true;          // Move SL to Breakeven
input double InpBEMultiplier   = 1.0;           // Breakeven Trigger (x ATR)

input group "=== DISPLAY PANEL ==="
input bool   InpShowPanel      = true;          // Show HUD Panel
input int    InpPanelX         = 20;            // Panel X Position
input int    InpPanelY         = 30;            // Panel Y Position
input bool   InpSoundAlerts    = true;          // Play Sound on Pattern
input bool   InpPopupAlerts    = false;         // Popup Alert on Pattern

//──────────────────────────────────────────────────────────────────────────────
//  Pattern name table (indexed by ENUM_PATTERN_ID)
//──────────────────────────────────────────────────────────────────────────────
string PATTERN_NAMES[] =
{
   "NONE", "DOJI", "HAMMER", "SHOOTING STAR",
   "BULL ENGULFING", "BEAR ENGULFING",
   "MORNING STAR", "EVENING STAR",
   "PIN BAR  BULL", "PIN BAR  BEAR",
   "INSIDE BAR",
   "THREE SOLDIERS", "THREE CROWS",
   "HARAMI BULL", "HARAMI BEAR",
   "TWEEZER BOTTOM", "TWEEZER TOP"
};

//──────────────────────────────────────────────────────────────────────────────
//  Globals
//──────────────────────────────────────────────────────────────────────────────
CTrade            g_Trade;
int               g_EMAHandle     = INVALID_HANDLE;
int               g_RSIHandle     = INVALID_HANDLE;
int               g_ATRHandle     = INVALID_HANDLE;
datetime          g_LastBarTime   = 0;
int               g_ScanFrame     = 0;
ENUM_PATTERN_ID   g_LastPattern   = PAT_NONE;
int               g_LastConf      = 0;
ENUM_SIGNAL_TYPE  g_LastSignal    = SIG_NONE;
int               g_TotalSignals  = 0;

// Panel colour theme (dark blue-grey tech style)
color COL_BG       = C'10,14,30';
color COL_HDR      = C'6,30,80';
color COL_INSET    = C'5,18,40';
color COL_FTR      = C'4,12,28';
color COL_ACCENT   = C'0,200,255';
color COL_BULL     = C'0,230,118';
color COL_BEAR     = C'255,82,82';
color COL_TEXT     = C'200,220,255';
color COL_DIM      = C'80,90,110';

string SCAN_CHARS[] = {"|", "/", "-", "\\"};

//══════════════════════════════════════════════════════════════════════════════
//  INIT / DEINIT
//══════════════════════════════════════════════════════════════════════════════
int OnInit()
{
   g_EMAHandle = iMA(_Symbol, PERIOD_CURRENT, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_RSIHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   g_ATRHandle = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

   if(g_EMAHandle == INVALID_HANDLE ||
      g_RSIHandle == INVALID_HANDLE ||
      g_ATRHandle == INVALID_HANDLE)
   {
      Alert("QuantumSynthesis: Indicator init failed — check symbol/TF");
      return INIT_FAILED;
   }

   g_Trade.SetExpertMagicNumber(MAGIC_QS);
   g_Trade.SetDeviationInPoints(30);
   g_Trade.SetTypeFilling(ORDER_FILLING_FOK);

   if(InpShowPanel) BuildPanel();

   EventSetMillisecondTimer(400);   // ~2.5 fps animation refresh

   Print("QuantumSynthesis EA v1.0 — ONLINE | ", _Symbol, " ", EnumToString(Period()));
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeletePanel();
   IndicatorRelease(g_EMAHandle);
   IndicatorRelease(g_RSIHandle);
   IndicatorRelease(g_ATRHandle);
}

//══════════════════════════════════════════════════════════════════════════════
//  TIMER — drives panel animation between bars
//══════════════════════════════════════════════════════════════════════════════
void OnTimer()
{
   g_ScanFrame = (g_ScanFrame + 1) % 4;
   if(InpShowPanel) AnimatePanel();
}

//══════════════════════════════════════════════════════════════════════════════
//  TICK
//══════════════════════════════════════════════════════════════════════════════
void OnTick()
{
   // Per-tick: manage open positions (trailing/BE)
   if(InpUseTrailing || InpUseBreakeven)
      ManageOpenPositions();

   // New-bar gate
   datetime barTime[1];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, barTime) < 1) return;
   if(barTime[0] == g_LastBarTime) return;
   g_LastBarTime = barTime[0];

   // Run pattern engine
   ENUM_PATTERN_ID pat;
   int             conf;
   ENUM_SIGNAL_TYPE sig;
   RunPatternEngine(pat, conf, sig);

   g_LastPattern = pat;
   g_LastConf    = conf;
   g_LastSignal  = sig;

   if(InpShowPanel) UpdatePanelData();

   // Auto-trade entry
   if(InpAutoTrade && sig != SIG_NONE && conf >= InpMinConfidence)
      AttemptEntry(sig);
}

//══════════════════════════════════════════════════════════════════════════════
//  PATTERN ENGINE
//══════════════════════════════════════════════════════════════════════════════

//+------------------------------------------------------------------+
//| Fetch OHLC + indicators for last N bars (index 1 = last closed)  |
//+------------------------------------------------------------------+
bool FetchBars(int n,
               double &o[], double &h[], double &l[], double &c[],
               double &ema[], double &rsi[], double &atr[])
{
   ArraySetAsSeries(o,   true); ArraySetAsSeries(h,   true);
   ArraySetAsSeries(l,   true); ArraySetAsSeries(c,   true);
   ArraySetAsSeries(ema, true); ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyOpen(_Symbol,  PERIOD_CURRENT, 1, n, o)   < n) return false;
   if(CopyHigh(_Symbol,  PERIOD_CURRENT, 1, n, h)   < n) return false;
   if(CopyLow(_Symbol,   PERIOD_CURRENT, 1, n, l)   < n) return false;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 1, n, c)   < n) return false;
   if(CopyBuffer(g_EMAHandle, 0, 1, n, ema)         < n) return false;
   if(CopyBuffer(g_RSIHandle, 0, 1, n, rsi)         < n) return false;
   if(CopyBuffer(g_ATRHandle, 0, 1, n, atr)         < n) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Master pattern scan — populates bestPat, bestConf, bestSig        |
//+------------------------------------------------------------------+
void RunPatternEngine(ENUM_PATTERN_ID &bestPat,
                      int             &bestConf,
                      ENUM_SIGNAL_TYPE &bestSig)
{
   bestPat  = PAT_NONE;
   bestConf = 0;
   bestSig  = SIG_NONE;

   double o[4], h[4], l[4], c[4], ema[4], rsi[4], atr[4];
   if(!FetchBars(4, o, h, l, c, ema, rsi, atr)) return;

   // Convenience flags
   bool bullTrend = c[0] > ema[0];
   bool bearTrend = c[0] < ema[0];
   bool rsiOS     = rsi[0] < (double)InpRSIOS;
   bool rsiOB     = rsi[0] > (double)InpRSIOB;
   double pip     = _Point * 10.0;

   // Candidate arrays (max 20 patterns)
   ENUM_PATTERN_ID  cPat[20];
   int              cCon[20];
   ENUM_SIGNAL_TYPE cSig[20];
   int n = 0;

#define PUSH(P,C,S) { cPat[n]=P; cCon[n]=(int)MathMin(98,C); cSig[n]=S; n++; }

   //────────────────────────────────────────────────────────────────
   // 1. DOJI — body ≤ 5% of range → indecision at S/R
   //────────────────────────────────────────────────────────────────
   {
      double range = h[0] - l[0];
      double body  = MathAbs(c[0] - o[0]);
      if(range > 0 && body / range <= InpDojiRatio)
      {
         if(InpUseRSIFilter && rsiOS && (!InpUseTrendFilter || !bullTrend))
            PUSH(PAT_DOJI, 60 + (rsiOS ? 10:0), SIG_BUY)
         else if(InpUseRSIFilter && rsiOB && (!InpUseTrendFilter || !bearTrend))
            PUSH(PAT_DOJI, 60 + (rsiOB ? 10:0), SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 2. HAMMER — small body near top, long lower wick ≥ 2× body
   //────────────────────────────────────────────────────────────────
   {
      double body  = MathAbs(c[0] - o[0]);
      double lwick = MathMin(o[0], c[0]) - l[0];
      double uwick = h[0] - MathMax(o[0], c[0]);
      double range = h[0] - l[0];
      if(body > 0 && range > 0 && body < range * 0.35 &&
         lwick >= body * 2.0 && uwick < body)
      {
         int conf = 68
                  + (InpUseTrendFilter && !bullTrend ? 8 : 0)
                  + (InpUseRSIFilter   && rsiOS      ? 12 : 0);
         PUSH(PAT_HAMMER, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 3. SHOOTING STAR — small body near bottom, long upper wick ≥ 2× body
   //────────────────────────────────────────────────────────────────
   {
      double body  = MathAbs(c[0] - o[0]);
      double uwick = h[0] - MathMax(o[0], c[0]);
      double lwick = MathMin(o[0], c[0]) - l[0];
      double range = h[0] - l[0];
      if(body > 0 && range > 0 && body < range * 0.35 &&
         uwick >= body * 2.0 && lwick < body)
      {
         int conf = 68
                  + (InpUseTrendFilter && bullTrend ? 8 : 0)
                  + (InpUseRSIFilter   && rsiOB     ? 12 : 0);
         PUSH(PAT_SHOOTING_STAR, conf, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 4. BULLISH ENGULFING — current bull bar fully engulfs prior bear
   //────────────────────────────────────────────────────────────────
   {
      double buf = InpEngulfBuffer * _Point;
      bool prevBear = c[1] < o[1];
      bool currBull = c[0] > o[0];
      if(prevBear && currBull &&
         o[0] <= c[1] - buf && c[0] >= o[1] + buf)
      {
         int conf = 74
                  + (InpUseTrendFilter && !bullTrend ? 5 : 0)
                  + (InpUseRSIFilter   && rsiOS      ? 10 : 0);
         PUSH(PAT_BULL_ENGULF, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 5. BEARISH ENGULFING
   //────────────────────────────────────────────────────────────────
   {
      double buf = InpEngulfBuffer * _Point;
      bool prevBull = c[1] > o[1];
      bool currBear = c[0] < o[0];
      if(prevBull && currBear &&
         o[0] >= c[1] + buf && c[0] <= o[1] - buf)
      {
         int conf = 74
                  + (InpUseTrendFilter && bullTrend ? 5 : 0)
                  + (InpUseRSIFilter   && rsiOB     ? 10 : 0);
         PUSH(PAT_BEAR_ENGULF, conf, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 6. MORNING STAR — 3-candle bullish reversal
   //    bar[2] big bear | bar[1] small doji-like | bar[0] big bull
   //────────────────────────────────────────────────────────────────
   {
      double ref   = atr[0] * 0.5;
      bool bigBear = c[2] < o[2] && (o[2] - c[2]) > ref;
      bool small1  = MathAbs(c[1] - o[1]) < atr[0] * 0.35;
      bool bigBull = c[0] > o[0] && (c[0] - o[0]) > ref;
      bool gapDn   = MathMax(o[1], c[1]) < o[2];
      if(bigBear && small1 && bigBull && gapDn)
      {
         int conf = 82 + (InpUseRSIFilter && rsiOS ? 8 : 0);
         PUSH(PAT_MORNING_STAR, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 7. EVENING STAR — 3-candle bearish reversal
   //────────────────────────────────────────────────────────────────
   {
      double ref   = atr[0] * 0.5;
      bool bigBull = c[2] > o[2] && (c[2] - o[2]) > ref;
      bool small1  = MathAbs(c[1] - o[1]) < atr[0] * 0.35;
      bool bigBear = c[0] < o[0] && (o[0] - c[0]) > ref;
      bool gapUp   = MathMin(o[1], c[1]) > o[2];
      if(bigBull && small1 && bigBear && gapUp)
      {
         int conf = 82 + (InpUseRSIFilter && rsiOB ? 8 : 0);
         PUSH(PAT_EVENING_STAR, conf, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 8. BULLISH PIN BAR — long lower wick, body in upper third, closes bull
   //────────────────────────────────────────────────────────────────
   {
      double body  = MathAbs(c[0] - o[0]);
      double lwick = MathMin(o[0], c[0]) - l[0];
      double uwick = h[0] - MathMax(o[0], c[0]);
      if(body > 0 && lwick >= body * InpPinWickRatio &&
         uwick < body * 0.5 && c[0] > o[0])
      {
         int conf = 70
                  + (InpUseRSIFilter   && rsiOS      ? 12 : 0)
                  + (InpUseTrendFilter && !bullTrend  ? 5  : 0);
         PUSH(PAT_PIN_BAR_BULL, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 9. BEARISH PIN BAR
   //────────────────────────────────────────────────────────────────
   {
      double body  = MathAbs(c[0] - o[0]);
      double uwick = h[0] - MathMax(o[0], c[0]);
      double lwick = MathMin(o[0], c[0]) - l[0];
      if(body > 0 && uwick >= body * InpPinWickRatio &&
         lwick < body * 0.5 && c[0] < o[0])
      {
         int conf = 70
                  + (InpUseRSIFilter   && rsiOB    ? 12 : 0)
                  + (InpUseTrendFilter && bullTrend ? 5  : 0);
         PUSH(PAT_PIN_BAR_BEAR, conf, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 10. INSIDE BAR — current bar fully inside previous bar
   //────────────────────────────────────────────────────────────────
   {
      if(h[0] < h[1] && l[0] > l[1])
      {
         if(bullTrend && rsiOS)
            PUSH(PAT_INSIDE_BAR, 63, SIG_BUY)
         else if(bearTrend && rsiOB)
            PUSH(PAT_INSIDE_BAR, 63, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 11. THREE WHITE SOLDIERS — 3 consecutive rising bull bars
   //────────────────────────────────────────────────────────────────
   {
      bool all3Bull = c[0]>o[0] && c[1]>o[1] && c[2]>o[2];
      bool rising   = c[0]>c[1] && c[1]>c[2];
      bool opRising = o[0]>o[1] && o[1]>o[2];
      if(all3Bull && rising && opRising)
      {
         int conf = 78 + (InpUseRSIFilter && !rsiOB ? 6 : 0);
         PUSH(PAT_THREE_SOLDIERS, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 12. THREE BLACK CROWS
   //────────────────────────────────────────────────────────────────
   {
      bool all3Bear = c[0]<o[0] && c[1]<o[1] && c[2]<o[2];
      bool falling  = c[0]<c[1] && c[1]<c[2];
      bool opFall   = o[0]<o[1] && o[1]<o[2];
      if(all3Bear && falling && opFall)
      {
         int conf = 78 + (InpUseRSIFilter && !rsiOS ? 6 : 0);
         PUSH(PAT_THREE_CROWS, conf, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 13. BULLISH HARAMI — small bull bar inside prior big bear
   //────────────────────────────────────────────────────────────────
   {
      bool bigBear  = c[1] < o[1] && (o[1]-c[1]) > atr[0]*0.4;
      bool smallBull = c[0] > o[0];
      bool insideBC  = o[0] > c[1] && c[0] < o[1];
      if(bigBear && smallBull && insideBC)
      {
         int conf = 65 + (InpUseRSIFilter && rsiOS ? 10 : 0);
         PUSH(PAT_HARAMI_BULL, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 14. BEARISH HARAMI
   //────────────────────────────────────────────────────────────────
   {
      bool bigBull  = c[1] > o[1] && (c[1]-o[1]) > atr[0]*0.4;
      bool smallBear = c[0] < o[0];
      bool insideBC  = o[0] < c[1] && c[0] > o[1];
      if(bigBull && smallBear && insideBC)
      {
         int conf = 65 + (InpUseRSIFilter && rsiOB ? 10 : 0);
         PUSH(PAT_HARAMI_BEAR, conf, SIG_SELL)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 15. TWEEZER BOTTOM — matching lows, prev bear → curr bull
   //────────────────────────────────────────────────────────────────
   {
      if(MathAbs(l[0] - l[1]) <= pip && c[1] < o[1] && c[0] > o[0])
      {
         int conf = 68 + (InpUseRSIFilter && rsiOS ? 14 : 0);
         PUSH(PAT_TWEEZER_BOTTOM, conf, SIG_BUY)
      }
   }

   //────────────────────────────────────────────────────────────────
   // 16. TWEEZER TOP — matching highs, prev bull → curr bear
   //────────────────────────────────────────────────────────────────
   {
      if(MathAbs(h[0] - h[1]) <= pip && c[1] > o[1] && c[0] < o[0])
      {
         int conf = 68 + (InpUseRSIFilter && rsiOB ? 14 : 0);
         PUSH(PAT_TWEEZER_TOP, conf, SIG_SELL)
      }
   }

#undef PUSH

   //────────────────────────────────────────────────────────────────
   // Select highest-confidence candidate
   //────────────────────────────────────────────────────────────────
   for(int i = 0; i < n; i++)
   {
      if(cCon[i] > bestConf)
      {
         bestConf = cCon[i];
         bestPat  = cPat[i];
         bestSig  = cSig[i];
      }
   }

   if(bestSig != SIG_NONE)
   {
      g_TotalSignals++;
      string sigStr = bestSig == SIG_BUY ? "BUY" : "SELL";
      Print("QS >> ", PATTERN_NAMES[bestPat],
            "  |  conf: ", bestConf, "%",
            "  |  signal: ", sigStr,
            "  |  RSI: ", DoubleToString(rsi[0], 1),
            "  |  ATR: ", DoubleToString(atr[0] / _Point, 1), " pts");
      if(InpSoundAlerts) PlaySound("alert.wav");
      if(InpPopupAlerts) Alert("QS Pattern: ", PATTERN_NAMES[bestPat],
                               "  |  Conf: ", bestConf, "%  |  ", sigStr);
   }
}

//══════════════════════════════════════════════════════════════════════════════
//  TRADE MANAGEMENT
//══════════════════════════════════════════════════════════════════════════════

int CountMyPositions()
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      PositionGetTicket(i);
      if((long)PositionGetInteger(POSITION_MAGIC) == MAGIC_QS &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         cnt++;
   }
   return cnt;
}

double CalcLot(double slDist)
{
   if(slDist <= 0.0) return InpMinLot;
   double bal      = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt  = bal * InpRiskPercent / 100.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) return InpMinLot;
   double pipValue = tickVal / tickSize * _Point;
   if(pipValue <= 0.0) return InpMinLot;
   double lot = riskAmt / (slDist / _Point * pipValue);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   lot = MathFloor(lot / step) * step;
   return MathMax(InpMinLot, MathMin(InpMaxLot, lot));
}

void AttemptEntry(ENUM_SIGNAL_TYPE sig)
{
   if(CountMyPositions() >= InpMaxPositions) return;

   double atr[1];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) < 1) return;
   double atrVal = atr[0];

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string comment = StringFormat("QS-%s", PATTERN_NAMES[g_LastPattern]);

   if(sig == SIG_BUY)
   {
      double sl  = ask - atrVal * InpSLMultiplier;
      double tp  = ask + atrVal * InpTPMultiplier;
      double lot = CalcLot(ask - sl);
      if(!g_Trade.Buy(lot, _Symbol, ask, sl, tp, comment))
         Print("QS Buy error: ", GetLastError(), " / ", g_Trade.ResultComment());
   }
   else
   {
      double sl  = bid + atrVal * InpSLMultiplier;
      double tp  = bid - atrVal * InpTPMultiplier;
      double lot = CalcLot(sl - bid);
      if(!g_Trade.Sell(lot, _Symbol, bid, sl, tp, comment))
         Print("QS Sell error: ", GetLastError(), " / ", g_Trade.ResultComment());
   }
}

void ManageOpenPositions()
{
   double atr[1];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_ATRHandle, 0, 0, 1, atr) < 1) return;
   double atrVal = atr[0];

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if((long)PositionGetInteger(POSITION_MAGIC) != MAGIC_QS) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPx = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);
      double newSL  = curSL;

      if(ptype == POSITION_TYPE_BUY)
      {
         if(InpUseBreakeven && bid >= openPx + atrVal * InpBEMultiplier)
            if(curSL < openPx) newSL = openPx + _Point;

         if(InpUseTrailing)
         {
            double trailLevel = bid - atrVal * InpTrailATR;
            if(trailLevel > newSL) newSL = trailLevel;
         }
         if(newSL > curSL && newSL < bid - _Point)
            g_Trade.PositionModify(ticket, newSL, curTP);
      }
      else // SELL
      {
         if(InpUseBreakeven && ask <= openPx - atrVal * InpBEMultiplier)
            if(curSL == 0.0 || curSL > openPx) newSL = openPx - _Point;

         if(InpUseTrailing)
         {
            double trailLevel = ask + atrVal * InpTrailATR;
            if(curSL == 0.0 || trailLevel < newSL) newSL = trailLevel;
         }
         if((newSL < curSL || curSL == 0.0) && newSL > ask + _Point)
            g_Trade.PositionModify(ticket, newSL, curTP);
      }
   }
}

//══════════════════════════════════════════════════════════════════════════════
//  DISPLAY PANEL
//══════════════════════════════════════════════════════════════════════════════

string PN(string s) { return PANEL_PREFIX + s; }

void MakeRect(string name, int x, int y, int w, int h,
              color bg, color border = clrNONE)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,    x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,    y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE,        w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE,        h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,      bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border == clrNONE ? bg : border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE,  BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, name, OBJPROP_BACK,         false);
}

void MakeLabel(string name, int x, int y, string txt,
               color clr, int sz, string font = "Consolas")
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0,  name, OBJPROP_TEXT,      txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  sz);
   ObjectSetString(0,  name, OBJPROP_FONT,      font);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_BACK,      false);
}

void SetText(string name, string txt) { ObjectSetString(0,  name, OBJPROP_TEXT,  txt); }
void SetClr(string  name, color  clr) { ObjectSetInteger(0, name, OBJPROP_COLOR, clr); }
void SetW(string    name, int    w)   { ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1,w)); }

//+------------------------------------------------------------------+
void BuildPanel()
{
   int px = InpPanelX, py = InpPanelY;
   int W  = PANEL_W,   H  = PANEL_H;

   // ── Outer shell ──────────────────────────────────────────────────
   MakeRect(PN("BG"),  px,   py,   W,   H,   COL_BG,  COL_ACCENT);

   // ── Header bar ───────────────────────────────────────────────────
   MakeRect(PN("HDR"), px,   py,   W,   36,  COL_HDR, COL_ACCENT);
   MakeLabel(PN("TITLE"), px+10, py+6,  "QUANTUM SYNTHESIS", COL_ACCENT,  10, "Arial Black");
   MakeLabel(PN("SUBTT"), px+10, py+21, "Pattern Intelligence Engine", COL_DIM, 7);

   // ── Scanner animation row ─────────────────────────────────────────
   MakeLabel(PN("SCN_LBL"), px+10, py+44, "SCAN STATUS", COL_DIM, 7);
   MakeLabel(PN("SCN_ANI"), px+10, py+55, "[ | ] BOOTING SCANNER...", COL_ACCENT, 8);

   // ── Pattern result box ───────────────────────────────────────────
   MakeRect(PN("PAT_BG"),   px+6,  py+76,  W-12, 44, COL_INSET, COL_ACCENT);
   MakeLabel(PN("PAT_HDR"), px+12, py+80,  "PATTERN DETECTED", COL_DIM, 7);
   MakeLabel(PN("PAT_NM"),  px+12, py+92,  "INITIALISING...",   COL_TEXT, 9);
   MakeLabel(PN("PAT_DIR"), px+192,py+92,  "---",               COL_ACCENT, 9);

   // ── Confidence bar ───────────────────────────────────────────────
   MakeLabel(PN("CF_LBL"),  px+10, py+128, "CONFIDENCE", COL_DIM, 7);
   MakeRect(PN("CF_TRACK"), px+10, py+140, W-20, 10, C'18,28,48', COL_ACCENT);
   MakeRect(PN("CF_FILL"),  px+10, py+140, 1,    10, COL_ACCENT,  COL_ACCENT);
   MakeLabel(PN("CF_PCT"),  px+10, py+153, "0%", COL_ACCENT, 8);

   // ── Signal display ───────────────────────────────────────────────
   MakeRect(PN("SIG_BG"),   px+6,  py+170, W-12, 38, COL_INSET, clrNONE);
   MakeLabel(PN("SIG_LBL"), px+12, py+174, "TRADE SIGNAL", COL_DIM, 7);
   MakeLabel(PN("SIG_VAL"), px+12, py+185, "SCANNING...",  COL_DIM, 11, "Arial Black");

   // ── Divider ──────────────────────────────────────────────────────
   MakeRect(PN("DIV"),      px+6,  py+214, W-12, 1, COL_ACCENT, COL_ACCENT);

   // ── Live stats grid ──────────────────────────────────────────────
   MakeLabel(PN("POS_L"),   px+10, py+222, "POSITIONS",    COL_DIM,    7);
   MakeLabel(PN("POS_V"),   px+94, py+222, "0/0",          COL_TEXT,   8);

   MakeLabel(PN("SIG_L"),   px+10, py+235, "SIGNALS TODAY",COL_DIM,    7);
   MakeLabel(PN("SIG_C"),   px+108,py+235, "0",            COL_ACCENT, 8);

   MakeLabel(PN("BAL_L"),   px+10, py+248, "BALANCE",      COL_DIM,    7);
   MakeLabel(PN("BAL_V"),   px+72, py+248, "---",          COL_TEXT,   8);

   MakeLabel(PN("EQ_L"),    px+10, py+261, "EQUITY",       COL_DIM,    7);
   MakeLabel(PN("EQ_V"),    px+72, py+261, "---",          COL_TEXT,   8);

   MakeLabel(PN("PNL_L"),   px+10, py+274, "OPEN P&L",     COL_DIM,    7);
   MakeLabel(PN("PNL_V"),   px+80, py+274, "+0.00",        COL_DIM,    8);

   // ── Footer ───────────────────────────────────────────────────────
   MakeRect(PN("FTR"), px, py+H-22, W, 22, COL_FTR, COL_ACCENT);
   MakeLabel(PN("FTR_T"), px+10, py+H-16,
             "quantum-synthesis.com  |  " + _Symbol + " " + EnumToString(Period()),
             COL_DIM, 6);

   ChartRedraw(0);
}

void DeletePanel()
{
   ObjectsDeleteAll(0, PANEL_PREFIX);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Called by timer — spinning scanner + live account data           |
//+------------------------------------------------------------------+
void AnimatePanel()
{
   // Spinner
   string spin = SCAN_CHARS[g_ScanFrame];
   string aniTxt = (g_LastPattern == PAT_NONE)
                   ? "[ " + spin + " ]  SCANNING PATTERNS..."
                   : "[ " + spin + " ]  PATTERN LOCKED ON";
   SetText(PN("SCN_ANI"), aniTxt);

   // Account
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   SetText(PN("BAL_V"), DoubleToString(bal, 2));
   SetText(PN("EQ_V"),  DoubleToString(eq,  2));

   // Positions
   int pos = CountMyPositions();
   SetText(PN("POS_V"), StringFormat("%d / %d", pos, InpMaxPositions));

   // Signal count
   SetText(PN("SIG_C"), (string)g_TotalSignals);

   // Floating P&L
   double pnl = 0.0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      PositionGetTicket(i);
      if((long)PositionGetInteger(POSITION_MAGIC) == MAGIC_QS &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         pnl += PositionGetDouble(POSITION_PROFIT);
   }
   SetText(PN("PNL_V"), StringFormat("%+.2f", pnl));
   SetClr(PN("PNL_V"), pnl > 0.001 ? COL_BULL : pnl < -0.001 ? COL_BEAR : COL_DIM);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Called on new bar — update pattern info                          |
//+------------------------------------------------------------------+
void UpdatePanelData()
{
   int trackW = PANEL_W - 20;   // 266 px

   if(g_LastPattern == PAT_NONE)
   {
      SetText(PN("PAT_NM"),  "NO SETUP FOUND");
      SetClr(PN("PAT_NM"),   COL_DIM);
      SetText(PN("PAT_DIR"), "---");
      SetClr(PN("PAT_DIR"),  COL_ACCENT);
      SetW(PN("CF_FILL"),    1);
      SetText(PN("CF_PCT"),  "0%");
      SetClr(PN("CF_PCT"),   COL_DIM);
      SetText(PN("SIG_VAL"), "SCANNING...");
      SetClr(PN("SIG_VAL"),  COL_DIM);
      return;
   }

   // Pattern name
   SetText(PN("PAT_NM"), PATTERN_NAMES[g_LastPattern]);

   // Direction + signal
   if(g_LastSignal == SIG_BUY)
   {
      SetText(PN("PAT_DIR"), "LONG");
      SetClr(PN("PAT_DIR"),  COL_BULL);
      SetClr(PN("PAT_NM"),   COL_BULL);
      SetText(PN("SIG_VAL"), "   BUY SIGNAL");
      SetClr(PN("SIG_VAL"),  COL_BULL);
   }
   else
   {
      SetText(PN("PAT_DIR"), "SHORT");
      SetClr(PN("PAT_DIR"),  COL_BEAR);
      SetClr(PN("PAT_NM"),   COL_BEAR);
      SetText(PN("SIG_VAL"), "   SELL SIGNAL");
      SetClr(PN("SIG_VAL"),  COL_BEAR);
   }

   // Confidence bar fill
   int fillW = (int)MathRound((double)trackW * g_LastConf / 100.0);
   SetW(PN("CF_FILL"), fillW);
   SetText(PN("CF_PCT"), StringFormat("%d%%", g_LastConf));

   color confClr = g_LastConf >= 80 ? COL_BULL :
                   g_LastConf >= 60 ? COL_ACCENT : COL_DIM;
   SetClr(PN("CF_PCT"),    confClr);
   SetClr(PN("CF_FILL"),   confClr);

   ChartRedraw(0);
}
//+------------------------------------------------------------------+
