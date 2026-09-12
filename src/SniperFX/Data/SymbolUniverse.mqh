#ifndef SNIPERFX_SYMBOL_UNIVERSE_MQH
#define SNIPERFX_SYMBOL_UNIVERSE_MQH

class CSymbolUniverse
  {
private:
   string m_requested[];
   string m_resolved[];
   bool m_valid[];
   int m_count;

   string Trim(const string value)
     {
      string result=value;
      StringTrimLeft(result);
      StringTrimRight(result);
      return(result);
     }

   string Resolve(const string requested)
     {
      if(SymbolSelect(requested,true))
         return(requested);
      int total=SymbolsTotal(false);
      string found="";
      for(int index=0; index<total; index++)
        {
         string candidate=SymbolName(index,false);
         // Accept one unambiguous broker prefix/suffix variant. Refuse to guess
         // when the broker exposes more than one matching contract.
         if(StringFind(candidate,requested)>=0)
           {
            if(found!="")
               return("");
            found=candidate;
           }
        }
      if(found!="")
         SymbolSelect(found,true);
      return(found);
     }

public:
   bool Build(const string csv)
     {
      m_count=0;
      ArrayResize(m_requested,0);
      ArrayResize(m_resolved,0);
      ArrayResize(m_valid,0);
      string parts[];
      int count=StringSplit(csv,',',parts);
      if(count<=0)
         return(false);
      for(int index=0; index<count; index++)
        {
         string requested=Trim(parts[index]);
         if(requested=="")
            continue;
         string resolved=Resolve(requested);
         ArrayResize(m_requested,m_count+1);
         ArrayResize(m_resolved,m_count+1);
         ArrayResize(m_valid,m_count+1);
         m_requested[m_count]=requested;
         m_resolved[m_count]=resolved;
         m_valid[m_count]=(resolved!="");
         m_count++;
        }
      return(m_count>0);
     }

   int Count() const { return(m_count); }
   string Requested(const int index) const { return(m_requested[index]); }
   string Symbol(const int index) const { return(m_resolved[index]); }
   bool IsValid(const int index) const { return(m_valid[index]); }
  };

#endif
