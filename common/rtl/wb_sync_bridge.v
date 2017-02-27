// Wishbone sync bridge
// Handshakes between two synchronous clock domains for WB transactions
module WB_SYNC_BRIDGE
   (
    // Clocks and resets (Source clock domain)
    input          CLK_SRC            ,
    input          EN_SRC             ,
    input          RST_SRC_SYNC       ,
    input          RST_SRC_ASYNC      , 

    // Clocks and resets (destination clock domain)
    input          CLK_DST            ,
    input          EN_DST             ,
    input          RST_DST_SYNC       ,
    input          RST_DST_ASYNC      , 

    // Wishbone interface (Slave)
    input      [31:0] WB_S_ADR_IN      ,
    input             WB_S_CYC_IN      ,
    input             WB_S_STB_IN      ,
    input             WB_S_WE_IN       ,
    input      [ 3:0] WB_S_SEL_IN      ,
    input      [ 2:0] WB_S_CTI_IN      ,
    input      [ 1:0] WB_S_BTE_IN      ,
    output            WB_S_STALL_OUT   ,
    output            WB_S_ACK_OUT     ,
    output            WB_S_ERR_OUT     ,
    output     [31:0] WB_S_DAT_RD_OUT  ,
    input      [31:0] WB_S_DAT_WR_IN   , 
   
    // Wishbone interface (Master)
    output    [31:0]  WB_M_ADR_OUT     ,
    output            WB_M_CYC_OUT     ,
    output            WB_M_STB_OUT     ,
    output            WB_M_WE_OUT      ,
    output    [ 3:0]  WB_M_SEL_OUT     ,
    output    [ 2:0]  WB_M_CTI_OUT     ,
    output    [ 1:0]  WB_M_BTE_OUT     , 

    input             WB_M_ACK_IN      ,
    input             WB_M_STALL_IN    ,
    input             WB_M_ERR_IN      ,

    input     [31:0]  WB_M_DAT_RD_IN   ,
    output    [31:0]  WB_M_DAT_WR_OUT  
   
    );
   

   /////////////////////////////////////////////////////////////////////////////
   // includes


   /////////////////////////////////////////////////////////////////////////////
   // parameters


   /////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // Master to Slave signals (Src clock registered)
    reg      [31:0] SrcWbAdr         ;
//    reg             SrcWbCyc         ; // CYC and STB used in handshake
//    reg             SrcWbStb         ;
    reg             SrcWbWe          ;
    reg      [ 3:0] SrcWbSel         ;
    reg      [ 2:0] SrcWbCti         ;
    reg      [ 1:0] SrcWbBte         ;
    reg      [31:0] SrcWbDatWr       ; 

   // Master to Slave signals (Dst clock registered)
    reg      [31:0] DstWbAdr         ;
//    reg             DstWbCyc         ; // CYC and STB used in handshake
//    reg             DstWbStb         ;
    reg             DstWbWe          ;
    reg      [ 3:0] DstWbSel         ;
    reg      [ 2:0] DstWbCti         ;
    reg      [ 1:0] DstWbBte         ;
    reg      [31:0] DstWbDatWr       ; 


    // Slave to Master signals (Dst clock registered)   
//   reg              DstWbStall       ; // Used in handshake
   reg              DstWbAck         ;
   reg              DstWbErr         ;
   reg       [31:0] DstWbDatRd       ;
   
    // Slave to Master signals (Src clock registered)   
