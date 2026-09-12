#ifndef SNIPERFX_BAR_TIME_STOP_MQH
#define SNIPERFX_BAR_TIME_STOP_MQH

bool TimeStopReachedByCount(const int elapsed_closed_bars,const int bars)
  {
   return(bars>0 && elapsed_closed_bars>=bars);
  }

int ClosedM5BarsSinceFill(const string symbol,const datetime fill_time)
  {
   if(symbol=="" || fill_time<=0) return(-1);
   int fill_shift=iBarShift(symbol,PERIOD_M5,fill_time,false);
   if(fill_shift<1) return(0);
   return(MathMax(0,fill_shift-1));
  }

bool TimeStopReached(const string symbol,const datetime fill_time,const int bars)
  {
   int elapsed=ClosedM5BarsSinceFill(symbol,fill_time);
   return(elapsed>=0 && TimeStopReachedByCount(elapsed,bars));
  }

#endif

