#ifndef SNIPERFX_CONFIRMED_PIVOT_DETECTOR_MQH
#define SNIPERFX_CONFIRMED_PIVOT_DETECTOR_MQH

bool IsConfirmedHigh(const MqlRates &bars[],const int count,const int shift,const int left_right)
  {
   if(left_right<1 || shift-left_right<1 || shift+left_right>=count)
      return(false);
   double value=bars[shift].high;
   for(int offset=1; offset<=left_right; offset++)
      if(bars[shift-offset].high>=value || bars[shift+offset].high>value)
         return(false);
   return(true);
  }

bool IsConfirmedLow(const MqlRates &bars[],const int count,const int shift,const int left_right)
  {
   if(left_right<1 || shift-left_right<1 || shift+left_right>=count)
      return(false);
   double value=bars[shift].low;
   for(int offset=1; offset<=left_right; offset++)
      if(bars[shift-offset].low<=value || bars[shift+offset].low<value)
         return(false);
   return(true);
  }

bool FindTwoConfirmedHighs(const MqlRates &bars[],const int count,const int left_right,
                           int &recent_shift,int &previous_shift)
  {
   recent_shift=-1; previous_shift=-1;
   for(int shift=left_right+1; shift<count-left_right; shift++)
     {
      if(!IsConfirmedHigh(bars,count,shift,left_right))
         continue;
      if(recent_shift<0) recent_shift=shift;
      else { previous_shift=shift; return(true); }
     }
   return(false);
  }

bool FindTwoConfirmedLows(const MqlRates &bars[],const int count,const int left_right,
                          int &recent_shift,int &previous_shift)
  {
   recent_shift=-1; previous_shift=-1;
   for(int shift=left_right+1; shift<count-left_right; shift++)
     {
      if(!IsConfirmedLow(bars,count,shift,left_right))
         continue;
      if(recent_shift<0) recent_shift=shift;
      else { previous_shift=shift; return(true); }
     }
   return(false);
  }

#endif

