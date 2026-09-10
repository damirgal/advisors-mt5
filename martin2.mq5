//+------------------------------------------------------------------+
//|                              Martingale_Grid_EA_Educational.mq5  |
//|                        Только для образовательных целей!         |
//+------------------------------------------------------------------+
#property copyright "Investment Analyst (Educational Purpose)"
#property version   "2.07"
#property strict

#include <Trade\Trade.mqh>

//--- Входные параметры
input double  InitialLot         = 0.01;     // Базовый лот
input double  LotMultiplier      = 2.0;      // Множитель Мартингейла
input int     MaxMartingaleSteps = 6;        // Макс. кол-во удвоений (лимит)
input int     GridStep           = 50;      // Шаг сетки в пунктах
input int     TakeProfit         = 20;      // Общий TP серии в пунктах (базовый)
input long    MagicNumber        = 789012;   // Уникальный номер советника
input string  TradeComment       = "MartGrid_Edu";

//--- Параметры адаптивного TP
input int     StepToChangeTP     = 2;        // С какого шага меняется TP (0 = отключено)
input int     AlternativeTakeProfit = 3;    // Альтернативный TP в пунктах

//--- Параметры адаптивного множителя
input int     StepToChangeMultiplier = 2;        // С какого шага меняется множитель (0 = отключено)
input double  AlternativeMultiplier  = 3.0;      // Альтернативный множитель лота

//--- Параметры информационной панели
input bool    ShowInfoPanel      = true;     // Показывать информационную панель
input int     PanelX             = 350;       // Отступ по X от правого края
input int     PanelY             = 20;       // Отступ по Y от верхнего края
input int     PanelFontSize      = 10;        // Размер шрифта панели
input color   PanelColorTitle    = clrGold;  // Цвет заголовка
input color   PanelColorNormal   = clrWhite; // Цвет обычного текста
input color   PanelColorProfit   = clrLime;  // Цвет прибыли
input color   PanelColorLoss     = clrWhite;   // Цвет убытка

//--- Параметры графических линий
input bool    ShowLines          = true;     // Показывать линии на графике
input color   LineColorTP        = clrLime;  // Цвет линии цели закрытия
input color   LineColorNext      = clrRed;   // Цвет линии следующей сделки
input color   LineColorAvg       = clrDodgerBlue; // Цвет линии средней цены
input int     LineWidth          = 2;        // Толщина линий
input ENUM_LINE_STYLE LineStyle  = STYLE_SOLID; // Стиль линий

//--- Глобальные переменные
CTrade trade;
string panelPrefix = "MartPanel_";
string linePrefix  = "MartLine_";

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
int OnInit() {
   // === ПРИНУДИТЕЛЬНАЯ ОЧИСТКА СТАРЫХ ОБЪЕКТОВ ===
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, panelPrefix) == 0 || StringFind(name, linePrefix) == 0) {
         ObjectDelete(0, name);
      }
   }
   ChartRedraw();
   // === КОНЕЦ ОЧИСТКИ ===
   
   Print("=== Martingale Grid EA ===");
   Print("Шаг сетки: ", GridStep, " пунктов");
   Print("Макс. шагов удвоения: ", MaxMartingaleSteps);
   Print("Базовый TP серии: ", TakeProfit, " пунктов");
   
      if(StepToChangeTP > 0) {
      Print("Адаптивный TP: с шага ", StepToChangeTP, " используется TP = ", AlternativeTakeProfit, " пунктов");
   } else {
      Print("Адаптивный TP: отключен");
   }
   
   if(StepToChangeMultiplier > 0) {
      Print("Адаптивный множитель: с шага ", StepToChangeMultiplier, 
            " используется множитель = ", AlternativeMultiplier);
   } else {
      Print("Адаптивный множитель: отключен (стандартный Мартингейл)");
   }
   
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   
   if(ShowInfoPanel) {
      CreateInfoPanel();
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Деинициализация                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(ShowInfoPanel) {
      DeleteInfoPanel();
   }
   if(ShowLines) {
      DeleteLines();
   }
   Print("Советник остановлен. Причина: ", reason);
}

//+------------------------------------------------------------------+
//| Получение текущего TP с учётом адаптивности                      |
//+------------------------------------------------------------------+
int GetCurrentTakeProfit(int seriesCount) {
   if(StepToChangeTP <= 0 || seriesCount < StepToChangeTP) {
      return TakeProfit;
   }
   return AlternativeTakeProfit;
}

