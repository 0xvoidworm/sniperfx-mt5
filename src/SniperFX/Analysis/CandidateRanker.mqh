#ifndef SNIPERFX_CANDIDATE_RANKER_MQH
#define SNIPERFX_CANDIDATE_RANKER_MQH

#include "..\Core\DomainTypes.mqh"

struct STradeCandidate
  {
   string candidate_id;
   string symbol;
   ENUM_SNIPER_DIRECTION direction;
   datetime decision_time;
   datetime impulse_time;
   datetime trigger_time;
   string zone_id;
   double trigger_reference;
   double entry;
   double stop;
   double target;
   double net_room_r;
   double trend_efficiency;
   double normalized_slope;
   double impulse_quality;
   double pullback_depth;
   double entry_distance_to_invalidation;
   double estimated_cost_r;
   string reject_reason;
   bool accepted;
  };

void ResetCandidate(STradeCandidate &candidate)
  {
   candidate.candidate_id=""; candidate.symbol=""; candidate.direction=DIRECTION_NONE;
   candidate.decision_time=0; candidate.impulse_time=0; candidate.trigger_time=0; candidate.zone_id="";
   candidate.trigger_reference=0.0; candidate.entry=0.0; candidate.stop=0.0;
   candidate.target=0.0; candidate.net_room_r=0.0;
   candidate.trend_efficiency=0.0; candidate.normalized_slope=0.0; candidate.impulse_quality=0.0;
   candidate.pullback_depth=0.0; candidate.entry_distance_to_invalidation=0.0;
   candidate.estimated_cost_r=0.0; candidate.reject_reason=""; candidate.accepted=false;
  }

bool CandidatePrecedes(const STradeCandidate &left,const STradeCandidate &right)
  {
   if(left.net_room_r!=right.net_room_r) return(left.net_room_r>right.net_room_r);
   if(left.trend_efficiency!=right.trend_efficiency) return(left.trend_efficiency>right.trend_efficiency);
   if(left.impulse_quality!=right.impulse_quality) return(left.impulse_quality>right.impulse_quality);
   if(left.entry_distance_to_invalidation!=right.entry_distance_to_invalidation) return(left.entry_distance_to_invalidation<right.entry_distance_to_invalidation);
   if(left.estimated_cost_r!=right.estimated_cost_r) return(left.estimated_cost_r<right.estimated_cost_r);
   return(left.symbol<right.symbol || (left.symbol==right.symbol && left.decision_time<right.decision_time));
  }

int SelectBestCandidate(const STradeCandidate &candidates[],const int count)
  {
   int best=-1;
   for(int index=0; index<count; index++)
     {
      if(!candidates[index].accepted) continue;
      if(best<0 || CandidatePrecedes(candidates[index],candidates[best]))
         best=index;
     }
   return(best);
  }

#endif
