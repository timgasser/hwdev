/* INSERT MODULE HEADER */

// MIPS 1 Top level RTL. Contains:
//
// 1. MIPS CPU Core
// 2. MIPS COP0 - Co processor
// 3. MIPS COP2 - PSX GTE
// 4. 4kB I-CACHE 
// 5. 1kB D-TCM : 0x1f80_0000 to 0x1f80_0400

/*****************************************************************************/
module MIPS1_TOP 
   (

    // Clocks and resets
    input         CLK                   ,
    input         RST_SYNC              ,
    
    // Wishbone interface (Master)
    output [31:0] WB_ADR_OUT     , // Master: Address of current transfer
    output        WB_CYC_OUT     , // Master: High while whole transfer is in progress
    output        WB_STB_OUT     , // Master: High while the current beat in burst is active
    output        WB_WE_OUT      , // Master: Write Enable (1), Read if 0
    output [ 3:0] WB_SEL_OUT     , // Master: Byte enables of write (one-hot)
    output [ 2:0] WB_CTI_OUT     , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    output [ 1:0] WB_BTE_OUT     , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap

    input         WB_ACK_IN      , // Slave:  Acknowledge of transaction
    input         WB_STALL_IN    , // Slave:  Not ready to accept a new address
    input         WB_ERR_IN      , // Slave:  Not ready to accept a new address

    input  [31:0] WB_DAT_RD_IN   , // Slave:  Read data
    output [31:0] WB_DAT_WR_OUT  , // Master: Write data
   
    // COP0
    input   [5:0] HW_IRQ_IN      
   
    );

