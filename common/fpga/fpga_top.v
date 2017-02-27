module FPGA_TOP
   (

    // Push-buttons
    input      BTN_0_IN              , // 
    input      BTN_1_IN              , // 
    input      BTN_2_IN              , // 
    input      BTN_3_IN              , //

    // 50MHz master clock input
    input      CLK_IN                , //

    // EPP interface to USB chip
    input      EPP_ASTB_IN           , // 
    input      EPP_DSTB_IN           , // 
    output     EPP_WAIT_OUT          , //

    // Flash signals
    output     FLASH_CS_OUT          , // 
    output     FLASH_RP_OUT          , // 
    input      FLASH_ST_STS_IN       , //

    // LEDs
    output     LED_0_OUT             , // 
    output     LED_1_OUT             , // 
    output     LED_2_OUT             , // 
    output     LED_3_OUT             , // 
    output     LED_4_OUT             , // 
    output     LED_5_OUT             , // 
    output     LED_6_OUT             , // 
    output     LED_7_OUT             , //

    // Memory address [23:1]
    output     MEM_ADDR_1_OUT        , // 
    output     MEM_ADDR_2_OUT        , // 
    output     MEM_ADDR_3_OUT        , // 
    output     MEM_ADDR_4_OUT        , // 
    output     MEM_ADDR_5_OUT        , // 
    output     MEM_ADDR_6_OUT        , // 
    output     MEM_ADDR_7_OUT        , // 
    output     MEM_ADDR_8_OUT        , // 
    output     MEM_ADDR_9_OUT        , // 
    output     MEM_ADDR_10_OUT       , // 
    output     MEM_ADDR_11_OUT       , // 
    output     MEM_ADDR_12_OUT       , // 
    output     MEM_ADDR_13_OUT       , // 
    output     MEM_ADDR_14_OUT       , // 
    output     MEM_ADDR_15_OUT       , // 
    output     MEM_ADDR_16_OUT       , // 
    output     MEM_ADDR_17_OUT       , // 
    output     MEM_ADDR_18_OUT       , // 
    output     MEM_ADDR_19_OUT       , // 
    output     MEM_ADDR_20_OUT       , // 
    output     MEM_ADDR_21_OUT       , // 
    output     MEM_ADDR_22_OUT       , // 
    output     MEM_ADDR_23_OUT       , //

    // Memory Data [16:0]
    inout      MEM_DATA_0_INOUT      , // 
    inout      MEM_DATA_1_INOUT      , // 
    inout      MEM_DATA_2_INOUT      , // 
    inout      MEM_DATA_3_INOUT      , // 
    inout      MEM_DATA_4_INOUT      , // 
    inout      MEM_DATA_5_INOUT      , // 
    inout      MEM_DATA_6_INOUT      , // 
    inout      MEM_DATA_7_INOUT      , // 
    inout      MEM_DATA_8_INOUT      , // 
    inout      MEM_DATA_9_INOUT      , // 
    inout      MEM_DATA_10_INOUT     , // 
    inout      MEM_DATA_11_INOUT     , // 
    inout      MEM_DATA_12_INOUT     , // 
    inout      MEM_DATA_13_INOUT     , // 
    inout      MEM_DATA_14_INOUT     , // 
    inout      MEM_DATA_15_INOUT     , //

    // Memory Control
    output     MEM_OE_OUT            , // 
    output     MEM_WR_OUT            , //

    // PS2 Interface
    inout      PS2_CLK_INOUT         , // 
    inout      PS2_DATA_INOUT        , //

    // RAM control
    output     RAM_ADV_OUT           , // 
    output     RAM_CLK_OUT           , // 
    output     RAM_CRE_OUT           , // 
    output     RAM_CS_OUT            , // 
    output     RAM_LB_OUT            , // 
    output     RAM_UB_OUT            , // 
    input      RAM_WAIT_IN           , //

    // RS232 port
    input      RS232_RX_IN           , // 
    inout      RS232_TX_INOUT        , //

    // 7-Segment displays
    output     SSEG_AN_0_OUT         , // 
    output     SSEG_AN_1_OUT         , // 
    output     SSEG_AN_2_OUT         , // 
    output     SSEG_AN_3_OUT         , // 
    output     SSEG_K_0_OUT          , // 
    output     SSEG_K_1_OUT          , // 
    output     SSEG_K_2_OUT          , // 
    output     SSEG_K_3_OUT          , // 
    output     SSEG_K_4_OUT          , // 
    output     SSEG_K_5_OUT          , // 
    output     SSEG_K_6_OUT          , // 
    output     SSEG_K_7_OUT          , //

    // Slider switches
    input      SW_0_IN               , // 
    input      SW_1_IN               , // 
    input      SW_2_IN               , // 
    input      SW_3_IN               , // 
    input      SW_4_IN               , // 
    input      SW_5_IN               , // 
    input      SW_6_IN               , // 
    input      SW_7_IN               , //

    // USB control
    output     USB_ADDR_0_OUT        , // 
    output     USB_ADDR_1_OUT        , // 
    input      USB_CLK_IN            , // 
    inout      USB_DATA_0_INOUT      , // 
    inout      USB_DATA_1_INOUT      , // 
    inout      USB_DATA_2_INOUT      , // 
    inout      USB_DATA_3_INOUT      , // 
    inout      USB_DATA_4_INOUT      , // 
    inout      USB_DATA_5_INOUT      , // 
    inout      USB_DATA_6_INOUT      , // 
    inout      USB_DATA_7_INOUT      , // 
    input      USB_DIR_IN            , // 
    input      USB_FLAG_IN           , // 
    input      USB_MODE_IN           , // 
    output     USB_OE_OUT            , // 
    output     USB_PKTEND_OUT        , // 
    output     USB_WR_OUT            , //

    // VGA Interface
    output     VGA_BLUE_0_OUT        , // 
    output     VGA_BLUE_1_OUT        , // 
    output     VGA_GREEN_0_OUT       , // 
    output     VGA_GREEN_1_OUT       , // 
    output     VGA_GREEN_2_OUT       , // 
    output     VGA_HSYNC_OUT         , // 
    output     VGA_RED_0_OUT         , // 
    output     VGA_RED_1_OUT         , // 
    output     VGA_RED_2_OUT         , // 
    output     VGA_VSYNC_OUT           // 

    );



  
   // Bus the INPUT signals here
   wire [3:0]  BTN       = {BTN_3_IN, BTN_2_IN, BTN_1_IN, BTN_0_IN};
   wire [7:0]  SW        = {SW_7_IN, SW_6_IN, SW_5_IN, SW_4_IN, SW_3_IN, SW_2_IN, SW_1_IN, SW_0_IN};



  


   // Declare OUTPUTs and assign them here
   wire [7:0]  LED;
   assign      LED_7_OUT = LED[7];
   assign      LED_6_OUT = LED[6];
   assign      LED_5_OUT = LED[5];
   assign      LED_4_OUT = LED[4];
   assign      LED_3_OUT = LED[3];
   assign      LED_2_OUT = LED[2];
   assign      LED_1_OUT = LED[1];
   assign      LED_0_OUT = LED[0];


   wire [23:1] MEM_ADDR;  
   assign      MEM_ADDR_23_OUT = MEM_ADDR[23];
   assign      MEM_ADDR_22_OUT = MEM_ADDR[22];
   assign      MEM_ADDR_21_OUT = MEM_ADDR[21];
   assign      MEM_ADDR_20_OUT = MEM_ADDR[20];
   assign      MEM_ADDR_19_OUT = MEM_ADDR[19];
   assign      MEM_ADDR_18_OUT = MEM_ADDR[18];
   assign      MEM_ADDR_17_OUT = MEM_ADDR[17];
   assign      MEM_ADDR_16_OUT = MEM_ADDR[16];
   assign      MEM_ADDR_15_OUT = MEM_ADDR[15];
   assign      MEM_ADDR_14_OUT = MEM_ADDR[14];
   assign      MEM_ADDR_13_OUT = MEM_ADDR[13];
   assign      MEM_ADDR_12_OUT = MEM_ADDR[12];
   assign      MEM_ADDR_11_OUT = MEM_ADDR[11];
   assign      MEM_ADDR_10_OUT = MEM_ADDR[10];
   assign      MEM_ADDR_9_OUT  = MEM_ADDR[ 9];
   assign      MEM_ADDR_8_OUT  = MEM_ADDR[ 8];
   assign      MEM_ADDR_7_OUT  = MEM_ADDR[ 7];
   assign      MEM_ADDR_6_OUT  = MEM_ADDR[ 6];
   assign      MEM_ADDR_5_OUT  = MEM_ADDR[ 5];
   assign      MEM_ADDR_4_OUT  = MEM_ADDR[ 4];
   assign      MEM_ADDR_3_OUT  = MEM_ADDR[ 3];
   assign      MEM_ADDR_2_OUT  = MEM_ADDR[ 2];
   assign      MEM_ADDR_1_OUT  = MEM_ADDR[ 1];
