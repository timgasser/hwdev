// Insert module header here

module INTC
   #(parameter IW = 11)
   (
    input           CLK       ,
    input           EN        ,
    input           RST_SYNC  ,
    input           RST_ASYNC ,

    // Core-side Instruction Memory (IM) - Pipelined wishbone B4 Spec
    input   [31:0]  WB_REGS_ADR_IN      , // Master: Bus Address
    input           WB_INTC_CYC_IN      , // Master: Slave CYC   <- Assume the REGS master 
    input           WB_INTC_STB_IN      , // Master: Slave STB   <- decoded high order address
    input           WB_REGS_WE_IN       , // Master: Bus WE
    input   [ 3:0]  WB_REGS_SEL_IN      , // Master: Bus SEL
    output          WB_INTC_ACK_OUT     , // Slave : Slave ACK
    output          WB_INTC_STALL_OUT   , // Slave:  Slave STALL <- asserted with ACK/ERR
    output          WB_INTC_ERR_OUT     , // Slave:  Slave ERRor
    output  [31:0]  WB_INTC_DAT_RD_OUT  , // Slave:  Read data
    input   [31:0]  WB_REGS_DAT_WR_IN   , // Master: Bus Write data

    // Interrupt in / out
    input  [IW-1:0] INT_SOURCE_IN       ,
    output          MIPS_HW_INT_OUT     
    );

   /////////////////////////////////////////////////////////////////////////////
   // parameters - todo ! Move these into a global PSX file

   parameter INTC_SRC_VBLANK = 0  ;
   parameter INTC_SRC_GPU    = 1  ;
   parameter INTC_SRC_CDROM  = 2  ;
   parameter INTC_SRC_DMAC   = 3  ;
   parameter INTC_SRC_RTC0   = 4  ;
   parameter INTC_SRC_RTC1   = 5  ;
   parameter INTC_SRC_RTC2   = 6  ;
   parameter INTC_SRC_CNTL   = 7  ;
   parameter INTC_SRC_SPU    = 8  ;
   parameter INTC_SRC_PIO    = 9  ;
   parameter INTC_SRC_SIO    = 10 ;
   
   parameter [3:0] INTC_IREG  = 4'h0;
   parameter [3:0] INTC_IMASK = 4'h4;

   /////////////////////////////////////////////////////////////////////////////
   // includes

   /////////////////////////////////////////////////////////////////////////////
   // wires / regs

   // Wishbone signals
   wire       WbReadAddrStb  ; // Address phase of a read transaction
   wire       WbWriteAddrStb ; // Address and Write data phase of a write transaction
   wire       WbAddrStb      ; // Combined Address phase (write and read)
   reg        WbAddrStbReg   ; // Registered Address strobe
   wire       WbAddrValid    ; // High when valid address seen (decodes middle order bits)
   wire       WbSelValid     ; // Check for valid byte enable and address low 2 bits
   wire       WbValid        ; // Combination of Addr and Sel
   wire [3:0] WbAddrRegSel   ; // Nibble to select which register is being accessed
	
   // Read data path
   reg [31:0] WbReadDataMux         ;
   reg [31:0] WbReadDataMuxAlign    ;
   reg [31:0] WbReadDataMuxAlignReg ;
   
   // Interrupt mask and registers
   reg  [IW-1:0] CfgIMask      ; // Standard R/W register
   wire 	 IRegWriteEn   ; // Write sensitive interrupt clear
   wire [IW-1:0] IRegWriteData ;

   // Per-Interrupt SR flop and masking
   reg 	  [2:0]     IntSourcePipe [IW-1:0];
   wire	  [IW-1:0]  IntRawSet ;
   wire   [IW-1:0]  IntRawClr ;
   reg    [IW-1:0]  IntRaw    ;
   wire   [IW-1:0]  IntMasked ;


   
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns (internal)
   
   // Decode the incoming wishbone signals
   assign WbReadAddrStb  = WB_INTC_CYC_IN & WB_INTC_STB_IN & ~WB_REGS_WE_IN & ~WB_INTC_STALL_OUT;
   assign WbWriteAddrStb = WB_INTC_CYC_IN & WB_INTC_STB_IN &  WB_REGS_WE_IN & ~WB_INTC_STALL_OUT;
   assign WbAddrStb      = WbReadAddrStb | WbWriteAddrStb;

   assign WbSelValid   = ( ((4'b1111 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[1:0] == 2'b00))
                         | ((4'b1100 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
                         | ((4'b0011 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
                           );
   assign WbAddrValid  = (4'h0 == WB_REGS_ADR_IN[11:8]); // todo tidy up address checks
   assign WbValid      = WbAddrValid & WbSelValid;

   assign WbAddrRegSel = WB_REGS_ADR_IN[3:0];
   
   // Write-sensitive IReg used to clear interrupts
   assign IRegWriteEn   = EN && WbWriteAddrStb && WbValid && (INTC_IMASK == WbAddrRegSel);
   assign IRegWriteData = { {32-IW{1'b0}}, 
			    (WB_REGS_DAT_WR_IN[IW-1:8] & {8{WB_REGS_SEL_IN[1]}}),
			    (WB_REGS_DAT_WR_IN[   7:0] & {8{WB_REGS_SEL_IN[0]}})
			  };			    
			   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns
   assign WB_INTC_STALL_OUT = WbAddrStbReg;
   assign WB_INTC_ACK_OUT   = WbAddrStbReg &  WbValid;
   assign WB_INTC_ERR_OUT   = WbAddrStbReg & ~WbValid;

   assign WB_INTC_DAT_RD_OUT = WbReadDataMuxAlignReg;
   
   /////////////////////////////////////////////////////////////////////////////
   // Wishbone CSR register clocked processes

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
         WbAddrStbReg <= WbAddrStb;
      end
   end
   
   // Register the R/W Control registers. Mask registers are standard R/W ones
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_CONFIG_REG
      if (RST_ASYNC)
      begin
	 CfgIMask <= {IW{1'b0}};
      end
      else if (RST_SYNC)
      begin
      	 CfgIMask <= {IW{1'b0}};
      end
      else if (EN && WbWriteAddrStb && WbValid && (INTC_IMASK == WbAddrRegSel))
      begin
         if (WB_REGS_SEL_IN[0]) CfgIMask[   7:0] <= WB_REGS_DAT_WR_IN[   7:0];
         if (WB_REGS_SEL_IN[1]) CfgIMask[IW-1:8] <= WB_REGS_DAT_WR_IN[IW-1:8];
      end
   end

   // 
   

   // Mux the read data combinatorially
   always @*
   begin : READ_DATA_MUX
      WbReadDataMux = 32'h0000_0000;

      case (WbAddrRegSel)
        INTC_IREG  : WbReadDataMux = { {32-IW{1'b0}}, IntMasked};
	INTC_IMASK : WbReadDataMux = { {32-IW{1'b0}}, CfgIMask };
      endcase
   end

   // Align the data with the byte enables
   always @*
   begin : READ_DATA_ALIGN
      WbReadDataMuxAlign = 32'h0000_0000;

      WbReadDataMuxAlign[ 7:0] = {8{WB_REGS_SEL_IN[0]}} & WbReadDataMux[ 7:0];
      WbReadDataMuxAlign[15:8] = {8{WB_REGS_SEL_IN[1]}} & WbReadDataMux[15:8];
      
   end
   
   // Register the read data before sending back
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_READ_DATA_REG
      if (RST_ASYNC)
      begin
        WbReadDataMuxAlignReg <= 32'h0000_0000;
      end
      else if (RST_SYNC)
      begin
        WbReadDataMuxAlignReg <= 32'h0000_0000;
      end
      else if (EN && WbReadAddrStb && WbValid)
      begin
        WbReadDataMuxAlignReg <= WbReadDataMuxAlign;
      end
   end



   /////////////////////////////////////////////////////////////////////////////
   // Interrupt generate loop logic
   // 			     
   // Chain is Resync -> SR -> Mask -> OR into one signal

   genvar i;

   generate for (i = 0 ; i < IW ; i = i + 1)
   begin : IRQ_PIPE_GEN

      // Generate a pulse in WB domain on a rising edge of resynced IRQ line
      assign IntRawSet[i] = IntSourcePipe[1] & ~IntSourcePipe[0];

      // Clear the un-masked interrupt on a write of 0 to IREG bit
      assign IntRawClr[i] = IRegWriteEn & ~WB_REGS_DAT_WR_IN;

      // Combine the Raw interrupt with the mask register
      assign IntMasked[i] = CfgIMask[i] & IntRaw[i];
      
      // Resynchronise the incoming interrupt sources into WB domain.
      // Shift reg goes 2 -> 1 -> 0.
      always @(posedge CLK or posedge RST_ASYNC)
      begin : INT_SOURCE_RESYNC
	 if (RST_ASYNC)
	 begin
	    IntSourcePipe[i] <= 3'b000;
	 end
	 else if (RST_SYNC)
	 begin
	    IntSourcePipe[i] <= 3'b000;
	 end
	 else if (EN)
	 begin
	    IntSourcePipe[i] <= {INT_SOURCE_IN[i], IntSourcePipe[i][2:1]};
	 end
      end
   
      // S-R Flip flop in the WB domain. Give S priority so no IRQs are missed..
      // Set - On a rising edge of the interrupt source (detected in WB domain)
      // Reset - On a write of 0 to the relevant bit in the IReg register
      always @(posedge CLK or posedge RST_ASYNC)
      begin : INT_SR_FLOP
	 if (RST_ASYNC)
	 begin
	    IntRaw[i] <= 1'b0;
	 end
	 else if (RST_SYNC)
	 begin
	    IntRaw[i] <= 1'b0;
	 end
	 else if (EN)
	 begin
	    if (IntRawSet[i])
	    begin
	       IntRaw[i] <= 1'b1;
	    end
	    else if (IntRawClr[i])
	    begin
	       IntRaw[i] <= 1'b0;
	    end
	 end
      end

   end // block: IRQ_PIPE_GEN
      
   
   endgenerate
   
endmodule // INTC
