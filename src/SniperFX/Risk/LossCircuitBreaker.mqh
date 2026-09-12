#ifndef SNIPERFX_LOSS_CIRCUIT_BREAKER_MQH
#define SNIPERFX_LOSS_CIRCUIT_BREAKER_MQH

double ManagedDailyPnl(const ulong magic,double &realized,double &unrealized)
  {
   realized=0.0; unrealized=0.0;
   MqlDateTime parts;
   TimeToStruct(TimeCurrent(),parts);
   parts.hour=0; parts.min=0; parts.sec=0;
   datetime day_start=StructToTime(parts);
   if(HistorySelect(day_start,TimeCurrent()))
     {
      int deals=HistoryDealsTotal();
      for(int index=0; index<deals; index++)
        {
         ulong ticket=HistoryDealGetTicket(index);
         if(ticket==0 || (ulong)HistoryDealGetInteger(ticket,DEAL_MAGIC)!=magic) continue;
         realized+=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         realized+=HistoryDealGetDouble(ticket,DEAL_COMMISSION);
         realized+=HistoryDealGetDouble(ticket,DEAL_SWAP);
         realized+=HistoryDealGetDouble(ticket,DEAL_FEE);
        }
     }
   for(int index=PositionsTotal()-1; index>=0; index--)
     {
      ulong ticket=PositionGetTicket(index);
      if(ticket>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==magic)
        {
         unrealized+=PositionGetDouble(POSITION_PROFIT);
         unrealized+=PositionGetDouble(POSITION_SWAP);
        }
     }
   return(realized+unrealized);
  }

bool DailyLossAllows(const ulong magic,const double equity,const double risk_percent,
                     const double max_daily_loss_r,string &reason)
  {
   if(max_daily_loss_r<=0.0 || equity<=0.0 || risk_percent<=0.0)
     { reason="INVALID_DAILY_LIMIT"; return(false); }
   double realized=0.0,unrealized=0.0;
   double pnl=ManagedDailyPnl(magic,realized,unrealized);
   // Keep the daily R denominator anchored near start-of-day equity.
   double start_equity=MathMax(0.0,equity-pnl);
   double one_r=start_equity*risk_percent/100.0;
   if(one_r<=0.0) { reason="INVALID_START_EQUITY"; return(false); }
   if(pnl<=-max_daily_loss_r*one_r) { reason="DAILY_LOSS_REACHED"; return(false); }
   reason="OK";
   return(true);
  }

#endif
