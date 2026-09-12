#ifndef SNIPERFX_YURI_CLEAN_DARK_THEME_MQH
#define SNIPERFX_YURI_CLEAN_DARK_THEME_MQH

bool ApplyYuriCleanDarkChartStyle(const long chart_id=0)
  {
   bool applied=true;
   applied=ChartSetInteger(chart_id,CHART_MODE,CHART_CANDLES) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_GRID,false) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE) && applied;
   applied=ChartSetInteger(chart_id,CHART_AUTOSCROLL,true) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHIFT,true) && applied;
   applied=ChartSetDouble(chart_id,CHART_SHIFT_SIZE,19.619823) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_TICKER,true) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_OHLC,false) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_BID_LINE,true) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_ASK_LINE,false) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_LAST_LINE,false) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_PERIOD_SEP,false) && applied;
   applied=ChartSetInteger(chart_id,CHART_SHOW_OBJECT_DESCR,false) && applied;

   // Exact palette from MQL5/Profiles/Templates/Yuri Clean Dark.tpl.
   applied=ChartSetInteger(chart_id,CHART_COLOR_BACKGROUND,C'19,23,34') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_FOREGROUND,C'209,212,220') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_CHART_UP,C'38,166,154') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_CHART_DOWN,C'239,83,80') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_CANDLE_BULL,C'38,166,154') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_CANDLE_BEAR,C'239,83,80') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_CHART_LINE,C'86,186,132') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_VOLUME,C'38,166,154') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_GRID,C'241,236,242') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_BID,C'38,166,154') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_ASK,C'239,83,80') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_LAST,C'156,186,240') && applied;
   applied=ChartSetInteger(chart_id,CHART_COLOR_STOP_LEVEL,C'239,83,80') && applied;
   ChartRedraw(chart_id);
   return(applied);
  }

#endif
