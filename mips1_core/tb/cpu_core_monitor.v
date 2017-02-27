/* INSERT MODULE HEADER */


/*****************************************************************************/
module CPU_CORE_MONITOR 
   (

    input  CLK                   ,
    input  RST_SYNC              ,

    // Instruction Memory (Read only)
    input [31:0]  CORE_INST_ADR_IN      , // Master: Address of current transfer
    input         CORE_INST_CYC_IN      , // Master: High while whole transfer is in progress
    input         CORE_INST_STB_IN      , // Master: High while the current beat in burst is active
    input         CORE_INST_WE_IN       , // Master: Write Enable (1), Read if 0
    input  [ 3:0] CORE_INST_SEL_IN      , // Master: Byte enables of write (one-hot)
    input  [ 2:0] CORE_INST_CTI_IN      , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    input  [ 1:0] CORE_INST_BTE_IN      , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap
    input         CORE_INST_ACK_IN      , // Slave:  Acknowledge of transaction
    input         CORE_INST_STALL_IN    , // Slave:  Not ready to accept a new address
    input         CORE_INST_ERR_IN      , // Slave:  Error occurred  
    input  [31:0] CORE_INST_DAT_RD_IN   , // Slave:  Read data
    input  [31:0] CORE_INST_DAT_WR_IN   , // Master: Write data
   
    // Data Memory (Read and Write)
    input [31:0]  CORE_DATA_ADR_IN      , // Master: Address of current transfer
    input         CORE_DATA_CYC_IN      , // Master: High while whole transfer is in progress
    input         CORE_DATA_STB_IN      , // Master: High while the current beat in burst is active
    input         CORE_DATA_WE_IN       , // Master: Write Enable (1), Read if 0
    input  [ 3:0] CORE_DATA_SEL_IN      , // Master: Byte enables of write (one-hot)
    input  [ 2:0] CORE_DATA_CTI_IN      , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    input  [ 1:0] CORE_DATA_BTE_IN      , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap
    input         CORE_DATA_ACK_IN      , // Slave:  Acknowledge of transaction
    input         CORE_DATA_STALL_IN    , // Slave:  Not ready to accept a new address
    input         CORE_DATA_ERR_IN      , // Slave:  Error occurred  
    input  [31:0] CORE_DATA_DAT_RD_IN   , // Slave:  Read data
    input  [31:0] CORE_DATA_DAT_WR_IN   , // Master: Write data

    output        CORE_MONITOR_ERROR_OUT
    
    );


`define TESTSTR "code.hex"


`include "cpu_defs.v"

   import CPU_CORE_MONITOR_PKG::regWriteEvent;
   import CPU_CORE_MONITOR_PKG::dataEvent;
   
   // Make C functions visible to verilog code

   
   // Print a hello world message from the DPI as a sanity check
   import "DPI-C" context function void helloWorld ();
   // Initialise the CPU C model (allocates memory for the CPU state)  
   import "DPI-C" context function void cpuInit ();
   // Run one cycle of the C model. During the course of this function call, the testbench queues are updated with the results   
   import "DPI-C" context function void cpuCycle(int pc, int opcode, int show_mode);
   // De-allocate the memory from the C model, dump out the register contents
   import "DPI-C" context function int  cpuEnd ();
	       
   // SV functions called by the C model to add onto the Queues
   export "DPI-C" function pcQueuePush    ; // (input int pcVal);
   export "DPI-C" function regQueuePush   ; // (input int regIndex, input int regValue);
   export "DPI-C" function dataQueuePush  ; // (input int dataRdWrB, input int dataSize, input int dataAddress, input int dataValue);
   export "DPI-C" function loHiQueuePush  ; //  (input int loVal, input int hiVal);

   // Testbench Queues
   int 	  pcQueue[$];  // Queue of PC values 
   regWriteEvent regQueue[$];
   dataEvent dataQueue[$];
   int loQueue[$];
   int hiQueue[$];


      int dutInstAddrQ[$]; // Instruction addresses
      int dutInstDataQ[$]; // Instructions

      reg CoreMonitorError;

      // Wire definitions
      wire [31:0] Instr;
      wire [ 4:0] InstrIndex;   // Index 32 instructions

      wire 	  DmCyc  ;
      wire 	  DmStb  ;
      wire [31:0] DmAddr ;
      wire [ 3:0] DmSel  ;
      wire 	  DmWe   ;

      wire [31:0] DmWriteData  ;
      wire [31:0] DmReadData   ;
      wire 	  DmReadEn     = DmCyc & DmStb & ~DmWe;
      wire 	  DmWriteEn    = DmCyc & DmStb &  DmWe;

      reg 	  cModelTraceEnable;

      string 	  register_names [32] = '{ "$zero ",  "$at   ",  "$v0   ",  "$v1   ",
					   "$a0   ",  "$a1   ",  "$a2   ",  "$a3   ",
					   "$t0   ",  "$t1   ",  "$t2   ",  "$t3   ",   
					   "$t4   ",  "$t5   ",  "$t6   ",  "$t7   ",   
					   "$s0   ",  "$s1   ",  "$s2   ",  "$s3   ",   
					   "$s4   ",  "$s5   ",  "$s6   ",  "$s7   ",   
					   "$s8   ",  "$s9   ",  "$k0   ",  "$k1   ",   
					   "$gp   ",  "$sp   ",  "$fp   ",  "$ra   "
					   };

      integer     instrLog;
      integer     dataLog;	     
      integer     regsLog;	     

      integer     instrCount = 0;

      reg 	  CoreInstAck;
      wire 	  CoreInstCyc;
      wire 	  CoreInstStb;

      // Testbench event queues
      typedef 	     enum {NEWPC, REGWRITE, MEMLOAD, MEMSTORE} T_CPU_ACTION_E;
      int 		  QDutPc[$]         ;
      T_CPU_ACTION_E    QDutAction[$]     ;
      int 		  QDutRegMemAddr[$] ;
      int 		  QDutDataVal[$]    ;

      reg signed [31:0]   RegArray [31:0];
      reg [31:0] 	  RegHi;
      reg [31:0] 	  RegLo;

      reg [63:0] 	  MultResult;
      reg [63:0] 	  DivResult;

      reg 		  DelaySlot;
      reg 		  LoadSlot;

      reg [5:0] 	  Opcode;
      reg [4:0] 	  Rs;
      reg [4:0] 	  Rt;
      reg [4:0] 	  Rd;
      reg [4:0] 	  Shamt;
      reg [5:0] 	  Funct;
      reg [15:0] 	  Immed;
      reg [31:0] 	  SignXImmed;
      reg [31:0] 	  ZeroXImmed;
      reg [25:0] 	  Target;

      reg [31:0] 	  currPc;
      reg [31:0] 	  nextPc;
      reg [31:0] 	  jumpPc;

      reg 		  dataCheck;
      reg [31:0] 	  nextDataAdr;
      reg [3:0] 	  nextDataSel;
      reg 		  nextDataWe;
      reg [31:0] 	  nextDataDatRd;
      reg [31:0] 	  nextDataDatWr;
      reg [4:0] 	  nextDataReg;

      reg [31:0] 	  Pc;
      reg [31:0] 	  PcReg;
