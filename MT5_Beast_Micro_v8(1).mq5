//+------------------------------------------------------------------+
//|                                      MT5_Beast_Micro_v8.mq5     |
//|                                   N3onhex — v8.0 SMART BEAST     |
//|  Рынки: XAUUSD (Gold) PRIMARY | EURUSD | GBPUSD | BTCUSD        |
//|                                                                  |
//|  НОВОЕ в v8.0:                                                   |
//|   ✅ Умный трейлинг-стоп: 4-фазный (шаг→сужение→зажим→рывок)   |
//|   ✅ Автоматический подъём SL — каждый тик, без задержки        |
//|   ✅ Мульти-символ с авто-определением параметров               |
//|   ✅ Улучшенный детектор импульсов (скорость + объём + ATR)     |
//|   ✅ Адаптивный лот по балансу ($23→$5000 auto-scale)           |
//|   ✅ Умный пирамидинг: добавляет лоты только по тренду          |
//|   ✅ EMA-ribbon (21/50/200) — быстрый фильтр направления        |
//|   ✅ RSI-дивергенция для ранних выходов                         |
//|   ✅ Канальный трейлинг (Donchian-based) для Gold               |
//|   ✅ Улучшенный детектор новостей (кулдаун перед/после NFP)     |
//|   ✅ Панель v8 с отображением стадии, DD, скоринга              |
//+------------------------------------------------------------------+
#property copyright "N3onhex"
#property link      "https://github.com/n3onhex"
#property version   "8.00"
#property description "BEAST MICRO v8 — Gold PRIMARY | EURUSD | GBPUSD | BTC"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//=================================================================
//  ВХОДНЫЕ ПАРАМЕТРЫ
//=================================================================

input group "════════ ИНСТРУМЕНТ ════════"
input string   Inp_Symbol           = "";       // Символ (пусто = текущий)
input int      Inp_Magic             = 88800;   // Магический номер

input group "════════ ТАЙМФРЕЙМЫ ════════"
input ENUM_TIMEFRAMES Inp_TF_Entry   = PERIOD_M5;
input ENUM_TIMEFRAMES Inp_TF_Trend   = PERIOD_H1;
input ENUM_TIMEFRAMES Inp_TF_Confirm = PERIOD_M15;
input ENUM_TIMEFRAMES Inp_TF_HTF     = PERIOD_H4;

input group "════════ СЕССИИ ════════"
input bool     Inp_UseSessions       = false;
input int      Inp_London_Start      = 7;
input int      Inp_London_End        = 17;
input int      Inp_NewYork_Start     = 13;
input int      Inp_NewYork_End       = 22;
input bool     Inp_TradeAsia         = true;
input int      Inp_Asia_Start        = 0;
input int      Inp_Asia_End          = 8;

input group "════════ БАЗОВЫЙ РИСК ════════"
input double   Inp_BaseRiskPct       = 1.5;    // Риск на сделку % (1.5% — безопасно для $23)
input double   Inp_MaxDailyLoss      = 5.0;    // Макс. дневной убыток %
input double   Inp_MaxDailyProfit    = 12.0;   // Дневная цель %
input double   Inp_WeeklyDrawdown    = 12.0;   // Макс. недельный DD %
// Спреды по инструментам (пипсы * 10 для 5-значных)
input int      Inp_MaxSpread_Gold    = 45;     // Gold макс. спред (pts)
input int      Inp_MaxSpread_Forex   = 20;     // EUR/GBP макс. спред (pts)
input int      Inp_MaxSpread_BTC     = 8000;   // BTC макс. спред (pts)

input group "════════ СКЕЙЛИНГ ЛОТА ($23→$5000) ════════"
input double   Inp_Scale_L1_Balance  = 50.0;
input double   Inp_Scale_L1_Mult     = 1.0;
input double   Inp_Scale_L2_Balance  = 100.0;
input double   Inp_Scale_L2_Mult     = 1.2;
input double   Inp_Scale_L3_Balance  = 200.0;
input double   Inp_Scale_L3_Mult     = 1.5;
input double   Inp_Scale_L4_Balance  = 500.0;
input double   Inp_Scale_L4_Mult     = 1.8;
input double   Inp_Scale_L5_Balance  = 1000.0;
input double   Inp_Scale_L5_Mult     = 2.2;
input bool     Inp_AggressiveWinStrk = true;
input int      Inp_WinStreak_Trigger = 3;
input double   Inp_WinStreak_Mult    = 1.20;

input group "════════ ПИРАМИДИНГ ════════"
input bool     Inp_Pyramiding        = true;
input int      Inp_MaxPyramidLevels  = 2;
input double   Inp_Pyramid_ATR_Step  = 1.2;
input double   Inp_PyramidRiskMult   = 0.65;
input bool     Inp_ReducePyramidRisk = true;
input int      Inp_MaxTotalPositions = 3;

input group "════════ ATR ════════"
input int      Inp_ATR_Period        = 14;
input double   Inp_SL_ATR_Gold       = 1.3;   // SL Gold: чуть больше для волатильности
input double   Inp_SL_ATR_Forex      = 1.1;   // SL Forex: меньше
input double   Inp_SL_ATR_BTC        = 1.5;
input double   Inp_TP1_ATR           = 1.0;   // TP1 — 25% позиции
input double   Inp_TP2_ATR           = 2.2;   // TP2 — 45% позиции
input double   Inp_TP3_ATR           = 5.0;   // TP3 — 30% (ранер)
input double   Inp_TP_Breakout_ATR   = 7.0;
// ТРЕЙЛИНГ — 4 фазы (Gold оптимизирован под высокую волатильность)
input double   Inp_Trail_Phase1_ATR  = 0.8;   // Фаза 1: прибыль <1 ATR
input double   Inp_Trail_Phase2_ATR  = 0.6;   // Фаза 2: прибыль 1-2 ATR
input double   Inp_Trail_Phase3_ATR  = 0.4;   // Фаза 3: прибыль 2-3 ATR
input double   Inp_Trail_Phase4_ATR  = 0.25;  // Фаза 4: прибыль >3 ATR (зажим)

input group "════════ БЕЗУБЫТОК ════════"
input bool     Inp_SmartBE           = true;
input double   Inp_BE_ATR_Trigger    = 0.7;   // BE когда профит >= N×ATR
input double   Inp_BE_Buffer_Pts     = 5.0;   // Буфер BE в пунктах (спред + немного)

input group "════════ BOLLINGER BANDS ════════"
input int      Inp_BB_Period         = 20;
input double   Inp_BB_Dev            = 2.0;
input bool     Inp_UseBBSqueeze      = true;
input double   Inp_BB_SqueezePct     = 0.30;  // v8: чуть уже для лучших сжатий

input group "════════ STOCHASTIC ════════"
input bool     Inp_UseStoch          = true;
input int      Inp_Stoch_K           = 5;
input int      Inp_Stoch_D           = 3;
input int      Inp_Stoch_Slow        = 3;

input group "════════ RSI / MACD ════════"
input bool     Inp_UseRSI            = true;
input int      Inp_RSI_Period        = 8;
input bool     Inp_UseMACD           = true;
input int      Inp_MACD_Fast         = 8;
input int      Inp_MACD_Slow         = 21;
input int      Inp_MACD_Sig          = 5;

input group "════════ ИМПУЛЬС v8 ════════"
input int      Inp_BodyPct           = 52;    // Мин. тело % (снижено с 55 для чуткости)
input int      Inp_MinPts_Gold       = 8;     // Мин. размер Gold (снижено — ловим мелкие)
input int      Inp_MinPts_Forex      = 5;     // Мин. размер Forex
input int      Inp_MinPts_BTC        = 50;
// Детектор ускорения: свеча[1] > свеча[2] по размеру = подтверждение
input bool     Inp_UseAcceleration   = true;  // Фильтр ускорения свечей
// Объёмный порог для Gold-импульса
input double   Inp_VolSpike_Gold     = 1.4;   // Gold: объём > предыдущего × N
input double   Inp_VolSpike_Forex    = 1.2;   // Forex: чуть ниже

input group "════════ ПРОБОЙ ════════"
input bool     Inp_UseBreakout       = true;
input int      Inp_BO_Lookback       = 20;
input double   Inp_BO_Confirm_ATR    = 0.15;  // v8: снижено для чуткости
input bool     Inp_UseTickBO         = true;
input int      Inp_TickBO_Pts_Gold   = 70;    // v8: снижено с 80
input int      Inp_TickBO_Pts_Forex  = 15;
input int      Inp_TickBO_Pts_BTC    = 300;
input long     Inp_TickBO_Ms         = 1500;

input group "════════ СВИНГ-СТОП ════════"
input bool     Inp_UseSwingSL        = true;
input int      Inp_SwingLookback     = 8;

input group "════════ MARKET STRUCTURE ════════"
input bool     Inp_UseMarketStr      = true;
input int      Inp_MSLookback        = 20;

input group "════════ ЗАЩИТА КАПИТАЛА ════════"
input int      Inp_ConsecutiveLoss   = 3;
input double   Inp_RecoveryRiskPct   = 0.8;   // Recovery: снижен с 1% до 0.8%
input double   Inp_MaxDD_Equity      = 18.0;
input bool     Inp_EquityCurveProt   = true;

input group "════════ DONCHIAN КАНАЛ (Gold) ════════"
input bool     Inp_UseDonchianTrail  = true;  // Доnchan трейлинг для Gold
input int      Inp_Donchian_Period   = 10;    // Период канала

//=================================================================
//  СТРУКТУРЫ
//=================================================================

struct TickData
{
   long   time_msc;
   double bid;
   double ask;
};

struct PyramidLevel
{
   ulong  ticket;
   int    level;
   double open_price;
   double sl;
   double tp;
   bool   tp1_done;
   bool   tp2_done;
   bool   be_done;
};

struct DayStats
{
   double start_equity;
   double peak_equity;
   int    wins;
   int    losses;
   int    win_streak;
   int    loss_streak;
   double realized_pnl;
};

// Тип инструмента
enum SYMBOL_TYPE { SYM_GOLD, SYM_BTC, SYM_FOREX_MAJOR, SYM_OTHER };

//=================================================================
//  ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
//=================================================================

CTrade        g_trade;
CPositionInfo g_pos;

string      g_sym          = "";
double      g_point        = 0.0;
SYMBOL_TYPE g_symtype      = SYM_OTHER;
bool        g_is_gold      = false;
bool        g_is_btc       = false;
bool        g_is_forex     = false;
int         g_digits       = 5;

// Индикаторы Entry TF
int h_ema200_e=INVALID_HANDLE, h_ema50_e=INVALID_HANDLE;
int h_ema21_e=INVALID_HANDLE,  h_atr_e=INVALID_HANDLE;
int h_rsi_e=INVALID_HANDLE,    h_macd_e=INVALID_HANDLE;
int h_bb_e=INVALID_HANDLE,     h_stoch_e=INVALID_HANDLE;
int h_vol_e=INVALID_HANDLE;
int h_don_hi=INVALID_HANDLE,   h_don_lo=INVALID_HANDLE; // Donchian

// Индикаторы Trend TF (H1)
int h_ema200_t=INVALID_HANDLE, h_ema50_t=INVALID_HANDLE;
int h_atr_t=INVALID_HANDLE,    h_macd_t=INVALID_HANDLE;
int h_rsi_t=INVALID_HANDLE;

// Confirm TF (M15)
int h_ema50_c=INVALID_HANDLE, h_rsi_c=INVALID_HANDLE;

// HTF (H4)
int h_ema200_h=INVALID_HANDLE, h_ema50_h=INVALID_HANDLE;

// Тик-буфер
TickData  g_ticks[3000];
int       g_tcnt=0, g_thead=0;
long      g_last_msc=0;

// Дневной контроль
DayStats  g_day;
bool      g_disabled=false;
int       g_last_day=-1;
int       g_last_week=-1;
double    g_week_start_eq=0;

// Эквити
double    g_equity_peak=0;

// Серии
int       g_consec_loss=0;
int       g_consec_win=0;
bool      g_recovery=false;

// Кулдаун
datetime  g_last_entry=0;
int       g_base_cooldown=18;   // v8: снижено до 18 сек

// Пирамидинг
PyramidLevel g_pyramid[5];
int          g_pyramid_cnt=0;

// Панель
bool     g_running         = true;
bool     g_indic_added     = false;
datetime g_last_chart_draw = 0;
int      g_chart_draw_sec  = 30;

// Скоринг последнего сигнала (для панели)
int      g_last_score      = 0;

