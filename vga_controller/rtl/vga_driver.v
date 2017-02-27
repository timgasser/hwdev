// VGA timings are fixed, and defined in the parameters below.
// The FB size can change from 320x200 to 640x480, the CFG_FB_*_IN specify this.
// This block reads from the FIFO in vga_cdc, sending out to panel.
module VGA_DRIVER
  // Horizontal timings (in Pixel Clocks)
  #(
   parameter H_SYNC    =  96 , // HSYNC duration
   parameter H_BP      =  48 , // Back porch 
   parameter H_ACTIVE  = 640 , // Visible pixels in a line
   parameter H_FP      =  16 , // Front Porch 
  
   // Vertical timings (in Lines)
   parameter V_SYNC    =   2 , // VSYNC duration
   parameter V_BP      =  33 , // Back porch 
   parameter V_ACTIVE  = 480 , // Visible lines in a frame
   parameter V_FP      =  10 , // Front Porch

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
   input         CLK           , // VGA Pixel clock
   input         EN            , // VGA Pixel clock
   input         RST_SYNC      , // Reset de-asserted with PCLK
   input         RST_ASYNC     , // Reset de-asserted with PCLK

   input         VGA_TEST_EN_IN, // VGA Test pattern enable
   
   // CDC FIFO interface
   input   [7:0] VGA_DATA_IN           , // Incoming VGA Data
   output        VGA_DATA_REQ_OUT      , // Data request from FIFO
   output        VGA_ACTIVE_LINE_OUT   , // Signal to the DMA to begin reading as it's an active line
   
   // VGA Panel interface
   output        VGA_VS_OUT     , // VSYNC
   output        VGA_HS_OUT     , // HSYNC

   output  [R_HI-R_LO:0] VGA_RED_OUT    , 
   output  [G_HI-G_LO:0] VGA_GREEN_OUT  , 
   output  [B_HI-B_LO:0] VGA_BLUE_OUT  
   
   );

// Includes

   // Derived parameters
   parameter 	 H_LEN = H_SYNC + H_BP + H_ACTIVE + H_FP; // 800
   parameter 	 V_LEN = V_SYNC + V_BP + V_ACTIVE + V_FP; // 525

   // As the RGB is registered before being sent out to the panel, you need to get the first pixel and the enable
   // ready the pixel before the first one in the active area..
//   parameter 	 H_ACTIVE_START  = H_SYNC + H_BP - 1; 
//   parameter 	 H_ACTIVE_END    = H_SYNC + H_BP + H_ACTIVE - 1;
//   parameter 	 V_ACTIVE_START  = V_SYNC + V_BP;
//   parameter 	 V_ACTIVE_END    = V_SYNC + V_BP + V_ACTIVE - 1;
   
   // 10 bit counters for line and pixels (0 to 1023)
   reg [9:0] 	 VgaPcntVal;
   reg [9:0] 	 VgaLcntVal;

//   wire [9:0] 	 VgaPcntActiveVal = VgaPcntVal - H_ACTIVE_START; // 
//   wire [9:0] 	 VgaLcntActiveVal = VgaLcntVal - V_ACTIVE_START; // 

   // Combinatorial end-of-line signals (reset counters)
   wire 	 VgaEndOfLine   = (VgaPcntVal == H_LEN - 1);
   wire 	 VgaEndOfFrame  = (VgaLcntVal == V_LEN - 1) & VgaEndOfLine;

   // VSYNC and HSYNC are active low. They are both registered, so need to set them low on
   // the cycle before the start of the next frame / line
   wire 	 VgaHsync = ~((VgaPcntVal < H_SYNC - 1) | VgaEndOfLine); 
   wire 	 VgaVsync = ~((VgaLcntVal < V_SYNC) | VgaEndOfFrame);

   // This signal is used to enable the RGB signals out to the panel. It needs to go high a cycle before the active
   // horizontal area of the panel, and go low a cycle before the end also.
   wire VgaActive = ( ((VgaPcntVal >= H_SYNC + H_BP - 1) && (VgaPcntVal <= H_SYNC + H_BP + H_ACTIVE - 2))
		   && ((VgaLcntVal >= V_SYNC + V_BP    ) && (VgaLcntVal <= V_SYNC + V_BP + V_ACTIVE - 1))
		    );

