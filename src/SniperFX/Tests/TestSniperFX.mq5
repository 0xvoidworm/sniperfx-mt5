#property strict
#property version "2.00"
#property description "Deterministic offline unit harness for SniperFX pure logic."

#include "..\Core\Config.mqh"
#include "..\Core\TradeIntent.mqh"
#include "..\Data\BrokerCapabilities.mqh"
#include "..\Analysis\ConfirmedPivotDetector.mqh"
#include "..\Analysis\TrendRegimeModel.mqh"
#include "..\Analysis\TriggerDetector.mqh"
#include "..\Analysis\CandidateRanker.mqh"
#include "..\Risk\CurrencyExposure.mqh"
#include "..\Execution\PendingOrderBuilder.mqh"
#include "..\Execution\ExecutionEngine.mqh"
#include "..\Management\BarTimeStop.mqh"
#include "..\Ops\StateStore.mqh"

int g_passed=0;
int g_failed=0;

void AssertTrue(const bool condition,const string name)
  {
   if(condition)
     {
      g_passed++;
      Print("TEST_PASS,",name);
     }
   else
     {
      g_failed++;
      Print("TEST_FAIL,",name);
     }
  }

bool AlmostEqual(const double left,const double right,const double tolerance=0.0000001)
  {
   return(MathAbs(left-right)<=tolerance);
  }

void SeedRates(MqlRates &bars[],const int count)
  {
   ArrayResize(bars,count);
   ArraySetAsSeries(bars,true);
   for(int shift=0; shift<count; shift++)
     {
      bars[shift].time=D'2026.01.02 00:00'-(datetime)(shift*300);
      bars[shift].open=1.1000;
      bars[shift].high=1.1010;
      bars[shift].low=1.0990;
      bars[shift].close=1.1000;
      bars[shift].tick_volume=100;
     }
  }

void TestConfig()
  {
   SConfig config;
   ConfigDefaults(config);
   string reason;
   AssertTrue(ConfigValidate(config,reason) && reason=="OK","config_defaults_valid");
   config.risk_percent=10.01;
   AssertTrue(!ConfigValidate(config,reason) && reason=="INVALID_RISK","config_rejects_excess_risk");
   ConfigDefaults(config);
   config.trading_enabled=true;
   config.operation_mode=OPERATION_SCAN_ONLY;
   AssertTrue(!ConfigValidate(config,reason) && reason=="TRADING_MODE_MISMATCH","config_requires_guarded_mode");
   ConfigDefaults(config);
   config.max_concurrent_positions=2;
   AssertTrue(!ConfigValidate(config,reason) && reason=="INVALID_POSITION_LIMIT","config_rejects_unsupported_multi_intent");
   ConfigDefaults(config);
   config.max_margin_fraction=1.0;
   AssertTrue(!ConfigValidate(config,reason) && reason=="INVALID_MARGIN_FRACTION","config_rejects_unbounded_margin");
  }

void TestSymbolParsing()
  {
   string base,quote;
   AssertTrue(ExtractPairAssets("EURUSD.a",base,quote) && base=="EUR" && quote=="USD","suffix_pair_parsing");
   AssertTrue(ExtractPairAssets("m.XAUUSD",base,quote) && base=="XAU" && quote=="USD","prefix_metal_parsing");
   AssertTrue(AssetsCollide("EURUSD.a","m.USDJPY"),"shared_currency_collision");
   AssertTrue(!AssetsCollide("EURGBP.a","m.AUDNZD"),"independent_pair_no_collision");
  }

void TestPoliciesAndIdentity()
  {
   AssertTrue(TradeRetcodeClass(TRADE_RETCODE_TIMEOUT)=="TRANSIENT_INFRASTRUCTURE","timeout_policy");
   AssertTrue(TradeRetcodeClass(TRADE_RETCODE_INVALID_STOPS)=="PERMANENT_REQUEST","invalid_stop_policy");
   AssertTrue(!TimeStopReachedByCount(3,4),"time_stop_not_early");
   AssertTrue(TimeStopReachedByCount(4,4),"time_stop_on_fourth_closed_bar");
   uint first=StableStringHash("scope|EURUSD|1|100|200|300");
   uint second=StableStringHash("scope|EURUSD|1|100|200|300");
   uint changed=StableStringHash("scope|EURUSD|-1|100|200|300");
   AssertTrue(first!=0 && first==second && first!=changed,"intent_hash_deterministic");
   AssertTrue(SubmitOutcomeUncertain("ORDERSEND_CALL_FAILED_4756",0),"send_transport_failure_is_uncertain");
   AssertTrue(SubmitOutcomeUncertain("TRANSIENT_INFRASTRUCTURE",TRADE_RETCODE_TIMEOUT),"timeout_retcode_is_uncertain");
   AssertTrue(!SubmitOutcomeUncertain("ORDERCHECK_REJECT",TRADE_RETCODE_INVALID_STOPS),"invalid_request_is_certain_reject");
  }

void TestPendingEntryStability()
  {
   SBrokerCapabilities caps;
   caps.digits=5;
   caps.point=0.00001;
   caps.tick_size=0.00010;
   caps.stops_level=5;
   MqlTick tick;
   tick.ask=1.10000;
   tick.bid=1.09980;
   double buy_first=PendingEntryPrice(ORDER_TYPE_BUY_STOP,1.10100,1.0,caps,tick);
   double buy_second=PendingEntryPrice(ORDER_TYPE_BUY_STOP,1.10100,1.0,caps,tick);
   double sell=PendingEntryPrice(ORDER_TYPE_SELL_STOP,1.09900,1.0,caps,tick);
   AssertTrue(AlmostEqual(buy_first,1.10110) && AlmostEqual(buy_first,buy_second),"pending_buy_reference_does_not_drift");
   AssertTrue(AlmostEqual(sell,1.09890),"pending_sell_reference_buffer");
  }

