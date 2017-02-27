// Insert module header here

module ROOT_CNT
   (
    // Clocks and resets
    input           CLK       ,
    input           EN        ,
    input           RST_SYNC  ,
    input           RST_ASYNC ,

    // Wishbone register slave interface
    input   [31:0] WB_REGS_ADR_IN           , // Master: Bus Address
    input          WB_REGS_RCNT_CYC_IN      , // Master: Slave CYC   <- Assume the REGS master 
    input          WB_REGS_RCNT_STB_IN      , // Master: Slave STB   <- decoded high order address
    input          WB_REGS_WE_IN            , // Master: Bus WE
    input   [ 3:0] WB_REGS_SEL_IN           , // Master: Bus SEL
    output         WB_REGS_RCNT_ACK_OUT     , // Slave : Slave ACK
    output         WB_REGS_RCNT_STALL_OUT   , // Slave:  Slave STALL <- asserted with ACK/ERR
    output         WB_REGS_RCNT_ERR_OUT     , // Slave:  Slave ERRor
    output  [31:0] WB_REGS_RCNT_DAT_RD_OUT  , // Slave:  Read data
    input   [31:0] WB_REGS_DAT_WR_IN        , // Master: Bus Write data
    
    // Video controller timing (only VSYNC used currently)
    input          WB_VS_STB_IN,
    input          WB_HS_STB_IN,
    input          WB_ACTIVE_ROW_IN,
    input          WB_ACTIVE_COL_IN,

    // Output IRQ lines
    output  [3:0]  RCNT_IRQ_OUT
    
    );
   /////////////////////////////////////////////////////////////////////////////
// parameters - todo ! Move these into a global PSX file
   parameter [1:0] RCNT_COUNT  = 2'b00; // 4'h0;
   parameter [1:0] RCNT_MODE   = 2'b01; // 4'h4;
   parameter [1:0] RCNT_TARGET = 2'b10; // 4'h8;

   parameter RCNT_CNT_SEL_MSB = 5;
   parameter RCNT_CNT_SEL_LSB = 4;
   parameter RCNT_REG_SEL_MSB = 3;
   parameter RCNT_REG_SEL_LSB = 2;
   
   // mode register bitfields
   parameter RCNT_MODE_EN_BIT   = 0;
   parameter RCNT_MODE_TGT_BIT  = 3;
   parameter RCNT_MODE_IRQ1_BIT = 4;
   parameter RCNT_MODE_IRQ2_BIT = 6;
   parameter RCNT_MODE_SRC_BIT  = 8;
   parameter RCNT_MODE_DIV_BIT  = 9;
   
   // target register bitfields
   parameter RCNT_TARGET_MSB   = 15;
   parameter RCNT_TARGET_LSB   = 0;

   // Fractional amount to increment on WB_CLK to represent VGA_CLK cycles
   parameter [8:0] VGA_DIV_WB_RATIO = 9'h0_C1;
   
   /////////////////////////////////////////////////////////////////////////////
   // includes

   /////////////////////////////////////////////////////////////////////////////
   // wires / regs

   // Wishbone signals
   wire      WbReadAddrStb  ; // Address phase of a read transaction
   wire      WbWriteAddrStb ; // Address and Write data phase of a write transaction
   wire      WbAddrStb      ; // Combined Address phase (write and read)
   reg       WbAddrStbReg   ; // Registered Address strobe
   wire      WbAddrValid    ; // High when valid address seen (decodes middle order bits)
   wire      WbSelValid     ; // Check for valid byte enable and address low 2 bits
   wire      WbValid        ; // Combination of Addr and Sel
   
   wire [1:0] WbAddrCntSel  ; // Selects which counter
   wire [1:0] WbAddrRegSel  ; // Selects which counter register 
   
   // Register signals (config and status). [3:0] are individual bits going to each counter
   reg [3:0] CfgDiv  ;
   reg [3:0] CfgSrc  ;
   reg [3:0] CfgIrq1 ;
   reg [3:0] CfgIrq2 ;
   reg [3:0] CfgTgt  ;
   reg [3:0] CfgEn   ;
 
   // Shame xilinx doesn't support 2d arrays ..  
   reg [15:0] CfgTarget0;
   reg [15:0] CfgTarget1;
   reg [15:0] CfgTarget2;

   // Read data path
   reg [31:0] WbReadDataMux         ;
   reg [31:0] WbReadDataMuxAlign    ;
   reg [31:0] WbReadDataMuxAlignReg ;
   
   // Counter signals
   wire       Rcnt0Clr;
   wire       Rcnt1Clr;
   wire       Rcnt2Clr;
   wire       Rcnt0Wrap;
   wire       Rcnt1Wrap;
   wire       Rcnt2Wrap;
   wire       Rcnt0Match;
   wire       Rcnt1Match;
   wire       Rcnt2Match;

   wire       PclkInc;
   wire       Rcnt0Inc;
   wire [8:0] Rcnt0IncVal;      

   wire       Rcnt1Inc;
   
   reg  [23:0] RootCnt0Val;     // Root counter 0 counts in units of PCLK. 16-bits int, 8-bit frac
   wire [15:0] RootCnt0ValInt;  // Root counter 0 counts in units of PCLK. 
   wire [ 7:0] RootCnt0ValFrac; // Root counter 0 counts in units of PCLK. 
   reg  [15:0] RootCnt1Val;
   reg  [15:0] RootCnt2Val;

   reg [3:0]  Div8CntVal;
   wire       Div8En;

   wire       Rcnt0Irq;
   wire       Rcnt1Irq;
   wire       Rcnt2Irq;
   wire       Rcnt3Irq;
   
   reg        Rcnt0IrqReg;
   reg        Rcnt1IrqReg;
   reg        Rcnt2IrqReg;
   reg        Rcnt3IrqReg;
  
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns (internal)
   
   // Decode the incoming wishbone signals
