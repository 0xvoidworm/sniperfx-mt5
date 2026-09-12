#ifndef SNIPERFX_PULLBACK_DETECTOR_MQH
#define SNIPERFX_PULLBACK_DETECTOR_MQH

#include "ImpulseDetector.mqh"

struct SPullback
  {
   bool valid;
   double depth;
   double extreme;
   double contraction_ratio;
   int bars;
   datetime start_time;
   datetime confirmed_at;
   string reason;
  };

bool DetectPullback(const MqlRates &bars[],const int count,const SImpulse &impulse,
                    const double min_depth,const double max_depth,
                    const int min_bars,const int max_bars,SPullback &pullback)
  {
   pullback.valid=false; pullback.depth=0.0; pullback.extreme=0.0;
   pullback.contraction_ratio=0.0; pullback.bars=0; pullback.start_time=0;
   pullback.confirmed_at=(count>1 ? bars[1].time : 0); pullback.reason="INVALID";
   double impulse_size=MathAbs(impulse.end_price-impulse.origin);
   if(!impulse.valid || count<16 || impulse_size<=0.0)
     { pullback.reason="NO_IMPULSE_OR_DATA"; return(false); }

   datetime start_after=impulse.end_time+PeriodSeconds(PERIOD_H1);
   int bars_after=0;
   double extreme=(impulse.direction==DIRECTION_BUY ? DBL_MAX : -DBL_MAX);
   double range_sum=0.0;
   for(int shift=1; shift<count && bars_after<max_bars+1; shift++)
     {
      if(bars[shift].time<start_after)
         break;
      bars_after++;
      range_sum+=bars[shift].high-bars[shift].low;
      if(impulse.direction==DIRECTION_BUY) extreme=MathMin(extreme,bars[shift].low);
      else extreme=MathMax(extreme,bars[shift].high);
      bool invalid=(impulse.direction==DIRECTION_BUY ? bars[shift].close<=impulse.origin
                                                     : bars[shift].close>=impulse.origin);
      if(invalid) { pullback.reason="STRUCTURE_INVALIDATED"; return(false); }
     }
   pullback.bars=bars_after;
   if(bars_after<min_bars || bars_after>max_bars)
     { pullback.reason="DURATION_OUTSIDE_RANGE"; return(false); }

   pullback.extreme=extreme;
   pullback.depth=(impulse.direction==DIRECTION_BUY)
                  ? (impulse.end_price-extreme)/impulse_size
                  : (extreme-impulse.end_price)/impulse_size;
   pullback.contraction_ratio=(impulse.atr>0.0 ? (range_sum/bars_after)/(impulse.atr/4.0) : 0.0);
   pullback.start_time=start_after;
   if(pullback.depth<min_depth || pullback.depth>max_depth)
     { pullback.reason="DEPTH_OUTSIDE_RANGE"; return(false); }

   pullback.valid=true; pullback.reason="OK";
   return(true);
  }

#endif

