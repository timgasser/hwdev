module WB_SLAVE_CTRL
   #(parameter DEFAULT_SLAVE =  0,
     parameter DEFAULT_ERR   =  0,
     parameter WB_ADDR_MSB   = 11,
     parameter WB_ADDR_LSB   =  8,
     parameter WB_ADDR_VAL   =  0
     )
   (
    // Clocks and resets
    input           CLK       ,
    input           EN        ,
    input           RST_SYNC  ,
    input           RST_ASYNC ,

    // Wishbone register slave interface
    input   [31:0] WB_REGS_ADR_IN      , 
    input          WB_REGS_CYC_IN      , 
    input          WB_REGS_STB_IN      , 
    input          WB_REGS_WE_IN       , 
    input   [ 3:0] WB_REGS_SEL_IN      , 
    output         WB_REGS_ACK_OUT     , 
    output         WB_REGS_STALL_OUT   , 
    output         WB_REGS_ERR_OUT     , 
    
//    output  [31:0] WB_REGS_DAT_RD_OUT  , 
//    input   [31:0] WB_REGS_DAT_WR_IN     

    // Decoded output signals
    output         WB_WRITE_ADDR_STB_OUT ,
    output         WB_READ_ADDR_STB_OUT  ,
    output         WB_VALID_OUT 
    
    
    );

   /////////////////////////////////////////////////////////////////////////////
   // wires / regs

   // Wishbone signals
   wire      WbReadAddrStb  ; // Address phase of a read transaction
   wire      WbWriteAddrStb ; // Address and Write data phase of a write transaction
   wire      WbAddrStb      ; // Combined Address phase (write and read)
   reg 	     WbAddrStbReg   ; // Registered Address strobe
   wire      WbAddrValid    ; // High when valid address seen (decodes middle order bits)
   wire      WbSelValid     ; // Check for valid byte enable and address low 2 bits
   wire      WbValid        ; // Combination of Addr and Sel
   

   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns (internal)
   
   // Decode the incoming wishbone signals
   assign WbReadAddrStb  = WB_REGS_CYC_IN & WB_REGS_STB_IN & ~WB_REGS_WE_IN & ~WB_REGS_STALL_OUT;
   assign WbWriteAddrStb = WB_REGS_CYC_IN & WB_REGS_STB_IN &  WB_REGS_WE_IN & ~WB_REGS_STALL_OUT;
   assign WbAddrStb      = WbReadAddrStb | WbWriteAddrStb;

   assign WbSelValid   = ( ((4'b1111 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[1:0] == 2'b00))
                         | ((4'b1100 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
                         | ((4'b0011 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
			   );
   assign WbAddrValid  = (WB_ADDR_VAL == WB_REGS_ADR_IN[WB_ADDR_MSB:WB_ADDR_LSB]); // todo tidy up address checks

   // If it's a default slave, always respond to the access.
   // WbValid being high will always set WbAddrStbReg high on the next cycle
   generate if (DEFAULT_SLAVE)
   begin : DEFAULT_RESPONSE
      assign WB_WRITE_ADDR_STB_OUT =  1'b0;
      assign WB_READ_ADDR_STB_OUT  =  1'b0 ;
      assign WB_VALID_OUT = 1'b0;  
      assign WbValid      = 1'b1;
   end
   else
   begin
      assign WB_WRITE_ADDR_STB_OUT = WbWriteAddrStb;
      assign WB_READ_ADDR_STB_OUT  = WbReadAddrStb ;
      assign WB_VALID_OUT = WbValid;
      assign WbValid      = WbAddrValid & WbSelValid;
   end
   endgenerate
   
   generate if (DEFAULT_ERR)
   begin : DEFAULT_ERR_GEN
      assign WB_REGS_ACK_OUT   = 1'b0;
      assign WB_REGS_ERR_OUT   = WbAddrStbReg;
   end
   else
   begin
      assign WB_REGS_ACK_OUT   = WbAddrStbReg &  WbValid;
      assign WB_REGS_ERR_OUT   = 1'b0;
   end
   endgenerate
   

   /////////////////////////////////////////////////////////////////////////////
   // external assigns

   // WB-side
   assign WB_REGS_STALL_OUT = WbAddrStbReg;
  
   // Core-side

   /////////////////////////////////////////////////////////////////////////////
   // clocked processes


   // Register the address strobe for use in generating ACK / ERR
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_ADDR_STB_REG
      if (RST_ASYNC)
      begin
	 WbAddrStbReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WbAddrStbReg <= 1'b0;
      end
      else if (EN)
      begin
	 WbAddrStbReg <= WbAddrStb & WbValid;
      end
   end
   


endmodule
