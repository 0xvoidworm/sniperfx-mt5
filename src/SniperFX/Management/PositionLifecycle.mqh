#ifndef SNIPERFX_POSITION_LIFECYCLE_MQH
#define SNIPERFX_POSITION_LIFECYCLE_MQH

#include "..\Data\BrokerCapabilities.mqh"

bool SelectManagedPositionByIndex(const int index,const ulong magic,ulong &ticket)
  {
   ticket=PositionGetTicket(index);
   return(ticket>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==magic);
  }

ENUM_ORDER_TYPE_FILLING MarketFillingMode(const SBrokerCapabilities &caps)
  {
   if((caps.filling_mode & SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK) return(ORDER_FILLING_FOK);
   if((caps.filling_mode & SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC) return(ORDER_FILLING_IOC);
   return(ORDER_FILLING_RETURN);
  }

bool BuildClosePositionRequest(const ulong ticket,const ulong magic,MqlTradeRequest &request,string &reason)
  {
   ZeroMemory(request);
   if(!PositionSelectByTicket(ticket)) { reason="POSITION_NOT_FOUND"; return(false); }
   if((ulong)PositionGetInteger(POSITION_MAGIC)!=magic) { reason="FOREIGN_POSITION"; return(false); }
   string symbol=PositionGetString(POSITION_SYMBOL);
   double volume=PositionGetDouble(POSITION_VOLUME);
   long position_type=PositionGetInteger(POSITION_TYPE);
   MqlTick tick;
   SBrokerCapabilities caps;
   if(volume<=0.0 || !SymbolInfoTick(symbol,tick) || !ReadBrokerCapabilities(symbol,caps))
     { reason="CLOSE_MARKET_DATA"; return(false); }

   request.action=TRADE_ACTION_DEAL;
   request.position=ticket;
   request.symbol=symbol;
   request.volume=volume;
   request.magic=magic;
   request.type=(position_type==POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   request.price=(request.type==ORDER_TYPE_SELL ? tick.bid : tick.ask);
   request.type_filling=MarketFillingMode(caps);
   request.comment="SNIPERFX_TIME_EXIT";
   reason="OK";
   return(true);
  }

#endif