//+------------------------------------------------------------------+
//| Создание информационной панели                                   |
//+------------------------------------------------------------------+
void CreateInfoPanel() {
   // Создаем 12 меток для информации
   for(int i = 0; i < 12; i++) {
      string labelName = panelPrefix + "Label_" + IntegerToString(i);
      
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, PanelX);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, PanelY + i * 18);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, PanelFontSize);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Удаление информационной панели                                   |
//+------------------------------------------------------------------+
void DeleteInfoPanel() {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, panelPrefix) == 0) {
         ObjectDelete(0, name);
      }
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Создание/обновление линий на графике                             |
//+------------------------------------------------------------------+
void UpdateLines() {
   if(!ShowLines) return;
   
   ENUM_POSITION_TYPE seriesType;
   int seriesCount = CountSeriesPositions(seriesType);
   
   if(seriesCount == 0) {
      DeleteLines();
      return;
   }
   
   double totalVolume = 0;
   double weightedPrice = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == seriesType) {
         
         double volume = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         
         totalVolume += volume;
         weightedPrice += openPrice * volume;
      }
   }
   
   if(totalVolume == 0) return;
   
   double avgPrice = weightedPrice / totalVolume;
   int currentTP = GetCurrentTakeProfit(seriesCount);
   double tpPrice = 0;
   
   if(seriesType == POSITION_TYPE_BUY) {
      tpPrice = avgPrice + currentTP * _Point;
   } else {
      tpPrice = avgPrice - currentTP * _Point;
   }
   
   double lastPosPrice = GetLastPositionPrice(seriesType);
   double nextTradePrice = 0;
   bool showNextLine = (seriesCount < MaxMartingaleSteps);
   
   if(showNextLine) {
      if(seriesType == POSITION_TYPE_BUY) {
         nextTradePrice = lastPosPrice - GridStep * _Point;
      } else {
         nextTradePrice = lastPosPrice + GridStep * _Point;
      }
   }
   
   CreateOrUpdateHLine(linePrefix + "TP", tpPrice, LineColorTP, "Цель закрытия (TP=" + IntegerToString(currentTP) + ")");
   CreateOrUpdateHLine(linePrefix + "Avg", avgPrice, LineColorAvg, "Средняя цена");
   
   if(showNextLine) {
      CreateOrUpdateHLine(linePrefix + "Next", nextTradePrice, LineColorNext, "След. сделка");
   } else {
      ObjectDelete(0, linePrefix + "Next");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Создание или обновление горизонтальной линии                     |
//+------------------------------------------------------------------+
void CreateOrUpdateHLine(string name, double price, color clr, string tooltip) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
      ObjectSetInteger(0, name, OBJPROP_STYLE, LineStyle);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   } else {
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   }
}