void TestIntentRoundTrip()
  {
   CStateStore store;
   AssertTrue(store.Initialize("SFX_UNIT","LOCAL"),"state_store_initialize");
   STradeIntent intent;
   ResetIntent(intent);
   intent.identity="LOCAL|EURUSD|1|100|200|300";
   intent.identity_hash=StableStringHash(intent.identity);
   intent.symbol="EURUSD";
   intent.direction=DIRECTION_BUY;
   intent.decision_time=(datetime)1767225600;
   intent.trigger_time=(datetime)1767225900;
   intent.entry=1.1234567890123456;
   intent.stop=1.1200000000000000;
   intent.target=1.1300000000000000;
   intent.volume=0.37;
   intent.order_ticket=(ulong)9007199254740993;
   intent.position_ticket=(ulong)9007199254740995;
   intent.recorded=true;
   bool saved=store.SaveIntent(intent);
   STradeIntent loaded;
   bool loaded_ok=store.LoadIntent(loaded);
   AssertTrue(saved && loaded_ok,"state_store_roundtrip_available");
   AssertTrue(loaded.identity==intent.identity && loaded.identity_hash==intent.identity_hash &&
              loaded.symbol==intent.symbol && loaded.direction==intent.direction,
              "state_store_roundtrip_identity");
   AssertTrue(loaded.order_ticket==intent.order_ticket && loaded.position_ticket==intent.position_ticket,
              "state_store_preserves_large_tickets");
   AssertTrue(AlmostEqual(loaded.entry,intent.entry,0.000000000000001) &&
              AlmostEqual(loaded.volume,intent.volume),"state_store_roundtrip_numbers");
   store.ClearIntent();
  }

void TestPivotAndEfficiency()
  {
   MqlRates bars[];
   SeedRates(bars,10);
   bars[3].high=1.1100;
   bars[4].low=1.0900;
   AssertTrue(IsConfirmedHigh(bars,ArraySize(bars),3,2),"confirmed_high_causal");
   AssertTrue(IsConfirmedLow(bars,ArraySize(bars),4,2),"confirmed_low_causal");
   AssertTrue(!IsConfirmedHigh(bars,ArraySize(bars),2,2),"pivot_rejects_unconfirmed_edge");

   MqlRates trend[];
   SeedRates(trend,8);
   for(int shift=1; shift<=5; shift++)
      trend[shift].close=1.1060-(shift-1)*0.0010;
   double efficiency=ClosedEfficiencyRatio(trend,ArraySize(trend),1,5);
   AssertTrue(AlmostEqual(efficiency,1.0),"efficiency_clean_direction_equals_one");
  }

void TestTriggers()
  {
   MqlRates bars[];
   SeedRates(bars,6);
   SZone zone;
   zone.state=ZONE_CREATED;
   zone.low_price=1.0990;
   zone.high_price=1.1000;
   bars[2].high=1.1008;
   bars[1].low=1.0995;
   bars[1].high=1.1020;
   bars[1].close=1.1015;
   STrigger trigger;
   AssertTrue(DetectClosedM5Trigger(bars,ArraySize(bars),zone,DIRECTION_BUY,trigger) &&
              AlmostEqual(trigger.entry_reference,1.1020),"buy_trigger_touch_reclaim_break");

   zone.low_price=1.1000;
   zone.high_price=1.1010;
   bars[2].low=1.0992;
   bars[1].low=1.0980;
   bars[1].high=1.1005;
   bars[1].close=1.0985;
   AssertTrue(DetectClosedM5Trigger(bars,ArraySize(bars),zone,DIRECTION_SELL,trigger) &&
              AlmostEqual(trigger.entry_reference,1.0980),"sell_trigger_touch_reclaim_break");

   zone.state=ZONE_EXPIRED;
   AssertTrue(!DetectClosedM5Trigger(bars,ArraySize(bars),zone,DIRECTION_SELL,trigger),"expired_zone_rejected");
  }

void TestRanking()
  {
   STradeCandidate candidates[];
   ArrayResize(candidates,3);
   for(int index=0; index<3; index++) ResetCandidate(candidates[index]);
   candidates[0].accepted=true; candidates[0].symbol="EURUSD"; candidates[0].net_room_r=1.80; candidates[0].trend_efficiency=0.60;
   candidates[1].accepted=true; candidates[1].symbol="GBPUSD"; candidates[1].net_room_r=2.10; candidates[1].trend_efficiency=0.40;
   candidates[2].accepted=false; candidates[2].symbol="XAUUSD"; candidates[2].net_room_r=5.00;
   AssertTrue(SelectBestCandidate(candidates,ArraySize(candidates))==1,"ranker_prefers_best_accepted_net_r");
   candidates[0].net_room_r=2.10;
   candidates[0].trend_efficiency=0.70;
   AssertTrue(SelectBestCandidate(candidates,ArraySize(candidates))==0,"ranker_tie_breaks_on_efficiency");
  }

int OnInit()
  {
   TestConfig();
   TestPoliciesAndIdentity();
   TestPendingEntryStability();
   TestIntentRoundTrip();
   TestSymbolParsing();
   TestPivotAndEfficiency();
   TestTriggers();
   TestRanking();
   PrintFormat("TEST_SUMMARY,passed=%d,failed=%d",g_passed,g_failed);
   return(g_failed==0 ? INIT_SUCCEEDED : INIT_FAILED);
  }

void OnTick()
  {
  }
