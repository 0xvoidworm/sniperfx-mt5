#ifndef SNIPERFX_CONFIG_MQH
#define SNIPERFX_CONFIG_MQH

#define SNIPERFX_VERSION "0.3.0"
#define SNIPERFX_STRATEGY_ID "SNIPERFX_MTF"

enum ENUM_OPERATION_MODE
  {
   OPERATION_SCAN_ONLY = 0,
   OPERATION_LIVE_GUARDED = 1
  };

struct SConfig
  {
   bool trading_enabled;
   ENUM_OPERATION_MODE operation_mode;
   string symbol_list;
   ulong magic;
   int timer_seconds;
   int health_log_seconds;
   int bars_to_copy;
   double risk_percent;
   double max_margin_fraction;
   int max_concurrent_positions;
   double min_net_reward_r;
   double default_target_r;
   int pending_expiry_m5_bars;
   int time_stop_m5_bars;
   double max_daily_loss_r;
   int pivot_left_right;
   int trend_slope_lookback;
   int trend_efficiency_lookback;
   double min_normalized_slope;
   double min_trend_efficiency;
   double min_impulse_atr;
   double min_impulse_body_fraction;
   double min_impulse_quality;
   double pullback_min_depth;
   double pullback_max_depth;
   int pullback_min_bars;
   int pullback_max_bars;
   double zone_half_width_atr;
   double stop_buffer_atr;
   double entry_buffer_ticks;
   double max_spread_stop_ratio;
   int max_tick_age_seconds;
  };

void ConfigDefaults(SConfig &config)
  {
   config.trading_enabled=false;
   config.operation_mode=OPERATION_SCAN_ONLY;
   config.symbol_list="EURUSD,USDJPY,GBPUSD,USDCHF,AUDUSD,USDCAD,XAUUSD";
   config.magic=92726001;
   config.timer_seconds=1;
   config.health_log_seconds=60;
   config.bars_to_copy=200;
   config.risk_percent=1.0;
   config.max_margin_fraction=0.50;
   config.max_concurrent_positions=1;
   config.min_net_reward_r=1.5;
   config.default_target_r=2.0;
   config.pending_expiry_m5_bars=2;
   config.time_stop_m5_bars=4;
   config.max_daily_loss_r=3.0;
   config.pivot_left_right=2;
   config.trend_slope_lookback=24;
   config.trend_efficiency_lookback=16;
   config.min_normalized_slope=0.05;
   config.min_trend_efficiency=0.25;
   config.min_impulse_atr=1.0;
   config.min_impulse_body_fraction=0.45;
   config.min_impulse_quality=0.0;
   config.pullback_min_depth=0.25;
   config.pullback_max_depth=0.70;
   config.pullback_min_bars=2;
   config.pullback_max_bars=12;
   config.zone_half_width_atr=0.20;
   config.stop_buffer_atr=0.10;
   config.entry_buffer_ticks=1.0;
   config.max_spread_stop_ratio=0.15;
   config.max_tick_age_seconds=30;
  }

bool ConfigValidate(const SConfig &config,string &reason)
  {
   reason="";
   if(config.trading_enabled && config.operation_mode!=OPERATION_LIVE_GUARDED) { reason="TRADING_MODE_MISMATCH"; return(false); }
   if(config.symbol_list=="") { reason="EMPTY_SYMBOL_LIST"; return(false); }
   if(config.magic==0) { reason="INVALID_MAGIC"; return(false); }
   if(config.timer_seconds<1 || config.timer_seconds>60) { reason="INVALID_TIMER"; return(false); }
   if(config.health_log_seconds<60 || config.health_log_seconds>3600) { reason="INVALID_HEALTH_INTERVAL"; return(false); }
   if(config.bars_to_copy<64 || config.bars_to_copy>5000) { reason="INVALID_BAR_COUNT"; return(false); }
   if(config.risk_percent<=0.0 || config.risk_percent>10.0) { reason="INVALID_RISK"; return(false); }
   if(config.max_margin_fraction<=0.0 || config.max_margin_fraction>0.90) { reason="INVALID_MARGIN_FRACTION"; return(false); }
   // The current ledger persists one active intent. Reject unsupported portfolio settings
   // instead of silently entering a state the reconciler cannot represent safely.
   if(config.max_concurrent_positions!=1) { reason="INVALID_POSITION_LIMIT"; return(false); }
   if(config.min_net_reward_r<=0.0 || config.default_target_r<config.min_net_reward_r) { reason="INVALID_REWARD"; return(false); }
   if(config.pending_expiry_m5_bars<1 || config.time_stop_m5_bars<1 || config.max_daily_loss_r<=0.0) { reason="INVALID_LIFECYCLE_LIMIT"; return(false); }
   if(config.pivot_left_right<1 || config.pivot_left_right>10) { reason="INVALID_PIVOT"; return(false); }
   if(config.trend_slope_lookback<5 || config.trend_efficiency_lookback<3) { reason="INVALID_TREND_LOOKBACK"; return(false); }
   if(config.min_normalized_slope<0.0 || config.min_trend_efficiency<=0.0 || config.min_trend_efficiency>1.0) { reason="INVALID_TREND_THRESHOLD"; return(false); }
   if(config.min_impulse_atr<=0.0 || config.min_impulse_body_fraction<=0.0 || config.min_impulse_body_fraction>1.0) { reason="INVALID_IMPULSE"; return(false); }
   if(config.min_impulse_quality<0.0 || config.min_impulse_quality>1.0) { reason="INVALID_IMPULSE_QUALITY"; return(false); }
   if(config.pullback_min_depth<0.0 || config.pullback_max_depth<=config.pullback_min_depth || config.pullback_max_depth>1.5) { reason="INVALID_PULLBACK_DEPTH"; return(false); }
   if(config.pullback_min_bars<1 || config.pullback_max_bars<config.pullback_min_bars) { reason="INVALID_PULLBACK_BARS"; return(false); }
   if(config.zone_half_width_atr<=0.0 || config.stop_buffer_atr<0.0 || config.entry_buffer_ticks<0.0) { reason="INVALID_PRICE_BUFFER"; return(false); }
   if(config.max_spread_stop_ratio<=0.0 || config.max_spread_stop_ratio>=1.0 || config.max_tick_age_seconds<1) { reason="INVALID_EXECUTION_GATE"; return(false); }
   reason="OK";
   return(true);
  }

bool ConfigLoad(SConfig &config)
  {
   ConfigDefaults(config);
   string reason;
   return(ConfigValidate(config,reason));
  }

#endif