//   reg              SrcWbStall       ; // Used in handshake
   reg              SrcWbAck         ;
   reg              SrcWbErr         ;
   reg       [31:0] SrcWbDatRd       ;

   // Src to Dst handshaking
   wire 	    SrcWbCycStb       ;
   reg 		    SrcWbCycStbTog    ;
   reg 		    DstWbCycStbTogReg ;
   wire 	    DstWbCycStbSet    ;
   wire 	    DstWbCycClr       ;
   wire 	    DstWbStbClr       ;
   reg 		    DstWbCycReg       ;
   reg 		    DstWbStbReg       ;
   
   // Dst to src handshaking
   reg 		    DstWbCycTog       ;
   reg 		    DstWbCycTogReg    ;
   wire 	    SrcCycStb         ;

   // SRC-domain STALL
   reg 		    SrcWbCycStbReg       ;
   
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns

   assign SrcWbCycStb    = WB_S_CYC_IN & WB_S_STB_IN & ~SrcWbCycStbReg;
   assign SrcCycStb      = DstWbCycTog ^ DstWbCycTogReg;
   assign DstWbCycStbSet = DstWbCycStbTogReg ^ SrcWbCycStbTog;
   assign DstWbCycClr    = DstWbCycReg & WB_M_ACK_IN;
   assign DstWbStbClr    = DstWbStbReg & ~ WB_M_STALL_IN;
   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns

   // Slave-side outputs
   assign WB_S_STALL_OUT   = SrcWbCycStbReg ;
   assign WB_S_ACK_OUT     = SrcWbAck       ;
   assign WB_S_ERR_OUT     = SrcWbErr       ;
   assign WB_S_DAT_RD_OUT  = SrcWbDatRd     ;

   // Master-side outputs
   assign WB_M_ADR_OUT     = DstWbAdr     ;
   assign WB_M_CYC_OUT     = DstWbCycReg  ;
   assign WB_M_STB_OUT     = DstWbStbReg  ;
   assign WB_M_WE_OUT      = DstWbWe      ;
   assign WB_M_SEL_OUT     = DstWbSel     ;
   assign WB_M_CTI_OUT     = DstWbCti     ;
   assign WB_M_BTE_OUT     = DstWbBte     ; 
   assign WB_M_DAT_WR_OUT  = DstWbDatWr   ;  
   

   
   /////////////////////////////////////////////////////////////////////////////
   // SRC-clocked Always blocks

   // SRC : Toggle flop. Change the level output when a new CYC+STB (and no stall)
   //       comes in on the slave interface. A change in level is recovered into
   //       a pulse using an XOR and register on the DST-side
   always @(posedge CLK_SRC or posedge RST_SRC_ASYNC)
   begin : SRC_WB_CYC_STB_TOG
      if (RST_SRC_ASYNC)
      begin
	 SrcWbCycStbTog <= 1'b0;
      end
      else if (RST_SRC_SYNC)
      begin
	 SrcWbCycStbTog <= 1'b0;
      end
      else if (EN_SRC && SrcWbCycStb)
      begin
	 SrcWbCycStbTog <= ~SrcWbCycStbTog;
      end
   end
   
   // SRC : SR flop. Set when the CYC+STB and no stall comes in on Slave i/f.
   //       Clear when the handshake pulse comes back from the DST domain
   //       
   always @(posedge CLK_SRC or posedge RST_SRC_ASYNC)
   begin : SRC_STALL_SR_REG
      if (RST_SRC_ASYNC)
      begin
	 SrcWbCycStbReg <= 1'b0;
      end
      else if (RST_SRC_SYNC)
      begin
	 SrcWbCycStbReg <= 1'b0;
      end
      else if (EN_SRC)
      begin
	 if (SrcWbCycStb)
	 begin
	    SrcWbCycStbReg <= 1'b1;
	 end
	 else if (SrcCycStb)
	 begin
	    SrcWbCycStbReg <= 1'b0;
	 end
      end
   end

   // SRC : Register incoming level change from DST domain to detect edge
   //       
   //       
   always @(posedge CLK_SRC or posedge RST_SRC_ASYNC)
   begin : SRC_WB_CYC_DST_REG
      if (RST_SRC_ASYNC)
      begin
	 DstWbCycTogReg <= 1'b0;
      end
      else if (RST_SRC_SYNC)
      begin
	 DstWbCycTogReg <= 1'b0;
      end
      else if (EN_SRC)
      begin
	 DstWbCycTogReg <= DstWbCycTog;
      end
   end

   // SRC : Data register - register Slave to Master signals in SRC domain
   //       
   //       
   always @(posedge CLK_SRC or posedge RST_SRC_ASYNC)
   begin : SRC_S2M_REG
      if (RST_SRC_ASYNC)
      begin
	 SrcWbAck    <= 1'b0;
	 SrcWbErr    <= 1'b0;
	 SrcWbDatRd  <= 32'h0000_0000;
      end
      else if (RST_SRC_SYNC)
      begin
	 SrcWbAck    <= 1'b0;
	 SrcWbErr    <= 1'b0;
	 SrcWbDatRd  <= 32'h0000_0000;
      end
      else if (EN_SRC && SrcCycStb)
      begin
	 SrcWbAck    <= DstWbAck    ;
	 SrcWbErr    <= DstWbErr    ;
	 SrcWbDatRd  <= DstWbDatRd  ;
      end
   end

   // SRC : Data register - register Master to Slave signals in SRC domain
   //       
   //       
   always @(posedge CLK_SRC or posedge RST_SRC_ASYNC)
   begin : SRC_M2S_REG
      if (RST_SRC_ASYNC)
      begin
	 SrcWbAdr    <=  32'h0000_0000  ;
	 SrcWbWe     <=  1'b0	  	;
	 SrcWbSel    <=  4'h0	  	;
	 SrcWbCti    <=  3'h0	  	;
	 SrcWbBte    <=  2'h0	  	;
	 SrcWbDatWr  <=  32'h0000_0000  ; 
      end
      else if (RST_SRC_SYNC)
      begin
	 SrcWbAdr    <=  32'h0000_0000  ;
	 SrcWbWe     <=  1'b0	  	;
	 SrcWbSel    <=  4'h0	  	;
	 SrcWbCti    <=  3'h0	  	;
	 SrcWbBte    <=  2'h0	  	;
	 SrcWbDatWr  <=  32'h0000_0000  ; 
      end
      else if (EN_SRC && SrcWbCycStb)
      begin
	 SrcWbAdr    <=  WB_S_ADR_IN    ;
	 SrcWbWe     <=  WB_S_WE_IN 	;
	 SrcWbSel    <=  WB_S_SEL_IN 	;
	 SrcWbCti    <=  WB_S_CTI_IN	;
	 SrcWbBte    <=  WB_S_BTE_IN	;
	 SrcWbDatWr  <=  WB_S_DAT_WR_IN ; 
      end
   end


   /////////////////////////////////////////////////////////////////////////////
   // DST-clocked Always blocks

   // DST : DstWbCycStbTogReg. Register the level coming from the SRC clock 
   //       domain. Check for a change in level with an XOR to trigger a WB
   //       transaction on the DST-side
   always @(posedge CLK_DST or posedge RST_DST_ASYNC)
   begin : DST_SRC_WB_CYC_STB_TOG_REG
      if (RST_DST_ASYNC)
      begin
	 DstWbCycStbTogReg <= 1'b0;         
      end
      else if (RST_DST_SYNC)
      begin
	 DstWbCycStbTogReg <= 1'b0;         
      end
      else if (EN_DST)
      begin
	 DstWbCycStbTogReg <= SrcWbCycStbTog;
      end
   end

   // DST : WB_CYC_OUT SR flop. Set on the level change from SRC domain detected
   //       on the DST flop. 
   //       Reset When ACK comes back
   always @(posedge CLK_DST or posedge RST_DST_ASYNC)
   begin : WB_CYC_SR_REG
      if (RST_DST_ASYNC)
      begin
	 DstWbCycReg <= 1'b0;         
      end
      else if (RST_DST_SYNC)
      begin
	 DstWbCycReg <= 1'b0;         
      end
      else if (EN_DST)
      begin
	 if (DstWbCycStbSet)
	 begin
	    DstWbCycReg <= 1'b1;         
	 end
	 else if (DstWbCycClr)
	 begin
	    DstWbCycReg <= 1'b0;         
	 end
      end
   end

   // DST : WB_STB_OUT SR flop. Set on the level change from SRC domain detected
   //       on the DST flop. 
   //       Reset when STALL goes low
   always @(posedge CLK_DST or posedge RST_DST_ASYNC)
   begin : WB_STB_SR_REG
      if (RST_DST_ASYNC)
      begin
	 DstWbStbReg <= 1'b0;         
      end
      else if (RST_DST_SYNC)
      begin
	 DstWbStbReg <= 1'b0;         
      end
      else if (EN_DST)
      begin
	 if (DstWbCycStbSet)
	 begin
	    DstWbStbReg <= 1'b1;         
	 end
	 else if (DstWbStbClr)
	 begin
	    DstWbStbReg <= 1'b0;         
	 end
      end
   end

   
   // DST : Toggle flop to send level change into SRC domain
   //       
   //       
   always @(posedge CLK_DST or posedge RST_DST_ASYNC)
   begin : DST_TOG_FLOP
      if (RST_DST_ASYNC)
      begin
	DstWbCycTog <= 1'b0;         
      end
      else if (RST_DST_SYNC)
      begin
	 DstWbCycTog <= 1'b0;         
      end
      else if (EN_DST && DstWbCycClr)
      begin
	 DstWbCycTog <= ~DstWbCycTog;         
      end
   end


   // DST : Data register - register Slave to Master signals in DST domain
   //       
   //       
   always @(posedge CLK_DST or posedge RST_DST_ASYNC)
   begin : DST_S2M_REG
      if (RST_DST_ASYNC)
      begin
	 DstWbAck    <= 1'b0;         
	 DstWbErr    <= 1'b0;         
	 DstWbDatRd  <= 32'h0000_0000;
      end
      else if (RST_DST_SYNC)
      begin
	 DstWbAck    <= 1'b0;
	 DstWbErr    <= 1'b0;
	 DstWbDatRd  <= 32'h0000_0000;
      end
      else if (EN_DST && DstWbCycClr)
      begin
	 DstWbAck    <= WB_M_ACK_IN    ;
	 DstWbErr    <= WB_M_ERR_IN    ;
	 DstWbDatRd  <= WB_M_DAT_RD_IN ;
      end
   end

   // DST : Data register - register Master to Slave signals in DST domain
   //       
   //       
   always @(posedge CLK_DST or posedge RST_DST_ASYNC)
   begin : DST_M2S_REG
      if (RST_DST_ASYNC)
      begin
	 DstWbAdr    <=  32'h0000_0000  ;
	 DstWbWe     <=  1'b0	  	;
	 DstWbSel    <=  4'h0	  	;
	 DstWbCti    <=  3'h0	  	;
	 DstWbBte    <=  2'h0	  	;
	 DstWbDatWr  <=  32'h0000_0000  ; 
      end
      else if (RST_DST_SYNC)
      begin
	 DstWbAdr    <=  32'h0000_0000  ;
	 DstWbWe     <=  1'b0	  	;
	 DstWbSel    <=  4'h0	  	;
	 DstWbCti    <=  3'h0	  	;
	 DstWbBte    <=  2'h0	  	;
	 DstWbDatWr  <=  32'h0000_0000  ; 
      end
      else if (EN_DST && DstWbCycStbSet)
      begin
	 DstWbAdr    <=  SrcWbAdr   ;
	 DstWbWe     <=  SrcWbWe    ;
	 DstWbSel    <=  SrcWbSel   ;
	 DstWbCti    <=  SrcWbCti   ;
	 DstWbBte    <=  SrcWbBte   ;
	 DstWbDatWr  <=  SrcWbDatWr ; 
      end
   end


   

endmodule
