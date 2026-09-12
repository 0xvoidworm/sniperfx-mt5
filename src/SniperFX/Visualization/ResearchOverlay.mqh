#ifndef SNIPERFX_RESEARCH_OVERLAY_MQH
#define SNIPERFX_RESEARCH_OVERLAY_MQH

#include "..\Research\AlphaBridge.mqh"

class CResearchOverlay
  {
private:
   string m_prefix;

   string SafeToken(string value) const
     {
      StringReplace(value," ","_");
      StringReplace(value,"|","_");
      StringReplace(value,";","_");
      return(value);
     }

   color ZoneColor(const SResearchZone &zone) const
     {
      if(zone.state=="TOUCHED") return(clrGold);
      if(zone.state=="ACCEPTED") return(zone.direction>0 ? clrLimeGreen : clrTomato);
      return(zone.direction>0 ? clrSeaGreen : clrIndianRed);
     }

   void UpsertStatus(const string status,const int visible_count,const datetime generated_at)
     {
      string name=m_prefix+"STATUS";
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      string updated=(generated_at>0 ? TimeToString(generated_at,TIME_DATE|TIME_SECONDS) : "-");
      string text="SFX ALPHA LAB | "+status+" | "+_Symbol+
                  " | zones="+IntegerToString(visible_count)+" | UTC "+updated;
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18);
      bool healthy=(status=="PYTHON_ACTIVE" || status=="PYTHON_ACTIVE_NO_ZONES");
      ObjectSetInteger(0,name,OBJPROP_COLOR,healthy ? clrLimeGreen : clrGold);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
     }

public:
   CResearchOverlay()
     {
      m_prefix="SFX_ALPHA_";
     }

   void Clear()
     {
      int total=ObjectsTotal(0,0,-1);
      for(int index=total-1; index>=0; index--)
        {
         string name=ObjectName(0,index,0,-1);
         if(StringFind(name,m_prefix)==0) ObjectDelete(0,name);
        }
      ChartRedraw(0);
     }

   void Render(const SResearchZone &zones[],const int count,const string status,
               const datetime generated_at)
     {
      Clear();
      int visible=0;
      for(int index=0; index<count; index++)
        {
         if(!ResearchZoneMatchesSymbol(zones[index],_Symbol)) continue;
         string token=SafeToken(zones[index].zone_id);
         string rectangle=m_prefix+"ZONE_"+token;
         datetime start=zones[index].time_start;
         datetime end=zones[index].time_end;
         if(start<=0) start=TimeCurrent()-PeriodSeconds(PERIOD_M5)*12;
         if(end<=start) end=start+PeriodSeconds(PERIOD_M5)*12;
         if(!ObjectCreate(0,rectangle,OBJ_RECTANGLE,0,start,zones[index].high_price,
                          end,zones[index].low_price))
            continue;
         color tint=ZoneColor(zones[index]);
         ObjectSetInteger(0,rectangle,OBJPROP_COLOR,tint);
         ObjectSetInteger(0,rectangle,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,rectangle,OBJPROP_WIDTH,1);
         ObjectSetInteger(0,rectangle,OBJPROP_FILL,true);
         ObjectSetInteger(0,rectangle,OBJPROP_BACK,true);
         ObjectSetInteger(0,rectangle,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,rectangle,OBJPROP_HIDDEN,true);
         string side=(zones[index].direction>0 ? "BUY" : "SELL");
         string tooltip="PY RESEARCH "+side+" | "+zones[index].source+" | "+zones[index].state+
                        " | score="+DoubleToString(zones[index].research_score*100.0,0)+
                        "/100 (not probability) | "+zones[index].reason;
         ObjectSetString(0,rectangle,OBJPROP_TOOLTIP,tooltip);

         string label=m_prefix+"TEXT_"+token;
         datetime label_time=TimeCurrent();
         double label_price=(zones[index].direction>0 ? zones[index].low_price : zones[index].high_price);
         if(ObjectCreate(0,label,OBJ_TEXT,0,label_time,label_price))
           {
            string text="PY "+side+" SCORE "+DoubleToString(zones[index].research_score*100.0,0)+
                        " "+zones[index].source+" "+zones[index].state;
            ObjectSetString(0,label,OBJPROP_TEXT,text);
            ObjectSetString(0,label,OBJPROP_FONT,"Consolas");
            ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
            ObjectSetInteger(0,label,OBJPROP_COLOR,tint);
            ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
            ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,label,OBJPROP_HIDDEN,true);
            ObjectSetString(0,label,OBJPROP_TOOLTIP,tooltip);
           }
         visible++;
        }
      UpsertStatus(status,visible,generated_at);
      ChartRedraw(0);
     }
  };

#endif