//      reg [31:0] 	  LastPcRegRefModel;
//      reg 		  StallReg;
      reg [31:0] 	  LastInstr;

      // Wishbone decoded signals
      wire                WbCoreInstAddrStb    = CORE_INST_CYC_IN & CORE_INST_STB_IN & ~CORE_INST_STALL_IN;
      wire                WbCoreInstDataStb    = CORE_INST_CYC_IN & CORE_INST_ACK_IN;
      wire                WbCoreDataAddrStb    = CORE_DATA_CYC_IN & CORE_DATA_STB_IN & ~CORE_DATA_STALL_IN;

      assign CORE_MONITOR_ERROR_OUT = CoreMonitorError;
      
      // Initialise the CPU model (will happen while the design is in reset)
      initial
	 begin
	    // Initialise CPU model
	    // helloWorld();
	    cpuInit();
	 end

   // Set up Verilog time format
   initial
      begin
         $timeformat(-9, 0, " ns", 6);
      end
   
   // Initialise the error signal to 0
   initial
      begin
         CoreMonitorError = 1'b0;
      end
   
   // **************************** SV functions called from C *************************
   function void pcQueuePush ( input int pcVal);
      $display("[DEBUG] -> pcQueuePush  called, pcVal = 0x%x, time is %t", pcVal, $time);
      pcQueue.push_front(pcVal); // the queue push functions return void (no value)
   endfunction // pcQueuePush

   function void regQueuePush (input int regIndex, input int regValue);
      regWriteEvent regWriteEventLocal;
      
      $display("[DEBUG] -> regQueuePush called, regIndex = %2d, regValue = 0x%x, time is %t", regIndex, regValue, $time);
      regWriteEventLocal.regIndex = regIndex;
      regWriteEventLocal.regValue = regValue;
      
      regQueue.push_front(regWriteEventLocal); // the queue push functions return void (no value)

   endfunction // pcQueuePush

   function void dataQueuePush  (input int dataRdWrB, input int dataSize, input int dataAddress, input int dataValue);
      dataEvent dataEventLocal;

      $display("[DEBUG] -> dataQueuePush called, dataRdWrB = %02d, dataSize = %02d, dataAddress = 0x%x, dataValue = 0x%x, time is %t", dataRdWrB, dataSize, dataAddress, dataValue, $time);
      dataEventLocal.dataRdWrB    = dataRdWrB;
      dataEventLocal.dataSize     = dataSize;
      dataEventLocal.dataAddress  = dataAddress;
      dataEventLocal.dataValue    = dataValue;
      
      dataQueue.push_front(dataEventLocal); // the queue push functions return void (no value)

   endfunction
   
   function void loHiQueuePush  (input int regIndex, input int regValue);
//      regWriteEvent regWriteEventLocal;

      $display("[DEBUG] -> loHiQueuePush called, regIndex = %2d, regValue = 0x%x, time is %t", regIndex, regValue, $time);
//      regWriteEventLocal.regIndex = regIndex;
//      regWriteEventLocal.regValue = regValue;

      if (0 == regIndex)
      begin
	 loQueue.push_front(regValue);
      end
      else
      begin
	 hiQueue.push_front(regValue);
      end
      
