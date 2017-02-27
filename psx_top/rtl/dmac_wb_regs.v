//

module DMAC_WB_REGS
   (
    // Clocks and resets
    input           CLK       ,
    input           EN        ,
    input           RST_SYNC  ,
    input           RST_ASYNC ,

    // Wishbone SLAVE interface
    input   [31:0] WB_REGS_ADR_IN      ,
    input          WB_REGS_DMAC_CYC_IN      ,
    input          WB_REGS_DMAC_STB_IN      ,
    input          WB_REGS_WE_IN       ,
    input   [ 3:0] WB_REGS_SEL_IN      ,
    output         WB_REGS_DMAC_ACK_OUT     ,
    output         WB_REGS_DMAC_STALL_OUT   ,
    output         WB_REGS_DMAC_ERR_OUT     ,
    output  [31:0] WB_REGS_DMAC_DAT_RD_OUT  ,
    input   [31:0] WB_REGS_DAT_WR_IN   ,
    
    // Configuration outputs 
    output  [31:0] CFG_DMAC_ICR_OUT    ,
    output  [31:0] CFG_DMAC_PCR_OUT    ,
    
    output  [31:0] CFG_DMAC_MADR0_OUT  ,
    output  [31:0] CFG_DMAC_MADR1_OUT  ,
    output  [31:0] CFG_DMAC_MADR2_OUT  ,
    output  [31:0] CFG_DMAC_MADR3_OUT  ,
    output  [31:0] CFG_DMAC_MADR4_OUT  ,
    output  [31:0] CFG_DMAC_MADR5_OUT  ,
    output  [31:0] CFG_DMAC_MADR6_OUT  ,
    
    output  [31:0] CFG_DMAC_BCR0_OUT   ,
    output  [31:0] CFG_DMAC_BCR1_OUT   ,
    output  [31:0] CFG_DMAC_BCR2_OUT   ,
    output  [31:0] CFG_DMAC_BCR3_OUT   ,
    output  [31:0] CFG_DMAC_BCR4_OUT   ,
    output  [31:0] CFG_DMAC_BCR5_OUT   ,
    output  [31:0] CFG_DMAC_BCR6_OUT   ,

    // CHCR has only 4 bits, and a self-clearing bit. Split it into separate
    // bits and combine into buses by DMA channel.
    output  [ 6:0] CFG_DMAC_CHCR_DR_OUT     ,
    output  [ 6:0] CFG_DMAC_CHCR_CO_OUT     ,
    output  [ 6:0] CFG_DMAC_CHCR_LI_OUT     ,
    output  [ 6:0] CFG_DMAC_CHCR_TR_OUT     ,   
    input   [ 6:0] CFG_DMAC_CHCR_TR_CLR_IN  
       
    );

   /////////////////////////////////////////////////////////////////////////////
// parameters - todo ! Move these into a global PSX file

   /////////////////////////////////////////////////////////////////////////////
   // includes
