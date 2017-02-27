// Wishbone Master.
// Supports burst accesses
module WB_MASTER
   // The parameter below asserts CYC combinatorially, before the STB and rest
   // of the transactions are ready. This was needed for the i-cache, which
   // needs a cycle to look up the TAG and VALID bits in an SRAM. It therefore
   // can't stall in the address phase of the read, only in the data phase.
   #(parameter     COMB_CYC     = 0)
   (
    // Clocks and resets
    input          CLK            ,
    input          EN             ,
    input          RST_SYNC       ,
    input          RST_ASYNC      , 

    // Wishbone interface (Master)
    output [31:0]  WB_ADR_OUT     , // Master: Address of current transfer
    output         WB_CYC_OUT     , // Master: High while whole transfer is in progress
    output         WB_STB_OUT     , // Master: High while the current beat in burst is active
    output         WB_WE_OUT      , // Master: Write Enable (1), Read if 0
    output [ 3:0]  WB_SEL_OUT     , // Master: Byte enables of write (one-hot)
    output [ 2:0]  WB_CTI_OUT     , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    output [ 1:0]  WB_BTE_OUT     , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap

    input          WB_ACK_IN      , // Slave:  Acknowledge of transaction
    input          WB_STALL_IN    , // Slave:  Not ready to accept a new address
    input          WB_ERR_IN      , // Slave:  Not ready to accept a new address

    input  [31:0]  WB_DAT_RD_IN   , // Slave:  Read data
    output [31:0]  WB_DAT_WR_OUT  , // Master: Write data
   
    // Generic BUS interface
    input   [31:0] BUS_START_ADDR_IN     , // Note doesn't have to be aligned..
   
    input          BUS_READ_REQ_IN       ,
    output         BUS_READ_ACK_OUT      ,
    input          BUS_WRITE_REQ_IN      ,
    output         BUS_WRITE_ACK_OUT     ,
    output         BUS_LAST_ACK_OUT      ,
    
    input   [ 1:0] BUS_SIZE_IN           , // 2'b00 = byte, 2'b01 = 16bit, 2'b10 = 32bit
    input   [ 4:0] BUS_LEN_IN            , // Lenght of Burst. 0 = reserved, 1 = single transfer, 2 = burst-of-2, 3 = burst-of-3, etc
    input          BUS_BURST_ADDR_INC_IN , // Whether to increment the address during a burst. 

    output  [31:0] BUS_READ_DATA_OUT     ,
    input   [31:0] BUS_WRITE_DATA_IN 
   
    );
   
