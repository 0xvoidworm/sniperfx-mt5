#ifndef SNIPERFX_PENDING_ORDER_BUILDER_MQH
#define SNIPERFX_PENDING_ORDER_BUILDER_MQH

#include "..\Data\BrokerCapabilities.mqh"

double PendingEntryPrice(const ENUM_ORDER_TYPE type,const double trigger_reference,
                         const double entry_buffer_ticks,const SBrokerCapabilities &caps,
                         const MqlTick &tick)
  {
   double min_distance=MinimumStopDistance(caps);
   double desired_buffer=MathMax(caps.tick_size,entry_buffer_ticks*caps.tick_size);
   double entry=(type==ORDER_TYPE_BUY_STOP)
                ? MathMax(trigger_reference+desired_buffer,tick.ask+min_distance)
                : MathMin(trigger_reference-desired_buffer,tick.bid-min_distance);
   return(NormalizePriceToTick(entry,caps));
  }

bool BuildPendingStop(const string symbol,const ENUM_ORDER_TYPE type,const double trigger_reference,
                      const double entry_buffer_ticks,const double stop,const double target,
                      const double volume,const datetime expiration,const ulong magic,
                      const string comment,MqlTradeRequest &request,string &reason)
  {
   ZeroMemory(request);
   if(type!=ORDER_TYPE_BUY_STOP && type!=ORDER_TYPE_SELL_STOP)
     { reason="UNSUPPORTED_PENDING_TYPE"; return(false); }

   SBrokerCapabilities caps;
   if(!ReadBrokerCapabilities(symbol,caps)) { reason="BROKER_CAPABILITIES"; return(false); }
   if(!caps.trade_allowed || !SupportsPendingStops(caps)) { reason="PENDING_STOP_NOT_ALLOWED"; return(false); }
   if((type==ORDER_TYPE_BUY_STOP && caps.trade_mode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (type==ORDER_TYPE_SELL_STOP && caps.trade_mode==SYMBOL_TRADE_MODE_LONGONLY))
     { reason="DIRECTION_NOT_ALLOWED"; return(false); }
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || tick.ask<=0.0 || tick.bid<=0.0)
     { reason="NO_TICK"; return(false); }

   double min_distance=MinimumStopDistance(caps);
   double entry=PendingEntryPrice(type,trigger_reference,entry_buffer_ticks,caps,tick);

   request.action=TRADE_ACTION_PENDING;
   request.symbol=symbol;
   request.volume=FloorVolumeToStep(volume,caps);
   request.type=type;
   request.price=NormalizePriceToTick(entry,caps);
   request.sl=NormalizePriceToTick(stop,caps);
   request.tp=NormalizePriceToTick(target,caps);
   request.magic=magic;
   request.type_filling=ORDER_FILLING_RETURN;
   request.comment=StringSubstr(comment,0,31);
   if((caps.expiration_mode & SYMBOL_EXPIRATION_SPECIFIED)==SYMBOL_EXPIRATION_SPECIFIED)
     {
      request.type_time=ORDER_TIME_SPECIFIED;
      request.expiration=expiration;
     }
   else
     {
      request.type_time=ORDER_TIME_GTC;
      request.expiration=0;
     }

   if(request.volume<caps.volume_min || request.price<=0.0 || request.sl<=0.0 || request.tp<=0.0)
     { reason="INVALID_NORMALIZED_ORDER"; return(false); }
   if(type==ORDER_TYPE_BUY_STOP)
     {
      if(request.sl>=request.price || request.tp<=request.price) { reason="INVALID_BUY_LEVELS"; return(false); }
      if(request.price-request.sl<min_distance || request.tp-request.price<min_distance) { reason="BUY_STOPS_TOO_CLOSE"; return(false); }
     }
   else
     {
      if(request.sl<=request.price || request.tp>=request.price) { reason="INVALID_SELL_LEVELS"; return(false); }
      if(request.sl-request.price<min_distance || request.price-request.tp<min_distance) { reason="SELL_STOPS_TOO_CLOSE"; return(false); }
     }
   reason="OK";
   return(true);
  }

#endif
