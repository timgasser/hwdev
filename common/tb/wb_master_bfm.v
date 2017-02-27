/* INSERT MODULE HEADER */


/*****************************************************************************/

// Updated the Master to use pipelined accesses
module WB_MASTER_BFM
   (
    input  CLK                   ,
    input  RST_SYNC              ,
   
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
    output [31:0] WB_DAT_WR_OUT    // Master: Write data
    
    
    );

`include "wb_defs.v"

   reg [31:0] WbAdr               ; // WB_ADR_OUT  
   reg        WbCyc               ; // WB_CYC_OUT  
   reg        WbStb               ; // WB_STB_OUT  
   reg        WbWe                ; // WB_WE_OUT
   reg [ 3:0] WbSel               ; // WB_SEL_OUT  
   reg [ 2:0] WbCti               ; // WB_CTI_OUT
   reg [ 1:0] WbBte               ; // WB_BTE_OUT
   
   reg [31:0] WbDatWr             ; // WB_DAT_WR_OUT

   reg        resetDone;
   int unsigned  clkCount = 0;
   
   assign WB_ADR_OUT      = WbAdr     ;
   assign WB_CYC_OUT      = WbCyc     ;
   assign WB_STB_OUT      = WbStb     ;
   assign WB_WE_OUT       = WbWe      ;
   assign WB_SEL_OUT      = WbSel     ;
   assign WB_CTI_OUT      = WbCti     ;
   assign WB_BTE_OUT      = WbBte     ;

   assign WB_DAT_WR_OUT   = WbDatWr   ;
   
   // Don't start any reads or writes until the reset has been released
initial
   begin
      resetDone = 1'b0;
      while (RST_SYNC)
	 @(posedge CLK);
      resetDone = 1'b1;
   end // initial begin
	   
   // Clock counter (wraps) to time the burst transactions
   always @(posedge CLK)
   begin
      if (!RST_SYNC)
      begin
         clkCount <= clkCount + 1;
      end
   end
   
   initial
      begin : zero_outputs
         WbAdr      = 32'h0000_0000;
         WbCyc      = 1'b0;
         WbStb      = 1'b0;
         WbWe       = 1'b0;
         WbSel      = 4'h0;
         WbCti      = 3'b000;
         WbBte      = 2'b00;
         WbDatWr    = 32'h0000_0000;
      end

   // Wrapper to write a single byte
   task automatic wbWriteByte
      (
       input [31:0] Addr,
       input [ 7:0] DataByte
       );
      begin
         case (Addr[1:0])
           2'b00 : wbWrite({Addr[31:2], 2'b00}, 4'b0001, {24'h00_0000, DataByte     });
           2'b01 : wbWrite({Addr[31:2], 2'b00}, 4'b0010, {16'h0000, DataByte, 8'h00 });
           2'b10 : wbWrite({Addr[31:2], 2'b00}, 4'b0100, {8'h00, DataByte, 16'h0000 });
           2'b11 : wbWrite({Addr[31:2], 2'b00}, 4'b1000, {DataByte, 24'h00_0000     });
         endcase // case (Addr[1:0])
      end
   endtask 
   
   // Wrapper to write a a halfword
   task automatic wbWriteHalf
      (
       input [31:0] Addr,
       input [15:0] DataHalf
       );
      begin
         case (Addr[1])
           1'b0 : wbWrite({Addr[31:2], 2'b00}, 4'b0011, {16'h0000, DataHalf });
           1'b1 : wbWrite({Addr[31:2], 2'b00}, 4'b1100, {DataHalf, 16'h0000 });
         endcase // case (Addr[1:0])
      end
   endtask 
   

   // Can't consolidate the single read and write access tasks into a burst-of-one below, as the burst
   // always assumes a 32-bit access, and doesnt' use the Sel input
   task automatic wbWrite
      (
       input [31:0] Addr,
       input [ 3:0] Sel,
       input [31:0] Data
       );
      begin

         int unsigned startClk = 0;
         int unsigned endClk = 0;

         wait (resetDone);

         if (| Addr[1:0])
         begin
            $display("[ERROR] WRITE: Addr = 0x%h, Unaligned access. Time = %d", Addr, $realtime);
         end

         $display("[INFO ] WRITE: Beginning transaction at time %4t", $realtime);
         // Begin transaction by asserting master signals
         WbCyc    <= 1'b1;
         WbStb    <= 1'b1;
         WbAdr    <= Addr;
         WbSel    <= Sel;
         WbWe     <= 1'b1;
         WbDatWr  <= Data;
	 @(posedge CLK);

         startClk = clkCount; // Start counting from the first bus request cycle, not when it's granted

         // Wait until the STALL is de-asserted 
         while (WB_STALL_IN) @(posedge CLK);

//         $display("[DEBUG] SINGLE WRITE: Addr = 0x%x, Sel = 0x%x, Data = 0x%x accepted at time %4t", Addr, Sel, Data, $time);
         // Zero all the master signals, they should have been registered.
         WbStb    <= 1'b0;
         WbAdr    <= 32'h0000_0000;
         WbSel    <= 4'b0000;
         WbWe     <= 1'b0;
         WbDatWr  <= 32'h0000_0000;

	 // Need to wait at least a cycle for the corresponding ACK or ERROR
	 @(posedge CLK);
         while (!(WB_ACK_IN || WB_ERR_IN)) @(posedge CLK);
         endClk = clkCount;
         if (WB_ACK_IN)
         begin
            $display("[INFO ] SINGLE WRITE: Addr = 0x%x, Sel = 0x%x, Data = 0x%x. Latency = %3d CLKs at time %4t", Addr, Sel, Data, (endClk - startClk-1), $time);     
            //       $display("[INFO ] SINGLE WRITE: Addr = 0x%h, Sel = 0x%h, Data = 0x%h, Time = %d", Addr, Sel, Data, $realtime);
         end
         else if (WB_ERR_IN)
         begin
            $display("[ERROR] SINGLE WRITE: Failed - Addr = 0x%x, Sel = 0x%x, Data = 0x%x. Latency = %3d CLKs at time %4t", Addr, Sel, Data, (endClk - startClk-1), $time);     
            //       $display("[ERROR] SINGLE WRITE: Addr = 0x%h, Sel = 0x%h, Data = 0x%h, Time = %d", Addr, Sel, Data, $realtime);
         end

         WbCyc    <= 1'b0;
         WbSel    <= 4'h0;
         WbWe     <= 1'b0;
      end
   endtask // wbWriteAccess


   task automatic wbReadCompareByte
      (
       input [31:0] Addr,
       input [ 7:0] ExpDataByte
       );
      begin
         case (Addr[1:0])
           2'b00 : wbReadCompare({Addr[31:2], 2'b00}, 4'b0001, {24'h00_0000, ExpDataByte     });
           2'b01 : wbReadCompare({Addr[31:2], 2'b00}, 4'b0010, {16'h0000, ExpDataByte, 8'h00 });
           2'b10 : wbReadCompare({Addr[31:2], 2'b00}, 4'b0100, {8'h00, ExpDataByte, 16'h0000 });
           2'b11 : wbReadCompare({Addr[31:2], 2'b00}, 4'b1000, {ExpDataByte, 24'h00_0000     });
         endcase // case (Addr[1:0])
      end
   endtask // wbReadCompareByte
   

   // Can't consolidate the single read and write access tasks into a burst-of-one below, as the burst
   // always assumes a 32-bit access, and doesnt' use the Sel input
   task automatic wbRead
      (
       input  [31:0] Addr,
       input  [ 3:0] Sel,
       output [31:0] ReadData
       );

     
      begin

         int unsigned startClk = 0;
         int unsigned endClk = 0;
         
         wait (resetDone);

         if (| Addr[1:0])
         begin
            $display("[ERROR] WRITE: Addr = 0x%h, Unaligned access. Time = %d", Addr, $realtime);
         end

         ReadData = 0;
          
         $display("[INFO ] READ: Requesting bus at time %4t", $realtime);
         // Begin transaction by asserting master signals for one cycle
         WbCyc    <= 1'b1;
         WbStb    <= 1'b1;
         WbAdr    <= Addr;
         WbSel    <= Sel;
         WbWe     <= 1'b0;
	 @(posedge CLK);
         startClk = clkCount;
	 
         // Wait until the STALL is de-asserted 
         while (WB_STALL_IN) @(posedge CLK);
//       $display("[INFO ] SINGLE READ: Address 0x%x, Sel = 0x%x accepted at time %4t", Addr, Sel, $realtime);

         WbStb   <= 1'b0;
         WbAdr   <= 32'h0000_0000;
         WbSel   <= 4'b0000;
         WbWe    <= 1'b0;

     	 // Need to wait at least a cycle for the corresponding ACK or ERR
	 @(posedge CLK);
	 while (!(WB_ACK_IN || WB_ERR_IN)) @(posedge CLK);
         endClk = clkCount;
         if (WB_ACK_IN)
         begin
            ReadData = WB_DAT_RD_IN;
            $display("[INFO ] SINGLE READ : Addr = 0x%x, Sel = 0x%x, Data = 0x%x. Latency = %3d CLKs at time %4t", Addr, Sel, ReadData, (endClk - startClk-1), $time);
            //       $display("[INFO ] SINGLE READ: Data ACK = 0x%x at time %4t", WB_DAT_RD_IN, $realtime);
         end
         else if (WB_ERR_IN)
         begin
            ReadData = 32'hxxxx_xxxx;
            $display("[ERROR] SINGLE READ : Failed - Addr = 0x%x, Sel = 0x%x, Data = 0x%x. Latency = %3d CLKs at time %4t", Addr, Sel, ReadData, (endClk - startClk-1), $time);
            //       $display("[INFO ] SINGLE READ: Data ACK = 0x%x at time %4t", WB_DAT_RD_IN, $realtime);
         end

         WbCyc  <= 1'b0; // Keep the CYC high until the ACK or ERR comes back
      end
   endtask
 

   task automatic wbReadCompare
      (
       input [31:0] Addr,
       input [ 3:0] Sel,
       input [31:0] ExpData
       );

      reg [31:0]    ReadData;

      reg [31:0]    ReadDataMasked;
      reg [31:0]    ExpDataMasked;
      
      
      begin

         wait (resetDone);

         if (| Addr[1:0])
         begin
            $display("[ERROR] WRITE: Addr = 0x%h, Unaligned access. Time = %d", Addr, $realtime);
         end
            
         // Begin transaction by asserting master signals for one cycle
	 WbCyc    <= 1'b1;
         WbStb    <= 1'b1;
         WbAdr    <= Addr;
         WbSel    <= Sel;
         WbWe     <= 1'b0;
         @(posedge CLK);

         // Wait until the STALL is de-asserted 
         while (WB_STALL_IN) @(posedge CLK);
         
         $display("[INFO ] WB Read Address and Data accepted at time %4t", $time);
         // Zero all the master signals, they should have been registered.
         WbStb    <= 1'b0;
         WbAdr    <= 32'h0000_0000;

         while (!(WB_ACK_IN || WB_ERR_IN)) @(posedge CLK);
         $display("[INFO ] WB Read Data ready  at time %4t", $time);      

         if (WB_ACK_IN)
         begin
            ReadData = WB_DAT_RD_IN;

            ReadDataMasked[31:24] = Sel[3] ? ReadData[31:24] : 8'h00;
            ReadDataMasked[23:16] = Sel[2] ? ReadData[23:16] : 8'h00;
            ReadDataMasked[15: 8] = Sel[1] ? ReadData[15: 8] : 8'h00;
            ReadDataMasked[ 7: 0] = Sel[0] ? ReadData[ 7: 0] : 8'h00;
            
            ExpDataMasked [31:24] = Sel[3] ? ExpData[31:24]  : 8'h00;
            ExpDataMasked [23:16] = Sel[2] ? ExpData[23:16]  : 8'h00;
            ExpDataMasked [15: 8] = Sel[1] ? ExpData[15: 8]  : 8'h00;
            ExpDataMasked [ 7: 0] = Sel[0] ? ExpData[ 7: 0]  : 8'h00;

            //       $display("[DEBUG] Sel is 0x%h", Sel);
            //       $display("[DEBUG] ReadData is 0x%h", ReadData);
            //       $display("[DEBUG] ExpData  is 0x%h", ExpData);
            //       $display("[DEBUG] ReadDataMasked is 0x%h", ReadDataMasked);
            //       $display("[DEBUG] ExpDataMasked  is 0x%h", ExpDataMasked);
            
         end
         else if (WB_ERR_IN)
         begin
            $display("[ERROR] WB Read Failed - at time %4t", $time);      
            ReadData = WB_DAT_RD_IN; // Make sure the comparison fails
            ExpDataMasked = ~ WB_DAT_RD_IN;
         end
            
         if (ReadDataMasked !== ExpDataMasked)
         begin
            $display("[ERROR] READ : Addr = 0x%h, Sel = 0x%h, Read Data = 0x%h, Expected Data = 0x%h, Time = %d", Addr, Sel, ReadData, ExpData, $realtime);
            $display("[ERROR]        Masked Read Data is 0x%h, Masked Expected Data is 0x%h", ReadDataMasked, ExpDataMasked);
         end
         else
         begin
            $display("[INFO ] READ : Addr = 0x%h, Sel = 0x%h, Read Data = 0x%h, Expected Data = 0x%h, Time = %d", Addr, Sel, ReadData, ExpData, $realtime);
         end
         
         WbCyc    <= 1'b0;
         WbStb    <= 1'b0;
         WbAdr    <= 32'h0000_0000;
         WbSel    <= 4'h0;
         WbWe     <= 1'b0;

      end
      
   endtask // wbWriteAccess


     task automatic wbBurstWrite32b
      (
       input int   Addr [],
       input int   WriteData []
       );

        int burstBeatNum;
//      int burstBeatLoop;

        // Counters to track the start and end times of a burst beat
        int unsigned startClk [] ;
        int unsigned endClk   [] ;

	int unsigned addrCount = 0; // incremented by address phase, 
	int unsigned dataCount = 0; // incremented by data phase, 
	
        // Check the size of the burst by reading address array size
        burstBeatNum = Addr.size();

        // Create arrays to store the start and end clock counts
        startClk = new[burstBeatNum]; // Need to create the necessary elements in the read array
        endClk   = new[burstBeatNum]; // Need to create the necessary elements in the read array
        
        $display("[INFO ] BURST WRITE: Burst starting at 0x%x, length %02d at time %4t", Addr[0], burstBeatNum, $realtime);
        // CYC must be asserted from the first STB with Address + Data to the last ACK
        WbCyc   <= 1'b1;

        // Fork separate processes for address and data in the burst
        fork
           begin : ADDR_ISSUE
              foreach (Addr[i])
                 begin
                    if (| Addr[i][1:0])
                    begin
                       $display("[ERROR] BURST WRITE: Addr = 0x%h, Unaligned access. Time = %d", Addr[i], $realtime);
                    end
                    // Begin transaction by asserting master signals for one cycle
                    WbStb   <= 1'b1;
                    WbAdr   <= Addr[i];
                    WbSel   <= 4'b1111;
                    WbWe    <= 1'b1;
                    WbDatWr <= WriteData[i];
                    @(posedge CLK);
                    startClk[i] = clkCount;
                    // Wait until the STALL is de-asserted 
                    while (WB_STALL_IN) @(posedge CLK);
		    addrCount++;
                    $display("[INFO ] BURST WRITE: Address 0x%x (%3d of %3d), Data 0x%x accepted at time %4t", Addr[i], addrCount, burstBeatNum, WriteData[i], $realtime);
                 end
//              WbCyc   = 1'b0; <- Can't de-assert CYC until all the data threads complete
              WbStb   <= 1'b0;
              WbAdr   <= 32'h0000_0000;
              WbSel   <= 4'b0000;
              WbWe    <= 1'b0;
              WbDatWr <= 32'h0000_0000;
           end // block: ADDR_ISSUE
           
           begin : DATA_ACK
              foreach (Addr[i])
                 begin
                    while (!((WB_ACK_IN || WB_ERR_IN) && (addrCount > i))) @(posedge CLK);
                    endClk[i] = clkCount;
		    dataCount++;
                    if (WB_ACK_IN)
                    begin
		       $display("[INFO ] BURST WRITE: Address 0x%x , Data 0x%x ACK seen (%3d of %3d). Latency = %3d at time %4t", 
                                Addr[i], WriteData[i], dataCount, burstBeatNum, (endClk[i] - startClk[i]-1), $realtime);
                    end
                    else if (WB_ERR_IN)
                    begin
                       $display("[ERROR] BURST WRITE: Failed - Address 0x%x , Data 0x%x ERR seen (%3d of %3d). Latency = %3d at time %4t", 
                                Addr[i], WriteData[i], dataCount, burstBeatNum, (endClk[i] - startClk[i]-1), $realtime);
                    end

                    // If there are more accesses to be ACKed, wait for another cycle before looping
                    if (dataCount < burstBeatNum) @(posedge CLK);
                 end
           end
           
        join
        
        $display("[INFO ] BURST WRITE: Completed at time %4t", $realtime);
        WbCyc   <= 1'b0;

     endtask
 
      task automatic wbBurstRead32b
      (
       input  int   Addr [],
       output int   ReadData []
       );

         int        burstBeatNum;
//       int        burstBeatLoop;
         
         // Counters to track the start and end times of a burst beat
         int        unsigned startClk [] ;
         int        unsigned endClk   [] ;

	 int 	    unsigned addrCount = 0; // incremented by address phase, 
	 int 	    unsigned dataCount = 0; // incremented by data phase, 

         burstBeatNum = Addr.size();
         ReadData = new[burstBeatNum]; // Need to create the necessary elements in the read array
         startClk = new[burstBeatNum]; // Need to create the necessary elements in the read array
         endClk   = new[burstBeatNum]; // Need to create the necessary elements in the read array
         
	 $display("[INFO ] BURST READ: Burst starting at 0x%x, length %02d at time %4t", Addr[0], burstBeatNum, $realtime);		    
	 // CYC must be asserted from the first STB with Address + Data to the last ACK
	 WbCyc   <= 1'b1;
         WbDatWr <= 32'h0000_0000;

        fork
           begin : ADDR_ISSUE
              foreach (Addr[i])
                 begin
                    if (| Addr[i][1:0])
                    begin
                       $display("[ERROR] BURST READ: Addr = 0x%h, Unaligned access. Time = %d", Addr[i], $realtime);
                    end

		    // Begin transaction by asserting master signals for one cycle
                    WbStb   <= 1'b1;
                    WbAdr   <= Addr[i];
                    WbSel   <= 4'b1111;
                    WbWe    <= 1'b0;
//                  WbDatWr = WriteData[i];
		    @(posedge CLK);
                    startClk[i] = clkCount;
                    // Wait until the STALL is de-asserted 
                    while (WB_STALL_IN) @(posedge CLK);
		    addrCount++;
		    $display("[INFO ] BURST READ: Address 0x%x (%3d of %3d) accepted at time %4t", Addr[i], addrCount, burstBeatNum, $realtime);
                 end
//              WbCyc   = 1'b0; <- Can't de-assert CYC until all the data threads complete
              WbStb   <= 1'b0;
              WbAdr   <= 32'h0000_0000;
              WbSel   <= 4'b0000;
              WbWe    <= 1'b0;
//            WbDatWr = 32'h0000_0000;

           end // block: ADDR_ISSUE
           
           begin : DATA_ACK
              foreach (Addr[i])
                 begin
                    while (!((WB_ACK_IN  || WB_ERR_IN) && (addrCount > i))) @(posedge CLK);
                    endClk[i] = clkCount;
		    dataCount++;
                    if (WB_ACK_IN)
                    begin
		       $display("[INFO ] BURST READ: Address 0x%x , Data = 0x%x  (%3d of %3d). Latency = %3d CLKs at time %4t", 
                                Addr[i], WB_DAT_RD_IN, dataCount, burstBeatNum, (endClk[i] - startClk[i]-1), $realtime);
                       ReadData[i] = WB_DAT_RD_IN;
                    end
                    else if (WB_ERR_IN)
                    begin
		       $display("[ERROR] BURST READ: Failed - Address 0x%x , Data = 0x%x  (%3d of %3d). Latency = %3d CLKs at time %4t", 
                                Addr[i], WB_DAT_RD_IN, dataCount, burstBeatNum, (endClk[i] - startClk[i]-1), $realtime);
                       ReadData[i] = 32'hxxxx_xxxx;
                    end

		    // If there are more accesses to be ACKed, wait for another cycle before looping
                    if (dataCount < burstBeatNum) @(posedge CLK);
                 end
           end
           
        join

         $display("[INFO ] BURST READ: Completed at time %4t", $realtime);
	 WbCyc   <= 1'b0;

     endtask
   
   // This task takes the SRAM base address and size. 
   // It then alternates overlapping writes and reads to check the entire RAM space
   task automatic wbOverlapWriteVerify
      (
       input  int   RamBaseAddr ,
       input  int   RamSizeByte ,
       output int   TestPass
       );
      
      begin

	 int AddrLoop;
	 int WriteData;
	 int expReadData;
	 int expReadAddr;

	 int DataQ [$];
	 
	 // Sync to the clock first
	 @(posedge CLK);

	 TestPass = 1;
	 
	 fork
	    begin : ADDR_PHASE
	       
	       // Keep feeding in writes and reads in back to back address phases
	       for (AddrLoop = RamBaseAddr ; AddrLoop < (RamBaseAddr + RamSizeByte) ; AddrLoop = AddrLoop + 4)
	       begin

		  // Randomise the write data, and store it in the expected read data variable
		  WriteData   = $urandom();
		  
		  // Write Address phase - assert the transaction for a clock cycle
		  WbCyc   <= 1'b1;
		  WbStb   <= 1'b1;
		  WbWe    <= 1'b1;
		  WbSel   <= 4'b1111;
		  WbAdr   <= AddrLoop;
		  WbDatWr <= WriteData;
		  @(posedge CLK);

		  // Wait until the write is accepted
		  while (WB_STALL_IN)
		     @(posedge CLK);
		  DataQ.push_front(WriteData);
		  $display("[DEBUG] SRAM Write Accepted. Addr = 0x%x, Sel = 0b%b, Write Data = 0x%x", AddrLoop, 4'b1111, WriteData);
		  
		  // Read Address phase - assert the transaction for a clock cycle
		  WbCyc   <= 1'b1;
		  WbStb   <= 1'b1;
		  WbWe    <= 1'b0;
		  WbSel   <= 4'b1111;
		  WbAdr   <= AddrLoop;
		  WbDatWr <= 32'h0000_0000;
		  @(posedge CLK);

		  // Wait until the read is accepted
		  while (WB_STALL_IN)
		     @(posedge CLK);
		  $display("[DEBUG] SRAM Read Accepted. Addr = 0x%x, Sel = 0b%b, ", AddrLoop, 4'b1111);

	       end // for (AddrLoop = RamBaseAddr ; AddrLoop < (RamBaseAddr + RamSize) ; AddrLoop = AddrLoop + 4)

	    end
   
	    begin : RD_DATA_PHASE

	       // Wait until the address phase of the read transaction
	       while (!(WbCyc && WbStb && !WbWe && !WB_STALL_IN))
		  @(posedge CLK);

	       // Wait 1 cycle to check the read data.
	       @(posedge CLK);

	       expReadData = DataQ.pop_back();
	       
	       if (expReadData != WB_DAT_RD_IN)
	       begin
		  $display("[ERROR] Read Data Mismatch at Addr = 0x%x, Expected = 0x%x, Read = 0x%x", expReadAddr, expReadData, WB_DAT_RD_IN );
		  TestPass = 0;
	       end
	       else
	       begin
//		  $display("[DEBUG] Read Data Match ! Addr = 0x%x, Expected = 0x%x, Read = 0x%x", expReadAddr, expReadData, WB_DAT_RD_IN );

	       end
	       
	       
	    end
	    
	 join

	 WbStb   <= 1'b0;
	 
	 // Wait until after the last ACK before de-asserting STB and CYC
	 while (WB_ACK_IN)
	    @(posedge CLK);
         
	 WbCyc   <= 1'b0;
	 WbWe    <= 1'b0;
	 WbSel   <= 4'b0000;
	 WbAdr   <= 32'h0000_0000;
	 WbDatWr <= 32'h0000_0000;

      end

endtask
   

   

   
endmodule
