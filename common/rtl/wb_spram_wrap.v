module WB_SPRAM_WRAP
   #(
     parameter [31:0] WBA   = 32'h0000_0000, // Wishbone Base Address
     parameter        WS_P2 = 10           , // Wishbone size as power-of-2 bytes
     parameter        DW    = 32             // Data Width
     )
   (
    input         CLK            ,
    input         EN             ,
    input         RST_SYNC       ,
    input         RST_ASYNC      ,
    
    // Wishbone Interface
    input  [31:0] WB_ADR_IN     ,
    input         WB_CYC_IN     ,
    input         WB_STB_IN     ,
    input         WB_WE_IN     ,
    input  [ 3:0] WB_SEL_IN     ,
    input  [ 2:0] WB_CTI_IN     ,
    input  [ 1:0] WB_BTE_IN     ,

    output        WB_ACK_OUT   ,
    output        WB_STALL_OUT ,
    output        WB_ERR_OUT   ,

    input  [DW-1:0] WB_WR_DAT_IN   ,
    output [DW-1:0] WB_RD_DAT_OUT  
    );

   // Subtract the WB Base address from incoming address to get offset only
   wire [31:0] 	    WbAddrOffset = WB_ADR_IN - WBA;
   // Check if the offset address is in the range of the RAM
   wire 	    WbAddrInRange = ~(| WbAddrOffset[31:WS_P2]);

   // Generate the RAM Signals if the address is in range, and we're enabled
   wire 	    RamEn      = EN & WB_CYC_IN & WB_STB_IN & WbAddrInRange;
   wire 	    RamWriteEn = EN & WB_CYC_IN & WB_STB_IN & WB_WE_IN & WbAddrInRange;
   wire [WS_P2-1:0] RamAddr    = WbAddrOffset[WS_P2-1:0];
   
   reg 		    WbAck; // assign WB_ACK_OUT
   reg 		    WbErr; // assign WB_ERR_OUT
   
   // External assigns
   assign WB_ACK_OUT = WbAck;
   assign WB_ERR_OUT = WbErr;

   // We can always accept a new read or write
   assign WB_STALL_OUT = 1'b0;

   // Generate an ACK in the next cycle if the current address is valid.
   // Generate an ERR response if the address isn't valid.
   always @(posedge CLK or posedge RST_ASYNC)
   begin
      if (RST_ASYNC)
      begin
	 WbAck <= 1'b0;
	 WbErr <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WbAck <= 1'b0;
	 WbErr <= 1'b0;
      end
      else if (EN)
      begin
	 WbAck <= RamEn;
	 WbErr <= EN & WB_CYC_IN & WB_STB_IN & ~WbAddrInRange;
      end
   end
   

   
   // Wishbone wrapper to access a Single-Port RAM
   // Need 4 parallel SPRAM instances to support BYTE selects
   genvar 	    i;

   generate for (i = 0 ; i < 4 ; i = i + 1)
   begin : RAM_BYTE_GEN
      
	 SPRAM 
	    #(.ADDR_WIDTH  (WS_P2   ),
	      .DATA_WIDTH  (DW >> 2 )
	      )
	 spram
	    (
	     .CLK            (CLK                       ),
	     .EN             (RamEn & WB_SEL_IN[i]      ),
	     .WRITE_EN_IN    (RamWriteEn & WB_SEL_IN[i] ),
	     .ADDR_IN        (RamAddr                   ),
	     .WRITE_DATA_IN  (WB_WR_DAT_IN [((i+1)*8)-1:(i*8)]  ),
	     .READ_DATA_OUT  (WB_RD_DAT_OUT[((i+1)*8)-1:(i*8)]  )
	     );

      end
   endgenerate
   
   
   
endmodule

