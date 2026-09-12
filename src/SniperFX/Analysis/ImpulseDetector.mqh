#ifndef SNIPERFX_IMPULSE_DETECTOR_MQH
#define SNIPERFX_IMPULSE_DETECTOR_MQH

#include "..\Core\DomainTypes.mqh"
#include "ConfirmedPivotDetector.mqh"
#include "TrendRegimeModel.mqh"

struct SImpulse
  {
   bool valid;
   ENUM_SNIPER_DIRECTION direction;
   double origin;
   double end_price;
   double broken_level;
   double atr;
   double displacement_atr;
   double body_fraction;
   double quality;
   datetime origin_time;
   datetime end_time;
   datetime confirmed_at;
   string reason;
  };

bool DetectImpulse(const MqlRates &bars[],const int count,const ENUM_SNIPER_DIRECTION direction,
                   const int pivot_left_right,const double min_displacement_atr,
                   const double min_body_fraction,SImpulse &impulse)
  {
   impulse.valid=false; impulse.direction=direction; impulse.origin=0.0; impulse.end_price=0.0;
   impulse.broken_level=0.0; impulse.atr=ClosedATR(bars,count,1,14);
   impulse.displacement_atr=0.0; impulse.body_fraction=0.0; impulse.quality=0.0;
   impulse.origin_time=0; impulse.end_time=0; impulse.confirmed_at=0; impulse.reason="INVALID";
   if(direction==DIRECTION_NONE || count<40 || impulse.atr<=0.0)
     { impulse.reason="NO_DIRECTION_OR_DATA"; return(false); }

   int recent_shift=-1,previous_shift=-1;
   bool found=(direction==DIRECTION_BUY)
              ? FindTwoConfirmedLows(bars,count,pivot_left_right,recent_shift,previous_shift)
              : FindTwoConfirmedHighs(bars,count,pivot_left_right,recent_shift,previous_shift);
   if(!found)
     { impulse.reason="ORIGIN_PIVOT_MISSING"; return(false); }

   int origin_shift=recent_shift;
   int broken_shift=-1;
   for(int shift=origin_shift+1; shift<count-pivot_left_right; shift++)
     {
      bool pivot=(direction==DIRECTION_BUY)
                 ? IsConfirmedHigh(bars,count,shift,pivot_left_right)
                 : IsConfirmedLow(bars,count,shift,pivot_left_right);
      if(pivot) { broken_shift=shift; break; }
     }
   if(broken_shift<0)
     { impulse.reason="BROKEN_PIVOT_MISSING"; return(false); }

   impulse.origin=(direction==DIRECTION_BUY ? bars[origin_shift].low : bars[origin_shift].high);
   impulse.broken_level=(direction==DIRECTION_BUY ? bars[broken_shift].high : bars[broken_shift].low);
   impulse.origin_time=bars[origin_shift].time;

   int end_shift=1;
   double end_value=(direction==DIRECTION_BUY ? bars[1].high : bars[1].low);
   int break_shift=-1;
   for(int shift=1; shift<origin_shift; shift++)
     {
      if(direction==DIRECTION_BUY && bars[shift].high>end_value) { end_value=bars[shift].high; end_shift=shift; }
      if(direction==DIRECTION_SELL && bars[shift].low<end_value) { end_value=bars[shift].low; end_shift=shift; }
      bool closed_break=(direction==DIRECTION_BUY ? bars[shift].close>impulse.broken_level
                                                  : bars[shift].close<impulse.broken_level);
      if(closed_break && (break_shift<0 || shift>break_shift))
         break_shift=shift;
     }
   if(break_shift<0)
     { impulse.reason="NO_CLOSED_BREAK"; return(false); }

   impulse.end_price=end_value;
   impulse.end_time=bars[end_shift].time;
   impulse.confirmed_at=bars[1].time;
   double displacement=MathAbs(impulse.end_price-impulse.origin);
   impulse.displacement_atr=displacement/impulse.atr;
   double bar_range=MathMax(bars[break_shift].high-bars[break_shift].low,0.00000001);
   impulse.body_fraction=MathAbs(bars[break_shift].close-bars[break_shift].open)/bar_range;
   impulse.quality=0.5*MathMin(impulse.displacement_atr/2.0,1.0)+
                   0.5*MathMin(impulse.body_fraction,1.0);

   bool directional=(direction==DIRECTION_BUY ? impulse.end_price>impulse.broken_level
                                              : impulse.end_price<impulse.broken_level);
   if(!directional || impulse.displacement_atr<min_displacement_atr)
     { impulse.reason="WEAK_DISPLACEMENT"; return(false); }
   if(impulse.body_fraction<min_body_fraction)
     { impulse.reason="WEAK_BREAK_BODY"; return(false); }

   impulse.valid=true; impulse.reason="OK";
   return(true);
  }

#endif

