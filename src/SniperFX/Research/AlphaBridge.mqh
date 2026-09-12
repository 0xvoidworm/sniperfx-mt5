#ifndef SNIPERFX_ALPHA_BRIDGE_MQH
#define SNIPERFX_ALPHA_BRIDGE_MQH

#define SNIPERFX_ALPHA_SCHEMA "SFX_ALPHA_ZONE_V2"

struct SResearchZone
  {
   datetime generated_at;
   string zone_id;
   string symbol;
   datetime time_start;
   datetime time_end;
   double low_price;
   double high_price;
   int direction;
   double research_score;
   string state;
   string source;
   string market_state;
   string reason;
  };

bool ResearchZoneFresh(const datetime generated_at,const datetime now,const int stale_seconds)
  {
   if(generated_at<=0 || now<=0 || stale_seconds<1) return(false);
   long age=(long)(now-generated_at);
   return(age>=-5 && age<=stale_seconds);
  }

bool ResearchZoneMatchesSymbol(const SResearchZone &zone,const string chart_symbol)
  {
   return(zone.symbol!="" && zone.symbol==chart_symbol);
  }

bool ResearchMarketStateStale(const string market_state)
  {
   return(StringFind(market_state,"STALE_QUOTE_")==0);
  }

class CAlphaBridge
  {
private:
   string m_file_name;
   int m_stale_seconds;
   int m_max_zones;
   datetime m_latest_generated_at;
   string m_latest_market_state;

   void ReadAndDiscardRow(const int handle)
     {
      for(int field=0; field<13; field++) FileReadString(handle);
     }

public:
   CAlphaBridge()
     {
      m_file_name="SniperFX\\alpha_zones.csv";
      m_stale_seconds=15;
      m_max_zones=8;
      m_latest_generated_at=0;
      m_latest_market_state="UNKNOWN";
     }

   bool Initialize(const string file_name,const int stale_seconds,const int max_zones)
     {
      if(file_name=="" || stale_seconds<1 || max_zones<1 || max_zones>50) return(false);
      m_file_name=file_name;
      m_stale_seconds=stale_seconds;
      m_max_zones=max_zones;
      m_latest_generated_at=0;
      m_latest_market_state="UNKNOWN";
      return(true);
     }

   datetime LatestGeneratedAt() const
     {
      return(m_latest_generated_at);
     }

   int Read(SResearchZone &zones[],string &status)
     {
      ArrayResize(zones,0);
      status="WAITING_FOR_PYTHON";
      int handle=FileOpen(m_file_name,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON|
                          FILE_SHARE_READ|FILE_SHARE_WRITE,';');
      if(handle==INVALID_HANDLE)
        {
         status="BRIDGE_FILE_MISSING";
         return(0);
        }

      int count=0;
      datetime newest=0;
      string newest_market_state="UNKNOWN";
      while(!FileIsEnding(handle))
        {
         string schema=FileReadString(handle);
         if(schema=="" && FileIsEnding(handle)) break;
         if(schema=="schema")
           {
            ReadAndDiscardRow(handle);
            continue;
           }

         string generated_text=FileReadString(handle);
         string zone_id=FileReadString(handle);
         string symbol=FileReadString(handle);
         string start_text=FileReadString(handle);
         string end_text=FileReadString(handle);
         string low_text=FileReadString(handle);
         string high_text=FileReadString(handle);
         string direction_text=FileReadString(handle);
         string score_text=FileReadString(handle);
         string state=FileReadString(handle);
         string source=FileReadString(handle);
         string market_state=FileReadString(handle);
         string reason=FileReadString(handle);

         if(schema!=SNIPERFX_ALPHA_SCHEMA) continue;
         datetime generated=(datetime)StringToInteger(generated_text);
         if(generated>newest)
           {
            newest=generated;
            newest_market_state=market_state;
           }
         if(count>=m_max_zones) continue;

         SResearchZone zone;
         zone.generated_at=generated;
         zone.zone_id=zone_id;
         zone.symbol=symbol;
         zone.time_start=(datetime)StringToInteger(start_text);
         zone.time_end=(datetime)StringToInteger(end_text);
         zone.low_price=StringToDouble(low_text);
         zone.high_price=StringToDouble(high_text);
         zone.direction=(int)StringToInteger(direction_text);
         zone.research_score=StringToDouble(score_text);
         zone.state=state;
         zone.source=source;
         zone.market_state=market_state;
         zone.reason=reason;
         if(zone.zone_id=="" || zone.symbol=="" || zone.low_price<=0.0 ||
            zone.high_price<=zone.low_price || (zone.direction!=1 && zone.direction!=-1))
            continue;
         ArrayResize(zones,count+1);
         zones[count]=zone;
         count++;
        }
      FileClose(handle);
      m_latest_generated_at=newest;
      m_latest_market_state=newest_market_state;

      datetime now=TimeGMT();
      if(!ResearchZoneFresh(newest,now,m_stale_seconds))
        {
         if(newest<=0) status="PYTHON_ONLINE_NO_ZONES";
         else status="PYTHON_STALE_"+IntegerToString((long)(now-newest))+"S";
         return(count);
        }
      if(ResearchMarketStateStale(m_latest_market_state))
         status="PYTHON_ACTIVE_MARKET_STALE";
      else
         status=(count>0 ? "PYTHON_ACTIVE" : "PYTHON_ACTIVE_NO_ZONES");
      return(count);
     }
  };

#endif
