module WB_ARB_4M_1S
   (
    // Clocks and resets
    input          CLK          ,
    input          EN           ,
    input          RST_SYNC     , 
    input          RST_ASYNC    , 

    // Wishbone SLAVE interface (connect to WB MASTER)
    input   [31:0] WB_SL0_ADR_IN     ,
    input          WB_SL0_CYC_IN     ,
    input          WB_SL0_STB_IN     ,
    input          WB_SL0_WE_IN      ,
    input   [ 3:0] WB_SL0_SEL_IN     ,
    input   [ 2:0] WB_SL0_CTI_IN     ,
    input   [ 1:0] WB_SL0_BTE_IN     ,

    output         WB_SL0_STALL_OUT  ,
    output         WB_SL0_ACK_OUT    ,
    output         WB_SL0_ERR_OUT    ,

    output  [31:0] WB_SL0_RD_DAT_OUT ,
    input   [31:0] WB_SL0_WR_DAT_IN  ,

    // Wishbone SLAVE interface (connect to WB MASTER)
    input   [31:0] WB_SL1_ADR_IN     ,
    input          WB_SL1_CYC_IN     ,
    input          WB_SL1_STB_IN     ,
    input          WB_SL1_WE_IN      ,
    input   [ 3:0] WB_SL1_SEL_IN     ,
    input   [ 2:0] WB_SL1_CTI_IN     , 
    input   [ 1:0] WB_SL1_BTE_IN     ,

    output         WB_SL1_STALL_OUT  ,
    output         WB_SL1_ACK_OUT    ,
    output         WB_SL1_ERR_OUT    ,

    output  [31:0] WB_SL1_RD_DAT_OUT ,
    input   [31:0] WB_SL1_WR_DAT_IN  ,

    // Wishbone SLAVE interface (connect to WB MASTER)
    input   [31:0] WB_SL2_ADR_IN     ,
    input          WB_SL2_CYC_IN     ,
    input          WB_SL2_STB_IN     ,
    input          WB_SL2_WE_IN      ,
    input   [ 3:0] WB_SL2_SEL_IN     ,
    input   [ 2:0] WB_SL2_CTI_IN     ,
    input   [ 1:0] WB_SL2_BTE_IN     ,

    output         WB_SL2_STALL_OUT  ,
    output         WB_SL2_ACK_OUT    ,
    output         WB_SL2_ERR_OUT    ,

    output  [31:0] WB_SL2_RD_DAT_OUT ,
    input   [31:0] WB_SL2_WR_DAT_IN  ,

    // Wishbone SLAVE interface (connect to WB MASTER)
    input   [31:0] WB_SL3_ADR_IN     ,
    input          WB_SL3_CYC_IN     ,
    input          WB_SL3_STB_IN     ,
    input          WB_SL3_WE_IN      ,
    input   [ 3:0] WB_SL3_SEL_IN     ,
    input   [ 2:0] WB_SL3_CTI_IN     ,
    input   [ 1:0] WB_SL3_BTE_IN     ,

    output         WB_SL3_STALL_OUT  ,
    output         WB_SL3_ACK_OUT    ,
    output         WB_SL3_ERR_OUT    ,

    output  [31:0] WB_SL3_RD_DAT_OUT ,
    input   [31:0] WB_SL3_WR_DAT_IN  ,

    // Wishbone MASTER interface (connect to WB SLAVE)
    output  [31:0] WB_M0_ADR_OUT     ,
    output         WB_M0_CYC_OUT     ,
    output         WB_M0_STB_OUT     ,
    output         WB_M0_WE_OUT      ,
    output  [ 3:0] WB_M0_SEL_OUT     ,
    output  [ 2:0] WB_M0_CTI_OUT     ,
    output  [ 1:0] WB_M0_BTE_OUT     ,

    input          WB_M0_STALL_IN    ,
    input          WB_M0_ACK_IN      ,
    input          WB_M0_ERR_IN      ,

    input   [31:0] WB_M0_RD_DAT_IN   ,
    output  [31:0] WB_M0_WR_DAT_OUT 
    );

   // wires / regs
   reg  [3:0] 	   WbArbGnt      ; 
   reg  [3:0] 	   WbArbGntReg   ;
   reg   	   WbArbGntRegEn ;


   // Currently granted Wishbone Master signals
   // Master to Slave
   reg [31:2] 	   WbAdr       ;
   reg 		   WbCyc       ;
   reg 		   WbStb       ;
   reg 		   WbWe        ;
   reg [ 3:0] 	   WbSel       ;
   reg [ 2:0] 	   WbCti       ;
   reg [ 1:0] 	   WbBte       ;
   reg [31:0] 	   WbWrDat     ;

   // Slave to Master
   reg 		   WbStall     ;
   reg 		   WbAck       ;
   reg 		   WbErr       ;
   reg [31:0] 	   WbRdDat     ;

   // External assigns

   // Demux the WB Slaves connected
   assign WB_M0_ADR_OUT     = WbAdr   ;
   assign WB_M0_CYC_OUT     = WbCyc   ;
   assign WB_M0_STB_OUT     = WbStb   ;
   assign WB_M0_WE_OUT      = WbWe    ;
   assign WB_M0_SEL_OUT     = WbSel   ;
   assign WB_M0_CTI_OUT     = WbCti   ;
   assign WB_M0_BTE_OUT     = WbBte   ;
   assign WB_M0_WR_DAT_OUT  = WbWrDat ;

   // Return the WB Slave to Master signals.
   // The STALL output is equivalent to the GNT from an arbiter. It is set as follows:
   // - For the selected master, the STALL comes from the slave.
   // - For the un-selected master, or no-one has been selected, the STALL comes back from the incoming CYC
   assign WB_SL0_STALL_OUT  = (WbArbGntReg == 4'b0001) ? WB_M0_STALL_IN   : WB_SL0_CYC_IN ;
   assign WB_SL0_ACK_OUT    = (WbArbGntReg == 4'b0001) ? WB_M0_ACK_IN     : 1'b0 ;
   assign WB_SL0_ERR_OUT    = (WbArbGntReg == 4'b0001) ? WB_M0_ERR_IN     : 1'b0 ;
   assign WB_SL0_RD_DAT_OUT = (WbArbGntReg == 4'b0001) ? WB_M0_RD_DAT_IN  : 32'h0000_0000 ;

   assign WB_SL1_STALL_OUT  = (WbArbGntReg == 4'b0010) ? WB_M0_STALL_IN   : WB_SL1_CYC_IN ;
   assign WB_SL1_ACK_OUT    = (WbArbGntReg == 4'b0010) ? WB_M0_ACK_IN     : 1'b0 ;
   assign WB_SL1_ERR_OUT    = (WbArbGntReg == 4'b0010) ? WB_M0_ERR_IN     : 1'b0 ;
   assign WB_SL1_RD_DAT_OUT = (WbArbGntReg == 4'b0010) ? WB_M0_RD_DAT_IN  : 32'h0000_0000 ;

   assign WB_SL2_STALL_OUT  = (WbArbGntReg == 4'b0100) ? WB_M0_STALL_IN   : WB_SL2_CYC_IN ;
   assign WB_SL2_ACK_OUT    = (WbArbGntReg == 4'b0100) ? WB_M0_ACK_IN     : 1'b0 ;
   assign WB_SL2_ERR_OUT    = (WbArbGntReg == 4'b0100) ? WB_M0_ERR_IN     : 1'b0 ;
   assign WB_SL2_RD_DAT_OUT = (WbArbGntReg == 4'b0100) ? WB_M0_RD_DAT_IN  : 32'h0000_0000 ;

   assign WB_SL3_STALL_OUT  = (WbArbGntReg == 4'b1000) ? WB_M0_STALL_IN   : WB_SL3_CYC_IN ;
   assign WB_SL3_ACK_OUT    = (WbArbGntReg == 4'b1000) ? WB_M0_ACK_IN     : 1'b0 ;
   assign WB_SL3_ERR_OUT    = (WbArbGntReg == 4'b1000) ? WB_M0_ERR_IN     : 1'b0 ;
   assign WB_SL3_RD_DAT_OUT = (WbArbGntReg == 4'b1000) ? WB_M0_RD_DAT_IN  : 32'h0000_0000 ;


   // Decode who is going to be granted the bus access. The CYC input is used as an arbiter
   // request line from the master
   always @*
   begin : GNT_DECODE

      // By default, keep the current settings
      WbArbGntRegEn = 1'b0;
      WbArbGnt      = 4'b0000;

      // No-one is currently granted, and at least one request comes in.
      // => simple, just grant the highest priority master.
      if ((4'b0000 == WbArbGntReg) 
          && (WB_SL0_CYC_IN || WB_SL1_CYC_IN  || WB_SL2_CYC_IN || WB_SL3_CYC_IN))
      begin
	 // Need to change grant value
	 WbArbGntRegEn = 1'b1;
	 // Choose the highest priority master
	 if (WB_SL0_CYC_IN)
	 begin
	    WbArbGnt = 4'b0001;
	 end
	 else if (WB_SL1_CYC_IN)
	 begin
	    WbArbGnt = 4'b0010;
	 end
	 else if (WB_SL2_CYC_IN)
	 begin
	    WbArbGnt = 4'b0100;
	 end
	 else if (WB_SL3_CYC_IN)
	 begin
	    WbArbGnt = 4'b1000;
	 end
      end

      // Master 0 currently selected, but not requesting
      else if ((4'b0001 == WbArbGntReg) && !WB_SL0_CYC_IN)
      begin
	 WbArbGntRegEn = 1'b1;
	 if (WB_SL1_CYC_IN)
	 begin
	    WbArbGnt = 4'b0010;
	 end
	 else if (WB_SL2_CYC_IN)
	 begin
	    WbArbGnt = 4'b0100;
	 end
	 else if (WB_SL3_CYC_IN)
	 begin
	    WbArbGnt = 4'b1000;
	 end
	 else
	 begin
	    WbArbGnt = 4'b0000;
	 end
      end

      // Master 1 currently selected, but not requesting any more
      else if ((4'b0010 == WbArbGntReg) && !WB_SL1_CYC_IN)
      begin
	 WbArbGntRegEn = 1'b1;
	 if (WB_SL0_CYC_IN)
	 begin
	    WbArbGnt = 4'b0001;
	 end
	 else if (WB_SL2_CYC_IN)
	 begin
	    WbArbGnt = 4'b0100;
	 end
	 else if (WB_SL3_CYC_IN)
	 begin
	    WbArbGnt = 4'b1000;
	 end
	 else
	 begin
	    WbArbGnt = 4'b0000;
	 end
      end

      // Master 2 currently selected, but not requesting any more
      else if ((4'b0100 == WbArbGntReg) && !WB_SL2_CYC_IN)
      begin
	 WbArbGntRegEn = 1'b1;
	 if (WB_SL0_CYC_IN)
	 begin
	    WbArbGnt = 4'b0001;
	 end
	 else if (WB_SL1_CYC_IN)
	 begin
	    WbArbGnt = 4'b0001;
	 end
	 else if (WB_SL3_CYC_IN)
	 begin
	    WbArbGnt = 4'b1000;
	 end
	 else
	 begin
	    WbArbGnt = 4'b0000;
	 end
      end

      // Master 3 currently selected, but not requesting any more
      else if ((4'b1000 == WbArbGntReg) && !WB_SL3_CYC_IN)
      begin
	 WbArbGntRegEn = 1'b1;
	 if (WB_SL0_CYC_IN)
	 begin
	    WbArbGnt = 4'b0001;
	 end
	 else if (WB_SL1_CYC_IN)
	 begin
	    WbArbGnt = 4'b0001;
	 end
	 else if (WB_SL2_CYC_IN)
	 begin
	    WbArbGnt = 4'b0100;
	 end
	 else
	 begin
	    WbArbGnt = 4'b0000;
	 end
      end
   end
   
    // Register the Grant signal back to WB Masters
    always @(posedge CLK or posedge RST_ASYNC)
    begin : GNT_REG
       if (RST_ASYNC)
       begin
 	 WbArbGntReg <= 4'b0000;
       end
       else if (RST_SYNC)
       begin
 	 WbArbGntReg <= 4'b0000;
       end
       else if (EN && WbArbGntRegEn)
       begin
 	 WbArbGntReg <= WbArbGnt;
       end
    end

   // Mux the MAster -> Slave signals according to which master was granted
   always @(*)
   begin : MASTER_TO_SLAVE_MUX
      
      WbAdr    = 32'h0000_0000;
      WbCyc    = 1'b0;
      WbStb    = 1'b0;
      WbWe     = 1'b0;
      WbSel    = 4'b0000;
      WbCti    = 4'b0000;
      WbBte    = 2'b00;
      WbWrDat  = 32'h0000_0000;
      
      case (WbArbGntReg)
	4'b0001 :
	   begin
	      WbAdr    = WB_SL0_ADR_IN     ;
	      WbCyc    = WB_SL0_CYC_IN     ;
	      WbStb    = WB_SL0_STB_IN     ;
	      WbWe     = WB_SL0_WE_IN      ;
	      WbSel    = WB_SL0_SEL_IN     ;
	      WbCti    = WB_SL0_CTI_IN     ;
	      WbBte    = WB_SL0_BTE_IN     ;
	      WbWrDat  = WB_SL0_WR_DAT_IN  ;
	   end	
	4'b0010 :
	   begin
	      WbAdr    = WB_SL1_ADR_IN     ;
	      WbCyc    = WB_SL1_CYC_IN     ;
	      WbStb    = WB_SL1_STB_IN     ;
	      WbWe     = WB_SL1_WE_IN      ;
	      WbSel    = WB_SL1_SEL_IN     ;
	      WbCti    = WB_SL1_CTI_IN     ;
	      WbBte    = WB_SL1_BTE_IN     ;
	      WbWrDat  = WB_SL1_WR_DAT_IN  ;
	   end
	4'b0100 :
	   begin
	      WbAdr    = WB_SL2_ADR_IN     ;
	      WbCyc    = WB_SL2_CYC_IN     ;
	      WbStb    = WB_SL2_STB_IN     ;
	      WbWe     = WB_SL2_WE_IN      ;
	      WbSel    = WB_SL2_SEL_IN     ;
	      WbCti    = WB_SL2_CTI_IN     ;
	      WbBte    = WB_SL2_BTE_IN     ;
	      WbWrDat  = WB_SL2_WR_DAT_IN  ;
	   end
	4'b1000 :
	   begin
	      WbAdr    = WB_SL3_ADR_IN     ;
	      WbCyc    = WB_SL3_CYC_IN     ;
	      WbStb    = WB_SL3_STB_IN     ;
	      WbWe     = WB_SL3_WE_IN      ;
	      WbSel    = WB_SL3_SEL_IN     ;
	      WbCti    = WB_SL3_CTI_IN     ;
	      WbBte    = WB_SL3_BTE_IN     ;
	      WbWrDat  = WB_SL3_WR_DAT_IN  ;
	   end
      endcase // case (WbArbGnt)
   end
   
endmodule