//+------------------------------------------------------------------+
//| Удаление всех линий                                              |
//+------------------------------------------------------------------+
void DeleteLines() {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, linePrefix) == 0) {
         ObjectDelete(0, name);
      }
   }
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Обновление информационной панели                                 |
//+------------------------------------------------------------------+
void UpdateInfoPanel() {
   if(!ShowInfoPanel) return;
   
   ENUM_POSITION_TYPE seriesType;
   int seriesCount = CountSeriesPositions(seriesType);
   
   int lineIndex = 0;
   
   SetPanelText(lineIndex++, "═══ MARTINGALE GRID ═══", PanelColorTitle);
   SetPanelText(lineIndex++, "Symbol: " + _Symbol, PanelColorNormal);
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spreadPoints = (ask - bid) / _Point;
   SetPanelText(lineIndex++, StringFormat("Цена: %.5f | Спред: %.0f п.", bid, spreadPoints), PanelColorNormal);
   
   if(seriesCount == 0) {
      SetPanelText(lineIndex++, "Нет открытых позиций", PanelColorNormal);
      SetPanelText(lineIndex++, "Ожидание сигнала...", PanelColorNormal);
   } else {
      string typeStr = (seriesType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      SetPanelText(lineIndex++, "Серия: " + typeStr + " (" + IntegerToString(seriesCount) + " поз.)", PanelColorNormal);
      SetPanelText(lineIndex++, "Шаг: " + IntegerToString(seriesCount) + "/" + IntegerToString(MaxMartingaleSteps), PanelColorNormal);
      
      int currentTP = GetCurrentTakeProfit(seriesCount);
      double totalVolume = 0;
      double weightedPrice = 0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == seriesType) {
            
            double volume = PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            totalVolume += volume;
            weightedPrice += openPrice * volume;
         }
      }
      
      string tpStatus = (currentTP != TakeProfit) ? " (адапт.)" : "";
      // Определяем текущий множитель для следующей сделки
      double nextMultiplier;
      string multStatus = "";
      if(StepToChangeMultiplier > 0 && seriesCount >= StepToChangeMultiplier) {
         nextMultiplier = AlternativeMultiplier;
         multStatus = " (адапт.)";
      } else {
         nextMultiplier = LotMultiplier;
      }
      
      SetPanelText(lineIndex++, StringFormat("TP: %d%s | Объём: %.2f лота | Множитель: %.1f%s", 
                           currentTP, tpStatus, totalVolume, nextMultiplier, multStatus), PanelColorNormal);
            
      double avgPrice = weightedPrice / totalVolume;
      double tpPrice = 0;
      
      if(seriesType == POSITION_TYPE_BUY) {
         tpPrice = avgPrice + currentTP * _Point;
      } else {
         tpPrice = avgPrice - currentTP * _Point;
      }
      
      SetPanelText(lineIndex++, "─── АНАЛИЗ ───", PanelColorTitle);
      SetPanelText(lineIndex++, StringFormat("Средняя цена: %.5f", avgPrice), PanelColorNormal);
      SetPanelText(lineIndex++, StringFormat("Цель закрытия: %.5f", tpPrice), PanelColorProfit);
      
      double lastPosPrice = GetLastPositionPrice(seriesType);
      double curPrice = (seriesType == POSITION_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double pointsToNext = 0;
      if(seriesType == POSITION_TYPE_BUY) {
         pointsToNext = GridStep - (lastPosPrice - curPrice) / _Point;
      } else {
         pointsToNext = GridStep - (curPrice - lastPosPrice) / _Point;
      }
      
      if(seriesCount >= MaxMartingaleSteps) {
         SetPanelText(lineIndex++, "След. сделка: ЛИМИТ ДОСТИГНУТ", PanelColorLoss);
      } else if(pointsToNext <= 0) {
         SetPanelText(lineIndex++, "След. сделка: ГОТОВА К ОТКРЫТИЮ", PanelColorLoss);
      } else {
         SetPanelText(lineIndex++, StringFormat("След. сделка через: %.1f п.", pointsToNext), PanelColorNormal);
      }
      
      double currentProfit = CalculateSeriesProfitInPoints(seriesType);
      double currentPrice = (seriesType == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double pointsToTarget = 0;
      if(seriesType == POSITION_TYPE_BUY) {
         pointsToTarget = (tpPrice - currentPrice) / _Point;
      } else {
         pointsToTarget = (currentPrice - tpPrice) / _Point;
      }
      
      color profitColor = (currentProfit >= 0) ? PanelColorProfit : PanelColorLoss;
      SetPanelText(lineIndex++, StringFormat("Текущая прибыль: %.1f п.", currentProfit), profitColor);
      
      color distanceColor = (pointsToTarget <= 0) ? PanelColorProfit : PanelColorNormal;
      SetPanelText(lineIndex++, StringFormat("До цели: %.1f п.", pointsToTarget), distanceColor);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Установка текста метки                                           |
//+------------------------------------------------------------------+
void SetPanelText(int lineIndex, string text, color clr = clrWhite) {
   string labelName = panelPrefix + "Label_" + IntegerToString(lineIndex);
   ObjectSetString(0, labelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
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
      return totalProfitPoints / totalVolume;
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
//| Расчет лота для текущего шага с учетом альтернативного множителя |
//+------------------------------------------------------------------+
double CalculateLot(int step) {
   double lot = InitialLot;
   
   for(int i = 0; i < step && i < MaxMartingaleSteps; i++) {
      // Определяем, какой множитель использовать
      double currentMultiplier;
      if(StepToChangeMultiplier > 0 && i >= StepToChangeMultiplier) {
         currentMultiplier = AlternativeMultiplier;
      } else {
         currentMultiplier = LotMultiplier;
      }
      
      lot *= currentMultiplier;
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
   if(ShowInfoPanel) {
      UpdateInfoPanel();
   }
   if(ShowLines) {
      UpdateLines();
   }
   
   ENUM_POSITION_TYPE seriesType;
   int seriesCount = CountSeriesPositions(seriesType);
   
   if(seriesCount == 0) {
      double lot = CalculateLot(0);
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
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
   
   int currentTP = GetCurrentTakeProfit(seriesCount);
   double avgProfitPoints = CalculateSeriesProfitInPoints(seriesType);
   
   if(avgProfitPoints >= currentTP) {
      Print("=== ДОСТИГНУТ ОБЩИЙ TP СЕРИИ ===");
      Print("Текущий TP: ", currentTP, " пунктов (шаг: ", seriesCount, ")");
      Print("Средняя прибыль: ", avgProfitPoints, " пунктов");
      CloseAllSeriesPositions();
      return;
   }
   
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
      distancePoints = (lastPrice - currentPrice) / _Point;
   } else {
      distancePoints = (currentPrice - lastPrice) / _Point;
   }
   
   if(distancePoints >= GridStep) {
      double lot = CalculateLot(seriesCount);
      
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