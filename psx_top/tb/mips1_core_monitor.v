/* INSERT MODULE HEADER */


/*****************************************************************************/

// No ports on the monitor, this is used in white-box testing and refers to
// hierarchical links in the tb_defines file

module MIPS1_CORE_MONITOR 
#(parameter VERBOSE = 0)
();

`define TESTSTR "code.hex"

`include "tb_defines.v"
`include "psx_top_defines.vh"  
`include "cpu_defs.v"

   /////////////////////////////////////////////////////////////////////////////
   // Define all the links to the CPU Core's ports (this module can be
   // instantiated anywhere, it might not be possible to wire ports directly).
   //
`define MON_CLK                `CPU.CLK               
`define MON_RST_SYNC           `CPU.RST_SYNC

`define MON_CORE_INST_ADR      `CPU.CORE_INST_ADR_OUT   
`define MON_CORE_INST_CYC      `CPU.CORE_INST_CYC_OUT   
`define MON_CORE_INST_STB      `CPU.CORE_INST_STB_OUT   
`define MON_CORE_INST_WE       `CPU.CORE_INST_WE_OUT    
`define MON_CORE_INST_SEL      `CPU.CORE_INST_SEL_OUT   
`define MON_CORE_INST_CTI      `CPU.CORE_INST_CTI_OUT   
`define MON_CORE_INST_BTE      `CPU.CORE_INST_BTE_OUT   
`define MON_CORE_INST_ACK      `CPU.CORE_INST_ACK_IN    
`define MON_CORE_INST_STALL    `CPU.CORE_INST_STALL_IN  
`define MON_CORE_INST_ERR      `CPU.CORE_INST_ERR_IN    
`define MON_CORE_INST_DAT_RD   `CPU.CORE_INST_DAT_RD_IN 
`define MON_CORE_INST_DAT_WR   `CPU.CORE_INST_DAT_WR_OUT

`define MON_CORE_DATA_ADR      `CPU.CORE_DATA_ADR_OUT   
`define MON_CORE_DATA_CYC      `CPU.CORE_DATA_CYC_OUT   
`define MON_CORE_DATA_STB      `CPU.CORE_DATA_STB_OUT   
`define MON_CORE_DATA_WE       `CPU.CORE_DATA_WE_OUT    
`define MON_CORE_DATA_SEL      `CPU.CORE_DATA_SEL_OUT   
`define MON_CORE_DATA_CTI      `CPU.CORE_DATA_CTI_OUT   
`define MON_CORE_DATA_BTE      `CPU.CORE_DATA_BTE_OUT   
`define MON_CORE_DATA_ACK      `CPU.CORE_DATA_ACK_IN    
`define MON_CORE_DATA_STALL    `CPU.CORE_DATA_STALL_IN  
`define MON_CORE_DATA_ERR      `CPU.CORE_DATA_ERR_IN    
`define MON_CORE_DATA_DAT_RD   `CPU.CORE_DATA_DAT_RD_IN 
`define MON_CORE_DATA_DAT_WR   `CPU.CORE_DATA_DAT_WR_OUT

// Internal Wires
`define MON_STALL              `CPU.Stall  
`define MON_LO_VAL             `CPU.LoVal
`define MON_HI_VAL             `CPU.HiVal
`define MON_REG_WR             `CPU.RegWriteWb
`define MON_REG_SEL            `CPU.RegWrWb
`define MON_REG_WR_DATA        `CPU.WriteDataWb
`define MON_MULT_REQ           `CPU.MultReq
`define MON_MULT_ACK           `CPU.MultAck
`define MON_DIV_REQ            `CPU.DivReq
`define MON_DIV_ACK            `CPU.DivAck
`define MON_MTHI               `CPU.MthiMem  
`define MON_MTLO               `CPU.MtloMem  

/////////////////////////////////////////////////////////////////////////////
// Import data type from the package
//
import CPU_CORE_MONITOR_PKG::regWriteEvent;
import CPU_CORE_MONITOR_PKG::wbM2SEvent;
import CPU_CORE_MONITOR_PKG::wbS2MEvent;

/////////////////////////////////////////////////////////////////////////////
// Declare all the Imports (C functions accesible by SV)
//
import "DPI-C" context function void helloWorld (); // Hello World sanity check
import "DPI-C" context function void cpuInit (); // Init CPU model
import "DPI-C" context function void cpuCycle(int pc, int opcode, int rd_data, int show_mode); // Execute one cycle
import "DPI-C" context function int  cpuEnd (); // De-allocate memory and end sim
          
/////////////////////////////////////////////////////////////////////////////
// Declare all the Exports (SV functions accesible by C)
//
// (input int pcVal);
export "DPI-C" function refInstM2SPush ; 
 // (input int regIndex, input int regValue);
