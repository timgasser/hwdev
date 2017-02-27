
/* INSERT MODULE HEADER */

module FPGA_BUS_TOP
(

    // Push-buttons
    input      [ 3:0] BTN_IN                , // 

    // 50MHz master clock input
    input             CLK_IN                , //

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
    output     [23:0] MEM_ADDR_OUT          , // Bit 0 isn't connected

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
    output 	      RAM_CLK_OUT           , // 
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
    input      	      USB_FLAG_IN           , // 
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

   wire 	      ShiftRegDcmReset;
   wire 	      ShiftRegCoreReset;

   wire 	      IbufgPreDcmClk; // 50MHz oscillator input after going through an IBUFG
   
   wire 	      DcmLocked; // DCM output - DLL Locked?
   wire [7:0] 	      DcmStatus; // DCM output - Status
//   wire 	      DcmReset;
//   wire 	      DcmClk100M;
   wire 	      DcmClk50M; // DCM output - 50MHz clock
   wire 	      DcmClk25M; // DCM output - 25MHz clock
   
   wire 	      BufgClk50M; // BUFG output - 50MHz clock
   wire 	      BufgClk25M; // BUFG output - 25MHz clock
   
   
 //  wire 	      Clk;
 //  reg  [ 7:0] 	      RstSyncPipe;
 //  reg 	[39:0]	      HeartBeatCnt;
//
//   // Button 0 is the synchronous reset
//   always @(posedge CLK_IN or posedge BTN_IN[0])
//   begin : button_0_sync_release
//      if (BTN_IN[0])
//      begin
//	 RstSyncPipe <= 8'hFF;
//      end
//     else
//      begin
//	 RstSyncPipe[7]   <= 1'b0;
//	 RstSyncPipe[6:0] <= RstSyncPipe[7:1];
//      end
//   end

   IBUFG ibufg_pre_dcm
      (.I (CLK_IN         ),
       .O (IbufgPreDcmClk )
       );

   // Generate 16 (pre-DCM) clock cycles of reset for the DCM
   SRL16 
      #(
	.INIT(16'hFFFF) // Initial Value of Shift Register
	) 
   srl16_dcm_reset 
      (
       .Q    (ShiftRegDcmReset ), // SRL data output
       .A0   (1'b1   ), // Select[0] input <- Program length of 16 for reset pulse (on CLK_IN)
       .A1   (1'b1   ), // Select[1] input
       .A2   (1'b1   ), // Select[2] input
       .A3   (1'b1   ), // Select[3] input
       .CLK  (IbufgPreDcmClk ), // Clock input     <- Direct from XO
       .D    (1'b0   )  // SRL data input
       );
   // End of SRL16_inst instantiation
   
   // DCM_SP: Digital Clock Manager Circuit
   // Spartan-3E
   // Xilinx HDL Libraries Guide, version 12.2
   DCM_SP 
      #(.CLKDV_DIVIDE       	(2.0), // Divide by: 1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5 7.0,7.5,8.0,9.0,10.0,11.0,12.0,13.0,14.0,15.0 or 16.0
	.CLKFX_DIVIDE       	(1), // Can be any integer from 1 to 32
	.CLKFX_MULTIPLY     	(2), // Can be any integer from 2 to 32
	.CLKIN_DIVIDE_BY_2  	("FALSE"), // TRUE/FALSE to enable CLKIN divide by two feature
	.CLKIN_PERIOD       	(20.0), // Specify period of input clock
	.CLKOUT_PHASE_SHIFT 	("VARIABLE"), // Specify phase shift of NONE, FIXED or VARIABLE
	.CLK_FEEDBACK       	("1X"), // Specify clock feedback of NONE, 1X or 2X
	.DESKEW_ADJUST      	("SYSTEM_SYNCHRONOUS"), // SOURCE_SYNCHRONOUS, SYSTEM_SYNCHRONOUS or an integer from 0 to 15
	.DLL_FREQUENCY_MODE     ("LOW"), // HIGH or LOW frequency mode for DLL
	.DUTY_CYCLE_CORRECTION  ("TRUE"), // Duty cycle correction, TRUE or FALSE
	.PHASE_SHIFT      	(0), // Amount of fixed phase shift from -255 to 255
	.STARTUP_WAIT      	("FALSE") // Delay configuration DONE until DCM LOCK, TRUE/FALSE
	) 
   dcm_sp_main
      (
       .CLK0      	(DcmClk50M    ), // 0 degree DCM CLK output
       .CLK180      	(	      ), // 180 degree DCM CLK output
       .CLK270      	(	      ), // 270 degree DCM CLK output
       .CLK2X      	(             ), // 2X DCM CLK output
       .CLK2X180      	(	      ), // 2X, 180 degree DCM CLK out
       .CLK90      	(	      ), // 90 degree DCM CLK output
       .CLKDV      	(DcmClk25M    ), // Divided DCM CLK out (CLKDV_DIVIDE)
       .CLKFX      	(	      ), // DCM CLK synthesis out (M/D)
       .CLKFX180      	(	      ), // 180 degree CLK synthesis out
       .LOCKED      	(DcmLocked    ), // DCM LOCK status output
       .PSDONE      	(	      ), // Dynamic phase adjust done output
       .STATUS      	(DcmStatus    ), // 8-bit DCM status bits output
       .CLKFB      	(BufgClk50M   ), // DCM clock feedback
       .CLKIN      	(IbufgPreDcmClk   ), // Clock input (from IBUFG, BUFG or DCM)
       .PSCLK      	(	      ), // Dynamic phase adjust clock input
       .PSEN      	(	      ), // Dynamic phase adjust enable input
       .PSINCDEC      	(	      ), // Dynamic phase adjust increment/decrement
       .RST      	(ShiftRegDcmReset  ),  // DCM asynchronous reset input
       .DSSEN           () // Not sure what this port is meant to be .. 
 );
   // End of DCM_SP_inst instantiation

   BUFG bufg_post_dcm_50m
      (.I (DcmClk50M  ),
       .O (BufgClk50M )
       );

   BUFG bufg_post_dcm_25m
      (.I (DcmClk25M  ),
       .O (BufgClk25M )
       );



   // Generate 16 (post-DCM) clock cycles of reset for the core logic
   SRL16 
      #(
	.INIT(16'hFFFF) // Initial Value of Shift Register
	) 
   srl16_core_reset 
      (
       .Q    (ShiftRegCoreReset ), // SRL data output
       .A0   (1'b1   ), // Select[0] input 
       .A1   (1'b1   ), // Select[1] input
       .A2   (1'b1   ), // Select[2] input
       .A3   (1'b1   ), // Select[3] input
       .CLK  (DcmClk25M  ), // Clock input     <- From DCM output. Use slowest DCM clock output
       .D    (~DcmLocked )  // SRL data input  <- De-assert reset 16 cycles after DCM locks
       );
   // End of SRL16_inst instantiation
   


   
// Need to add the clock and reset generation for digital_top.
// Route LEDs and switches into digital_top (depends on platform)
// Tie off unused ports from digital top and synthesis will remove them.

   DIGITAL_TOP digital_top
   (
    .CLK      		   (BufgClk25M          ),
    .RST_SYNC 		   (ShiftRegCoreReset   ),
    
    .BTN_IN                (BTN_IN              ), //   [ 3:0] 
//    .CLK                   (CLK_IN              ), // <- Put input clock through DCM         
    .EPP_ASTB_IN           (EPP_ASTB_IN         ), //          
    .EPP_DSTB_IN           (EPP_DSTB_IN         ), //          
    .EPP_WAIT_OUT          (EPP_WAIT_OUT        ), //          
    .FLASH_CS_OUT          (FLASH_CS_OUT        ), //          
    .FLASH_RP_OUT          (FLASH_RP_OUT        ), //          
    .FLASH_ST_STS_IN       (FLASH_ST_STS_IN     ), //          
    .LED_OUT               (LED_OUT             ), //   [ 7:0] 
    .MEM_ADDR_OUT          (MEM_ADDR_OUT        ), //   [23:0] <- Bit 0 isn't connected
    .MEM_DATA_INOUT        (MEM_DATA_INOUT      ), //   [15:0] 
    .MEM_OE_OUT            (MEM_OE_OUT          ), //          
    .MEM_WR_OUT            (MEM_WR_OUT          ), //          
    .PS2_CLK_INOUT         (PS2_CLK_INOUT       ), //          
    .PS2_DATA_INOUT        (PS2_DATA_INOUT      ), //          
    .RAM_ADV_OUT           (RAM_ADV_OUT         ), //          
    .RAM_CLK_OUT           (RAM_CLK_OUT         ), //          
    .RAM_CRE_OUT           (RAM_CRE_OUT         ), //          
    .RAM_CS_OUT            (RAM_CS_OUT          ), //          
    .RAM_LB_OUT            (RAM_LB_OUT          ), //          
    .RAM_UB_OUT            (RAM_UB_OUT          ), //          
    .RAM_WAIT_IN           (RAM_WAIT_IN         ), //          
    .RS232_RX_IN           (RS232_RX_IN         ), //          
    .RS232_TX_INOUT        (RS232_TX_INOUT      ), //          
    .SSEG_AN_OUT           (SSEG_AN_OUT         ), //    [3:0] 
    .SSEG_K_OUT            (SSEG_K_OUT          ), //    [7:0] 
    .SW_IN                 (SW_IN               ), //    [7:0] 
    .USB_ADDR_OUT          (USB_ADDR_OUT        ), //    [1:0] 
    .USB_CLK_IN            (USB_CLK_IN          ), //          
    .USB_DATA_INOUT        (USB_DATA_INOUT      ), //    [7:0] 
    .USB_DIR_IN            (USB_DIR_IN          ), //          
    .USB_FLAG_IN           (USB_FLAG_IN         ), //          
    .USB_MODE_IN           (USB_MODE_IN         ), //          
    .USB_OE_OUT            (USB_OE_OUT          ), //          
    .USB_PKTEND_OUT        (USB_PKTEND_OUT      ), //          
    .USB_WR_OUT            (USB_WR_OUT          ), //          
    .VGA_BLUE_OUT          (VGA_BLUE_OUT        ), //    [1:0] 
    .VGA_GREEN_OUT         (VGA_GREEN_OUT       ), //    [2:0] 
    .VGA_HSYNC_OUT         (VGA_HSYNC_OUT       ), //          
    .VGA_RED_OUT           (VGA_RED_OUT         ), //    [2:0] 
    .VGA_VSYNC_OUT         (VGA_VSYNC_OUT       )  //          
   );


   
endmodule