`include "psx_mem_map.vh"
   
   /////////////////////////////////////////////////////////////////////////////
   // wires / regs

   // Wishbone signals
   wire      WbReadAddrStb  ; // Address phase of a read transaction
   wire      WbWriteAddrStb ; // Address and Write data phase of a write transaction
   wire      WbAddrStb      ; // Combined Address phase (write and read)
//   reg             WbAddrStbReg   ; // Registered Address strobe
   wire      WbAddrValid    ; // High when valid address seen (decodes middle order bits)
   wire      WbSelValid     ; // Check for valid byte enable and address low 2 bits
   wire      WbValid        ; // Combination of Addr and Sel

      // Read data path
   reg [31:0] WbReadDataMux         ;
   reg [31:0] WbReadDataMuxAlign    ;
   reg [31:0] WbReadDataMuxAlignReg ;

   // Channel and register
   // Per-channel setup
   wire [2:0] DmacChSel;
   wire       DmacMadrSel;
   wire       DmacBcrSel ;
   wire       DmacChcrSel;

   // Register select for common regs
   wire       DmacPcrSel;
   wire       DmacIcrSel;

   // registers for the config
   reg [31:0] CfgDmacIcr;
   reg [31:0] CfgDmacPcr;
   reg [31:0] CfgDmacMadr [6:0];
   reg [31:0] CfgDmacBcr  [6:0];

//   reg [31:0] CfgDmacChcr [6:0];
// Split the CHCR into individual bits
   reg [ 6:0] CfgDmacChcrDr;
   reg [ 6:0] CfgDmacChcrCo;
   reg [ 6:0] CfgDmacChcrLi;
   reg [ 6:0] CfgDmacChcrTr;  
  
   
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns (internal)
   
   // Decode the incoming wishbone signals
//   assign WbReadAddrStb  = WB_REGS_DMAC_CYC_IN & WB_REGS_DMAC_STB_IN & ~WB_REGS_WE_IN & ~WB_REGS_DMAC_STALL_OUT;
//   assign WbWriteAddrStb = WB_REGS_DMAC_CYC_IN & WB_REGS_DMAC_STB_IN &  WB_REGS_WE_IN & ~WB_REGS_DMAC_STALL_OUT;
   assign WbAddrStb      = WbReadAddrStb | WbWriteAddrStb;

//   assign WbSelValid   = ( ((4'b1111 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[1:0] == 2'b00))
//                         | ((4'b1100 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
//                         | ((4'b0011 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
//                         );
//   assign WbAddrValid  = (4'h0 == WB_REGS_ADR_IN[11:8]); // todo tidy up address checks
//   assign WbValid      = WbAddrValid & WbSelValid;

   // Decode the channel and type of register
   assign DmacChSel   = WB_REGS_ADR_IN[DMAC_CH_SEL_MSB:DMAC_CH_SEL_LSB];
   assign DmacMadrSel = (DMAC_REG_SEL_MADR == WB_REGS_ADR_IN[DMAC_REG_SEL_MSB:DMAC_REG_SEL_LSB]);
   assign DmacBcrSel  = (DMAC_REG_SEL_BCR  == WB_REGS_ADR_IN[DMAC_REG_SEL_MSB:DMAC_REG_SEL_LSB]);
   assign DmacChcrSel = (DMAC_REG_SEL_CHCR == WB_REGS_ADR_IN[DMAC_REG_SEL_MSB:DMAC_REG_SEL_LSB]);

   assign DmacPcrSel  = (8'hf0 == WB_REGS_ADR_IN[7:0]);
   assign DmacIcrSel  = (8'hf4 == WB_REGS_ADR_IN[7:0]);
   
   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns
   // MOVED TO REGS SLAVE
//   assign WB_REGS_DMAC_STALL_OUT = WbAddrStbReg;
//   assign WB_REGS_DMAC_ACK_OUT   = WbAddrStbReg &  WbValid;
//   assign WB_REGS_DMAC_ERR_OUT   = WbAddrStbReg & ~WbValid;

   assign WB_REGS_DMAC_DAT_RD_OUT = WbReadDataMuxAlignReg;

   assign CFG_DMAC_ICR_OUT   = CfgDmacIcr;
   assign CFG_DMAC_PCR_OUT   = CfgDmacPcr;
   
   assign CFG_DMAC_MADR0_OUT = CfgDmacMadr[0];
   assign CFG_DMAC_MADR1_OUT = CfgDmacMadr[1];
   assign CFG_DMAC_MADR2_OUT = CfgDmacMadr[2];
   assign CFG_DMAC_MADR3_OUT = CfgDmacMadr[3];
   assign CFG_DMAC_MADR4_OUT = CfgDmacMadr[4];
   assign CFG_DMAC_MADR5_OUT = CfgDmacMadr[5];
   assign CFG_DMAC_MADR6_OUT = CfgDmacMadr[6];

   assign CFG_DMAC_BCR0_OUT  = CfgDmacBcr[0];
   assign CFG_DMAC_BCR1_OUT  = CfgDmacBcr[1];
   assign CFG_DMAC_BCR2_OUT  = CfgDmacBcr[2];
   assign CFG_DMAC_BCR3_OUT  = CfgDmacBcr[3];
   assign CFG_DMAC_BCR4_OUT  = CfgDmacBcr[4];
   assign CFG_DMAC_BCR5_OUT  = CfgDmacBcr[5];
   assign CFG_DMAC_BCR6_OUT  = CfgDmacBcr[6];


   assign CFG_DMAC_CHCR_TR_OUT = CfgDmacChcrTr;
   assign CFG_DMAC_CHCR_LI_OUT = CfgDmacChcrLi;
   assign CFG_DMAC_CHCR_CO_OUT = CfgDmacChcrCo;
   assign CFG_DMAC_CHCR_DR_OUT = CfgDmacChcrDr;

   /////////////////////////////////////////////////////////////////////////////
   // clocked processes

   // Register the ICR (common regs to all channels)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : CFG_DMAC_ICR_REG
      if (RST_ASYNC)
      begin
         CfgDmacIcr <= 32'h0000_0000;
      end
      else if (RST_SYNC)
      begin
         CfgDmacIcr <= 32'h0000_0000;
      end
      else if (EN && WbValid && WbWriteAddrStb && DmacIcrSel)
      begin
         if (WB_REGS_SEL_IN[0]) CfgDmacIcr[ 7: 0] <= WB_REGS_DAT_WR_IN[ 7: 0];
         if (WB_REGS_SEL_IN[1]) CfgDmacIcr[15: 8] <= WB_REGS_DAT_WR_IN[15: 8];
         if (WB_REGS_SEL_IN[2]) CfgDmacIcr[23:16] <= WB_REGS_DAT_WR_IN[23:16];
         if (WB_REGS_SEL_IN[3]) CfgDmacIcr[31:24] <= WB_REGS_DAT_WR_IN[31:24];
      end
   end
   
   // Register the PCR (common regs to all channels)
   // Reset value is 0x0765_4321 (from nocash website)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMAC_PCR_REG
      if (RST_ASYNC)
      begin
         CfgDmacPcr <= 32'h0765_4321;
      end
      else if (RST_SYNC)
      begin
         CfgDmacPcr <= 32'h0765_4321;
      end
      else if (EN && WbValid && WbWriteAddrStb && DmacPcrSel)
      begin
         if (WB_REGS_SEL_IN[0]) CfgDmacPcr[ 7: 0] <= WB_REGS_DAT_WR_IN[ 7: 0];
         if (WB_REGS_SEL_IN[1]) CfgDmacPcr[15: 8] <= WB_REGS_DAT_WR_IN[15: 8];
         if (WB_REGS_SEL_IN[2]) CfgDmacPcr[23:16] <= WB_REGS_DAT_WR_IN[23:16];
         if (WB_REGS_SEL_IN[3]) CfgDmacPcr[31:24] <= WB_REGS_DAT_WR_IN[31:24];
      end
   end

   // Generate a loop of Madr registers
   genvar MadrChLoop;
   generate for (MadrChLoop = 0 ; MadrChLoop <= 6 ; MadrChLoop = MadrChLoop + 1)
   begin : MADR_GEN
      
      always @(posedge CLK or posedge RST_ASYNC)
      begin : DMAC_MADR_REG
         if (RST_ASYNC)
         begin
            CfgDmacMadr[MadrChLoop] <= 32'h0000_0000;
         end
         else if (RST_SYNC)
         begin
            CfgDmacMadr[MadrChLoop] <= 32'h0000_0000;
         end
         else if (EN && WbValid && WbWriteAddrStb && (MadrChLoop == DmacChSel) && DmacMadrSel)
         begin
            if (WB_REGS_SEL_IN[0]) CfgDmacMadr[MadrChLoop][ 7: 0] <= WB_REGS_DAT_WR_IN[ 7: 0];
            if (WB_REGS_SEL_IN[1]) CfgDmacMadr[MadrChLoop][15: 8] <= WB_REGS_DAT_WR_IN[15: 8];
            if (WB_REGS_SEL_IN[2]) CfgDmacMadr[MadrChLoop][23:16] <= WB_REGS_DAT_WR_IN[23:16];
            if (WB_REGS_SEL_IN[3]) CfgDmacMadr[MadrChLoop][31:24] <= WB_REGS_DAT_WR_IN[31:24];
         end
      end
   end
   endgenerate
   
   // Generate a loop of Bcr registers
   genvar BcrChLoop;
   generate for (BcrChLoop = 0 ; BcrChLoop <= 6 ; BcrChLoop = BcrChLoop + 1)
   begin : BCR_GEN
      
      always @(posedge CLK or posedge RST_ASYNC)
      begin : DMAC_BCR_REG
         if (RST_ASYNC)
         begin
            CfgDmacBcr[BcrChLoop] <= 32'h0000_0000;
         end
         else if (RST_SYNC)
         begin
            CfgDmacBcr[BcrChLoop] <= 32'h0000_0000;
         end
         else if (EN && WbValid && WbWriteAddrStb && (BcrChLoop == DmacChSel) && DmacBcrSel)
         begin
            if (WB_REGS_SEL_IN[0]) CfgDmacBcr[BcrChLoop][ 7: 0] <= WB_REGS_DAT_WR_IN[ 7: 0];
            if (WB_REGS_SEL_IN[1]) CfgDmacBcr[BcrChLoop][15: 8] <= WB_REGS_DAT_WR_IN[15: 8];
            if (WB_REGS_SEL_IN[2]) CfgDmacBcr[BcrChLoop][23:16] <= WB_REGS_DAT_WR_IN[23:16];
            if (WB_REGS_SEL_IN[3]) CfgDmacBcr[BcrChLoop][31:24] <= WB_REGS_DAT_WR_IN[31:24];
         end
      end
   end
   endgenerate

   // CHCR is a bit different, split into single bits with a self clearing register
   genvar ChcrChLoop;
   generate for (ChcrChLoop = 0 ; ChcrChLoop <= 6 ; ChcrChLoop = ChcrChLoop + 1)
   begin : CHCR_GEN

      // DR bit (bit [0] in bottom byte)
      always @(posedge CLK or posedge RST_ASYNC)
      begin : DMAC_CHCR_REG_DR
         if (RST_ASYNC)
         begin
            CfgDmacChcrDr[ChcrChLoop] <= 1'b0;
         end
         else if (RST_SYNC)
         begin
            CfgDmacChcrDr[ChcrChLoop] <= 1'b0;
         end
         else if (EN && WbValid && WbWriteAddrStb && (ChcrChLoop == DmacChSel) && DmacChcrSel)
         begin
            if (WB_REGS_SEL_IN[0]) CfgDmacChcrDr[ChcrChLoop] <= WB_REGS_DAT_WR_IN[DMAC_CHCR_DR_BIT];
         end
      end

      // CO bit (bit [1] in 2nd to bottom byte)
      always @(posedge CLK or posedge RST_ASYNC)
      begin : DMAC_CHCR_REG_CO
         if (RST_ASYNC)
         begin
            CfgDmacChcrCo[ChcrChLoop] <= 1'b0;
         end
         else if (RST_SYNC)
         begin
            CfgDmacChcrCo[ChcrChLoop] <= 1'b0;
         end
         else if (EN && WbValid && WbWriteAddrStb && (ChcrChLoop == DmacChSel) && DmacChcrSel)
         begin
            if (WB_REGS_SEL_IN[1]) CfgDmacChcrCo[ChcrChLoop] <= WB_REGS_DAT_WR_IN[DMAC_CHCR_CO_BIT-8];
         end
      end

      // LI bit (bit [2] in 2nd to bottom byte)
      always @(posedge CLK or posedge RST_ASYNC)
      begin : DMAC_CHCR_REG_LI
         if (RST_ASYNC)
         begin
            CfgDmacChcrLi[ChcrChLoop] <= 1'b0;
         end
         else if (RST_SYNC)
         begin
            CfgDmacChcrLi[ChcrChLoop] <= 1'b0;
         end
         else if (EN && WbValid && WbWriteAddrStb && (ChcrChLoop == DmacChSel) && DmacChcrSel)
         begin
            if (WB_REGS_SEL_IN[1]) CfgDmacChcrLi[ChcrChLoop] <= WB_REGS_DAT_WR_IN[DMAC_CHCR_LI_BIT-8];
         end
      end

      // TR bit can be SET by a write to bit [0] in top byte)
      // Can also be cleared by CFG_DMAC_CHCR_TR_CLR_IN pulse
      always @(posedge CLK or posedge RST_ASYNC)
      begin : DMAC_CHCR_REG_TR
         if (RST_ASYNC)
         begin
            CfgDmacChcrTr[ChcrChLoop] <= 1'b0;
         end
         else if (RST_SYNC)
         begin
            CfgDmacChcrTr[ChcrChLoop] <= 1'b0;
         end
         // SET
         else if (EN && WbValid && WbWriteAddrStb && (ChcrChLoop == DmacChSel) && DmacChcrSel)
         begin
            if (WB_REGS_SEL_IN[3]) CfgDmacChcrTr[ChcrChLoop] <= WB_REGS_DAT_WR_IN[DMAC_CHCR_TR_BIT-24];
         end
         // CLR
         else if (CFG_DMAC_CHCR_TR_CLR_IN[ChcrChLoop])
         begin
            CfgDmacChcrTr[ChcrChLoop] <= 1'b0;
         end
      end
      
   end
   endgenerate
   
   // Mux all the various config combinatorially
   always @*
   begin : WB_RD_DAT_MUX

      WbReadDataMux = 32'h0000_0000;

      case (1'b1)
        DmacMadrSel : WbReadDataMux = CfgDmacMadr[DmacChSel];
        DmacBcrSel  : WbReadDataMux = CfgDmacBcr [DmacChSel];
        DmacChcrSel : 
           begin
              WbReadDataMux[DMAC_CHCR_TR_BIT] = CfgDmacChcrTr[DmacChSel];
              WbReadDataMux[DMAC_CHCR_LI_BIT] = CfgDmacChcrLi[DmacChSel];
              WbReadDataMux[DMAC_CHCR_CO_BIT] = CfgDmacChcrCo[DmacChSel];
              WbReadDataMux[DMAC_CHCR_DR_BIT] = CfgDmacChcrDr[DmacChSel];
           end
        DmacPcrSel  : WbReadDataMux = CfgDmacPcr;
        DmacIcrSel  : WbReadDataMux = CfgDmacIcr;
      endcase
      
   end
     
   // Align the data to be read back
   always @*
   begin : WB_RD_DAT_ALIGN

      WbReadDataMuxAlign = 32'h0000_0000;

      WbReadDataMuxAlign[ 7: 0] = {8{WB_REGS_SEL_IN[0]}} & WbReadDataMux[ 7: 0];
      WbReadDataMuxAlign[15: 8] = {8{WB_REGS_SEL_IN[1]}} & WbReadDataMux[15: 8];
      WbReadDataMuxAlign[23:16] = {8{WB_REGS_SEL_IN[2]}} & WbReadDataMux[23:16];
      WbReadDataMuxAlign[31:24] = {8{WB_REGS_SEL_IN[3]}} & WbReadDataMux[31:24];
     
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
   // module instantiations

   WB_SLAVE_CTRL
      #(.WB_ADDR_MSB (11),
        .WB_ADDR_LSB ( 8),
        .WB_ADDR_VAL ( 0)
        )
      wb_slave_ctrl
      (
       .CLK                   (CLK        ),
       .EN                    (EN         ),
       .RST_SYNC              (RST_SYNC   ),
       .RST_ASYNC             (RST_ASYNC  ),
       
       .WB_REGS_ADR_IN        (WB_REGS_ADR_IN           ), 
       .WB_REGS_CYC_IN        (WB_REGS_DMAC_CYC_IN      ), 
       .WB_REGS_STB_IN        (WB_REGS_DMAC_STB_IN      ), 
       .WB_REGS_WE_IN         (WB_REGS_WE_IN            ), 
       .WB_REGS_SEL_IN        (WB_REGS_SEL_IN           ), 
       .WB_REGS_ACK_OUT       (WB_REGS_DMAC_ACK_OUT     ), 
       .WB_REGS_STALL_OUT     (WB_REGS_DMAC_STALL_OUT   ), 
       .WB_REGS_ERR_OUT       (WB_REGS_DMAC_ERR_OUT     ), 
       
       .WB_WRITE_ADDR_STB_OUT (WbWriteAddrStb ),
       .WB_READ_ADDR_STB_OUT  (WbReadAddrStb  ),
       .WB_VALID_OUT          (WbValid        )
       );
   






   
  
endmodule