// includes
`include "wb_defs.v"

   wire            BusReq       ; // assign = BUS_WRITE_REQ_IN | BUS_READ_REQ_IN
   reg             BusReqReg    ; // 
   wire            BusReqRedge  ; // assign = BusReq & ~BusReqReg

   wire            WbLastAck    ; // assign = BusReq & (5'd1 == AckTmrVal  ) & AckTmrDec
   wire            WbLastStb    ; // assign = BusReq & (5'd1 == BurstTmrVal) & BurstTmrDec

   wire            BurstTmrDec  ; // assign = WB_CYC_OUT & WB_STB_OUT & ~WB_STALL_IN
   wire            AckTmrDec    ; // assign = WB_ACK_IN

   // Timers/Counters
   reg [ 4:0]     BurstTmrVal;
   reg [ 4:0]     AckTmrVal;
   reg [31:0]     AddrCntVal;

   // Aligned Read and Write data. The BUS interface uses data starting from the
   // bottom of the bus.
   reg [31:0]     BusReadData ; // assign BUS_READ_DATA_OUT
   reg [31:0]     WrWbDat     ; // assign WB_WR_DAT_OUT

   // Registered Wishbone control signals
   reg            WbCyc; // assign = WB_CYC_OUT
   reg            WbStb; // assign = WB_STB_OUT
   reg            WbWe ; // assign = WB_WE_OUT
   reg  [ 3:0]    WbSelLocal ; // version of WB_SEL, held until the entire burst has completed.
   reg  [ 3:0]    WbSel ; // assign = WB_WE_OUT, held until last address strobe accepted
   reg  [ 3:0]    WbSelNxt; // combinatorial version
   reg  [ 2:0]    WbCti;    // registered WB_CYC_OUT
   wire [ 2:0]    WbCtiNxt; // combinatorial WB_CYC_OUT
   
   // internal assigns
   assign    BusReq       = BUS_WRITE_REQ_IN | BUS_READ_REQ_IN;
   assign    BusReqRedge  = BusReq & ~BusReqReg;
          
   assign    WbLastAck    = BusReq & (5'd1 == AckTmrVal  ) & AckTmrDec;
   assign    WbLastStb    = BusReq & (5'd1 == BurstTmrVal) & BurstTmrDec;
   assign    Wb2ndLastStb = BusReq & (5'd2 == BurstTmrVal) & BurstTmrDec;
          
   assign    BurstTmrDec  = WB_CYC_OUT & WB_STB_OUT & ~WB_STALL_IN;
   assign    AckTmrDec    = WB_ACK_IN;

   // external assigns

   generate if (COMB_CYC)
   begin : GEN_CYC_COMB
      assign WB_CYC_OUT        =  WbCyc | BUS_READ_REQ_IN | BUS_WRITE_REQ_IN;
   end
   else
   begin
      assign WB_CYC_OUT        =  WbCyc ;
   end
   endgenerate
   
   assign WB_ADR_OUT        =  {AddrCntVal[31:2], 2'b00};
   assign WB_STB_OUT        =  WbStb ;
   assign WB_WE_OUT         =  WbWe  ;
   assign WB_SEL_OUT        =  WbSel ;

   assign WB_CTI_OUT        = WbCti;
   assign WB_BTE_OUT        = BTE_LINEAR_BURST; // Always do a linear burst (no wrapping)
   
   assign BUS_WRITE_ACK_OUT =  BUS_WRITE_REQ_IN  & WB_ACK_IN  ;
   assign BUS_READ_ACK_OUT  =  BUS_READ_REQ_IN   & WB_ACK_IN  ;
   assign BUS_LAST_ACK_OUT  =  WbLastAck;
   
   assign BUS_READ_DATA_OUT = BusReadData    ; // WB_DAT_RD_IN      ;
   assign WB_DAT_WR_OUT     = WrWbDat        ; // BUS_WRITE_DATA_IN ;


   // Register the BusReq to find a rising edge of the read or write request.
   // Use this pulse to register the new transaction settings to if they change during
   // the burst they're still held constant internally.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_REQ_REG
      if (RST_ASYNC)
      begin
         BusReqReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         BusReqReg <= 1'b0;
      end
      else if (EN)
      begin
         BusReqReg <= BusReq;
      end
   end
   
   // WB_CYC_OUT register. 
   // Set on the rising edge of BusReq. 
   // Clear when last ACK is seen (need to look ahead as the CYC is registered).
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_CYC_REG
      if (RST_ASYNC)
      begin
         WbCyc <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         WbCyc <= 1'b0;
      end
      else if (EN)
      begin
         if (BusReqRedge)
         begin
            WbCyc <= 1'b1;
         end
         else if (BusReq && WbLastAck)
         begin
            WbCyc <= 1'b0;
         end
      end
   end

   // WB_STB_OUT register. 
   // Set on the rising edge of BusReq.
   // Clear when last address has been accepted.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_STB_REG
      if (RST_ASYNC)
      begin
         WbStb <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         WbStb <= 1'b0;
      end
      else if (EN)
      begin
         if (BusReqRedge)
         begin
            WbStb <= 1'b1;
         end
         else if (BusReq && WbLastStb)
         begin
            WbStb <= 1'b0;
         end
      end
   end

   // WB_WE_OUT register. 
   // Set on the rising edge of BusReq.
   // Clear when last address has been accepted.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_WE_REG
      if (RST_ASYNC)
      begin
         WbWe <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         WbWe <= 1'b0;
      end
      else if (EN)
      begin
         if (BusReqRedge && BUS_WRITE_REQ_IN)
         begin
            WbWe <= 1'b1;
         end
         else if (BusReq && WbLastStb)
         begin
            WbWe <= 1'b0;
         end
      end
   end

   // WB_SEL_OUT register. 
   // Set on the rising edge of BusReq.
   // Clear when last address has been accepted.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_SEL_REG
      if (RST_ASYNC)
      begin
         WbSel <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         WbSel <= 1'b0;
      end
      else if (EN)
      begin
         if (BusReqRedge)
         begin
            WbSel <= WbSelNxt;
         end
         else if (WbLastStb)
         begin
            WbSel <= 4'b0000;
         end
      end
   end

   // WbSelLocal register. 
   // Stored on rising edge of BusReq.
   // Need a different SEL to the bus WB_SEL as this is held unti last ACK, other one is until last address strobe is accepted
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_SEL_LOCAL_REG
      if (RST_ASYNC)
      begin
         WbSelLocal <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         WbSelLocal <= 1'b0;
      end
      else if (EN)
      begin
         if (BusReqRedge)
         begin
            WbSelLocal <= WbSelNxt;
         end
      end
   end
   
   // WB_CTI_OUT register. 
   // Leave at 000 for non-burst access
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_CTI_REG
      if (RST_ASYNC)
      begin
         WbCti <= CTI_CLASSIC;
      end
      else if (RST_SYNC)
      begin
         WbCti <= CTI_CLASSIC;
      end
      else if (EN)
      begin
         // If it's the first cycle of the bus request, set the burst address if length > 1
         // If it's the last address cycle of the burst, change the CTI to show it.
         if (BusReqRedge)
	 begin
	    // First cycle of the bus request, register an incrementing burst if requested
	    if (BUS_BURST_ADDR_INC_IN)
	    begin
	       WbCti <= CTI_INCR_ADDR;
	    end
	    // Otherwise make sure it's a classic single access
	    else
	    begin
	       WbCti <= CTI_CLASSIC;
	    end
	 end

	 // Or if the penultimate address has been accepted in this cycle, set the next one to the last burst identifier
	 else if (Wb2ndLastStb)
	 begin
	    WbCti <= CTI_END_BURST;
	 end

	 // Once the last strobe has been accepted, reset to the classic access
	 else if (WbLastStb)
	 begin
	    WbCti <= CTI_CLASSIC;
	 end
      end
   end

   // Burst timer. 
   // Loaded by FSM when requesting to the arbiter.
   // Decremented when the address is accepted (but don't wrap, stay at 0)
   always @(posedge CLK    or posedge RST_ASYNC)
   begin : BURST_TIMER
      if (RST_ASYNC)
      begin
         BurstTmrVal <= 5'd0;
      end
      else if (RST_SYNC)
      begin
         BurstTmrVal <= 5'd0;
      end
      else if (EN)
      begin
         // Store the length of the burst on a rising bus request
         if (BusReqRedge)
         begin
            BurstTmrVal <= BUS_LEN_IN;
         end
         // Decrement until it reaches 0 every time a new address is accepted (STB and no STALL)
         else if (BurstTmrDec && (| BurstTmrVal))
         begin
            BurstTmrVal <= BurstTmrVal - 5'd1;
         end
      end
   end
   
   // ACK Timer timer. 
   // Loaded by FSM when requesting to the arbiter.
   // Decremented when the data ACKs are seen. Need to see as many ACKs as Addresses 
   // STB'ed onto the bus
   always @(posedge CLK    or posedge RST_ASYNC)
   begin : ACK_TIMER
      if (RST_ASYNC)
      begin
         AckTmrVal <= 5'd0;
      end
      else if (RST_SYNC)
      begin
         AckTmrVal <= 5'd0;
      end
      else if (EN)
      begin
         // Store the length of the burst on a rising edge of the bus request
         if (BusReqRedge)
         begin
            AckTmrVal <= BUS_LEN_IN;
         end
         // Decrement until it hits zero every time an ACK is seen
         else if (WB_ACK_IN && (| AckTmrVal))
         begin
            AckTmrVal <= AckTmrVal - 5'd1;
         end
      end
   end
   
   // Address Counter
   // Loaded by FSM when requesting to the arbiter.
   // Incremented every time the address is accepted when required.
   always @(posedge CLK    or posedge RST_ASYNC)
   begin : ADDR_CNT
      if (RST_ASYNC)
      begin
         AddrCntVal <= 32'h0000_0000;
      end
      else if (RST_SYNC)
      begin
         AddrCntVal <= 32'h0000_0000;
      end
      else if (EN)
      begin
         // Store the beginning address of the burst on a rising bus request edge
         if (BusReqRedge)
         begin
            AddrCntVal <= BUS_START_ADDR_IN;
         end
         // If an incrementing burst is selected, keep incrementing every time
         // a STB is sent out and no STALL comes back
         else if (BUS_BURST_ADDR_INC_IN && BurstTmrDec)
         begin
            AddrCntVal <= AddrCntVal + 32'd4;
         end
      end
   end
   
   // WB_SEL decoder
   always @*
   begin : WB_SEL_DECODE

      WbSelNxt = 4'b0000;

      case (BUS_SIZE_IN)
        
        // Byte
        2'b00 : 
          begin
             case (BUS_START_ADDR_IN[1:0])
               2'b00 : WbSelNxt = 4'b0001;
               2'b01 : WbSelNxt = 4'b0010;
               2'b10 : WbSelNxt = 4'b0100;
               2'b11 : WbSelNxt = 4'b1000;
             endcase
          end

        // 16-bit
        2'b01 :
          begin
             case (BUS_START_ADDR_IN[1])
               1'b0 : WbSelNxt = 4'b0011;
               1'b1 : WbSelNxt = 4'b1100;
             endcase
          end

        2'b10 : WbSelNxt = 4'b1111; 
        
        default : WbSelNxt = 4'b0000;
      endcase // case (BUS_SIZE_IN)
   end
   

   // Align the Wishbone read data bus to the bus.
   // All data aligned to the bottom of the bus.
   always @(*)
   begin : BUS_READ_DATA_ALIGN
      BusReadData = 32'h0000_0000;
      case (WbSelLocal)
        4'b0001 : BusReadData = {24'h00_0000, WB_DAT_RD_IN[ 7: 0]};
        4'b0010 : BusReadData = {24'h00_0000, WB_DAT_RD_IN[15: 8]};
        4'b0100 : BusReadData = {24'h00_0000, WB_DAT_RD_IN[23:16]};
        4'b1000 : BusReadData = {24'h00_0000, WB_DAT_RD_IN[31:24]};
        4'b0011 : BusReadData = {16'h0000, WB_DAT_RD_IN[15: 0]};
        4'b1100 : BusReadData = {16'h0000, WB_DAT_RD_IN[31:16]};
        4'b1111 : BusReadData = WB_DAT_RD_IN;
      endcase // case (WbSel)
   end

   // Align the Wishbone write data
   always @(*)
   begin : WB_WRITE_DATA_ALIGN
      WrWbDat = 32'h0000_0000;
      
      case (WbSel)
        4'b0001 : WrWbDat  = {24'h00_0000, BUS_WRITE_DATA_IN[7:0]};
        4'b0010 : WrWbDat  = {16'h0000, BUS_WRITE_DATA_IN[7:0], 8'h00};
        4'b0100 : WrWbDat  = {8'h00,BUS_WRITE_DATA_IN[7:0], 16'h0000};
        4'b1000 : WrWbDat  = {BUS_WRITE_DATA_IN[7:0], 24'h00_0000};
        4'b0011 : WrWbDat  = {16'h0000, BUS_WRITE_DATA_IN[15: 0]};
        4'b1100 : WrWbDat  = {BUS_WRITE_DATA_IN[15: 0], 16'h0000};
        4'b1111 : WrWbDat  = BUS_WRITE_DATA_IN;
      endcase // case (WbSel)
   end
      
endmodule 
