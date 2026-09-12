#property strict
#property version "3.00"
#property description "SniperFX causal multi-symbol MTF sniper; SCAN_ONLY by default."

#include "Core\Config.mqh"
#include "Core\DomainTypes.mqh"
#include "Core\TradeIntent.mqh"
#include "Data\SymbolUniverse.mqh"
#include "Data\TimeframeCache.mqh"
#include "Data\BrokerCapabilities.mqh"
#include "Analysis\TrendRegimeModel.mqh"
#include "Analysis\ImpulseDetector.mqh"
#include "Analysis\PullbackDetector.mqh"
#include "Analysis\ZoneBuilder.mqh"
#include "Analysis\TriggerDetector.mqh"
#include "Analysis\CandidateRanker.mqh"
#include "Risk\PositionSizer.mqh"
#include "Risk\CurrencyExposure.mqh"
#include "Risk\LossCircuitBreaker.mqh"
#include "Execution\ExecutionEngine.mqh"
#include "Execution\TradeReconciler.mqh"
#include "Management\BarTimeStop.mqh"
#include "Management\PositionLifecycle.mqh"
#include "Management\StructuralExit.mqh"
#include "Ops\StateStore.mqh"
#include "Ops\DecisionJournal.mqh"
#include "Research\AlphaBridge.mqh"
#include "Visualization\ResearchOverlay.mqh"

input bool InpTradingEnabled=false;
input ENUM_OPERATION_MODE InpOperationMode=OPERATION_SCAN_ONLY;
input string InpSymbols="EURUSD,USDJPY,GBPUSD,USDCHF,AUDUSD,USDCAD,XAUUSD";
input ulong InpMagic=92726001;
input int InpTimerSeconds=1;
input int InpHealthLogSeconds=60;
input int InpBarsToCopy=200;
input double InpRiskPercent=1.0;
input double InpMaxMarginFraction=0.50;
input int InpMaxConcurrentPositions=1;
input double InpMinNetRewardR=1.5;
input double InpDefaultTargetR=2.0;
input int InpPendingExpiryM5Bars=2;
input int InpTimeStopM5Bars=4;
input double InpMaxDailyLossR=3.0;
input int InpPivotLeftRight=2;
input int InpTrendSlopeLookback=24;
input int InpTrendEfficiencyLookback=16;
input double InpMinNormalizedSlope=0.05;
input double InpMinTrendEfficiency=0.25;
input double InpMinImpulseATR=1.0;
input double InpMinImpulseBodyFraction=0.45;
input double InpMinImpulseQuality=0.0;
input double InpPullbackMinDepth=0.25;
input double InpPullbackMaxDepth=0.70;
input int InpPullbackMinBars=2;
input int InpPullbackMaxBars=12;
input double InpZoneHalfWidthATR=0.20;
input double InpStopBufferATR=0.10;
input double InpEntryBufferTicks=1.0;
input double InpMaxSpreadStopRatio=0.15;
input int InpMaxTickAgeSeconds=30;
input bool InpResearchOverlayEnabled=true;
input string InpResearchBridgeFile="SniperFX\\alpha_zones.csv";
input int InpResearchBridgeStaleSeconds=15;
input int InpResearchOverlayRefreshSeconds=2;
input int InpResearchOverlayMaxZones=8;

SConfig g_config;
CSymbolUniverse g_universe;
CDecisionJournal g_journal;
CStateStore g_state_store;
CTimeframeCache g_h4_cache[];
CTimeframeCache g_h1_cache[];
CTimeframeCache g_m15_cache[];
CTimeframeCache g_m5_cache[];
datetime g_last_m5_bar[];
ENUM_SNIPER_FSM g_state=FSM_BOOT;
STradeIntent g_active_intent;
datetime g_last_health_log=0;
ulong g_telemetry_position_ticket=0;
datetime g_last_position_bar=0;
datetime g_last_time_exit_attempt_bar=0;
CAlphaBridge g_alpha_bridge;
CResearchOverlay g_research_overlay;
datetime g_last_research_overlay_refresh=0;

string FsmName(const ENUM_SNIPER_FSM state)
  {
   switch(state)
     {
      case FSM_BOOT: return("BOOT");
      case FSM_SYNCING: return("SYNCING");
      case FSM_SCANNING: return("SCANNING");
      case FSM_BIAS_VALID: return("BIAS_VALID");
      case FSM_ZONE_ARMED: return("ZONE_ARMED");
      case FSM_TRIGGER_CONFIRMED: return("TRIGGER_CONFIRMED");
      case FSM_INTENT_RECORDED: return("INTENT_RECORDED");
      case FSM_ORDER_PENDING: return("ORDER_PENDING");
      case FSM_POSITION_OPEN: return("POSITION_OPEN");
      case FSM_MANAGING: return("MANAGING");
      case FSM_EXITING: return("EXITING");
      case FSM_COOLDOWN: return("COOLDOWN");
      case FSM_SAFE_MODE: return("SAFE_MODE");
      case FSM_HALTED: return("HALTED");
     }
   return("UNKNOWN");
  }

string DirectionName(const ENUM_SNIPER_DIRECTION direction)
  {
   if(direction==DIRECTION_BUY) return("BUY");
   if(direction==DIRECTION_SELL) return("SELL");
   return("NONE");
  }

