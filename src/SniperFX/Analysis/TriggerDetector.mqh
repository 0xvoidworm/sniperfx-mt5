#ifndef SNIPERFX_TRIGGER_DETECTOR_MQH
#define SNIPERFX_TRIGGER_DETECTOR_MQH

#include "ZoneBuilder.mqh"

struct STrigger
  {
   bool valid;
   datetime time;
   double high;
   double low;
   double entry_reference;
   string reason;
  };

bool DetectClosedM5Trigger(const MqlRates &bars[],const int count,const SZone &zone,
                           const ENUM_SNIPER_DIRECTION direction,STrigger &trigger)
  {
   trigger.valid=false; trigger.time=0; trigger.high=0.0; trigger.low=0.0;
   trigger.entry_reference=0.0; trigger.reason="INVALID";
   if(count<4 || zone.state>=ZONE_EXPIRED || direction==DIRECTION_NONE)
     { trigger.reason="ZONE_OR_DATA_INVALID"; return(false); }
   MqlRates bar=bars[1];
   bool touched=bar.low<=zone.high_price && bar.high>=zone.low_price;
   bool reclaim=(direction==DIRECTION_BUY ? bar.close>zone.high_price : bar.close<zone.low_price);
   bool micro_break=(direction==DIRECTION_BUY ? bar.close>bars[2].high : bar.close<bars[2].low);
   if(!touched) { trigger.reason="ZONE_NOT_TOUCHED"; return(false); }
   if(!reclaim) { trigger.reason="NO_RECLAIM"; return(false); }
   if(!micro_break) { trigger.reason="NO_MICRO_BREAK"; return(false); }
   trigger.valid=true; trigger.time=bar.time; trigger.high=bar.high; trigger.low=bar.low;
   trigger.entry_reference=(direction==DIRECTION_BUY ? bar.high : bar.low);
   trigger.reason="OK";
   return(true);
  }

#endif

