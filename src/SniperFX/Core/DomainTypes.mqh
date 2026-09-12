#ifndef SNIPERFX_DOMAIN_TYPES_MQH
#define SNIPERFX_DOMAIN_TYPES_MQH

enum ENUM_SNIPER_DIRECTION
  {
   DIRECTION_NONE = 0,
   DIRECTION_BUY = 1,
   DIRECTION_SELL = -1
  };

enum ENUM_SNIPER_FSM
  {
   FSM_BOOT = 0,
   FSM_SYNCING,
   FSM_SCANNING,
   FSM_BIAS_VALID,
   FSM_ZONE_ARMED,
   FSM_TRIGGER_CONFIRMED,
   FSM_INTENT_RECORDED,
   FSM_ORDER_PENDING,
   FSM_POSITION_OPEN,
   FSM_MANAGING,
   FSM_EXITING,
   FSM_COOLDOWN,
   FSM_SAFE_MODE,
   FSM_HALTED
  };

struct SClosedBar
  {
   datetime time;
   double open;
   double high;
   double low;
   double close;
   long tick_volume;
  };

struct SMarketSnapshot
  {
   string symbol;
   MqlTick tick;
   datetime m5_closed_time;
   bool synchronized;
   bool fresh_tick;
   bool has_bars;
   double spread_points;
  };

#endif