// Объект-имена
#define N3P          "N8_"
#define BTN_SS       N3P"BTN_SS"
#define OBJ_PANEL    N3P"PANEL"
#define LBL_TITLE    N3P"TITLE"
#define LBL_STATUS   N3P"STATUS"
#define LBL_BAL      N3P"BAL"
#define LBL_EQ       N3P"EQ"
#define LBL_STAGE    N3P"STAGE"
#define LBL_RISK     N3P"RISK"
#define LBL_WL       N3P"WL"
#define LBL_POS      N3P"POS"
#define LBL_SCORE    N3P"SCORE"
#define LBL_DD       N3P"DD"
#define PFX_FIB      N3P"FIB_"
#define PFX_SR       N3P"SR_"
#define PFX_TL       N3P"TL_"
#define PFX_MS       N3P"MS_"
#define PFX_SES      N3P"SES_"
#define PFX_ATR      N3P"ATR_"

//=================================================================
//  ТИК-БУФЕР
//=================================================================

void TBuf_Add(const MqlTick &t)
{
   int i = g_tcnt % 3000;
   g_ticks[i].time_msc = t.time_msc;
   g_ticks[i].bid      = t.bid;
   g_ticks[i].ask      = t.ask;
   g_tcnt++;
   g_thead = (g_tcnt > 3000) ? (g_tcnt % 3000) : 0;
}

int      TBuf_Total() { return MathMin(g_tcnt, 3000); }
TickData TBuf_At(int p) { return g_ticks[(g_thead + p) % 3000]; }

//=================================================================
//  OnInit
//=================================================================

int OnInit()
{
   g_sym    = (Inp_Symbol == "") ? _Symbol : Inp_Symbol;
   g_digits = (int)SymbolInfoInteger(g_sym, SYMBOL_DIGITS);

   // Определяем тип инструмента
   string su = g_sym; StringToUpper(su);
   g_is_gold  = (StringFind(su,"XAU")>=0 || StringFind(su,"GOLD")>=0);
   g_is_btc   = (StringFind(su,"BTC")>=0 || StringFind(su,"XBT")>=0);
   g_is_forex = (!g_is_gold && !g_is_btc &&
                 (StringFind(su,"EUR")>=0 || StringFind(su,"GBP")>=0 ||
                  StringFind(su,"USD")>=0 || StringFind(su,"JPY")>=0 ||
                  StringFind(su,"CHF")>=0 || StringFind(su,"AUD")>=0 ||
                  StringFind(su,"CAD")>=0 || StringFind(su,"NZD")>=0));

   if      (g_is_gold)  g_symtype = SYM_GOLD;
   else if (g_is_btc)   g_symtype = SYM_BTC;
   else if (g_is_forex) g_symtype = SYM_FOREX_MAJOR;
   else                 g_symtype = SYM_OTHER;

   g_trade.SetExpertMagicNumber(Inp_Magic);
   g_trade.SetDeviationInPoints(200);
   g_trade.SetTypeFilling(GetFilling(g_sym));
   g_trade.SetAsyncMode(false);

   g_point = SymbolInfoDouble(g_sym, SYMBOL_POINT);
   if (g_point == 0.0) { Print("[FAIL] Point=0"); return INIT_FAILED; }

   // === ENTRY TF ===
   h_ema200_e = iMA(g_sym,Inp_TF_Entry,200,0,MODE_EMA,PRICE_CLOSE);
   h_ema50_e  = iMA(g_sym,Inp_TF_Entry,50, 0,MODE_EMA,PRICE_CLOSE);
   h_ema21_e  = iMA(g_sym,Inp_TF_Entry,21, 0,MODE_EMA,PRICE_CLOSE);
   h_atr_e    = iATR(g_sym,Inp_TF_Entry,Inp_ATR_Period);
   h_rsi_e    = iRSI(g_sym,Inp_TF_Entry,Inp_RSI_Period,PRICE_CLOSE);
   h_macd_e   = iMACD(g_sym,Inp_TF_Entry,Inp_MACD_Fast,Inp_MACD_Slow,Inp_MACD_Sig,PRICE_CLOSE);
   h_bb_e     = iBands(g_sym,Inp_TF_Entry,Inp_BB_Period,0,Inp_BB_Dev,PRICE_CLOSE);
   h_stoch_e  = iStochastic(g_sym,Inp_TF_Entry,Inp_Stoch_K,Inp_Stoch_D,Inp_Stoch_Slow,MODE_SMA,STO_LOWHIGH);
   h_vol_e    = iVolumes(g_sym,Inp_TF_Entry,VOLUME_TICK);
   // Donchian для Gold
   h_don_hi   = iHighest(g_sym,Inp_TF_Entry,MODE_HIGH,Inp_Donchian_Period,1);
   h_don_lo   = iLowest (g_sym,Inp_TF_Entry,MODE_LOW, Inp_Donchian_Period,1);

   // === TREND TF ===
   h_ema200_t = iMA(g_sym,Inp_TF_Trend,200,0,MODE_EMA,PRICE_CLOSE);
   h_ema50_t  = iMA(g_sym,Inp_TF_Trend,50, 0,MODE_EMA,PRICE_CLOSE);
   h_atr_t    = iATR(g_sym,Inp_TF_Trend,Inp_ATR_Period);
   h_macd_t   = iMACD(g_sym,Inp_TF_Trend,Inp_MACD_Fast,Inp_MACD_Slow,Inp_MACD_Sig,PRICE_CLOSE);
   h_rsi_t    = iRSI(g_sym,Inp_TF_Trend,Inp_RSI_Period,PRICE_CLOSE);

   // === CONFIRM TF ===
   h_ema50_c  = iMA(g_sym,Inp_TF_Confirm,50,0,MODE_EMA,PRICE_CLOSE);
   h_rsi_c    = iRSI(g_sym,Inp_TF_Confirm,Inp_RSI_Period,PRICE_CLOSE);

   // === HTF ===
   h_ema200_h = iMA(g_sym,Inp_TF_HTF,200,0,MODE_EMA,PRICE_CLOSE);
   h_ema50_h  = iMA(g_sym,Inp_TF_HTF,50, 0,MODE_EMA,PRICE_CLOSE);

   // Валидация (Donchian — не критичен)
   if (h_ema200_e==INVALID_HANDLE || h_ema50_e==INVALID_HANDLE ||
       h_ema21_e ==INVALID_HANDLE || h_atr_e  ==INVALID_HANDLE ||
       h_rsi_e   ==INVALID_HANDLE || h_macd_e ==INVALID_HANDLE ||
       h_bb_e    ==INVALID_HANDLE || h_stoch_e==INVALID_HANDLE ||
       h_ema200_t==INVALID_HANDLE || h_ema50_t==INVALID_HANDLE ||
       h_atr_t   ==INVALID_HANDLE || h_macd_t ==INVALID_HANDLE ||
       h_rsi_t   ==INVALID_HANDLE || h_ema50_c==INVALID_HANDLE ||
       h_rsi_c   ==INVALID_HANDLE || h_ema200_h==INVALID_HANDLE ||
       h_ema50_h ==INVALID_HANDLE)
   {
      PrintFormat("[FAIL] Индикатор не инициализирован: %d", GetLastError());
      return INIT_FAILED;
   }

   g_day.start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_day.peak_equity  = g_day.start_equity;
   g_equity_peak      = g_day.start_equity;
   g_week_start_eq    = g_day.start_equity;

   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   g_last_day  = dt.day;
   g_last_week = dt.day_of_week;

   ZeroMemory(g_pyramid);
   g_pyramid_cnt = 0;

   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   PrintFormat("════ EA v8 SMART BEAST ════");
   PrintFormat("Счёт: %s | Bal: %.2f | Eq: %.2f",
               mode==ACCOUNT_TRADE_MODE_REAL?"!!! РЕАЛЬНЫЙ !!!":"DEMO",
               AccountInfoDouble(ACCOUNT_BALANCE),
               AccountInfoDouble(ACCOUNT_EQUITY));
   PrintFormat("Символ: %s [%s] | Point: %.5f | Digits: %d",
               g_sym, SymTypeStr(), g_point, g_digits);
   PrintFormat("SL_ATR: %.1f | Trail: %.2f/%.2f/%.2f/%.2f | Cooldown: %d",
               GetSL_ATR_Mult(),
               Inp_Trail_Phase1_ATR, Inp_Trail_Phase2_ATR,
               Inp_Trail_Phase3_ATR, Inp_Trail_Phase4_ATR,
               g_base_cooldown);

   EventSetTimer(60);
   DrawPanel();
   RedrawAll();
   return INIT_SUCCEEDED;
}

//=================================================================
//  OnDeinit
//=================================================================

void OnDeinit(const int reason)
{
   EventKillTimer();
   int handles[] = {
      h_ema200_e, h_ema50_e, h_ema21_e, h_atr_e, h_rsi_e, h_macd_e,
      h_bb_e, h_stoch_e, h_vol_e, h_don_hi, h_don_lo,
      h_ema200_t, h_ema50_t, h_atr_t, h_macd_t, h_rsi_t,
      h_ema50_c, h_rsi_c, h_ema200_h, h_ema50_h
   };
   for (int i=0; i<ArraySize(handles); i++)
      if (handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);

   DeleteObjects(N3P);
   PrintFormat("════ EA v8 Стоп | Причина: %d | W:%d L:%d ════",
               reason, g_day.wins, g_day.losses);
}

//=================================================================
//  OnTimer
//=================================================================

void OnTimer()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   MqlTick t; SymbolInfoTick(g_sym, t);
   double spread = (t.ask - t.bid) / g_point;
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double dd  = (g_equity_peak > 0) ? (g_equity_peak - eq) / g_equity_peak * 100.0 : 0;
   int trend  = GetTrend();
   int ms     = GetMarketStructure();

   PrintFormat("[v8 ДИАГН] %02d:%02d | Bal=%.2f Eq=%.2f DD=%.1f%% | Поз=%d/%d | Спред=%.0f | Trend=%d MS=%d | %s | %s",
               dt.hour, dt.min, bal, eq, dd,
               CountPos(), GetDynamicMaxPositions(),
               spread, trend, ms,
               GetGrowthStage(),
               g_disabled?"СТОП":(g_running?"АКТИВЕН":"ПАУЗА"));
}

//=================================================================
//  OnTick — ГЛАВНАЯ ЛОГИКА
//=================================================================

void OnTick()
{
   MqlTick tick;
   if (!SymbolInfoTick(g_sym, tick)) return;

   // Периодическая перерисовка
   if (TimeCurrent() - g_last_chart_draw >= g_chart_draw_sec)
      RedrawAll();
   else
      UpdatePanel();

   if (tick.time_msc > g_last_msc)
   { TBuf_Add(tick); g_last_msc = tick.time_msc; }

   // Дневной/недельный сброс
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   if (dt.day != g_last_day) DailyReset(dt);
   if (dt.day_of_week < g_last_week || (dt.day_of_week==1 && g_last_week!=1))
      WeeklyReset();

   if (g_disabled) return;

   if (!g_running)
   {
      int pc = CountPos();
      if (pc > 0) { SyncPyramidState(); ManageAllPositions(); }
      return;
   }

   double cur_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_day.peak_equity = MathMax(g_day.peak_equity, cur_eq);
   g_equity_peak     = MathMax(g_equity_peak, cur_eq);

   // === ЗАЩИТА ДНЕВНАЯ ===
   if (cur_eq < g_day.start_equity * (1.0 - Inp_MaxDailyLoss/100.0))
   {
      PrintFormat("[СТОП] Дневной убыток >%.0f%% | Eq=%.2f", Inp_MaxDailyLoss, cur_eq);
      g_disabled = true; CloseAll(); return;
   }
   if (Inp_MaxDailyProfit>0 && cur_eq > g_day.start_equity*(1.0+Inp_MaxDailyProfit/100.0))
   {
      PrintFormat("[ЦЕЛЬ] +%.0f%% за день! Фиксируем.", Inp_MaxDailyProfit);
      g_disabled = true; CloseAll(); return;
   }

   // === ЗАЩИТА EQUITY CURVE ===
   if (Inp_EquityCurveProt && g_equity_peak > 0)
   {
      double dd = (g_equity_peak - cur_eq) / g_equity_peak * 100.0;
      if (dd > Inp_MaxDD_Equity)
      {
         PrintFormat("[DD ЗАЩИТА] %.1f%% от пика %.2f", dd, g_equity_peak);
         g_disabled = true; CloseAll(); return;
      }
   }

   // === ЗАЩИТА НЕДЕЛЬНАЯ ===
   if (Inp_WeeklyDrawdown > 0)
   {
      double wdd = (g_week_start_eq - cur_eq) / g_week_start_eq * 100.0;
      if (wdd > Inp_WeeklyDrawdown)
      {
         PrintFormat("[НЕДЕЛЯ СТОП] DD=%.1f%%", wdd);
         g_disabled = true; CloseAll(); return;
      }
   }

   // Фильтр сессий
   if (Inp_UseSessions && !IsActiveSession(dt.hour)) return;

   // Спред-фильтр
   double spread = (tick.ask - tick.bid) / g_point;
   if (spread > GetMaxSpread()) return;

   // Маржа-фильтр
   double free_m = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   if (bal > 0 && free_m < bal * 0.15) { Print("[ПРОПУСК] Маржа<15%"); return; }

   int pos_cnt = CountPos();

   // === УПРАВЛЕНИЕ ПОЗИЦИЯМИ (каждый тик!) ===
   if (pos_cnt > 0)
   {
      SyncPyramidState();
      ManageAllPositions();
   }

   // === НОВЫЙ ВХОД ===
   if (pos_cnt < GetDynamicMaxPositions())
   {
      int cooldown = CalcCooldown();
      if (TimeCurrent() - g_last_entry < cooldown) return;

      if (Inp_UseTickBO   && TryTickBreakout())   return;
      if (Inp_UseBreakout && TryCandleBreakout())  return;
      if (Inp_UseBBSqueeze && TryBBBreakout())     return;
      TryImpulse();

      if (Inp_Pyramiding && pos_cnt >= 1)
         TryAddPyramidLevel();
   }
}

