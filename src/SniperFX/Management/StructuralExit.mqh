#ifndef SNIPERFX_STRUCTURAL_EXIT_MQH
#define SNIPERFX_STRUCTURAL_EXIT_MQH

bool StructuralFailure(const ENUM_SNIPER_DIRECTION direction,const double close_price,const double invalidation)
  {
   if(direction==DIRECTION_BUY) return(close_price<=invalidation);
   if(direction==DIRECTION_SELL) return(close_price>=invalidation);
   return(false);
  }

#endif
