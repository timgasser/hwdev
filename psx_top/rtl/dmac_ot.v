module DMAC_OT
   #(parameter DMAC6_BURST_LEN_P2 = 5'd4)
   (
    // Clocks and resets
    input          CLK            ,
    input          EN             ,
    input          RST_SYNC       ,
    input          RST_ASYNC      , 

    // Configuration (from registers)
    input   [31:0] CFG_DMAC_MADR_IN         ,
    input   [31:0] CFG_DMAC_BCR_IN          ,
    input          CFG_DMAC_CHCR_TR_IN      , // Only need single control bit
    output         CFG_DMAC_CHCR_TR_CLR_OUT , // Clear TR. Leave hanging for later !! todo !

    // Generic BUS interface (Master)
    output  [31:0] BUS_START_ADDR_OUT     , // Note doesn't have to be aligned..
   
    output         BUS_READ_REQ_OUT       ,
    input          BUS_READ_ACK_IN        ,
    output         BUS_WRITE_REQ_OUT      ,
    input          BUS_WRITE_ACK_IN       ,
    input          BUS_LAST_ACK_IN        ,
    
    output  [ 1:0] BUS_SIZE_OUT           ,
    output  [ 4:0] BUS_LEN_OUT            , 
    output         BUS_BURST_ADDR_INC_OUT , 

    input   [31:0] BUS_READ_DATA_IN       ,
    output  [31:0] BUS_WRITE_DATA_OUT 
   
    );