export "DPI-C" function refRegPush     ;
// (input int dataRdWrB, input int dataSize, input int dataAddress, input int dataValue);
export "DPI-C" function refDataM2SPush ; 
 // (input int loVal, input int hiVal);
export "DPI-C" function refLoHiPush    ;

   /////////////////////////////////////////////////////////////////////////////
   // TB Queues used as FIFOs in the tests.
   //
   
   // DUT-side Queues
   wbM2SEvent dutInstM2SQ[$];
   wbS2MEvent dutInstS2MQ[$];
   wbM2SEvent dutDataM2SQ[$];
   wbS2MEvent dutDataS2MQ[$];
      
   regWriteEvent dutRegQ[$];
   int dutLoQ[$];
   int dutHiQ[$];

   // C-model-side Queues.
   // No Slave-2-Master for the reference model, that comes from DUT.
   wbM2SEvent refInstM2SQ[$];
   wbS2MEvent refInstS2MQ[$];
   wbM2SEvent refDataM2SQ[$];
   wbS2MEvent refDataS2MQ[$];

   regWriteEvent refRegQ[$];
   int refLoQ[$];
   int refHiQ[$];

   int modelTraceActive;
   
      // Wishbone decoded signals
      wire      WbCoreInstAddrStb = `MON_CORE_INST_CYC & `MON_CORE_INST_STB & ~`MON_CORE_INST_STALL;
      wire      WbCoreInstDataStb = `MON_CORE_INST_CYC & `MON_CORE_INST_ACK;
      wire      WbCoreDataAddrStb = `MON_CORE_DATA_CYC & `MON_CORE_DATA_STB & ~`MON_CORE_DATA_STALL;
      wire      WbCoreDataDataStb = `MON_CORE_DATA_CYC & `MON_CORE_DATA_ACK;

//      assign CORE_MONITOR_ERROR_OUT = CoreMonitorError;
//      
   // Initialise the CPU model (will happen while the design is in reset)
   initial
      begin
	 // Initialise CPU model
	 // helloWorld();
	 cpuInit();
         if (VERBOSE > 0) $display("[INFO ] MIPS1 Core Monitor initialised at time %t", $time);
      end
   
   // Set up Verilog time format
   initial
      begin
         $timeformat(-9, 0, " ns", 6);
      end



   /////////////////////////////////////////////////////////////////////////////
   // Helper functions
   //

   // This function returns a 1 if the M2S structs match, or 0 if they don't
   // It only checks the write data for a write transaction
   function int chkM2SData (wbM2SEvent wbM2SEventRef, wbM2SEvent wbM2SEventDut, string dataType, int Verbose = 1);

      chkM2SData = 0; // Assume it doesn't match initially
      
      // Assume the ref is the more trusted one, check for a read transaction
      // READ
      if (wbM2SEventRef.RdWrB)
      begin

         // Data match ! Write Data M2S field not checked for read
         if ((wbM2SEventRef.Address == wbM2SEventDut.Address) &&
             (wbM2SEventRef.Sel     == wbM2SEventDut.Sel    ) &&
             (wbM2SEventRef.RdWrB   == wbM2SEventDut.RdWrB  )
             )
         begin
            if (VERBOSE > 0) $display("[INFO ] WB M2S %s Match at time %t", dataType, $time);
            chkM2SData = 1;
         end

         // Mismatch of read M2S transaction data
         else
         begin
            $display("[ERROR] WB M2S %s Mismatch at time %t", dataType, $time);
            
//            if (Verbose)
//            begin
               $display("[ERROR] -> RdWrB   Expected 0x%x, Actual 0x%x"
                        , wbM2SEventRef.RdWrB   
                        , wbM2SEventDut.RdWrB   );
	       $display("[ERROR] -> Sel     Expected 0x%x, Actual 0x%x"
                        , wbM2SEventRef.Sel    
                        , wbM2SEventDut.Sel     );
	       $display("[ERROR] -> Address Expected 0x%x, Actual 0x%x"
                        , wbM2SEventRef.Address 
                        , wbM2SEventDut.Address );
               //	       $display("[DEBUG] -> Value   Expected 0x%x, Actual 0x%x"
               //                        ,wbM2SEventRef.WrValue 
               //                        ,wbM2SEventDut.WrValue );
