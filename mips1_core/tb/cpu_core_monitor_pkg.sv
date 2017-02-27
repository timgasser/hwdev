package CPU_CORE_MONITOR_PKG ;

   typedef struct packed 
      {
       int regIndex  ;
       int regValue  ;
       } regWriteEvent;


   typedef struct packed 
      {
       int dataRdWrB    ;
       int dataSize     ;
       int dataAddress  ;
       int dataValue    ;
       } dataEvent;





endpackage 
   