//=================================================================
//  ДНЕВНОЙ / НЕДЕЛЬНЫЙ СБРОС
//=================================================================

void DailyReset(const MqlDateTime &dt)
{
   double now = AccountInfoDouble(ACCOUNT_EQUITY);
   double pnl = now - g_day.start_equity;
   if (pnl < 0) { g_consec_loss++; g_consec_win=0; }
   else         { g_consec_win++;  g_consec_loss=0; }
   g_recovery = (g_consec_loss >= Inp_ConsecutiveLoss);
   g_day.start_equity = now;
   g_day.peak_equity  = now;
   g_day.wins         = 0;
   g_day.losses       = 0;
   g_day.realized_pnl = 0;
   g_disabled         = false;
   g_last_day         = dt.day;
   ZeroMemory(g_pyramid);
   g_pyramid_cnt = 0;
   PrintFormat("══ Новый день %d.%d | Eq:%.2f | PnL:%.2f | WS:%d LS:%d ══",
               dt.day, dt.mon, now, pnl, g_consec_win, g_consec_loss);
}

void WeeklyReset()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   g_week_start_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   g_last_week     = dt.day_of_week;
   PrintFormat("══ Новая неделя | Start Eq: %.2f ══", g_week_start_eq);
}

//=================================================================
//  ИНДИКАТОРЫ — ХЕЛПЕРЫ
//=================================================================

double Ind(int h, int buf=0, int shift=0)
{
   double b[1];
   if (CopyBuffer(h, buf, shift, 1, b) < 1) return 0.0;
   return b[0];
}

double IndArr(int h, int buf, int shift)
{
   double b[]; ArraySetAsSeries(b, true);
   if (CopyBuffer(h, buf, 0, shift+2, b) < shift+2) return 0.0;
   return b[shift];
}

double EMA200e()  { return Ind(h_ema200_e); }
double EMA50e()   { return Ind(h_ema50_e);  }
double EMA21e()   { return Ind(h_ema21_e);  }
double ATRe()     { return Ind(h_atr_e);    }
double RSIe()     { return Ind(h_rsi_e);    }
double RSIe1()    { return IndArr(h_rsi_e, 0, 1); }  // RSI предыдущий для дивергенции
double MACDm()    { return Ind(h_macd_e, 0); }
double MACDs()    { return Ind(h_macd_e, 1); }
double MACDm1()   { return IndArr(h_macd_e, 0, 1); }
double MACDs1()   { return IndArr(h_macd_e, 1, 1); }
double BBup()     { return Ind(h_bb_e, 1);  }
double BBlo()     { return Ind(h_bb_e, 2);  }
double BBmid()    { return Ind(h_bb_e, 0);  }
double StochK()   { return Ind(h_stoch_e, 0); }
double StochD()   { return Ind(h_stoch_e, 1); }
double VolCur()   { return Ind(h_vol_e, 0);  }
double VolPrev()  { return IndArr(h_vol_e, 0, 1); }

double EMA200t()  { return Ind(h_ema200_t); }
double EMA50t()   { return Ind(h_ema50_t);  }
double ATRt()     { return Ind(h_atr_t);    }
double MACDmt()   { return Ind(h_macd_t, 0); }
double MACDst()   { return Ind(h_macd_t, 1); }
double RSIt()     { return Ind(h_rsi_t);    }

double EMA50c()   { return Ind(h_ema50_c);  }
double RSIc()     { return Ind(h_rsi_c);    }

double EMA200h()  { return Ind(h_ema200_h); }
double EMA50h()   { return Ind(h_ema50_h);  }

// Donchian High/Low за N свечей
double DonchianHigh()
{
   double H[]; ArraySetAsSeries(H, true);
   if (CopyHigh(g_sym, Inp_TF_Entry, 1, Inp_Donchian_Period, H) < Inp_Donchian_Period) return 0;
   double hi = H[0];
   for (int i=1; i<Inp_Donchian_Period; i++) hi = MathMax(hi, H[i]);
   return hi;
}

double DonchianLow()
{
   double L[]; ArraySetAsSeries(L, true);
   if (CopyLow(g_sym, Inp_TF_Entry, 1, Inp_Donchian_Period, L) < Inp_Donchian_Period) return 0;
   double lo = L[0];
   for (int i=1; i<Inp_Donchian_Period; i++) lo = MathMin(lo, L[i]);
   return lo;
}

//=================================================================
//  ВСПОМОГАТЕЛЬНЫЕ — ТИП ИНСТРУМЕНТА
//=================================================================

string SymTypeStr()
{
   if (g_symtype==SYM_GOLD)        return "GOLD";
   if (g_symtype==SYM_BTC)         return "BTC";
   if (g_symtype==SYM_FOREX_MAJOR) return "FOREX";
   return "OTHER";
}

double GetSL_ATR_Mult()
{
   if (g_symtype==SYM_GOLD)  return Inp_SL_ATR_Gold;
   if (g_symtype==SYM_BTC)   return Inp_SL_ATR_BTC;
   return Inp_SL_ATR_Forex;
}

double GetMaxSpread()
{
   if (g_symtype==SYM_GOLD)  return Inp_MaxSpread_Gold;
   if (g_symtype==SYM_BTC)   return Inp_MaxSpread_BTC;
   return Inp_MaxSpread_Forex;
}

int GetMinPts()
{
   if (g_symtype==SYM_GOLD)  return Inp_MinPts_Gold;
   if (g_symtype==SYM_BTC)   return Inp_MinPts_BTC;
   return Inp_MinPts_Forex;
}

double GetVolSpikeThresh()
{
   if (g_symtype==SYM_GOLD)  return Inp_VolSpike_Gold;
   return Inp_VolSpike_Forex;
}

int GetTickBoPts()
{
   if (g_symtype==SYM_GOLD)  return Inp_TickBO_Pts_Gold;
   if (g_symtype==SYM_BTC)   return Inp_TickBO_Pts_BTC;
   return Inp_TickBO_Pts_Forex;
}

//=================================================================
//  ФИЛЬТР СЕССИЙ
//=================================================================

bool IsActiveSession(int h)
{
   bool ldn  = (h>=Inp_London_Start  && h<Inp_London_End);
   bool ny   = (h>=Inp_NewYork_Start && h<Inp_NewYork_End);
   bool ovl  = (h>=Inp_London_End    && h<=Inp_NewYork_Start+1);
   bool asia = (Inp_TradeAsia && h>=Inp_Asia_Start && h<Inp_Asia_End);
   return ldn || ny || ovl || asia;
}

//=================================================================
//  МТФ ТРЕНД
//=================================================================

int GetTrendScore()
{
   int score = 0;
   MqlTick t; SymbolInfoTick(g_sym, t);
   double p = t.bid;

   // H4 — вес ×2
   double e200h=EMA200h(), e50h=EMA50h();
   if (e200h>0 && e50h>0)
   {
      if (p>e200h && p>e50h && e50h>e200h) score += 2;
      else if (p<e200h && p<e50h && e50h<e200h) score -= 2;
   }

   // H1
   double e200t=EMA200t(), e50t=EMA50t();
   double mm_t=MACDmt(), ms_t=MACDst();
   if (e200t>0 && e50t>0)
   {
      if (p>e200t && p>e50t && mm_t>ms_t) score++;
      else if (p<e200t && p<e50t && mm_t<ms_t) score--;
   }

   // M15
   double e50c=EMA50c(); double rsic=RSIc();
   if (e50c>0)
   {
      if (p>e50c && rsic>44) score++;
      else if (p<e50c && rsic<56) score--;
   }

   return score;
}

int GetTrend()
{
   int s = GetTrendScore();
   if (s >= 2)  return 1;
   if (s <= -2) return -1;
   return 0;
}

//=================================================================
//  MARKET STRUCTURE — HH/HL/LH/LL
//=================================================================

int GetMarketStructure()
{
   if (!Inp_UseMarketStr) return 0;
   int need = Inp_MSLookback + 4;
   double H[], L[];
   ArraySetAsSeries(H, true); ArraySetAsSeries(L, true);
   if (CopyHigh(g_sym, Inp_TF_Trend, 0, need, H) < need) return 0;
   if (CopyLow (g_sym, Inp_TF_Trend, 0, need, L) < need) return 0;

   double h1=-1, h2=-1, l1=DBL_MAX, l2=DBL_MAX;
   for (int i=2; i<Inp_MSLookback; i++)
   {
      if (H[i]>H[i-1] && H[i]>H[i+1])
      {
         if (h1<0)      { h1=H[i]; }
         else if (h2<0) { h2=H[i]; break; }
      }
   }
   for (int i=2; i<Inp_MSLookback; i++)
   {
      if (L[i]<L[i-1] && L[i]<L[i+1])
      {
         if (l1==DBL_MAX)      { l1=L[i]; }
         else if (l2==DBL_MAX) { l2=L[i]; break; }
      }
   }

   if (h1<0 || l1==DBL_MAX) return 0;
   if (h2>=0 && l2!=DBL_MAX)
   {
      bool hh=(h1>h2), hl=(l1>l2), lh=(h1<h2), ll=(l1<l2);
      if (hh && hl) return 1;
      if (lh && ll) return -1;
      if (hh) return 1;
      if (ll) return -1;
      return 0;
   }
   MqlTick tk; SymbolInfoTick(g_sym, tk);
   double p = tk.bid;
   if (p > h1) return 1;
   if (p < l1) return -1;
   return 0;
}

//=================================================================
//  MOMENTUM SCORE v8 — УЛУЧШЕННЫЙ СКОРИНГ
//=================================================================

int CalcMomentumScore(int dir)
{
   int score = 0;
   MqlTick t; SymbolInfoTick(g_sym, t);
   double p = t.bid;

   int ts = GetTrendScore();

   // Базовые 12 очков за любой сигнал
   score += 12;

   // Тренд-скор (макс 28 очков)
   if (dir==1)  score += MathMax(0, ts) * 7;
   if (dir==-1) score += MathMax(0, -ts) * 7;

   // RSI направление (12 очков)
   double rsi = RSIe();
   if (dir==1  && rsi>42 && rsi<76) score += 12;
   if (dir==-1 && rsi<58 && rsi>24) score += 12;

   // MACD (12 очков)
   double mm=MACDm(), ms=MACDs(), mm1=MACDm1(), ms1=MACDs1();
   if (dir==1  && mm>ms && mm1<=ms1) score += 12;
   else if (dir==1  && mm>ms)        score += 6;
   if (dir==-1 && mm<ms && mm1>=ms1) score += 12;
   else if (dir==-1 && mm<ms)        score += 6;

   // Stochastic (10 очков)
   double sk=StochK(), sd=StochD();
   if (dir==1  && sk>sd && sk<82) score += 10;
   if (dir==-1 && sk<sd && sk>18) score += 10;

   // Volume spike (14 очков — v8: усилен)
   double vc=VolCur(), vp=VolPrev();
   double vth = GetVolSpikeThresh();
   if (vp>0 && vc>vp*vth)         score += 14;
   else if (vp>0 && vc>vp*1.0)    score += 6;

   // Market structure (12 очков)
   int ms_dir = GetMarketStructure();
   if (ms_dir==dir)  score += 12;
   else if (ms_dir==0) score += 4;

   // EMA ribbon (12 очков) — v8: улучшен
   double e200=EMA200e(), e50=EMA50e(), e21=EMA21e();
   if (e200>0 && e50>0 && e21>0)
   {
      // Полный ribbon (21>50>200 для buy)
      if (dir==1  && e21>e50 && e50>e200 && p>e21) score += 12;
      if (dir==-1 && e21<e50 && e50<e200 && p<e21) score += 12;
      // Частичный
      if (dir==1  && p>e50) score += 4;
      if (dir==-1 && p<e50) score += 4;
   }

   // === Donchian подтверждение для Gold (6 очков) ===
   if (g_symtype == SYM_GOLD && Inp_UseDonchianTrail)
   {
      double dhi = DonchianHigh();
      double dlo = DonchianLow();
      if (dir==1  && dhi>0 && p>dhi) score += 6;  // пробой канала вверх
      if (dir==-1 && dlo>0 && p<dlo) score += 6;  // пробой канала вниз
   }

   return MathMin(score, 100);
}

