#ifndef SNIPERFX_TRADE_RECONCILER_MQH
#define SNIPERFX_TRADE_RECONCILER_MQH

enum ENUM_MANAGED_BROKER_STATE
  {
   MANAGED_NONE=0,
   MANAGED_ORDER_PENDING=1,
   MANAGED_POSITION_OPEN=2,
   MANAGED_CONFLICT=3
  };

int CountManagedPositions(const ulong magic)
  {
   int count=0;
   for(int index=PositionsTotal()-1; index>=0; index--)
     {
      ulong ticket=PositionGetTicket(index);
      if(ticket>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==magic) count++;
     }
   return(count);
  }

int CountManagedOrders(const ulong magic)
  {
   int count=0;
   for(int index=OrdersTotal()-1; index>=0; index--)
     {
      ulong ticket=OrderGetTicket(index);
      if(ticket>0 && (ulong)OrderGetInteger(ORDER_MAGIC)==magic) count++;
     }
   return(count);
  }

ENUM_MANAGED_BROKER_STATE ManagedBrokerState(const ulong magic)
  {
   int positions=CountManagedPositions(magic);
   int orders=CountManagedOrders(magic);
   if(positions>1 || orders>1 || (positions>0 && orders>0)) return(MANAGED_CONFLICT);
   if(positions==1) return(MANAGED_POSITION_OPEN);
   if(orders==1) return(MANAGED_ORDER_PENDING);
   return(MANAGED_NONE);
  }

bool HasManagedPositionOrOrder(const string symbol,const ulong magic)
  {
   for(int index=PositionsTotal()-1; index>=0; index--)
     {
      ulong ticket=PositionGetTicket(index);
      if(ticket>0 && PositionGetString(POSITION_SYMBOL)==symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==magic) return(true);
     }
   for(int index=OrdersTotal()-1; index>=0; index--)
     {
      ulong ticket=OrderGetTicket(index);
      if(ticket>0 && OrderGetString(ORDER_SYMBOL)==symbol &&
         (ulong)OrderGetInteger(ORDER_MAGIC)==magic) return(true);
     }
   return(false);
  }

#endif

