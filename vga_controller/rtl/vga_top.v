// Top level of the VGA controller. Includes:
// VGA_DMA : WB Master to read pixel data from memory
// VGA_CDC : CDC for the Pixel data, and to convert HSYNC and VSYNC into WB domain pulses
// VGA_DRIVER : Reads pixel data from the async fifo, and drives it to the panel


module VGA_TOP
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
   input          CLK_VGA        , // VGA Pixel clock
   input          EN_VGA         , // VGA Pixel clock
   input          RST_SYNC_VGA   , // Reset de-asserted with PCLK
   input          RST_ASYNC_VGA  , // Reset de-asserted with PCLK
   
   input          CLK_WB         , // Framebuffer clock
   input          EN_WB          , 
   input          RST_SYNC_WB    , // Reset de-asserted with FB clock
   input          RST_ASYNC_WB   , // Reset de-asserted with FB clock

   // VGA Test mode (displays a fixed pattern on VGA without reading from DMA)
   input          VGA_TEST_EN_IN,
   
   // Wishbone interface (Master)
   output [31:0]  WB_ADR_OUT     ,
   output         WB_CYC_OUT     ,
   output         WB_STB_OUT     ,
   output         WB_WE_OUT      ,
   output [ 3:0]  WB_SEL_OUT     ,
   output [ 2:0]  WB_CTI_OUT     ,
   output [ 1:0]  WB_BTE_OUT     ,

   input          WB_ACK_IN      ,
   input          WB_STALL_IN    ,
   input          WB_ERR_IN      ,

   input  [31:0]  WB_DAT_RD_IN   ,
   output [31:0]  WB_DAT_WR_OUT  ,
  
   // VGA Panel interface
   output        VGA_VS_OUT     ,
   output        VGA_HS_OUT     ,

   output  [2:0] VGA_RED_OUT    , 
   output  [2:0] VGA_GREEN_OUT  , 
   output  [1:0] VGA_BLUE_OUT   ,

   // Root Counter ports
   output        WB_RCNT_ACTIVE_ROW_OUT ,
   output        WB_RCNT_ACTIVE_COL_OUT ,

   // Configuration inputs
   input            CFG_DITHER_IN       , // unused currently
   input            CFG_LINEAR_FB_IN    , // unused currently
   input [    1: 0] CFG_PIXEL_FMT_IN    , // 00 = PSX_16B, 01 = PSX_24B, 10 = RGB_8B, 11 = RGB_24B
   input [   31:20] CFG_BASE_ADDR_IN    ,
   input [X_MSB: 0] CFG_TOP_LEFT_X_IN   ,
   input [Y_MSB: 0] CFG_TOP_LEFT_Y_IN   ,
   input [X_MSB: 0] CFG_START_X_IN      ,
   input [X_MSB: 0] CFG_END_X_IN        ,
   input [Y_MSB: 0] CFG_START_Y_IN      ,
   input [Y_MSB: 0] CFG_END_Y_IN        
  
   );
   
   // wires
   // Wishbone domain pixel data, enable, and H/VSYNC
   wire 	  WbPixelDataEn   ;
   wire [7:0] 	  WbPixelData     ;
   wire 	  WbPixelDataFull ;
   wire 	  WbActiveLine  ;   
   wire 	  WbVsStb       ;
   wire 	  WbHsStb       ;

   // VGA-domain pixel data, enable, and H/VSYNC
   wire 	  VgaPixelDataEn ;
   wire 	  VgaActiveLine  ;
   wire [7:0] 	  VgaPixelData   ;
   wire 	  VgaVsStb       ;
   wire 	  VgaHsStb       ;

   // external assigns

   assign VGA_VS_OUT = VgaVsStb;
   assign VGA_HS_OUT = VgaHsStb;


   VGA_DMA
      #( .X_MSB (X_MSB),
	 .Y_MSB (Y_MSB),
      
	 .R_HI  (R_HI ),
	 .R_LO  (R_LO ),
	 .G_HI  (G_HI ),
	 .G_LO  (G_LO ),
	 .B_HI  (B_HI ),
	 .B_LO  (B_LO )
	 )
   vga_dma
      (
       .CLK                    (CLK_WB          ),
       .EN                     (EN_WB         & ~VGA_TEST_EN_IN  ),
       .RST_SYNC               (~EN_WB        |  VGA_TEST_EN_IN  ), 
       .RST_ASYNC              (RST_ASYNC_WB  |  VGA_TEST_EN_IN  ), 

       .WB_ADR_OUT             (WB_ADR_OUT      ),
       .WB_CYC_OUT             (WB_CYC_OUT      ),
       .WB_STB_OUT             (WB_STB_OUT      ),
       .WB_WE_OUT              (WB_WE_OUT       ),
       .WB_SEL_OUT             (WB_SEL_OUT      ),
       .WB_CTI_OUT             (WB_CTI_OUT      ), 
       .WB_BTE_OUT             (WB_BTE_OUT      ), 
       
       .WB_ACK_IN              (WB_ACK_IN       ),
       .WB_STALL_IN            (WB_STALL_IN     ),
       .WB_ERR_IN              (WB_ERR_IN       ),
      
       .WB_DAT_RD_IN           (WB_DAT_RD_IN    ),
       .WB_DAT_WR_OUT          (WB_DAT_WR_OUT   ),    

       .WB_PIXEL_DATA_EN_OUT   (WbPixelDataEn   ),
       .WB_PIXEL_DATA_OUT      (WbPixelData     ),
       .WB_PIXEL_DATA_FULL_IN  (WbPixelDataFull ),
       .WB_VS_STB_IN           (WbVsStb         ),
       .WB_HS_STB_IN           (WbHsStb         ),
       .WB_ACTIVE_LINE_IN      (WbActiveLine    ),
       
       .CFG_DITHER_IN          (CFG_DITHER_IN          ), // unused currently
       .CFG_LINEAR_FB_IN       (CFG_LINEAR_FB_IN       ),
       .CFG_PIXEL_FMT_IN       (CFG_PIXEL_FMT_IN       ), //            
       .CFG_BASE_ADDR_IN       (CFG_BASE_ADDR_IN       ), // [   31:20] 
       .CFG_TOP_LEFT_X_IN      (CFG_TOP_LEFT_X_IN      ), // [X_MSB: 0] 
       .CFG_TOP_LEFT_Y_IN      (CFG_TOP_LEFT_Y_IN      ), // [Y_MSB: 0] 
       .CFG_START_X_IN         (CFG_START_X_IN         ), // [X_MSB: 0] 
       .CFG_END_X_IN           (CFG_END_X_IN           ), // [X_MSB: 0] 
       .CFG_START_Y_IN         (CFG_START_Y_IN         ), // [Y_MSB: 0] 
       .CFG_END_Y_IN           (CFG_END_Y_IN           )  // [Y_MSB: 0] 
       );
   
   // No synchronous reset or enables for the CDC block
   VGA_CDC vga_cdc
      (
       .CLK_VGA            (CLK_VGA          ), // VGA Pixel clock
       .RST_ASYNC_VGA      (RST_ASYNC_VGA    ), // Reset de-asserted with PCLK
      
       .CLK_WB             (CLK_WB           ), // Framebuffer clock
       .RST_ASYNC_WB       (RST_ASYNC_WB     ), // Reset de-asserted with FB clock

       .VGA_DATA_OUT       (VgaPixelData     ),
       .VGA_DATA_REQ_IN    (VgaPixelDataEn   ),
       .VGA_ACTIVE_LINE_IN (VgaActiveLine    ), // Only start reading from frame buffer on active line
       .VGA_HS_IN          (VgaHsStb         ),
       .VGA_VS_IN          (VgaVsStb         ),

       .WB_DATA_EN_IN      (WbPixelDataEn    ),
       .WB_DATA_IN         (WbPixelData      ),
       .WB_DATA_FULL_OUT   (WbPixelDataFull  ),
       .WB_ACTIVE_LINE_OUT (WbActiveLine     ),
       .WB_VS_STB_OUT      (WbVsStb          ),
       .WB_HS_STB_OUT      (WbHsStb          ),

       .WB_RCNT_ACTIVE_ROW_OUT (WB_RCNT_ACTIVE_ROW_OUT),
       .WB_RCNT_ACTIVE_COL_OUT (WB_RCNT_ACTIVE_COL_OUT)
       
       );


   VGA_DRIVER 
      #(
	.R_HI (7), 
	.R_LO (5),
	.G_HI (4),
	.G_LO (2),
	.B_HI (1),
	.B_LO (0)
	)
   vga_driver
      (
       .CLK                    (CLK_VGA        ), // VGA Pixel clock
       .EN                     (EN_VGA         ), // VGA Pixel clock
       .RST_SYNC               (RST_SYNC_VGA   ), 
       .RST_ASYNC              (RST_ASYNC_VGA  ), // Reset de-asserted with PCLK

       .VGA_TEST_EN_IN         (VGA_TEST_EN_IN ),
      
       .VGA_DATA_IN            (VgaPixelData   ), // Incoming VGA Data
       .VGA_DATA_REQ_OUT       (VgaPixelDataEn ), // Data request from FIFO
       .VGA_ACTIVE_LINE_OUT    (VgaActiveLine  ), // Only start reading from frame buffer on active line
       
       .VGA_VS_OUT             (VgaVsStb       ), // VSYNC
       .VGA_HS_OUT             (VgaHsStb       ), // HSYNC

       .VGA_RED_OUT            (VGA_RED_OUT    ), 
       .VGA_GREEN_OUT          (VGA_GREEN_OUT  ), 
       .VGA_BLUE_OUT           (VGA_BLUE_OUT   )
      
       );







   
endmodule