//      loHiQueue.push_front(regWriteEventLocal); // the queue push functions return void (no value)

   endfunction

   // *********************************************************************************



   

   // **************************** Register tracing *************************
   // Registers are written on a negedge clock. 
   initial
      begin
	 regsLog = $fopen("core_regs_log.txt");
      end
   
   always @(negedge TB_TOP.cpu_core.CLK)
   begin
      regWriteEvent regWriteEventLocal;

      int regIndex  ;
      int regValue  ;
      
      if (TB_TOP.cpu_core.RegWriteWb && !TB_TOP.cpu_core.Stall)
      begin

	 regIndex = TB_TOP.cpu_core.RegWrWb;
	 regValue = TB_TOP.cpu_core.WriteDataWb;
	 
	 $fwrite(regsLog, "REG WR: Register %02d = 0x%08x\n", TB_TOP.cpu_core.RegWrWb, TB_TOP.cpu_core.WriteDataWb);

	 // Check to see if there are any register writes from the C model to compare against
	 if (regQueue.size() > 0)
	 begin
	    // Pop the back of the register queue to check it matches
	    regWriteEventLocal = regQueue.pop_back();
	    // Packed struct so should be able to compare directly
	    if (regWriteEventLocal != {regIndex, regValue})
	    begin
               CoreMonitorError <= 1'b1;
	       $display("[ERROR] REGS CHECKER : Mismatch found at time %t", $time);
	       $display("[DEBUG] -> regIndex    Expected %02d, Actual %02d", regWriteEventLocal.regIndex, regIndex  );
	       $display("[DEBUG] -> regValue    Expected 0x%x, Actual 0x%x", regWriteEventLocal.regValue, regValue  );
	    end
	    else
	    begin
	       $display("[INFO ] REGS CHECKER: Register match (%02d = 0x%x) at time %t", regIndex, regValue, $time);
	    end
	 end // if (regQueue.size() > 0)

	 // No register events in the queue, but one happened in the processor = ERROR !
	 else if ((0 == regIndex) && (0 == regValue))
	 begin
	    $display("[INFO ] REGS CHECKER : NOP detected after C prediction disabled at time %t", $time);
	 end

	 // Unexpected register access
	 else
	 begin
            CoreMonitorError <= 1'b1;
	    $display("[ERROR] REGS CHECKER : Register Queue empty but processor performed an access at time %t", $time);
	    $display("[DEBUG] -> reg %02d = 0x%x", regIndex, regValue);
	 end // else: !if(regQueue.size() > 0)
	 
      end
   end // if (CORE_DATA_CYC_IN && CORE_DATA_STB_IN && CORE_DATA_ACK_IN)
   // *************************************************************************


   // ************************ lo / hi Value tracing **************************

   // Possible updates
   // MultResultValid : Hi & Lo
   // DivResultValid  : Hi & Lo
   // MtloMem : Lo 
   // MthiMem : Hi

   always @(negedge TB_TOP.cpu_core.CLK)
   begin

      int loVal  ;
      int hiVal  ;

      int tbLoVal;
      int tbHiVal;
      
     if ( (TB_TOP.cpu_core.MultReq && TB_TOP.cpu_core.MultAck)
       || (TB_TOP.cpu_core.DivReq  && TB_TOP.cpu_core.DivAck )
        )
      begin

	 // Need to wait for one cycle before the LoVal and HiVal are updated ..
	 @(negedge TB_TOP.cpu_core.CLK);

	 // Get hi and lo values from the processor core
	 loVal = TB_TOP.cpu_core.LoVal;
	 hiVal = TB_TOP.cpu_core.HiVal;

	 tbLoVal = loQueue.pop_back();
	 tbHiVal = hiQueue.pop_back();
	 
//	 // First pop gets the loval
//	 regWriteEventLocal = loHiQueue.pop_back();
	 if (tbLoVal != loVal)
	 begin
            CoreMonitorError <= 1'b1;
	    $display("[ERROR] LO   CHECKER : Mismatch found at time %t", $time);
	    $display("[DEBUG] ->  Expected 0x%x, Actual 0x%x", tbLoVal, loVal);
  	 end
	 else
	 begin
	    $display("[INFO ] LO   CHECKER: Register match (0x%x) at time %t", loVal, $time);
	 end

//	 // Next pop gets the hival
//	 regWriteEventLocal = loHiQueue.pop_back();
	 if (tbHiVal != hiVal)
	 begin
            CoreMonitorError <= 1'b1;
	    $display("[ERROR] HI   CHECKER: Mismatch found at time %t", $time);
	    $display("[DEBUG] ->  Expected 0x%x, Actual 0x%x", tbHiVal, hiVal);
  	 end
	 else
	 begin
	    $display("[INFO ] HI   CHECKER: Register match (0x%x)at time %t", hiVal, $time);
	 end
      end
   end // always @ (negedge TB_TOP.cpu_core.CLK)
   

   always @(negedge TB_TOP.cpu_core.CLK && !TB_TOP.cpu_core.Stall)
   begin

      int loVal  ;
      int hiVal  ;

      int tbLoVal;
      int tbHiVal;
      

      if (TB_TOP.cpu_core.MtloMem && !TB_TOP.cpu_core.Stall)
      begin
	 $display("[DEBUG] Lo checker detected negedge write at time %t", $time);

	 // Need to wait for one cycle before the LoVal is updated ..
	 @(negedge TB_TOP.cpu_core.CLK);

	 // Get hi and lo values from the processor core
	 loVal = TB_TOP.cpu_core.LoVal;
	 hiVal = TB_TOP.cpu_core.HiVal;

	 $display("[DEBUG] Lo checker sampling negedge data at time %t", $time);

	 // Pop to get the loval
	 tbLoVal = loQueue.pop_back();
	 if (tbLoVal != loVal)
	 begin
            CoreMonitorError <= 1'b1;
	    $display("[ERROR] LO   CHECKER : Mismatch found at time %t", $time);
	    $display("[DEBUG] ->  Expected 0x%x, Actual 0x%x", tbLoVal, loVal);
  	 end
	 else
	 begin
	    $display("[INFO ] LO   CHECKER: Register match (0x%x) at time %t", tbLoVal, $time);
	 end
      end
   end
      
   always @(negedge TB_TOP.cpu_core.CLK)
   begin

      int loVal  ;
      int hiVal  ;

      int tbLoVal;
      int tbHiVal;
      

      if (TB_TOP.cpu_core.MthiMem && !TB_TOP.cpu_core.Stall)
      begin
	 $display("[DEBUG] Hi checker detected negedge write at time %t", $time);

	 // Need to wait for one cycle before the LoVal and HiVal are updated ..
 	 @(negedge TB_TOP.cpu_core.CLK);

	 // Get hi and lo values from the processor core
	 loVal = TB_TOP.cpu_core.LoVal;
	 hiVal = TB_TOP.cpu_core.HiVal;

	 $display("[DEBUG] Hi checker sampling negedge data at time %t", $time);
	 
	 // Get the hival
	 tbHiVal = hiQueue.pop_back();
	 if (tbHiVal != hiVal)
	 begin
            CoreMonitorError <= 1'b1;
	    $display("[ERROR] HI   CHECKER : Mismatch found at time %t", $time);
	    $display("[DEBUG] ->  Expected 0x%x, Actual 0x%x", tbHiVal, hiVal);
  	 end
	 else
	 begin
	    $display("[INFO ] HI   CHECKER: Register match (0x%x)", hiVal);
	 end
     end
   end

   // *************************************************************************


   
   
   // **************************** Data memory tracing *************************
   // Registers are written on a negedge clock. 