`include "mips1_top_defines.v"
`include "wb_defs.v"


   // MIPS Core wires

   // Instruction Port (M2S)
   wire [31:0]    CoreInstAdr         ; 
   wire           CoreInstCyc         ; 
   wire           CoreInstStb         ; 
   wire           CoreInstWe          ; 
   wire [ 3:0]    CoreInstSel         ; 
   wire [ 2:0]    CoreInstCti         ; 
   wire [ 1:0]    CoreInstBte         ; 
   wire [31:0]    CoreInstDatWr       ; 

   // Instruction Port (S2M)
   wire           CoreInstAck         ; 
   wire           CoreInstStall       ; 
   wire           CoreInstErr         ; 
   wire [31:0]    CoreInstDatRd       ; 
   
   // Data Port (M2S)
   wire [31:0]    CoreDataAdr         ; 
   wire           CoreDataCyc         ; 
   wire           CoreDataStb         ; 
   wire           CoreDataWe          ; 
   wire [ 3:0]    CoreDataSel         ; 
   wire [ 2:0]    CoreDataCti         ; 
   wire [ 1:0]    CoreDataBte         ; 
   wire [31:0]    CoreDataDatWr       ; 

   // Data Port (S2M)
   wire           CoreDataAck         ;
   wire           CoreDataStall       ;
   wire           CoreDataErr         ;  
   wire [31:0]    CoreDataDatRd       ;
   
   // MIPS COP0 wires
   wire           Cop0InstEn      ; 
   wire [4:0]     Cop0Inst        ; 
   
   wire           Cop0RdEn        ; 
   wire           Cop0RdCtrlSel   ; 
   wire [4:0]     Cop0RdSel       ; 
   wire [31:0]    Cop0RdData      ; 

   wire           Cop0WrEn        ; 
   wire           Cop0WrCtrlSel   ; 
   wire [4:0]     Cop0WrSel       ; 
   wire [31:0]    Cop0WrData      ; 

   wire [3:0]     CopUsable       ; 

   wire           Cop0Int         ; 
   
   wire           CoreExcEn       ; 
   wire [1:0]     CoreExcCe       ; 
   wire [4:0]     CoreExcCode     ; 
   wire           CoreExcBd       ; 
   wire [31:0]    CoreExcEpc      ; 
   wire [31:0]    CoreExcBadva    ; 
   wire [31:0]    CoreExcVector   ; 
   
   // COP0 Cache wires
   wire           CacheIso       ; 
   wire           CacheSwap      ; 
   wire           CacheMiss      ; 

   /////////////////////////////////////////////////////////////////////////////
   // Slave select and decodes
   //
   // Memory map region decodes
   wire           InstAddrKseg2;
   wire           InstAddrKseg1;
   wire           InstAddrKseg0;
   wire           InstAddrKuseg;

   // Declare wires assigned to parameters so you can do bit selects
   wire [31:0]    DataTcmBaseAddr = DATA_TCM_BASE;

   // Slave selects
   wire           CoreInstAdrArbSel            ; // Instruction can be either
   reg            CoreInstAdrArbSelReg         ; // I-Cache or Arbiter
   wire           CoreInstAdrCacheSel          ;
   reg            CoreInstAdrCacheSelReg       ;
   wire           CoreDataAdrArbSel            ; // Data can be TCM, Arbiter, 
   reg            CoreDataAdrArbSelReg         ; // or Write Buffer 
   wire           CoreDataAdrTcmSel            ;
   reg            CoreDataAdrTcmSelReg         ;
   wire           CoreDataAdrWriteBuffSel      ;
   reg            CoreDataAdrWriteBuffSelReg   ;

   /////////////////////////////////////////////////////////////////////////////
   // Instruction WB buses
   //
   // Instruction Cache Slave wires M2S - qualified with CoreInstAdrCacheSel(Reg)
   wire [31:0]    CoreInstIcacheAdr     ; 
   wire           CoreInstIcacheCyc     ; 
   wire           CoreInstIcacheStb     ; 
   wire           CoreInstIcacheWe      ; 
   wire [ 3:0]    CoreInstIcacheSel     ; 
   wire [ 2:0]    CoreInstIcacheCti     ; 
   wire [ 1:0]    CoreInstIcacheBte     ; 
   wire [31:0]    CoreInstIcacheDatWr   ; 

  // I-Cache Slave (M2S). Muxed with CacheIso between CoreInstIcache and CoreData
   wire [31:0]    IcacheSlaveAdr         ; 
   wire           IcacheSlaveCyc         ; 
   wire           IcacheSlaveStb         ; 
   wire           IcacheSlaveWe          ; 
   wire [ 3:0]    IcacheSlaveSel         ; 
   wire [ 2:0]    IcacheSlaveCti         ; 
   wire [ 1:0]    IcacheSlaveBte         ; 
   wire [31:0]    IcacheSlaveDatWr       ; 
   
   // I-Cache Slave (S2M). In Cache Iso connected to CoreData S2M
   wire           IcacheSlaveAck     ; 
   wire           IcacheSlaveStall   ; 
   wire           IcacheSlaveErr     ; 
   wire [31:0]    IcacheSlaveDatRd   ; 
   
   // Instruction Arbiter (M2S) - qualified with CoreInstAdrArbSel(Reg)
   wire [31:0]    ArbInstAdr     ; 
   wire           ArbInstCyc     ; 
   wire           ArbInstStb     ; 
   wire           ArbInstWe      ; 
   wire [ 3:0]    ArbInstSel     ; 
   wire [ 2:0]    ArbInstCti     ; 
   wire [ 1:0]    ArbInstBte     ; 
   wire [31:0]    ArbInstDatWr   ; 

   // Instruction Arbiter (S2M) - qualified with CoreInstAdrArbSel(Reg)
   wire           ArbInstAck     ; 
   wire           ArbInstStall   ; 
   wire           ArbInstErr     ; 
   wire [31:0]    ArbInstDatRd   ; 

  // I-Cache Master (M2S) - not qualified, point-to-point with Arb
   wire [31:0]    IcacheMasterAdr         ; 
   wire           IcacheMasterCyc         ; 
   wire           IcacheMasterStb         ; 
   wire           IcacheMasterWe          ; 
   wire [ 3:0]    IcacheMasterSel         ; 
   wire [ 2:0]    IcacheMasterCti         ; 
   wire [ 1:0]    IcacheMasterBte         ; 
   wire [31:0]    IcacheMasterDatWr       ; 

   // I-Cache Master (S2M) - not qualified, used by Arb
   wire           IcacheMasterAck     ; 
   wire           IcacheMasterStall   ; 
   wire           IcacheMasterErr     ; 
   wire [31:0]    IcacheMasterDatRd   ; 

   /////////////////////////////////////////////////////////////////////////////
   // Data WB buses
   //
   // Arbiter Master to Slave wires (Data)
   wire [31:0]    ArbDataAdr          ; 
   wire           ArbDataCyc          ; 
   wire           ArbDataStb          ; 
   wire           ArbDataWe           ; 
   wire [ 3:0]    ArbDataSel          ; 
   wire [ 2:0]    ArbDataCti          ; 
   wire [ 1:0]    ArbDataBte          ; 
   wire [31:0]    ArbDataDatWr        ;

   // Write Buffer Master to Slave wires (Data)
   wire [31:0]    WriteBuffSlaveAdr   ; 
   wire           WriteBuffSlaveCyc   ; 
   wire           WriteBuffSlaveStb   ; 
   wire           WriteBuffSlaveWe    ; 
   wire [ 3:0]    WriteBuffSlaveSel   ; 
   wire [ 2:0]    WriteBuffSlaveCti   ; 
   wire [ 1:0]    WriteBuffSlaveBte   ; 
   wire [31:0]    WriteBuffSlaveDatWr ;

   // TCM Master to Slave wires (Data)
   wire [31:0]    TcmDataAdr          ; 
   wire           TcmDataCyc          ; 
   wire           TcmDataStb          ; 
   wire           TcmDataWe           ; 
   wire [ 3:0]    TcmDataSel          ; 
   wire [ 2:0]    TcmDataCti          ; 
   wire [ 1:0]    TcmDataBte          ; 
   wire [31:0]    TcmDataDatWr        ;   

   // Write Buffer Master to Slave wires (Data)
   wire [31:0]    WriteBuffMasterAdr         ; 
   wire           WriteBuffMasterCyc         ; 
   wire           WriteBuffMasterStb         ; 
   wire           WriteBuffMasterWe          ; 
   wire [ 3:0]    WriteBuffMasterSel         ; 
   wire [ 2:0]    WriteBuffMasterCti         ; 
   wire [ 1:0]    WriteBuffMasterBte         ; 
   wire [31:0]    WriteBuffMasterDatWr       ;
 
   // TCM Slave to Master wires
   wire           TcmDataAck     ; 
   wire           TcmDataStall   ; 
   wire           TcmDataErr     ; 
   wire [31:0]    TcmDataDatRd   ; 
   
   // Write buffer slave S2M wires
   wire           WriteBuffSlaveAck     ; 
   wire           WriteBuffSlaveStall   ; 
   wire           WriteBuffSlaveErr     ; 
   wire [31:0]    WriteBuffSlaveDatRd   ; 
   
   // Arbiter Master to Slave wires (Data)
   wire           ArbDataAck     ; 
   wire           ArbDataStall   ; 
   wire           ArbDataErr     ; 
   wire [31:0]    ArbDataDatRd   ; 
  
   // Write buffer master S2M wires
   wire           WriteBuffMasterAck     ; 
   wire           WriteBuffMasterStall   ; 
   wire           WriteBuffMasterErr     ; 
   wire [31:0]    WriteBuffMasterDatRd   ; 
   
   // Remove the top 3 bits of the address before sending out (convert to physical values)
   wire [31:0]    WbAdr;

   assign WB_ADR_OUT = {3'b000, WbAdr[28:0]};

   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CORE_INST Slave select decodes

   // Decode what regions the instruction accesses are:
   assign InstAddrKseg2 = (CoreInstAdr[31:30] == 2'b11  );
   assign InstAddrKseg1 = (CoreInstAdr[31:29] == 3'b101 );
   assign InstAddrKseg0 = (CoreInstAdr[31:29] == 3'b100 );
   assign InstAddrKuseg = (CoreInstAdr[   31] == 1'b0   );

   // Instruction address decoding is used to direct core requests to either the cache, or external arbiter.
   // 0xC000_0000 to 0xFFFF_FFFF = Kernel Cached      (kseg2) <- InstAddrKseg2
   // 0xA000_0000 to 0xC000_0000 = Kernel Uncached    (kseg1) <- InstAddrKseg1
   // 0x8000_0000 to 0xA000_0000 = Kernel Cached      (kseg0) <- InstAddrKseg0
   // 0x0000_0000 to 0x8000_0000 = Kernel/User Cached (kuseg) <- InstAddrKuseg
   assign CoreInstAdrArbSel   =   InstAddrKseg1 & CoreInstCyc & CoreInstStb;
   assign CoreInstAdrCacheSel =  (InstAddrKseg2 | InstAddrKseg0 | InstAddrKuseg) & CoreInstCyc & CoreInstStb;

   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CORE_INST Combinatorial assigns

   // ARBITER INST Master to Slave signals. Gated by Select (replicated as necessary)
   assign ArbInstAdr    = {ADR_W {CoreInstAdrArbSel}}   & CoreInstAdr   ; 
   assign ArbInstCyc    = {CYC_W {(CoreInstAdrArbSel | CoreInstAdrArbSelReg)}} & CoreInstCyc   ;
   assign ArbInstStb    = {STB_W {CoreInstAdrArbSel}}   & CoreInstStb   ; 
   assign ArbInstWe     = {WE_W  {CoreInstAdrArbSel}}   & CoreInstWe    ; 
   assign ArbInstSel    = {SEL_W {CoreInstAdrArbSel}}   & CoreInstSel   ; 
   assign ArbInstCti    = {CTI_W {CoreInstAdrArbSel}}   & CoreInstCti   ; 
   assign ArbInstBte    = {BTE_W {CoreInstAdrArbSel}}   & CoreInstBte   ; 
   assign ArbInstDatWr  = {DAT_W {CoreInstAdrArbSel}}   & CoreInstDatWr ;
                         
   // CPU Core to Instruction Cache (M2S). Qualified with CoreInstAdrCacheSel
   assign CoreInstIcacheAdr    = {DAT_W{CoreInstAdrCacheSel}}  & CoreInstAdr; 
   assign CoreInstIcacheCyc    = {CYC_W{(CoreInstAdrCacheSel | CoreInstAdrCacheSelReg)}}  & CoreInstCyc; 
   assign CoreInstIcacheStb    = {STB_W{CoreInstAdrCacheSel}}  & CoreInstStb   ; 
   assign CoreInstIcacheWe     = {WE_W {CoreInstAdrCacheSel}}  & CoreInstWe    ; 
   assign CoreInstIcacheSel    = {SEL_W{CoreInstAdrCacheSel}}  & CoreInstSel   ;
   assign CoreInstIcacheCti    = {CTI_W{CoreInstAdrCacheSel}}  & CoreInstCti   ; 
   assign CoreInstIcacheBte    = {BTE_W{CoreInstAdrCacheSel}}  & CoreInstBte   ; 
   assign CoreInstIcacheDatWr  = {DAT_W{CoreInstAdrCacheSel}}  & CoreInstDatWr ;

   // Mux the IcacheSlave M2S ports with CoreInstIcache and CoreData (CacheIso = 0 and 1)
   assign IcacheSlaveAdr     = CacheIso ? CoreDataAdr    : CoreInstIcacheAdr   ; 
   assign IcacheSlaveCyc     = CacheIso ? CoreDataCyc    : CoreInstIcacheCyc   ; 
   assign IcacheSlaveStb     = CacheIso ? CoreDataStb    : CoreInstIcacheStb   ; 
   assign IcacheSlaveWe      = CacheIso ? CoreDataWe     : CoreInstIcacheWe    ; 
   assign IcacheSlaveSel     = CacheIso ? CoreDataSel    : CoreInstIcacheSel   ; 
   assign IcacheSlaveCti     = CacheIso ? CoreDataCti    : CoreInstIcacheCti   ; 
   assign IcacheSlaveBte     = CacheIso ? CoreDataBte    : CoreInstIcacheBte   ; 
   assign IcacheSlaveDatWr   = CacheIso ? CoreDataDatWr  : CoreInstIcacheDatWr ; 
   
   // CoreInst S2M signals muxed between IcacheSlave and ArbInst
   assign CoreInstAck   = ({ACK_W {CoreInstAdrArbSelReg   }} & ArbInstAck       ) 
                        | ({ACK_W {CoreInstAdrCacheSelReg }} & IcacheSlaveAck   );

   // Need to stall the Master either in the address phase when the STALL comes
   // back combinatorially, or in the data phase when the ACK hasn't come back
   // yet. Otherwise if a new Address phase is started with a different slave
   // before the previous data completes, the data read back will be corrupted.
   assign CoreInstStall = ({STL_W {CoreInstAdrArbSel      }} & ArbInstStall     ) 
                        | ({STL_W {CoreInstAdrCacheSel    }} & IcacheSlaveStall )
                        | ({STL_W {CoreInstAdrArbSelReg   }} & ~ArbInstAck      ) 
                        | ({STL_W {CoreInstAdrCacheSelReg }} & ~IcacheSlaveAck  );
   
   assign CoreInstErr   = ({ERR_W {CoreInstAdrArbSelReg   }} & ArbInstErr       ) 
                        | ({ERR_W {CoreInstAdrCacheSelReg }} & IcacheSlaveErr   );
   
   assign CoreInstDatRd = ({DAT_W{CoreInstAdrArbSelReg    }} & ArbInstDatRd     ) 
                        | ({DAT_W{CoreInstAdrCacheSelReg  }} & IcacheSlaveDatRd );
   
   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CORE_DATA Slave select decodes

   // Decode slave selects for the Data Port. If Cache Isolate is asserted, the Data Master is 
   // connected to Instruction slave ports, so gate off all these selects.
   assign CoreDataAdrTcmSel       = CoreDataCyc & CoreDataStb 
                                    & (CoreDataAdr[28:10] == DataTcmBaseAddr[28:10])
                                    & ~CacheIso;

   assign CoreDataAdrWriteBuffSel = CoreDataCyc & CoreDataStb 
                                    & (CoreDataAdr[28:USER_RAM_SIZE_P2] == {28-USER_RAM_SIZE_P2+1{1'b0}})
                                    & ~CacheIso    ;
   
   // If the TCM address or platform RAM address don't match, default to the ARB
   assign CoreDataAdrArbSel       = CoreDataCyc & CoreDataStb 
                                    & ~CoreDataAdrTcmSel
                                    & ~CoreDataAdrWriteBuffSel
                                    & ~CacheIso;
   
   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CPU Data Combinatorial assigns

   // ARBITER DATA Master to Slave signals. Gated by the select
   assign ArbDataAdr   = {ADR_W {CoreDataAdrArbSel}}  & CoreDataAdr       ; 
   assign ArbDataCyc   = {CYC_W {CoreDataAdrArbSel | CoreDataAdrArbSelReg}}   & CoreDataCyc; 
   assign ArbDataStb   = {STB_W {CoreDataAdrArbSel}}  & CoreDataStb       ; 
   assign ArbDataWe    = {WE_W  {CoreDataAdrArbSel}}  & CoreDataWe        ; 
   assign ArbDataSel   = {SEL_W {CoreDataAdrArbSel}}  & CoreDataSel       ; 
   assign ArbDataCti   = {CTI_W {CoreDataAdrArbSel}}  & CoreDataCti       ; 
   assign ArbDataBte   = {BTE_W {CoreDataAdrArbSel}}  & CoreDataBte       ; 
   assign ArbDataDatWr = {DAT_W {CoreDataAdrArbSel}}  & CoreDataDatWr     ;
   
   // TCM Master to slave wires
   assign TcmDataAdr   = { {20{1'b0}}, ({10{CoreDataAdrTcmSel}} & CoreDataAdr[11:2]), 2'b00};   
   assign TcmDataCyc   = CoreDataAdrTcmSel       & CoreDataCyc    ;   
   assign TcmDataStb   = CoreDataAdrTcmSel       & CoreDataStb    ;   
   assign TcmDataWe    = CoreDataAdrTcmSel       & CoreDataWe     ;   
   assign TcmDataSel   = {4{CoreDataAdrTcmSel}}  & CoreDataSel    ;   
   assign TcmDataCti   = 3'b000    ;   
   assign TcmDataBte   = 2'b00     ;   
   assign TcmDataDatWr = {32{CoreDataAdrTcmSel}} & CoreDataDatWr  ;   

   // TCM Master to slave wires
   assign WriteBuffSlaveAdr   = {ADR_W {CoreDataAdrWriteBuffSel}}  & CoreDataAdr       ;
   assign WriteBuffSlaveCyc   = {CYC_W {CoreDataAdrWriteBuffSel | CoreDataAdrWriteBuffSelReg}} & CoreDataCyc; 
   assign WriteBuffSlaveStb   = {STB_W {CoreDataAdrWriteBuffSel}}  & CoreDataStb       ;
   assign WriteBuffSlaveWe    = {WE_W  {CoreDataAdrWriteBuffSel}}  & CoreDataWe        ;
   assign WriteBuffSlaveSel   = {SEL_W {CoreDataAdrWriteBuffSel}}  & CoreDataSel       ;
   assign WriteBuffSlaveCti   = {CTI_W {CoreDataAdrWriteBuffSel}}  & CoreDataCti       ;
   assign WriteBuffSlaveBte   = {BTE_W {CoreDataAdrWriteBuffSel}}  & CoreDataBte       ;
   assign WriteBuffSlaveDatWr = {DAT_W {CoreDataAdrWriteBuffSel}}  & CoreDataDatWr     ;
   
   // CPU_CORE DATA Slave to Master signals (muxed by registered select, apart from STALL).
   // Cache Isolate takes first priority, and connects CPU Data S2M signals from ICACHE
   assign CoreDataAck   = CacheIso ? IcacheSlaveAck : 
                          ({ACK_W {CoreDataAdrArbSelReg       }} & ArbDataAck         ) 
                        | ({ACK_W {CoreDataAdrTcmSelReg       }} & TcmDataAck         )
                        | ({ACK_W {CoreDataAdrWriteBuffSelReg }} & WriteBuffSlaveAck  );

   // Stall is a special case. You need to use the Address-phase select to return the
   // STALLs, and the data phase select to invert ACK and return this as STALL.
   // This prevents the master from issuing a new transaction to another slave
   // before the current one has completed
   assign CoreDataStall = CacheIso ? IcacheSlaveStall : 
                          ({STL_W {CoreDataAdrArbSel          }} & ArbDataStall        ) 
                        | ({STL_W {CoreDataAdrTcmSel          }} & TcmDataStall        )
                        | ({STL_W {CoreDataAdrWriteBuffSel    }} & WriteBuffSlaveStall )
                        | ({STL_W {CoreDataAdrArbSelReg       }} & ~ArbDataAck         ) 
                        | ({STL_W {CoreDataAdrTcmSelReg       }} & ~TcmDataAck         )
                        | ({STL_W {CoreDataAdrWriteBuffSelReg }} & ~WriteBuffSlaveAck  );
   
   assign CoreDataErr   = CacheIso ? IcacheSlaveErr   : 
                          ({ERR_W {CoreDataAdrArbSelReg       }} & ArbDataErr         ) 
                        | ({ERR_W {CoreDataAdrTcmSelReg       }} & TcmDataErr         )
                        | ({ERR_W {CoreDataAdrWriteBuffSelReg }} & WriteBuffSlaveErr  );
   
   assign CoreDataDatRd = CacheIso ? IcacheSlaveDatRd   : 
                          ({DAT_W {CoreDataAdrArbSelReg       }} & ArbDataDatRd        ) 
                        | ({DAT_W {CoreDataAdrTcmSelReg       }} & TcmDataDatRd        )
                        | ({DAT_W {CoreDataAdrWriteBuffSelReg }} & WriteBuffSlaveDatRd );

   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CORE_INST Slave select registers
   //
   // Register the Cache Select when the address is accepted. Use this to mux the Slave to Master signals
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CoreInstAdrCacheSelReg <= 1'b0;
      end
      // Set Cache Select when the address is accepted
      else if (CoreInstCyc && CoreInstStb && !CoreInstStall && CoreInstAdrCacheSel)
      begin
         CoreInstAdrCacheSelReg <= 1'b1;
      end
      // Clear Cache Select when the ACK is seen
      else if (CoreInstCyc && CoreInstAdrCacheSelReg && CoreInstAck)
      begin
         CoreInstAdrCacheSelReg <= 1'b0;
      end
   end

   // Register the Arb Select when the address is accepted. Use this to mux the Slave to Master signals
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CoreInstAdrArbSelReg <= 1'b0;
      end
      // Set Arb Select when the address is accepted
      else if (CoreInstCyc && CoreInstStb && !CoreInstStall && CoreInstAdrArbSel)
      begin
         CoreInstAdrArbSelReg <= 1'b1; 
      end
      // Clear Arb Select when last ACK comes back
      else if (CoreInstCyc && CoreInstAdrArbSelReg && ArbInstAck)
      begin
         CoreInstAdrArbSelReg <= 1'b0;
      end
   end

   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CORE_DATA Slave select registers
   //
   // Register the TCM select Need to register the TCM Select for an extra cycle so it is asserted
   // in the data phase
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CoreDataAdrTcmSelReg <= 1'b0;
      end
      // Set TCM Registered select when the address is accepted
      else if (CoreDataCyc && CoreDataStb && !CoreDataStall && CoreDataAdrTcmSel)
      begin
         CoreDataAdrTcmSelReg  <= 1'b1;
      end
      // Clear the TCM reg'd select when the data is ACK'ed
      else if (CoreDataCyc && CoreDataAdrTcmSelReg && CoreDataAck)
      begin
         CoreDataAdrTcmSelReg  <= 1'b0;
      end
   end

   // Register the data arbiter select
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CoreDataAdrArbSelReg <= 1'b0;
      end
      // Set TCM Registered select when the address is accepted
      else if (CoreDataCyc && CoreDataStb && !CoreDataStall && CoreDataAdrArbSel)
      begin
         CoreDataAdrArbSelReg <= 1'b1;
      end
      // Clear the ARB select when last ACK is seen
      else if (CoreDataCyc && CoreDataAdrArbSelReg && ArbDataAck)
      begin
         CoreDataAdrArbSelReg <= 1'b0;
      end
   end

   // Register the Write buffer select
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CoreDataAdrWriteBuffSelReg <= 1'b0;
      end
      // Set TCM Registered select when the address is accepted
      else if (CoreDataCyc && CoreDataStb && !CoreDataStall && CoreDataAdrWriteBuffSel)
      begin
         CoreDataAdrWriteBuffSelReg <= 1'b1;
      end
      // Clear the ARB select when last ACK is seen
      else if (CoreDataCyc && CoreDataAdrWriteBuffSelReg && WriteBuffSlaveAck)
      begin
         CoreDataAdrWriteBuffSelReg <= 1'b0;
      end
   end


   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CPU_CORE instantiation (can be BFM or actual RTL)
   //
   
   // Select either the BFM CPU core for integration tests, or the proper RTL.
   // Note the default vlog setting is to compile all files in one compilation
   // unit, so `defines aren't global. Set -mfcu in the compile_args ..   
`ifdef CPU_CORE_BFM
   CPU_CORE_BFM
`else
      CPU_CORE
`endif      
         #(.PC_RST_VALUE  (BOOTROM_KSEG1_BASE))
   cpu_core
      (
      .CLK                   (CLK             ),
      .RST_SYNC              (RST_SYNC        ),

      .CORE_INST_ADR_OUT     (CoreInstAdr     ), 
      .CORE_INST_CYC_OUT     (CoreInstCyc     ), 
      .CORE_INST_STB_OUT     (CoreInstStb     ), 
      .CORE_INST_WE_OUT      (CoreInstWe      ),
      .CORE_INST_SEL_OUT     (CoreInstSel     ),
      .CORE_INST_CTI_OUT     (CoreInstCti     ),
      .CORE_INST_BTE_OUT     (CoreInstBte     ),
      .CORE_INST_ACK_IN      (CoreInstAck     ),
      .CORE_INST_STALL_IN    (CoreInstStall   ),
      .CORE_INST_ERR_IN      (CoreInstErr     ),
      .CORE_INST_DAT_RD_IN   (CoreInstDatRd   ),
      .CORE_INST_DAT_WR_OUT  (CoreInstDatWr   ),
      
      .CORE_DATA_ADR_OUT     (CoreDataAdr     ), 
      .CORE_DATA_CYC_OUT     (CoreDataCyc     ), 
      .CORE_DATA_STB_OUT     (CoreDataStb     ), 
      .CORE_DATA_WE_OUT      (CoreDataWe      ),
      .CORE_DATA_SEL_OUT     (CoreDataSel     ),
      .CORE_DATA_CTI_OUT     (CoreDataCti     ),
      .CORE_DATA_BTE_OUT     (CoreDataBte     ),
      .CORE_DATA_ACK_IN      (CoreDataAck     ),
      .CORE_DATA_STALL_IN    (CoreDataStall   ),
      .CORE_DATA_ERR_IN      (CoreDataErr     ),
      .CORE_DATA_DAT_RD_IN   (CoreDataDatRd   ),
      .CORE_DATA_DAT_WR_OUT  (CoreDataDatWr   ),

      .COP0_INST_EN_OUT      (Cop0InstEn      ), 
      .COP0_INST_OUT         (Cop0Inst        ), 
      
      .COP0_RD_EN_OUT        (Cop0RdEn        ), 
      .COP0_RD_CTRL_SEL_OUT  (Cop0RdCtrlSel   ), 
      .COP0_RD_SEL_OUT       (Cop0RdSel       ), 
      .COP0_RD_DATA_IN       (Cop0RdData      ), 
      
      .COP0_WR_EN_OUT        (Cop0WrEn        ), 
      .COP0_WR_CTRL_SEL_OUT  (Cop0WrCtrlSel   ), 
      .COP0_WR_SEL_OUT       (Cop0WrSel       ), 
      .COP0_WR_DATA_OUT      (Cop0WrData      ), 
      
      .COP_USABLE_IN         (CopUsable       ), 
      
      .COP0_INT_IN           (Cop0Int         ), 
      
      .CORE_EXC_EN_OUT       (CoreExcEn       ), 
      .CORE_EXC_CE_OUT       (CoreExcCe       ), 
      .CORE_EXC_CODE_OUT     (CoreExcCode     ), 
      .CORE_EXC_BD_OUT       (CoreExcBd       ), 
      .CORE_EXC_EPC_OUT      (CoreExcEpc      ), 
      .CORE_EXC_BADVA_OUT    (CoreExcBadva    ), 
      .CORE_EXC_VECTOR_IN    (CoreExcVector   )
         );

   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CPU_COP0 instantiation (can be BFM or actual RTL)
   //
   COP0 cop0
      (
       .CLK                  (CLK           ),
       .RST_SYNC             (RST_SYNC      ),

       .COP0_INST_EN_IN      (Cop0InstEn    ),
       .COP0_INST_IN         (Cop0Inst      ),

       .COP0_RD_EN_IN        (Cop0RdEn          ),
       .COP0_RD_CTRL_SEL_IN  (Cop0RdCtrlSel     ),
       .COP0_RD_SEL_IN       (Cop0RdSel         ),
       .COP0_RD_DATA_OUT     (Cop0RdData        ),

       .COP0_WR_EN_IN        (Cop0WrEn          ),
       .COP0_WR_CTRL_SEL_IN  (Cop0WrCtrlSel     ),
       .COP0_WR_SEL_IN       (Cop0WrSel         ),
       .COP0_WR_DATA_IN      (Cop0WrData        ),

       .HW_IRQ_IN            (HW_IRQ_IN         ),
       .COUNT_IRQ_OUT        (   ), 

       .COP_USABLE_OUT       (CopUsable ),  

       .COP0_INT_OUT         (Cop0Int   ), 
      
       .CORE_EXC_EN_IN       (CoreExcEn         ),
       .CORE_EXC_CE_IN       (CoreExcCe         ),
       .CORE_EXC_CODE_IN     (CoreExcCode       ),
       .CORE_EXC_BD_IN       (CoreExcBd         ),
       .CORE_EXC_EPC_IN      (CoreExcEpc        ),
       .CORE_EXC_BADVA_IN    (CoreExcBadva      ),
       .CORE_EXC_VECTOR_OUT  (CoreExcVector     ),

       .CACHE_ISO_OUT        (CacheIso       ),
       .CACHE_SWAP_OUT       (CacheSwap      ),
       .CACHE_MISS_IN        (CacheMiss      )

       );

   /////////////////////////////////////////////////////////////////////////////////////////////////
   // CPU Instruction Cache instantiation
   //

   CPU_ICACHE cpu_icache
      (
       .CLK              (CLK       ),
       .RST_SYNC         (RST_SYNC  ),

       .CORE_ADR_IN      (IcacheSlaveAdr        ),
       .CORE_CYC_IN      (IcacheSlaveCyc        ),
       .CORE_STB_IN      (IcacheSlaveStb        ),
       .CORE_WE_IN       (IcacheSlaveWe         ),
       .CORE_SEL_IN      (IcacheSlaveSel        ),
       .CORE_STALL_OUT   (IcacheSlaveStall      ), 
       .CORE_ACK_OUT     (IcacheSlaveAck        ),
       .CORE_ERR_OUT     (IcacheSlaveErr        ), 
       .CORE_DAT_RD_OUT  (IcacheSlaveDatRd      ), 
       .CORE_DAT_WR_IN   (IcacheSlaveDatWr      ), 
      
       .CACHE_ADR_OUT    (IcacheMasterAdr       ), 
       .CACHE_CYC_OUT    (IcacheMasterCyc       ), 
       .CACHE_STB_OUT    (IcacheMasterStb       ), 
       .CACHE_WE_OUT     (IcacheMasterWe        ), 
       .CACHE_SEL_OUT    (IcacheMasterSel       ), 
       .CACHE_CTI_OUT    (IcacheMasterCti       ), 
       .CACHE_BTE_OUT    (IcacheMasterBte       ), 

       .CACHE_ACK_IN     (IcacheMasterAck       ),
       .CACHE_STALL_IN   (IcacheMasterStall     ),
       .CACHE_ERR_IN     (IcacheMasterErr       ),

       .CACHE_DAT_RD_IN  (IcacheMasterDatRd     ),
       .CACHE_DAT_WR_OUT (IcacheMasterDatWr     )
       );


   /////////////////////////////////////////////////////////////////////////////////////////////////
   // D-TCM instantiation
   //
   WB_SPRAM_WRAP
      #(
      .WBA   (32'h0000_0000), // Wishbone Base Address
      .WS_P2 (10           ), // Wishbone size as power-of-2 bytes
      .DW    (32           )  // Data Width
         )
   wb_spram_wrap_data_tcm
      (
      .CLK            (CLK          ),
      .EN             (1'b1         ),
      .RST_SYNC       (RST_SYNC     ),
      .RST_ASYNC      (1'b0         ),

      .WB_ADR_IN      (TcmDataAdr   ),
      .WB_CYC_IN      (TcmDataCyc   ),
      .WB_STB_IN      (TcmDataStb   ),
      .WB_WE_IN       (TcmDataWe    ),
      .WB_SEL_IN      (TcmDataSel   ),
      .WB_CTI_IN      (TcmDataCti   ),
      .WB_BTE_IN      (TcmDataBte   ),
      
      .WB_ACK_OUT     (TcmDataAck   ),
      .WB_STALL_OUT   (TcmDataStall ),
      .WB_ERR_OUT     (TcmDataErr   ),

      .WB_WR_DAT_IN   (TcmDataDatWr ),
      .WB_RD_DAT_OUT  (TcmDataDatRd )
         );


   /////////////////////////////////////////////////////////////////////////////////////////////////
   // Write Buffer
   //

   WB_WRITE_BUFFER  wb_write_buffer
      (
      .CLK              (CLK        ),
      .EN               (1'b1       ),
      .RST_SYNC         (RST_SYNC   ),
      .RST_ASYNC        (1'b0       ),

      .WB_S_ADR_IN      (WriteBuffSlaveAdr    ),
      .WB_S_CYC_IN      (WriteBuffSlaveCyc    ),
      .WB_S_STB_IN      (WriteBuffSlaveStb    ),
      .WB_S_WE_IN       (WriteBuffSlaveWe     ),
      .WB_S_SEL_IN      (WriteBuffSlaveSel    ),
      .WB_S_CTI_IN      (WriteBuffSlaveCti    ),
      .WB_S_BTE_IN      (WriteBuffSlaveBte    ),

      .WB_S_STALL_OUT   (WriteBuffSlaveStall  ),
      .WB_S_ACK_OUT     (WriteBuffSlaveAck    ),
      .WB_S_ERR_OUT     (WriteBuffSlaveErr    ),

      .WB_S_DAT_RD_OUT  (WriteBuffSlaveDatRd  ),
      .WB_S_DAT_WR_IN   (WriteBuffSlaveDatWr  ),

      .WB_M_ADR_OUT     (WriteBuffMasterAdr   ),
      .WB_M_CYC_OUT     (WriteBuffMasterCyc   ),
      .WB_M_STB_OUT     (WriteBuffMasterStb   ),
      .WB_M_WE_OUT      (WriteBuffMasterWe    ),
      .WB_M_SEL_OUT     (WriteBuffMasterSel   ),
      .WB_M_CTI_OUT     (WriteBuffMasterCti   ),
      .WB_M_BTE_OUT     (WriteBuffMasterBte   ),
      
      .WB_M_ACK_IN      (WriteBuffMasterAck   ),
      .WB_M_STALL_IN    (WriteBuffMasterStall ),
      .WB_M_ERR_IN      (WriteBuffMasterErr   ),
      
      .WB_M_DAT_RD_IN   (WriteBuffMasterDatRd ),
      .WB_M_DAT_WR_OUT  (WriteBuffMasterDatWr )
      );


   /////////////////////////////////////////////////////////////////////////////////////////////////
   // Wishbone Arbiter
   //
   WB_ARB_4M_1S wb_arb_4m_1s
      (
       .CLK               (CLK        ),
       .EN                (1'b1       ),
       .RST_SYNC          (RST_SYNC   ), 
       .RST_ASYNC         (1'b0       ), 

       .WB_SL0_ADR_IN     (ArbDataAdr    ),
       .WB_SL0_CYC_IN     (ArbDataCyc    ),
       .WB_SL0_STB_IN     (ArbDataStb    ),
       .WB_SL0_WE_IN      (ArbDataWe     ),
       .WB_SL0_SEL_IN     (ArbDataSel    ),
       .WB_SL0_CTI_IN     (ArbDataCti    ),
       .WB_SL0_BTE_IN     (ArbDataBte    ),

       .WB_SL0_STALL_OUT  (ArbDataStall  ),
       .WB_SL0_ACK_OUT    (ArbDataAck    ),
       .WB_SL0_ERR_OUT    (ArbDataErr    ),

       .WB_SL0_RD_DAT_OUT (ArbDataDatRd  ),
       .WB_SL0_WR_DAT_IN  (ArbDataDatWr  ),

       // I-cache has to have higher priority over the un-cached instruction
       // access. The I-Cache will only access the arbiter if it's filling a
       // line. The stall signal comes in the data phase for the I-Cache as
       // it needs a cycle to look up the VALID and TAG bits in the SRAM. 
       .WB_SL1_ADR_IN     (IcacheMasterAdr      ),
       .WB_SL1_CYC_IN     (IcacheMasterCyc      ),
       .WB_SL1_STB_IN     (IcacheMasterStb      ),
       .WB_SL1_WE_IN      (IcacheMasterWe       ),
       .WB_SL1_SEL_IN     (IcacheMasterSel      ),
       .WB_SL1_CTI_IN     (IcacheMasterCti      ),
       .WB_SL1_BTE_IN     (IcacheMasterBte      ),
      
       .WB_SL1_STALL_OUT  (IcacheMasterStall    ),
       .WB_SL1_ACK_OUT    (IcacheMasterAck      ),
       .WB_SL1_ERR_OUT    (IcacheMasterErr      ),

       .WB_SL1_RD_DAT_OUT (IcacheMasterDatRd    ),
       .WB_SL1_WR_DAT_IN  (IcacheMasterDatWr    ),

       .WB_SL2_ADR_IN     (ArbInstAdr    ),
       .WB_SL2_CYC_IN     (ArbInstCyc    ),
       .WB_SL2_STB_IN     (ArbInstStb    ),
       .WB_SL2_WE_IN      (ArbInstWe     ),
       .WB_SL2_SEL_IN     (ArbInstSel    ),
       .WB_SL2_CTI_IN     (ArbInstCti    ),
       .WB_SL2_BTE_IN     (ArbInstBte    ),
      
       .WB_SL2_STALL_OUT  (ArbInstStall  ),
       .WB_SL2_ACK_OUT    (ArbInstAck    ),
       .WB_SL2_ERR_OUT    (ArbInstErr    ),

       .WB_SL2_RD_DAT_OUT (ArbInstDatRd  ),
       .WB_SL2_WR_DAT_IN  (ArbInstDatWr  ),

       .WB_SL3_ADR_IN     (WriteBuffMasterAdr   ),
       .WB_SL3_CYC_IN     (WriteBuffMasterCyc   ),
       .WB_SL3_STB_IN     (WriteBuffMasterStb   ),
       .WB_SL3_WE_IN      (WriteBuffMasterWe    ),
       .WB_SL3_SEL_IN     (WriteBuffMasterSel   ),
       .WB_SL3_CTI_IN     (WriteBuffMasterCti   ),
       .WB_SL3_BTE_IN     (WriteBuffMasterBte   ),
      
       .WB_SL3_STALL_OUT  (WriteBuffMasterStall ),
       .WB_SL3_ACK_OUT    (WriteBuffMasterAck   ),
       .WB_SL3_ERR_OUT    (WriteBuffMasterErr   ),

       .WB_SL3_RD_DAT_OUT (WriteBuffMasterDatRd ),
       .WB_SL3_WR_DAT_IN  (WriteBuffMasterDatWr ),

       // Master 0
       .WB_M0_ADR_OUT     (WbAdr         ),
       .WB_M0_CYC_OUT     (WB_CYC_OUT    ),
       .WB_M0_STB_OUT     (WB_STB_OUT    ),
       .WB_M0_WE_OUT      (WB_WE_OUT     ),
       .WB_M0_SEL_OUT     (WB_SEL_OUT    ),
       .WB_M0_CTI_OUT     (WB_CTI_OUT    ),
       .WB_M0_BTE_OUT     (WB_BTE_OUT    ),
      
       .WB_M0_STALL_IN    (WB_STALL_IN   ),
       .WB_M0_ACK_IN      (WB_ACK_IN     ),
       .WB_M0_ERR_IN      (WB_ERR_IN     ),

       .WB_M0_RD_DAT_IN   (WB_DAT_RD_IN  ),
       .WB_M0_WR_DAT_OUT  (WB_DAT_WR_OUT )
       );

   

endmodule
/*****************************************************************************/
