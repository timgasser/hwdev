// Block-level testbench for the VGA controller. 
module TB_TOP   ();

`include "tb_defines.v"

// Moved below to VGA defines   
// `define VGA_FIFO_RD_EMPTY  `TB.vga_top.vga_cdc.FifoReadEmpty
// `define VGA_FIFO_RD_EN     `TB.vga_top.vga_cdc.VGA_DATA_REQ_IN
   
   parameter CLK_VGA_HALF_PERIOD = 20;  // 25MHz clock
   parameter CLK_WB_HALF_PERIOD  = 6;  // ?? - 100MHz clock

   parameter X_MSB = 9;  // up to 1024 (in 16 bit addresses)
   parameter Y_MSB = 8;  // up to  512 (in 16 bit addresses)

   // RGB Data Packing
   parameter R_HI = 7; 
   parameter R_LO = 5;
   parameter G_HI = 4;
   parameter G_LO = 2;
   parameter B_HI = 1;
   parameter B_LO = 0;

   reg            ClkVga       ;
   reg            RstVga       ;
   reg            ClkWb        ;
   reg            RstWb        ;

   reg 		  EnVga;

   // Wishbone-side interface (Master)
   wire          WbCyc 		  ;
   wire          WbStb 		  ;    
   wire   [31:0] WbAdr 		  ;
   wire   [ 3:0] WbSel 	 	  ;
   wire          WbWe  	 	  ;
   wire          WbStall          ;
   wire          WbAck      	  ;  
   wire   [31:0] WbDatWr  	  ;
   wire   [31:0] WbDatRd          ;    

   // VGA signals
   wire        VgaVs      ;
   wire        VgaHs      ;

   wire  [2:0] VgaRed     ; 
   wire  [2:0] VgaGreen   ; 
   wire  [1:0] VgaBlue    ; 
   
   wire [7:0] VgaRed8b     ; 
   wire [7:0] VgaGreen8b   ; 
   wire [7:0] VgaBlue8b    ; 

   wire       VgaTestEn = 1'b0; // VGA_TEST_EN_IN

   // Configuration for the VGA driver

   reg              CfgDither       ;
   reg 		    CfgLinearFb     ;
   reg   [1:0]      CfgPixelFmt     ; // 00 = PSX_16B, 01 = PSX_24B, 10 = RGB_8B, 11 = RGB_24B
   reg   [   31:20] CfgBaseAddr     ;
   reg   [X_MSB: 0] CfgTopLeftX     ;
   reg   [Y_MSB: 0] CfgTopLeftY     ;
   reg   [X_MSB: 0] CfgStartX       ;
   reg   [X_MSB: 0] CfgEndX         ;
   reg   [Y_MSB: 0] CfgStartY       ;
   reg   [Y_MSB: 0] CfgEndY         ;

   
   // VGA LUT to get 8-bit volour values from 3 or 2 bit inputs..
   assign VgaRed8b   = VgaRed   * 36;
   assign VgaGreen8b = VgaGreen * 36;
   assign VgaBlue8b  = VgaBlue  * 85;
   

   // **************************** Reset and Clock Gen *************************
   //

   // Set up a baseline configuration. X and Y co-ordinates are 16-bit values
   initial
      begin
	 CfgDither       = 1'b0            ;
	 CfgLinearFb     = 1'b1            ; // Scan the FB linearly, don't jump to new Y
	 CfgPixelFmt     = 2'b11           ; // Select 24 bit 8R, 8G, 8B pixel colour
	 CfgBaseAddr     = 12'd0           ;
	 CfgTopLeftX     = {X_MSB+1{1'b0}} ;
	 CfgTopLeftY     = {Y_MSB+1{1'b0}} ;
	 CfgStartX       = {X_MSB+1{1'b0}} ;
	 CfgEndX         = 960             ; // units of 16 bit
	 CfgStartY       = {Y_MSB+1{1'b0}} ;
	 CfgEndY         = 480             ; // default to VGA dimensions
      end
   
   
   // VGA reset and clock speed
   initial
     begin
        ClkVga = 1'b0;
        RstVga = 1'b1;
        @(posedge ClkVga);
        @(posedge ClkVga);
        @(posedge ClkVga);
        @(posedge ClkVga);
	RstVga = 1'b0;
     end

   always #CLK_VGA_HALF_PERIOD ClkVga = !ClkVga;
   
   // WB reset and clock speed
   initial
     begin
        ClkWb = 1'b0;
        RstWb = 1'b1;
        @(posedge ClkWb);
        @(posedge ClkWb);
        @(posedge ClkWb);
        @(posedge ClkWb);
	RstWb = 1'b0;
     end

   always #CLK_WB_HALF_PERIOD ClkWb = !ClkWb;
   
   // *************************************************************************

   // Monitor the VGA fifo for underruns ..
   always @(posedge ClkVga)
   begin : VGA_FIFO_MONITOR
      if (`VGA_FIFO_RD_EMPTY && `VGA_FIFO_RD_EN && !VgaTestEn)
      begin
	 $display("[ERROR] VGA Fifo underrun at time %t !", $time);
	 $finish();
      end
   end
   
   
   TESTCASE testcase();

 WB_SLAVE_BFM
  #(.VERBOSE     (0),
    .READ_ONLY   (0),
    .MEM_BASE    (32'h0000_0000 ),
    .MEM_SIZE_P2 (20), // VGA driver can address 1MB frame buffer
    .MAX_LATENCY (1),
    .ADDR_LIMIT  (1)
    )
   wb_slave_bfm  
   (
    .CLK            (ClkWb  ),
    .RST_SYNC       (RstWb  ),
    
    .WB_ADR_IN      (WbAdr          ),
    .WB_CYC_IN      (WbCyc          ),
    .WB_STB_IN      (WbStb          ),
    .WB_SEL_IN      (WbSel          ),
    .WB_WE_IN       (WbWe           ),
    .WB_CTI_IN      ( ),
    .WB_BTE_IN      ( ),
    
    .WB_STALL_OUT   (WbStall        ),
    .WB_ACK_OUT     (WbAck          ),
    .WB_ERR_OUT     ( ),
    
    .WB_DAT_RD_OUT  (WbDatRd        ), 
    .WB_DAT_WR_IN   (WbDatWr        )  
    
    );

  

   VGA_TOP 
      #(.X_MSB  (X_MSB ),
	.Y_MSB  (Y_MSB ),
	.R_HI   (R_HI  ),
	.R_LO   (R_LO  ),
	.G_HI   (G_HI  ),
	.G_LO   (G_LO  ),
	.B_HI   (B_HI  ),
	.B_LO   (B_LO  )
	)
   vga_top
      (
       .CLK_VGA        	       (ClkVga    	), 
       .EN_VGA         	       (~RstVga   	), 
       .RST_SYNC_VGA   	       (RstVga    	), 
       .RST_ASYNC_VGA  	       (RstVga    	), 
      
       .CLK_WB         	       (ClkWb     	), 
       .EN_WB          	       (~RstWb    	), 
       .RST_SYNC_WB    	       (RstWb     	), 
       .RST_ASYNC_WB   	       (RstWb     	), 
      
       .VGA_TEST_EN_IN         (VgaTestEn 	),

       .WB_ADR_OUT     	       (WbAdr     	),
       .WB_CYC_OUT     	       (WbCyc     	),
       .WB_STB_OUT     	       (WbStb     	),
       .WB_WE_OUT      	       (WbWe      	),
       .WB_SEL_OUT     	       (WbSel     	),
       .WB_CTI_OUT             ( ),
       .WB_BTE_OUT             ( ),
       
       .WB_STALL_IN    	       (WbStall   	),
       .WB_ACK_IN      	       (WbAck     	),
       .WB_ERR_IN      	       (1'b0      	),

       .WB_DAT_RD_IN 	       (WbDatRd   	),
       .WB_DAT_WR_OUT	       (WbDatWr   	),

       .VGA_VS_OUT             (VgaVs     	),
       .VGA_HS_OUT             (VgaHs     	),
      
       .VGA_RED_OUT            (VgaRed    	), 
       .VGA_GREEN_OUT          (VgaGreen  	), 
       .VGA_BLUE_OUT           (VgaBlue   	),

       .WB_RCNT_ACTIVE_ROW_OUT (), // Outputs for the root counters not verified here..
       .WB_RCNT_ACTIVE_COL_OUT (),
       
       .CFG_DITHER_IN          (CfgDither       ),
       .CFG_LINEAR_FB_IN       (CfgLinearFb     ),
       .CFG_PIXEL_FMT_IN       (CfgPixelFmt     ),
       .CFG_BASE_ADDR_IN       (CfgBaseAddr     ),
       .CFG_TOP_LEFT_X_IN      (CfgTopLeftX     ),
       .CFG_TOP_LEFT_Y_IN      (CfgTopLeftY     ),
       .CFG_START_X_IN         (CfgStartX       ),
       .CFG_END_X_IN           (CfgEndX         ),
       .CFG_START_Y_IN         (CfgStartY       ),
       .CFG_END_Y_IN           (CfgEndY         )
   );


    VGA_SLAVE_MONITOR
    #(
      .STORE_IMAGES        (  1),
      
      .PCLK_PERIOD_NS      ( 40),
      
      .HORIZ_SYNC          ( 96),
      .HORIZ_BACK_PORCH    ( 48),
      .HORIZ_ACTIVE_WIDTH  (640),
      .HORIZ_FRONT_PORCH   ( 16),
     
      .VERT_SYNC           (  2),
      .VERT_BACK_PORCH     ( 33),
      .VERT_ACTIVE_HEIGHT  (480),
      .VERT_FRONT_PORCH    ( 10),
     
      .R_HI (23),
      .R_LO (16),
      .G_HI (15),
      .G_LO ( 8),
      .B_HI ( 7),
      .B_LO ( 0),
     
      .COLOUR_DEPTH        (  8)
       )
    vga_slave_monitor
    (
     .PCLK     (ClkVga  ),
     .VSYNC_IN (VgaVs   ),
     .HSYNC_IN (VgaHs   ),   
     .RED_IN   (VgaRed8b   ),
     .GREEN_IN (VgaGreen8b ),
     .BLUE_IN  (VgaBlue8b  )

     
     );



   
   
endmodule // TB_VGA_TOP
