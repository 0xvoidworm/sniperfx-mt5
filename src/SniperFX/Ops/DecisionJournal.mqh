#ifndef SNIPERFX_DECISION_JOURNAL_MQH
#define SNIPERFX_DECISION_JOURNAL_MQH

class CDecisionJournal
  {
private:
   string m_file_name;
   string m_version;

public:
   bool Initialize(const string strategy_id,const string account_scope,const string version)
     {
      m_file_name=strategy_id+"_"+account_scope+"_audit.csv";
      m_version=version;
      int handle=FileOpen(m_file_name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,',');
      if(handle==INVALID_HANDLE) return(false);
      if(FileSize(handle)==0)
         FileWrite(handle,"utc","server_time","version","event","symbol","state_before","state_after","reason","bar_time","details");
      FileClose(handle);
      return(true);
     }

   bool Write(const string event_name,const string symbol,const string before_state,
              const string after_state,const string reason,const datetime bar_time,
              const string details)
     {
      int handle=FileOpen(m_file_name,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE,',');
      if(handle==INVALID_HANDLE)
        {
         Print("SNIPERFX_JOURNAL_OPEN_FAILED,",GetLastError(),",",event_name,",",reason);
         return(false);
        }
      FileSeek(handle,0,SEEK_END);
      FileWrite(handle,TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS),
                TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),m_version,event_name,symbol,
                before_state,after_state,reason,
                bar_time>0 ? TimeToString(bar_time,TIME_DATE|TIME_SECONDS) : "",details);
      FileFlush(handle);
      FileClose(handle);
      return(true);
     }
  };

#endif

