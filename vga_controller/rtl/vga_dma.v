module VGA_DMA
  #(parameter X_MSB = 0,
    parameter Y_MSB = 0,

    // RGB Data Packing
    parameter R_HI = 7, 
    parameter R_LO = 5,
    parameter G_HI = 4,
    parameter G_LO = 2,
    parameter B_HI = 1,
    parameter B_LO = 0
    
    )
   (
    // Clocks and resets
    input          CLK            , // Framebuffer clock
    input          EN             ,
    input          RST_SYNC       , // Reset de-asserted with FB clock
    input          RST_ASYNC      , // Reset de-asserted with FB clock

    // Wishbone MASTER interface
    output  [31:0] WB_ADR_OUT     ,
    output         WB_CYC_OUT     ,
    output         WB_STB_OUT     ,
    output         WB_WE_OUT      ,
    output  [ 3:0] WB_SEL_OUT     ,
    output  [ 2:0] WB_CTI_OUT     , 
    output  [ 1:0] WB_BTE_OUT     , 

    input          WB_STALL_IN    ,
    input          WB_ACK_IN      ,
    input          WB_ERR_IN      ,

    input  [31:0]  WB_DAT_RD_IN   , 
    output [31:0]  WB_DAT_WR_OUT  , 

    // VGA-side ports
    output         WB_PIXEL_DATA_EN_OUT  ,
    output   [7:0] WB_PIXEL_DATA_OUT     ,
    input          WB_PIXEL_DATA_FULL_IN ,
    input          WB_VS_STB_IN          ,
    input          WB_HS_STB_IN          ,
    input          WB_ACTIVE_LINE_IN     ,

    // Configuration
    input            CFG_DITHER_IN          , // unused currently
    input            CFG_LINEAR_FB_IN       ,
    input [    1: 0] CFG_PIXEL_FMT_IN       ,
    input [   31:20] CFG_BASE_ADDR_IN       ,
    input [X_MSB: 0] CFG_TOP_LEFT_X_IN      ,
    input [Y_MSB: 0] CFG_TOP_LEFT_Y_IN      ,
    input [X_MSB: 0] CFG_START_X_IN         ,
    input [X_MSB: 0] CFG_END_X_IN           ,
    input [Y_MSB: 0] CFG_START_Y_IN         ,
    input [Y_MSB: 0] CFG_END_Y_IN               

  );

   parameter [1:0] WB_8B  = 2'b00;
   parameter [1:0] WB_16B = 2'b01;
   parameter [1:0] WB_32B = 2'b10;

   parameter [1:0] PIXEL_FMT_PSX_16B = 2'b00;
   parameter [1:0] PIXEL_FMT_PSX_24B = 2'b01;
   parameter [1:0] PIXEL_FMT_RGB_8B  = 2'b10;
   parameter [1:0] PIXEL_FMT_RGB_24B = 2'b11;
   
   