void RefreshResearchOverlay()
  {
   if(!InpResearchOverlayEnabled) return;
   datetime now=TimeLocal();
   if(g_last_research_overlay_refresh>0 &&
      now-g_last_research_overlay_refresh<InpResearchOverlayRefreshSeconds) return;
   g_last_research_overlay_refresh=now;
   SResearchZone zones[];
   string status;
   int count=g_alpha_bridge.Read(zones,status);
   g_research_overlay.Render(zones,count,status,g_alpha_bridge.LatestGeneratedAt());
  }

void SetState(const ENUM_SNIPER_FSM next_state,const string reason)
  {
   ENUM_SNIPER_FSM before=g_state;
   if(before==next_state) return;
   g_state=next_state;
   g_journal.Write("FSM","",FsmName(before),FsmName(next_state),reason,0,"");
  }

void ApplyInputs(SConfig &config)
  {
   ConfigDefaults(config);
   config.trading_enabled=InpTradingEnabled;
   config.operation_mode=InpOperationMode;
   config.symbol_list=InpSymbols;
   config.magic=InpMagic;
   config.timer_seconds=InpTimerSeconds;
   config.health_log_seconds=InpHealthLogSeconds;
   config.bars_to_copy=InpBarsToCopy;
   config.risk_percent=InpRiskPercent;
   config.max_margin_fraction=InpMaxMarginFraction;
   config.max_concurrent_positions=InpMaxConcurrentPositions;
   config.min_net_reward_r=InpMinNetRewardR;
   config.default_target_r=InpDefaultTargetR;
   config.pending_expiry_m5_bars=InpPendingExpiryM5Bars;
   config.time_stop_m5_bars=InpTimeStopM5Bars;
   config.max_daily_loss_r=InpMaxDailyLossR;
   config.pivot_left_right=InpPivotLeftRight;
   config.trend_slope_lookback=InpTrendSlopeLookback;
   config.trend_efficiency_lookback=InpTrendEfficiencyLookback;
   config.min_normalized_slope=InpMinNormalizedSlope;
   config.min_trend_efficiency=InpMinTrendEfficiency;
   config.min_impulse_atr=InpMinImpulseATR;
   config.min_impulse_body_fraction=InpMinImpulseBodyFraction;
   config.min_impulse_quality=InpMinImpulseQuality;
   config.pullback_min_depth=InpPullbackMinDepth;
   config.pullback_max_depth=InpPullbackMaxDepth;
   config.pullback_min_bars=InpPullbackMinBars;
   config.pullback_max_bars=InpPullbackMaxBars;
   config.zone_half_width_atr=InpZoneHalfWidthATR;
   config.stop_buffer_atr=InpStopBufferATR;
   config.entry_buffer_ticks=InpEntryBufferTicks;
   config.max_spread_stop_ratio=InpMaxSpreadStopRatio;
   config.max_tick_age_seconds=InpMaxTickAgeSeconds;
  }

int CacheIndexForSymbol(const string symbol)
  {
   for(int index=0; index<g_universe.Count(); index++)
      if(g_universe.IsValid(index) && g_universe.Symbol(index)==symbol) return(index);
   return(-1);
  }

bool TimeframesCausalAt(const MqlRates &h4[],const MqlRates &h1[],const MqlRates &m15[],
                        const MqlRates &m5[],const datetime decision_time,string &reason)
  {
   if(ArraySize(h4)<2 || ArraySize(h1)<2 || ArraySize(m15)<2 || ArraySize(m5)<3)
     { reason="MTF_ARRAY_SHORT"; return(false); }
   if(h4[1].time+PeriodSeconds(PERIOD_H4)>decision_time)
     { reason="H4_NOT_CLOSED_AT_DECISION"; return(false); }
   if(h1[1].time+PeriodSeconds(PERIOD_H1)>decision_time)
     { reason="H1_NOT_CLOSED_AT_DECISION"; return(false); }
   if(m15[1].time+PeriodSeconds(PERIOD_M15)>decision_time)
     { reason="M15_NOT_CLOSED_AT_DECISION"; return(false); }
   if(m5[1].time+PeriodSeconds(PERIOD_M5)>decision_time)
     { reason="M5_NOT_CLOSED_AT_DECISION"; return(false); }
   reason="OK";
   return(true);
  }

