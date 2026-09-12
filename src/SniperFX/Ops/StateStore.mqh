#ifndef SNIPERFX_STATE_STORE_MQH
#define SNIPERFX_STATE_STORE_MQH

#include "..\Core\TradeIntent.mqh"

class CStateStore
  {
private:
   string m_prefix;
   string m_file_name;

public:
   bool Initialize(const string strategy_id,const string account_scope)
     {
      m_prefix=strategy_id+"_"+account_scope+"_";
      m_file_name=strategy_id+"_"+account_scope+"_active_intent.csv";
      return(m_prefix!="" && m_file_name!="");
     }

   bool Save(const string key,const double value)
     {
      return(GlobalVariableSet(m_prefix+key,value)>0);
     }

   bool Load(const string key,double &value)
     {
      string name=m_prefix+key;
      if(!GlobalVariableCheck(name)) return(false);
      value=GlobalVariableGet(name);
      return(true);
     }

   bool SaveIntent(const STradeIntent &intent)
     {
      int handle=FileOpen(m_file_name,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(handle==INVALID_HANDLE) return(false);
      FileWrite(handle,intent.identity,IntegerToString((long)intent.identity_hash),intent.symbol,
                IntegerToString((int)intent.direction),IntegerToString((long)intent.decision_time),
                IntegerToString((long)intent.trigger_time),DoubleToString(intent.entry,16),
                DoubleToString(intent.stop,16),DoubleToString(intent.target,16),
                DoubleToString(intent.volume,8),IntegerToString((long)intent.order_ticket),
                IntegerToString((long)intent.position_ticket));
      FileFlush(handle);
      FileClose(handle);
      return(true);
     }

   bool LoadIntent(STradeIntent &intent)
     {
      ResetIntent(intent);
      int handle=FileOpen(m_file_name,FILE_READ|FILE_CSV|FILE_ANSI,',');
      if(handle==INVALID_HANDLE) return(false);
      intent.identity=FileReadString(handle);
      intent.identity_hash=(uint)StringToInteger(FileReadString(handle));
      intent.symbol=FileReadString(handle);
      intent.direction=(ENUM_SNIPER_DIRECTION)((int)StringToInteger(FileReadString(handle)));
      intent.decision_time=(datetime)((long)StringToInteger(FileReadString(handle)));
      intent.trigger_time=(datetime)((long)StringToInteger(FileReadString(handle)));
      intent.entry=StringToDouble(FileReadString(handle));
      intent.stop=StringToDouble(FileReadString(handle));
      intent.target=StringToDouble(FileReadString(handle));
      intent.volume=StringToDouble(FileReadString(handle));
      intent.order_ticket=(ulong)StringToInteger(FileReadString(handle));
      intent.position_ticket=(ulong)StringToInteger(FileReadString(handle));
      FileClose(handle);
      intent.recorded=(intent.identity!="" && intent.identity_hash!=0);
      return(intent.recorded);
     }

   void ClearIntent()
     {
      FileDelete(m_file_name);
     }

   void Flush() { GlobalVariablesFlush(); }
  };

#endif