//            end
            
         end
         
         
      end

      // WRITE comparison, include the write data too
      else
      begin

         if ((wbM2SEventRef.Address == wbM2SEventDut.Address ) &&
             (wbM2SEventRef.Sel     == wbM2SEventDut.Sel     ) &&
             (wbM2SEventRef.RdWrB   == wbM2SEventDut.RdWrB   ) &&
             (wbM2SEventRef.WrValue == wbM2SEventDut.WrValue )
             )
         begin
            if (VERBOSE > 0) $display("[INFO ] WB M2S %s Match at time %t", dataType, $time);
            chkM2SData = 1;
         end

         else
         begin

            $display("[ERROR] WB M2S %s Mismatch at time %t", dataType, $time);

//            if (Verbose)
//            begin
               $display("[ERROR] -> RdWrB   Expected 0x%x, Actual 0x%x"
                        , wbM2SEventRef.RdWrB   
                        , wbM2SEventDut.RdWrB   );
	       $display("[ERROR] -> Sel     Expected 0x%x, Actual 0x%x"
                        , wbM2SEventRef.Sel    
                        , wbM2SEventDut.Sel     );
	       $display("[ERROR] -> Address Expected 0x%x, Actual 0x%x"
                        , wbM2SEventRef.Address 
                        , wbM2SEventDut.Address );
               $display("[ERROR] -> Value   Expected 0x%x, Actual 0x%x"
                        ,wbM2SEventRef.WrValue 
                        ,wbM2SEventDut.WrValue );
//            end
         end
      end
   endfunction
   
   /////////////////////////////////////////////////////////////////////////////
   // SV functions called from C. 
   // These functions all push into REF FIFOs for later comparison with DUT-side
   // FIFOs

   // C Ref Model : Instruction Master-to-Slave PUSH
   function void refInstM2SPush (int Address);

   // Pack the ints sent over from the C environment into a Master-to-Slave
   // struct, and push this into the refInstM2S FIFO.
   wbM2SEvent wbM2SEventLocal;

   wbM2SEventLocal.RdWrB   = 1             ; // Fixed fields for instruction fetches
   wbM2SEventLocal.Sel     = 32'h0000_000f ; // Have to be READ, 32-bits
   wbM2SEventLocal.Address = Address       ; 
   wbM2SEventLocal.WrValue = 0             ;  
   
   if (VERBOSE)  $display("[DEBUG] REF INST M2S Push : Addr = 0x%x, Sel = 0x%x, RdWrB = %1d, WrValue = 0x%x at time %t"
               ,wbM2SEventLocal.Address
               ,wbM2SEventLocal.Sel[3:0]
               ,wbM2SEventLocal.RdWrB
               ,wbM2SEventLocal.WrValue
               , $time    );

   refInstM2SQ.push_front(wbM2SEventLocal);
   
   endfunction
   
   // C Ref Model : Data Master-to-Slave PUSH
   function void refDataM2SPush (int RdWrB, int Size, int Address, int WrValue);

      logic [31:0] AddrAligned;
      logic [ 3:0] Sel;
      logic [31:0] DataAligned;
      
   // Pack the ints sent over from the C environment into a Master-to-Slave
   // struct, and push this into the refDataM2S FIFO.
   wbM2SEvent wbM2SEventLocal;

   wbM2SEventLocal.RdWrB   = RdWrB   ;
