//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, Rodrigo Malacarne / Alain Verleyen"
#property copyright "© GM, 2020, 2021, 2022, 2023"
#property description "Stocks heatmap"

#property strict    //--- For compatibility with MT4
#property indicator_chart_window
#property indicator_plots   0

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <Arrays\ArrayString.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- ENUMS
enum ENUM_SCALE_TYPE {
   Dinâmica,
   Fixa
};

enum ENUM_INDICATOR_TYPE_DISPLAY {
   Scale,
   Gradient,
   Heatmap
};

enum ENUM_INDICATOR_TYPE {
   Alfabética, //Alfabética
   Diária,     //Diária
   Semanal,    //Semanal
   Mensal,     //Mensal
   Volume      //Volume
};

enum ENUM_MODO_ORDENACAO {
   ordCrescente, //Crescente
   ordDecrescente     //Decrescente
};

enum ENUM_MERCADO {
   Ações,
   Futuros,
   Todos
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- INPUTS
input string                              indicatorSettings    =  "----- Indicator Settings";      // ■ Indicator Management
input string                              inputIndicatorName = "heatmap";
input ENUM_INDICATOR_TYPE                 indicatorType = Volume;
input ENUM_MODO_ORDENACAO                 modoOrdenacao = ordDecrescente;
input ENUM_MERCADO                        inputMercado = Ações;
input ENUM_INDICATOR_TYPE_DISPLAY         indicatorTypeDisplay        =  Heatmap;                         // Indicator Type
input int                                 inputPeriodos = 200;
input bool                                filterFutures  = true;
input double                              filterVolume = 0;
input bool                                filterByAverage = false;
input color                               textColor = clrWhite;
input color                               positiveColor = clrLime;
input color                               neutralColor = C'55,55,55';
input color                               negativeColor = clrRed;
input int                                 inputFontSize = 8;
input int                                 inputColunas = 15;
input double                              alturaBox = 35;
input double                              larguraBox = 60;
input bool                                boxCompleto = true;
input int                                 WaitMilliseconds = 1000;  // Timer (milliseconds) for recalculation
input bool                                debug = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- GLOBALS
string         marketWatchSymbolsList[];
double         targetMaxMin[];
int            symbolsTotal = 0;
double scaleMax, scaleMin, scaleEdge;
int midValue;
int n, total;
double soma, media, vwap;
MqlRates       DailyBar[];
string ativo;
int totalRates, periodos;
string indicatorName;
double volumeMedioMercado;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct objeto {
   string            nome;
   double            variacaoD;
   double            variacaoS;
   double            variacaoM;
   long              contratosD;
   long              contratosS;
   long              contratosM;
   double            financeiroD;
   double            financeiroS;
   double            financeiroM;
   double            volumeDirecional;
   double            volume_medioH[10];
   double            volume_medioD;
   double            volume_medioS;
   double            volume_medioM;
   double            vwapx;
   color             colorVariacao;
   color             colorD;
   color             colorS;
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#define ArraySortStruct(T, ARRAY, FIELD)                                         \
{                                                                                \
  class SORT{                                                                    \
  private:                                                                       \
    static void Swap( T &Array[], const int i, const int j ){                    \
      const T Temp = Array[i];                                                   \
      Array[i] = Array[j];                                                       \
      Array[j] = Temp;                                                           \
      return;                                                                    \
    }                                                                            \
                                                                                 \
    static int Partition( T &Array[], const int Start, const int End ){          \
      int Marker = Start;                                                        \
      for (int i = Start; i <= End; i++)                                         \
        if (Array[i].##FIELD <= Array[End].##FIELD){                             \
          SORT::Swap(Array, i, Marker);                                          \
          Marker++;                                                              \
        }                                                                        \
       return(Marker - 1);                                                       \
    }                                                                            \
                                                                                 \
    static void QuickSort( T &Array[], const int Start, const int End ) {        \
      if (Start < End){                                                          \
        const int Pivot = Partition(Array, Start, End);                          \
        SORT::QuickSort(Array, Start, Pivot - 1);                                \
        SORT::QuickSort(Array, Pivot + 1, End);                                  \
      }                                                                          \
      return;                                                                    \
    }                                                                            \
                                                                                 \
  public:                                                                        \
    static void Sort( T &Array[], int Count = WHOLE_ARRAY, const int Start = 0 ){\
      if (Count == WHOLE_ARRAY)                                                  \
        Count = ::ArraySize(Array);                                              \
                                                                                 \
      SORT::QuickSort(Array, Start, Start + Count - 1);                          \
                                                                                 \
return;                                                                          \
}                                                                                \
};                                                                               \
                                                                                 \
SORT::Sort(ARRAY);                                                               \
}                                                                                \

objeto arrayObjetos[];

//+------------------------------------------------------------------+
//| Indicator initialization function                                |
//+------------------------------------------------------------------+
int OnInit() {

   indicatorName = inputIndicatorName + "_";

   _updateTimer = new MillisecondTimer(WaitMilliseconds, false);

   if(SymbolsTotal(true) < 5) {
      Alert("The minimum number of symbols must be 5 (five).");
      return(INIT_PARAMETERS_INCORRECT);
   }

   periodos = inputPeriodos;
   EventSetMillisecondTimer(WaitMilliseconds);
   ArraySetAsSeries(DailyBar, true);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Indicator deinitialization function                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//--- Delete only what is drawn by your code
   delete(_updateTimer);
   deleteScale(symbolsTotal);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Indicator iteration function                                     |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[]) {
   return (1);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
   CheckTimer();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTimer() {
   EventKillTimer();

   if(_updateTimer.Check() || !_lastOK) {
      _lastOK = Update();
      //if (debug) Print("Heatmap " + " " + _Symbol + ":" + GetTimeFrame(Period()) + " ok");

      EventSetMillisecondTimer(WaitMilliseconds);

      _updateTimer.Reset();
   } else {
      EventSetTimer(1);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Update() {
   int currentSymbolsTotal = SymbolsTotal(true);


   ObjectsDeleteAll(0, indicatorName);

//--- If we add or remove a symbol to the market watch
   if(symbolsTotal != currentSymbolsTotal) {
      //--- resize arrays
      ArrayResize(marketWatchSymbolsList, currentSymbolsTotal);

      //--- update arrays of symbol's name
      for(int i = 0; i < currentSymbolsTotal; i++) {
         ativo = SymbolName(i, true);
         marketWatchSymbolsList[i] = ativo;
      }

      int count = 0;
      string tempArray[];
      for(int i = 0; i < currentSymbolsTotal; i++) {
         ativo = SymbolName(i, true);
         double current_bid = SymbolInfoDouble(ativo, SYMBOL_BID);
         double current_ask = SymbolInfoDouble(ativo, SYMBOL_ASK);
         vwap = SymbolInfoDouble(ativo, SYMBOL_SESSION_AW);
         if (current_bid > 0 && current_ask > 0) { // filter non-relevant symbols (that have insignificant volumes)
            ENUM_SYMBOL_CALC_MODE tipoMercado = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(ativo, SYMBOL_TRADE_CALC_MODE);
            if (inputMercado == Ações) {
               if (tipoMercado == SYMBOL_CALC_MODE_EXCH_STOCKS) {
                  if ((filterVolume > 0) && (iRealVolume(ativo, PERIOD_D1, 0) * vwap >= filterVolume)) {
                     ArrayInsert(tempArray, marketWatchSymbolsList, count, i, 1);
                     count++;
                  } else if (filterVolume == 0) {
                     ArrayInsert(tempArray, marketWatchSymbolsList, count, i, 1);
                     count++;
                  }
               }
            } else if (inputMercado == Futuros) {
               if (tipoMercado == SYMBOL_CALC_MODE_FUTURES || tipoMercado == SYMBOL_CALC_MODE_EXCH_FUTURES) {
                  if ((filterVolume > 0) && (iRealVolume(ativo, PERIOD_D1, 0) * vwap >= filterVolume)) {
                     ArrayInsert(tempArray, marketWatchSymbolsList, count, i, 1);
                     count++;
                  } else if (filterVolume == 0) {
                     ArrayInsert(tempArray, marketWatchSymbolsList, count, i, 1);
                     count++;
                  }
               }
            } else if (inputMercado == Todos) {
               if (tipoMercado == SYMBOL_CALC_MODE_EXCH_STOCKS || tipoMercado == SYMBOL_CALC_MODE_FUTURES || tipoMercado == SYMBOL_CALC_MODE_EXCH_FUTURES) {
                  if ((filterVolume > 0) && (iRealVolume(ativo, PERIOD_D1, 0) * vwap >= filterVolume)) {
                     ArrayInsert(tempArray, marketWatchSymbolsList, count, i, 1);
                     count++;
                  } else if (filterVolume == 0) {
                     ArrayInsert(tempArray, marketWatchSymbolsList, count, i, 1);
                     count++;
                  }
               }
            }
         }
      }

      ArrayResize(marketWatchSymbolsList, count);
      ArrayCopy(marketWatchSymbolsList, tempArray);
      currentSymbolsTotal = ArraySize(marketWatchSymbolsList);

      // sort array
      CArrayString array;
      array.Step(1);
      string x[];
      for(int i = 0; i < currentSymbolsTotal; i++) {
         array.Add(marketWatchSymbolsList[i]);
      }
      array.Resize(currentSymbolsTotal);
      array.Sort(0);
      //ArrayResize(x, currentSymbolsTotal);
      for(int i = 0; i < array.Total(); i++) {
         string atual = array.At(i);
         marketWatchSymbolsList[i] = array.At(i);
      }
      //ArrayCopy(marketWatchSymbolsList, x);
      currentSymbolsTotal = ArraySize(marketWatchSymbolsList);

      ArrayResize(targetMaxMin, currentSymbolsTotal);
      ArrayResize(arrayObjetos, currentSymbolsTotal);

      volumeMedioMercado = 0;
      for(int i = 0; i < currentSymbolsTotal; i++) {
         ativo = marketWatchSymbolsList[i];
         arrayObjetos[i].nome = ativo;
         arrayObjetos[i].vwapx = SymbolInfoDouble(ativo, SYMBOL_SESSION_AW);
         arrayObjetos[i].contratosD = iRealVolume(ativo, PERIOD_D1, 0);
         arrayObjetos[i].financeiroD = arrayObjetos[i].contratosD * arrayObjetos[i].vwapx;
         volumeMedioMercado = volumeMedioMercado + arrayObjetos[i].financeiroD;
         int direcao;

         //--- Calculates the percent change of each symbol
         if(CopyRates(ativo, PERIOD_D1, 0, 2, DailyBar) == 2)
            arrayObjetos[i].variacaoD = ((DailyBar[0].close / DailyBar[1].close) - 1) * 100;

         if(CopyRates(ativo, PERIOD_W1, 0, 2, DailyBar) == 2)
            arrayObjetos[i].variacaoS = ((DailyBar[0].close / DailyBar[1].close) - 1) * 100;

         if(CopyRates(ativo, PERIOD_MN1, 0, 2, DailyBar) == 2)
            arrayObjetos[i].variacaoM = ((DailyBar[0].close / DailyBar[1].close) - 1) * 100;

         if (arrayObjetos[i].variacaoD >= 0)
            arrayObjetos[i].volumeDirecional = arrayObjetos[i].financeiroD;
         else
            arrayObjetos[i].volumeDirecional = -1 * arrayObjetos[i].financeiroD;

      }

      //--- remove Panel1in excess
      deleteScale(symbolsTotal, currentSymbolsTotal);
      symbolsTotal = currentSymbolsTotal;
   }
   volumeMedioMercado = (double) (volumeMedioMercado / currentSymbolsTotal);

   if (filterByAverage) {
      for(int i = 0; i < currentSymbolsTotal; i++) {
         if (arrayObjetos[i].financeiroD < volumeMedioMercado) {
            ArrayRemove(arrayObjetos, i, 1);
            ArrayRemove(targetMaxMin, i, 1);
            currentSymbolsTotal--;
            i--;
         } else {
            int z = 0;
         }
      }
   }
   symbolsTotal = currentSymbolsTotal;

   periodos = inputPeriodos;
   datetime dataAlvo = iTime(NULL, PERIOD_D1, periodos);
   long barraAlvo = iBarShift(NULL, PERIOD_H1, dataAlvo);
   double countVolume[][10];
   double somaVolume[][10];
   ArrayResize(countVolume, currentSymbolsTotal);
   ArrayResize(somaVolume, currentSymbolsTotal);
   for(int i = 0; i < currentSymbolsTotal; i++) {
      for(int k = 0; k < 10; k++) {
         somaVolume[i][k] = 0;
         countVolume[i][k] = 0;
      }
   }


   for(int i = 0; i < currentSymbolsTotal; i++) {
      ativo = arrayObjetos[i].nome;
      totalRates = SeriesInfoInteger(ativo, PERIOD_H1, SERIES_BARS_COUNT);
      if (barraAlvo > totalRates)
         barraAlvo = totalRates;

      if (periodos > totalRates)
         periodos = totalRates;

      for(int j = 0; j < barraAlvo; j++) {
         double v = iRealVolume(ativo, PERIOD_H1, j);
         double h = iHigh(ativo, PERIOD_H1, j);
         double l = iLow(ativo, PERIOD_H1, j);
         double c = iClose(ativo, PERIOD_H1, j);
         double p = (double) (h + l + c) / 3;
         datetime tempo = iTime(ativo, PERIOD_H1, j);
         MqlDateTime time;
         TimeToStruct(tempo, time);
         int hora = time.hour;

         switch (hora) {
         case 9 :
            somaVolume[i][0] = somaVolume[i][0] + (v * p);
            countVolume[i][0] = countVolume[i][0] + 1;
            break;
         case 10 :
            somaVolume[i][1] = somaVolume[i][1] + (v * p);
            countVolume[i][1] = countVolume[i][1] + 1;
            break;
         case 11 :
            somaVolume[i][2] = somaVolume[i][2] + (v * p);
            countVolume[i][2] = countVolume[i][2] + 1;
            break;
         case 12 :
            somaVolume[i][3] = somaVolume[i][3] + (v * p);
            countVolume[i][3] = countVolume[i][3] + 1;
            break;
         case 13 :
            somaVolume[i][4] = somaVolume[i][4] + (v * p);
            countVolume[i][4] = countVolume[i][4] + 1;
            break;
         case 14 :
            somaVolume[i][5] = somaVolume[i][5] + (v * p);
            countVolume[i][5] = countVolume[i][5] + 1;
            break;
         case 15 :
            somaVolume[i][6] = somaVolume[i][6] + (v * p);
            countVolume[i][6] = countVolume[i][6] + 1;
            break;
         case 16 :
            somaVolume[i][7] = somaVolume[i][7] + (v * p);
            countVolume[i][7] = countVolume[i][7] + 1;
            break;
         case 17 :
            somaVolume[i][8] = somaVolume[i][8] + (v * p);
            countVolume[i][8] = countVolume[i][8] + 1;
            break;
         case 18 :
            somaVolume[i][9] = somaVolume[i][9] + (v * p);
            countVolume[i][9] = countVolume[i][9] + 1;
            break;
         }
      }

      double volD = 0;
      for(int k = 0; k < 10; k++) {
         if (countVolume[i][k] > 0) {
            arrayObjetos[i].volume_medioH[k] = (double) (somaVolume[i][k] / countVolume[i][k]);
         } else {
            // this is necessary because of some sort of initialition bug on array. This fixes it.
            arrayObjetos[i].volume_medioH[k] = 0;
         }
         volD = volD + arrayObjetos[i].volume_medioH[k];
      }
      arrayObjetos[i].volume_medioD = volD;

      //if (ativo == "MATD3") {
      //   string teste = DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[0], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[1], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[2], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[3], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[4], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[5], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[6], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[7], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[8], 0), 0)
      //                  + " - " + DoubleToString(NormalizeDouble(arrayObjetos[i].volume_medioH[9], 0), 0);
      //   Print(volD  );
      //}

      if (indicatorType == Diária) {
         targetMaxMin[i] = arrayObjetos[i].variacaoD;
      } else if (indicatorType == Semanal) {
         targetMaxMin[i] = arrayObjetos[i].variacaoS;
      } else if (indicatorType == Mensal) {
         targetMaxMin[i] = arrayObjetos[i].variacaoM;
      } else if (indicatorType == Alfabética) {
         targetMaxMin[i] = arrayObjetos[i].nome;
      } else if (indicatorType == Volume) {
         targetMaxMin[i] = arrayObjetos[i].volumeDirecional;
      }
   }

   if (indicatorType == Diária) {
      ArraySortStruct(objeto, arrayObjetos, variacaoD);
   } else if (indicatorType == Semanal) {
      ArraySortStruct(objeto, arrayObjetos, variacaoS);
   } else if (indicatorType == Mensal) {
      ArraySortStruct(objeto, arrayObjetos, variacaoM);
   } else if (indicatorType == Volume) {
      ArraySortStruct(objeto, arrayObjetos, volumeDirecional);
   }

   if (modoOrdenacao == ordDecrescente)
      ArrayReverse(arrayObjetos);

   doHeatmap();

   ChartRedraw();

   return true;
}

//+------------------------------------------------------------------+
//| Heatmap                                                          |
//+------------------------------------------------------------------+
void doHeatmap() {

   int    arrayMax, arrayMin;
   string strColor[];
   double UltraVol = 0, VeryHighVol = 0, HighVol = 0;

   StringSplit(ColorToString(positiveColor), StringGetCharacter(",", 0), strColor);
//--- Color 1 parameters
   int r_1 = (int)strColor[0];
   int g_1 = (int)strColor[1];
   int b_1 = (int)strColor[2];

   StringSplit(ColorToString(neutralColor), StringGetCharacter(",", 0), strColor);
//--- Color 2 parameters
   int r_2 = (int)strColor[0];
   int g_2 = (int)strColor[1];
   int b_2 = (int)strColor[2];

   StringSplit(ColorToString(negativeColor), StringGetCharacter(",", 0), strColor);
//--- Color 3 parameters
   int r_3 = (int)strColor[0];
   int g_3 = (int)strColor[1];
   int b_3 = (int)strColor[2];

   midValue = (symbolsTotal % 2 == 0 ? symbolsTotal / 2 : (symbolsTotal - 1) / 2) - 1;
   double fatorColor = 1;
//--- Build an array of colors and calculate percentage price's change
   for(int i = 0; i < symbolsTotal; i++) {
      ativo = arrayObjetos[i].nome;
      double volMedio = 0;
      //--- Local variables
      int r_value = r_2;
      int g_value = g_2;
      int b_value = b_2;

      if(i <= midValue) { // Positive values
         //--- Positive interpolation function
         r_value = (r_1 - i * (r_1 - r_2) / midValue);
         g_value = g_1 - i * (g_1 - g_2) / midValue;
         b_value = (b_1 - i * (b_1 - b_2) / midValue) ;
         //r_value = r_1 + i * 0.5;
         //g_value = g_1 - i;
         //b_value = b_1 + i * 0.5;
         //if (g_value > 254)
         //   g_value = 254;
         //if (g_value < 50)
         //   g_value = 50;
         int z = 0;
      } else {
         //--- Negative interpolation function
         r_value = (r_2 - (i - midValue - 1) * (r_2 - r_3) / midValue) * fatorColor;
         g_value = g_2 - (i - midValue - 1) * (g_2 - g_3) / midValue;
         b_value = b_2 - (i - midValue - 1) * (b_2 - b_3) / midValue;
         //r_value = r_1 - i;
         //g_value = g_1 + i * 0.5;
         //b_value = b_1 + i * 0.5;
      }

      //--- Sets all possible colors to the array colorArray1[]
      string rgbColor = IntegerToString(r_value) + "," + IntegerToString(g_value) + "," + IntegerToString(b_value);
      arrayObjetos[i].colorVariacao = StringToColor(rgbColor);

      if (indicatorType != Volume) {

         volMedio = arrayObjetos[i].volume_medioD;
         double financeiro = arrayObjetos[i].financeiroD;
         UltraVol = volMedio * 4;
         VeryHighVol = volMedio * 3;
         HighVol = volMedio * 2;
         //--- Positive interpolation function
         if(financeiro >= UltraVol) { // Positive values
            arrayObjetos[i].colorD = clrMagenta;
         } else if(financeiro >= VeryHighVol && financeiro < UltraVol) {
            arrayObjetos[i].colorD = clrRed;
         } else if(financeiro >= HighVol && financeiro < VeryHighVol) {
            arrayObjetos[i].colorD = clrYellow;
         } else {
            arrayObjetos[i].colorD = neutralColor;
         }

      } else if (indicatorType == Volume) {
         MqlDateTime time;
         TimeToStruct(TimeCurrent(), time);
         int hora = time.hour;
         if (hora < 9)
            hora = 9;

         if (hora > 18)
            hora = 18;

         //hora = 15;
         volMedio = 0;

         if (hora >= 9 && hora <= 18) {
            for(int k = 0; k <= hora - 9; k++) {
               volMedio = volMedio + arrayObjetos[i].volume_medioH[k];
               int z = 0;
            }

         }

         if (volMedio > 0) {
            //arrayObjetos[i].financeiroD = iRealVolume(ativo, PERIOD_H1, iBarShift(ativo, PERIOD_H1, "2022.9.21 10:00:00")) * SymbolInfoDouble(ativo, SYMBOL_SESSION_AW);;
            double volAtual = arrayObjetos[i].financeiroD;
            UltraVol = volMedio * 3;
            VeryHighVol = volMedio * 2;
            HighVol = volMedio * 1.3;
            //--- Positive interpolation function
            if(volAtual >= UltraVol) { // Positive values
               arrayObjetos[i].colorD = clrMagenta;
            } else if(volAtual >= VeryHighVol && volAtual < UltraVol) {
               arrayObjetos[i].colorD = clrRed;
            } else if(volAtual >= HighVol && volAtual < VeryHighVol) {
               arrayObjetos[i].colorD = clrYellow;
            } else if(volAtual >= volMedio && volAtual < HighVol) {
               arrayObjetos[i].colorD = neutralColor;
            } else if(volAtual < volMedio) {
               arrayObjetos[i].colorD = neutralColor;

            }
         } else {
            arrayObjetos[i].colorD = neutralColor;
         }

      }
   }

//--- Determine maximum/minimum and the scale value
   arrayMax = ArrayMaximum(targetMaxMin);
   arrayMin = ArrayMinimum(targetMaxMin);
   if(arrayMax == -1 || arrayMin == -1)
      return;

//--- Determine the scale
   scaleEdge = MathMax(MathAbs(targetMaxMin[arrayMax]), MathAbs(targetMaxMin[arrayMin]));
//scaleMax = scaleEdge;
//scaleMin = -scaleEdge;
   scaleMax = MathAbs(targetMaxMin[arrayMax]);
   scaleMin = -MathAbs(targetMaxMin[arrayMin]);
   midValue = (symbolsTotal % 2 == 0 ? symbolsTotal / 2 : (symbolsTotal - 1) / 2);

//--- Sets colors to the heatmap
   total = 0;
   int divisor = inputColunas - 1;
   int linhas, colunas;
   if (symbolsTotal % divisor > 0)
      linhas = symbolsTotal / divisor + 1;
   int resto = symbolsTotal % divisor;

   n = 0;
   for (int x = 0; x < linhas - 1; x++) {
      for(int y = 0; y < divisor; y++) {
         boxDisplay(x, y);
      }
   }

   int x = linhas - 1;
   for (int y = 0; y < resto; y++) {
      boxDisplay(x, y);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void boxDisplay(int linha, int coluna) {

   double financeiro = arrayObjetos[n].financeiroD;
   double volMedio = arrayObjetos[n].volume_medioD;
   double razao = (double) (financeiro / volMedio);
//--- Local variable
   int heatmapColor = 0;
   int largura = larguraBox;
   int altura = alturaBox;
   if (indicatorType != Volume && boxCompleto)
      altura = altura + 14;

   int x = 10 * (coluna + 1) + coluna * largura;
   int y = 10 + linha * altura;

   largura = largura - 6;

   double comparaX, comparaY;
   string texto;
   if (indicatorType == Alfabética || indicatorType == Diária) {
      comparaX = arrayObjetos[n].variacaoD;
      comparaY = 0;
      texto = DoubleToString(arrayObjetos[n].variacaoD, 2) + "%";
   } else if (indicatorType == Semanal) {
      comparaX = arrayObjetos[n].variacaoS;
      comparaY = 0;
      texto = DoubleToString(arrayObjetos[n].variacaoS, 2) + "%";
   } else if (indicatorType == Mensal) {
      comparaX = arrayObjetos[n].variacaoM;
      comparaY = 0;
      texto = DoubleToString(arrayObjetos[n].variacaoM, 2) + "%";
   } else if (indicatorType == Volume) {
      comparaX = arrayObjetos[n].volumeDirecional;
      comparaY = volumeMedioMercado;
      texto = DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2);
   }

//--- Sets the color position (gradientColor) inside the colorArray1
   if(comparaX >= comparaY) {
      //--- color index between 0 and (symbolsTotal/2)-1
      heatmapColor = (int)MathFloor((1 - comparaX / scaleMax) * midValue);
   } else if(comparaX < comparaY) {
      //--- color index between symbolsTotal/2 and symbolsTotal-1
      heatmapColor = (int)MathCeil((comparaX / scaleMin) * midValue) + midValue - 1;
   } else {
      heatmapColor = midValue; // Mid position
   }

   if(heatmapColor < 0)
      Print("Array out of range, heatmapcolor=", heatmapColor);

   if(heatmapColor >= symbolsTotal)
      Print("Array out of range, heatmapcolor=", heatmapColor, " colorArray1 size=", symbolsTotal);

   SetPanel(indicatorName + "Panel1" + "_x" + linha + "_y" + coluna, 0, x, y, largura, altura - 3, arrayObjetos[heatmapColor].colorVariacao, neutralColor, 1);
   SetText(indicatorName + "Text1" + "_x" + linha + "_y" + coluna, arrayObjetos[n].nome, x + 3, y + 3, textColor, inputFontSize,
           "Variação D: "  + DoubleToString(arrayObjetos[n].variacaoD, 2) + "%" + "\n"
           "Variação S: "  + DoubleToString(arrayObjetos[n].variacaoS, 2) + "%" + "\n"
           "Variação M: "  + DoubleToString(arrayObjetos[n].variacaoM, 2) + "%" + "\n"
           "Vol. $ Médio: " + DoubleToStrCommaSep(arrayObjetos[n].volume_medioD, 2) + "\n"
           "Vol. $ Atual: " + DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2));

   if(arrayObjetos[linha].volume_medioD >= 0) {
      SetText(indicatorName + "Value1" + "_" + IntegerToString(n), texto, x + 5, y + 17, textColor, inputFontSize,
              "Variação D: "  + DoubleToString(arrayObjetos[n].variacaoD, 2) + "%" + "\n"
              "Variação S: "  + DoubleToString(arrayObjetos[n].variacaoS, 2) + "%" + "\n"
              "Variação M: "  + DoubleToString(arrayObjetos[n].variacaoM, 2) + "%" + "\n"
              "Vol. $ Médio: " + DoubleToStrCommaSep(arrayObjetos[n].volume_medioD, 2) + "\n"
              "Vol. $ Atual: " + DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2));
   } else {
      SetText(indicatorName + "Value1" + "_" + IntegerToString(n), texto, x + 3, y + 17, textColor, inputFontSize,
              "Variação D: "  + DoubleToString(arrayObjetos[n].variacaoD, 2) + "%" + "\n"
              "Variação S: "  + DoubleToString(arrayObjetos[n].variacaoS, 2) + "%" + "\n"
              "Variação M: "  + DoubleToString(arrayObjetos[n].variacaoM, 2) + "%" + "\n"
              "Vol. $ Médio: " + DoubleToStrCommaSep(arrayObjetos[n].volume_medioD, 2) + "\n"
              "Vol. $ Atual: " + DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2));
   }

   if (indicatorType != Volume && boxCompleto) {
      SetText(indicatorName + "Value2" + "_" + IntegerToString(n), DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2), x + 3, y + 28, textColor, inputFontSize,
              "Variação D: "  + DoubleToString(arrayObjetos[n].variacaoD, 2) + "%" + "\n"
              "Variação S: "  + DoubleToString(arrayObjetos[n].variacaoS, 2) + "%" + "\n"
              "Variação M: "  + DoubleToString(arrayObjetos[n].variacaoM, 2) + "%" + "\n"
              "Vol. $ Médio: " + DoubleToStrCommaSep(arrayObjetos[n].volume_medioD, 2) + "\n"
              "Vol. $ Atual: " + DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2));
   }

   heatmapColor = n;
   SetPanel(indicatorName + "Panel2" + "_" + IntegerToString(n), 0, x + largura, y - 1, 8, altura - 1, arrayObjetos[heatmapColor].colorD, arrayObjetos[heatmapColor].colorD, 0);
   SetText(indicatorName + "Value2" + "_" + IntegerToString(n), " ", x + largura, y + 14, textColor, inputFontSize,
           "Variação D: "  + DoubleToString(arrayObjetos[n].variacaoD, 2) + "%" + "\n"
           "Variação S: "  + DoubleToString(arrayObjetos[n].variacaoS, 2) + "%" + "\n"
           "Variação M: "  + DoubleToString(arrayObjetos[n].variacaoM, 2) + "%" + "\n"
           "Vol. $ Médio: " + DoubleToStrCommaSep(arrayObjetos[n].volume_medioD, 2) + "\n"
           "Vol. $ Atual: " + DoubleToStrCommaSep(arrayObjetos[n].financeiroD, 2));

//double tempY = y - 1 + altura * (1 - razao);
//if (tempY < 0)
//   tempY = altura;
//SetPanel(indicatorName + "Panel3" + "_" + IntegerToString(n), 0, x + largura, tempY, 8, 2, arrayObjetos[heatmapColor].colorD, clrBlack, 1);

   n++;
   total++;
//ChartRedraw();
   int z = 0;
}

//+------------------------------------------------------------------+
//| Remove unneeded objects from main chart                          |
//+------------------------------------------------------------------+
void deleteScale(int from, int to = 1) {
   from--;
   to--;
   for(int i = from; i >= to; i--) {
      ObjectDelete(0, indicatorName + "Panel1" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Text1" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Value1" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Panel2" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Text2" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Value2" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Value3" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Value4" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Panel3" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Panel4" + IntegerToString(i));
      ObjectDelete(0, indicatorName + "Panel5" + IntegerToString(i));

   }
}

//+------------------------------------------------------------------+
//| Draw data about a symbol in a Panel1                             |
//+------------------------------------------------------------------+
void SetText(string name, string text, int x, int y, color colour, int fontsize = 12, string tooltip = "\n") {
   if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_COLOR, colour);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Draw a Panel1with given color for a symbol                       |
//+------------------------------------------------------------------+
void SetPanel(string name, int sub_window, int x, int y, int width, int height, color bg_color, color border_clr, int border_width) {
   if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, sub_window, 0, 0)) {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border_clr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      //ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, neutralColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, 0);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
}

//+------------------------------------------------------------------+
//| Draw a Panel1with given color for a symbol                       |
//+------------------------------------------------------------------+
void SetTrend(string name, int sub_window, int x, int y, int width, int height, color bg_color, color border_clr, int border_width) {
   if(ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, sub_window, 0, 0)) {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_COLOR, border_clr);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      //ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, neutralColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, border_width);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, 0);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string DoubleToStrCommaSep(double v, int decimals = 4, string s = "") { // 6,454.23