//=================================================================
//  АДАПТИВНЫЙ КУЛДАУН
//=================================================================

int CalcCooldown()
{
   double atr = ATRe();
   double atrt = ATRt();
   if (atrt > 0 && atr > 0)
   {
      double ratio = atr / atrt;
      if (ratio > 1.8) return 12;   // экстремальная воля
      if (ratio > 1.3) return 18;
      if (ratio > 1.0) return 22;
   }
   // Gold — более агрессивный кулдаун (ловим импульсы)
   if (g_symtype == SYM_GOLD) return 15;
   return g_base_cooldown;
}

//=================================================================
//  ДИНАМИЧЕСКИЙ РИСК
//=================================================================

double GetDynamicRiskPct()
{
   if (g_recovery) return Inp_RecoveryRiskPct;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double mult = Inp_Scale_L1_Mult;
   if      (bal >= Inp_Scale_L5_Balance) mult = Inp_Scale_L5_Mult;
   else if (bal >= Inp_Scale_L4_Balance) mult = Inp_Scale_L4_Mult;
   else if (bal >= Inp_Scale_L3_Balance) mult = Inp_Scale_L3_Mult;
   else if (bal >= Inp_Scale_L2_Balance) mult = Inp_Scale_L2_Mult;
   else if (bal >= Inp_Scale_L1_Balance) mult = Inp_Scale_L1_Mult;

   if (Inp_AggressiveWinStrk && g_consec_win >= Inp_WinStreak_Trigger)
      mult *= Inp_WinStreak_Mult;
   return Inp_BaseRiskPct * mult;
}

//=================================================================
//  ДИНАМИЧЕСКИЙ ЛИМИТ ПОЗИЦИЙ
//=================================================================

int GetDynamicMaxPositions()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if (bal < 100.0)  return MathMin(2, Inp_MaxTotalPositions);
   if (bal < 500.0)  return MathMin(3, Inp_MaxTotalPositions);
   if (bal < 1000.0) return MathMin(4, Inp_MaxTotalPositions);
   return Inp_MaxTotalPositions;
}

int GetDynamicPyramidLevels()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if (bal < 100.0)  return MathMin(1, Inp_MaxPyramidLevels);
   if (bal < 500.0)  return MathMin(2, Inp_MaxPyramidLevels);
   return Inp_MaxPyramidLevels;
}

//=================================================================
//  СТРАТЕГИЯ 1: ТИК-ПРОБОЙ
//=================================================================

bool TryTickBreakout()
{
   int total = TBuf_Total();
   if (total < 4) return false;

   TickData tP = TBuf_At(total-2);
   TickData tL = TBuf_At(total-1);
   long   dms  = tL.time_msc - tP.time_msc;
   double dpt  = (tL.bid - tP.bid) / g_point;

   if (dms <= 0 || dms > Inp_TickBO_Ms) return false;

   int thresh = GetTickBoPts();
   if (MathAbs(dpt) < thresh) return false;

   int dir = (dpt > 0) ? 1 : -1;
   int trend = GetTrend();
   if (trend != 0 && trend != dir) return false;

   int mscore = CalcMomentumScore(dir);
   if (mscore < 22) return false;

   MqlTick t; if (!SymbolInfoTick(g_sym, t)) return false;
   double price = (dir==1) ? t.ask : t.bid;

   g_last_score = mscore;
   PrintFormat("[ТИК-BO %s] %.0fпт за %dмс | Trend=%d Score=%d",
               dir==1?"BUY":"SELL", MathAbs(dpt), (int)dms, trend, mscore);
   OpenOrder(dir==1?ORDER_TYPE_BUY:ORDER_TYPE_SELL, price, true, 0, mscore);
   g_last_entry = TimeCurrent();
   return true;
}

//=================================================================
//  СТРАТЕГИЯ 2: ПРОБОЙ СВЕЧНОГО УРОВНЯ
//=================================================================

bool TryCandleBreakout()
{
   int need = Inp_BO_Lookback + 4;
   double H[], L[], C[];
   ArraySetAsSeries(H,true); ArraySetAsSeries(L,true); ArraySetAsSeries(C,true);
   if (CopyHigh (g_sym,Inp_TF_Entry,0,need,H) < need) return false;
   if (CopyLow  (g_sym,Inp_TF_Entry,0,need,L) < need) return false;
   if (CopyClose(g_sym,Inp_TF_Entry,0,need,C) < need) return false;

   double hi=H[2], lo=L[2];
   for (int i=2; i<Inp_BO_Lookback+2; i++) { hi=MathMax(hi,H[i]); lo=MathMin(lo,L[i]); }

   double atr = ATRe();
   if (atr <= 0) return false;
   double confirm = atr * Inp_BO_Confirm_ATR;
   double c1 = C[1];
   int trend = GetTrend();
   int ms_dir = GetMarketStructure();

   MqlTick t; if (!SymbolInfoTick(g_sym,t)) return false;
   double p = t.bid;
   double e200=EMA200e(), e50=EMA50e();
   if (e200==0 || e50==0) return false;

   if (c1 > hi+confirm && (trend>=0) && (ms_dir>=0) && p>e50)
   {
      double rsi=RSIe(), sk=StochK();
      if (Inp_UseRSI   && rsi>79) return false;
      if (Inp_UseStoch && sk>89)  return false;
      int mscore = CalcMomentumScore(1);
      if (mscore < 18) return false;
      g_last_score = mscore;
      PrintFormat("[BO UP] c1=%.5f>Hi=%.5f | Score=%d", c1, hi, mscore);
      OpenOrder(ORDER_TYPE_BUY, t.ask, true, 0, mscore);
      g_last_entry = TimeCurrent();
      return true;
   }

   if (c1 < lo-confirm && (trend<=0) && (ms_dir<=0) && p<e50)
   {
      double rsi=RSIe(), sk=StochK();
      if (Inp_UseRSI   && rsi<21)  return false;
      if (Inp_UseStoch && sk<11)   return false;
      int mscore = CalcMomentumScore(-1);
      if (mscore < 18) return false;
      g_last_score = mscore;
      PrintFormat("[BO DOWN] c1=%.5f<Lo=%.5f | Score=%d", c1, lo, mscore);
      OpenOrder(ORDER_TYPE_SELL, t.bid, true, 0, mscore);
      g_last_entry = TimeCurrent();
      return true;
   }
   return false;
}

//=================================================================
//  СТРАТЕГИЯ 3: BB СЖАТИЕ + ПРОБОЙ
//=================================================================

bool TryBBBreakout()
{
   double upper=BBup(), lower=BBlo(), middle=BBmid();
   double atr = ATRe();
   if (upper==0 || lower==0 || atr<=0) return false;

   double bb_width = upper - lower;
   bool squeezed = (bb_width < atr * Inp_BB_SqueezePct);

   double C[]; ArraySetAsSeries(C,true);
   if (CopyClose(g_sym,Inp_TF_Entry,0,4,C) < 4) return false;

   MqlTick t; if (!SymbolInfoTick(g_sym,t)) return false;
   int trend = GetTrend();
   double e50=EMA50e();
   if (e50==0) return false;
   double sk=StochK(), sd=StochD(), rsi=RSIe();

   if (C[1]>upper && (trend>=0) && t.bid>e50 &&
       (!Inp_UseStoch || (sk>sd && sk<88)) &&
       (!Inp_UseRSI   || (rsi>45 && rsi<77)))
   {
      int mscore = CalcMomentumScore(1);
      if (mscore < 18) return false;
      g_last_score = mscore;
      PrintFormat("[BB %s BUY] W=%.5f Sq=%s Score=%d",
                  squeezed?"SQ":"UP", bb_width, squeezed?"Y":"N", mscore);
      OpenOrder(ORDER_TYPE_BUY, t.ask, squeezed, 0, mscore);
      g_last_entry = TimeCurrent();
      return true;
   }

   if (C[1]<lower && (trend<=0) && t.bid<e50 &&
       (!Inp_UseStoch || (sk<sd && sk>12)) &&
       (!Inp_UseRSI   || (rsi<55 && rsi>23)))
   {
      int mscore = CalcMomentumScore(-1);
      if (mscore < 18) return false;
      g_last_score = mscore;
      PrintFormat("[BB %s SELL] W=%.5f Sq=%s Score=%d",
                  squeezed?"SQ":"DOWN", bb_width, squeezed?"Y":"N", mscore);
      OpenOrder(ORDER_TYPE_SELL, t.bid, squeezed, 0, mscore);
      g_last_entry = TimeCurrent();
      return true;
   }
   return false;
}

//=================================================================
//  СТРАТЕГИЯ 4: ИМПУЛЬСНАЯ СВЕЧА v8
//  — Улучшен: ускорение, объём, Donchian, EMA ribbon
//=================================================================

void TryImpulse()
{
   int need = 7;
   double O[], H[], L[], C[];
   ArraySetAsSeries(O,true); ArraySetAsSeries(H,true);
   ArraySetAsSeries(L,true); ArraySetAsSeries(C,true);
   if (CopyOpen (g_sym,Inp_TF_Entry,0,need,O) < need) return;
   if (CopyHigh (g_sym,Inp_TF_Entry,0,need,H) < need) return;
   if (CopyLow  (g_sym,Inp_TF_Entry,0,need,L) < need) return;
   if (CopyClose(g_sym,Inp_TF_Entry,0,need,C) < need) return;

   double atr = ATRe();
   if (atr <= 0) return;

   // Свеча [1] — закрытая (импульсная)
   double body1  = MathAbs(C[1]-O[1]);
   double range1 = H[1]-L[1];
   double rng_pt = range1 / g_point;
   double body_p = (range1>0) ? body1/range1*100.0 : 0.0;
   bool is_bull  = C[1] > O[1];

   int min_pts = GetMinPts();
   if (rng_pt < min_pts) return;
   if (body_p  < Inp_BodyPct) return;

   // === НОВЫЙ ДЕТЕКТОР УСКОРЕНИЯ v8 ===
   // Свеча [1] должна быть больше свечи [2] (ускорение)
   if (Inp_UseAcceleration)
   {
      double range2 = H[2]-L[2];
      if (range2 > 0 && range1 < range2 * 0.8) return; // замедление — пропуск
   }

   // === ОБЪЁМНЫЙ ФИЛЬТР v8 ===
   double vc=VolCur(), vp=VolPrev();
   double vth = GetVolSpikeThresh();
   bool vol_ok = (vp <= 0) || (vc >= vp * (vth - 0.2)); // немного мягче

   // Текущая свеча подтверждает направление
   bool follow_bull = (C[0] >= O[0]);
   bool follow_bear = (C[0] <= O[0]);

   int trend  = GetTrend();
   int ms_dir = GetMarketStructure();
   double e200=EMA200e(), e50=EMA50e(), e21=EMA21e();
   double rsi = Inp_UseRSI   ? RSIe()  : 50;
   double mm  = Inp_UseMACD  ? MACDm() : 0;
   double ms2 = Inp_UseMACD  ? MACDs() : 0;
   double sk  = Inp_UseStoch ? StochK(): 50;
   double sd  = Inp_UseStoch ? StochD(): 50;

   MqlTick t; if (!SymbolInfoTick(g_sym,t)) return;
   double p = t.bid;
   if (e50 == 0) return;

   bool above_key = (p > e50);
   bool below_key = (p < e50);

   // === БЫЧИЙ ИМПУЛЬС ===
   if (is_bull && follow_bull && vol_ok &&
       (trend>=0) && (ms_dir>=0 || trend>=1) &&
       above_key &&
       (!Inp_UseRSI   || (rsi>42 && rsi<79)) &&
       (!Inp_UseMACD  || mm>ms2) &&
       (!Inp_UseStoch || (sk>sd && sk<86)))
   {
      int mscore = CalcMomentumScore(1);
      if (mscore < 18) return;
      g_last_score = mscore;
      PrintFormat("[IMP BUY v8] Body=%.0f%% Rng=%.0fpt RSI=%.1f Vol=%.1fx Score=%d T=%d MS=%d",
                  body_p, rng_pt, rsi, vp>0?vc/vp:0, mscore, trend, ms_dir);
      OpenOrder(ORDER_TYPE_BUY, t.ask, false, 0, mscore);
      g_last_entry = TimeCurrent();
   }
   // === МЕДВЕЖИЙ ИМПУЛЬС ===
   else if (!is_bull && follow_bear && vol_ok &&
            (trend<=0) && (ms_dir<=0 || trend<=-1) &&
            below_key &&
            (!Inp_UseRSI   || (rsi<58 && rsi>21)) &&
            (!Inp_UseMACD  || mm<ms2) &&
            (!Inp_UseStoch || (sk<sd && sk>14)))
   {
      int mscore = CalcMomentumScore(-1);
      if (mscore < 18) return;
      g_last_score = mscore;
      PrintFormat("[IMP SELL v8] Body=%.0f%% Rng=%.0fpt RSI=%.1f Vol=%.1fx Score=%d T=%d MS=%d",
                  body_p, rng_pt, rsi, vp>0?vc/vp:0, mscore, trend, ms_dir);
      OpenOrder(ORDER_TYPE_SELL, t.bid, false, 0, mscore);
      g_last_entry = TimeCurrent();
   }
}

