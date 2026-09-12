#ifndef SNIPERFX_TIMEFRAME_CACHE_MQH
#define SNIPERFX_TIMEFRAME_CACHE_MQH

#include "..\Core\DomainTypes.mqh"

class CTimeframeCache
  {
private:
   string m_symbol;
   MqlRates m_rates[];
   int m_count;
   datetime m_last_closed;
   bool m_ready;

public:
   CTimeframeCache(void) { m_symbol=""; m_count=0; m_last_closed=0; m_ready=false; }
   bool Initialize(const string symbol,const int capacity)
     {
      m_symbol=symbol;
      ArrayResize(m_rates,capacity);
      ArraySetAsSeries(m_rates,true);
      m_count=0;
      m_last_closed=0;
      m_ready=false;
      return(m_symbol!="" && capacity>=16);
     }

   bool Refresh(const ENUM_TIMEFRAMES timeframe,const int requested)
     {
      if(m_symbol=="")
         return(false);
      // CopyRates is also the synchronization trigger for non-chart symbols in
      // the Strategy Tester and on a fresh terminal. Do not gate it behind a
      // SERIES_SYNCHRONIZED check or those symbols can remain cold forever.
      ResetLastError();
      int copied=CopyRates(m_symbol,timeframe,0,requested,m_rates);
      long synchronized=0;
      if(!SymbolIsSynchronized(m_symbol) ||
         !SeriesInfoInteger(m_symbol,timeframe,SERIES_SYNCHRONIZED,synchronized) ||
         synchronized==0)
         return(false);
      if(copied<requested || copied<3)
         return(false);
      if(m_rates[1].time<=0 || m_rates[1].time>=m_rates[0].time)
         return(false);
      m_last_closed=m_rates[1].time;
      m_count=copied;
      m_ready=true;
      return(true);
     }

   bool Ready() const { return(m_ready); }
   datetime LastClosedTime() const { return(m_last_closed); }
   bool HasNewClosedBar(const datetime previous) const { return(m_ready && m_last_closed>previous); }
   MqlRates Bar(const int shift) const { return(m_rates[shift]); }
   int Count() const { return(m_count); }
    void CopyTo(MqlRates &target[]) const
       {
         ArrayResize(target,m_count);
         ArraySetAsSeries(target,true);
         ArrayCopy(target,m_rates,0,0,m_count);
       }
  };

#endif
