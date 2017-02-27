/* INSERT MODULE HEADER */


/*****************************************************************************/

module WB_SLAVE_BFM
   #(parameter VERBOSE     = 0,
     parameter READ_ONLY   = 0,
     parameter MEM_BASE    = 32'h0000_0000 ,
     parameter MEM_SIZE_P2 = 16,
     parameter MAX_LATENCY = 1 , // Maximum cycles of latency for STALL and ACK
     parameter MIN_LATENCY = 0 , // Minimum cycles of latency for STALL and ACK
     parameter ADDR_LIMIT  = 1  // Maximum amount of addresses that can be accepted before data completes.
                                 // If this is an AHB-like BFM, it can never have more than one address in flight
                                 // for this case, STAL, = ~ACK, and the ACK is basically HREADY
     )
   (
    input  CLK                   ,
    input  RST_SYNC              ,
   
    // Wishbone interface
    input      [31:0] WB_ADR_IN      , // Master: Address of current transfer
    input             WB_CYC_IN      , // Master: High while whole transfer is in progress
    input             WB_STB_IN      , // Master: High while the current beat in burst is active
    input             WB_WE_IN       , // Master: Write Enable (1), Read if 0
    input      [ 3:0] WB_SEL_IN      , // Master: Byte enables of write (one-hot)
    input      [ 2:0] WB_CTI_IN      , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    input      [ 1:0] WB_BTE_IN      , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap
    output reg        WB_STALL_OUT   , // Slave : Not ready to accept new address
    output reg        WB_ACK_OUT     , // Slave:  Acknowledge of transaction
    output reg        WB_ERR_OUT     , // Slave:  Transaction caused error
    output reg [31:0] WB_DAT_RD_OUT  , // Slave:  Read data
    input      [31:0] WB_DAT_WR_IN     // Master: Write data
   
    );

   // Include the definitions of BTE and CTI   