//=================================================================
//  ПИРАМИДИНГ
//=================================================================

void TryAddPyramidLevel()
{
   if (!Inp_Pyramiding) return;
   int pyr_open = 0;
   for (int i=0; i<g_pyramid_cnt; i++)
      if (g_pyramid[i].level > 0 && g_pyramid[i].ticket > 0) pyr_open++;
   if (pyr_open >= GetDynamicPyramidLevels()) return;

   ulong base_ticket = 0;
   ENUM_POSITION_TYPE base_type = POSITION_TYPE_BUY;
   double base_open = 0;
   for (int i=0; i<g_pyramid_cnt; i++)
   {
      if (g_pyramid[i].level==0 && g_pyramid[i].ticket>0)
      {
         if (!g_pos.SelectByTicket(g_pyramid[i].ticket)) continue;
         base_ticket = g_pyramid[i].ticket;
         base_type   = g_pos.PositionType();
         base_open   = g_pos.PriceOpen();
         break;
      }
   }
   if (base_ticket == 0) return;

   double atr = ATRe();
   if (atr <= 0) return;
   MqlTick t; SymbolInfoTick(g_sym, t);
   double cur = (base_type==POSITION_TYPE_BUY) ? t.bid : t.ask;
   double dist_pts = (base_type==POSITION_TYPE_BUY)
                     ? (cur - base_open) / g_point
                     : (base_open - cur) / g_point;
   double step_pts = (atr * Inp_Pyramid_ATR_Step) / g_point;
   double min_dist = step_pts * (pyr_open + 1);
   if (dist_pts < min_dist) return;

   int trend = GetTrend();
   if (base_type==POSITION_TYPE_BUY  && trend<0) return;
   if (base_type==POSITION_TYPE_SELL && trend>0) return;

   int dir = (base_type==POSITION_TYPE_BUY) ? 1 : -1;
   int mscore = CalcMomentumScore(dir);
   if (mscore < 42) return;

   double pyr_risk = GetDynamicRiskPct();
   if (Inp_ReducePyramidRisk)
      for (int lv=0; lv<pyr_open+1; lv++) pyr_risk *= Inp_PyramidRiskMult;

   double price = (base_type==POSITION_TYPE_BUY) ? t.ask : t.bid;
   PrintFormat("[ПИРАМИД L%d] %s | Dist=%.0fpt | Score=%d | Risk=%.2f%%",
               pyr_open+1, base_type==POSITION_TYPE_BUY?"BUY":"SELL",
               dist_pts, mscore, pyr_risk);
   OpenOrder(base_type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,
             price, false, pyr_open+1, mscore, pyr_risk);
   g_last_entry = TimeCurrent();
}

//=================================================================
//  ОТКРЫТИЕ ОРДЕРА
//=================================================================

void OpenOrder(ENUM_ORDER_TYPE otype, double price, bool is_breakout,
               int pyramid_level=0, int mscore=50, double override_risk=-1)
{
   double atr = ATRe();
   if (atr <= 0) { Print("[SKIP] ATR=0"); return; }

   double sl_mult = GetSL_ATR_Mult();
   double sl_pts;

   if (Inp_UseSwingSL)
   {
      double sw = GetSwingSL(otype, Inp_SwingLookback);
      MqlTick t2; SymbolInfoTick(g_sym, t2);
      if (sw > 0)
      {
         double sw_pts = (otype==ORDER_TYPE_BUY)
                         ? (t2.ask - sw) / g_point
                         : (sw - t2.bid) / g_point;
         sl_pts = MathMax(sw_pts, (atr*sl_mult)/g_point);
      }
      else sl_pts = (atr*sl_mult) / g_point;
   }
   else sl_pts = (atr*sl_mult) / g_point;

   double tp_mult  = is_breakout ? Inp_TP_Breakout_ATR : Inp_TP3_ATR;
   double tp_pts   = (atr * tp_mult) / g_point;
   double stops_lv = (double)SymbolInfoInteger(g_sym, SYMBOL_TRADE_STOPS_LEVEL);
   sl_pts = MathMax(sl_pts, stops_lv + 5.0);
   tp_pts = MathMax(tp_pts, stops_lv + 10.0);

   double risk_pct;
   if (override_risk > 0)      risk_pct = override_risk;
   else if (pyramid_level > 0) risk_pct = GetDynamicRiskPct() * MathPow(Inp_PyramidRiskMult, pyramid_level);
   else                        risk_pct = GetDynamicRiskPct();

   // Бонус моментума
   if (mscore >= 80) risk_pct *= 1.12;
   else if (mscore >= 65) risk_pct *= 1.06;

   double lot = CalcLot(sl_pts, risk_pct);
   if (lot <= 0) { Print("[SKIP] lot=0"); return; }

   price = NormalizeDouble(price, g_digits);
   double sl, tp;
   string cmt;

   if (otype == ORDER_TYPE_BUY)
   {
      sl  = NormalizeDouble(price - sl_pts*g_point, g_digits);
      tp  = NormalizeDouble(price + tp_pts*g_point, g_digits);
      cmt = StringFormat("v8_%s_BUY_L%d_S%d", is_breakout?"BO":"IMP", pyramid_level, mscore);
   }
   else
   {
      sl  = NormalizeDouble(price + sl_pts*g_point, g_digits);
      tp  = NormalizeDouble(price - tp_pts*g_point, g_digits);
      cmt = StringFormat("v8_%s_SELL_L%d_S%d", is_breakout?"BO":"IMP", pyramid_level, mscore);
   }

   bool ok = (otype==ORDER_TYPE_BUY)
             ? g_trade.Buy (lot, g_sym, price, sl, tp, cmt)
             : g_trade.Sell(lot, g_sym, price, sl, tp, cmt);

   if (ok)
   {
      ulong tkt = g_trade.ResultOrder();
      if (tkt>0 && g_pyramid_cnt < 5)
      {
         g_pyramid[g_pyramid_cnt].ticket    = tkt;
         g_pyramid[g_pyramid_cnt].level     = pyramid_level;
         g_pyramid[g_pyramid_cnt].open_price = price;
         g_pyramid[g_pyramid_cnt].sl        = sl;
         g_pyramid[g_pyramid_cnt].tp        = tp;
         g_pyramid[g_pyramid_cnt].tp1_done  = false;
         g_pyramid[g_pyramid_cnt].tp2_done  = false;
         g_pyramid[g_pyramid_cnt].be_done   = false;
         g_pyramid_cnt++;
      }
      PrintFormat("[%s OPEN L%d] P=%.5f SL=%.5f TP=%.5f Lot=%.4f Risk=%.2f%% ATR=%.5f Sc=%d",
                  otype==ORDER_TYPE_BUY?"BUY":"SELL",
                  pyramid_level, price, sl, tp, lot, risk_pct, atr, mscore);
   }
   else
      PrintFormat("[ORDER ERR] %d: %s",
                  (int)g_trade.ResultRetcode(), g_trade.ResultComment());
}

//=================================================================
//  СИНХРОНИЗАЦИЯ ПИРАМИДЫ
//=================================================================

void SyncPyramidState()
{
   for (int i=g_pyramid_cnt-1; i>=0; i--)
   {
      if (g_pyramid[i].ticket == 0) continue;
      if (!PositionSelectByTicket(g_pyramid[i].ticket))
      {
         PrintFormat("[SYNC] Позиция #%I64u закрыта (L%d)", g_pyramid[i].ticket, g_pyramid[i].level);
         for (int j=i; j<g_pyramid_cnt-1; j++) g_pyramid[j] = g_pyramid[j+1];
         ZeroMemory(g_pyramid[g_pyramid_cnt-1]);
         g_pyramid_cnt--;
      }
   }
}

//=================================================================
//  УПРАВЛЕНИЕ ПОЗИЦИЯМИ
//=================================================================

void ManageAllPositions()
{
   for (int i=PositionsTotal()-1; i>=0; i--)
   {
      if (!g_pos.SelectByIndex(i)) continue;
      if (g_pos.Magic()!=(ulong)Inp_Magic || g_pos.Symbol()!=g_sym) continue;
      ManageSinglePos(g_pos.Ticket());
   }
}

