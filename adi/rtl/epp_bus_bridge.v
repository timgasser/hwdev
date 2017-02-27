// EPP BUS Bridge
//
// This module interfaces with the EPP slave, and provides a memory-mapped
// bus interface.


module EPP_BUS_BRIDGE
   (
    // Clock / reset
    input           CLK        ,
    input           EN         ,
    input           RST_SYNC   ,
    input           RST_ASYNC  ,

    // REGS interface (from EPP USB slave)
    input   	    REGS_WRITE_REQ_IN   ,
    input   	    REGS_READ_REQ_IN    ,
    input  	    REGS_ADDR_SEL_IN    ,
    input  	    REGS_DATA_SEL_IN    ,

    output  	    REGS_READ_ACK_OUT   ,
    output  	    REGS_WRITE_ACK_OUT  ,

    output    [7:0] REGS_READ_DATA_OUT  ,
    input     [7:0] REGS_WRITE_DATA_IN  ,
    
    // Bus interface 
    output   [31:0] BUS_ADDR_OUT	  ,
    output          BUS_REQ_OUT 	  ,
    input           BUS_ACK_IN  	  ,

    output          BUS_RWB_OUT 	  ,
    output   [ 1:0] BUS_SIZE_OUT 	  ,
    output   [31:0] BUS_WRITE_DATA_OUT	  ,
    input    [31:0] BUS_READ_DATA_IN	  

   );