`include "wb_defs.v"
   
   reg [ 7:0] 	      MemArray [(2 ** MEM_SIZE_P2) - 1:0];
   wire [31:0] 	      ArrayAddr    =  WB_ADR_IN - MEM_BASE;
   wire [31:0] 	      ArrayAddr32b = {ArrayAddr[31:2], 2'b00};

   int 		      ByteLoop;
   int 		      AddrCnt;

   // FIFOs used to communicate between the parallel Address and Data threads
   int 		      AddrQ      [$:ADDR_LIMIT]   ; // Queue of Addresses. Push on CYC+STB and no STALL in Address thread. Pop when ACK returned in Data thread.
   bit [3:0] 	      SelQ       [$:ADDR_LIMIT]   ; // Queue of SELs for writes
   int                TransRwbQ  [$:ADDR_LIMIT]   ; // Queue of read (1) or write (0) transaction type ints. Pushed by address thread, popped in Data thread.
   int 		      WriteDataQ [$:ADDR_LIMIT]	  ; // Queue of Write Data. Push on CYC+STB+WE and no stall in Address thread. Pop when ACK returned addresses stored

   int 		      AddrLatency      ; // 
   int 		      DataLatency      ;

   //   int 		      ReadAddrReg;
   
   // Decode when addresses, and read / write data are valid
   wire 	      WbAddrStb    = WB_CYC_IN & WB_STB_IN & ~WB_STALL_OUT;
//   wire 	      WbWrAddrStb  = WB_CYC_IN & WB_STB_IN & ~WB_STALL_OUT & WB_WE_IN;
//   wire 	      WbRdAddrStb  = WB_CYC_IN & WB_STB_IN & ~WB_STALL_OUT & ~WB_WE_IN;
//   wire 	      WbWrDataStb  = WB_CYC_IN & WB_STB_IN & ~WB_STALL_OUT & WB_WE_IN;
//   wire 	      WbRdDataStb  = WB_CYC_IN & WB_ACK_OUT;
   
   // Zero the outputs from Slave to Master
   initial
      begin : output_zero
         WB_STALL_OUT   = 1'b0;
         WB_ACK_OUT     = 1'b0;
         WB_ERR_OUT     = 1'b0;
         WB_DAT_RD_OUT  = 32'h0000_0000;
      end 

   // The pseudocode for the two process is below:

   // Generate a random length stall for each access. 

   // This works as follows:
   //
   // ADDR Phase (pushes into the FIFOs):
   // - Waits for an Address strobe (on the negedge of the clock). Use the negedge of the clock for
   //   this process as it is only used internally, ACK/STALL are sent out on posedge CLK by DATA thread.
   //   => Once an Address strobe is seen push the AddrQ, SelQ, TransRwbQ, and WriteDataQ if necessary
   // 
   // DATA Phase (pops from the FIFOs)
   // - Waits for the AddrQ size to be non-zero (on posedge of clock)
   //   => Randomises latency between 0 and the MAX_LATENCY limit
   // - Wait for latency on negedge of clock (STALL <= 1, ACK <= 0)
   // - Set STALL = 0, ACK = 1 for a clock cycle
      
      
   
   initial 
      begin

	 // Wait for the reset to be de-asserted
	 while (RST_SYNC !== 1'b0)
	    @(posedge CLK);
	 if (VERBOSE) $display("[DEBUG] %m : Reset de-asserted at time %4t", $time);
	 
	 fork
	    
	    begin : ADDR_PHASE

	       forever
		  begin 
		     // Wait until an address strobe comes in. Can't do a clocked wait unless it's negedge as
		     // you need to assert the STALL in the same cycle the first CYC+STB arrives.
		     while  (!WbAddrStb)
			@(negedge CLK);
		     if (2 == VERBOSE) $display("[DEBUG] %m : Address strobe seen on negedge at time %4t", $time);

//		     // First of all, wait until the address fifo is less than the address limit. 
//		     // Addresses are pushed by the address thread, and popped by the data thread when data read / written
//		     // Only set the WB_STALL in the addr limit and addr latency processes to avoid glitches
//		     if (AddrQ.size() >= ADDR_LIMIT) 
//		     begin
//			if (VERBOSE) $display("[DEBUG] %m : Maximum Address limit of %2d reached at time %4t", ADDR_LIMIT, $time);
//			WB_STALL_OUT <= 1'b1;
//			while (AddrQ.size() >= MAX_LATENCY)	       
//			   @(posedge CLK);
// //			WB_STALL_OUT <= 1'b0;
//		     end
//
//		     // A new address has been sent, randomise latency and wait until putting it into queue
//		     AddrLatency = $urandom_range(0,MAX_LATENCY);
//		     if (VERBOSE) $display("[DEBUG] %m : Inserting latency of %2d cycles for Address at time %4t", AddrLatency, $time);
//		     if (0 != AddrLatency)
//		     begin
//			WB_STALL_OUT <= 1'b1;
//			repeat (AddrLatency)
//			   @(negedge CLK);
//		     end
//		     WB_STALL_OUT <= 1'b0;
//

		     // Store the Address phase signals into fifos immediately. The DATA phase randomises the ACK latency
		     AddrQ.push_front(ArrayAddr); // Use address with base subtracted ! 
		     SelQ.push_front(WB_SEL_IN);
		     TransRwbQ.push_front(~WB_WE_IN);
		     if (WB_WE_IN) WriteDataQ.push_front(WB_DAT_WR_IN);
//		     if (VERBOSE) $display("[DEBUG] %m : De-asserting STALL, storing Addr = 0x%x, Sel = 0b%b, Rwb = 0b%b, Write Data = 0x%x at time %4t", WB_ADR_IN, WB_SEL_IN, ~WB_WE_IN, WB_DAT_WR_IN, $time);

		     // Wait for another clock before checking the strobes, etc again
		     @(negedge CLK);
		     
		  end
	    end
	    
	    begin : DATA_PHASE

	       forever 
		  begin

		     int       dataPhaseAddr ; // popped from AddrQ
		     bit [3:0] dataPhaseSel  ; // popped from SelQ
		     int       dataPhaseRwb  ; // popped from TransRwbQ
		     int       dataPhaseWriteData  ; // popped from TransRwbQ

		     logic [31:0] WbReadData;
		     
		     // Wait until there is an address in the FIFO from the address phase thread
		     while (0 == AddrQ.size())
			@(posedge CLK);
		     if (2 == VERBOSE) $display("[DEBUG] %m : Address Queue has entry at time %4t", $time);

		     // Store the FIFO contents into local variables
		     dataPhaseAddr = AddrQ.pop_back();
		     dataPhaseSel  = SelQ.pop_back();
		     dataPhaseRwb  = TransRwbQ.pop_back();
		     if (!dataPhaseRwb) dataPhaseWriteData = WriteDataQ.pop_back();
		     if (2 == VERBOSE) $display("[DEBUG] %m : Queues contain : Addr = 0x%x, Sel = 0x%x, Rwb = %1d, Write Data (only valid for writes) = 0x%x at time %4t", dataPhaseAddr, dataPhaseSel, dataPhaseRwb, dataPhaseWriteData, $time);

		     // --- Check to see if it's a valid transaction .. If not send an ERR response on next cycle ---
		     // Check for an unaligned access
		     if (dataPhaseAddr[1:0] != 2'b00)
		     begin
			$display("[ERROR] %m : Unaligned address 0x%x at time %4t", dataPhaseAddr, $time);
			WB_ERR_OUT <= 1'b1;
			@(posedge CLK);
			WB_ERR_OUT <= 1'b0;
			// $stop();
		     end
		     
		     // Check for an access out of the range of the WB Slave
		     else if (dataPhaseAddr >= MEM_BASE + (2 ** MEM_SIZE_P2))
		     begin
			$display("[ERROR] %m : Address 0x%x out of range of 0x%x to 0x%x at time %4t", dataPhaseAddr, MEM_BASE, MEM_BASE + (2 ** MEM_SIZE_P2), $time);
			WB_ERR_OUT <= 1'b1;
			@(posedge CLK);
			WB_ERR_OUT <= 1'b0;
			// $stop();
		     end

		     // Check for invalid SEL byte lane selects
		     else if (! (   (4'b1111 == dataPhaseSel)
				 || (4'b0011 == dataPhaseSel)
				 || (4'b1100 == dataPhaseSel)
				 || (4'b0001 == dataPhaseSel)
				 || (4'b0010 == dataPhaseSel)
				 || (4'b0100 == dataPhaseSel)
				 || (4'b1000 == dataPhaseSel)
				    ))
		     begin
			$display("[ERROR] %m : Invalid WB_SEL_IN = %04b at time %4t", dataPhaseSel, $time);
			WB_ERR_OUT <= 1'b1;
			@(posedge CLK);
			WB_ERR_OUT <= 1'b0;
		     end
		     
		     // If it gets to here, the transaction is ok to go through
		     else
		     begin
		     
			// Now wait for a random amount of cycles before ACKing 
			DataLatency = $urandom_range(MIN_LATENCY, MAX_LATENCY);
			if (2 == VERBOSE) $display("[DEBUG] %m : Inserting latency of %2d cycles for Data ACK at time %4t", DataLatency, $time);
			if (DataLatency)
			begin
			   if (2 == VERBOSE) $display("[DEBUG] %m : Asserting STALL at time %4t", $time);
			   WB_STALL_OUT <= 1'b1;
			   repeat (DataLatency)
			      @(posedge CLK);
			   if (2 == VERBOSE) $display("[DEBUG] %m : De-asserting STALL at time %4t", $time);
			   WB_STALL_OUT <= 1'b0;
			end
			
			// READ Transaction, return data on the read bus
			if (dataPhaseRwb)
			begin
			   // Now send an ACK back to Master, and store FIFO values in local variables
			   WbReadData     = {( {8{dataPhaseSel[3]}} & MemArray[dataPhaseAddr+3]),
					     ( {8{dataPhaseSel[2]}} & MemArray[dataPhaseAddr+2]),
					     ( {8{dataPhaseSel[1]}} & MemArray[dataPhaseAddr+1]),
					     ( {8{dataPhaseSel[0]}} & MemArray[dataPhaseAddr+0])
					     };
			   WB_DAT_RD_OUT <= WbReadData;
			   if (1 == VERBOSE) $display("[INFO ] %m : WB Slave READ: Address = 0x%x, Data = 0x%x, SEL = 0b%b", dataPhaseAddr, WbReadData, dataPhaseSel);
			end
			
			// WRITE transaction, write data into array
			else
			begin

			   if (1 == VERBOSE) $display("[INFO ] WB Slave WRITE: Address = 0x%x, Data = 0x%x, SEL = 0b%b", dataPhaseAddr, dataPhaseWriteData, dataPhaseSel);

			   // Decode the byte select
			   // Write depending on SEL output from DM ports. Little endian.
			   case (dataPhaseSel)

			     // Word Write to memory
			     4'b1111 : 
				begin
				   MemArray[dataPhaseAddr+3] <= dataPhaseWriteData[31:24];
				   MemArray[dataPhaseAddr+2] <= dataPhaseWriteData[23:16];
				   MemArray[dataPhaseAddr+1] <= dataPhaseWriteData[15: 8];
				   MemArray[dataPhaseAddr  ] <= dataPhaseWriteData[ 7: 0];
				end
			     // Half-word Write to memory
			     4'b1100 : 
				begin
				   MemArray[dataPhaseAddr+3] <= dataPhaseWriteData[31:24];
				   MemArray[dataPhaseAddr+2] <= dataPhaseWriteData[23:16];
				end
			     4'b0011 : 
				begin
				   MemArray[dataPhaseAddr+1] <= dataPhaseWriteData[15: 8];
				   MemArray[dataPhaseAddr  ] <= dataPhaseWriteData[ 7: 0];
				end
			     // Byte write to memory
			     4'b1000 : MemArray[dataPhaseAddr+3] <= dataPhaseWriteData[31:24];
			     4'b0100 : MemArray[dataPhaseAddr+2] <= dataPhaseWriteData[23:16];
			     4'b0010 : MemArray[dataPhaseAddr+1] <= dataPhaseWriteData[15: 8];
			     4'b0001 : MemArray[dataPhaseAddr  ] <= dataPhaseWriteData[ 7: 0];
			     
//			     default: 
//				begin
//				   $display("[ERROR] %m : Invalid WB_SEL_IN = %04b at time %4t", dataPhaseSel, $time);
//				   WB_ERR_OUT <= 1'b1;
//				   @(posedge CLK);
//				   WB_ERR_OUT <= 1'b0;
//				   // $stop();
//				end
			     
			   endcase // case (dataPhaseSel)

			end // else: !if(dataPhaseRwb)
			
			// Now send an ACK back to Master, and store FIFO values in local variables
			if (2 == VERBOSE) $display("[DEBUG] %m : Asserting ACK at time %4t", $time);
			WB_ACK_OUT <= 1'b1;
			
			@(posedge CLK);
			
			WB_ACK_OUT <= 1'b0;
			WB_DAT_RD_OUT <= 32'h0000_0000; // Don't hold the read data outside of the ACK pulse
			
		     end
		  end
	       
	    end
	    
	 join_none
	 
      end



   
   

   
endmodule // WB_SLAVE_BFM
