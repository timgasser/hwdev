module SDRAM_CONTROLLER
   #(
     parameter [31:0] WBA   = 32'h0000_0000, // Wishbone Base Address
     parameter        WS_P2 = 24             // Wishbone size as power-of-2 bytes
     )
   (
    input         CLK            ,
    input         EN             ,
    input         RST_SYNC       ,
    input         RST_ASYNC      ,
    output        CLK_SDR_EN_OUT ,
    
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

    input  [31:0] WB_WR_DAT_IN   ,
    output [31:0] WB_RD_DAT_OUT  ,

    // SDRAM interface
    output [23:1] SDR_ADDR_OUT   ,
    output 	  SDR_CRE_OUT    ,
    output 	  SDR_ADVB_OUT   ,
    output 	  SDR_CEB_OUT    ,
    output 	  SDR_OEB_OUT    ,
    output 	  SDR_WEB_OUT    ,
    input  	  SDR_WAIT_IN    ,

    output 	  SDR_LBB_OUT    ,
    output 	  SDR_UBB_OUT    ,
   
    inout  [15:0] SDR_DATA_INOUT 
   
    );

   // includes
`include "sdr_defs.v"
   
   // parameters
   parameter WS_MSB = WS_P2 - 1;
   parameter  [3:0] ASYNC_CLKS = 4'd4;
// parameter  [3:0] PWRUP_CLKS = 4'd12;

   // wires / regs
   wire      WbRead       ; // = WB_CYC_IN & ~WB_WE_IN;
   wire      WbWrite      ; // = WB_CYC_IN &  WB_WE_IN;
   wire      WbAddrStb    ; // = WB_CYC_IN & WB_STB_IN & ~WB_STALL_OUT;

//   wire      WbReadStall  ; // = WbRead & (3'd4 == WbAddrCntVal);
   reg 	     WbWriteAck   ; // <-(CLK) WriteFifoWriteEn

   wire [22:0] SdrBcrVal   = 23'd0 
   			   | BCR_RS_BCR     << BCR_RS_LO
			   | BCR_OM_SYNC    << BCR_OM 
			   | BCR_IL_VAR     << BCR_IL 
			   | BCR_LC_C3      << BCR_LC_LO  
			   | BCR_WP_LOW     << BCR_WP
			   | BCR_WC_NONE    << BCR_WC  
			   | BCR_DS_HALF    << BCR_DS_LO  
			   | BCR_BW_NO_WRAP << BCR_BW
			   | BCR_BL_CONT    << BCR_BL_LO;    

   wire     [31:0] SdrAddr32b   ; // = (WB_ADR_IN[31:0] - WBA);
   wire [WS_MSB:0] SdrAddr      ; // = SdrAddr32b[WS_MSB:1];
   wire [WS_MSB:1] SdrAddrMux   ; // = SdrBcrAddrbSel ? SdrBcrVal : SdrAddr;
   reg  [WS_MSB:1] SdrAddrReg   ; // assign SDR_ADDR_OUT
   
   wire        WriteFifoWriteEn   ; // = WbWrite & WbAddrStb & ~WriteFifoWriteFull;
   wire        WriteFifoWriteFull ;
   wire [35:0] WriteFifoWriteData ; // = {WB_SEL_IN[3:2], WB_WR_DAT_IN[31:16], WB_SEL_IN[1:0], WB_WR_DAT_IN[15:0]};
   wire	       WriteFifoReadEn    ; // <-(CLK) WbWrite & ~SDR_WAIT_IN;
   wire        WriteFifoReadEmpty ;
   wire [17:0] WriteFifoReadData  ;

   wire [ 1:0] SdrByteEn          ;
   wire [15:0] SdrWriteData       ;
   reg  [ 1:0] SdrByteEnReg       ; // = WriteFifoReadData[17:16];
   reg  [15:0] SdrWriteDataReg    ; // = WriteFifoReadData[15: 0];
   
   //   wire WbReadAck          ; <- declared in FSM section
   wire        ReadFifoReadEmpty  ;
   wire        ReadFifoWriteEn    ; // = WbRead & ~SDR_WAIT_IN;
   wire        ReadFifoWriteFull  ;
//   reg [15:0]  ReadFifoWriteData  ; 
   
   wire        SdrDriveEn         ; // = SDR_WAIT_IN & WbWrite;
   wire [15:0] SdrReadData        ; // assign SDR_DATA_INOUT

   wire        SdrDataStb         ; // = SdrCeb & ~SDR_WAIT_IN
   
   reg [2:0]   WbAddrCntVal    ;
   wire [3:0]  WbAddrCntValShift = {WbAddrCntVal, 1'b0};
   reg [3:0]   SdrDataCntVal   ;

   wire        SdrDataDriveEn; // = SDR_WAIT_IN & WbWrite;
   
   reg 	       ClkSdrEnSet;
   reg 	       ClkSdrEn; // assign CLK_SDR_EN_OUT

   wire        WbRowWrapStall;
   
   // FSM

   // Bus-side
   
   parameter [3:0] SDRFSM_IDLE            = 4'h0;       
   parameter [3:0] SDRFSM_BCR_WRITE_REQ   = 4'h1;     
   parameter [3:0] SDRFSM_BCR_WRITE_ACK   = 4'h2;       
   parameter [3:0] SDRFSM_READY           = 4'h3;       
   parameter [3:0] SDRFSM_WB_READ_ADDR    = 4'h4;       
   parameter [3:0] SDRFSM_SDR_READ_DATA   = 4'h5;       
   parameter [3:0] SDRFSM_WB_READ_DATA    = 4'h6;       
   parameter [3:0] SDRFSM_WB_WRITE_DATA   = 4'h7;       
   parameter [3:0] SDRFSM_SDR_WRITE_DATA  = 4'h8;       
   parameter [3:0] SDRFSM_WRITE_END       = 4'h9;
   
   // SDRFSM_STATE SdrFsmStateCur;
   // SDRFSM_STATE SdrFsmStateNxt;
   
   reg [3:0]   SdrFsmStateCur ;
   reg [3:0]   SdrFsmStateNxt ;
   
   reg 	       WbReadAckNxt     ;
   reg 	       WbReadAck        ;

   reg 	       WbWriteStallNxt  ;
   reg 	       WbWriteStall     ;

   reg 	       WbReadStallNxt  ;
   reg 	       WbReadStall     ;

   reg 	       WbAsyncStallNxt  ;
   reg 	       WbAsyncStall     ;
   
   // SDRAM-side 
   reg 	       SdrCreNxt   ;
   reg 	       SdrCre      ;
   reg 	       SdrAdvbNxt  ;
   reg 	       SdrAdvb     ;
   reg 	       SdrCebNxt   ;
   reg 	       SdrCeb      ;
   reg 	       SdrOebNxt   ;
   reg 	       SdrOeb      ;
   reg 	       SdrWebNxt   ;
   reg 	       SdrWeb      ;
   reg 	       SdrWaitValidNxt ;
   reg 	       SdrWaitValid    ;
   
   // Internal
   reg 	       SdrBcrAddrbSel   ;
   reg 	       SdrAddrRegEn     ;
   reg 	       WbAddrCntClr     ;
   reg 	       SdrDataCntClr    ;
   
   reg 	       SdrAsyncCntLd    ;
// reg [3:0]   SdrAsyncCntLdVal ;
   reg [3:0]   SdrAsyncCntVal   ;

   wire        SdrDataEn; 
//   reg 	       SdrWaitReg; // posedge registered SDR_WAIT_IN
   
   // Internal assigns
   assign WbRead       = WB_CYC_IN & ~WB_WE_IN;
   assign WbWrite      = WB_CYC_IN &  WB_WE_IN;
   assign WbAddrStb    = WB_CYC_IN & WB_STB_IN & ~WB_STALL_OUT;

//   assign WbReadStall  = WbRead & (3'd4 == WbAddrCntVal); <- comes from the FSM now .. 
   
   assign SdrAddr32b   = (WB_ADR_IN - WBA);
   assign SdrAddr      = {SdrAddr32b[WS_MSB:1], 1'b0};
   assign SdrAddrMux   = SdrBcrAddrbSel ? SdrBcrVal : SdrAddr[23:1];
   
   assign WriteFifoWriteEn    = WbWrite & WbAddrStb & ~WriteFifoWriteFull;
   assign WriteFifoWriteData  = {WB_SEL_IN[3:2], WB_WR_DAT_IN[31:16], WB_SEL_IN[1:0], WB_WR_DAT_IN[15:0]};
   assign WriteFifoReadEn     = SdrDataStb & ~SdrWeb;

   assign ReadFifoWriteEn    = SdrDataStb & SdrWeb;
   
   assign SdrByteEn          = WriteFifoReadData[17:16];
   assign SdrWriteData       = WriteFifoReadData[15: 0];

   assign SdrDataDriveEn     = SdrOeb & SdrDataStb; // Advb & ClkSdrEn & ~SdrWait & ~SdrWeb & ~SdrCeb; // Don't drive in async mode, or when sending address

   assign SdrDataStb         = ~SdrCeb & SdrWaitValid & SDR_WAIT_IN;

//   assign SdrWait            = SDR_WAIT_IN & SdrWaitValid;

   assign WbRowWrapStall     = (WbAddrCntVal > 3'd0) & (WB_ADR_IN[7:2] == 6'h00); // 0x100 byte aligned row
   
   // External assigns
   assign WB_STALL_OUT 	  = (WB_CYC_IN & WB_STB_IN) & (WbReadStall | WbWriteStall | WbAsyncStall | WbRowWrapStall);
   assign WB_ACK_OUT   	  = (WbReadAck & ~ReadFifoReadEmpty)   | WbWriteAck;
   assign WB_ERR_OUT   	  = WB_ADR_IN > (WBA + (2 ** 24));
   
   assign SDR_ADDR_OUT  = SdrAddrReg ;
   assign SDR_CRE_OUT   = SdrCre     ;
   assign SDR_ADVB_OUT  = SdrAdvb    ;
   assign SDR_CEB_OUT   = SdrCeb     ;
   assign SDR_OEB_OUT   = SdrOeb     ;
   assign SDR_WEB_OUT   = SdrWeb     ;

   // Both the byte enables have to be 0 for reads .. 
   assign SDR_LBB_OUT   = (~SdrCeb & SdrWeb) ? 1'b0 : ~SdrByteEnReg[0] ;
   assign SDR_UBB_OUT   = (~SdrCeb & SdrWeb) ? 1'b0 : ~SdrByteEnReg[1] ;

   assign SDR_DATA_INOUT = SdrDataDriveEn ? SdrWriteDataReg : 16'hzzzz;
   assign SdrReadData    = SDR_DATA_INOUT;
   assign CLK_SDR_EN_OUT = ClkSdrEn;

   // Always blocks

   // Gate the SDR enable initially, disable after FSM has written the config reg asynchronously
   always @(posedge CLK or posedge RST_ASYNC)
   begin : CLK_SDR_EN_SR
      if (RST_ASYNC)
      begin
	 ClkSdrEn <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 ClkSdrEn <= 1'b0;
      end
      else if (EN)
      begin
	 if (ClkSdrEnSet)
	 begin
	    ClkSdrEn <= 1'b1;
	 end
      end
   end
   
   // Register the write fifo write en for an ACK back to wishbone
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_WRITE_ACK_REG
      if (RST_ASYNC)
      begin
	 WbWriteAck <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WbWriteAck <= 1'b0;
      end
      else if (EN)
      begin
	 WbWriteAck <= WriteFifoWriteEn;
      end
   end
   
   // Register the Address out to SDRAM
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SDR_ADDR_REG
      if (RST_ASYNC)
      begin
	 SdrAddrReg <= 22'd0;
      end
      else if (RST_SYNC)
	 begin
	    SdrAddrReg <= 22'd0;
	 end
      else if (EN)
      begin
	 if (SdrAddrRegEn)
	 begin
	    SdrAddrReg <= SdrAddrMux;
	 end
      end
   end

   // Register the Byte Enables going out to the SDRAM
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SDR_BYTE_EN_REG
      if (RST_ASYNC)
      begin
	 SdrByteEnReg <= 2'b00;
      end
      else if (RST_SYNC)
      begin
	 SdrByteEnReg <= 2'b00;
      end
      else if (EN && !SdrCeb)
      begin
	 SdrByteEnReg <= SdrByteEn;
      end
   end

   // Register the Write data going out to the SDRAM
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SDR_WRITE_DATA_REG
      if (RST_ASYNC)
      begin
	 SdrWriteDataReg <= 16'h0000;
      end
      else if (RST_SYNC)
      begin
	 SdrWriteDataReg <= 16'h0000;
      end
      else if (EN && !SdrCeb)
      begin
	 SdrWriteDataReg <= SdrWriteData;
      end
   end

//   
//   // Register the WAIT from SDRAM and use as read enable for Write fifo
//   always @(posedge CLK or posedge RST_ASYNC)
//   begin : WRITE_FIFO_READ_EN_REG
//      if (RST_ASYNC)
//      begin
//	 WriteFifoReadEn <= 1'b0;
//      end
//      else if (RST_SYNC)
//      begin
//	 WriteFifoReadEn <= 1'b0;
//      end
//      else if (EN)
//      begin
//	 WriteFifoReadEn <= SdrDataStb & ~SdrWeb;
//      end
//   end
//
//   
//   // Register the Read WAIT on the negedge of the clock
//   always @(negedge CLK or posedge RST_ASYNC)
//   begin : READ_FIFO_WRITE_NEG_REG
//      if (RST_ASYNC)
//      begin
//	 ReadFifoWriteEn <= 1'b0;
//      end
//      else if (RST_SYNC)
//      begin
//	 ReadFifoWriteEn <= 1'b0;
//      end
//      else if (EN)
//      begin
//	 ReadFifoWriteEn <= SdrDataStb & SdrWeb;
//      end
//   end
//
//   
//   // Register the Read Data on the negedge of the clock
//   always @(negedge CLK or posedge RST_ASYNC)
//   begin : READ_FIFO_DATA_NEG_REG
//      if (RST_ASYNC)
//      begin
//	 ReadFifoWriteData <= 16'h0000;
//      end
//      else if (RST_SYNC)
//      begin
//	 ReadFifoWriteData <= 16'h0000;
//      end
//      else if (EN)
//      begin
//	 ReadFifoWriteData <= SdrReadData;
//      end
//   end
//
//   // Register the WAIT signal on posedge to delay the FSM moving on
//   always @(posedge CLK or posedge RST_ASYNC)
//   begin : SDR_WAIT_REG
//      if (RST_ASYNC)
//      begin
//	 SdrWaitReg <= 1'b0;
//      end
//      else if (RST_SYNC)
//      begin
//	 SdrWaitReg <= 1'b0;
//      end
//      else if (EN)
//      begin
//	 SdrWaitReg <= SDR_WAIT_IN;
//      end
//   end
//
   
   // Wishbone Address Counter
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_ADDR_CNT
      if (RST_ASYNC)
      begin
	 WbAddrCntVal <= 3'd0;
      end
      else if (RST_SYNC)
      begin
	 WbAddrCntVal <= 3'd0;
      end
      else if (EN)
      begin
	 if (WbAddrCntClr && WbAddrStb)
	 begin
	    WbAddrCntVal <= 3'd1;
	 end
	 else if (WbAddrCntClr)
	 begin
	    WbAddrCntVal <= 3'd0;
	 end
	 else if (WbAddrStb)
	 begin
	    WbAddrCntVal <= WbAddrCntVal + 3'd1;
	 end
      end
   end

   // SDRAM Data counter
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SDR_DATA_CNT
      if (RST_ASYNC)
      begin
	 SdrDataCntVal <= 4'd0;
      end
      else if (RST_SYNC)
      begin
	 SdrDataCntVal <= 4'd0;
      end
      else if (EN)
      begin
	 if (SdrDataCntClr && SdrDataStb)
	 begin
	    SdrDataCntVal <= 4'd1;
	 end
	 else if (SdrDataStb)
	 begin
	    SdrDataCntVal <= SdrDataCntVal + 4'd1;
	 end
	 else if (SdrDataCntClr)
	 begin
	    SdrDataCntVal <= 4'd0;
	 end
      end
   end

   // ASYNC counter (for asynchronous CRE access)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SDR_ASYNC_CNT
      if (RST_ASYNC)
      begin
	 SdrAsyncCntVal <= 4'd0;
      end
      else if (RST_SYNC)
      begin
	 SdrAsyncCntVal <= 4'd0;
      end
      else if (EN)
      begin
	 if (SdrAsyncCntLd)
	 begin
	    SdrAsyncCntVal <= ASYNC_CLKS;
	 end
	 else if (| SdrAsyncCntVal)
	 begin
	    SdrAsyncCntVal <= SdrAsyncCntVal - 4'd1;
	 end
      end
   end

   // FSM : Combinatorial next state and output decoder
   always @(*)
   begin : SDRFSM_ST
      
      SdrFsmStateNxt = SdrFsmStateCur;
      
      WbReadAckNxt    = 1'b0;
      WbReadStallNxt  = 1'b0;
      WbWriteStallNxt = 1'b0;
      WbAsyncStallNxt = 1'b0;
      
      SdrCreNxt       = 1'b0;
      SdrAdvbNxt      = 1'b1; // active low !
      SdrCebNxt       = 1'b1; // active low !
      SdrOebNxt       = 1'b1; // active low !
      SdrWebNxt       = 1'b1; // active low !
      
      SdrBcrAddrbSel  = 1'b0;
      SdrAddrRegEn    = 1'b0;
      WbAddrCntClr    = 1'b0;
      SdrDataCntClr   = 1'b0;
      SdrAsyncCntLd   = 1'b0;

      ClkSdrEnSet     = 1'b0;
      SdrWaitValidNxt = 1'b0;

      
      case (SdrFsmStateCur)

	SDRFSM_IDLE :
	   begin
	      SdrCreNxt      	 = 1'b1;
	      SdrAdvbNxt     	 = 1'b0;
	      SdrCebNxt      	 = 1'b0;
	      //	      SdrWebNxt      	 = 1'b0;
	      SdrBcrAddrbSel 	 = 1'b1;
	      SdrAddrRegEn   	 = 1'b1;
	      SdrAsyncCntLd  	 = 1'b1;
	      WbAsyncStallNxt	 = 1'b1;
	      // Next state
	      SdrFsmStateNxt = SDRFSM_BCR_WRITE_REQ;
	   end
	
	SDRFSM_BCR_WRITE_REQ :
	   begin
	      // Current state outputs
	      SdrCreNxt       = 1'b1;
	      SdrCebNxt       = 1'b0;
	      SdrWebNxt       = 1'b0;
	      WbAsyncStallNxt = 1'b1;
	      // Need to change outputs to be registered a cycle before timer expires
	      if (3'd1 == SdrAsyncCntVal)
	      begin
		 // Next state outputs
		 SdrCreNxt      = 1'b0;
		 SdrCebNxt      = 1'b1;
		 SdrWebNxt      = 1'b1;
		 WbAddrCntClr   = 1'b1;
		 SdrDataCntClr  = 1'b1;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_BCR_WRITE_ACK;
	      end
	   end

	SDRFSM_BCR_WRITE_ACK :
	   begin
	      ClkSdrEnSet     = 1'b1;
//	      WbAsyncStallNxt = 1'b1;
	      // Next state
	      SdrFsmStateNxt = SDRFSM_READY;
	   end

	SDRFSM_READY            :
	   begin
	      // Current state outputs
	      if (WbRead && WbAddrStb)
	      begin
		 // Next state outputs
		 SdrAddrRegEn = 1'b1;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_WB_READ_ADDR;
	      end

	      else if (WbWrite && WbAddrStb)
	      begin
		 // Next state outputs
		 SdrAddrRegEn = 1'b1;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_WB_WRITE_DATA;
	      end
	   end

	SDRFSM_WB_READ_ADDR    :
	   begin
	      // Current state outputs
	      if ((!WbAddrStb) || ((3'd3 == WbAddrCntVal) && WbAddrStb))
	      begin
		 // Next state outputs
		 SdrAdvbNxt     = 1'b0;
		 SdrCebNxt      = 1'b0;
		 WbReadStallNxt = 1'b1;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_SDR_READ_DATA;
	      end
	   end

	SDRFSM_SDR_READ_DATA    :
	   begin
	      // Current state outputs
	      SdrCebNxt   = 1'b0;
	      SdrOebNxt   = 1'b0;
	      SdrWaitValidNxt = 1'b1;
	      WbReadStallNxt  = 1'b1;

	      if ((SdrDataCntVal == WbAddrCntValShift - 1) && SdrDataStb)
	      begin
		 // Next state outputs
		 SdrCebNxt   = 1'b1;
		 SdrOebNxt   = 1'b1;
		 WbReadAckNxt    = 1'b1;
		 SdrWaitValidNxt = 1'b0;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_WB_READ_DATA;
	      end
	   end

	SDRFSM_WB_READ_DATA     :
	   begin
	      // Current state outputs
	      WbReadAckNxt = 1'b1;
	      WbReadStallNxt  = 1'b1;

	      if ((3'd2 == SdrDataCntVal) || ReadFifoReadEmpty)
	      begin
		 // Next state outputs
		 WbReadAckNxt   = 1'b0;
		 WbReadStallNxt = 1'b0;
		 WbAddrCntClr   = 1'b1;
		 SdrDataCntClr  = 1'b1;
 		 // Next state
		 SdrFsmStateNxt = SDRFSM_READY;
	      end
	   end
	      
//	      else if (ReadFifoReadEmpty)
//	      begin
//		 // Next state outputs
//		 WbReadAckNxt   = 1'b0;
//		 WbReadStallNxt = 1'b0;
//		 WbAddrCntClr   = 1'b1;
//		 SdrDataCntClr  = 1'b1;
//		 // Next state
//		 SdrFsmStateNxt = SDRFSM_READY;
//	      end
//	   end

	SDRFSM_WB_WRITE_DATA     :
	   begin
	      // Current state outputs
	      if (!WbAddrStb || ((3'd3 == WbAddrCntVal) && WbAddrStb))
	      begin
		 // Next state outputs
		 SdrAdvbNxt       = 1'b0;
		 SdrCebNxt        = 1'b0;
		 SdrWebNxt        = 1'b0;
		 WbWriteStallNxt  = 1'b1;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_SDR_WRITE_DATA;
	      end
	   end

	SDRFSM_SDR_WRITE_DATA   :
	   begin
	      // Current state outputs
	      SdrCebNxt        = 1'b0;
	      SdrWebNxt        = 1'b0;
	      WbWriteStallNxt  = 1'b1;
	      SdrWaitValidNxt  = 1'b1;

	      // SDRAM Write data and byte enables are registered to SDRAM, so extend the SDRAM transaction by one cycle after the last data is read
	      if ((SdrDataCntVal == WbAddrCntValShift) && SdrDataStb)
	      begin
		 // Next state outputs
		 SdrCebNxt        = 1'b1;
		 SdrWebNxt        = 1'b1;
//		 WbWriteStallNxt  = 1'b0; <- Can't accept a new address yet .. 
		 SdrWaitValidNxt  = 1'b0;
		 // Next state
		 SdrFsmStateNxt = SDRFSM_WRITE_END;
	      end
	      
	   end

	SDRFSM_WRITE_END        :
	   begin
	      // Current state outputs
	      SdrDataCntClr = 1'b1;
	      WbAddrCntClr  = 1'b1;
	      // Also the WbStall is active from the previous state, so no new WB trans can be started here..
	      
	      // Next state
	      SdrFsmStateNxt = SDRFSM_READY;
	   end
	default : SdrFsmStateNxt = SdrFsmStateCur;
      endcase // case (SdrFsmStateCur)
   end
   

   // FSM : Clocked process
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SDRFSM_CP
      if (RST_ASYNC)
      begin
	 SdrFsmStateCur <= SDRFSM_IDLE;
	 
	 WbReadAck    <= 1'b0 ;
	 WbWriteStall <= 1'b0 ;
	 WbAsyncStall <= 1'b1 ; // Want to come out of reset stalling WB-side
	 
	 SdrCre       <= 1'b0 ;
	 SdrAdvb      <= 1'b1 ;
	 SdrCeb       <= 1'b1 ;
	 SdrOeb       <= 1'b1 ;
	 SdrWeb       <= 1'b1 ;

	 SdrWaitValid <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 SdrFsmStateCur <= SDRFSM_IDLE;
	 
	 WbReadAck    <= 1'b0 ;
	 WbWriteStall <= 1'b0 ;
	 WbAsyncStall <= 1'b1 ; // Want to come out of reset stalling WB-side
	 
	 SdrCre       <= 1'b0 ;
	 SdrAdvb      <= 1'b1 ;
	 SdrCeb       <= 1'b1 ;
	 SdrOeb       <= 1'b1 ;
	 SdrWeb       <= 1'b1 ;

	 SdrWaitValid <= 1'b0;
      end
      else if (EN)
      begin
	 SdrFsmStateCur <= SdrFsmStateNxt;

	 WbReadAck      <= WbReadAckNxt    ;
	 WbWriteStall   <= WbWriteStallNxt ;
	 WbReadStall    <= WbReadStallNxt  ;
	 WbAsyncStall   <= WbAsyncStallNxt ;
	    
	 SdrCre       <= SdrCreNxt  ;
	 SdrAdvb      <= SdrAdvbNxt ;
	 SdrCeb       <= SdrCebNxt  ;
	 SdrOeb       <= SdrOebNxt  ;
	 SdrWeb       <= SdrWebNxt  ;

    	 SdrWaitValid <= SdrWaitValidNxt;
      end
   end
   
   // Module instantiations


   // Write Fifo
   SYNC_FIFO 
      #(
	.D_P2       ( 2),
	.BW         (18),
	.WWM        ( 2),
	.RWM        ( 1),
	.USE_RAM    ( 0) 
	)
   sync_fifo_write_data
      (
       .WR_CLK           (CLK              ),
       .RD_CLK           (CLK              ),
//       .EN               (EN               ),
       .RST_SYNC         (RST_SYNC         ),
       .RST_ASYNC        (RST_ASYNC        ),
      
       .WRITE_EN_IN      (WriteFifoWriteEn   ),
       .WRITE_DATA_IN    (WriteFifoWriteData ),
       .WRITE_FULL_OUT   (WriteFifoWriteFull ),

       .READ_EN_IN       (WriteFifoReadEn    ),
       .READ_DATA_OUT    (WriteFifoReadData  ),
       .READ_EMPTY_OUT   (WriteFifoReadEmpty )
       );


   // Read Fifo
   SYNC_FIFO 
      #(
	.D_P2       ( 3),
	.BW         (16),
	.WWM        ( 1),
	.RWM        ( 2),
	.USE_RAM    ( 0) 
	)
   sync_fifo_read_data 
      (
       .WR_CLK           (CLK              ),
       .RD_CLK           (CLK              ),
//       .EN               (EN               ),
       .RST_SYNC         (RST_SYNC         ),
       .RST_ASYNC        (RST_ASYNC        ),
      
       .WRITE_EN_IN      (ReadFifoWriteEn   ),
       .WRITE_DATA_IN    (SdrReadData       ),
       .WRITE_FULL_OUT   (ReadFifoWriteFull ),

       .READ_EN_IN       (WbReadAck         ),
       .READ_DATA_OUT    (WB_RD_DAT_OUT     ),
       .READ_EMPTY_OUT   (ReadFifoReadEmpty )
       );

   
   
   
   
endmodule // SDRAM_CONTROLLER