   string abbr = "";
//Septillion: Y; sextillion: Z; Quintillion: E; Quadrillion: Q; Trillion: T; Billion: B; Million: M;
//if (v > 999999999999999999999999) { v = v/1000000000000000000000000; abbr = "Y"; } else
//if (v > 999999999999999999999) { v = v/1000000000000000000000; abbr = "Z"; } else
//if (v > 999999999999999999) { v = v/1000000000000000000; abbr = "E"; } else
//if (v > 999999999999999) { v = v/1000000000000000; abbr = "Q";} else
   if (v > 999999999999) {
      v = v / 1000000000000;
      abbr = "T";
   } else if (v > 999999999) {
      v = v / 1000000000;
      abbr = "B";
   } else if (v > 999999) {
      v = v / 1000000;
      abbr = "M";
   } else if (v > 999) {
      v = v / 1000;
      abbr = "K";
   }


   v = NormalizeDouble(v, decimals);
   int integer = v;

   if (decimals == 0) {
      return( IntToStrCommaSep(v, s) + abbr);
   } else {
      string fraction = StringSubstr(DoubleToString(v - integer, decimals), 1);
      return(IntToStrCommaSep(integer, s) + fraction + abbr);
   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string IntToStrCommaSep(int integer, string s = "") {

   string right;
   if(integer < 0) {
      s = "-";
      integer = -integer;
   }

   for(right = ""; integer >= 1000; integer /= 1000)
      right = "," + RJust(integer % 1000, 3, "0") + right;

   return(s + integer + right);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string RJust(string s, int size, string fill = "0") {
   while( StringLen(s) < size )
      s = fill + s;
   return(s);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MillisecondTimer {

 private:
   int               _milliseconds;
 private:
   uint              _lastTick;

 public:
   void              MillisecondTimer(const int milliseconds, const bool reset = true) {
      _milliseconds = milliseconds;

      if(reset)
         Reset();
      else
         _lastTick = 0;
   }

 public:
   bool              Check() {
      uint now = getCurrentTick();
      bool stop = now >= _lastTick + _milliseconds;

      if(stop)
         _lastTick = now;

      return(stop);
   }

 public:
   void              Reset() {
      _lastTick = getCurrentTick();
   }

 private:
   uint              getCurrentTick() const {
      return(GetTickCount());
   }

};

//+---------------------------------------------------------------------+
//| GetTimeFrame function - returns the textual timeframe               |
//+---------------------------------------------------------------------+
string GetTimeFrame(int lPeriod) {
   switch(lPeriod) {
   case PERIOD_M1:
      return("M1");
   case PERIOD_M2:
      return("M2");
   case PERIOD_M3:
      return("M3");
   case PERIOD_M4:
      return("M4");
   case PERIOD_M5:
      return("M5");
   case PERIOD_M6:
      return("M6");
   case PERIOD_M10:
      return("M10");
   case PERIOD_M12:
      return("M12");
   case PERIOD_M15:
      return("M15");
   case PERIOD_M20:
      return("M20");
   case PERIOD_M30:
      return("M30");
   case PERIOD_H1:
      return("H1");
   case PERIOD_H2:
      return("H2");
   case PERIOD_H3:
      return("H3");
   case PERIOD_H4:
      return("H4");
   case PERIOD_H6:
      return("H6");
   case PERIOD_H8:
      return("H8");
   case PERIOD_H12:
      return("H12");
   case PERIOD_D1:
      return("D1");
   case PERIOD_W1:
      return("W1");
   case PERIOD_MN1:
      return("MN1");
   }
   return IntegerToString(lPeriod);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool _lastOK = false;
MillisecondTimer *_updateTimer;
bool _updateOnTick = true;
//+------------------------------------------------------------------+
