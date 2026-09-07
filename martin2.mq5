//+------------------------------------------------------------------+
//|                              Martingale_Grid_EA_Educational.mq5  |
//|                        Только для образовательных целей!         |
//+------------------------------------------------------------------+
#property copyright "Investment Analyst (Educational Purpose)"
#property version   "2.01"
#property strict

#include <Trade\Trade.mqh>

//--- Входные параметры
input double  InitialLot         = 0.01;     // Базовый лот
input double  LotMultiplier      = 2.0;      // Множитель Мартингейла
input int     MaxMartingaleSteps = 5;        // Макс. кол-во удвоений (лимит)
input int     GridStep           = 100;      // Шаг сетки в пунктах (расстояние между позициями)
input int     TakeProfit         = 50;      // Общий тейк-профит серии в пунктах
input long    MagicNumber        = 789012;   // Уникальный номер советника
input string  TradeComment       = "MartGrid_Edu";

//--- Глобальные переменные
CTrade trade;

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   Print("=== Martingale Grid EA ===");
   Print("Шаг сетки: ", GridStep, " пунктов");
   Print("Макс. шагов удвоения: ", MaxMartingaleSteps);
   Print("Общий TP серии: ", TakeProfit, " пунктов");
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Подсчет количества открытых позиций серии                        |
//+------------------------------------------------------------------+
int CountSeriesPositions(ENUM_POSITION_TYPE &seriesType) {
   int count = 0;
   seriesType = POSITION_TYPE_BUY;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
         if(count == 0) {
            seriesType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         }
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Получение цены открытия последней позиции серии                  |
//+------------------------------------------------------------------+
double GetLastPositionPrice(ENUM_POSITION_TYPE seriesType) {
   datetime lastTime = 0;
   double lastPrice = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == seriesType) {
         
         datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(posTime > lastTime) {
            lastTime = posTime;
            lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }
   return lastPrice;
}

//+------------------------------------------------------------------+
//| Расчет суммарной прибыли/убытка серии в пунктах                  |
//+------------------------------------------------------------------+
double CalculateSeriesProfitInPoints(ENUM_POSITION_TYPE seriesType) {
   double totalProfitPoints = 0;
   double totalVolume = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == seriesType) {
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double volume = PositionGetDouble(POSITION_VOLUME);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         double profitPoints = 0;
         if(seriesType == POSITION_TYPE_BUY) {
            profitPoints = (currentPrice - openPrice) / _Point;
         } else {
            profitPoints = (openPrice - currentPrice) / _Point;
         }
         
         totalProfitPoints += profitPoints * volume;
         totalVolume += volume;
      }
   }
   
   if(totalVolume > 0) {
      return totalProfitPoints / totalVolume; // Средневзвешенная прибыль в пунктах
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Закрытие всех позиций серии                                      |
//+------------------------------------------------------------------+
void CloseAllSeriesPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
         
         trade.PositionClose(ticket);
         Print("Закрыта позиция #", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Расчет лота для текущего шага                                    |
//+------------------------------------------------------------------+
double CalculateLot(int step) {
   double lot = InitialLot;
   
   for(int i = 0; i < step && i < MaxMartingaleSteps; i++) {
      lot *= LotMultiplier;
   }
   
   // Нормализация
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(minLot, lot);
   lot = MathMin(maxLot, lot);
   lot = MathRound(lot / lotStep) * lotStep;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Основная логика                                                  |
//+------------------------------------------------------------------+
void OnTick() {
   ENUM_POSITION_TYPE seriesType;
   int seriesCount = CountSeriesPositions(seriesType);
   
   // === СЦЕНАРИЙ 1: Нет открытых позиций - открываем первую ===
   if(seriesCount == 0) {
      double lot = CalculateLot(0);
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Простой сигнал: случайный выбор (в реальности - ваша стратегия)
      bool buySignal = (MathRand() % 2 == 1);
      
      if(buySignal) {
         trade.Buy(lot, _Symbol, price, 0, 0, TradeComment);
         Print("Открыта первая позиция BUY. Лот: ", lot);
      } else {
         price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         trade.Sell(lot, _Symbol, price, 0, 0, TradeComment);
         Print("Открыта первая позиция SELL. Лот: ", lot);
      }
      return;
   }
   
   // === СЦЕНАРИЙ 2: Есть позиции - проверяем условия ===
   
   // 2.1. Проверяем, достигли ли общего тейк-профита серии
   double avgProfitPoints = CalculateSeriesProfitInPoints(seriesType);
   
   if(avgProfitPoints >= TakeProfit) {
      Print("=== ДОСТИГНУТ ОБЩИЙ TP СЕРИИ ===");
      Print("Средняя прибыль: ", avgProfitPoints, " пунктов");
      CloseAllSeriesPositions();
      return;
   }
   
   // 2.2. Проверяем, нужно ли открыть следующую позицию сетки
   if(seriesCount > MaxMartingaleSteps) {
      Print("ДОСТИГНУТ ЛИМИТ ШАГОВ (", MaxMartingaleSteps, "). Новые позиции не открываются.");
      return;
   }
   
   double lastPrice = GetLastPositionPrice(seriesType);
   double currentPrice = (seriesType == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double distancePoints = 0;
   if(seriesType == POSITION_TYPE_BUY) {
      distancePoints = (lastPrice - currentPrice) / _Point; // Цена упала
   } else {
      distancePoints = (currentPrice - lastPrice) / _Point; // Цена выросла
   }
   
   // Если цена ушла против позиции на GridStep пунктов - открываем следующую
   if(distancePoints >= GridStep) {
      double lot = CalculateLot(seriesCount);
      
      // Проверка маржи - ИСПРАВЛЕННАЯ ВЕРСИЯ
      double marginRequired = 0;
      ENUM_ORDER_TYPE orderType;
      
      if(seriesType == POSITION_TYPE_BUY) {
         orderType = ORDER_TYPE_BUY;
      } else {
         orderType = ORDER_TYPE_SELL;
      }
      
      double orderPrice = (seriesType == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(!OrderCalcMargin(orderType, _Symbol, lot, orderPrice, marginRequired)) {
         Print("Ошибка расчета маржи");
         return;
      }
      
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(freeMargin < marginRequired * 1.5) {
         Print("КРИТИЧЕСКАЯ ОШИБКА: Недостаточно маржи для лота ", lot);
         return;
      }
      
      if(seriesType == POSITION_TYPE_BUY) {
         trade.Buy(lot, _Symbol, orderPrice, 0, 0, TradeComment);
         Print("Открыта усредняющая позиция BUY #", seriesCount + 1, ". Лот: ", lot, 
               ". Дистанция: ", distancePoints, " п.");
      } else {
         trade.Sell(lot, _Symbol, orderPrice, 0, 0, TradeComment);
         Print("Открыта усредняющая позиция SELL #", seriesCount + 1, ". Лот: ", lot, 
               ". Дистанция: ", distancePoints, " п.");
      }
   }
}