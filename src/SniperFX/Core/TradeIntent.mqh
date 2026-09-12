#ifndef SNIPERFX_TRADE_INTENT_MQH
#define SNIPERFX_TRADE_INTENT_MQH

#include "DomainTypes.mqh"

struct STradeIntent
  {
   string identity;
   uint identity_hash;
   string symbol;
   ENUM_SNIPER_DIRECTION direction;
   datetime decision_time;
   datetime trigger_time;
   double entry;
   double stop;
   double target;
   double volume;
   ulong order_ticket;
   ulong position_ticket;
   bool recorded;
  };

uint StableStringHash(const string value)
  {
   uint hash=2166136261;
   int length=StringLen(value);
   for(int index=0; index<length; index++)
     {
      hash^=(uint)StringGetCharacter(value,index);
      hash*=16777619;
     }
   return(hash);
  }

string BuildAccountScope()
  {
   string raw=IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN))+"|"+
              AccountInfoString(ACCOUNT_SERVER);
   return(IntegerToString((long)StableStringHash(raw)));
  }

string BuildIntentIdentity(const string account_key,const string symbol,const ENUM_SNIPER_DIRECTION direction,
                           const datetime impulse_time,const datetime zone_time,const datetime trigger_time)
  {
   return(account_key+"|"+symbol+"|"+IntegerToString((int)direction)+"|"+
          IntegerToString((long)impulse_time)+"|"+IntegerToString((long)zone_time)+"|"+IntegerToString((long)trigger_time));
  }

void ResetIntent(STradeIntent &intent)
  {
   intent.identity=""; intent.identity_hash=0; intent.symbol=""; intent.direction=DIRECTION_NONE;
   intent.decision_time=0; intent.trigger_time=0; intent.entry=0.0; intent.stop=0.0;
   intent.target=0.0; intent.volume=0.0; intent.order_ticket=0; intent.position_ticket=0;
   intent.recorded=false;
  }

#endif