//   assign      MEM_ADDR_0_OUT  = MEM_ADDR[ 0];

//    wire [15:0] MEM_DATA;
//    assign      MEM_DATA_15_INOUT = MEM_DATA[15];
//    assign      MEM_DATA_14_INOUT = MEM_DATA[14];
//    assign      MEM_DATA_13_INOUT = MEM_DATA[13];
//    assign      MEM_DATA_12_INOUT = MEM_DATA[12];
//    assign      MEM_DATA_11_INOUT = MEM_DATA[11];
//    assign      MEM_DATA_10_INOUT = MEM_DATA[10];
//    assign      MEM_DATA_9_INOUT  = MEM_DATA[ 9];
//    assign      MEM_DATA_8_INOUT  = MEM_DATA[ 8];
//    assign      MEM_DATA_7_INOUT  = MEM_DATA[ 7];
//    assign      MEM_DATA_6_INOUT  = MEM_DATA[ 6];
//    assign      MEM_DATA_5_INOUT  = MEM_DATA[ 5];
//    assign      MEM_DATA_4_INOUT  = MEM_DATA[ 4];
//    assign      MEM_DATA_3_INOUT  = MEM_DATA[ 3];
//    assign      MEM_DATA_2_INOUT  = MEM_DATA[ 2];
//    assign      MEM_DATA_1_INOUT  = MEM_DATA[ 1];
//    assign      MEM_DATA_0_INOUT  = MEM_DATA[ 0];

   wire [3:0]  SSEG_AN;
   assign      SSEG_AN_0_OUT = SSEG_AN[0];
   assign      SSEG_AN_1_OUT = SSEG_AN[1];
   assign      SSEG_AN_2_OUT = SSEG_AN[2];
   assign      SSEG_AN_3_OUT = SSEG_AN[3];

   wire [7:0]  SSEG_K;
   assign      SSEG_K_0_OUT = SSEG_K[0];
   assign      SSEG_K_1_OUT = SSEG_K[1];
   assign      SSEG_K_2_OUT = SSEG_K[2];
   assign      SSEG_K_3_OUT = SSEG_K[3];
   assign      SSEG_K_4_OUT = SSEG_K[4];
   assign      SSEG_K_5_OUT = SSEG_K[5];
   assign      SSEG_K_6_OUT = SSEG_K[6];
   assign      SSEG_K_7_OUT = SSEG_K[7];

   wire [1:0]  USB_ADDR ;
   assign      USB_ADDR_0_OUT = USB_ADDR[0];
   assign      USB_ADDR_1_OUT = USB_ADDR[1];