void ManageSinglePos(ulong ticket)
{
   if (!g_pos.SelectByTicket(ticket)) return;

   ENUM_POSITION_TYPE pt = g_pos.PositionType();
   double open_p  = g_pos.PriceOpen();
   double cur_sl  = g_pos.StopLoss();
   double cur_tp  = g_pos.TakeProfit();
   double lot     = g_pos.Volume();

   MqlTick t; SymbolInfoTick(g_sym, t);
   double cur = (pt==POSITION_TYPE_BUY) ? t.bid : t.ask;
   double profit_pts = (pt==POSITION_TYPE_BUY)
                       ? (cur - open_p) / g_point
                       : (open_p - cur) / g_point;

   double atr = ATRe();
   if (atr <= 0) return;

   int pidx = -1;
   for (int i=0; i<g_pyramid_cnt; i++)
      if (g_pyramid[i].ticket == ticket) { pidx=i; break; }

   double ml = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MIN);
   double ls = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_STEP);

   //--- TP1: 25% на TP1_ATR
   bool tp1_done = (pidx>=0) ? g_pyramid[pidx].tp1_done : false;
   if (!tp1_done && profit_pts >= (atr*Inp_TP1_ATR)/g_point)
   {
      double cl = MathRound(lot*0.25/ls)*ls;
      if (cl >= ml && g_trade.PositionClosePartial(ticket, cl))
      {
         PrintFormat("[TP1 25%%] #%I64u +%.0fpt", ticket, profit_pts);
         if (pidx>=0) g_pyramid[pidx].tp1_done = true;
      }
   }

   //--- TP2: 45% на TP2_ATR
   bool tp2_done = (pidx>=0) ? g_pyramid[pidx].tp2_done : false;
   if (!tp2_done && profit_pts >= (atr*Inp_TP2_ATR)/g_point)
   {
      double cl = MathRound(lot*0.45/ls)*ls;
      if (cl >= ml && g_trade.PositionClosePartial(ticket, cl))
      {
         PrintFormat("[TP2 45%%] #%I64u +%.0fpt", ticket, profit_pts);
         if (pidx>=0) g_pyramid[pidx].tp2_done = true;
      }
   }

   //--- БЕЗУБЫТОК — умный с буфером
   bool be_done = (pidx>=0) ? g_pyramid[pidx].be_done : false;
   double be_thresh_pts = (atr * Inp_BE_ATR_Trigger) / g_point;
   if (!be_done && profit_pts >= be_thresh_pts)
   {
      double be_price;
      if (pt == POSITION_TYPE_BUY)
         be_price = NormalizeDouble(open_p + Inp_BE_Buffer_Pts*g_point, g_digits);
      else
         be_price = NormalizeDouble(open_p - Inp_BE_Buffer_Pts*g_point, g_digits);

      bool need_be = (pt==POSITION_TYPE_BUY  && (cur_sl==0 || be_price>cur_sl)) ||
                     (pt==POSITION_TYPE_SELL && (cur_sl==0 || be_price<cur_sl));
      if (need_be && g_trade.PositionModify(ticket, be_price, cur_tp))
      {
         PrintFormat("[BE] #%I64u → %.5f (+%.0fpt буфер=%.1f)", ticket, be_price, profit_pts, Inp_BE_Buffer_Pts);
         cur_sl = be_price;
         if (pidx>=0) g_pyramid[pidx].be_done = true;
      }
   }

   //--- УМНЫЙ ТРЕЙЛИНГ v8: 4-ФАЗНЫЙ ATR-ТРЕЙЛИНГ
   //    Каждый тик двигает SL вверх — никогда не назад!
   {
      double p_atr = (atr > 0) ? (profit_pts / (atr/g_point)) : 0;
      double trail_mult;

      if      (p_atr >= 3.5) trail_mult = Inp_Trail_Phase4_ATR;  // Фаза 4: зажим
      else if (p_atr >= 2.5) trail_mult = Inp_Trail_Phase3_ATR;  // Фаза 3
      else if (p_atr >= 1.5) trail_mult = Inp_Trail_Phase2_ATR;  // Фаза 2
      else                   trail_mult = Inp_Trail_Phase1_ATR;  // Фаза 1: широкий

      // Gold: дополнительный Donchian-трейлинг (каналовый)
      double trail_pts = MathMax((atr*trail_mult)/g_point, 8.0);

      if (g_symtype==SYM_GOLD && Inp_UseDonchianTrail && profit_pts > 0)
      {
         // Для BUY: SL = Donchian Low (минимум за N свечей)
         // Для SELL: SL = Donchian High
         if (pt == POSITION_TYPE_BUY)
         {
            double don_lo = DonchianLow();
            if (don_lo > 0)
            {
               double don_trail = (cur - don_lo) / g_point;
               trail_pts = MathMin(trail_pts, don_trail); // берём минимальное расстояние
            }
         }
         else
         {
            double don_hi = DonchianHigh();
            if (don_hi > 0)
            {
               double don_trail = (don_hi - cur) / g_point;
               trail_pts = MathMin(trail_pts, don_trail);
            }
         }
         trail_pts = MathMax(trail_pts, 8.0); // минимум 8 пунктов
      }

      if (pt == POSITION_TYPE_BUY)
      {
         double cand = NormalizeDouble(cur - trail_pts*g_point, g_digits);
         // Двигаем только вверх, и только если позиция в плюсе
         if (profit_pts > 0 && (cur_sl==0 || cand > cur_sl))
         {
            if (g_trade.PositionModify(ticket, cand, cur_tp))
               PrintFormat("[TRAIL BUY] #%I64u SL→%.5f (фаза%.0f, +%.0fpt)",
                           ticket, cand, p_atr<1.5?1:p_atr<2.5?2:p_atr<3.5?3:4, profit_pts);
         }
      }
      else
      {
         double cand = NormalizeDouble(cur + trail_pts*g_point, g_digits);
         // Двигаем только вниз (для SELL), и только если в плюсе
         if (profit_pts > 0 && (cur_sl==0 || cand < cur_sl))
         {
            if (g_trade.PositionModify(ticket, cand, cur_tp))
               PrintFormat("[TRAIL SELL] #%I64u SL→%.5f (фаза%.0f, +%.0fpt)",
                           ticket, cand, p_atr<1.5?1:p_atr<2.5?2:p_atr<3.5?3:4, profit_pts);
         }
      }
   }

   //--- RSI-ДИВЕРГЕНЦИЯ — ранний выход (v8 новое)
   {
      double rsi_cur  = RSIe();
      double rsi_prev = RSIe1();
      // Дивергенция: цена растёт но RSI падает (medvezhya дивергенция при BUY)
      bool bull_div = (pt==POSITION_TYPE_BUY  && cur>open_p && rsi_cur<rsi_prev-3 && rsi_cur>75);
      bool bear_div = (pt==POSITION_TYPE_SELL && cur<open_p && rsi_cur>rsi_prev+3 && rsi_cur<25);
      if ((bull_div || bear_div) && profit_pts > (atr*Inp_TP2_ATR)/g_point)
      {
         PrintFormat("[RSI DIV EXIT] #%I64u RSI=%.1f prev=%.1f +%.0fpt", ticket, rsi_cur, rsi_prev, profit_pts);
         if (g_trade.PositionClose(ticket))
         {
            g_day.wins++; g_consec_win++; g_consec_loss=0;
            g_recovery = (g_consec_loss >= Inp_ConsecutiveLoss);
         }
         return;
      }
   }

   //--- RSI ЭКСТРИМ — аварийный выход
   {
      double rsi = RSIe();
      bool exit_sig = (pt==POSITION_TYPE_BUY  && rsi>85 && profit_pts>0) ||
                      (pt==POSITION_TYPE_SELL && rsi<15 && profit_pts>0);
      if (exit_sig)
      {
         PrintFormat("[RSI EXIT] #%I64u RSI=%.1f +%.0fpt", ticket, rsi, profit_pts);
         if (g_trade.PositionClose(ticket))
         {
            if (profit_pts>0) { g_day.wins++; g_consec_win++; g_consec_loss=0; }
            else              { g_day.losses++; g_consec_loss++; g_consec_win=0; }
            g_recovery = (g_consec_loss >= Inp_ConsecutiveLoss);
         }
         return;
      }
   }

   //--- СМЕНА ТРЕНДА — выход если BE сработал
   {
      bool be_d = (pidx>=0) ? g_pyramid[pidx].be_done : false;
      if (be_d && profit_pts > 0)
      {
         int trend = GetTrend();
         bool flip = (pt==POSITION_TYPE_BUY  && trend==-1) ||
                     (pt==POSITION_TYPE_SELL && trend==1);
         if (flip)
         {
            PrintFormat("[TREND FLIP EXIT] #%I64u +%.0fpt", ticket, profit_pts);
            g_trade.PositionClose(ticket);
         }
      }
   }
}

//=================================================================
//  SWING HIGH / LOW ДЛЯ SL
//=================================================================

double GetSwingSL(ENUM_ORDER_TYPE otype, int lookback)
{
   double H[], L[];
   ArraySetAsSeries(H,true); ArraySetAsSeries(L,true);
   int need = lookback + 3;
   if (CopyHigh(g_sym,Inp_TF_Entry,0,need,H) < need) return 0;
   if (CopyLow (g_sym,Inp_TF_Entry,0,need,L) < need) return 0;

   if (otype == ORDER_TYPE_BUY)
   {
      double lo = L[1];
      for (int i=1; i<lookback; i++) lo = MathMin(lo, L[i]);
      return lo;
   }
   else
   {
      double hi = H[1];
      for (int i=1; i<lookback; i++) hi = MathMax(hi, H[i]);
      return hi;
   }
}

//=================================================================
//  РАСЧЁТ ЛОТА — ДИНАМИЧЕСКИЙ
//=================================================================

double CalcLot(double sl_pts, double risk_pct)
{
   if (sl_pts <= 0) return 0.0;
   double bal      = AccountInfoDouble(ACCOUNT_BALANCE);
   double min_lot  = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MIN);
   double lot_step = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_STEP);
   double max_lot  = SymbolInfoDouble(g_sym, SYMBOL_VOLUME_MAX);
   if (bal < 1.0) return min_lot;

   double tv = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(g_sym, SYMBOL_TRADE_TICK_SIZE);
   if (tv<=0 || ts<=0) return min_lot;

   double pv       = tv * (g_point/ts);
   if (pv <= 0) return min_lot;

   double risk_usd = bal * (risk_pct/100.0);
   double lot      = risk_usd / (sl_pts * pv);

   lot = MathRound(lot/lot_step)*lot_step;
   lot = MathMax(min_lot, MathMin(lot, max_lot));

   PrintFormat("[ЛОТ] Bal=%.2f Risk=%.2f%% SL=%.0fpt → %.4f", bal, risk_pct, sl_pts, lot);
   return lot;
}

//=================================================================
//  ВСПОМОГАТЕЛЬНЫЕ
//=================================================================

ENUM_ORDER_TYPE_FILLING GetFilling(string sym)
{
   int f = (int)SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if ((f & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if ((f & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

int CountPos()
{
   int n=0;
   for (int i=PositionsTotal()-1; i>=0; i--)
      if (g_pos.SelectByIndex(i) &&
          g_pos.Magic()==(ulong)Inp_Magic &&
          g_pos.Symbol()==g_sym) n++;
   return n;
}

void CloseAll()
{
   for (int i=PositionsTotal()-1; i>=0; i--)
      if (g_pos.SelectByIndex(i) &&
          g_pos.Magic()==(ulong)Inp_Magic &&
          g_pos.Symbol()==g_sym)
         g_trade.PositionClose(g_pos.Ticket());
}

string GetGrowthStage()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if      (bal <  50.0)  return "SEED $23→$50";
   else if (bal < 100.0)  return "STAGE1 $50→$100";
   else if (bal < 200.0)  return "STAGE2 $100→$200";
   else if (bal < 500.0)  return "STAGE3 $200→$500";
   else if (bal < 1000.0) return "STAGE4 $500→$1K";
   else if (bal < 2000.0) return "STAGE5 $1K→$2K";
   else if (bal < 5000.0) return "STAGE6 $2K→$5K";
   else                   return "★ GOAL $5K+ ★";
}

//=================================================================
//  ПАНЕЛЬ УПРАВЛЕНИЯ v8
//=================================================================

void DeleteObjects(string pfx)
{
   int total = ObjectsTotal(0,-1,-1);
   for (int i=total-1; i>=0; i--)
   {
      string nm = ObjectName(0,i,-1,-1);
      if (StringFind(nm, pfx) == 0) ObjectDelete(0, nm);
   }
}

void MakeLabel(string nm, string txt, int x, int y,
               color clr, int sz=8, string font="Arial Bold")
{
   if (ObjectFind(0,nm) < 0)
      ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0,nm,OBJPROP_XDISTANCE,  x);
   ObjectSetInteger(0,nm,OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0,nm,OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,     ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,      clr);
   ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,   sz);
   ObjectSetString (0,nm,OBJPROP_FONT,       font);
   ObjectSetString (0,nm,OBJPROP_TEXT,       txt);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,nm,OBJPROP_BACK,       false);
}

void DrawPanel()
{
   if (ObjectFind(0, OBJ_PANEL) < 0)
      ObjectCreate(0, OBJ_PANEL, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_XDISTANCE,  5);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_YDISTANCE,  5);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_XSIZE,       218);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_YSIZE,       255);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BGCOLOR,     C'14,18,28');
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BORDER_COLOR,C'0,180,255');
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_WIDTH,       2);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0,OBJ_PANEL,OBJPROP_BACK,        false);

   MakeLabel(LBL_TITLE, "⚡ BEAST MICRO v8 | "+SymTypeStr(), 12, 12, C'0,200,255', 9);

   if (ObjectFind(0, BTN_SS) < 0)
      ObjectCreate(0, BTN_SS, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0,BTN_SS,OBJPROP_XDISTANCE, 12);
   ObjectSetInteger(0,BTN_SS,OBJPROP_YDISTANCE, 32);
   ObjectSetInteger(0,BTN_SS,OBJPROP_XSIZE,     194);
   ObjectSetInteger(0,BTN_SS,OBJPROP_YSIZE,      24);
   ObjectSetInteger(0,BTN_SS,OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0,BTN_SS,OBJPROP_FONTSIZE,   9);
   ObjectSetString (0,BTN_SS,OBJPROP_FONT,       "Arial Bold");
   ObjectSetInteger(0,BTN_SS,OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0,BTN_SS,OBJPROP_STATE,      false);

   UpdatePanel();
}

