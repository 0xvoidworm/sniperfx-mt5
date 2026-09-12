#ifndef SNIPERFX_TREND_REGIME_MODEL_MQH
#define SNIPERFX_TREND_REGIME_MODEL_MQH

#include "..\Core\DomainTypes.mqh"
#include "ConfirmedPivotDetector.mqh"

struct STrendRegimeResult
  {
   ENUM_SNIPER_DIRECTION direction;
   double efficiency;
   double normalized_slope;
   double atr;
   datetime confirmed_at;
   string reason;
  };

double ClosedEfficiencyRatio(const MqlRates &bars[],const int count,const int start_shift,const int lookback)
  {
   if(lookback<2 || start_shift<1 || start_shift+lookback>count)
      return(0.0);
   double displacement=MathAbs(bars[start_shift].close-bars[start_shift+lookback-1].close);
   double path=0.0;
   for(int index=start_shift; index<start_shift+lookback-1; index++)
      path+=MathAbs(bars[index].close-bars[index+1].close);
   return(path>0.0 ? displacement/path : 0.0);
  }

double ClosedLogSlope(const MqlRates &bars[],const int count,const int start_shift,const int lookback)
  {
   if(lookback<3 || start_shift<1 || start_shift+lookback>count)
      return(0.0);
   double sum_x=0.0,sum_y=0.0,sum_xy=0.0,sum_x2=0.0;
   for(int index=0; index<lookback; index++)
     {
      double x=(double)index;
      double y=MathLog(MathMax(bars[start_shift+lookback-1-index].close,0.00000001));
      sum_x+=x; sum_y+=y; sum_xy+=x*y; sum_x2+=x*x;
     }
   double denominator=lookback*sum_x2-sum_x*sum_x;
   return(denominator!=0.0 ? (lookback*sum_xy-sum_x*sum_y)/denominator : 0.0);
  }

double ClosedATR(const MqlRates &bars[],const int count,const int start_shift,const int lookback)
  {
   if(lookback<1 || start_shift<1 || start_shift+lookback>=count)
      return(0.0);
   double sum=0.0;
   for(int shift=start_shift; shift<start_shift+lookback; shift++)
     {
      double previous_close=bars[shift+1].close;
      double tr=MathMax(bars[shift].high-bars[shift].low,
                        MathMax(MathAbs(bars[shift].high-previous_close),
                                MathAbs(bars[shift].low-previous_close)));
      sum+=tr;
     }
   return(sum/lookback);
  }

bool DetectRegime(const MqlRates &bars[],const int count,const int pivot_left_right,
                  const int slope_lookback,const int efficiency_lookback,
                  const double min_normalized_slope,const double min_efficiency,
                  STrendRegimeResult &result)
  {
   result.direction=DIRECTION_NONE;
   result.efficiency=ClosedEfficiencyRatio(bars,count,1,efficiency_lookback);
   result.atr=ClosedATR(bars,count,1,14);
   result.confirmed_at=(count>1 ? bars[1].time : 0);
   result.reason="INSUFFICIENT_DATA";
   if(count<MathMax(slope_lookback,efficiency_lookback)+16 || result.atr<=0.0 || bars[1].close<=0.0)
      return(false);

   double raw_slope=ClosedLogSlope(bars,count,1,slope_lookback);
   double atr_fraction=result.atr/bars[1].close;
   result.normalized_slope=(atr_fraction>0.0 ? raw_slope/atr_fraction : 0.0);

   int recent_high=-1,previous_high=-1,recent_low=-1,previous_low=-1;
   if(!FindTwoConfirmedHighs(bars,count,pivot_left_right,recent_high,previous_high) ||
      !FindTwoConfirmedLows(bars,count,pivot_left_right,recent_low,previous_low))
     {
      result.reason="PIVOTS_NOT_CONFIRMED";
      return(false);
     }

   bool bullish_structure=(bars[recent_high].high>bars[previous_high].high &&
                           bars[recent_low].low>bars[previous_low].low);
   bool bearish_structure=(bars[recent_high].high<bars[previous_high].high &&
                           bars[recent_low].low<bars[previous_low].low);
   if(result.efficiency<min_efficiency)
     {
      result.reason="LOW_EFFICIENCY";
      return(false);
     }
   if(bullish_structure && result.normalized_slope>=min_normalized_slope)
     {
      result.direction=DIRECTION_BUY; result.reason="BULLISH"; return(true);
     }
   if(bearish_structure && result.normalized_slope<=-min_normalized_slope)
     {
      result.direction=DIRECTION_SELL; result.reason="BEARISH"; return(true);
     }
   result.reason="STRUCTURE_SLOPE_CONFLICT";
   return(false);
  }

#endif

