#ifndef SNIPERFX_EXECUTION_ENGINE_MQH
#define SNIPERFX_EXECUTION_ENGINE_MQH

#include "..\Core\Config.mqh"
#include "PendingOrderBuilder.mqh"
#include "RetcodePolicy.mqh"

bool SubmitOutcomeUncertain(const string submit_reason,const uint retcode)
  {
   return(StringFind(submit_reason,"ORDERSEND_CALL_FAILED_")==0 ||
          TradeRetcodeClass(retcode)=="TRANSIENT_INFRASTRUCTURE");
  }

bool SubmitGuarded(const SConfig &config,MqlTradeRequest &request,MqlTradeCheckResult &check,
                   MqlTradeResult &result,string &reason)
  {
   ZeroMemory(check); ZeroMemory(result);
   if(!config.trading_enabled || config.operation_mode!=OPERATION_LIVE_GUARDED)
     { reason="SCAN_ONLY_BLOCK"; return(false); }
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) { reason="TERMINAL_DISCONNECTED"; return(false); }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     { reason="ALGO_PERMISSION_DENIED"; return(false); }

   ResetLastError();
   if(!OrderCheck(request,check))
     { reason="ORDERCHECK_CALL_FAILED_"+IntegerToString(GetLastError()); return(false); }
   if(check.retcode!=0 && check.retcode!=TRADE_RETCODE_DONE && check.retcode!=TRADE_RETCODE_PLACED)
     { reason="ORDERCHECK_REJECT_"+IntegerToString((int)check.retcode); return(false); }

   ResetLastError();
   if(!OrderSend(request,result))
     { reason="ORDERSEND_CALL_FAILED_"+IntegerToString(GetLastError()); return(false); }
   reason=TradeRetcodeClass(result.retcode);
   return(result.retcode==TRADE_RETCODE_PLACED || result.retcode==TRADE_RETCODE_DONE ||
          result.retcode==TRADE_RETCODE_DONE_PARTIAL);
  }

#endif
