#ifndef SNIPERFX_CURRENCY_EXPOSURE_MQH
#define SNIPERFX_CURRENCY_EXPOSURE_MQH

#include "..\Core\DomainTypes.mqh"

int CountManagedPositionsAndOrders(const ulong magic)
  {
   int count=0;
   for(int index=PositionsTotal()-1; index>=0; index--)
     {
      ulong ticket=PositionGetTicket(index);
      if(ticket>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==magic) count++;
     }
   for(int index=OrdersTotal()-1; index>=0; index--)
     {
      ulong ticket=OrderGetTicket(index);
      if(ticket>0 && (ulong)OrderGetInteger(ORDER_MAGIC)==magic) count++;
     }
   return(count);
  }

bool IsKnownAsset(const string asset)
  {
   return(asset=="USD" || asset=="EUR" || asset=="JPY" || asset=="GBP" ||
          asset=="CHF" || asset=="AUD" || asset=="CAD" || asset=="NZD" ||
          asset=="XAU" || asset=="XAG");
  }

bool ExtractPairAssets(const string symbol,string &base,string &quote)
  {
   base=""; quote="";
   string upper=symbol;
   StringToUpper(upper);
   int length=StringLen(upper);
   for(int offset=0; offset<=length-6; offset++)
     {
      string first=StringSubstr(upper,offset,3);
      string second=StringSubstr(upper,offset+3,3);
      if(IsKnownAsset(first) && IsKnownAsset(second))
        {
         if(base!="") return(false);
         base=first;
         quote=second;
        }
     }
   return(base!="" && quote!="");
  }

bool AssetsCollide(const string symbol,const string other)
  {
   string base,quote,other_base,other_quote;
   if(!ExtractPairAssets(symbol,base,quote) ||
      !ExtractPairAssets(other,other_base,other_quote))
      return(true); // Unknown contract: fail closed instead of stacking hidden exposure.
   return(base==other_base || base==other_quote || quote==other_base || quote==other_quote);
  }

bool ExposureAllows(const string symbol,const ENUM_SNIPER_DIRECTION direction,const ulong magic,
                    const int max_positions,string &reason)
  {
   int active=CountManagedPositionsAndOrders(magic);
   if(active>=max_positions) { reason="MAX_CONCURRENT_POSITIONS"; return(false); }
   if(symbol=="" || direction==DIRECTION_NONE) { reason="INVALID_SYMBOL_DIRECTION"; return(false); }

   for(int index=PositionsTotal()-1; index>=0; index--)
     {
      ulong ticket=PositionGetTicket(index);
      if(ticket==0 || (ulong)PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      if(AssetsCollide(symbol,PositionGetString(POSITION_SYMBOL)))
        { reason="CURRENCY_EXPOSURE_COLLISION"; return(false); }
     }
   for(int index=OrdersTotal()-1; index>=0; index--)
     {
      ulong ticket=OrderGetTicket(index);
      if(ticket==0 || (ulong)OrderGetInteger(ORDER_MAGIC)!=magic) continue;
      if(AssetsCollide(symbol,OrderGetString(ORDER_SYMBOL)))
        { reason="CURRENCY_EXPOSURE_COLLISION"; return(false); }
     }
   reason="OK";
   return(true);
  }

#endif