initial
   begin : DATA_QUEUE_CHECKER

      int dataRdWrB   ;
      int dataSize    ;
      int dataAddress ;
      int dataValue   ;
      
      dataEvent dataEventLocal;

      dataLog = $fopen("core_data_log.txt");

      $display("[DEBUG] %m Waiting for reset to be de-asserted at time %t", $time);
      // Wait for the reset to be de asserted
      while (1'b0 !== RST_SYNC)
         @(posedge CLK);
      $display("[DEBUG] %m Reset de-asserted at time %t", $time);

      forever
      begin : DATA_CHECK_LOOP
      
         // Wait for an address strobe
         while (1'b1 !== WbCoreDataAddrStb)
            @(posedge CLK);
         $display("[DEBUG] %m Address strobe at time %t", $time);

         // Store read/write common details in ints
         dataSize    = CORE_DATA_SEL_IN[3] + CORE_DATA_SEL_IN[2] + CORE_DATA_SEL_IN[1] + CORE_DATA_SEL_IN[0];
         dataAddress = CORE_DATA_ADR_IN;
         if (CORE_DATA_WE_IN) 
         begin
            dataRdWrB   = 0;
         end
         else
         begin
            dataRdWrB   = 1;
         end
         
         // Write supplies write data along with address strobe
         if (CORE_DATA_WE_IN)
         begin
	    dataValue = CORE_DATA_DAT_WR_IN;
	    $fwrite(dataLog, "DATA WR: Addr 0x%08x = Data 0x%08x, Byte Sel = 0x%1x at time %t\n", dataAddress, dataValue, CORE_DATA_SEL_IN, $time);
            @(posedge CLK); // ASSUME: No overlapping data accesses from CPU
         end

         // Read
         else
         begin
            // Wait for an ACK to be returned with the read data before checking Queue.
            // C Model includes a RAM space, so it can predict what the read values should be (based on previous writes)
            while (!CORE_DATA_ACK_IN)
               @(posedge CLK);
            
	    dataValue = CORE_DATA_DAT_RD_IN;
	    $fwrite(dataLog, "DATA RD: Addr 0x%08x = Data 0x%08x, Byte Sel = 0x%1x at time %t\n", dataAddress, dataValue, CORE_DATA_SEL_IN, $time);
         end

         
         // Check to see if there are any memory accesses from the C model to compare against
         if (dataQueue.size() > 0)
         begin
	    
	    // Pop the back of the data queue to check it matches
	    dataEventLocal = dataQueue.pop_back();

	    // For read and writes, the whole 
	    // The typedefs are packed, so should be able to compare directly
	    if (dataEventLocal != {dataRdWrB, dataSize, dataAddress, dataValue})
	    begin
               CoreMonitorError <= 1'b1;
	       $display("[ERROR] DATA CHECKER : Mismatch found at time %t", $time);
	       $display("[DEBUG] -> dataRdWrB   Expected 0x%x, Actual 0x%x", dataEventLocal.dataRdWrB   , dataRdWrB   );
	       $display("[DEBUG] -> dataSize    Expected 0x%x, Actual 0x%x", dataEventLocal.dataSize    , dataSize    );
	       $display("[DEBUG] -> dataAddress Expected 0x%x, Actual 0x%x", dataEventLocal.dataAddress , dataAddress );
	       $display("[DEBUG] -> dataValue   Expected 0x%x, Actual 0x%x", dataEventLocal.dataValue   , dataValue   );
	    end
	    else
	    begin
	       $display("[INFO ] DATA CHECKER : Match (0x%x = 0x%x) at time %t", dataAddress, dataValue, $time);
	    end // else: !if(dataEventLocal != {dataRdWrB, dataSize, dataAddress, dataValue})
	    
         end // if (regQueue.size() > 0)

         // No register events in the queue, but one happened in the processor = ERROR !
         else
         begin
            CoreMonitorError <= 1'b1;
	    $display("[ERROR] DATA CHECKER : Data Memory Queue empty but processor performed an access at time %t", $time);
	    $display("[DEBUG] -> dataRdWrB   = 0x%x", dataRdWrB   );
	    $display("[DEBUG] -> dataSize    = 0x%x", dataSize    );
	    $display("[DEBUG] -> dataAddress = 0x%x", dataAddress );
	    $display("[DEBUG] -> dataValue   = 0x%x", dataValue   );
         end
      end
   end
   
// *************************************************************************





// **************************** Instruction tracing *************************
   initial
      begin
	 instrLog = $fopen("core_instr_log.txt");
	 
	 cModelTraceEnable = 1'b1;

	 pcQueuePush(0); // Need to add the reset vector 
	 //      pcQueuePush(0); // Need to add the reset vector 
	 //      $display("[INFO ] Preloading PC Queue with reset value of 0x0000_0000");
	 //      LastPcRegRefModel = 32'h1111_1111;

      end

// Instruction reads are pipelined, but the read data doesn't necessarily come a cycle
// after the address is accepted. 2 processes below push the front of a pair of queues
// which are popped by the checker
//   
//   // Instruction reads are pipelined. This means the data comes back a cycle after
//   // the address is sent out..
//   
//   always @(posedge CLK)
//   begin
//      if (!RST_SYNC)
//      begin
//	 if (CORE_INST_CYC_IN && CORE_INST_STB_IN)
//	 begin
//	    PcReg = CORE_INST_ADR_IN;
//	 end
//      end
//   end
//   
//   always @(posedge CLK)
//   begin
//      StallReg <= TB_TOP.cpu_core.Stall;
//   end
//

   // Check the instruction bus to see when a new PC / Address is accepted
   always @(negedge CLK)
   begin : INST_ADDR_Q_PUSH
      if (WbCoreInstAddrStb)
      begin
         dutInstAddrQ.push_front(CORE_INST_ADR_IN);
         $display("[DEBUG] dutInstAddrQ : PC value push 0x%x at time %t", CORE_INST_ADR_IN, $time);
      end
   end
   
   // Check the instruction bus to see when a new instruction is returned
   always @(negedge CLK)
   begin : INST_DATA_Q_PUSH
      if (WbCoreInstDataStb)
      begin
         dutInstDataQ.push_front(CORE_INST_DAT_RD_IN);
         $display("[DEBUG] dutInstDataQ : Instruction push 0x%x at time %t", CORE_INST_DAT_RD_IN, $time);
      end
   end

   // Instruction ADDR and DATA Queues are pushed on the negedge of the clock.
   // Make sure they're popped on the posedge to avoid races
   always @(posedge CLK)
   begin
      
      int queuePcVal;
      int dutPcVal  ;
      int dutInst   ;

      if (!RST_SYNC && (dutInstAddrQ.size() > 0) && (dutInstDataQ.size() > 0))
      begin

//	 // When new instruction read in call the c model to predict the effects
//         // Removed the ACK, the address is accepted when CYC and STB are high
//         // without a STALL coming back
//	 if (CORE_INST_CYC_IN && CORE_INST_STB_IN && !CORE_INST_STALL_IN)
//	 begin
//
         
	    // Once you read a break instruction, stop calling C model to predict the next instruction and
	    // registers / memory accesses
	    if (cModelTraceEnable && (32'h0000_000d == TB_TOP.INST_DAT_RD))
	    begin

	       // Pop the back of the PC queue to check it matches
	       queuePcVal = pcQueue.pop_back();
               dutPcVal   = dutInstAddrQ.pop_back();
               
	       if (queuePcVal != dutPcVal)
	       begin
                  CoreMonitorError <= 1'b1;
		  $display("[ERROR] PC CHECKER : Mismatch found at time %t", $time);
		  $display("[DEBUG] -> Expected 0x%x, Actual 0x%x", queuePcVal, dutPcVal );
	       end
	       else
	       begin
		  $display("[INFO ] PC CHECKER: PC match (0x%x) at time %t", queuePcVal, $time);
	       end

	       
	       $display("[INFO ] Detected break instruction. Disabling C model prediction at time %t", $time);
	       cModelTraceEnable = 0;
	    end

	    // Otherwise, call the C model with the current pc and instruction, it will push new PCs and register / data events
	    // onto the queue to check against the processor.
	    else if (cModelTraceEnable)
	    begin

               dutPcVal   = dutInstAddrQ.pop_back();
               dutInst    = dutInstDataQ.pop_back();
                           
	       $display("[DEBUG] cpuCycle called in C model. PC = 0x%x, INST = 0x%h at time %t", dutPcVal,dutInst, $time);
	       cpuCycle(dutPcVal, dutInst, 0 /* <- show_mode */);
//	       LastPcRegRefModel = PcReg;

	       // Check to see if there are any register writes from the C model to compare against
	       if (pcQueue.size() > 0)
	       begin
	       
		  // Pop the back of the PC queue to check it matches
		  queuePcVal = pcQueue.pop_back();

		  if (queuePcVal != dutPcVal)
		  begin
                     CoreMonitorError <= 1'b1;
		     $display("[ERROR] PC CHECKER : Mismatch found at time %t", $time);
		     $display("[DEBUG] -> Expected 0x%x, Actual 0x%x", queuePcVal, dutPcVal );
		  end
		  else
		  begin
		     $display("[INFO ] PC CHECKER: PC match (0x%x)", queuePcVal);
		  end

		  // Increment PC counter
		  instrCount = instrCount + 1;

		  $fwrite(instrLog, "INST CNT: %04d: ", instrCount);
		  
		  // decode the instruction fields (not all will be used)
		  Opcode = CORE_INST_DAT_RD_IN[OPC_HI:OPC_LO];
		  Rs     = CORE_INST_DAT_RD_IN[RS_HI:RS_LO];
		  Rt     = CORE_INST_DAT_RD_IN[RT_HI:RT_LO];
		  Rd     = CORE_INST_DAT_RD_IN[RD_HI:RD_LO];
		  Shamt  = CORE_INST_DAT_RD_IN[SA_HI:SA_LO];
		  Funct  = CORE_INST_DAT_RD_IN[FUNCT_HI:FUNCT_LO];
		  Immed  = CORE_INST_DAT_RD_IN[IMMED_HI:IMMED_LO];
		  SignXImmed = {{16{Immed[15]}}, Immed};
		  ZeroXImmed = {{16{1'b0}}, Immed};
		  Target = CORE_INST_DAT_RD_IN[TARGET_HI:TARGET_LO];

		  // update PCs, assume no jump / branch, etc
		  currPc = PcReg;
		  nextPc = PcReg + 32'd4;

		  LastInstr = CORE_INST_DAT_RD_IN;
		  
		  if (DelaySlot)
		  begin
		     $fwrite(instrLog, "DLY_SLOT: ");
		     nextPc = jumpPc;
		     DelaySlot = 1'b0;
		  end
		  
		  $fwrite(instrLog, "PC: 0x%08x, INST: 0x%08x : ", dutPcVal, dutInst);
		  
		  // SPECIAL instructions
		  if (Opcode == OPC_SPECIAL)
		  begin
		     
		     // todo: can you replace this with a LUT made from an array of strings?
		     case (Funct)
		       FUNCT_SLL       : 
			  begin
			     RegArray[Rd] = RegArray[Rt] << Shamt; // { RegArray[Rt][31 - Shamt:0]  , {Shamt{1'b0}}};
			     $fwrite(instrLog, "FUNCT  = SLL    ,  REG[%2d] = REG[%2d] << %02d", Rd, Rt, Shamt);
			  end
		       FUNCT_SRL       : 
			  begin
			     RegArray[Rd] = RegArray[Rt] >> Shamt; //{ {Shamt{1'b0}} , RegArray[Rt][31:Shamt]};
			     $fwrite(instrLog, "FUNCT  = SRL    ,  REG[%2d] = REG[%2d] >> %02d", Rd, Rt, Shamt);
			  end 
		       FUNCT_SRA       : 
			  begin
			     RegArray[Rd] = RegArray[Rt] <<< Shamt; // { {Shamt{RegArray[Rt][31]}} , RegArray[Rt][31:Shamt]};
			     $fwrite(instrLog, "FUNCT  = SRA    ,  REG[%2d] = REG[%2d] <<< %02d", Rd, Rt, Shamt);
			  end 
		       FUNCT_SLLV      : 
			  begin
			     RegArray[Rd] = RegArray[Rt] << RegArray[Rs]; // { RegArray[Rt][31 - Rs:0]  , {Rs{1'b0}}};
			     $fwrite(instrLog, "FUNCT  = SLLV   ,  REG[%2d] = REG[%2d] << REG[%2d]", Rd, Rt, Rs);
			  end 
		       FUNCT_SRLV      : 
			  begin
			     RegArray[Rd] = RegArray[Rt] >> RegArray[Rs]; // { {Rs{1'b0}} , RegArray[Rt][31:Rs]};
			     $fwrite(instrLog, "FUNCT  = SRLV   ,  REG[%2d] = REG[%2d] >> REG[%02d]", Rd, Rt, Rs);
			  end 
		       FUNCT_SRAV      : 
			  begin
			     RegArray[Rd] = RegArray[Rt] >>> RegArray[Rs]; // { {Rs{RegArray[Rt][31]}} , RegArray[Rt][31:Rs]};
			     $fwrite(instrLog, "FUNCT  = SRAV   ,  REG[%2d] = REG[%2d] >>> REG[$2d]", Rd, Rt, Rs);
			  end 
		       FUNCT_JR        : 
			  begin
			     jumpPc = RegArray[Rs] ; 
			     DelaySlot = 1'b1;
			     $fwrite(instrLog, "FUNCT  = JR     ,  Delay PC = 0x%08x, Jump PC = REG[%2d]", nextPc, Rs);
			  end 
		       FUNCT_JALR      : 
			  begin
			     RegArray[Rd] = nextPc + 32'd4; 
			     jumpPc = RegArray[Rs] ;
			     DelaySlot = 1'b1;
			     $fwrite(instrLog, "FUNCT  = JALR   , Delay PC = 0x%08x, Jump PC = REG[%2d], REG[31] = 0x%08x", nextPc, Rd, nextPc + 32'd4);

			  end 
		       FUNCT_SYSCALL   : 
			  begin
			     $fwrite(instrLog, "FUNCT  = SYSCALL ");
			  end 
		       FUNCT_BREAK     : 
			  begin
			     $fwrite(instrLog, "FUNCT  = BREAK ");
			  end 
		       FUNCT_MFHI      : 
			  begin
			     RegArray[Rd] = RegHi;
			     $fwrite(instrLog, "FUNCT  = MFHI   ,  REG[%2d] = REGHI", Rd);
			  end 
		       FUNCT_MTHI      : 
			  begin
			     RegHi = RegArray[Rs];
			     $fwrite(instrLog, "FUNCT  = MTHI   ,  REGHI = REG[%2d]", Rs);
			  end 
		       FUNCT_MFLO      : 
			  begin
			     RegArray[Rd] = RegLo;
			     $fwrite(instrLog, "FUNCT  = MFLO   ,  REG[%2d] = REGHI", Rd);
			  end 
		       FUNCT_MTLO      : 
			  begin
			     RegLo = RegArray[Rs];
			     $fwrite(instrLog, "FUNCT  = MTLO   ,  REGLO = REG[%2d]", Rs);
			  end 
		       FUNCT_MULT      : 
			  begin
			     MultResult = RegArray[Rs] * RegArray[Rt]; 
			     RegLo = MultResult[31:0]; 
			     RegHi = MultResult[63:32];
			     $fwrite(instrLog, "FUNCT  = MULT   ,  REG{HI,LO} = REG[%2d] * REG [%2d]", Rs, Rt);		 
			  end 
		       FUNCT_MULTU     : 
			  begin
			     MultResult = RegArray[Rs] * RegArray[Rt]; 
			     RegLo = MultResult[31:0]; 
			     RegHi = MultResult[63:32];
			     $fwrite(instrLog, "FUNCT  = MULTU  ,  REG{HI,LO} = REG[%2d] * REG [%2d]", Rs, Rt);		 		 
			  end 
		       FUNCT_DIV       : 
			  begin
			     DivResult  = RegArray[Rs] / RegArray[Rt]; 
			     RegLo = DivResult[31:0]; 
			     RegHi = DivResult[63:32];
			     $fwrite(instrLog, "FUNCT  = DIV    ,  REG{HI,LO} = REG[%2d] / REG [%2d]", Rs, Rt);
			  end 
		       FUNCT_DIVU      : 
			  begin
			     DivResult  = RegArray[Rs] / RegArray[Rt]; 
			     RegLo = DivResult[31:0]; 
			     RegHi = DivResult[63:32];
			     $fwrite(instrLog, "FUNCT  = DIVU   ,  REG{HI,LO} = REG[%2d] / REG [%2d]", Rs, Rt);
			  end 
		       FUNCT_ADD       : 
			  begin
			     RegArray[Rd] = RegArray[Rs] + RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = ADD    ,  REG[%2d] = REG[%2d] + REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_ADDU      : 
			  begin
			     RegArray[Rd] = RegArray[Rs] + RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = ADDU   ,  REG[%2d] = REG[%2d] + REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_SUB       : 
			  begin
			     RegArray[Rd] = RegArray[Rs] - RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = SUB    ,  REG[%2d] = REG[%2d] - REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_SUBU      : 
			  begin
			     RegArray[Rd] = RegArray[Rs] - RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = SUBU   ,  REG[%2d] = REG[%2d] - REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_AND       : 
			  begin
			     RegArray[Rd] = RegArray[Rs] & RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = AND    ,  REG[%2d] = REG[%2d] AND REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_OR        : 
			  begin
			     RegArray[Rd] = RegArray[Rs] | RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = OR     ,  REG[%2d] = REG[%2d] OR REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_XOR       : 
			  begin
			     RegArray[Rd] = RegArray[Rs] ^ RegArray[Rt];
			     $fwrite(instrLog, "FUNCT  = XOR    ,  REG[%2d] = REG[%2d] XOR REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_NOR       : 
			  begin
			     RegArray[Rd] = ~(RegArray[Rs] | RegArray[Rt]);
			     $fwrite(instrLog, "FUNCT  = NOR    ,  REG[%2d] = REG[%2d] NOR REG[%2d]", Rd, Rs, Rt);
			  end 
		       FUNCT_SLT       : 
			  begin
			     RegArray[Rd] = (RegArray[Rs] < RegArray[Rt]);
			     $fwrite(instrLog, "FUNCT  = SLT    ,  REG[%2d] = (REG[%2d] < REG[%2d])", Rd, Rs, Rt);
			  end 
		       FUNCT_SLTU      : 
			  begin
			     RegArray[Rd] = (RegArray[Rs] < RegArray[Rt]);
			     $fwrite(instrLog, "FUNCT  = SLTU   ,  REG[%2d] = (REG[%2d] < REG[%2d])", Rd, Rs, Rt);
			  end 
		       default: 
			  begin
                             CoreMonitorError <= 1'b1;
    			     $fwrite(instrLog, "UNRECOGNISED SPECIAL OPCODE");
			     $display("[ERROR] Unrecognized SPECIAL FUNCT");
			  end
		       
		     endcase // case (Instr[FUNCT_HI:SA_LO])

		  end
		  
		  else if (Opcode == OPC_REGIMM)
		  begin
		     case (Rt)
		       REGIMM_BLTZ   : 
			  begin
     			     jumpPc = nextPc + {Immed, 2'b00} ; 
			     $fwrite(instrLog, "REGIMM = BLTZ    , REG[%2d] < 0 ? to PC 0x%08x", Rs, jumpPc);
			     DelaySlot = 1'b1;
			  end
		       
		       REGIMM_BGEZ   : 
 			  begin
     			     jumpPc = nextPc + {Immed, 2'b00} ; 
			     $fwrite(instrLog, "REGIMM = BGEZ    , REG[%2d] >= 0 ? to PC 0x%08x", Rs, jumpPc);
			     DelaySlot = 1'b1;
			  end
		       
		       REGIMM_BLTZAL :
			  begin

     			     jumpPc = nextPc + {Immed, 2'b00} ; 
			     $fwrite(instrLog, "REGIMM = BLTZAL  , REG[%2d] < 0 ? to PC 0x%08x, REG[31] = 0x%08x", Rs, jumpPc, nextPc + 32'd4);
			     DelaySlot = 1'b1;
			  end
		       
		       REGIMM_BGEZAL :
 			  begin

     			     jumpPc = nextPc + {Immed, 2'b00} ; 
			     $fwrite(instrLog, "REGIMM = BGEZAL  , REG[%2d] >= 0 ? to PC 0x%08x, REG[31] = 0x%08x", Rs, jumpPc, nextPc + 32'd4);
			     DelaySlot = 1'b1;
			  end
		       
		       default: 
                          begin
                             CoreMonitorError <= 1'b1;
                             $display("[ERROR] Unrecognized REGIMM RT");
                          end
                       
		     endcase // case (Instr[FUNCT_HI:FUNCT_LO])

		  end 
		  
		  else
		  begin
		     case (Opcode)
		       OPC_J        : 
			  begin
			     jumpPc = nextPc + {Target, 2'b00} ; 
			     DelaySlot = 1'b1;
			     $fwrite(instrLog, "OPCODE = J      ,  Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
			  end
		       OPC_JAL      : 
			  begin
			     jumpPc = nextPc + {Target, 2'b00} ; 
			     DelaySlot = 1'b1;
			     RegArray[31] = nextPc + 32'd4;
			     $fwrite(instrLog, "OPCODE = JAL    ,  Delay PC = 0x%08x, Jump PC = 0x%08x, REG[31] = 0x%08x", nextPc, jumpPc, nextPc + 32'd4);
			  end
		       OPC_BEQ      : 
			  begin

			     jumpPc = nextPc + {Immed, 2'b00} ; 
			     $fwrite(instrLog, "OPCODE = BEQ    , REG[%2d] == REG [%2d] ? to PC 0x%08x", Rs, Rt, jumpPc);
			     DelaySlot = 1'b1;
			  end
		       OPC_BNE      : 
			  begin
			     jumpPc = nextPc + {Immed, 2'b00} ; 		 
			     $fwrite(instrLog, "OPCODE = BNE    , REG[%2d] != REG [%2d] ? to PC 0x%08x", Rs, Rt, jumpPc);
			     DelaySlot = 1'b1;
			  end
		       OPC_BLEZ     : 
			  begin
			     jumpPc = nextPc + {Immed, 2'b00} ; 
			     $fwrite(instrLog, "OPCODE = BLEZ   , REG[%2d] <= 0 ? to PC 0x%08x", Rs, jumpPc);
			     DelaySlot = 1'b1;
			  end
		       OPC_BGTZ     : 
			  begin
			     jumpPc = nextPc + {Immed, 2'b00} ; 		 
			     $fwrite(instrLog, "OPCODE = BGTZ   , REG[%2d] > 0 ? to PC 0x%08x", Rs, jumpPc);
			     DelaySlot = 1'b1;
			  end
		       OPC_ADDI     : 
			  begin
			     //		 RegArray[Rt] = RegArray[Rs] + SignXImmed;
			     $fwrite(instrLog, "OPCODE = ADDI   ,  REG[%2d] = REG[%2d] + 0x%08x", Rt, Rs, SignXImmed);
			  end
		       OPC_ADDIU    : 
			  begin
			     //		 RegArray[Rt] = RegArray[Rs] + SignXImmed;
			     $fwrite(instrLog, "OPCODE = ADDIU  ,  REG[%2d] = REG[%2d] + 0x%08x", Rt, Rs, SignXImmed);
			  end
		       OPC_SLTI     : 
			  begin
			     $fwrite(instrLog, "OPCODE = SLTI   , REG[%2d] < IMMED 0x%08x ?", Rs, SignXImmed);
			  end
		       OPC_SLTIU    : 
			  begin
			     $fwrite(instrLog, "OPCODE = SLTIU  , REG[%2d] < IMMED 0x%08x ?", Rs, SignXImmed);
			  end
		       OPC_ANDI     : 
			  begin
			     //		 RegArray[Rt] = RegArray[Rs] & ZeroXImmed;
			     $fwrite(instrLog, "OPCODE = ANDI   ,  REG[%2d] = REG[%2d] AND 0x%08x", Rt, Rs, ZeroXImmed);
			  end
		       OPC_ORI      : 
			  begin
			     //		 RegArray[Rt] = RegArray[Rs] | ZeroXImmed;
			     $fwrite(instrLog, "OPCODE = ORI    ,  REG[%2d] = REG[%2d] OR 0x%08x", Rt, Rs, ZeroXImmed);
			  end
		       OPC_XORI     : 
			  begin
			     //		 RegArray[Rt] = RegArray[Rs] ^ ZeroXImmed;
			     $fwrite(instrLog, "OPCODE = XOR    ,  REG[%2d] = REG[%2d] XOR 0x%08x", Rt, Rs, ZeroXImmed);
			  end
		       OPC_LUI      : 
			  begin
			     RegArray[Rt] = {Immed, 16'h0000};
			     $fwrite(instrLog, "OPCODE = LUI    ,  REG[%2d] = 0x%04x0000", Rt, Immed);
			  end
		       OPC_COP0     : 
			  begin
			     $fwrite(instrLog, "OPC_COP0     , ");
			  end
		       OPC_COP1     : 
			  begin
			     $fwrite(instrLog, "OPC_COP1     , ");
			  end
		       OPC_COP2     : 
			  begin
			     $fwrite(instrLog, "OPC_COP2     , ");
			  end
		       OPC_COP3     : 
			  begin
			     $fwrite(instrLog, "OPC_COP3     , ");
			  end
		       OPC_LB       : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b0001;
			     nextDataWe    = 1'b0;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = 32'hXXXXXXXX;
			     nextDataReg   = RegArray[Rt];
			     $fwrite(instrLog, "OPCODE = LB     ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
			  end
		       OPC_LH       : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b0011;
			     nextDataWe    = 1'b0;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = 32'hXXXXXXXX;
			     nextDataReg   = RegArray[Rt];
			     $fwrite(instrLog, "OPCODE = LH     ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
			  end
		       OPC_LWL      : 
			  begin
			     $fwrite(instrLog, "OPC_LWL      , ");
			  end
		       OPC_LW       :
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b1111;
			     nextDataWe    = 1'b0;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = 32'hXXXXXXXX;
			     nextDataReg   = RegArray[Rt];
			     $fwrite(instrLog, "OPCODE = LW     ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
			  end
		       OPC_LBU      : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b0001;
			     nextDataWe    = 1'b0;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = 32'hXXXXXXXX;
			     nextDataReg   = RegArray[Rt];
			     $fwrite(instrLog, "OPCODE = LBU    ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
			  end
		       OPC_LHU      : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b0011;
			     nextDataWe    = 1'b0;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = 32'hXXXXXXXX;
			     nextDataReg   = RegArray[Rt];
			     $fwrite(instrLog, "OPCODE = LHU    ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
			  end
		       OPC_LWR      : 
			  begin
			     $fwrite(instrLog, "OPC_LWR      , ");
			  end
		       OPC_SB       : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b0001;
			     nextDataWe    = 1'b1;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = RegArray[Rt];
			     nextDataReg   = 5'd0;
			     $fwrite(instrLog, "OPCODE = SB     ,  DATA[ REG[%2d] + Immed 0x%08x] = REG[%2d]", Rs, SignXImmed, Rt);
			  end
		       OPC_SH       : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b0011;
			     nextDataWe    = 1'b1;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = RegArray[Rt];
			     nextDataReg   = 5'd0;
			     $fwrite(instrLog, "OPCODE = SH     ,  DATA[ REG[%2d] + Immed 0x%08x] = REG[%2d]", Rs, SignXImmed, Rt);
			  end
		       OPC_SWL      : 
			  begin
			     $fwrite(instrLog, "OPC_SWL      , ");
			  end
		       OPC_SW       : 
			  begin
			     nextDataAdr   = RegArray[Rs] + SignXImmed;
			     nextDataSel   = 4'b1111;
			     nextDataWe    = 1'b1;
			     nextDataDatRd = 32'hXXXXXXXX;
			     nextDataDatWr = RegArray[Rt];
			     nextDataReg   = 5'd0;
			     $fwrite(instrLog, "OPCODE = SW     ,  DATA[ REG[%2d] + Immed 0x%08x] = REG[%2d]", Rs, SignXImmed, Rt);
			  end
		       OPC_SWR      : 
			  begin
			     $fwrite(instrLog, "OPC_SWR      , ");
			  end
		       OPC_LWC1     : 
			  begin
			     $fwrite(instrLog, "OPC_LWC1     , ");
			  end
		       OPC_LWC2     : 
			  begin
			     $fwrite(instrLog, "OPC_LWC2     , ");
			  end
		       OPC_LWC3     : 
			  begin
			     $fwrite(instrLog, "OPC_LWC3     , ");
			  end
		       OPC_SWC1     : 
			  begin
			     $fwrite(instrLog, "OPC_SWC1     , ");
			  end
		       OPC_SWC2     : 
			  begin
			     $fwrite(instrLog, "OPC_SWC2     , ");
			  end
		       OPC_SWC3     : 
			  begin
			     $fwrite(instrLog, "OPC_SWC3     , ");
			  end

		     endcase // case (Opcode)
		  end 
	       end // if (pcQueue.size() > 0)

	       // The processor executed an event not present in the C model prediction queue
	       else
	       begin
                  CoreMonitorError <= 1'b1;
		  $display("[ERROR] INST CHECKER : Processor executed instruction which wasn't predicted at time %t", $time);
		  $display("[DEBUG] -> PC = 0x%x, INST = 0x%x", PcReg, TB_TOP.INST_DAT_RD);
	       end // else: !if(pcQueue.size() > 0)
	       
	    end // else: !if(Opcode == OPC_REGIMM)
	    $fwrite(instrLog, "\n");
//	 end // if (CORE_INST_CYC_IN && CORE_INST_STB_IN && CORE_INST_ACK_IN)
      end // if (!RST_SYNC)
   end // always @ (negedge CLK)

   // *************************************************************************




endmodule
/*****************************************************************************/