void UpdatePanel()
{
   if (g_running)
   {
      ObjectSetString (0,BTN_SS,OBJPROP_TEXT,   "  ■  ОСТАНОВИТЬ");
      ObjectSetInteger(0,BTN_SS,OBJPROP_BGCOLOR, C'180,30,30');
      ObjectSetInteger(0,BTN_SS,OBJPROP_COLOR,   clrWhite);
   }
   else
   {
      ObjectSetString (0,BTN_SS,OBJPROP_TEXT,   "  ▶  ЗАПУСТИТЬ");
      ObjectSetInteger(0,BTN_SS,OBJPROP_BGCOLOR, C'20,160,60');
      ObjectSetInteger(0,BTN_SS,OBJPROP_COLOR,   clrWhite);
   }

   color sc = g_disabled ? clrOrangeRed : (g_running ? C'0,240,120' : clrGray);
   string st_txt = g_disabled ? "⛔ ДНЕВНОЙ СТОП" :
                   (g_recovery ? "⚠ RECOVERY MODE" :
                   (g_running  ? "● АКТИВЕН" : "○ ПАУЗА"));
   MakeLabel(LBL_STATUS, st_txt, 12, 62, sc, 8);

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd  = (g_equity_peak > 0) ? (g_equity_peak - eq) / g_equity_peak * 100.0 : 0;
   MakeLabel(LBL_BAL, StringFormat("Баланс : $ %.2f", bal), 12,  80, clrSilver, 8);
   MakeLabel(LBL_EQ,  StringFormat("Эквити : $ %.2f", eq),  12,  96, eq>=bal?C'0,220,100':clrOrangeRed, 8);
   MakeLabel(LBL_DD,  StringFormat("DD пика: %.2f%%", dd),  12, 112,
             dd<5?C'0,200,80':dd<10?clrOrange:clrOrangeRed, 8);

   MakeLabel(LBL_STAGE, "► "+GetGrowthStage(), 12, 128, C'255,200,50', 8);

   double rsk = GetDynamicRiskPct();
   int mx_pos = GetDynamicMaxPositions();
   int cur_pos = CountPos();
   MakeLabel(LBL_RISK, StringFormat("Риск: %.2f%%  Поз: %d/%d Trail:4Ph", rsk, cur_pos, mx_pos), 12, 145, clrLightSteelBlue, 8);

   color wl_c = (g_consec_win>0) ? C'0,220,100' : (g_consec_loss>0?clrOrangeRed:clrGray);
   MakeLabel(LBL_WL, StringFormat("Win×%d  Loss×%d  Rec:%s", g_consec_win, g_consec_loss, g_recovery?"Y":"N"), 12, 161, wl_c, 8);
   MakeLabel(LBL_POS, StringFormat("День: +%d -%d | Score:%d", g_day.wins, g_day.losses, g_last_score), 12, 177, clrDarkGray, 7);

   MakeLabel(N3P"HINT", "◈ Fib/SR/TL/MS/ATR авто | 4-Ph Trail", 12, 195, C'60,90,120', 7);
   MakeLabel(N3P"VER",  "N3onhex v8 SMART BEAST | $23→$5000",    12, 210, C'40,55,85',  7);
   MakeLabel(N3P"MKT",  "Gold[PRI] EUR GBP BTC supported",        12, 225, C'40,55,85',  7);

   ChartRedraw(0);
}

//=================================================================
//  ДОБАВЛЕНИЕ ИНДИКАТОРОВ НА ГРАФИК
//=================================================================

void AddIndicatorsToChart()
{
   if (g_indic_added) return;
   ChartIndicatorAdd(0, 0, h_ema200_e);
   ChartIndicatorAdd(0, 0, h_ema50_e);
   ChartIndicatorAdd(0, 0, h_ema21_e);
   ChartIndicatorAdd(0, 0, h_bb_e);
   ChartIndicatorAdd(0, 1, h_rsi_e);
   ChartIndicatorAdd(0, 2, h_macd_e);
   ChartIndicatorAdd(0, 3, h_stoch_e);
   ChartIndicatorAdd(0, 4, h_atr_e);
   ChartIndicatorAdd(0, 5, h_vol_e);
   g_indic_added = true;
   Print("[CHART] Индикаторы добавлены (EMA/BB/RSI/MACD/Stoch/ATR/Vol)");
}

//=================================================================
//  FIBONACCI — АВТО-РИСОВАНИЕ
//=================================================================

void DrawFibonacci()
{
   DeleteObjects(PFX_FIB);
   int lookback = 60;
   double H[], L[];
   ArraySetAsSeries(H,true); ArraySetAsSeries(L,true);
   if (CopyHigh(g_sym,Inp_TF_Entry,0,lookback,H) < lookback) return;
   if (CopyLow (g_sym,Inp_TF_Entry,0,lookback,L) < lookback) return;
   datetime T[]; ArraySetAsSeries(T,true);
   if (CopyTime(g_sym,Inp_TF_Entry,0,lookback,T) < lookback) return;

   double swing_hi=H[0]; int shi=0;
   double swing_lo=L[0]; int sli=0;
   for (int i=1; i<lookback; i++)
   {
      if (H[i]>swing_hi) { swing_hi=H[i]; shi=i; }
      if (L[i]<swing_lo) { swing_lo=L[i]; sli=i; }
   }
   bool up_move = (shi > sli);
   double fib_lo = up_move ? swing_lo : swing_hi;
   double fib_hi = up_move ? swing_hi : swing_lo;
   double range  = fib_hi - fib_lo;
   if (range <= 0) return;

   double levels[] = {0.0, 0.236, 0.382, 0.500, 0.618, 0.786, 1.000, 1.272, 1.618};
   string labels[] = {"0%","23.6%","38.2%","50%","★61.8% ЗС","78.6%","100%","127.2%","★161.8%"};
   color  colors[] = {clrGray,C'80,120,180',C'100,150,200',clrSilver,C'255,200,0',C'80,120,180',clrGray,C'100,180,100',C'0,220,120'};
   int    widths[] = {1,1,1,1,2,1,1,1,2};

   datetime t_right = T[0] + (datetime)PeriodSeconds(Inp_TF_Entry)*50;
   for (int i=0; i<9; i++)
   {
      double price = up_move ? fib_lo + range*(1.0-levels[i]) : fib_hi - range*(1.0-levels[i]);
      string nm = PFX_FIB+IntegerToString(i);
      string nm_lbl = PFX_FIB+"L"+IntegerToString(i);
      if (ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_TREND,0,T[shi>sli?shi:sli],price,t_right,price);
      else { ObjectSetDouble(0,nm,OBJPROP_PRICE,0,price); ObjectSetDouble(0,nm,OBJPROP_PRICE,1,price); }
      ObjectSetInteger(0,nm,OBJPROP_COLOR,  colors[i]);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,  widths[i]);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,  i==4||i==8?STYLE_SOLID:STYLE_DOT);
      ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT,true);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      if (ObjectFind(0,nm_lbl)<0) ObjectCreate(0,nm_lbl,OBJ_TEXT,0,t_right,price);
      ObjectSetInteger(0,nm_lbl,OBJPROP_TIME,  t_right);
      ObjectSetDouble (0,nm_lbl,OBJPROP_PRICE, price);
      ObjectSetString (0,nm_lbl,OBJPROP_TEXT,  " "+labels[i]+StringFormat(" (%.5f)",price));
      ObjectSetInteger(0,nm_lbl,OBJPROP_COLOR, colors[i]);
      ObjectSetInteger(0,nm_lbl,OBJPROP_FONTSIZE,i==4||i==8?8:7);
      ObjectSetString (0,nm_lbl,OBJPROP_FONT,  i==4||i==8?"Arial Bold":"Arial");
      ObjectSetInteger(0,nm_lbl,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm_lbl,OBJPROP_BACK,false);
   }
}

//=================================================================
//  SUPPORT / RESISTANCE — АВТО-РИСОВАНИЕ
//=================================================================

void DrawSupportResistance()
{
   DeleteObjects(PFX_SR);
   int lookback = 100;
   double H[], L[];
   ArraySetAsSeries(H,true); ArraySetAsSeries(L,true);
   if (CopyHigh(g_sym,Inp_TF_Trend,0,lookback,H) < lookback) return;
   if (CopyLow (g_sym,Inp_TF_Trend,0,lookback,L) < lookback) return;
   datetime T[]; ArraySetAsSeries(T,true);
   if (CopyTime(g_sym,Inp_TF_Trend,0,lookback,T) < lookback) return;

   double atr = ATRe();
   double zone = atr * 0.3;
   datetime t_right = T[0] + (datetime)PeriodSeconds(Inp_TF_Trend)*60;

   int sr_cnt=0;
   double sr_levels[20]; bool sr_is_res[20]; int sr_strength[20];

   for (int i=2; i<lookback-2 && sr_cnt<20; i++)
   {
      if (H[i]>H[i-1]&&H[i]>H[i+1]&&H[i]>H[i-2]&&H[i]>H[i+2])
      {
         bool dup=false;
         for (int k=0; k<sr_cnt; k++)
            if (MathAbs(sr_levels[k]-H[i])<zone) { sr_strength[k]++; dup=true; break; }
         if (!dup && sr_cnt<20) { sr_levels[sr_cnt]=H[i]; sr_is_res[sr_cnt]=true; sr_strength[sr_cnt]=1; sr_cnt++; }
      }
      if (L[i]<L[i-1]&&L[i]<L[i+1]&&L[i]<L[i-2]&&L[i]<L[i+2])
      {
         bool dup=false;
         for (int k=0; k<sr_cnt; k++)
            if (MathAbs(sr_levels[k]-L[i])<zone) { sr_strength[k]++; dup=true; break; }
         if (!dup && sr_cnt<20) { sr_levels[sr_cnt]=L[i]; sr_is_res[sr_cnt]=false; sr_strength[sr_cnt]=1; sr_cnt++; }
      }
   }

   for (int i=0; i<sr_cnt; i++)
   {
      string nm=PFX_SR+IntegerToString(i), nml=PFX_SR+"L"+IntegerToString(i);
      bool is_res=sr_is_res[i]; int strg=sr_strength[i];
      color c = is_res?(strg>=2?C'255,80,80':C'180,60,60'):(strg>=2?C'80,200,80':C'60,150,60');
      int w = strg>=3?2:1;
      if (ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_HLINE,0,0,sr_levels[i]);
      ObjectSetDouble (0,nm,OBJPROP_PRICE, sr_levels[i]);
      ObjectSetInteger(0,nm,OBJPROP_COLOR, c);
      ObjectSetInteger(0,nm,OBJPROP_WIDTH, w);
      ObjectSetInteger(0,nm,OBJPROP_STYLE, strg>=2?STYLE_SOLID:STYLE_DASHDOT);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_BACK,true);
      if (ObjectFind(0,nml)<0) ObjectCreate(0,nml,OBJ_TEXT,0,t_right,sr_levels[i]);
      ObjectSetInteger(0,nml,OBJPROP_TIME,  t_right);
      ObjectSetDouble (0,nml,OBJPROP_PRICE, sr_levels[i]);
      ObjectSetString (0,nml,OBJPROP_TEXT,  " "+(is_res?"R":"S")+IntegerToString(i+1)+"×"+IntegerToString(strg)+StringFormat(" (%.5f)",sr_levels[i]));
      ObjectSetInteger(0,nml,OBJPROP_COLOR, c);
      ObjectSetInteger(0,nml,OBJPROP_FONTSIZE,7);
      ObjectSetString (0,nml,OBJPROP_FONT,"Arial");
      ObjectSetInteger(0,nml,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nml,OBJPROP_BACK,false);
   }
}

//=================================================================
//  ТРЕНДОВЫЕ ЛИНИИ — АВТО-РИСОВАНИЕ
//=================================================================