//   wbM2SEventLocal.Size    = Size    ;
//   wbM2SEventLocal.Address = Address ;
   wbM2SEventLocal.WrValue = WrValue ;

      DataAligned = 0;
      
      // Need to generate aligned Address and Sel from Size
      case (Size)
        4 : 
           begin
              if (2'b00 != Address[1:0])
              begin
                 $display("[ERROR] Unaligned C Ref model M2S Data Push. Address = 0x%x, Size = %2d at time %t", Address, Size, $time);
              end
              else
              begin
                 AddrAligned = Address;
                 Sel = 4'b1111;
                 DataAligned = WrValue;
              end
           end 

        2 :
           begin
              if (1'b0 != Address[0])
              begin
                 $display("[ERROR] Unaligned C Ref model M2S Data Push. Address = 0x%x, Size = %2d at time %t", Address, Size, $time);
              end
              else
              begin
                 // 32-bit align the address ...
                 AddrAligned = {Address[31:2], 2'b00};
                 // ... and set SEL strobes accordingly
                 if (Address[1])
                 begin
                    Sel = 4'b1100;
                    DataAligned[31:16] = WrValue[15:0];
                 end
                 else
                 begin
                    Sel = 4'b0011;
                    DataAligned[15:0] = WrValue[15:0];
                 end
              end
           end

        1 :
           begin
              // 32-bit align the address ...
              AddrAligned = {Address[31:2], 2'b00};
              // ... and set SEL strobes accordingly
              Sel = 4'b0000;
              Sel[Address[1:0]] = 1'b1;

              case (Address[1:0])
                2'b00 : DataAligned[ 7: 0] = WrValue[7:0];
                2'b01 : DataAligned[15: 8] = WrValue[7:0];
                2'b10 : DataAligned[23:16] = WrValue[7:0];
                2'b11 : DataAligned[31:24] = WrValue[7:0];
              endcase

           end
        
        default : $display("[ERROR] Illegal Size pushed from C model = 0x%x at time %t", Size, $time);
      endcase

      // Store the SEL and aligned address in the FIFO
      wbM2SEventLocal.Sel     = Sel         ;
      wbM2SEventLocal.Address = AddrAligned ;
      wbM2SEventLocal.WrValue = DataAligned ;
         
      if (VERBOSE) $display("[DEBUG] REF DATA M2S Push : Addr = 0x%x, Sel = 0x%x, RdWrB = %1d, WrValue = 0x%x at time %t"
               ,wbM2SEventLocal.Address
               ,wbM2SEventLocal.Sel[3:0]
               ,wbM2SEventLocal.RdWrB
               ,wbM2SEventLocal.WrValue
               , $time    );

      refDataM2SQ.push_front(wbM2SEventLocal);
   
   endfunction

   // C Ref Model : Register write PUSH
   function void refRegPush (input int regIndex, input int regValue);

      // Pack ints into the struct and push into Register FIFO
      regWriteEvent regWriteEventLocal;
      
      regWriteEventLocal.regIndex = regIndex;
      regWriteEventLocal.regValue = regValue;
      
      if (VERBOSE) $display("[DEBUG] REF REG WR Push : Index = %2d, Data = 0x%x at time %t"
               , regWriteEventLocal.regIndex
               , regWriteEventLocal.regValue
               , $time    );

      refRegQ.push_front(regWriteEventLocal); // the queue push functions return void (no value)

   endfunction

   // C Ref Model : LO or HI register PUSH. regIndex = 0 for LO, 1 for HI
   function void refLoHiPush (input int regIndex, input int regValue);

      // If regIndex is 1, store in HI Queue
      if (regIndex)
      begin
         if (VERBOSE) $display("[DEBUG] REF HI REG WR Push : Hi = 0x%x at time %t"
                  , regValue
                  , $time    );
	 refHiQ.push_front(regValue);
      end
      else
      begin
         if (VERBOSE) $display("[DEBUG] REF LO REG WR Push : Lo = 0x%x at time %t"
                  , regValue
                  , $time    );
	 refLoQ.push_front(regValue);
      end
      
   endfunction

   /////////////////////////////////////////////////////////////////////////////
   // DUT FIFO pushes (from DUT I/F)
   // These functions all push into DUT FIFOs for later comparison with REF FIFOs
   //

   // DUT INST M2S FIFO
   always @(negedge `MON_CLK)
   begin

      wbM2SEvent wbM2SEventLocal;
      
      if (WbCoreInstAddrStb)
      begin
         wbM2SEventLocal.RdWrB    = (32'd1 === `MON_CORE_INST_WE) ? 0 : 1;
         wbM2SEventLocal.Sel      = {28'h000_0000, `MON_CORE_INST_SEL};
         wbM2SEventLocal.Address  = `MON_CORE_INST_ADR;
         wbM2SEventLocal.WrValue  = `MON_CORE_INST_DAT_WR;

         assert (!$isunknown(`MON_CORE_INST_WE));
         assert (!$isunknown(`MON_CORE_INST_SEL));
         assert (!$isunknown(`MON_CORE_INST_ADR));
         assert (!$isunknown(`MON_CORE_INST_DAT_WR));
        
         
         if (VERBOSE) $display("[DEBUG] DUT INST M2S Push : Addr = 0x%x, Sel = 0x%x, RdWrB = %1d, WrValue = 0x%x at time %t"
                  ,wbM2SEventLocal.Address
                  ,wbM2SEventLocal.Sel[3:0]
                  ,wbM2SEventLocal.RdWrB
                  ,wbM2SEventLocal.WrValue
                  , $time    );
         
         dutInstM2SQ.push_front(wbM2SEventLocal);
      end
   end
   
   // DUT DATA M2S FIFO
   always @(negedge `MON_CLK)
   begin

      wbM2SEvent wbM2SEventLocal;
      
      if (WbCoreDataAddrStb)
      begin
         wbM2SEventLocal.RdWrB    = (32'd1 == `MON_CORE_DATA_WE) ? 0 : 1;
         wbM2SEventLocal.Sel      = {28'h000_0000, `MON_CORE_DATA_SEL};
         wbM2SEventLocal.Address  = `MON_CORE_DATA_ADR;
         wbM2SEventLocal.WrValue  = `MON_CORE_DATA_DAT_WR;
         
         if (VERBOSE) $display("[DEBUG] DUT DATA M2S Push : Addr = 0x%x, Sel = 0x%x, RdWrB = %1d, WrValue = 0x%x at time %t"
                  ,wbM2SEventLocal.Address
                  ,wbM2SEventLocal.Sel[3:0]
                  ,wbM2SEventLocal.RdWrB
                  ,wbM2SEventLocal.WrValue
                  , $time    );
         
         dutDataM2SQ.push_front(wbM2SEventLocal);
      end
   end
   
   // DUT INST S2M FIFO
   always @(negedge `MON_CLK)
   begin

      wbS2MEvent wbS2MEventLocal;
      
      if (WbCoreInstDataStb)
      begin
         wbS2MEventLocal.RdValue  = `MON_CORE_INST_DAT_RD;

          if (VERBOSE) $display("[DEBUG] DUT INST S2M Push : RdValue = 0x%x at time %t"
                  ,wbS2MEventLocal.RdValue
                  , $time    );
        
         dutInstS2MQ.push_front(wbS2MEventLocal);
      end
   end
   
   // DUT DATA S2M FIFO
   always @(negedge `MON_CLK)
   begin

      wbS2MEvent wbS2MEventLocal;
      
      if (WbCoreDataDataStb)
      begin
         wbS2MEventLocal.RdValue  = `MON_CORE_DATA_DAT_RD;

         if (VERBOSE) $display("[DEBUG] DUT DATA S2M Push : RdValue = 0x%x at time %t"
                  ,wbS2MEventLocal.RdValue
                  , $time    );
        
        dutDataS2MQ.push_front(wbS2MEventLocal);
      end
   end

   // DUT REG FIFO PUSH
   always @(negedge `MON_CLK)
   begin
      regWriteEvent regWriteEventLocal;

      if (`MON_REG_WR && !`MON_STALL)
      begin
         regWriteEventLocal.regIndex = `MON_REG_SEL;
         regWriteEventLocal.regValue = `MON_REG_WR_DATA;
         
         if (VERBOSE) $display("[DEBUG] DUT REG WR Push : Index = %2d, Data = 0x%x at time %t"
                  , regWriteEventLocal.regIndex
                  , regWriteEventLocal.regValue
                  , $time    );
         
         dutRegQ.push_front(regWriteEventLocal);                   
      end
   end
   
   // DUT LO and HI FIFO PUSH
   always @(negedge `MON_CLK)
   begin
      regWriteEvent regWriteEventLocal;

      // Multiply or divide updates both HI and LO
      if ((`MON_MULT_REQ && `MON_MULT_ACK ) ||
          (`MON_DIV_REQ  && `MON_DIV_ACK  ))
      begin
         if (VERBOSE) $display("[DEBUG] DUT LO REG WR Push : Lo = 0x%x at time %t"
                  , `MON_LO_VAL
                  , $time    );
         if (VERBOSE) $display("[DEBUG] DUT HI REG WR Push : Hi = 0x%x at time %t"
                  , `MON_HI_VAL
                  , $time    );

         dutLoQ.push_front(`MON_LO_VAL);
         dutHiQ.push_front(`MON_HI_VAL);
         
      end

      if (`MON_MTHI && !`MON_STALL)
      begin
         if (VERBOSE) $display("[DEBUG] DUT HI REG WR Push : Hi = 0x%x at time %t"
                  , `MON_HI_VAL
                  , $time    );
         dutHiQ.push_front(`MON_HI_VAL);
      end

      if (`MON_MTLO && !`MON_STALL)
      begin
         if (VERBOSE) $display("[DEBUG] DUT LO REG WR Push : Lo = 0x%x at time %t"
                  , `MON_LO_VAL
                  , $time    );
         dutLoQ.push_front(`MON_LO_VAL);
      end
      
   end
   
   
   /////////////////////////////////////////////////////////////////////////////
   // CHECKER : CPU Core Instruction and Data always block
   //

   initial
      begin : CORE_INST_DATA_CHECK

         regWriteEvent regWriteEventLocal;

         wbM2SEvent wbM2SEventLocal;
         wbS2MEvent wbS2MEventLocal;

         wbM2SEvent  refM2SDataEventLocal;
         wbM2SEvent  dutM2SDataEventLocal;
         wbS2MEvent  refS2MDataEventLocal;
         wbS2MEvent  dutS2MDataEventLocal;
         
         wbM2SEvent  refM2SInstEventLocal;
         wbM2SEvent  dutM2SInstEventLocal;
         wbS2MEvent  refS2MInstEventLocal;
         wbS2MEvent  dutS2MInstEventLocal;

         int LoadInst;
         int StoreInst;
         logic [5:0] InstOpcode;
         
         // Need to align the data before returning to the C model
         int RdData;

         int instCount = 0;
         
         // Need to put the first reference PC into the refInstM2S FIFO, this
         // is the reset vector so it has to match the HW.
         wbM2SEventLocal.RdWrB    = 1;
         wbM2SEventLocal.Sel      = 32'h0000_000f;
         wbM2SEventLocal.Address  = CPU_RST_VECTOR;
         wbM2SEventLocal.WrValue  = 0;
         refInstM2SQ.push_front(wbM2SEventLocal);

         // The first instruction read in is treated as a NOP, add this to
         // the register queue
         regWriteEventLocal.regIndex = 0;
         regWriteEventLocal.regValue = 0;
         refRegQ.push_front(regWriteEventLocal);
         
         // Enable Model tracing
         modelTraceActive = 1;
         
         // Wait for reset to de-assert
         while (1'b0 !== `MON_RST_SYNC)
            @(posedge `MON_CLK);

         // Main test loop
         while (modelTraceActive)
         begin
            
//            // Wait for a REF Instruction M2S to be in the FIFO. 
//            while (refInstM2SQ.size() == 0)
//               @(posedge `MON_CLK);

            ////////////////////////////////////////////////////////////////////
            // Wait for the DUT to read a new instruction, check M2S with 
            // reference model
            
            // Wait for the DUT to do an instruction fetch
            while ((dutInstM2SQ.size() == 0) ||
                   (dutInstS2MQ.size() == 0))
               @(posedge `MON_CLK);
            if (VERBOSE) $display("[DEBUG] CPU WB Instruction ready at time %t", $time);

            // Update instruction counter, print 
            instCount++;
            if (0 == (instCount % 10000))
            begin
               $display("[INFO ] Instruction %6d issued at time %t", instCount, $time);
            end
            
            
            // Use the DUT Instruction Address and Data to call CPU model later
            dutM2SInstEventLocal = dutInstM2SQ.pop_back();
            dutS2MInstEventLocal = dutInstS2MQ.pop_back();
            
            InstOpcode = dutS2MInstEventLocal.RdValue[OPC_HI:OPC_LO];
            
            if ((OPC_LB  == InstOpcode) ||
                (OPC_LH  == InstOpcode) ||
                (OPC_LW  == InstOpcode) ||
                (OPC_LBU == InstOpcode) ||
                (OPC_LHU == InstOpcode) 
                )
            begin
               LoadInst  = 1;
               StoreInst = 0;
            end
            else if ((OPC_SB   == InstOpcode) ||
                     (OPC_SH   == InstOpcode) ||
                     (OPC_SW   == InstOpcode) 
                     )
            begin
               LoadInst  = 0;
               StoreInst = 1;
            end
            else if ((OPC_LWL    == InstOpcode) ||
                     (OPC_LBU    == InstOpcode) ||
                     (OPC_LHU    == InstOpcode) ||
                     (OPC_LWR    == InstOpcode) ||
                     (OPC_SWL    == InstOpcode) ||
                     (OPC_SWR    == InstOpcode) ||
                     (OPC_LWC0   == InstOpcode) ||
                     (OPC_LWC1   == InstOpcode) ||
                     (OPC_LWC2   == InstOpcode) ||
                     (OPC_LWC3   == InstOpcode) ||
                     (OPC_SWC0   == InstOpcode) ||
                     (OPC_SWC1   == InstOpcode) ||
                     (OPC_SWC2   == InstOpcode) ||
                     (OPC_SWC3   == InstOpcode)
                     )
            begin
               LoadInst  = 0;
               StoreInst = 0;
               $display("[ERROR] Unsupported Load or Store (0x%x) found at time %t",
                        InstOpcode,
                        $time);
            end // if ((OPC_LWL    == InstOpcode) ||...
            else 
            begin
               LoadInst  = 0;
               StoreInst = 0;
            end
            
               
            ////////////////////////////////////////////////////////////////////
            // LOAD : Wait for DUT to have an M2S and S2M entry in the FIFOs.
            // Then run the cpu model to predict M2S and read data (S2M)
            
            // If the current Instruction is a Load of some sort, you can't call 
            // the CPU model until the read data has been returned by the system.
            // Due to the pipelining of the CPU, this won't be for a few cycles 
            // later. So check the instruction to see if it's a load.
            if (LoadInst)
            begin
               if (VERBOSE) $display("[DEBUG] Load instruction (OPC = 0x%x) detected at time %t",
                        InstOpcode,
                        $time);

               if (VERBOSE) $display("[DEBUG] Waiting for DUT Data M2S and S2M at time %t", $time);

               while ((0 == dutDataM2SQ.size()) || (0 == dutDataS2MQ.size()))
                  @(posedge `MON_CLK);
               if (VERBOSE) $display("[DEBUG] DUT Data M2S and S2M ready at time %t", $time);

               dutM2SDataEventLocal = dutDataM2SQ.pop_back();
               dutS2MDataEventLocal = dutDataS2MQ.pop_back();


               // Read data will be aligned with the byte lanes it was returned on.
               // Need to shift down to bottom LSBs
               RdData = 0;
               case(dutM2SDataEventLocal.Sel)
                 4'b1111 : RdData = dutS2MDataEventLocal.RdValue;
                 4'h1100 : RdData = {16'd0, dutS2MDataEventLocal.RdValue[31:16]};
                 4'b0011 : RdData = {16'd0, dutS2MDataEventLocal.RdValue[15: 0]};
                 4'b1000 : RdData = {24'd0, dutS2MDataEventLocal.RdValue[31:24]};
                 4'b0100 : RdData = {24'd0, dutS2MDataEventLocal.RdValue[23:16]};
                 4'b0010 : RdData = {24'd0, dutS2MDataEventLocal.RdValue[15: 8]};
                 4'b0001 : RdData = {24'd0, dutS2MDataEventLocal.RdValue[ 7: 0]};
               endcase // case (dutM2SDataEventLocal.Sel)               
               
               // Call CPU cycle to predict REF Data M2S and store DUT Data S2M
               if (VERBOSE) $display("[INFO ] C Model call. PC = 0x%x, Inst = 0x%x at time %t",
                        dutM2SInstEventLocal.Address,
                        dutS2MInstEventLocal.RdValue,
                        $time);
               
               cpuCycle(dutM2SInstEventLocal.Address ,
                        dutS2MInstEventLocal.RdValue ,
                        RdData, // need to align dutS2MDataEventLocal.RdValue 
                        VERBOSE);

            end // if (LoadInst)


            ////////////////////////////////////////////////////////////////////
            // STORE : Wait for DUT to have an M2S and S2M entry in the FIFOs.
            // Then run the cpu model to generate expected Data M2S
            else if (StoreInst)
            begin
               if (VERBOSE) $display("[DEBUG] Store instruction (OPC = 0x%x) detected at time %t",
                        InstOpcode,
                        $time);

               while ((0 == dutDataM2SQ.size()) || (0 == dutDataS2MQ.size()))
                  @(posedge `MON_CLK);
               if (VERBOSE) $display("[DEBUG] DUT Data M2S and S2M ready at time %t", $time);

               dutM2SDataEventLocal = dutDataM2SQ.pop_back();
               dutS2MDataEventLocal = dutDataS2MQ.pop_back();
                                
               // Call CPU cycle to predict REF Data M2S and store DUT Data S2M
               if (VERBOSE) $display("[INFO ] C Model call. PC = 0x%x, Inst = 0x%x at time %t",
                        dutM2SInstEventLocal.Address,
                        dutS2MInstEventLocal.RdValue,
                        $time);
               
               // Call CPU cycle to predict REF Data M2S
               cpuCycle(dutM2SInstEventLocal.Address ,
                        dutS2MInstEventLocal.RdValue ,
                        0 ,
                        VERBOSE);


            end // if (StoreInst)

            ////////////////////////////////////////////////////////////////////
            // NOT LOAD OR STORE : Don't wait for any Data entries in the FIFOs,
            // just call the reference model
            else
            begin
               // Call CPU cycle to predict REF Data M2S and store DUT Data S2M
               if (VERBOSE) $display("[INFO ] C Model call. PC = 0x%x, Inst = 0x%x at time %t",
                        dutM2SInstEventLocal.Address,
                        dutS2MInstEventLocal.RdValue,
                        $time);
               
               // Call CPU cycle to predict REF Inst M2S
               cpuCycle(dutM2SInstEventLocal.Address ,
                        dutS2MInstEventLocal.RdValue ,
                        0 ,
                        VERBOSE);

            end
            
            ////////////////////////////////////////////////////////////////////
            // LOAD OR STORE : Check the M2S predicted by the model matches DUT
            //
            if (StoreInst || LoadInst)
            begin

               // The reference model should have stored a Data M2S in the FIFO
               refM2SDataEventLocal = refDataM2SQ.pop_back();
               chkM2SData (refM2SDataEventLocal, dutM2SDataEventLocal, "Data",VERBOSE);
               
            end // if (StoreInst || LoadInst)

         ////////////////////////////////////////////////////////////////////
         // INST : Check the M2S predicted by the model matches DUT
         //

         // Now the CPU model has been called, there should be a predicted Inst
         // M2S in the Inst FIFO
         refM2SInstEventLocal = refInstM2SQ.pop_back();

         chkM2SData (refM2SInstEventLocal, dutM2SInstEventLocal, "Inst",VERBOSE);

         end // while (modelTraceActive)
      end // block: CORE_INST_DATA_CHECK
   
         

   

   /////////////////////////////////////////////////////////////////////////////
   // CHECKER : Register writes
   //
   initial
      begin : CORE_REG_CHECK

         regWriteEvent refRegWriteEventLocal;
         regWriteEvent dutRegWriteEventLocal;

         // Wait for reset to de-assert
         while (1'b0 !== `MON_RST_SYNC)
            @(posedge `MON_CLK);

         // Main test loop
         while (modelTraceActive)
         begin

            // Wait for a REF register write to be in FIFO
            while (refRegQ.size() == 0)
               @(posedge `MON_CLK);

            // Wait for the corresponding DUT register write
            while (dutRegQ.size() == 0)
               @(posedge `MON_CLK);

            // Pop the two values out to compare
            refRegWriteEventLocal = refRegQ.pop_back();
            dutRegWriteEventLocal = dutRegQ.pop_back();
            
            // Compare the two register writes
            // Check the M2S from the ref and DUT match
            if (refRegWriteEventLocal == dutRegWriteEventLocal)
            begin
               if (VERBOSE > 0) $display("[INFO ] CPU REG Write Match at time %t", $time);
            end
            else
            begin
	       $display("[ERROR] CPU REGS Write Mismatch at time %t", $time);
	       $display("[ERROR] -> regIndex  Expected 0x%x, Actual 0x%x"
                        , refRegWriteEventLocal.regIndex   
                        , dutRegWriteEventLocal.regIndex   );
	       $display("[ERROR] -> regValue  Expected 0x%x, Actual 0x%x"
                        , refRegWriteEventLocal.regValue   
                        , dutRegWriteEventLocal.regValue   );

//               // Put the expected register access back in the FIFO in case it
//               // matches a later transaction
//               if (VERBOSE) $display("[DEBUG] -> Putting reference element back into REF FIFO");
//               refRegQ.push_back(refRegWriteEventLocal);
	    end
         end
      end

   // Check the LO register writes
   initial
      begin : CORE_LO_REG_CHECK

         int refLoVal;
         int dutLoVal;

         // Wait for reset to de-assert
         while (1'b0 !== `MON_RST_SYNC)
            @(posedge `MON_CLK);

         // Main test loop
         while (modelTraceActive)
         begin

            // Wait for a REF register write to be in FIFO
            while (refLoQ.size() == 0)
               @(posedge `MON_CLK);

            // Wait for the corresponding DUT register write
            while (dutLoQ.size() == 0)
               @(posedge `MON_CLK);

            // Pop the two values out to compare
            refLoVal = refLoQ.pop_back();
            dutLoVal = dutLoQ.pop_back();
            
            // Compare the two register writes
            // Check the M2S from the ref and DUT match
            if (refLoVal == dutLoVal)
            begin
               $display("[INFO ] CPU LO REG Write Match at time %t", $time);
            end
            else
            begin
	       $display("[ERROR] CPU LO REG Write Mismatch at time %t", $time);
	       if (VERBOSE) $display("[DEBUG] -> Expected 0x%x, Actual 0x%x"
                        , refLoVal
                        , dutLoVal );
	    end
         end
      end

   // Check the HI register writes
   initial
      begin : CORE_HI_REG_CHECK

         int refHiVal;
         int dutHiVal;

         // Wait for reset to de-assert
         while (1'b0 !== `MON_RST_SYNC)
            @(posedge `MON_CLK);

         // Main test hiop
         while (modelTraceActive)
         begin

            // Wait for a REF register write to be in FIFO
            while (refHiQ.size() == 0)
               @(posedge `MON_CLK);

            // Wait for the corresponding DUT register write
            while (dutHiQ.size() == 0)
               @(posedge `MON_CLK);

            // Pop the two values out to compare
            refHiVal = refHiQ.pop_back();
            dutHiVal = dutHiQ.pop_back();
            
            // Compare the two register writes
            // Check the M2S from the ref and DUT match
            if (refHiVal == dutHiVal)
            begin
               $display("[INFO ] CPU HI REG Write Match at time %t", $time);
            end
            else
            begin
	       $display("[ERROR] CPU HI REG Write Mismatch at time %t", $time);
	       if (VERBOSE) $display("[DEBUG] -> Expected 0x%x, Actual 0x%x"
                        , refHiVal
                        , dutHiVal );
	    end
         end
      end

endmodule
/*****************************************************************************/




