// MOVED WB REGS TO MODULE
//   assign WbReadAddrStb  = WB_REGS_RCNT_CYC_IN & WB_REGS_RCNT_STB_IN & ~WB_REGS_WE_IN & ~WB_REGS_RCNT_STALL_OUT;
//   assign WbWriteAddrStb = WB_REGS_RCNT_CYC_IN & WB_REGS_RCNT_STB_IN &  WB_REGS_WE_IN & ~WB_REGS_RCNT_STALL_OUT;

   assign WbAddrStb      = WbReadAddrStb | WbWriteAddrStb;
//
//   assign WbSelValid   = ( ((4'b1111 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[1:0] == 2'b00))
//                         | ((4'b1100 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
//                         | ((4'b0011 == WB_REGS_SEL_IN) && (WB_REGS_ADR_IN[  0] == 1'b0 ))
//                         );
//   assign WbAddrValid  = (4'h1 == WB_REGS_ADR_IN[11:8]); // todo tidy up address checks
//   assign WbValid      = WbAddrValid & WbSelValid;

   assign WbAddrCntSel = WB_REGS_ADR_IN[RCNT_CNT_SEL_MSB:RCNT_CNT_SEL_LSB];
   assign WbAddrRegSel = WB_REGS_ADR_IN[RCNT_REG_SEL_MSB:RCNT_REG_SEL_LSB];


   // Root counter 0 integer and fractional
   assign RootCnt0ValInt  = RootCnt0Val[23:8];
   assign RootCnt0ValFrac = RootCnt0Val[ 7:0];

   // If the src bit is 1, increment counter on each PCLK. Actually increment by PCLK / WB clock
   // ratio on every WB_CLK time period
   assign PclkInc     = WB_ACTIVE_ROW_IN & WB_ACTIVE_COL_IN;
   assign Rcnt0Inc    = CfgSrc[0] ? PclkInc          : 1'b1;
   assign Rcnt0IncVal = CfgSrc[0] ? VGA_DIV_WB_RATIO : 9'h100;

   // Counter 1 can be set to hsync (src = 1) or normal clock
   assign Rcnt1Inc    = CfgSrc[1] ? WB_ACTIVE_ROW_IN & WB_HS_STB_IN : 1'b1;
   
   // counter combinatorial

   assign Rcnt0Wrap = | RootCnt0ValInt;
   assign Rcnt1Wrap = | RootCnt1Val;
   assign Rcnt2Wrap = | RootCnt2Val;

   assign Rcnt0Match = (RootCnt0ValInt == CfgTarget0);
   assign Rcnt1Match = (RootCnt1Val == CfgTarget1);
   assign Rcnt2Match = (RootCnt2Val == CfgTarget2);
   
   assign Rcnt0Clr = CfgTgt[0] ? Rcnt0Match : Rcnt0Wrap;
   assign Rcnt1Clr = CfgTgt[1] ? Rcnt1Match : Rcnt1Wrap;
   assign Rcnt2Clr = CfgTgt[2] ? Rcnt2Match : Rcnt2Wrap;
   
   assign Div8En = (4'd7 == Div8CntVal);
   
   assign Rcnt0Irq = CfgEn[0] & Rcnt0Clr & CfgIrq1[0] & CfgIrq2[0];
   assign Rcnt1Irq = CfgEn[1] & Rcnt1Clr & CfgIrq1[1] & CfgIrq2[1];
   assign Rcnt2Irq = CfgEn[2] & Rcnt2Clr & CfgIrq1[2] & CfgIrq2[2];
   assign Rcnt3Irq = CfgEn[3] & WB_VS_STB_IN & CfgIrq1[3] & CfgIrq2[3];

   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns
// MOVED to regs slave
//   assign WB_REGS_RCNT_STALL_OUT = WbAddrStbReg;
//   assign WB_REGS_RCNT_ACK_OUT   = WbAddrStbReg &  WbValid;
//   assign WB_REGS_RCNT_ERR_OUT   = WbAddrStbReg & ~WbValid;

   assign WB_REGS_RCNT_DAT_RD_OUT = WbReadDataMuxAlignReg;
   
   /////////////////////////////////////////////////////////////////////////////
   // clocked processes

// MOVED to regs slave
//   // Register the address strobe for use in generating ACK / ERR
//   always @(posedge CLK or posedge RST_ASYNC)
//   begin : WB_ADDR_STB_REG
//      if (RST_ASYNC)
//      begin
//       WbAddrStbReg <= 1'b0;
//      end
//      else if (RST_SYNC)
//      begin
//       WbAddrStbReg <= 1'b0;
//      end
//      else if (EN)
//      begin
//       WbAddrStbReg <= WbAddrStb;
//      end
//   end
//
   
   // Register the R/W Control registers (1-bit config settings)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_CONFIG_REG
      if (RST_ASYNC)
      begin
         CfgDiv  <= 4'h0;
         CfgSrc  <= 4'h0;
         CfgIrq1 <= 4'h0;
         CfgIrq2 <= 4'h0;
         CfgTgt  <= 4'h0;
         CfgEn   <= 4'h0;
      end
      else if (RST_SYNC)
      begin
         CfgDiv  <= 4'h0;
         CfgSrc  <= 4'h0;
         CfgIrq1 <= 4'h0;
         CfgIrq2 <= 4'h0;
         CfgTgt  <= 4'h0;
         CfgEn   <= 4'h0;
      end
      else if (EN && WbWriteAddrStb && WbValid && (RCNT_MODE == WbAddrRegSel))
      begin
         if (WB_REGS_SEL_IN[0])
         begin
            CfgIrq1 [WbAddrCntSel] <= WB_REGS_DAT_WR_IN[RCNT_MODE_IRQ1_BIT ];
            CfgIrq2 [WbAddrCntSel] <= WB_REGS_DAT_WR_IN[RCNT_MODE_IRQ2_BIT ];
            CfgTgt  [WbAddrCntSel] <= WB_REGS_DAT_WR_IN[RCNT_MODE_TGT_BIT  ];
            CfgEn   [WbAddrCntSel] <= WB_REGS_DAT_WR_IN[RCNT_MODE_EN_BIT   ];
         end

         if (WB_REGS_SEL_IN[1])
         begin
            CfgDiv  [WbAddrCntSel] <= WB_REGS_DAT_WR_IN[RCNT_MODE_DIV_BIT  ];
            CfgSrc  [WbAddrCntSel] <= WB_REGS_DAT_WR_IN[RCNT_MODE_SRC_BIT  ];
         end
      end
   end
   
   // Register the R/W Control registers (16-bit target settings)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_TARGET_REG
      if (RST_ASYNC)
      begin
         CfgTarget0 <= 16'h0000;
         CfgTarget1 <= 16'h0000;
         CfgTarget2 <= 16'h0000;
      end
      else if (RST_SYNC)
      begin
         CfgTarget0 <= 16'h0000;
         CfgTarget1 <= 16'h0000;
         CfgTarget2 <= 16'h0000;
      end
      else if (EN && WbWriteAddrStb && WbValid && (RCNT_TARGET == WbAddrRegSel))
      begin
         case (WbAddrCntSel)
           2'd0 : 
              begin
                 if (WB_REGS_SEL_IN[0]) CfgTarget0[ 7:0] <= WB_REGS_DAT_WR_IN[ 7:0];
                 if (WB_REGS_SEL_IN[1]) CfgTarget0[15:8] <= WB_REGS_DAT_WR_IN[15:8];
              end
           2'd1 : 
              begin
                 if (WB_REGS_SEL_IN[0]) CfgTarget1[ 7:0] <= WB_REGS_DAT_WR_IN[ 7:0];
                 if (WB_REGS_SEL_IN[1]) CfgTarget1[15:8] <= WB_REGS_DAT_WR_IN[15:8];
              end
           2'd2 :
              begin
                 if (WB_REGS_SEL_IN[0]) CfgTarget2[ 7:0] <= WB_REGS_DAT_WR_IN[ 7:0];
                 if (WB_REGS_SEL_IN[1]) CfgTarget2[15:8] <= WB_REGS_DAT_WR_IN[15:8];
              end
         endcase
      end
   end

   // Mux the read data combinatorially
   always @*
   begin : READ_DATA_MUX
      WbReadDataMux = 32'h0000_0000;

      // First index by the type of register being read back, then by the counter number.
      case (WbAddrRegSel)
        RCNT_COUNT :
           begin
              case (WbAddrCntSel)
                2'd0 : WbReadDataMux[RCNT_TARGET_MSB:RCNT_TARGET_LSB] = RootCnt0ValInt;
                2'd1 : WbReadDataMux[RCNT_TARGET_MSB:RCNT_TARGET_LSB] = RootCnt1Val;
                2'd2 : WbReadDataMux[RCNT_TARGET_MSB:RCNT_TARGET_LSB] = RootCnt2Val;
              endcase
           end
        
        RCNT_MODE :
           begin
              WbReadDataMux[RCNT_MODE_EN_BIT   ] = CfgDiv [WbAddrCntSel];
              WbReadDataMux[RCNT_MODE_TGT_BIT  ] = CfgSrc [WbAddrCntSel];
              WbReadDataMux[RCNT_MODE_IRQ1_BIT ] = CfgIrq1[WbAddrCntSel];
              WbReadDataMux[RCNT_MODE_IRQ2_BIT ] = CfgIrq2[WbAddrCntSel];
              WbReadDataMux[RCNT_MODE_SRC_BIT  ] = CfgTgt [WbAddrCntSel];
              WbReadDataMux[RCNT_MODE_DIV_BIT  ] = CfgEn  [WbAddrCntSel];
           end
        
        RCNT_TARGET :
           begin
              case (WbAddrCntSel)
                2'd0 : WbReadDataMux[RCNT_TARGET_MSB:RCNT_TARGET_LSB] = CfgTarget0;
                2'd1 : WbReadDataMux[RCNT_TARGET_MSB:RCNT_TARGET_LSB] = CfgTarget1;
                2'd2 : WbReadDataMux[RCNT_TARGET_MSB:RCNT_TARGET_LSB] = CfgTarget2;
              endcase
           end
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

   // Root Counter 0
   always @(posedge CLK or posedge RST_ASYNC)
   begin : ROOT_CNT_0
      if (RST_ASYNC)
      begin
         RootCnt0Val <= 23'h0000_00;
      end
      else if (RST_SYNC || Rcnt0Clr)
      begin
         RootCnt0Val <= 23'h0000_00;
      end
      else if (EN && CfgEn[0] && Rcnt0Inc)
      begin
         RootCnt0Val <= RootCnt0Val + Rcnt0IncVal;
      end
   end
   
   // Root Counter 1
   always @(posedge CLK or posedge RST_ASYNC)
   begin : ROOT_CNT_1
      if (RST_ASYNC)
      begin
         RootCnt1Val <= 16'h0000;
      end
      else if (RST_SYNC || Rcnt1Clr)
      begin
         RootCnt1Val <= 16'h0000;
      end
      else if (EN && CfgEn[1] && Rcnt1Inc)
      begin
         RootCnt1Val <= RootCnt1Val + 16'd1;
      end
   end
   
   // Root Counter 2
   always @(posedge CLK or posedge RST_ASYNC)
   begin : ROOT_CNT_2
      if (RST_ASYNC)
      begin
         RootCnt2Val <= 16'h0000;
      end
      else if (RST_SYNC || Rcnt2Clr)
      begin
         RootCnt2Val <= 16'h0000;
      end
      else if (EN && CfgEn[1])
      begin
         RootCnt2Val <= RootCnt2Val + 16'd1;
      end
   end
   
   // Divide-by-8 counter to produce a strobe every 8 cycles
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DIV8_CNT
      if (RST_ASYNC)
      begin
         Div8CntVal <= 4'd0;
      end
      else if (RST_SYNC || !CfgDiv[2] || Div8En)
      begin
         Div8CntVal <= 4'd0;
      end
      else if (EN && CfgDiv[2])
      begin
         Div8CntVal <= Div8CntVal + 4'd1;
         
      end
   end

   // Register IRQs out to the IRQ controller
   always @(posedge CLK or posedge RST_ASYNC)
   begin : RCNT_IRQ0_REG
      if (RST_ASYNC)
      begin
         Rcnt0IrqReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         Rcnt0IrqReg <= 1'b0;
      end
      else if (EN)
      begin
         Rcnt0IrqReg <= Rcnt0Irq;
      end
   end
 
   always @(posedge CLK or posedge RST_ASYNC)
   begin : RCNT_IRQ1_REG
      if (RST_ASYNC)
      begin
         Rcnt1IrqReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         Rcnt1IrqReg <= 1'b0;
      end
      else if (EN)
      begin
         Rcnt1IrqReg <= Rcnt1Irq;
      end
   end
 
   always @(posedge CLK or posedge RST_ASYNC)
   begin : RCNT_IRQ2_REG
      if (RST_ASYNC)
      begin
         Rcnt2IrqReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         Rcnt2IrqReg <= 1'b0;
      end
      else if (EN)
      begin
         Rcnt2IrqReg <= Rcnt2Irq;
      end
   end
 
   always @(posedge CLK or posedge RST_ASYNC)
   begin : RCNT_IRQ3_REG
      if (RST_ASYNC)
      begin
         Rcnt3IrqReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         Rcnt3IrqReg <= 1'b0;
      end
      else if (EN)
      begin
         Rcnt3IrqReg <= Rcnt3Irq;
      end
   end

   /////////////////////////////////////////////////////////////////////////////
   // module instantiations

   WB_SLAVE_CTRL 
      #(.WB_ADDR_MSB (11),
	.WB_ADDR_LSB ( 8),
	.WB_ADDR_VAL ( 1)
	)
   wb_slave_ctrl
      (
       .CLK                   (CLK        ),
       .EN                    (EN         ),
       .RST_SYNC              (RST_SYNC   ),
       .RST_ASYNC             (RST_ASYNC  ),
       
       .WB_REGS_ADR_IN        (WB_REGS_ADR_IN           ), 
       .WB_REGS_CYC_IN        (WB_REGS_RCNT_CYC_IN      ), 
       .WB_REGS_STB_IN        (WB_REGS_RCNT_STB_IN      ), 
       .WB_REGS_WE_IN         (WB_REGS_WE_IN            ), 
       .WB_REGS_SEL_IN        (WB_REGS_SEL_IN           ), 
       .WB_REGS_ACK_OUT       (WB_REGS_RCNT_ACK_OUT     ), 
       .WB_REGS_STALL_OUT     (WB_REGS_RCNT_STALL_OUT   ), 
       .WB_REGS_ERR_OUT       (WB_REGS_RCNT_ERR_OUT     ), 
       
       .WB_WRITE_ADDR_STB_OUT (WbWriteAddrStb ),
       .WB_READ_ADDR_STB_OUT  (WbReadAddrStb  ),
       .WB_VALID_OUT          (WbValid        )
       );
   

   
endmodule // ROOT_CNT
