#ifndef SNIPERFX_POSITION_SIZER_MQH
#define SNIPERFX_POSITION_SIZER_MQH

#include "..\Data\BrokerCapabilities.mqh"

struct SPositionSizeResult
  {
   bool valid;
   double volume;
   double loss_per_lot;
   double risk_cash;
   double estimated_loss;
   double margin;
   string reason;
  };

bool CalculatePositionSize(const string symbol,const ENUM_ORDER_TYPE order_type,const double entry,
                           const double stop,const double equity,const double risk_percent,
                           const double max_margin_fraction,
                           SPositionSizeResult &result)
  {
   result.valid=false; result.volume=0.0; result.loss_per_lot=0.0; result.risk_cash=0.0;
   result.estimated_loss=0.0; result.margin=0.0; result.reason="";
   SBrokerCapabilities caps;
   if(!ReadBrokerCapabilities(symbol,caps)) { result.reason="BROKER_CAPABILITIES"; return(false); }
   result.risk_cash=equity*risk_percent/100.0;
   bool sell=(order_type==ORDER_TYPE_SELL_STOP || order_type==ORDER_TYPE_SELL);
   if(result.risk_cash<=0.0 || max_margin_fraction<=0.0 || max_margin_fraction>0.90 ||
      entry<=0.0 || stop<=0.0 ||
      (!sell && stop>=entry) || (sell && stop<=entry))
     { result.reason="INVALID_RISK_OR_STOP"; return(false); }

   double profit=0.0;
   ENUM_ORDER_TYPE side=(sell ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
   if(!OrderCalcProfit(side,symbol,1.0,entry,stop,profit)) { result.reason="ORDERCALC_PROFIT"; return(false); }
   result.loss_per_lot=MathAbs(profit);
   if(result.loss_per_lot<=0.0) { result.reason="ZERO_LOSS_PER_LOT"; return(false); }

   double raw=result.risk_cash/result.loss_per_lot;
   result.volume=FloorVolumeToStep(raw,caps);
   if(result.volume<caps.volume_min) { result.reason="MIN_VOLUME_EXCEEDS_RISK"; result.volume=0.0; return(false); }
   double broker_max=caps.volume_max;
   if(caps.volume_limit>0.0) broker_max=MathMin(broker_max,caps.volume_limit);
   if(result.volume>broker_max) result.volume=FloorVolumeToStep(broker_max,caps);
   if(result.volume<caps.volume_min) { result.reason="BROKER_VOLUME_LIMIT"; result.volume=0.0; return(false); }

   double free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double margin_per_lot=0.0;
   if(free_margin<=0.0 || !OrderCalcMargin(side,symbol,1.0,entry,margin_per_lot) || margin_per_lot<=0.0)
     { result.reason="ORDERCALC_MARGIN"; return(false); }
   double margin_cap=free_margin*max_margin_fraction;
   double margin_limited_volume=FloorVolumeToStep(margin_cap/margin_per_lot,caps);
   result.volume=MathMin(result.volume,margin_limited_volume);
   result.volume=FloorVolumeToStep(result.volume,caps);
   if(result.volume<caps.volume_min)
     { result.reason="MARGIN_CAP_BELOW_MIN_VOLUME"; result.volume=0.0; return(false); }

   if(!OrderCalcMargin(side,symbol,result.volume,entry,result.margin)) { result.reason="ORDERCALC_MARGIN"; return(false); }
   if(result.margin<=0.0 || result.margin>margin_cap+0.01)
     { result.reason="MARGIN_CAP_EXCEEDED"; return(false); }

   double normalized_profit=0.0;
   if(!OrderCalcProfit(side,symbol,result.volume,entry,stop,normalized_profit))
     { result.reason="RECALC_PROFIT"; return(false); }
   result.estimated_loss=MathAbs(normalized_profit);
   if(result.estimated_loss>result.risk_cash+MathMax(0.01,result.risk_cash*0.001))
     { result.reason="NORMALIZED_RISK_EXCEEDED"; return(false); }

   result.valid=true; result.reason="OK";
   return(true);
  }

#endif