// includes
`include "psx_mem_map.vh"
   
   // Local parameters
                          
   /////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // Dmac flow control
   wire     CfgDmacStart;
   wire     DmacStartStb;
   reg 	    DmacOtNullWriteReq;
   reg 	    DmacOtWriteReq;
      
   wire     BusWriteEnd;
   wire     DmacOtNullWriteEnd;
   wire     DmacOtWriteEnd;

   reg 	    BusWriteReq;
   
   reg  [31:2] DmacLastAddrReg;

   wire [31:2] DmacStartAddr;
   reg  [31:2] DmacOtAddrCntVal;
   reg  [23:2] DmacOtAddrCntValReg;

   wire [4:0]  DmacOtLen;
   wire [31:2] DmacAddrTmr;
   
   
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns

   // Enable the channel when the magic value is written into CHCR
   assign CfgDmacStart = CFG_DMAC_CHCR_TR_IN; // (DMAC6_CHCR_EN == CFG_DMAC_CHCR_IN);
   // Only start the writes when not currently processing one.
   assign DmacStartStb = CfgDmacStart & ~DmacOtNullWriteReq & ~DmacOtWriteReq;

   assign BusWriteEnd        = BusWriteReq & BUS_WRITE_ACK_IN;
   assign DmacOtNullWriteEnd = BusWriteEnd & DmacOtNullWriteReq;
   assign DmacOtWriteEnd     = BusWriteEnd & DmacOtWriteReq 
			       & (DmacOtAddrCntVal[31:2] == DmacLastAddrReg[31:2]);

   assign DmacAddrTmr = DmacLastAddrReg[31:2] - DmacOtAddrCntVal[31:2];
   assign DmacOtLen   = (DmacAddrTmr > DMAC6_BURST_LEN_P2) ? DMAC6_BURST_LEN_P2 : DmacAddrTmr;
      
   assign DmacStartAddr = CFG_DMAC_MADR_IN[31:2] 
	                - CFG_DMAC_BCR_IN[DMAC_BCR_BLK_SIZE_MSB:DMAC_BCR_BLK_SIZE_LSB];
   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns

   // static bus assignments
   assign BUS_READ_REQ_OUT        = 1'b0; // Write-only channel
   assign BUS_SIZE_OUT            = 2'd2; // 32-b only transactions
   assign BUS_BURST_ADDR_INC_OUT  = 1'b1; // Always incrementing bursts
   
   // Dynamic bus assignments
   assign BUS_START_ADDR_OUT = {DmacOtAddrCntVal[31:2], 2'b00};
   assign BUS_WRITE_REQ_OUT  = BusWriteReq;
   assign BUS_LEN_OUT        = DmacOtNullWriteReq ? 5'd1         : DmacOtLen;
   assign BUS_WRITE_DATA_OUT = DmacOtNullWriteReq ? DMAC6_OT_END : {8'h00, 
								    DmacOtAddrCntValReg[23:2], 
								    2'b00};

   assign CFG_DMAC_CHCR_TR_CLR_OUT = DmacOtWriteEnd;
			      
   /////////////////////////////////////////////////////////////////////////////
   // always blocks

   // Register the 32b address (drop bottom 2 bits) when starting an OT
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMAC_LAST_ADDR_REG
      if (RST_ASYNC)
      begin
         DmacLastAddrReg <= 30'd0;
      end
      else if (RST_SYNC)
      begin
         DmacLastAddrReg <= 30'd0;
      end
      else if (EN)
      begin
         DmacLastAddrReg <= CFG_DMAC_MADR_IN[31:2];
      end
   end

   // Register when the OT terminator write is going on
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMAC_OT_NULL_WRITE_REQ
      if (RST_ASYNC)
      begin
         DmacOtNullWriteReq <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         DmacOtNullWriteReq <= 1'b0;
      end
      else if (EN)
      begin
	 if (DmacOtNullWriteEnd)
	 begin
            DmacOtNullWriteReq <= 1'b0;
	 end
	 else if (DmacStartStb)
	 begin
            DmacOtNullWriteReq <= 1'b1;
	 end
      end
   end
   

   // Register when the normal OT is being written
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMAC_OT_WRITE_REQ_REG
      if (RST_ASYNC)
      begin
         DmacOtWriteReq <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         DmacOtWriteReq <= 1'b0;
      end
      else if (EN)
      begin
	 if (DmacOtWriteEnd)
	 begin
            DmacOtWriteReq <= 1'b0;
	 end
	 else if (DmacOtNullWriteReq)
	 begin	    
	    DmacOtWriteReq <= 1'b1;
	 end
      end
   end

   // Register a bus write request unless it's the cycle after a LAST_ACK
   // comes back from wb master (you need to de-assert the request line
   // in between bursts) ..
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_WRITE_REQ_REG
      if (RST_ASYNC)
      begin
         BusWriteReq <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         BusWriteReq <= 1'b0;
      end
      else if (EN)
      begin
	 if (BUS_LAST_ACK_IN)
	 begin
            BusWriteReq <= 1'b0;
	 end
	 else if (DmacOtNullWriteReq || DmacOtWriteReq)
	 begin
	    BusWriteReq <= 1'b1;
	 end
      end
   end
   
   // DMAC OT address counter. The units are in 32 bits
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMAC_OT_ADDR_CNT
      if (RST_ASYNC)
      begin
         DmacOtAddrCntVal <= 30'd0;
      end
      else if (RST_SYNC)
      begin
         DmacOtAddrCntVal <= 30'd0;
      end
      else if (EN)
      begin
	 // Load the starting address (MADR - BCR << 2) when
	 // it's the start of a new OT operation
	 if (DmacStartStb)
	 begin
	    DmacOtAddrCntVal <= DmacStartAddr;
	 end
	 else if (BusWriteEnd)
	 begin
	    DmacOtAddrCntVal <= DmacOtAddrCntVal + 30'd1;
	 end
      end
   end

   // Register the address used for the previous write, this
   // is the data for the current write. Only need bottom 24 bits
   // (top byte of OT is length in bytes, = 8'h00)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMAC_OT_ADDR_CNT_REG
      if (RST_ASYNC)
      begin
         DmacOtAddrCntValReg <= 22'd0;
      end
      else if (RST_SYNC)
      begin
         DmacOtAddrCntValReg <= 22'd0;
      end
      else if (EN && BusWriteEnd)
      begin
         DmacOtAddrCntValReg <= DmacOtAddrCntValReg + 22'd1;
      end
   end
   

   /////////////////////////////////////////////////////////////////////////////
   // DMAC Channel 6

   


   
   /////////////////////////////////////////////////////////////////////////////
   // Wishbone Master arbiter (6-M to 1-S)



endmodule // DMAC_CH6
