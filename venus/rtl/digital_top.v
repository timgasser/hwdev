// VENUS platform digital_top

// Contains:
// --------
//  - ADI (Epp slave / WB Master) block to connect to host PC 
//  - VGA_CONTROLLER (VGA Master / WB Master) to connect to external monitor
//  - ARB : 2-Master 1-Slave Arbiter. fixed priority arbitration (0 highest priority)
//     M0 = VGA_CONTROLLER
//     M1 = ADI
//     S0 = SDRAM_CONTROLLER
//  - SDRAM_CONTROLLER (WB Slave / SDRAM Master) to access the platform RAM.


// This is a template digital_top. all outputs are tied to 0, and inputs
// disregarded. Connect the host interfaces / LEDs from here as necessary
module DIGITAL_TOP
   (

    input     	      CLK_33M         	 ,
    input             CLK_25M         	 ,
    input             CLK_SDR_33M     	 ,
    input     	      RST_ASYNC_33M   	 ,
    input     	      RST_ASYNC_25M   	 ,  
    input     	      RST_ASYNC_SDR_33M  ,
    input      	      DCMS_LOCKED_IN     ,
    
    // Push-buttons
    input      [ 3:0] BTN_IN                , // 

    // EPP interface to USB chip
    input             EPP_ASTB_IN           , // 
    input             EPP_DSTB_IN           , // 
    output            EPP_WAIT_OUT          , //

    // Flash signals
    output            FLASH_CS_OUT          , // 
    output            FLASH_RP_OUT          , // 
    input             FLASH_ST_STS_IN       , //

    // LEDs
    output     [ 7:0] LED_OUT               , // 

    // Memory address [23:1]
    output     [23:1] MEM_ADDR_OUT          , // Bit 0 isn't connected

    // Memory Data [15:0]
    inout      [15:0] MEM_DATA_INOUT        , // 

    // Memory Control
    output            MEM_OE_OUT            , // 
    output            MEM_WR_OUT            , //

    // PS2 Interface
    inout 	      PS2_CLK_INOUT         , // 
    inout 	      PS2_DATA_INOUT        , //

    // RAM control
    output 	      RAM_ADV_OUT           , // 
    output 	      RAM_CLK_EN_OUT        , //            
    output 	      RAM_CRE_OUT           , // 
    output 	      RAM_CS_OUT            , // 
    output 	      RAM_LB_OUT            , // 
    output 	      RAM_UB_OUT            , // 
    input 	      RAM_WAIT_IN           , //

    // RS232 port 
    input 	      RS232_RX_IN           , // 
    inout 	      RS232_TX_INOUT        , //

    // 7-Segment displays
    output      [3:0] SSEG_AN_OUT           , // 
    output      [7:0] SSEG_K_OUT            , // 

    // Slider switches
    input       [7:0] SW_IN                 , // 

    // USB control
    output      [1:0] USB_ADDR_OUT          , // 
    input             USB_CLK_IN            , // 
    inout       [7:0] USB_DATA_INOUT        , // 
    input      	      USB_DIR_IN            , // 
    input      	      USB_FLAG_IN           , // This is cryptically named, it's actually the EPP Write strobe (active low).
    input      	      USB_MODE_IN           , // 
    output     	      USB_OE_OUT            , // 
    output     	      USB_PKTEND_OUT        , // 
    output     	      USB_WR_OUT            , //

    // VGA Interface
    output     	[1:0] VGA_BLUE_OUT          , // 
    output     	[2:0] VGA_GREEN_OUT         , // 
    output     	      VGA_HSYNC_OUT         , // 
    output     	[2:0] VGA_RED_OUT           , // 
    output     	      VGA_VSYNC_OUT           // 

    );
   // Parameters
   parameter X_MSB = 9;
   parameter Y_MSB = 8;

   parameter [1:0] PSX_16B = 2'b00;
   parameter [1:0] PSX_24B = 2'b01; 
   parameter [1:0] RGB_8B  = 2'b10; 
   parameter [1:0] RGB_24B = 2'b11;

   parameter [X_MSB:0] VGA_WIDTH_16B_COL = 640;
   parameter [X_MSB:0] VGA_WIDTH_24B_COL = VGA_WIDTH_16B_COL * (3/2);
   
   // ADI Wishbone Master Interface
   wire 	      AdiWbArbReq  ; 
   wire 	      AdiWbArbGnt  ;
   
   wire [31:0] 	      AdiWbAdr     ;
   wire 	      AdiWbCyc     ;
   wire 	      AdiWbStb     ;
   wire 	      AdiWbWe      ;
   wire [ 3:0] 	      AdiWbSel     ;

   wire 	      AdiWbStall   ;
   wire 	      AdiWbAck     ;
   wire 	      AdiWbErr     ;

   wire [31:0] 	      AdiWbRdDat   ;
   wire [31:0] 	      AdiWbWrDat   ;

   // VGA Wishbone Master Interface
   wire 	      VgaWbArbReq  ; 
   wire 	      VgaWbArbGnt  ;
   
   wire [31:0] 	      VgaWbAdr     ;
   wire 	      VgaWbCyc     ;
   wire 	      VgaWbStb     ;
   wire 	      VgaWbWe      ;
   wire [ 3:0] 	      VgaWbSel     ;

   wire 	      VgaWbStall   ;
   wire 	      VgaWbAck     ;
   wire 	      VgaWbErr     ;

   wire [31:0] 	      VgaWbRdDat   ;
   wire [31:0] 	      VgaWbWrDat   ;

   // SDRAM Wishbone Slave Interface
   wire [31:0] 	      SdramWbAdr     ;
   wire 	      SdramWbCyc     ;
   wire 	      SdramWbStb     ;
   wire 	      SdramWbWe      ;
   wire [ 3:0] 	      SdramWbSel     ;

   wire 	      SdramWbStall   ;
   wire 	      SdramWbAck     ;
   wire 	      SdramWbErr     ;

   wire [31:0] 	      SdramWbRdDat   ;
   wire [31:0] 	      SdramWbWrDat   ;

   reg [2:0] 	      Sw0Resync33M;
   reg [2:0] 	      Sw0Resync25M;
   reg [2:0] 	      Sw1Resync25M;

   // Tie off unused board level pins
   assign LED_OUT = {AdiWbArbReq       , // 7
		     AdiWbArbGnt       , // 6
		     AdiWbCyc          , // 5
		     AdiWbAck          , // 4
		     VgaWbArbReq       , // 3
		     VgaWbArbGnt       , // 2
		     SdramWbCyc        , // 1
		     DCMS_LOCKED_IN      // 0
		     };
   
   // Switch 0 is used to enable the VGA Driver and DMA. It is resynced to 33MHz for the WB-side, and 25 for VGA.
   // Switch 1 is used to enable the VGA Driver testmode (displaying a fixed pattern). This is 25MHz only.
   
   // Switch 0 resynced to 33MHz for WB clk side of VGA top
   always @(posedge CLK_33M or posedge RST_ASYNC_33M)
   begin : SW_0_33M_RESYNC
      if (RST_ASYNC_33M)
      begin
	 Sw0Resync33M <= 3'b000;
      end
      else
      begin
	 Sw0Resync33M <= {SW_IN[0], Sw0Resync33M[2:1]};
      end
   end

   // Switch 0 resynced to 25MHz for VGA-side of VGA top
   always @(posedge CLK_25M or posedge RST_ASYNC_25M)
   begin : SW_0_25M_RESYNC
      if (RST_ASYNC_25M)
      begin
	 Sw0Resync25M <= 3'b000;
      end
      else
      begin
	 Sw0Resync25M <= {SW_IN[0], Sw0Resync25M[2:1]};
      end
   end

   // Switch 1 resynced to 25MHz for VGA testmode enable
   always @(posedge CLK_25M or posedge RST_ASYNC_25M)
   begin : SW_1_25M_RESYNC
      if (RST_ASYNC_25M)
      begin
	 Sw1Resync25M <= 3'b000;
      end
      else
      begin
	 Sw1Resync25M <= {SW_IN[1], Sw1Resync25M[2:1]};
      end
   end
   


   ADI_TOP adi_top
      (
       .CLK          	(CLK_33M            ),
       .EN              (1'b1   ),
       .RST_SYNC   	(1'b0   ), 
       .RST_ASYNC   	(RST_ASYNC_33M      ), 

       .EPP_DATA_INOUT 	(USB_DATA_INOUT ),
       .EPP_WRITE_IN   	(USB_FLAG_IN    ),
       .EPP_ASTB_IN    	(EPP_ASTB_IN    ),
       .EPP_DSTB_IN    	(EPP_DSTB_IN    ),
       .EPP_WAIT_OUT   	(EPP_WAIT_OUT   ),

       .EPP_INT_OUT    	(      ), // Not used
       .EPP_RESET_IN   	(1'b0  ),

       .WB_ARB_REQ_OUT 	(AdiWbArbReq    ),
       .WB_ARB_GNT_IN  	(AdiWbArbGnt    ),
      
       .WB_ADR_OUT     	(AdiWbAdr       ),
       .WB_CYC_OUT     	(AdiWbCyc       ),
       .WB_STB_OUT     	(AdiWbStb       ),
       .WB_WE_OUT      	(AdiWbWe        ),
       .WB_SEL_OUT     	(AdiWbSel       ),
      
       .WB_STALL_IN    	(AdiWbStall     ),
       .WB_ACK_IN      	(AdiWbAck       ),
       .WB_ERR_IN      	(AdiWbErr       ),
      
       .WB_RD_DAT_IN   	(AdiWbRdDat     ),
       .WB_WR_DAT_OUT  	(AdiWbWrDat     )
       );
   

   VGA_TOP 
      #(.X_MSB 		(X_MSB), // Y is [1023:0]
	.Y_MSB 		(Y_MSB)  // X is [511:0]
	)
   vga_top
      (
       .CLK_VGA        	(CLK_25M           ),
       .EN_VGA          (Sw0Resync25M[0]   ),
       .RST_SYNC_VGA  	(~Sw0Resync25M[0]  ), 
       .RST_ASYNC_VGA  	(RST_ASYNC_25M     ), 

       .CLK_WB         	(CLK_33M           ),
       .EN_WB           (Sw0Resync33M[0]   ),
       .RST_SYNC_WB     (~Sw0Resync33M[0]  ),     
       .RST_ASYNC_WB   	(RST_ASYNC_33M     ), 

       .WB_ARB_REQ_OUT 	(VgaWbArbReq    ),
       .WB_ARB_GNT_IN  	(VgaWbArbGnt    ),

       .VGA_TEST_EN_IN  (Sw1Resync25M[0]),
      
       .WB_ADR_OUT     	(VgaWbAdr       ),
       .WB_CYC_OUT     	(VgaWbCyc       ),
       .WB_STB_OUT     	(VgaWbStb       ),
       .WB_WE_OUT      	(VgaWbWe        ),
       .WB_SEL_OUT     	(VgaWbSel       ),
      
       .WB_STALL_IN    	(VgaWbStall     ),
       .WB_ACK_IN      	(VgaWbAck       ),
       .WB_ERR_IN      	(VgaWbErr       ),
      
       .WB_RD_DAT_IN   	(VgaWbRdDat     ),
       .WB_WR_DAT_OUT  	(VgaWbWrDat     ),

       .VGA_VS_OUT      (VGA_VSYNC_OUT  ),
       .VGA_HS_OUT      (VGA_HSYNC_OUT  ),

       .VGA_RED_OUT     (VGA_RED_OUT    ), 
       .VGA_GREEN_OUT   (VGA_GREEN_OUT  ), 
       .VGA_BLUE_OUT    (VGA_BLUE_OUT   ),

       .CFG_DITHER_IN       (1'b0      	       ), //             
       .CFG_LINEAR_FB_IN    (1'b1      	       ), //             
       .CFG_PIXEL_FMT_IN    (RGB_24B   	       ), //  [    1: 0] 
       .CFG_BASE_ADDR_IN    (12'd0     	       ), //  [   31:20] 
       .CFG_TOP_LEFT_X_IN   ({X_MSB+1{1'b0}}   ), //  [X_MSB: 0] 
       .CFG_TOP_LEFT_Y_IN   ({Y_MSB+1{1'b0}}   ), //  [Y_MSB: 0] 
       .CFG_START_X_IN      ({X_MSB+1{1'b0}}   ), //  [X_MSB: 0] 
       .CFG_END_X_IN        (VGA_WIDTH_24B_COL ), //  [X_MSB: 0] 
       .CFG_START_Y_IN      ({Y_MSB+1{1'b0}}   ), //  [Y_MSB: 0]  
       .CFG_END_Y_IN        (9'd480            )  //  [Y_MSB: 0] 
       
       );



   // Arbiter (2 Master - 1 Slave)
   // M0 = VGA
   // M1 = EPP
   // S0 = SDRAM (only slave)
   //    
   WB_ARB_2M_1S wb_arb_2m_1s
      (
       .CLK         	  (CLK_33M         ),
       .EN             	  (1'b1            ),
       .RST_SYNC       	  (1'b0            ), 
       .RST_ASYNC      	  (RST_ASYNC_33M   ), 

       .WB_ARB_REQ_IN  	  ({AdiWbArbReq, VgaWbArbReq} ),
       .WB_ARB_GNT_OUT 	  ({AdiWbArbGnt, VgaWbArbGnt} ),

       .WB_SL0_ADR_IN     (VgaWbAdr      ),
       .WB_SL0_CYC_IN     (VgaWbCyc      ),
       .WB_SL0_STB_IN     (VgaWbStb      ),
       .WB_SL0_WE_IN      (VgaWbWe       ),
       .WB_SL0_SEL_IN     (VgaWbSel      ),
      
       .WB_SL0_STALL_OUT  (VgaWbStall    ),
       .WB_SL0_ACK_OUT    (VgaWbAck      ),
       .WB_SL0_ERR_OUT    (VgaWbErr      ),
      
       .WB_SL0_RD_DAT_OUT (VgaWbRdDat    ),
       .WB_SL0_WR_DAT_IN  (VgaWbWrDat    ),

       .WB_SL1_ADR_IN     (AdiWbAdr      ),
       .WB_SL1_CYC_IN     (AdiWbCyc      ),
       .WB_SL1_STB_IN     (AdiWbStb      ),
       .WB_SL1_WE_IN      (AdiWbWe       ),
       .WB_SL1_SEL_IN     (AdiWbSel      ),
      
       .WB_SL1_STALL_OUT  (AdiWbStall    ),
       .WB_SL1_ACK_OUT    (AdiWbAck      ),
       .WB_SL1_ERR_OUT    (AdiWbErr      ),
      
       .WB_SL1_RD_DAT_OUT (AdiWbRdDat    ),
       .WB_SL1_WR_DAT_IN  (AdiWbWrDat    ),

       .WB_M0_ADR_OUT     (SdramWbAdr    ),
       .WB_M0_CYC_OUT     (SdramWbCyc    ),
       .WB_M0_STB_OUT     (SdramWbStb    ),
       .WB_M0_WE_OUT      (SdramWbWe     ),
       .WB_M0_SEL_OUT     (SdramWbSel    ),
      
       .WB_M0_STALL_IN    (SdramWbStall  ),
       .WB_M0_ACK_IN      (SdramWbAck    ),
       .WB_M0_ERR_IN      (SdramWbErr    ),
      
       .WB_M0_RD_DAT_IN   (SdramWbRdDat  ),
       .WB_M0_WR_DAT_OUT  (SdramWbWrDat  )
       );

// // Replace the SDRAM Controller with a blockram instead
// 
// WB_SPRAM_WRAP
//    #(
//      .WBA   (32'h0000_0000), // Wishbone Base Address
//      .WS_P2 (13           ), // Wishbone size as power-of-2 bytes
//      .DW    (32           )  // Data Width
//      )
//   wb_spram_wrap 
//    (
//     .CLK            (CLK_33M        ),
//     .EN             (1'b1           ),
//     .RST_SYNC       (1'b0           ),
//     .RST_ASYNC      (RST_ASYNC_33M  ),
//     
//     .WB_ADR_IN      (SdramWbAdr    ),
//     .WB_CYC_IN      (SdramWbCyc    ),
//     .WB_STB_IN      (SdramWbStb    ),
//     .WB_WE_IN       (SdramWbWe     ),
//     .WB_SEL_IN      (SdramWbSel    ),
//     .WB_CTI_IN      (3'b000        ),
//     .WB_BTE_IN      (2'b00         ),
// 
//     .WB_ACK_OUT     (SdramWbAck    ),
//     .WB_STALL_OUT   (SdramWbStall  ),
//     .WB_ERR_OUT     (SdramWbErr    ),
// 		                   
//     .WB_WR_DAT_IN   (SdramWbWrDat  ),
//     .WB_RD_DAT_OUT  (SdramWbRdDat  )
//     );
// 
   
  
   SDRAM_CONTROLLER 
      #(
	.WBA   (32'h0000_0000), // Wishbone Base Address
	.WS_P2 (24)             // Wishbone size as power-of-2 bytes
	)
   sdram_controller
      (
       .CLK               (CLK_33M        ),
       .EN                (1'b1           ),
       .RST_SYNC          (1'b0           ),
       .RST_ASYNC         (RST_ASYNC_33M  ),
       .CLK_SDR_EN_OUT    (RAM_CLK_EN_OUT ), // Send clock enable to fpga_bus_top clock generation logic
      
       .WB_ADR_IN         (SdramWbAdr     ), // Word aligned addresses only
       .WB_CYC_IN         (SdramWbCyc     ),
       .WB_STB_IN         (SdramWbStb     ),
       .WB_WE_IN          (SdramWbWe      ),
       .WB_SEL_IN         (SdramWbSel     ),
       .WB_CTI_IN         (3'b000         ), // not used in the block
       .WB_BTE_IN         (2'b00          ),

       .WB_ACK_OUT        (SdramWbAck     ),
       .WB_STALL_OUT      (SdramWbStall   ),
       .WB_ERR_OUT        (SdramWbErr     ),

       .WB_WR_DAT_IN      (SdramWbWrDat   ),
       .WB_RD_DAT_OUT     (SdramWbRdDat   ),

       .SDR_ADDR_OUT      (MEM_ADDR_OUT   ),
       .SDR_CRE_OUT       (RAM_CRE_OUT    ),
       .SDR_ADVB_OUT      (RAM_ADV_OUT    ),
       .SDR_CEB_OUT       (RAM_CS_OUT     ),
       .SDR_OEB_OUT       (MEM_OE_OUT     ),
       .SDR_WEB_OUT       (MEM_WR_OUT     ),
       .SDR_WAIT_IN       (RAM_WAIT_IN    ),

       .SDR_LBB_OUT       (RAM_LB_OUT     ),
       .SDR_UBB_OUT       (RAM_UB_OUT     ),
      
       .SDR_DATA_INOUT    (MEM_DATA_INOUT )
      
       );

endmodule

