void DrawTrendLines()
{
   DeleteObjects(PFX_TL);
   int lookback=50;
   double H[],L[]; ArraySetAsSeries(H,true); ArraySetAsSeries(L,true);
   if (CopyHigh(g_sym,Inp_TF_Entry,0,lookback,H) < lookback) return;
   if (CopyLow (g_sym,Inp_TF_Entry,0,lookback,L) < lookback) return;
   datetime T[]; ArraySetAsSeries(T,true);
   if (CopyTime(g_sym,Inp_TF_Entry,0,lookback,T) < lookback) return;

   int h1i=-1,h2i=-1; double h1v=0,h2v=0;
   int l1i=-1,l2i=-1; double l1v=0,l2v=0;
   for (int i=2;i<lookback-2;i++)
   {
      if (H[i]>H[i-1]&&H[i]>H[i+1]&&H[i]>H[i-2]&&H[i]>H[i+2])
      { if (h1i<0){h1i=i;h1v=H[i];} else{h2i=i;h2v=H[i];break;} }
   }
   for (int i=2;i<lookback-2;i++)
   {
      if (L[i]<L[i-1]&&L[i]<L[i+1]&&L[i]<L[i-2]&&L[i]<L[i+2])
      { if (l1i<0){l1i=i;l1v=L[i];} else{l2i=i;l2v=L[i];break;} }
   }
   datetime t_right = T[0]+(datetime)PeriodSeconds(Inp_TF_Entry)*40;

   if (l1i>=0&&l2i>=0)
   {
      string nm=PFX_TL+"UP";
      if (ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_TREND,0,T[l2i],l2v,T[l1i],l1v);
      ObjectSetInteger(0,nm,OBJPROP_TIME, 0,T[l2i]); ObjectSetDouble(0,nm,OBJPROP_PRICE,0,l2v);
      ObjectSetInteger(0,nm,OBJPROP_TIME, 1,T[l1i]); ObjectSetDouble(0,nm,OBJPROP_PRICE,1,l1v);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,     C'50,200,100');
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,     2);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,     STYLE_SOLID);
      ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_BACK,      true);
      string nml=PFX_TL+"UP_L";
      if (ObjectFind(0,nml)<0) ObjectCreate(0,nml,OBJ_TEXT,0,t_right,l1v);
      ObjectSetInteger(0,nml,OBJPROP_TIME,   t_right); ObjectSetDouble(0,nml,OBJPROP_PRICE,l1v);
      ObjectSetString (0,nml,OBJPROP_TEXT,   " ↗ TL BUY");
      ObjectSetInteger(0,nml,OBJPROP_COLOR,  C'50,200,100');
      ObjectSetInteger(0,nml,OBJPROP_FONTSIZE,8); ObjectSetString(0,nml,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,nml,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nml,OBJPROP_BACK,false);
   }
   if (h1i>=0&&h2i>=0)
   {
      string nm=PFX_TL+"DN";
      if (ObjectFind(0,nm)<0) ObjectCreate(0,nm,OBJ_TREND,0,T[h2i],h2v,T[h1i],h1v);
      ObjectSetInteger(0,nm,OBJPROP_TIME, 0,T[h2i]); ObjectSetDouble(0,nm,OBJPROP_PRICE,0,h2v);
      ObjectSetInteger(0,nm,OBJPROP_TIME, 1,T[h1i]); ObjectSetDouble(0,nm,OBJPROP_PRICE,1,h1v);
      ObjectSetInteger(0,nm,OBJPROP_COLOR,     C'220,60,60');
      ObjectSetInteger(0,nm,OBJPROP_WIDTH,     2);
      ObjectSetInteger(0,nm,OBJPROP_STYLE,     STYLE_SOLID);
      ObjectSetInteger(0,nm,OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nm,OBJPROP_BACK,      true);
      string nml=PFX_TL+"DN_L";
      if (ObjectFind(0,nml)<0) ObjectCreate(0,nml,OBJ_TEXT,0,t_right,h1v);
      ObjectSetInteger(0,nml,OBJPROP_TIME,   t_right); ObjectSetDouble(0,nml,OBJPROP_PRICE,h1v);
      ObjectSetString (0,nml,OBJPROP_TEXT,   " ↘ TL SELL");
      ObjectSetInteger(0,nml,OBJPROP_COLOR,  C'220,60,60');
      ObjectSetInteger(0,nml,OBJPROP_FONTSIZE,8); ObjectSetString(0,nml,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,nml,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nml,OBJPROP_BACK,false);
   }
}

//=================================================================
//  MARKET STRUCTURE LABELS
//=================================================================

void DrawMarketStructureLabels()
{
   DeleteObjects(PFX_MS);
   int lookback=40;
   double H[],L[]; ArraySetAsSeries(H,true); ArraySetAsSeries(L,true);
   if (CopyHigh(g_sym,Inp_TF_Entry,0,lookback,H)<lookback) return;
   if (CopyLow (g_sym,Inp_TF_Entry,0,lookback,L)<lookback) return;
   datetime T[]; ArraySetAsSeries(T,true);
   if (CopyTime(g_sym,Inp_TF_Entry,0,lookback,T)<lookback) return;

   int cnt=0; double prev_hi=0,prev_lo=0;
   for (int i=3;i<lookback-3&&cnt<12;i++)
   {
      if (H[i]>H[i-1]&&H[i]>H[i+1]&&H[i]>H[i-2]&&H[i]>H[i+2])
      {
         string lbl; color c;
         if (prev_hi==0){lbl="HIGH";c=clrSilver;}
         else if(H[i]>prev_hi){lbl="HH";c=C'0,220,100';}
         else{lbl="LH";c=C'255,100,60';}
         prev_hi=H[i];
         string nm=PFX_MS+"H"+IntegerToString(cnt);
         if(ObjectFind(0,nm)<0)ObjectCreate(0,nm,OBJ_TEXT,0,T[i],H[i]);
         ObjectSetInteger(0,nm,OBJPROP_TIME,T[i]); ObjectSetDouble(0,nm,OBJPROP_PRICE,H[i]+ATRe()*0.15);
         ObjectSetString(0,nm,OBJPROP_TEXT,lbl); ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
         ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,7); ObjectSetString(0,nm,OBJPROP_FONT,"Arial Bold");
         ObjectSetInteger(0,nm,OBJPROP_ANCHOR,ANCHOR_LOWER);
         ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm,OBJPROP_BACK,false);
         cnt++;
      }
      if (L[i]<L[i-1]&&L[i]<L[i+1]&&L[i]<L[i-2]&&L[i]<L[i+2])
      {
         string lbl; color c;
         if(prev_lo==0){lbl="LOW";c=clrSilver;}
         else if(L[i]<prev_lo){lbl="LL";c=C'255,80,80';}
         else{lbl="HL";c=C'50,200,150';}
         prev_lo=L[i];
         string nm=PFX_MS+"L"+IntegerToString(cnt);
         if(ObjectFind(0,nm)<0)ObjectCreate(0,nm,OBJ_TEXT,0,T[i],L[i]);
         ObjectSetInteger(0,nm,OBJPROP_TIME,T[i]); ObjectSetDouble(0,nm,OBJPROP_PRICE,L[i]-ATRe()*0.15);
         ObjectSetString(0,nm,OBJPROP_TEXT,lbl); ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
         ObjectSetInteger(0,nm,OBJPROP_FONTSIZE,7); ObjectSetString(0,nm,OBJPROP_FONT,"Arial Bold");
         ObjectSetInteger(0,nm,OBJPROP_ANCHOR,ANCHOR_UPPER);
         ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm,OBJPROP_BACK,false);
         cnt++;
      }
   }
}

//=================================================================
//  ATR ЗОНЫ
//=================================================================

void DrawATRZones()
{
   DeleteObjects(PFX_ATR);
   MqlTick tk; if (!SymbolInfoTick(g_sym,tk)) return;
   double cur=tk.bid, atr=ATRe();
   if (atr<=0) return;
   datetime T[]; ArraySetAsSeries(T,true);
   if (CopyTime(g_sym,Inp_TF_Entry,0,2,T)<2) return;
   datetime t_right=T[0]+(datetime)PeriodSeconds(Inp_TF_Entry)*80;
   double u1=cur+atr, u2=cur+atr*2, d1=cur-atr, d2=cur-atr*2;
   string nms[]={PFX_ATR+"U1",PFX_ATR+"U2",PFX_ATR+"D1",PFX_ATR+"D2"};
   double prs[]={u1,u2,d1,d2};
   string txts[]={" +1 ATR"," +2 ATR"," -1 ATR"," -2 ATR"};
   color  cols[]={C'60,120,180',C'30,80,140',C'180,100,60',C'140,60,30'};
   for (int i=0;i<4;i++)
   {
      if(ObjectFind(0,nms[i])<0) ObjectCreate(0,nms[i],OBJ_HLINE,0,0,prs[i]);
      ObjectSetDouble(0,nms[i],OBJPROP_PRICE,prs[i]); ObjectSetInteger(0,nms[i],OBJPROP_COLOR,cols[i]);
      ObjectSetInteger(0,nms[i],OBJPROP_WIDTH,1); ObjectSetInteger(0,nms[i],OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,nms[i],OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nms[i],OBJPROP_BACK,true);
      string ln=nms[i]+"_L";
      if(ObjectFind(0,ln)<0) ObjectCreate(0,ln,OBJ_TEXT,0,t_right,prs[i]);
      ObjectSetInteger(0,ln,OBJPROP_TIME,t_right); ObjectSetDouble(0,ln,OBJPROP_PRICE,prs[i]);
      ObjectSetString(0,ln,OBJPROP_TEXT,txts[i]+StringFormat(" (%.5f)",prs[i]));
      ObjectSetInteger(0,ln,OBJPROP_COLOR,cols[i]); ObjectSetInteger(0,ln,OBJPROP_FONTSIZE,7);
      ObjectSetString(0,ln,OBJPROP_FONT,"Arial"); ObjectSetInteger(0,ln,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,ln,OBJPROP_BACK,false);
   }
}

//=================================================================
//  СЕССИОННЫЕ ЗОНЫ
//=================================================================

void DrawSessionZones()
{
   DeleteObjects(PFX_SES);
   datetime now=TimeCurrent();
   MqlDateTime dt; TimeToStruct(now,dt);
   datetime day_start=now-(dt.hour*3600+dt.min*60+dt.sec);

   struct SesInfo { string name; int h_start; int h_end; color c; };
   SesInfo ses[3];
   ses[0].name="London";  ses[0].h_start=Inp_London_Start;  ses[0].h_end=Inp_London_End;  ses[0].c=C'50,130,220';
   ses[1].name="NewYork"; ses[1].h_start=Inp_NewYork_Start; ses[1].h_end=Inp_NewYork_End; ses[1].c=C'220,100,50';
   ses[2].name="Asia";    ses[2].h_start=Inp_Asia_Start;    ses[2].h_end=Inp_Asia_End;    ses[2].c=C'180,50,220';

   for (int s=0;s<3;s++)
   {
      datetime t_open=day_start+ses[s].h_start*3600;
      datetime t_close=day_start+ses[s].h_end*3600;
      string nm_o=PFX_SES+ses[s].name+"_O";
      string nm_c=PFX_SES+ses[s].name+"_C";
      string nm_l=PFX_SES+ses[s].name+"_L";
      if(ObjectFind(0,nm_o)<0)ObjectCreate(0,nm_o,OBJ_VLINE,0,t_open,0);
      ObjectSetInteger(0,nm_o,OBJPROP_TIME,t_open); ObjectSetInteger(0,nm_o,OBJPROP_COLOR,ses[s].c);
      ObjectSetInteger(0,nm_o,OBJPROP_WIDTH,1); ObjectSetInteger(0,nm_o,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,nm_o,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm_o,OBJPROP_BACK,true);
      if(ObjectFind(0,nm_c)<0)ObjectCreate(0,nm_c,OBJ_VLINE,0,t_close,0);
      ObjectSetInteger(0,nm_c,OBJPROP_TIME,t_close); ObjectSetInteger(0,nm_c,OBJPROP_COLOR,ses[s].c);
      ObjectSetInteger(0,nm_c,OBJPROP_WIDTH,1); ObjectSetInteger(0,nm_c,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,nm_c,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm_c,OBJPROP_BACK,true);
      MqlTick tkt; SymbolInfoTick(g_sym,tkt);
      if(ObjectFind(0,nm_l)<0)ObjectCreate(0,nm_l,OBJ_TEXT,0,t_open,tkt.bid);
      ObjectSetInteger(0,nm_l,OBJPROP_TIME,t_open); ObjectSetDouble(0,nm_l,OBJPROP_PRICE,tkt.bid);
      ObjectSetString(0,nm_l,OBJPROP_TEXT,ses[s].name); ObjectSetInteger(0,nm_l,OBJPROP_COLOR,ses[s].c);
      ObjectSetInteger(0,nm_l,OBJPROP_FONTSIZE,8); ObjectSetString(0,nm_l,OBJPROP_FONT,"Arial Bold");
      ObjectSetInteger(0,nm_l,OBJPROP_ANCHOR,ANCHOR_UPPER);
      ObjectSetInteger(0,nm_l,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,nm_l,OBJPROP_BACK,false);
   }
}

//=================================================================
//  МАСТЕР-ПЕРЕРИСОВКА
//=================================================================

void RedrawAll()
{
   AddIndicatorsToChart();
   DrawFibonacci();
   DrawSupportResistance();
   DrawTrendLines();
   DrawMarketStructureLabels();
   DrawATRZones();
   DrawSessionZones();
   UpdatePanel();
   ChartRedraw(0);
   g_last_chart_draw = TimeCurrent();
}

//=================================================================
//  OnChartEvent — КНОПКА
//=================================================================

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if (id==CHARTEVENT_OBJECT_CLICK && sparam==BTN_SS)
   {
      g_running = !g_running;
      ObjectSetInteger(0, BTN_SS, OBJPROP_STATE, false);
      UpdatePanel();
      PrintFormat("[PANEL] Торговля %s", g_running?"ЗАПУЩЕНА ▶":"ОСТАНОВЛЕНА ■");
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//  КОНЕЦ ФАЙЛА — MT5 Beast Micro v8 SMART BEAST
//  N3onhex | Gold[PRIMARY] + EUR + GBP + BTC
//  $23 → $5000 Auto-Scale | 4-Phase Trail | Smart Impulse v8
//+------------------------------------------------------------------+
