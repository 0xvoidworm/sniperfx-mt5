#ifndef SNIPERFX_BROKER_CAPABILITIES_MQH
#define SNIPERFX_BROKER_CAPABILITIES_MQH

struct SBrokerCapabilities
  {
   string symbol;
   int digits;
   double point;
   double tick_size;
   double tick_value;
   double volume_min;
   double volume_max;
   double volume_step;
   double volume_limit;
   long stops_level;
   long freeze_level;
   long filling_mode;
   long expiration_mode;
   long order_mode;
   long trade_mode;
   bool trade_allowed;
  };

bool ReadBrokerCapabilities(const string symbol,SBrokerCapabilities &caps)
  {
   caps.symbol=symbol;
   caps.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   caps.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   caps.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   caps.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   caps.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   caps.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   caps.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   caps.volume_limit=SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   caps.stops_level=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   caps.freeze_level=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   caps.filling_mode=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   caps.expiration_mode=SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);
   caps.order_mode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
   caps.trade_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   caps.trade_allowed=(caps.trade_mode!=SYMBOL_TRADE_MODE_DISABLED && caps.trade_mode!=SYMBOL_TRADE_MODE_CLOSEONLY);
   return(caps.point>0.0 && caps.tick_size>0.0 && caps.volume_min>0.0 &&
          caps.volume_max>=caps.volume_min && caps.volume_step>0.0);
  }

double NormalizePriceToTick(const double price,const SBrokerCapabilities &caps)
  {
   if(caps.tick_size<=0.0)
      return(price);
   return(NormalizeDouble(MathRound(price/caps.tick_size)*caps.tick_size,caps.digits));
  }

double FloorVolumeToStep(const double volume,const SBrokerCapabilities &caps)
  {
   if(caps.volume_step<=0.0)
      return(0.0);
   double result=MathFloor((volume+1e-12)/caps.volume_step)*caps.volume_step;
   return(NormalizeDouble(result,8));
  }

double MinimumStopDistance(const SBrokerCapabilities &caps)
  {
   return(MathMax(caps.tick_size,(double)(caps.stops_level+1)*caps.point));
  }

bool SupportsPendingStops(const SBrokerCapabilities &caps)
  {
   return((caps.order_mode & SYMBOL_ORDER_STOP)==SYMBOL_ORDER_STOP);
  }

#endif