//   reg 	VgaActiveReg;

   reg 		 VgaHsyncReg;
   reg 		 VgaVsyncReg;
   
   reg [7:0] 	 VgaDataReg;
   
   wire 	 VgaDataReq = (VgaActive); //  | VgaActiveReg);

   reg 		 VgaTestEnReg; // Registered version of VGA_TEST_EN_IN using VgaEndOfFrame
   reg [7:0] 	 VgaTestData;  // LUT from pixel and line count for the test pattern
   wire [7:0] 	 VgaData;      // MUXed VGA data between the VGA_DATA_IN and Test Pattern
   
   
   // Internal assigns
   assign VgaData           = VGA_TEST_EN_IN /* VgaTestEnReg */ ? VgaTestData : VGA_DATA_IN;

   // External assigns
   assign  VGA_DATA_REQ_OUT = VgaDataReq; 
   // Need to send a signal back to the DMA to indicate it's the start of an active line. You only want to start reading from
   // the framebuffer at the start of active lines, as the FIFO is sized for a line buffer.
   assign  VGA_ACTIVE_LINE_OUT =  ((VgaLcntVal >= V_SYNC + V_BP    ) && (VgaLcntVal <= V_SYNC + V_BP + V_ACTIVE - 1));
   
   assign  VGA_VS_OUT 	    = VgaVsyncReg;
   assign  VGA_HS_OUT 	    = VgaHsyncReg;
   
   assign  VGA_RED_OUT      = VgaDataReg[R_HI:R_LO];
   assign  VGA_GREEN_OUT    = VgaDataReg[G_HI:G_LO]; 
   assign  VGA_BLUE_OUT     = VgaDataReg[B_HI:B_LO];

   // Pixel Counter
   always @(posedge CLK     or posedge RST_ASYNC)
   begin : PCNT
      if (RST_ASYNC)
      begin
	 VgaPcntVal <= 10'd0;
      end
      else if (RST_SYNC)
      begin
	 VgaPcntVal <= 10'd0;
      end
      else if (EN)
      begin
	 if (VgaEndOfLine)
	 begin
	    VgaPcntVal <= 10'd0;
	 end
	 else
	 begin
	    VgaPcntVal <= VgaPcntVal + 10'd1;
	 end
      end
   end
   
   // Line Counter
   always @(posedge CLK     or posedge RST_ASYNC)
   begin : LCNT
      if (RST_ASYNC)
      begin
	 VgaLcntVal <= 10'd0;
      end
      else if (RST_SYNC)
      begin
	 VgaLcntVal <= 10'd0;
      end
      else if (EN)
      begin
	 if (VgaEndOfFrame)
	 begin
	    VgaLcntVal <= 10'd0;
	 end
	 else if (VgaEndOfLine)
	 begin
	    VgaLcntVal <= VgaLcntVal + 10'd1;
	 end
      end
   end

   // VGA Test Pattern LUT
   always @*
   begin : VGA_TEST_DATA_LUT
      VgaTestData = 8'h00;

      // First priority - dotted black and white lines around edges. The data has to be muxed in the
      // pixel before the first pixel of the active area, as the RGB data is registered.
      if (  ((H_SYNC + H_BP - 1 == VgaPcntVal) || (H_SYNC + H_BP + H_ACTIVE - 2 == VgaPcntVal))
      // Horizontal black stripes at start and end of vertical active ares
	 || ((V_SYNC + V_BP     == VgaLcntVal) || (V_SYNC + V_BP + V_ACTIVE - 1 == VgaLcntVal))
	 )
      begin
	 VgaTestData = {8{VgaPcntVal[0] ^ VgaLcntVal[0]}};
      end
      else if ((VgaPcntVal > H_SYNC + H_BP - 1) && (VgaPcntVal < H_SYNC + H_BP + H_ACTIVE - 1 ))
      begin

	 if (VgaPcntVal < H_SYNC + H_BP + 9'd213)
	 begin
	    VgaTestData = 8'b1110_0000; // Red
	 end
	 else if (VgaPcntVal < H_SYNC + H_BP + 9'd426)
	 begin
	    VgaTestData = 8'b0001_1100; // Green 
	 end
	 else if (VgaPcntVal < H_SYNC + H_BP + H_ACTIVE)
	 begin
	    VgaTestData = 8'b0000_0011; // Blue
	 end
      end
   end
   
//   // VGA ACTIVE register
//   always @(posedge CLK     or posedge RST_ASYNC)
//   begin : VGA_ACTIVE_REG
//      if (RST_ASYNC)
//      begin
//	 VgaActiveReg <= 1'b0;
//      end
//      else if (RST_SYNC)
//      begin
//	 VgaActiveReg <= 1'b0;
//      end
//      else if (EN)
//      begin
//	 VgaActiveReg <= VgaActive;
//      end
//   end
//
   

   // VGA Test mode register. Don't update the register until the end of the frame
   // to avoid tearing artifact when enabled hte test mode
     always @(posedge CLK     or posedge RST_ASYNC)
   begin : VGA_TEST_MODE_REG
      if (RST_ASYNC)
      begin
	 VgaTestEnReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 VgaTestEnReg <= 1'b0;
      end
      else if (EN)
      begin
	 if (VgaEndOfFrame)
	 begin
	    VgaTestEnReg <= VGA_TEST_EN_IN;
	 end
	 
      end
   end
	
   // Output register
   always @(posedge CLK     or posedge RST_ASYNC)
   begin : OUTPUT_REG
      if (RST_ASYNC)
      begin
	 VgaVsyncReg <= 1'b1;  // active low !      
	 VgaHsyncReg <= 1'b1;         
	 VgaDataReg  <= 8'h00;
      end
      else if (RST_SYNC)
      begin
	 VgaVsyncReg <= 1'b1;  // active low !      
	 VgaHsyncReg <= 1'b1;         
	 VgaDataReg  <= 8'h00;
      end
      else if (EN)
      begin

	 VgaVsyncReg <= VgaVsync;     
	 VgaHsyncReg <= VgaHsync;      

	 if (VgaActive)
	 begin
	    VgaDataReg  <= VgaData; // VGA_DATA_IN; <- now muxed between test pattern and VGA_DATA_IN
	 end
	 else
	 begin
//     	    VgaVsyncReg <= 1'b1;  // active low !
//	    VgaHsyncReg <= 1'b1;         
	    VgaDataReg  <= 8'h00;
	 end
      end
   end

   
endmodule // VGA_DRIVER

