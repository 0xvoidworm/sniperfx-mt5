#ifndef SNIPERFX_ZONE_BUILDER_MQH
#define SNIPERFX_ZONE_BUILDER_MQH

#include "PullbackDetector.mqh"

enum ENUM_ZONE_SOURCE { ZONE_BROKEN_SWING=0, ZONE_IMPULSE_ORIGIN=1, ZONE_SESSION_EXTREME=2 };
enum ENUM_ZONE_STATE { ZONE_CREATED=0, ZONE_APPROACHING=1, ZONE_TOUCHED=2, ZONE_REJECTED=3, ZONE_ACCEPTED=4, ZONE_EXPIRED=5, ZONE_INVALID=6 };

struct SZone
  {
   string id;
   string symbol;
   ENUM_SNIPER_DIRECTION direction;
   ENUM_ZONE_SOURCE source;
   double low_price;
   double high_price;
   datetime created_at;
   datetime expires_at;
   datetime confirmed_at;
   int touch_count;
   double invalidation_price;
   ENUM_ZONE_STATE state;
  };

bool BuildBrokenSwingZone(const string symbol,const SImpulse &impulse,const SPullback &pullback,
                          const double atr_m15,const double half_width_atr,
                          const double stop_buffer_atr,const datetime decision_time,SZone &zone)
  {
   if(!impulse.valid || !pullback.valid || atr_m15<=0.0 || impulse.broken_level<=0.0)
      return(false);
   double half_width=half_width_atr*atr_m15;
   zone.id=symbol+"_SWING_"+IntegerToString((long)impulse.origin_time)+"_"+IntegerToString((long)impulse.end_time);
   zone.symbol=symbol;
   zone.direction=impulse.direction;
   zone.source=ZONE_BROKEN_SWING;
   zone.low_price=impulse.broken_level-half_width;
   zone.high_price=impulse.broken_level+half_width;
   zone.created_at=impulse.end_time;
   zone.expires_at=decision_time+PeriodSeconds(PERIOD_M5)*12;
   zone.confirmed_at=impulse.confirmed_at;
   zone.touch_count=0;
   zone.invalidation_price=(impulse.direction==DIRECTION_BUY)
                           ? pullback.extreme-stop_buffer_atr*atr_m15
                           : pullback.extreme+stop_buffer_atr*atr_m15;
   zone.state=ZONE_CREATED;
   return(zone.low_price<zone.high_price && zone.invalidation_price>0.0);
  }

#endif

