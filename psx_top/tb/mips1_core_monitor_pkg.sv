package CPU_CORE_MONITOR_PKG ;

   typedef struct packed 
      {
       logic [31:0]  regIndex  ;
       logic [31:0]  regValue  ;
       } regWriteEvent;


   typedef struct packed 
      {
       logic [31:0]  RdWrB    ;
       logic [31:0]  Sel      ; 
       logic [31:0]  Address  ;
       logic [31:0]  WrValue  ;
       } wbM2SEvent;

   typedef struct packed 
      {
       logic [31:0]  RdValue  ;
       } wbS2MEvent;






endpackage 
   