// includes

   // FSM parameters and wires
   parameter [1:0] VDFSM_IDLE        = 2'b00;
   parameter [1:0] VDFSM_ACTIVE      = 2'b01;
   parameter [1:0] VDFSM_REQ_DATA    = 2'b10;
   parameter [1:0] VDFSM_PIXEL_DATA  = 2'b11;

      // wires /regs
   reg [1:0] 	  VdfsmStateCur;
   reg [1:0] 	  VdfsmStateNxt;

   // FSM inputs
   reg [4:0] 	  BusTmrVal;
   
   // FSM outputs
   reg 		  BusReadReqNxt;
   reg 		  BusReadReq;
   reg 		  WbMasterRegEn;
   reg 		  PixelDataEn;

   // Registered frame config (on VSYNC strobe)
   reg             CfgDitherReg       ;
   reg             CfgLinearFbReg     ;
   reg  [    1: 0] CfgPixelFmtReg     ;
   reg  [   31:20] CfgBaseAddrReg     ;
   reg  [X_MSB: 0] CfgTopLeftXReg     ;
   reg  [Y_MSB: 0] CfgTopLeftYReg     ;
   reg  [X_MSB: 0] CfgStartXReg       ;
   reg  [X_MSB: 0] CfgEndXReg         ;
   reg  [Y_MSB: 0] CfgStartYReg       ;
   reg  [Y_MSB: 0] CfgEndYReg         ;     


   // Convert the 16b start and end x into byte form
   wire [X_MSB+1:0] CfgStartXRegByte = {CfgStartXReg, 1'b0};
   wire [X_MSB+1:0] CfgEndXRegByte   = {CfgEndXReg  , 1'b0};

   wire [X_MSB+Y_MSB+2:0] LinearFbXY; //  = FbXByte + (FbY * CfgEndXRegByte);
   
   // Need to count the X dimension in bytes, as each read returns 3 x 4 bytes = 12 bytes. 
   // In 16-bit mode, each pixel is 2 bytes, in 24-bit mode, each pixel is 3 bytes.
//   reg  [X_MSB+1:0] FbXCntByte; // Need to count in units of bytes as a pixel can be either 3 bytes (24 bit) or 2 (16 bit)
   reg  [X_MSB+1:0]  FbXByte; //  = FbXCntByte + {CFG_START_X_IN, 1'b0}; // X counter is in units of bytes, start X is in 16-bit units
   wire [X_MSB+1:0]  FbXBytesLeft = CfgEndXRegByte - FbXByte;
   
//   reg  [Y_MSB:0]   FbYCnt;     // Y Counter is in units of lines

   wire 	    FbEndOfLine = (FbXByte >= CfgEndXRegByte);
   
   reg [Y_MSB:0]    FbY; //  = FbYCnt + CfgStartYReg;
   wire 	    FbEndOfFrame = (FbY == CfgEndYReg);

   wire [31:0] 	    BusAddr  = CfgLinearFbReg ? {CfgBaseAddrReg        , // 31:20 (12 bits)
						 LinearFbXY              // 19:0  (20 bits)
						 } :
						 {CfgBaseAddrReg       , // 31:20 (12 bits)
						  FbY                  , // 19:11 ( 9 bits)     
						  FbXByte                // 10:0  (10 bits)     
						  };
//   reg  	    BusReadReq    ;
   wire 	    BusReadAck    ;
   wire 	    BusReadDataEn = BusReadReq & BusReadAck;

   wire [31:0] 	    BusReadData;

   reg  [  4:0]     PixelByteCnt;
   reg  [ 95:0]     PixelShiftReg; // 96 bits => 12 bytes => 4 24 bit pixels, or 6 16 bit pixels

//   wire 	    PixelDataEn; <- now controlled by the FSM

   reg [1:0] 	    WbMasterBusSize ;
   reg [4:0] 	    WbMasterBusLen  ;
   reg [1:0] 	    WbMasterBusSizeReg ;
   reg [4:0] 	    WbMasterBusLenReg  ;

   // internal assigns
   assign LinearFbXY = (CfgStartXRegByte + FbXByte) + (CfgStartYReg + (FbY * CfgEndXRegByte));

   
   // Alternate between requesting DMA burst data, and pushing this into the FIFO
//   assign PixelDataEn = (PixelByteCnt > 0) & ~BusReadReq & ~WB_PIXEL_DATA_FULL_IN; <- now controlled by the FSM
//   assign BusReadReq  = ~PixelDataEn & ~FbEndOfLine & (PixelByteCnt < 5'd12); 
   
   // external assigns
   assign WB_PIXEL_DATA_EN_OUT         = PixelDataEn;
   assign WB_PIXEL_DATA_OUT[R_HI:R_LO] = PixelShiftReg[ 7: 5]; // [23:21];
   assign WB_PIXEL_DATA_OUT[G_HI:G_LO] = PixelShiftReg[15:13];
   assign WB_PIXEL_DATA_OUT[B_HI:B_LO] = PixelShiftReg[23:22]; // [ 7: 6];

   // Always blocks


   // Register the frame config on a VSYNC strobe
   always @(posedge CLK or posedge RST_ASYNC)
   begin : CONFIG_REG
      if (RST_ASYNC)
      begin
	 CfgDitherReg     <= 1'b0;
	 CfgLinearFbReg   <= 1'b0;
	 CfgPixelFmtReg   <= 2'b00;
	 CfgBaseAddrReg   <= 12'd0;
	 CfgTopLeftXReg   <= {X_MSB+1{1'b0}};
	 CfgTopLeftYReg   <= {Y_MSB+1{1'b0}};
	 CfgStartXReg     <= {X_MSB+1{1'b0}};
	 CfgEndXReg       <= {X_MSB+1{1'b0}};
	 CfgStartYReg     <= {Y_MSB+1{1'b0}};
	 CfgEndYReg       <= {Y_MSB+1{1'b0}};
      end
      else if (RST_SYNC)
      begin
	 CfgDitherReg     <= 1'b0;
	 CfgLinearFbReg   <= 1'b0;
	 CfgPixelFmtReg   <= 2'b00;
	 CfgBaseAddrReg   <= 12'd0;
	 CfgTopLeftXReg   <= {X_MSB+1{1'b0}};
	 CfgTopLeftYReg   <= {Y_MSB+1{1'b0}};
	 CfgStartXReg     <= {X_MSB+1{1'b0}};
	 CfgEndXReg       <= {X_MSB+1{1'b0}};
	 CfgStartYReg     <= {Y_MSB+1{1'b0}};
	 CfgEndYReg       <= {Y_MSB+1{1'b0}};
      end
      else if (EN && WB_VS_STB_IN)
      begin
	 CfgDitherReg     <= CFG_DITHER_IN     ;
	 CfgLinearFbReg   <= CFG_LINEAR_FB_IN  ;
	 CfgPixelFmtReg   <= CFG_PIXEL_FMT_IN  ;
	 CfgBaseAddrReg   <= CFG_BASE_ADDR_IN  ;
	 CfgTopLeftXReg   <= CFG_TOP_LEFT_X_IN ;
	 CfgTopLeftYReg   <= CFG_TOP_LEFT_Y_IN ;
	 CfgStartXReg     <= CFG_START_X_IN    ;
	 CfgEndXReg       <= CFG_END_X_IN      ;
	 CfgStartYReg     <= CFG_START_Y_IN    ;
	 CfgEndYReg       <= CFG_END_Y_IN      ;
      end
   end

// This is now controlled by the FSM   
//   // Bus request register
//   always @(posedge CLK or posedge RST_ASYNC)
//   begin : BUS_READ_REQ_REG
//      if (RST_ASYNC)
//      begin
//	 BusReadReq <= 1'b0;
//      end
//      else if (RST_SYNC)
//      begin
//	 BusReadReq <= 1'b0;
//      end
//      else if (EN)
//      begin
//	 // Drop the bus request if either:
//	 // - The pixel shift register is full
//	 // - All the pixels have been read for the current line. 
//	 if (BusReadDataEn && ((5'd8 == PixelByteCnt) || (0 == FbXBytesLeft)))
//	 begin
//	    BusReadReq <= 1'b0;
//	 end
//	 // Request a new burst of 3 x 32 if not the end of line, and pixel shift reg empty
//	 else if (!FbEndOfLine && (5'd0 == PixelByteCnt))
//	 begin
//	    BusReadReq <= 1'b1;
//         end
//      end
//   end
   
   // X Counter
   always @(posedge CLK or posedge RST_ASYNC)
   begin : X_CNT
      if (RST_ASYNC)
      begin
	 FbXByte <= {X_MSB+1{1'b0}};
      end
      else if (RST_SYNC)
      begin
	 FbXByte <= {X_MSB+1{1'b0}};
      end
      else if (EN && WB_ACTIVE_LINE_IN)
      begin
	 // At the start of a new line, store the beginning X position
	 if (WB_HS_STB_IN)
	 begin
	    FbXByte <= CfgStartXRegByte;
	 end
	 else if (BusReadDataEn)
	 begin
	    case (WbMasterBusSize)
	      WB_32B : FbXByte <= FbXByte + 4;
	      WB_16B : FbXByte <= FbXByte + 2;
	      WB_8B  : FbXByte <= FbXByte + 1;
	    endcase // case (WbMasterBusLen)
         end
      end
   end
   
   // Y Counter
   // CLR : On a new frame (VSYNC strobe)
   // INC : On a new line (HSYNC strobe)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : Y_CNT
      if (RST_ASYNC)
      begin
	 FbY <= {Y_MSB{1'b0}};
      end
      else if (RST_SYNC)
      begin
	 FbY <= {Y_MSB{1'b0}};
      end
      else if (EN && WB_ACTIVE_LINE_IN)
      begin
	 if (WB_VS_STB_IN)
	 begin
	    FbY <= {Y_MSB+1{1'b0}};
	 end
	 // If you don't qualify the HS with an end of line indicator, you'll increment
	 // on the first active line, and start at line 1, not 0.
	 else if (WB_HS_STB_IN && (FbEndOfLine))
	 begin
	    FbY <= FbY + 1;
	 end
      end
   end
   
   // Pixel Shift register counter.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_PIXEL_SHIFT_REG_CNT
      if (RST_ASYNC)
      begin
	 PixelByteCnt <= 5'd0;
      end
      else if (RST_SYNC)
      begin
	 PixelByteCnt <= 5'd0;
      end
      else if (EN)
      begin
	 if (BusReadDataEn)
	 begin
	    case (WbMasterBusSize)
	      WB_32B : PixelByteCnt <= PixelByteCnt + 5'd4;
	      WB_16B : PixelByteCnt <= PixelByteCnt + 5'd2;
	      WB_8B  : PixelByteCnt <= PixelByteCnt + 5'd1;
	    endcase // case (WbMasterBusSize)
	 end
	 // Need to protect the counter from wrapping, as you don't know if the x width in bytes
	 // will be a multiple of the pixel byte cnt
	 else if (PixelDataEn)
	 begin
	    case (CfgPixelFmtReg)
	      PIXEL_FMT_PSX_16B : 
		 begin
		    if (PixelByteCnt > 5'd2) 
		    begin
		       PixelByteCnt <= PixelByteCnt - 5'd2;
		    end
		    else
		    begin
		       PixelByteCnt <= 5'd0;
		    end
		 end
	      
	      PIXEL_FMT_PSX_24B :
		 begin
		    if (PixelByteCnt > 5'd3) 
		    begin
		       PixelByteCnt <= PixelByteCnt - 5'd3;
		    end
		    else
		    begin
		       PixelByteCnt <= 5'd0;
		    end
		 end

	      PIXEL_FMT_RGB_8B  : 
		 begin
		    if (PixelByteCnt > 5'd1) 
		    begin
		       PixelByteCnt <= PixelByteCnt - 5'd1;
		    end
		    else
		    begin
		       PixelByteCnt <= 5'd0;
		    end
		 end

	      PIXEL_FMT_RGB_24B :
		 begin
		    if (PixelByteCnt > 5'd3) 
		    begin
		       PixelByteCnt <= PixelByteCnt - 5'd3;
		    end
		    else
		    begin
		       PixelByteCnt <= 5'd0;
		    end
		 end

	    endcase // case (CfgPixelFmt)
         end
      end
   end

   // Pixel Shift Data Register
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_PIXEL_SHIFT_REG
      if (RST_ASYNC)
      begin
	 PixelShiftReg <= 96'd0;
      end
      else  if (RST_ASYNC)
      begin
	 PixelShiftReg <= 96'd0;
      end
      else if (EN)
      begin
	 if (BusReadDataEn)
	 begin
	    // XST doesn't support this standard v2k construct .. :-/
	    //	 PixelShiftReg[(PixelByteCnt*8) - 1 +: 32] <= BusReadData;

	    if (WB_32B == WbMasterBusSize)
	    begin
	       case (PixelByteCnt)
		 5'd0   : PixelShiftReg[ 31:  0] <= BusReadData ;
		 5'd1   : PixelShiftReg[ 39:  8] <= BusReadData ;
		 5'd2   : PixelShiftReg[ 47: 16] <= BusReadData ;
		 5'd3   : PixelShiftReg[ 55: 24] <= BusReadData ;
		 5'd4   : PixelShiftReg[ 63: 32] <= BusReadData ;
		 5'd5   : PixelShiftReg[ 71: 40] <= BusReadData ;
		 5'd6   : PixelShiftReg[ 79: 48] <= BusReadData ;
		 5'd7   : PixelShiftReg[ 87: 56] <= BusReadData ;
		 5'd8   : PixelShiftReg[ 95: 64] <= BusReadData ;
//		 5'd9   : PixelShiftReg[103: 72] <= BusReadData ;
//		 5'd10  : PixelShiftReg[111: 80] <= BusReadData ;
//		 5'd11  : PixelShiftReg[119: 88] <= BusReadData ;
//		 5'd12  : PixelShiftReg[127: 96] <= BusReadData ;
	       endcase
	    end
	    else if (WB_16B == WbMasterBusSize)
	    begin
	       case (PixelByteCnt)
		 5'd0   : PixelShiftReg[15: 0] <= BusReadData ;
		 5'd1   : PixelShiftReg[23: 8] <= BusReadData ;
		 5'd2   : PixelShiftReg[31:16] <= BusReadData ;
		 5'd3   : PixelShiftReg[39:24] <= BusReadData ;
		 5'd4   : PixelShiftReg[47:32] <= BusReadData ;
		 5'd5   : PixelShiftReg[55:40] <= BusReadData ;
		 5'd6   : PixelShiftReg[63:48] <= BusReadData ;
		 5'd7   : PixelShiftReg[71:56] <= BusReadData ;
		 5'd8   : PixelShiftReg[79:64] <= BusReadData ;
		 5'd9   : PixelShiftReg[87:72] <= BusReadData ;
		 5'd10  : PixelShiftReg[95:80] <= BusReadData ;
//		 5'd11  : PixelShiftReg[:] <= BusReadData ;
//		 5'd12  : PixelShiftReg[:] <= BusReadData ;
	       endcase // case (PixelByteCnt)
	    end
	    else if (WB_8B == WbMasterBusSize)
	    begin
	       case (PixelByteCnt)
		 5'd0   : PixelShiftReg[7 :0 ] <= BusReadData ;
		 5'd1   : PixelShiftReg[15:8 ] <= BusReadData ;
		 5'd2   : PixelShiftReg[23:16] <= BusReadData ;
		 5'd3   : PixelShiftReg[31:24] <= BusReadData ;
		 5'd4   : PixelShiftReg[39:32] <= BusReadData ;
		 5'd5   : PixelShiftReg[47:40] <= BusReadData ;
		 5'd6   : PixelShiftReg[55:48] <= BusReadData ;
		 5'd7   : PixelShiftReg[63:56] <= BusReadData ;
		 5'd8   : PixelShiftReg[71:64] <= BusReadData ;
		 5'd9   : PixelShiftReg[79:72] <= BusReadData ;
		 5'd10  : PixelShiftReg[87:80] <= BusReadData ;
		 5'd11  : PixelShiftReg[95:88] <= BusReadData ;
//		 5'd12  : PixelShiftReg[:] <= BusReadData ;
	       endcase
	    end
	 end

	 // Shift down by 24 bits when registering pixel data out to the panel FIFO
	 else if (PixelDataEn)
	 begin
	    case (CfgPixelFmtReg)
	      PIXEL_FMT_PSX_16B : PixelShiftReg <= {16'd0, PixelShiftReg[95:16]};
	      PIXEL_FMT_PSX_24B : PixelShiftReg <= {24'd0, PixelShiftReg[95:24]};
	      PIXEL_FMT_RGB_8B  : PixelShiftReg <= {8'd0 , PixelShiftReg[95: 8]};
	      PIXEL_FMT_RGB_24B : PixelShiftReg <= {24'd0, PixelShiftReg[95:24]};
	    endcase // case (CfgPixelFmt)

//	    PixelShiftReg[95:0] <= {24'd0, PixelShiftReg[95:24]};
	    
	 end
      end
   end

   // Bus Timer
   // Count down the amount of bus accesses remaining
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BUS_TMR
      if (RST_ASYNC)
      begin
	 BusTmrVal <= 5'd0;
      end
      else if (RST_SYNC)
      begin
	 BusTmrVal <= 5'd0;
      end
      else if (EN)
      begin
	 // 1st priority, if a bus access is ongoing decrement the counter.
	 // Shouldn't need wrap protection as the request line should be dropped
	 // before then.
	 if (BusReadDataEn)
	 begin
	    BusTmrVal <= BusTmrVal - 5'd1;
	 end
	 // When the next bus access parameters are being registered, store the input
	 // to the registers in the timer
	 else if (WbMasterRegEn)
	 begin
	    BusTmrVal <= WbMasterBusLen;
	 end
     end
   end
   
   // Decode the next type of access for the FSM to register
   always @*
   begin : WB_MASTER_ACCESS_DECODE

      // Default to a 3 x 4-byte burst
      WbMasterBusSize = 2'b10; // 32 bits
      WbMasterBusLen  = 5'd3 ; // x 3 beats = 96 bits

      // More than or equal to 12 bytes left
      if (FbXBytesLeft >= 12)
      begin
         WbMasterBusSize = WB_32B;
	 WbMasterBusLen  = 5'd3 ;
      end
      // Between 11 and 8 bytes left
      else if (FbXBytesLeft >= 8)
      begin
         WbMasterBusSize = WB_32B;
	 WbMasterBusLen  = 5'd2 ;
      end
      // Between 7 and 4 bytes left
      else if (FbXBytesLeft >= 4)
      begin
         WbMasterBusSize = WB_32B;
	 WbMasterBusLen  = 5'd1 ;
      end
      // Between 3 and 2 bytes left
      else if (FbXBytesLeft >= 2)
      begin
         WbMasterBusSize = WB_16B;
	 WbMasterBusLen  = 5'd1 ;
      end
      // 1 Byte left
      else if (FbXBytesLeft > 0)
      begin
         WbMasterBusSize = WB_8B;
	 WbMasterBusLen  = 5'd1 ;
      end
   end
   
   // FSM Clocked process
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WBM_REG
      if (RST_ASYNC)
      begin
	 WbMasterBusSizeReg <= 2'b00;
	 WbMasterBusLenReg  <= 5'd0;
      end
      else if (RST_SYNC)
      begin
	 WbMasterBusSizeReg <= 2'b00;
	 WbMasterBusLenReg  <= 5'd0;
      end
      else if (EN && WbMasterRegEn)
      begin
 	 WbMasterBusSizeReg <= WbMasterBusSize;
	 WbMasterBusLenReg  <= WbMasterBusLen;
     end
   end
   
   // FSM - Combinatorial process
   always @*
   begin : VDFSM_ST

      // Default outputs
      VdfsmStateNxt = VdfsmStateCur;

      // Combinatorial outputs
      BusReadReqNxt  = 1'b0;
      WbMasterRegEn  = 1'b0;
      PixelDataEn    = 1'b0;

      case (VdfsmStateCur)

	// If the current line is an active line, kick the FSM off to read in data.
	VDFSM_IDLE        :
	   begin
	      if (WB_HS_STB_IN && WB_ACTIVE_LINE_IN)
	      begin
		 VdfsmStateNxt = VDFSM_ACTIVE;
	      end
	   end

	// Check if we need to read any more bytes from the WB interface.
	// If not, return to the IDLE state and wait for the next line
	VDFSM_ACTIVE      :
	   begin
	      if ((CfgEndXRegByte > FbXByte) & (!WB_PIXEL_DATA_FULL_IN))
	      begin
		 // Next state outputs
		 WbMasterRegEn = 1'b1;
		 BusReadReqNxt = 1'b1;
		 // Next state
		 VdfsmStateNxt = VDFSM_REQ_DATA;
	      end
	      else
	      begin
		 // Next state
		 VdfsmStateNxt = VDFSM_IDLE;
	      end
	   end

	// Request data from the bus. The Size and Length are decoded combinatorially and registered on every new access.
	// Look ahead when the timer will tick down to 0 in the next cycle and de-assert request (2-phase)
	VDFSM_REQ_DATA    :
	   begin
	      // Current output
	      BusReadReqNxt = 1'b1;
	      // Next state / outputs
	      if ((5'd1 == BusTmrVal) && (BusReadDataEn))
	      begin
		 // Next state outputs
		 BusReadReqNxt = 1'b0;
		 // Next state
		 VdfsmStateNxt = VDFSM_PIXEL_DATA;
	      end
	   end

	// Once the Pixel data counter has been filled, clock it into the WB-side of the async fifo.
	// Go back to the active state and check if more bytes are needed from the WB master.
	VDFSM_PIXEL_DATA  :
	   begin
	      // Current output
	      PixelDataEn = 1'b1;
	      // Next state / outputs
	      if (5'd0 == PixelByteCnt)
	      begin
		 // Next state outputs
		 PixelDataEn = 1'b0;
		 // Next state
		 VdfsmStateNxt = VDFSM_ACTIVE;
	      end
	   end
      endcase // case (VdfsmStateCur)
   end
   
   // FSM Clocked process
   always @(posedge CLK or posedge RST_ASYNC)
   begin : VDFSM_CP
      if (RST_ASYNC)
      begin
	 BusReadReq    <= 1'b0;
	 VdfsmStateCur <= VDFSM_IDLE;
      end
      else if (RST_SYNC)
      begin
	 BusReadReq    <= 1'b0;
	 VdfsmStateCur <= VDFSM_IDLE;
      end
      else if (EN)
      begin
	 BusReadReq    <= BusReadReqNxt;
	 VdfsmStateCur <= VdfsmStateNxt;
      end
   end
   
   // Wishbone Master. Read-Only, with 4-beat bursts
   WB_MASTER wb_master
     (
      .CLK            	      (CLK             ),
      .EN            	      (EN              ),
      .RST_SYNC      	      (RST_SYNC        ), 
      .RST_ASYNC      	      (RST_ASYNC       ), 

      .WB_ADR_OUT     	      (WB_ADR_OUT      ),
      .WB_CYC_OUT     	      (WB_CYC_OUT      ),
      .WB_STB_OUT     	      (WB_STB_OUT      ),
      .WB_WE_OUT      	      (WB_WE_OUT       ),
      .WB_SEL_OUT     	      (WB_SEL_OUT      ),
      .WB_CTI_OUT     	      (WB_CTI_OUT      ), 
      .WB_BTE_OUT     	      (WB_BTE_OUT      ), 
      
      .WB_STALL_IN    	      (WB_STALL_IN     ),
      .WB_ACK_IN      	      (WB_ACK_IN       ),
      .WB_ERR_IN      	      (WB_ERR_IN       ),

      .WB_DAT_RD_IN   	      (WB_DAT_RD_IN    ),
      .WB_DAT_WR_OUT 	      (WB_DAT_WR_OUT   ),

      .BUS_START_ADDR_IN      (BusAddr         ), 
      
      .BUS_READ_REQ_IN        (BusReadReq      ),
      .BUS_READ_ACK_OUT       (BusReadAck      ),
      .BUS_WRITE_REQ_IN       (1'b0), // Read-Only WB Master
      .BUS_WRITE_ACK_OUT      (    ),
      .BUS_LAST_ACK_OUT       (    ),
      
      .BUS_SIZE_IN            (WbMasterBusSizeReg ),
      .BUS_LEN_IN             (WbMasterBusLenReg  ), // 3-beat burst => 12 bytes
      .BUS_BURST_ADDR_INC_IN  (1'b1            ), 

      .BUS_READ_DATA_OUT      (BusReadData     ),
      .BUS_WRITE_DATA_IN      (32'h0000_0000   )
      
      );
   
   


   
endmodule // VGA_DMA