`include "epp_bus_bridge_defs.v"
  
   // typedefs
  
   // Internal wires
   reg [ 7:0] 	    EppAddr  ; // EPP Address register
   reg [31:0] 	    BusAddr  ; // 
   reg 		    BusReq   ;
   reg 		    BusStreamReq  ;
   
   reg 		    BusRwb   ; // Single access controls
   reg [ 1:0] 	    BusSize  ;
   reg [31:0] 	    BusData  ;

   reg 		    BusStreamRwb                   ; // Streaming access controls
   wire [1:0] 	    BusStreamSize = ERW_SIZE_BYTE  ; // Only byte accesses in streaming mode
   reg  [7:0] 	    BusStreamData  ;
   
   reg 		    RegsWriteAck ; // assign REGS_WRITE_ACK_OUT
   reg 		    RegsReadAck  ; // assign REGS_READ_ACK_OUT
   reg [7:0] 	    RegsReadData ; // assign REGS_READ_DATA_OUT

   reg [7:0] 	    EppReadData  ;
   
   // Internal wire/assigns
   wire  EppAddrWriteEn = REGS_ADDR_SEL_IN & REGS_WRITE_REQ_IN & REGS_WRITE_ACK_OUT;
   wire  EppDataWriteEn = REGS_DATA_SEL_IN & REGS_WRITE_REQ_IN & REGS_WRITE_ACK_OUT;
   
   // External assigns
//   assign REGS_READ_ACK_OUT  = REGS_READ_REQ_IN;
//   assign REGS_WRITE_ACK_OUT = REGS_ADDR_SEL_IN ? REGS_WRITE_REQ_IN : // First priority, all Address complete in one cycle
//			       (ERW_TRANS == EppAddr) ? (BusReq & BUS_ACK_IN) : REGS_WRITE_REQ_IN;
//   assign REGS_READ_DATA_OUT =   (EppAddr      & {8{REGS_ADDR_SEL_IN}})
//                               | (EppReadData  & {8{REGS_DATA_SEL_IN}});

   assign REGS_WRITE_ACK_OUT = RegsWriteAck ; 
   assign REGS_READ_ACK_OUT  = RegsReadAck  ;
   assign REGS_READ_DATA_OUT = RegsReadData ; // 

   assign BUS_ADDR_OUT        = BusAddr ;
   assign BUS_REQ_OUT         = BusReq  | BusStreamReq;

   assign BUS_RWB_OUT         = BusStreamReq ? BusStreamRwb  : BusRwb  ;
   assign BUS_SIZE_OUT 	      = BusStreamReq ? ERW_SIZE_BYTE : BusSize ;
   assign BUS_WRITE_DATA_OUT  = BusStreamReq ? BusStreamData : BusData ;


   //**************************************************************************
   //* EPP-mastered registers
   //**************************************************************************

   // Address Register. Read and written from EPP only. Incremented by streaming register.
   // Indexes other data accesses
   always @(posedge CLK or posedge RST_ASYNC)
   begin : EPP_ADDR_REG
      if (RST_ASYNC)
      begin
	 EppAddr <= 8'h00;
      end
      else if (RST_SYNC)
      begin
	 EppAddr <= 8'h00;
      end
      else if (EN)
      begin
	 // Store value on EPP Register access
	 if (EppAddrWriteEn)
	 begin
	    EppAddr <= REGS_WRITE_DATA_IN;
	 end
      end
   end

   // Bus Address Register. Read and written from EPP only.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_ADDR_REG
      if (RST_ASYNC)
      begin
	 BusAddr <= 8'h00;
      end
      else if (RST_SYNC)
      begin
	 BusAddr <= 8'h00;
      end
      else if (EN)
      begin
	 // Increment when a streaming access completes
	 if (BusStreamReq && BUS_ACK_IN)
	 begin
	    BusAddr <= BusAddr + 32'd1;
	 end
	 // Store Address bytes on EPP accesses
	 else if (EppDataWriteEn)
	 begin
	    case (EppAddr)
	      ERW_ADDR0 : BusAddr <= {BusAddr[31:8]	, REGS_WRITE_DATA_IN                };
	      ERW_ADDR1 : BusAddr <= {BusAddr[31:16]	, REGS_WRITE_DATA_IN, BusAddr[7:0]  };
	      ERW_ADDR2 : BusAddr <= {BusAddr[31:24]	, REGS_WRITE_DATA_IN, BusAddr[15:0] };
	      ERW_ADDR3 : BusAddr <= {REGS_WRITE_DATA_IN , BusAddr[23:0]                     };
	    endcase // case (EppAddr)
	 end
      end
   end

   // Streaming Register. Read and write sensitive from EPP. Data Written by EPP, Read from Bus.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_STREAM_REG
      if (RST_ASYNC)
      begin
	 BusStreamReq   <= 1'b0;
	 BusStreamRwb   <= 1'b0;
//	 BusStreamSize  <= 2'b00; // Only byte accesses supported in streaming
	 BusStreamData  <= 8'h00;
      end
      else if (RST_SYNC)
      begin
	 BusStreamReq   <= 1'b0;
	 BusStreamRwb   <= 1'b0;
//	 BusStreamSize  <= 2'b00; // Only byte accesses supported in streaming
	 BusStreamData  <= 8'h00;
      end
      else if (EN)
      begin
	 if (ERW_STREAM == EppAddr)
	 begin
	    // 1st priority when the ACK comes back (or the transaction will never end)
	    if (BusStreamReq && BUS_ACK_IN)
	    begin
	       BusStreamReq   <= 1'b0;
	       // Store the read data if a read was requested
	       if (REGS_READ_REQ_IN) 
	       begin
		  BusStreamData <= BUS_READ_DATA_IN;
	       end
	    end
	    // 2nd priority, could be read or write 	    
	    else if (REGS_DATA_SEL_IN && (REGS_READ_REQ_IN || REGS_WRITE_REQ_IN) && !BusStreamReq)
	    begin
	       BusStreamReq   <= 1'b1;
	       // Read. Request data, register when the ACK is returned.
	       if (REGS_READ_REQ_IN)
	       begin
		  BusStreamRwb <= 1'b1;
	       end
	       // Write
	       else if (REGS_WRITE_REQ_IN)
	       begin
		  BusStreamRwb  <= 1'b0;
		  BusStreamData <= REGS_WRITE_DATA_IN;
	       end
	    end
	 end
      end
   end
  
   // Transaction Register. Read and written from EPP only. Write-sensitive, requests BUS transaction
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_TRANS_REG
      if (RST_ASYNC)
      begin
	 BusReq   <= 1'b0;
	 BusRwb   <= 1'b0;
	 BusSize  <= 2'b00;
      end
      else if (RST_SYNC)
      begin
	 BusReq   <= 1'b0;
	 BusRwb   <= 1'b0;
	 BusSize  <= 2'b00;
      end
      else if (EN)
      begin
	 
	 if (ERW_TRANS == EppAddr)
	 begin
	    // 1st priority when the ACK comes back (or the transaction will never end)
	    if (BusReq && BUS_ACK_IN)
	    begin
	       BusReq   <= 1'b0;
	    end
	    // 2nd priority 	    
	    else if (REGS_DATA_SEL_IN && REGS_WRITE_REQ_IN && !BusReq)
	    begin
	       BusReq   <= 1'b1;
	       BusRwb   <= REGS_WRITE_DATA_IN[ERW_TRANS_RWB];
	       BusSize  <= REGS_WRITE_DATA_IN[ERW_TRANS_SIZE_MSB:ERW_TRANS_SIZE_LSB];
	    end
	 end
      end
   end
  
   // Bus Data Register. Has the following two modes:
   // - BUS READ : Written by BUS-side, read by EPP-side
   // - BUS WRITE: Written by EPP, used by BUS-side.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_DATA_REG
      if (RST_ASYNC)
      begin
	 BusData <= 32'h0000_0000;
      end
      else if (RST_SYNC)
      begin
	 BusData <= 32'h0000_0000;
      end
      else if (EN)
      begin
	 // If doing a bus read, store the result in this register
	 if (BusReq && BusRwb && BUS_ACK_IN)
	 begin
	    BusData <= BUS_READ_DATA_IN;
	 end

	 // If doing an EPP write, store the appropriate byte   
	 else if (EppDataWriteEn)
	 begin
	    case (EppAddr)
	      ERW_DATA0 : BusData <= {BusData[31:8]	, REGS_WRITE_DATA_IN                };
	      ERW_DATA1 : BusData <= {BusData[31:16]	, REGS_WRITE_DATA_IN, BusData[7:0]  };
	      ERW_DATA2 : BusData <= {BusData[31:24]	, REGS_WRITE_DATA_IN, BusData[15:0] };
	      ERW_DATA3 : BusData <= {REGS_WRITE_DATA_IN , BusData[23:0]                     };
	    endcase // case (EppAddr)
	 end
      end
   end
 
   //**************************************************************************


   //**************************************************************************
   //* Return signals to the EPP slave
   //**************************************************************************

   // Return Write ACK 
   always @*
   begin : REGS_WRITE_ACK_SEL

      RegsWriteAck = 1'b0;

      // Address writes complete in one cycle
      if (REGS_ADDR_SEL_IN)
      begin
	 RegsWriteAck = REGS_WRITE_REQ_IN;
      end
      // Data writes may be stalled .. 
      else if (REGS_WRITE_REQ_IN)
      begin
	 case (EppAddr)
	   ERW_TRANS  : RegsWriteAck = BusReq & BUS_ACK_IN       ;
	   ERW_STREAM : RegsWriteAck = BusStreamReq & BUS_ACK_IN ;
	   default    : RegsWriteAck = REGS_WRITE_REQ_IN         ;
	 endcase // case (EppAddr)
      end
   end
   
   // Return Read ACK 
   always @*
   begin : REGS_READ_ACK_SEL

      RegsReadAck = 1'b0;

      // Streaming register reads can stall ..
      if (ERW_STREAM == EppAddr)
      begin
	 RegsReadAck = BusStreamReq & BUS_ACK_IN;
      end
      else
      begin
	 RegsReadAck = REGS_READ_REQ_IN;
      end
   end
   
   always @*
   begin : REGS_READ_DATA_SEL

      RegsReadData = 8'h00;
      
      if (REGS_ADDR_SEL_IN && REGS_READ_REQ_IN)
      begin
	 RegsReadData = EppAddr;
      end
      
      else if (REGS_DATA_SEL_IN && REGS_READ_REQ_IN)
      begin
	 
	 case (EppAddr)
	   ERW_ADDR0   : RegsReadData = BusAddr[ 7: 0];
	   ERW_ADDR1   : RegsReadData = BusAddr[15: 8];
	   ERW_ADDR2   : RegsReadData = BusAddr[23:16];
	   ERW_ADDR3   : RegsReadData = BusAddr[31:24];
	   ERW_DATA0   : RegsReadData = BusData[ 7: 0];
	   ERW_DATA1   : RegsReadData = BusData[15: 8];
	   ERW_DATA2   : RegsReadData = BusData[23:16];
	   ERW_DATA3   : RegsReadData = BusData[31:24]; 
	   ERW_TRANS   : RegsReadData = (8'h00 | BusRwb << ERW_TRANS_RWB | BusSize << ERW_TRANS_SIZE_LSB);
	   ERW_STATUS  : RegsReadData = (8'h00 | BusReq);
	   ERW_STREAM  : RegsReadData = BUS_READ_DATA_IN[7:0];
	 endcase // case (EppAddr)

      end
   end
   //**************************************************************************

endmodule