bool BuildCandidateForIndex(const int index,STradeCandidate &candidate,string &reason)
  {
   ResetCandidate(candidate);
   string symbol=g_universe.Symbol(index);
   MqlRates h4[],h1[],m15[],m5[];
   g_h4_cache[index].CopyTo(h4);
   g_h1_cache[index].CopyTo(h1);
   g_m15_cache[index].CopyTo(m15);
   g_m5_cache[index].CopyTo(m5);
   datetime decision_time=m5[1].time+PeriodSeconds(PERIOD_M5);
   if(!TimeframesCausalAt(h4,h1,m15,m5,decision_time,reason)) return(false);

   STrendRegimeResult regime;
   if(!DetectRegime(h4,ArraySize(h4),g_config.pivot_left_right,
                    g_config.trend_slope_lookback,g_config.trend_efficiency_lookback,
                    g_config.min_normalized_slope,g_config.min_trend_efficiency,regime))
     { reason="REGIME_"+regime.reason; return(false); }

   SImpulse impulse;
   if(!DetectImpulse(h1,ArraySize(h1),regime.direction,g_config.pivot_left_right,
                     g_config.min_impulse_atr,g_config.min_impulse_body_fraction,impulse))
     { reason="IMPULSE_"+impulse.reason; return(false); }
   if(!ImpulseQualityPasses(impulse.quality,g_config.min_impulse_quality))
     { reason="IMPULSE_QUALITY_BELOW_MIN"; return(false); }

   SPullback pullback;
   if(!DetectPullback(m15,ArraySize(m15),impulse,g_config.pullback_min_depth,
                      g_config.pullback_max_depth,g_config.pullback_min_bars,
                      g_config.pullback_max_bars,pullback))
     { reason="PULLBACK_"+pullback.reason; return(false); }

   double atr_m15=ClosedATR(m15,ArraySize(m15),1,14);
   SZone zone;
   if(!BuildBrokenSwingZone(symbol,impulse,pullback,atr_m15,g_config.zone_half_width_atr,
                            g_config.stop_buffer_atr,decision_time,zone))
     { reason="ZONE_BUILD_FAILED"; return(false); }

   STrigger trigger;
   if(!DetectClosedM5Trigger(m5,ArraySize(m5),zone,regime.direction,trigger))
     { reason="TRIGGER_"+trigger.reason; return(false); }

   SBrokerCapabilities caps;
   MqlTick tick;
   if(!ReadBrokerCapabilities(symbol,caps) || !SymbolInfoTick(symbol,tick))
     { reason="BROKER_OR_TICK"; return(false); }
   if(tick.ask<=0.0 || tick.bid<=0.0 || tick.ask<=tick.bid)
     { reason="INVALID_QUOTE"; return(false); }
   long tick_age=(long)(TimeCurrent()-tick.time);
   if(tick_age<0 || tick_age>g_config.max_tick_age_seconds)
     { reason="STALE_TICK"; return(false); }

   ENUM_ORDER_TYPE order_type=(regime.direction==DIRECTION_BUY ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   double entry=PendingEntryPrice(order_type,trigger.entry_reference,g_config.entry_buffer_ticks,caps,tick);
   double stop=NormalizePriceToTick(zone.invalidation_price,caps);
   double risk_distance=MathAbs(entry-stop);
   if(risk_distance<MinimumStopDistance(caps))
     { reason="STOP_DISTANCE_TOO_SMALL"; return(false); }
   if((regime.direction==DIRECTION_BUY && stop>=entry) ||
      (regime.direction==DIRECTION_SELL && stop<=entry))
     { reason="STOP_WRONG_SIDE"; return(false); }

   double spread=tick.ask-tick.bid;
   double spread_stop_ratio=spread/risk_distance;
   if(spread_stop_ratio>g_config.max_spread_stop_ratio)
     { reason="SPREAD_STOP_RATIO"; return(false); }
   double target=(regime.direction==DIRECTION_BUY)
                 ? entry+g_config.default_target_r*risk_distance
                 : entry-g_config.default_target_r*risk_distance;
   target=NormalizePriceToTick(target,caps);
   double gross_r=MathAbs(target-entry)/risk_distance;
   double cost_r=spread/risk_distance;
   double net_r=gross_r-cost_r;
   if(net_r<g_config.min_net_reward_r)
     { reason="INSUFFICIENT_NET_R"; return(false); }

   candidate.symbol=symbol;
   candidate.direction=regime.direction;
   candidate.decision_time=decision_time;
   candidate.impulse_time=impulse.origin_time;
   candidate.trigger_time=trigger.time;
   candidate.zone_id=zone.id;
   candidate.trigger_reference=trigger.entry_reference;
   candidate.entry=entry;
   candidate.stop=stop;
   candidate.target=target;
   candidate.net_room_r=net_r;
   candidate.trend_efficiency=regime.efficiency;
   candidate.normalized_slope=regime.normalized_slope;
   candidate.impulse_quality=impulse.quality;
   candidate.pullback_depth=pullback.depth;
   candidate.entry_distance_to_invalidation=risk_distance;
   candidate.estimated_cost_r=cost_r;
   string raw_id=symbol+"|"+IntegerToString((int)regime.direction)+"|"+
                 IntegerToString((long)impulse.origin_time)+"|"+zone.id+"|"+
                 IntegerToString((long)trigger.time);
   candidate.candidate_id=IntegerToString((long)StableStringHash(raw_id));
   candidate.accepted=true;
   candidate.reject_reason="OK";
   reason="OK";
   return(true);
  }

string CandidateDetails(const STradeCandidate &candidate)
  {
   return("id="+candidate.candidate_id+
          ";side="+DirectionName(candidate.direction)+
          ";trigger_ref="+DoubleToString(candidate.trigger_reference,8)+
          ";entry="+DoubleToString(candidate.entry,8)+
          ";stop="+DoubleToString(candidate.stop,8)+
          ";target="+DoubleToString(candidate.target,8)+
          ";net_r="+DoubleToString(candidate.net_room_r,3)+
          ";eff="+DoubleToString(candidate.trend_efficiency,3)+
          ";slope="+DoubleToString(candidate.normalized_slope,3)+
          ";impulse_q="+DoubleToString(candidate.impulse_quality,3)+
          ";depth="+DoubleToString(candidate.pullback_depth,3)+
          ";cost_r="+DoubleToString(candidate.estimated_cost_r,3)+
          ";zone="+candidate.zone_id);
  }

void ProcessSelectedCandidate(STradeCandidate &candidate)
  {
   if(g_state==FSM_SAFE_MODE || g_state==FSM_HALTED) return;
   string gate_reason;
   if(!ExposureAllows(candidate.symbol,candidate.direction,g_config.magic,
                      g_config.max_concurrent_positions,gate_reason))
     {
      g_journal.Write("CANDIDATE_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      gate_reason,candidate.trigger_time,CandidateDetails(candidate));
      return;
     }
   if(!DailyLossAllows(g_config.magic,AccountInfoDouble(ACCOUNT_EQUITY),
                       g_config.risk_percent,g_config.max_daily_loss_r,gate_reason))
     {
      g_journal.Write("CANDIDATE_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      gate_reason,candidate.trigger_time,CandidateDetails(candidate));
      SetState(FSM_HALTED,gate_reason);
      return;
     }
   if(HasManagedPositionOrOrder(candidate.symbol,g_config.magic))
     {
      g_journal.Write("CANDIDATE_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      "DUPLICATE_SYMBOL_INTENT",candidate.trigger_time,CandidateDetails(candidate));
      return;
     }

   SetState(FSM_BIAS_VALID,"SELECTED_"+candidate.symbol);
   SetState(FSM_ZONE_ARMED,candidate.zone_id);
   SetState(FSM_TRIGGER_CONFIRMED,candidate.candidate_id);

   ENUM_ORDER_TYPE order_type=(candidate.direction==DIRECTION_BUY ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
   SPositionSizeResult sizing;
   if(!CalculatePositionSize(candidate.symbol,order_type,candidate.entry,candidate.stop,
                             AccountInfoDouble(ACCOUNT_EQUITY),g_config.risk_percent,
                             g_config.max_margin_fraction,sizing))
     {
      g_journal.Write("RISK_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      sizing.reason,candidate.trigger_time,CandidateDetails(candidate));
      SetState(FSM_SCANNING,"RISK_REJECT");
      return;
     }

   datetime expiration=candidate.decision_time+
                       g_config.pending_expiry_m5_bars*PeriodSeconds(PERIOD_M5);
   MqlTradeRequest request;
   string build_reason;
   string intent_identity=BuildIntentIdentity(BuildAccountScope(),candidate.symbol,candidate.direction,
                                               candidate.impulse_time,candidate.decision_time,
                                               candidate.trigger_time);
   string order_comment="SFX|"+IntegerToString((long)StableStringHash(intent_identity));
   if(!BuildPendingStop(candidate.symbol,order_type,
                        candidate.trigger_reference,g_config.entry_buffer_ticks,
                        candidate.stop,candidate.target,sizing.volume,expiration,
                        g_config.magic,order_comment,request,build_reason))
     {
      g_journal.Write("ORDER_BUILD_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      build_reason,candidate.trigger_time,CandidateDetails(candidate));
      SetState(FSM_SCANNING,"ORDER_BUILD_REJECT");
      return;
     }

   // Recalculate if broker constraints moved the pending entry materially.
   SBrokerCapabilities caps;
   ReadBrokerCapabilities(candidate.symbol,caps);
   if(MathAbs(request.price-candidate.entry)>=caps.tick_size)
     {
      double distance=MathAbs(request.price-candidate.stop);
      candidate.entry=request.price;
      candidate.target=NormalizePriceToTick(candidate.direction==DIRECTION_BUY
                                            ? request.price+g_config.default_target_r*distance
                                            : request.price-g_config.default_target_r*distance,caps);
      if(!CalculatePositionSize(candidate.symbol,order_type,candidate.entry,candidate.stop,
                                AccountInfoDouble(ACCOUNT_EQUITY),g_config.risk_percent,
                                g_config.max_margin_fraction,sizing) ||
         !BuildPendingStop(candidate.symbol,order_type,candidate.trigger_reference,
                           g_config.entry_buffer_ticks,candidate.stop,
                           candidate.target,sizing.volume,expiration,g_config.magic,
                           order_comment,request,build_reason))
        {
         g_journal.Write("ORDER_REPRICE_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                         sizing.reason+"|"+build_reason,candidate.trigger_time,CandidateDetails(candidate));
         SetState(FSM_SCANNING,"ORDER_REPRICE_REJECT");
         return;
        }
     }

   if(!g_config.trading_enabled || g_config.operation_mode==OPERATION_SCAN_ONLY)
     {
      string details=CandidateDetails(candidate)+
                     ";volume="+DoubleToString(sizing.volume,4)+
                     ";risk_cash="+DoubleToString(sizing.risk_cash,2)+
                     ";margin="+DoubleToString(sizing.margin,2);
      g_journal.Write("WOULD_SUBMIT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      "SCAN_ONLY_BLOCK",candidate.trigger_time,details);
      SetState(FSM_SCANNING,"SCAN_ONLY_COMPLETE");
      return;
     }

   ResetIntent(g_active_intent);
   g_active_intent.identity=intent_identity;
   g_active_intent.identity_hash=StableStringHash(intent_identity);
   g_active_intent.symbol=candidate.symbol;
   g_active_intent.direction=candidate.direction;
   g_active_intent.decision_time=candidate.decision_time;
   g_active_intent.trigger_time=candidate.trigger_time;
   g_active_intent.entry=request.price;
   g_active_intent.stop=request.sl;
   g_active_intent.target=request.tp;
   g_active_intent.volume=request.volume;
   g_active_intent.recorded=true;
   if(!g_state_store.SaveIntent(g_active_intent))
     {
      g_journal.Write("INTENT_REJECT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                      "PERSIST_FAILED",candidate.trigger_time,CandidateDetails(candidate));
      SetState(FSM_SAFE_MODE,"PERSIST_FAILED");
      return;
     }
   SetState(FSM_INTENT_RECORDED,g_active_intent.identity);

   MqlTradeCheckResult check;
   MqlTradeResult result;
   string submit_reason;
   bool submitted=SubmitGuarded(g_config,request,check,result,submit_reason);
   string details=CandidateDetails(candidate)+
                  ";volume="+DoubleToString(request.volume,4)+
                  ";check="+IntegerToString((int)check.retcode)+
                  ";retcode="+IntegerToString((int)result.retcode)+
                  ";order="+IntegerToString((long)result.order)+
                  ";deal="+IntegerToString((long)result.deal);
   g_journal.Write("ORDER_SUBMIT",candidate.symbol,FsmName(g_state),FsmName(g_state),
                   submit_reason,candidate.trigger_time,details);
   if(submitted)
     {
      g_active_intent.order_ticket=result.order;
      g_state_store.SaveIntent(g_active_intent);
      SetState(FSM_ORDER_PENDING,submit_reason);
     }
   else
     {
      if(SubmitOutcomeUncertain(submit_reason,result.retcode))
         SetState(FSM_SAFE_MODE,"SUBMIT_UNCERTAIN_RECONCILE_REQUIRED");
      else
        {
         g_state_store.ClearIntent();
         ResetIntent(g_active_intent);
         SetState(FSM_SCANNING,"SUBMIT_REJECTED");
        }
     }
  }

void ManagePendingOrders()
  {
   for(int index=OrdersTotal()-1; index>=0; index--)
     {
      ulong ticket=OrderGetTicket(index);
      if(ticket==0 || (ulong)OrderGetInteger(ORDER_MAGIC)!=g_config.magic) continue;
      string symbol=OrderGetString(ORDER_SYMBOL);
      datetime setup=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int elapsed=ClosedM5BarsSinceFill(symbol,setup);
      if(elapsed<g_config.pending_expiry_m5_bars) continue;

      if(!g_config.trading_enabled)
        {
         g_journal.Write("WOULD_CANCEL_EXPIRED",symbol,FsmName(g_state),FsmName(g_state),
                         "SCAN_ONLY_BLOCK",setup,IntegerToString((long)ticket));
         continue;
        }
      MqlTradeRequest request; ZeroMemory(request);
      request.action=TRADE_ACTION_REMOVE; request.order=ticket; request.symbol=symbol;
      request.magic=g_config.magic; request.comment="SFX_EXPIRED";
      MqlTradeCheckResult check; MqlTradeResult result; string reason;
      bool ok=SubmitGuarded(g_config,request,check,result,reason);
      g_journal.Write("CANCEL_EXPIRED",symbol,FsmName(g_state),FsmName(g_state),reason,setup,
                      "ticket="+IntegerToString((long)ticket)+";ok="+IntegerToString(ok ? 1 : 0));
     }
  }

void ManageOpenPositions()
  {
   bool any=false;
   for(int index=PositionsTotal()-1; index>=0; index--)
     {
      ulong ticket=0;
      if(!SelectManagedPositionByIndex(index,g_config.magic,ticket)) continue;
      any=true;
      string symbol=PositionGetString(POSITION_SYMBOL);
      datetime fill_time=(datetime)PositionGetInteger(POSITION_TIME);
      if(g_telemetry_position_ticket!=ticket)
        {
         g_telemetry_position_ticket=ticket;
         g_last_position_bar=0;
         g_last_time_exit_attempt_bar=0;
        }
      datetime closed_bar=iTime(symbol,PERIOD_M5,1);
      if(closed_bar>g_last_position_bar)
        {
         g_last_position_bar=closed_bar;
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double stop=PositionGetDouble(POSITION_SL);
         long position_type=PositionGetInteger(POSITION_TYPE);
         double high=iHigh(symbol,PERIOD_M5,1);
         double low=iLow(symbol,PERIOD_M5,1);
         double close=iClose(symbol,PERIOD_M5,1);
         double risk=MathAbs(entry-stop);
         if(risk>0.0 && high>0.0 && low>0.0 && close>0.0)
           {
            double favorable=(position_type==POSITION_TYPE_BUY ? high-entry : entry-low)/risk;
            double adverse=(position_type==POSITION_TYPE_BUY ? entry-low : high-entry)/risk;
            double close_r=(position_type==POSITION_TYPE_BUY ? close-entry : entry-close)/risk;
            int elapsed=ClosedM5BarsSinceFill(symbol,fill_time);
            string telemetry="ticket="+IntegerToString((long)ticket)+
                             ";bar="+IntegerToString(elapsed)+
                             ";close_r="+DoubleToString(close_r,4)+
                             ";favorable_r="+DoubleToString(favorable,4)+
                             ";adverse_r="+DoubleToString(adverse,4);
            g_journal.Write("POSITION_BAR",symbol,FsmName(g_state),FsmName(g_state),
                            "CLOSED_M5",closed_bar,telemetry);
           }
        }
      if(!TimeStopReached(symbol,fill_time,g_config.time_stop_m5_bars)) continue;
      // A closed market or transient broker rejection must not trigger a request
      // every timer tick. Retry once when the next M5 bar has closed.
      if(!ShouldAttemptExitOnClosedBar(closed_bar,g_last_time_exit_attempt_bar)) continue;
      g_last_time_exit_attempt_bar=closed_bar;
      if(!g_config.trading_enabled)
        {
         g_journal.Write("WOULD_TIME_EXIT",symbol,FsmName(g_state),FsmName(g_state),
                         "SCAN_ONLY_BLOCK",fill_time,IntegerToString((long)ticket));
         continue;
        }

      MqlTradeRequest request; string build_reason;
      if(!BuildClosePositionRequest(ticket,g_config.magic,request,build_reason))
        {
         g_journal.Write("TIME_EXIT_BUILD_REJECT",symbol,FsmName(g_state),FsmName(g_state),
                         build_reason,fill_time,IntegerToString((long)ticket));
         SetState(FSM_SAFE_MODE,"TIME_EXIT_BUILD_FAILED");
         continue;
        }
      SetState(FSM_EXITING,"FOUR_BAR_TIME_STOP");
      MqlTradeCheckResult check; MqlTradeResult result; string submit_reason;
      bool ok=SubmitGuarded(g_config,request,check,result,submit_reason);
      g_journal.Write("TIME_EXIT_SUBMIT",symbol,FsmName(g_state),FsmName(g_state),submit_reason,
                      fill_time,"ticket="+IntegerToString((long)ticket)+";ok="+IntegerToString(ok ? 1 : 0));
      if(!ok) SetState(FSM_SAFE_MODE,"TIME_EXIT_FAILED");
     }
   if(!any)
     {
      g_telemetry_position_ticket=0;
      g_last_position_bar=0;
      g_last_time_exit_attempt_bar=0;
     }
   if(any && g_state!=FSM_EXITING && g_state!=FSM_SAFE_MODE) SetState(FSM_MANAGING,"POSITION_PRESENT");
  }

void ReconcileRuntimeState()
  {
   ENUM_MANAGED_BROKER_STATE broker_state=ManagedBrokerState(g_config.magic);
   if(broker_state==MANAGED_CONFLICT)
     {
      SetState(FSM_SAFE_MODE,"BROKER_STATE_CONFLICT");
      return;
     }
   if(broker_state==MANAGED_POSITION_OPEN && g_state!=FSM_MANAGING &&
      g_state!=FSM_POSITION_OPEN && g_state!=FSM_EXITING)
      SetState(FSM_POSITION_OPEN,"RECONCILED_POSITION");
   if(broker_state==MANAGED_ORDER_PENDING && g_state!=FSM_ORDER_PENDING)
      SetState(FSM_ORDER_PENDING,"RECONCILED_ORDER");
   if(broker_state==MANAGED_NONE && (g_state==FSM_ORDER_PENDING || g_state==FSM_POSITION_OPEN ||
                                     g_state==FSM_MANAGING || g_state==FSM_EXITING))
     {
      g_state_store.ClearIntent();
      ResetIntent(g_active_intent);
      SetState(FSM_COOLDOWN,"BROKER_FLAT");
      SetState(FSM_SCANNING,"COOLDOWN_COMPLETE");
     }
  }

int OnInit()
  {
   ResetIntent(g_active_intent);
   ApplyInputs(g_config);
   string config_reason;
   if(!ConfigValidate(g_config,config_reason))
     {
      Print("SNIPERFX_CONFIG_REJECT,",config_reason);
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!g_universe.Build(g_config.symbol_list))
      return(INIT_FAILED);

   string account_scope=BuildAccountScope();
   if(!g_journal.Initialize(SNIPERFX_STRATEGY_ID,account_scope,SNIPERFX_VERSION))
      return(INIT_FAILED);
   if(!g_state_store.Initialize(SNIPERFX_STRATEGY_ID,account_scope))
      return(INIT_FAILED);
   if(InpResearchOverlayEnabled &&
      !g_alpha_bridge.Initialize(InpResearchBridgeFile,InpResearchBridgeStaleSeconds,
                                 InpResearchOverlayMaxZones))
     {
      Print("SNIPERFX_ALPHA_BRIDGE_CONFIG_REJECT");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpResearchOverlayRefreshSeconds<1 || InpResearchOverlayRefreshSeconds>60)
     {
      Print("SNIPERFX_ALPHA_OVERLAY_REFRESH_REJECT");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_state_store.Save("trading_enabled",g_config.trading_enabled ? 1.0 : 0.0);
   g_state_store.Flush();

   int symbols=g_universe.Count();
   ArrayResize(g_h4_cache,symbols);
   ArrayResize(g_h1_cache,symbols);
   ArrayResize(g_m15_cache,symbols);
   ArrayResize(g_m5_cache,symbols);
   ArrayResize(g_last_m5_bar,symbols);
   int valid=0;
   for(int index=0; index<symbols; index++)
     {
      g_last_m5_bar[index]=0;
      if(!g_universe.IsValid(index))
        {
         g_journal.Write("SYMBOL_RESOLUTION",g_universe.Requested(index),"","","AMBIGUOUS_OR_MISSING",0,"");
         continue;
        }
      string symbol=g_universe.Symbol(index);
      if(!g_h4_cache[index].Initialize(symbol,g_config.bars_to_copy) ||
         !g_h1_cache[index].Initialize(symbol,g_config.bars_to_copy) ||
         !g_m15_cache[index].Initialize(symbol,g_config.bars_to_copy) ||
         !g_m5_cache[index].Initialize(symbol,g_config.bars_to_copy))
        {
         g_journal.Write("SYMBOL_INIT",symbol,"","","CACHE_INIT_FAILED",0,"");
         continue;
        }
      valid++;
      g_journal.Write("SYMBOL_RESOLUTION",symbol,"","","RESOLVED",0,g_universe.Requested(index));
     }
   if(valid<1) return(INIT_FAILED);
   if(!EventSetTimer(g_config.timer_seconds)) return(INIT_FAILED);

   bool persisted=g_state_store.LoadIntent(g_active_intent);
   ENUM_MANAGED_BROKER_STATE broker_state=ManagedBrokerState(g_config.magic);
   if(broker_state==MANAGED_CONFLICT)
      SetState(FSM_SAFE_MODE,"STARTUP_BROKER_CONFLICT");
   else if(broker_state==MANAGED_POSITION_OPEN)
      SetState(FSM_POSITION_OPEN,persisted ? "STARTUP_RECOVERED" : "STARTUP_POSITION_WITHOUT_LEDGER");
   else if(broker_state==MANAGED_ORDER_PENDING)
      SetState(FSM_ORDER_PENDING,persisted ? "STARTUP_RECOVERED" : "STARTUP_ORDER_WITHOUT_LEDGER");
   else if(persisted && g_config.trading_enabled)
      SetState(FSM_SAFE_MODE,"PERSISTED_INTENT_BROKER_FLAT");
   else
     {
      if(persisted) { g_state_store.ClearIntent(); ResetIntent(g_active_intent); }
      SetState(FSM_SYNCING,"INIT");
     }
   return(INIT_SUCCEEDED);
  }

void OnTimer()
  {
   RefreshResearchOverlay();
   ReconcileRuntimeState();
   ManagePendingOrders();
   ManageOpenPositions();

   STradeCandidate candidates[];
   int candidate_count=0;
   int ready=0;
   for(int index=0; index<g_universe.Count(); index++)
     {
      if(!g_universe.IsValid(index)) continue;
      string symbol=g_universe.Symbol(index);
      bool h4_ready=g_h4_cache[index].Refresh(PERIOD_H4,g_config.bars_to_copy);
      bool h1_ready=g_h1_cache[index].Refresh(PERIOD_H1,g_config.bars_to_copy);
      bool m15_ready=g_m15_cache[index].Refresh(PERIOD_M15,g_config.bars_to_copy);
      bool m5_ready=g_m5_cache[index].Refresh(PERIOD_M5,g_config.bars_to_copy);
      if(!h4_ready || !h1_ready || !m15_ready || !m5_ready) continue;
      ready++;

      datetime closed_bar=g_m5_cache[index].LastClosedTime();
      if(!g_m5_cache[index].HasNewClosedBar(g_last_m5_bar[index])) continue;
      g_last_m5_bar[index]=closed_bar;

      STradeCandidate candidate; string reason;
      if(BuildCandidateForIndex(index,candidate,reason))
        {
         ArrayResize(candidates,candidate_count+1);
         candidates[candidate_count]=candidate;
         candidate_count++;
         g_journal.Write("CANDIDATE_VALID",symbol,FsmName(g_state),FsmName(g_state),
                         "VALID",closed_bar,CandidateDetails(candidate));
        }
      else
         g_journal.Write("CANDIDATE_REJECT",symbol,FsmName(g_state),FsmName(g_state),
                         reason,closed_bar,"");
     }

   if(ready>0 && (g_state==FSM_SYNCING || g_state==FSM_BOOT))
      SetState(FSM_SCANNING,"DATA_READY");
   if(candidate_count>0 && g_state!=FSM_SAFE_MODE && g_state!=FSM_HALTED)
     {
      int best=SelectBestCandidate(candidates,candidate_count);
      for(int index=0; index<candidate_count; index++)
        {
         if(index==best) continue;
         g_journal.Write("CANDIDATE_NOT_SELECTED",candidates[index].symbol,FsmName(g_state),
                         FsmName(g_state),"LOWER_RANK",candidates[index].trigger_time,
                         CandidateDetails(candidates[index]));
        }
      if(best>=0) ProcessSelectedCandidate(candidates[best]);
     }

   datetime now=TimeCurrent();
   if(g_last_health_log==0 || now-g_last_health_log>=g_config.health_log_seconds)
     {
      g_last_health_log=now;
      g_journal.Write("HEALTH","",FsmName(g_state),FsmName(g_state),"TIMER",0,
                      "ready="+IntegerToString(ready)+";candidates="+IntegerToString(candidate_count)+
                      ";positions="+IntegerToString(CountManagedPositions(g_config.magic))+
                      ";orders="+IntegerToString(CountManagedOrders(g_config.magic)));
     }
  }

void OnTick()
  {
   // Multi-symbol decisions are timer-driven. Keep this handler intentionally empty.
  }

bool IsManagedTransaction(const MqlTradeTransaction &transaction,const MqlTradeRequest &request)
  {
   if(request.magic==g_config.magic) return(true);
   if(transaction.deal>0 && HistoryDealSelect(transaction.deal) &&
      (ulong)HistoryDealGetInteger(transaction.deal,DEAL_MAGIC)==g_config.magic) return(true);
   if(transaction.order>0)
     {
      if(OrderSelect(transaction.order) && (ulong)OrderGetInteger(ORDER_MAGIC)==g_config.magic) return(true);
      if(HistoryOrderSelect(transaction.order) &&
         (ulong)HistoryOrderGetInteger(transaction.order,ORDER_MAGIC)==g_config.magic) return(true);
     }
   if(transaction.position>0 && PositionSelectByTicket(transaction.position) &&
      (ulong)PositionGetInteger(POSITION_MAGIC)==g_config.magic) return(true);
   return(false);
  }

void OnTradeTransaction(const MqlTradeTransaction &transaction,const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(!IsManagedTransaction(transaction,request)) return;
   string symbol=transaction.symbol;
   if(symbol=="" && g_active_intent.recorded) symbol=g_active_intent.symbol;
   string details="type="+IntegerToString((int)transaction.type)+
                  ";order="+IntegerToString((long)transaction.order)+
                  ";deal="+IntegerToString((long)transaction.deal)+
                  ";position="+IntegerToString((long)transaction.position)+
                  ";retcode="+IntegerToString((int)result.retcode);
   g_journal.Write("TRADE_TRANSACTION",symbol,FsmName(g_state),FsmName(g_state),
                   TradeRetcodeClass(result.retcode),TimeCurrent(),details);

   if(transaction.type==TRADE_TRANSACTION_ORDER_ADD)
     {
      g_active_intent.order_ticket=transaction.order;
      if(g_active_intent.recorded) g_state_store.SaveIntent(g_active_intent);
      SetState(FSM_ORDER_PENDING,"ORDER_ADD");
     }
   if(transaction.type==TRADE_TRANSACTION_DEAL_ADD && transaction.deal>0 &&
      HistoryDealSelect(transaction.deal))
     {
      long entry=HistoryDealGetInteger(transaction.deal,DEAL_ENTRY);
      string deal_details="deal="+IntegerToString((long)transaction.deal)+
                          ";entry="+IntegerToString((int)entry)+
                          ";price="+DoubleToString(HistoryDealGetDouble(transaction.deal,DEAL_PRICE),8)+
                          ";volume="+DoubleToString(HistoryDealGetDouble(transaction.deal,DEAL_VOLUME),4)+
                          ";profit="+DoubleToString(HistoryDealGetDouble(transaction.deal,DEAL_PROFIT),2)+
                          ";commission="+DoubleToString(HistoryDealGetDouble(transaction.deal,DEAL_COMMISSION),2)+
                          ";swap="+DoubleToString(HistoryDealGetDouble(transaction.deal,DEAL_SWAP),2);
      g_journal.Write("DEAL",symbol,FsmName(g_state),FsmName(g_state),
                      entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY ? "EXIT" : "ENTRY",
                      TimeCurrent(),deal_details);
      if(entry==DEAL_ENTRY_IN || entry==DEAL_ENTRY_INOUT)
        {
         g_active_intent.position_ticket=transaction.position;
         if(g_active_intent.recorded) g_state_store.SaveIntent(g_active_intent);
         SetState(FSM_POSITION_OPEN,"DEAL_ENTRY");
        }
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
        {
         if(ManagedBrokerState(g_config.magic)==MANAGED_NONE)
           {
            g_state_store.ClearIntent();
            ResetIntent(g_active_intent);
            SetState(FSM_COOLDOWN,"DEAL_EXIT");
           }
        }
     }
   if(transaction.type==TRADE_TRANSACTION_ORDER_DELETE)
      ReconcileRuntimeState();
  }

double OnTester()
  {
   double trades=TesterStatistics(STAT_TRADES);
   double net_profit=TesterStatistics(STAT_PROFIT);
   double drawdown=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double profit_factor=TesterStatistics(STAT_PROFIT_FACTOR);
   double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   double expected_payoff=TesterStatistics(STAT_EXPECTED_PAYOFF);
   double sharpe=TesterStatistics(STAT_SHARPE_RATIO);
   PrintFormat("SNIPERFX_TEST_METRICS,trades=%.0f,net=%.2f,pf=%.6f,dd_pct=%.4f,recovery=%.6f,expectancy=%.6f,sharpe=%.6f",
               trades,net_profit,profit_factor,drawdown,recovery,expected_payoff,sharpe);
   if(trades<10.0 || profit_factor<=0.0 || profit_factor>=DBL_MAX/2.0)
      return(-1000000.0+trades);
   return((profit_factor*MathMax(0.0,recovery))/(1.0+MathMax(0.0,drawdown)));
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_research_overlay.Clear();
   if(g_active_intent.recorded) g_state_store.SaveIntent(g_active_intent);
   g_state_store.Flush();
   g_journal.Write("DEINIT","",FsmName(g_state),FsmName(g_state),
                   IntegerToString(reason),0,"");
  }
