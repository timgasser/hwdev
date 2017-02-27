
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
    output     [23:1] MEM_ADDR_OUT          , // Bit 0 isn't connected

    // Memory Data [15:0]
    inout      [15:0] MEM_DATA_INOUT        , // 

    // Memory Control
    output            MEM_OE_OUT            , // 
    output            MEM_WR_OUT            , //

    // PS2 Interface
    inout             PS2_CLK_INOUT         , // 
    inout             PS2_DATA_INOUT        , //

     // RAM control
    output            RAM_ADV_OUT           , // 
    output            RAM_CLK_OUT           , // 
    output            RAM_CRE_OUT           , // 
    output            RAM_CS_OUT            , // 
    output            RAM_LB_OUT            , // 
    output            RAM_UB_OUT            , // 
    input             RAM_WAIT_IN           , //

    // RS232 port
    input             RS232_RX_IN           , // 
    inout             RS232_TX_INOUT        , //

    // 7-Segment displays
    output      [3:0] SSEG_AN_OUT           , // 
    output      [7:0] SSEG_K_OUT            , // 

    // Slider switches
    input       [7:0] SW_IN                 , // 

    // USB control
    output      [1:0] USB_ADDR_OUT          , // 
    input             USB_CLK_IN            , // 
    inout       [7:0] USB_DATA_INOUT        , // 
    input             USB_DIR_IN            , // 
    input             USB_FLAG_IN           , // 
    input             USB_MODE_IN           , // 
    output            USB_OE_OUT            , // 
    output            USB_PKTEND_OUT        , // 
    output            USB_WR_OUT            , //

    // VGA Interface
    output      [1:0] VGA_BLUE_OUT          , // 
    output      [2:0] VGA_GREEN_OUT         , // 
    output            VGA_HSYNC_OUT         , // 
    output      [2:0] VGA_RED_OUT           , // 
    output            VGA_VSYNC_OUT           // 

    );

   // IBUFG input clock into FPGA
   wire               IbufgPreDcmClk; // 50MHz oscillator input after going through an IBUFG
   wire               BufgPreDcmClk;  // Use dedicated routing
   
   // DCM reset signals from SRL16 Shift regs
   wire               SysDcmRst;
   wire 	      SdrDcmRst;

   // SYS DCM signals
   wire               SysDcmClk50M     ; // DCM output - 50MHz clock
   wire               SysDcmClk25M     ; // DCM output - 25MHz clock
   wire               SysDcmClk33M     ; // DCM output - 33MHz clock
   wire               SysDcmLocked     ; // DCM output - LOCKED

   wire               SysBufgClk50M    ; // BUFG'ed SysDcmClk line
   wire               SysBufgClk25M    ; // BUFG'ed SysDcmClk line
   wire               SysBufgClk33M    ; // BUFG'ed SysDcmClk line

   // SDR DCM signals
   wire               SdrDcmClk50M     ;
   wire               SdrDcmClk33M     ;
   wire               SdrDcmLocked     ;
   
   wire               SdrBufgClk50M      ;
   wire 	      SdrBufgClk33M      ;
   wire               SdrBufgClk33MGated ;
   wire 	      RamClkEn           ;

   reg [1:0] 	      RamClkEnSdr33MPipe;

   // Logic Reset Signals
   wire 	      CoreRst33M ;
   wire 	      CoreRst25M ;
   wire 	      CoreSdrRst33M ;

   wire 	      DcmsLocked;

   // internal assigns
   assign DcmsLocked = SysDcmLocked & SdrDcmLocked;

   // external assigns
   assign RAM_CLK_OUT = SdrBufgClk33MGated;
   
   ///////////////////////////////////////////////////////////////////////////////////////////////////
   // Common Pre-DCM Reset and IBUFG for the CLK_IN pad
   ///////////////////////////////////////////////////////////////////////////////////////////////////
   
   // First IBUFG : Built into CLK_IN pad. Doesn't access global routing.
   IBUFG ibufg_pre_dcm
      (.I (CLK_IN         ), // Top-level pad
       .O (IbufgPreDcmClk )  // Pad input line
       );

   // BUFG - Takes pad CLK_IN and routes it all over the chip on global routing (to DCMs)
   BUFG bufg_pre_dcm
      (.I (IbufgPreDcmClk ), // From top-level pin
       .O (BufgPreDcmClk  )  // To DCM clock input, and DCM reset shift reg clock
       );

   // Generate RST pin for the main DCM
   SRL16 
      #(
        .INIT(16'hFFFF) // Initial Value of Shift Register
        ) 
   srl16_sys_dcm_rst 
      (
       .Q    (SysDcmRst        ), // SRL data output
       .A0   (1'b1             ), // Select[0] input <- Program length of 16 for reset pulse (on CLK_IN)
       .A1   (1'b1             ), // Select[1] input
       .A2   (1'b1             ), // Select[2] input
       .A3   (1'b1             ), // Select[3] input
       .CLK  (BufgPreDcmClk    ), // Clock input
       .D    (1'b0             )  // SRL data input
       );

   // Generate RST for the SDRAM DCM
   SRL16 
      #(
        .INIT(16'hFFFF) // Initial Value of Shift Register
        ) 
   srl16_sdr_dcm_rst 
      (
       .Q    (SdrDcmRst        ), // SRL data output
       .A0   (1'b1             ), // Select[0] input <- Program length of 16 for reset pulse (on CLK_IN)
       .A1   (1'b1             ), // Select[1] input
       .A2   (1'b1             ), // Select[2] input
       .A3   (1'b1             ), // Select[3] input
       .CLK  (BufgPreDcmClk    ), // Clock input
       .D    (1'b0             )  // SRL data input
       );

   ///////////////////////////////////////////////////////////////////////////////////////////////////



   ///////////////////////////////////////////////////////////////////////////////////////////////////
   // DCM instantiations and associated BUFGs
   ///////////////////////////////////////////////////////////////////////////////////////////////////

   // SYS DCM - Generates 50MHz, 33MHz and 25MHz clocks
   DCM_SP 
      #(.CLKDV_DIVIDE           (2.0                  ),
        .CLKFX_DIVIDE           (3                    ),
        .CLKFX_MULTIPLY         (2                    ),
        .CLKIN_DIVIDE_BY_2      ("FALSE"              ),
        .CLKIN_PERIOD           (20.0                 ),
        .CLKOUT_PHASE_SHIFT     ("FIXED"              ),
        .CLK_FEEDBACK           ("1X"                 ),
        .DESKEW_ADJUST          ("SYSTEM_SYNCHRONOUS" ),
        .DLL_FREQUENCY_MODE     ("LOW"                ),
        .DUTY_CYCLE_CORRECTION  ("TRUE"               ),
        .PHASE_SHIFT            (0                    ),
        .STARTUP_WAIT           ("FALSE"              ) 
        ) 
   dcm_sp_sys
      (
       .CLK0            (SysDcmClk50M      ), 
       .CLK180          (                  ), 
       .CLK270          (                  ), 
       .CLK2X           (                  ), 
       .CLK2X180        (                  ), 
       .CLK90           (                  ), 
       .CLKDV           (SysDcmClk25M      ), 
       .CLKFX           (SysDcmClk33M      ), 
       .CLKFX180        (                  ), 
       .LOCKED          (SysDcmLocked      ), 
       .PSDONE          (                  ), 
       .STATUS          (                  ), 
       .CLKFB           (SysBufgClk50M     ), 
       .CLKIN           (BufgPreDcmClk     ), 
       .PSCLK           (                  ), 
       .PSEN            (                  ), 
       .PSINCDEC        (                  ), 
       .RST             (SysDcmRst         ), 
       .DSSEN           (                  )  
       );

   // BUFGs for SYS post-DCM clocks 
   BUFG bufg_post_sys_dcm_50m
      (.I (SysDcmClk50M  ),
       .O (SysBufgClk50M )
       );

   BUFG bufg_post_sys_dcm_25m
      (.I (SysDcmClk25M  ),
       .O (SysBufgClk25M )
       );

   BUFG bufg_post_sys_dcm_33m
      (.I (SysDcmClk33M  ),
       .O (SysBufgClk33M )
       );

   // SDRAM DCM - produces phase-shifted 33MHz output for external SDRAM
   DCM_SP 
      #(.CLKDV_DIVIDE           (2.0                   ),
        .CLKFX_DIVIDE           (3                     ),
        .CLKFX_MULTIPLY         (2                     ),
        .CLKIN_DIVIDE_BY_2      ("FALSE"               ),
        .CLKIN_PERIOD           (20.0                  ),
        .CLKOUT_PHASE_SHIFT     ("FIXED"               ),
        .CLK_FEEDBACK           ("1X"                  ),
        .DESKEW_ADJUST          ("SYSTEM_SYNCHRONOUS"  ),
        .DLL_FREQUENCY_MODE     ("LOW"                 ),
        .DUTY_CYCLE_CORRECTION  ("TRUE"                ),
        .PHASE_SHIFT            (64                    ),
        .STARTUP_WAIT           ("FALSE"               ) 
        ) 
   dcm_sp_sdr
      (
       .CLK0            (SdrDcmClk50M      ),
       .CLK180          (                  ),
       .CLK270          (                  ),
       .CLK2X           (                  ),
       .CLK2X180        (                  ),
       .CLK90           (                  ),
       .CLKDV           (         	   ),
       .CLKFX           (SdrDcmClk33M 	   ),
       .CLKFX180        (                  ),
       .LOCKED          (SdrDcmLocked      ),
       .PSDONE          (                  ),
       .STATUS          (                  ),
       .CLKFB           (SdrBufgClk50M     ),
       .CLKIN           (BufgPreDcmClk     ),
       .PSCLK           (                  ),
       .PSEN            (                  ),
       .PSINCDEC        (                  ),
       .RST             (SdrDcmRst         ), 
       .DSSEN           (                  )  
       );

   // Need to buffer the 50MHz clock and send into CLK_FB pin
   BUFG bufg_post_sdr_dcm_50m
      (.I (SdrDcmClk50M   ),
       .O (SdrBufgClk50M  )
       );

   // BUFG the 33MHZ clock for reset release
   BUFG bufg_post_sdr_dcm_33m
      (.I (SdrDcmClk33M   ),
       .O (SdrBufgClk33M  )
       );

   // Need to resync the enable for the phase-shifted 33MHz clock from SYS 33MHz domain
   always @(posedge SdrBufgClk33M or posedge CoreSdrRst33M)
   begin : RAM_CLK_EN_RESYNC
      if (CoreSdrRst33M)
      begin
	 RamClkEnSdr33MPipe <= 2'b00;
      end
      else
      begin
 	 RamClkEnSdr33MPipe <= {RamClkEn, RamClkEnSdr33MPipe[1]};
     end
   end
   
   // Clock-gate the SDRAM clock to the logic and external chip
   BUFGCE bufgce_post_sdr_dcm_33m_gate
      (.I  (SdrDcmClk33M          ),
       .CE (RamClkEnSdr33MPipe[0] ),
       .O  (SdrBufgClk33MGated    )
       );

   ///////////////////////////////////////////////////////////////////////////////////////////////////

   
   ///////////////////////////////////////////////////////////////////////////////////////////////////
   // Core logic reset generation
   ///////////////////////////////////////////////////////////////////////////////////////////////////

   // Reset generator for the 25MHz logic
   SRL16 
      #(
        .INIT(16'hFFFF) // Initial Value of Shift Register
        ) 
   srl16_core_reset_25m 
      (
       .Q    (CoreRst25M       ), // SRL data output
       .A0   (1'b1             ), // Select[0] input 
       .A1   (1'b1             ), // Select[1] input
       .A2   (1'b1             ), // Select[2] input
       .A3   (1'b1             ), // Select[3] input
       .CLK  (SysBufgClk25M    ), // Clock input     <- From DCM output. Use slowest DCM clock output
       .D    (~SysDcmLocked    )  // SRL data input  <- De-assert reset 16 cycles after DCM locks
       );
   
   // Reset generator for the 33MHz logic
   SRL16 
      #(
        .INIT(16'hFFFF) // Initial Value of Shift Register
        ) 
   srl16_core_reset_33m 
      (
       .Q    (CoreRst33M       ), // SRL data output
       .A0   (1'b1             ), // Select[0] input 
       .A1   (1'b1             ), // Select[1] input
       .A2   (1'b1             ), // Select[2] input
       .A3   (1'b1             ), // Select[3] input
       .CLK  (SysBufgClk33M    ), // Clock input     <- From DCM output. Use slowest DCM clock output
       .D    (~SysDcmLocked    )  // SRL data input  <- De-assert reset 16 cycles after DCM locks
       );

   // Reset generator for the 33MHz SDRAM logic
   SRL16 
      #(
        .INIT(16'hFFFF) // Initial Value of Shift Register
        ) 
   srl16_core_reset_33m_sdr 
      (
       .Q    (CoreSdrRst33M    ), // SRL data output
       .A0   (1'b1             ), // Select[0] input 
       .A1   (1'b1             ), // Select[1] input
       .A2   (1'b1             ), // Select[2] input
       .A3   (1'b1             ), // Select[3] input
       .CLK  (SdrBufgClk33M    ), // Clock input     <- From DCM output. Use slowest DCM clock output
       .D    (~SdrDcmLocked    )  // SRL data input  <- De-assert reset 16 cycles after DCM locks
       );

   ///////////////////////////////////////////////////////////////////////////////////////////////////

   
   
// Need to add the clock and reset generation for digital_top.
// Route LEDs and switches into digital_top (depends on platform)
// Tie off unused ports from digital top and synthesis will remove them.

   DIGITAL_TOP digital_top
   (
    .CLK_33M               (SysBufgClk33M       ),
    .CLK_25M               (SysBufgClk25M       ),
    .CLK_SDR_33M           (SdrBufgClk33MGated  ),
    .RST_ASYNC_33M         (CoreRst33M          ),
    .RST_ASYNC_25M         (CoreRst25M          ),
    .RST_ASYNC_SDR_33M     (CoreSdrRst33M       ),
    .DCMS_LOCKED_IN        (DcmsLocked          ),
    
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
    .RAM_CLK_EN_OUT        (RamClkEn            ), //          
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