//    wire [7:0]  USB_DATA;
//    assign      USB_DATA_0_INOUT = USB_DATA[0];
//    assign      USB_DATA_1_INOUT = USB_DATA[1];
//    assign      USB_DATA_2_INOUT = USB_DATA[2];
//    assign      USB_DATA_3_INOUT = USB_DATA[3];
//    assign      USB_DATA_4_INOUT = USB_DATA[4];
//    assign      USB_DATA_5_INOUT = USB_DATA[5];
//    assign      USB_DATA_6_INOUT = USB_DATA[6];
//    assign      USB_DATA_7_INOUT = USB_DATA[7];

   wire [1:0]  VGA_BLUE;
   wire [2:0]  VGA_GREEN;
   wire [2:0]  VGA_RED;
   assign      VGA_BLUE_0_OUT   = VGA_BLUE[0];
   assign      VGA_BLUE_1_OUT   = VGA_BLUE[1];
   assign      VGA_GREEN_0_OUT  = VGA_GREEN[0];
   assign      VGA_GREEN_1_OUT  = VGA_GREEN[1];
   assign      VGA_GREEN_2_OUT  = VGA_GREEN[2];
   assign      VGA_RED_0_OUT    = VGA_RED[0];
   assign      VGA_RED_1_OUT    = VGA_RED[1];
   assign      VGA_RED_2_OUT    = VGA_RED[2];


   FPGA_BUS_TOP fpga_bus_top
     (

      .BTN_IN                (BTN              ), // 
      .CLK_IN                (CLK_IN           ), //
      .EPP_ASTB_IN           (EPP_ASTB_IN      ), // 
      .EPP_DSTB_IN           (EPP_DSTB_IN      ), // 
      .EPP_WAIT_OUT          (EPP_WAIT_OUT     ), //
      .FLASH_CS_OUT          (FLASH_CS_OUT     ), // 
      .FLASH_RP_OUT          (FLASH_RP_OUT     ), // 
      .FLASH_ST_STS_IN       (FLASH_ST_STS_IN  ), //
      .LED_OUT               (LED              ), // 
      .MEM_ADDR_OUT          (MEM_ADDR         ), // Bit 0 isn't connected
      .MEM_DATA_INOUT        ({MEM_DATA_15_INOUT, MEM_DATA_14_INOUT, MEM_DATA_13_INOUT, MEM_DATA_12_INOUT ,
			       MEM_DATA_11_INOUT, MEM_DATA_10_INOUT, MEM_DATA_9_INOUT , MEM_DATA_8_INOUT  ,
			       MEM_DATA_7_INOUT , MEM_DATA_6_INOUT , MEM_DATA_5_INOUT , MEM_DATA_4_INOUT  ,
			       MEM_DATA_3_INOUT , MEM_DATA_2_INOUT , MEM_DATA_1_INOUT , MEM_DATA_0_INOUT  }), // 
      .MEM_OE_OUT            (MEM_OE_OUT       ), // 
      .MEM_WR_OUT            (MEM_WR_OUT       ), //
      .PS2_CLK_INOUT         (PS2_CLK_INOUT    ), // 
      .PS2_DATA_INOUT        (PS2_DATA_INOUT   ), //
      .RAM_ADV_OUT           (RAM_ADV_OUT      ), // 
      .RAM_CLK_OUT           (RAM_CLK_OUT      ), // 
      .RAM_CRE_OUT           (RAM_CRE_OUT      ), // 
      .RAM_CS_OUT            (RAM_CS_OUT       ), // 
      .RAM_LB_OUT            (RAM_LB_OUT       ), // 
      .RAM_UB_OUT            (RAM_UB_OUT       ), // 
      .RAM_WAIT_IN           (RAM_WAIT_IN      ), //
      .RS232_RX_IN           (RS232_RX_IN      ), // 
      .RS232_TX_INOUT        (RS232_TX_INOUT   ), //
      .SSEG_AN_OUT           (SSEG_AN          ), // 
      .SSEG_K_OUT            (SSEG_K           ), // 
      .SW_IN                 (SW               ), // 
      .USB_ADDR_OUT          (USB_ADDR         ), // 
      .USB_CLK_IN            (USB_CLK_IN       ), // 
      .USB_DATA_INOUT        ({USB_DATA_7_INOUT ,
			       USB_DATA_6_INOUT ,
			       USB_DATA_5_INOUT ,
			       USB_DATA_4_INOUT ,
			       USB_DATA_3_INOUT ,
			       USB_DATA_2_INOUT ,
			       USB_DATA_1_INOUT ,
			       USB_DATA_0_INOUT } ), // 
      .USB_DIR_IN            (USB_DIR_IN       ), // 
      .USB_FLAG_IN           (USB_FLAG_IN      ), // 
      .USB_MODE_IN           (USB_MODE_IN      ), // 
      .USB_OE_OUT            (USB_OE_OUT       ), // 
      .USB_PKTEND_OUT        (USB_PKTEND_OUT   ), // 
      .USB_WR_OUT            (USB_WR_OUT       ), //
      .VGA_BLUE_OUT          (VGA_BLUE         ), // 
      .VGA_GREEN_OUT         (VGA_GREEN        ), // 
      .VGA_HSYNC_OUT         (VGA_HSYNC_OUT    ), // 
      .VGA_RED_OUT           (VGA_RED          ), // 
      .VGA_VSYNC_OUT         (VGA_VSYNC_OUT    )  // 

      );







   
endmodule
