// Wrapper to represent the board top-level.
// The only ports at this level are the interfaces which leave the board

module BOARD_TOP
   (

    // Push-buttons
    input      BTN_0_IN              , // 
    input      BTN_1_IN              , // 
    input      BTN_2_IN              , // 
    input      BTN_3_IN              , //

//    // 50MHz master clock input
//    input      CLK_IN                , //

    // EPP interface to USB chip
    input      EPP_ASTB_IN           , // 
    input      EPP_DSTB_IN           , // 
    output     EPP_WAIT_OUT          , //

//     // Flash signals
//     output     FLASH_CS_OUT          , // 
//     output     FLASH_RP_OUT          , // 
//     input      FLASH_ST_STS_IN       , //
// 
//     // LEDs
//     output     LED_0_OUT             , // 
//     output     LED_1_OUT             , // 
//     output     LED_2_OUT             , // 
//     output     LED_3_OUT             , // 
//     output     LED_4_OUT             , // 
//     output     LED_5_OUT             , // 
//     output     LED_6_OUT             , // 
//     output     LED_7_OUT             , //
// 
//     // Memory address [23:1]
//     output     MEM_ADDR_1_OUT        , // 
//     output     MEM_ADDR_2_OUT        , // 
//     output     MEM_ADDR_3_OUT        , // 
//     output     MEM_ADDR_4_OUT        , // 
//     output     MEM_ADDR_5_OUT        , // 
//     output     MEM_ADDR_6_OUT        , // 
//     output     MEM_ADDR_7_OUT        , // 
//     output     MEM_ADDR_8_OUT        , // 
//     output     MEM_ADDR_9_OUT        , // 
//     output     MEM_ADDR_10_OUT       , // 
//     output     MEM_ADDR_11_OUT       , // 
//     output     MEM_ADDR_12_OUT       , // 
//     output     MEM_ADDR_13_OUT       , // 
//     output     MEM_ADDR_14_OUT       , // 
//     output     MEM_ADDR_15_OUT       , // 
//     output     MEM_ADDR_16_OUT       , // 
//     output     MEM_ADDR_17_OUT       , // 
//     output     MEM_ADDR_18_OUT       , // 
//     output     MEM_ADDR_19_OUT       , // 
//     output     MEM_ADDR_20_OUT       , // 
//     output     MEM_ADDR_21_OUT       , // 
//     output     MEM_ADDR_22_OUT       , // 
//     output     MEM_ADDR_23_OUT       , //
// 
//     // Memory Data [16:0]
//     inout      MEM_DATA_0_INOUT      , // 
//     inout      MEM_DATA_1_INOUT      , // 
//     inout      MEM_DATA_2_INOUT      , // 
//     inout      MEM_DATA_3_INOUT      , // 
//     inout      MEM_DATA_4_INOUT      , // 
//     inout      MEM_DATA_5_INOUT      , // 
//     inout      MEM_DATA_6_INOUT      , // 
//     inout      MEM_DATA_7_INOUT      , // 
//     inout      MEM_DATA_8_INOUT      , // 
//     inout      MEM_DATA_9_INOUT      , // 
//     inout      MEM_DATA_10_INOUT     , // 
//     inout      MEM_DATA_11_INOUT     , // 
//     inout      MEM_DATA_12_INOUT     , // 
//     inout      MEM_DATA_13_INOUT     , // 
//     inout      MEM_DATA_14_INOUT     , // 
//     inout      MEM_DATA_15_INOUT     , //
// 
//     // Memory Control
//     output     MEM_OE_OUT            , // 
//     output     MEM_WR_OUT            , //
// 
    // PS2 Interface
    inout      PS2_CLK_INOUT         , // 
    inout      PS2_DATA_INOUT        , //

//     // RAM control
//     output     RAM_ADV_OUT           , // 
//     output     RAM_CLK_OUT           , // 
//     output     RAM_CRE_OUT           , // 
//     output     RAM_CS_OUT            , // 
//     output     RAM_LB_OUT            , // 
//     output     RAM_UB_OUT            , // 
//     input      RAM_WAIT_IN           , //
// 
    // RS232 port
    input      RS232_RX_IN           , // 
    inout      RS232_TX_INOUT        , //

//     // 7-Segment displays
//     output     SSEG_AN_0_OUT         , // 
//     output     SSEG_AN_1_OUT         , // 
//     output     SSEG_AN_2_OUT         , // 
//     output     SSEG_AN_3_OUT         , // 
//     output     SSEG_K_0_OUT          , // 
//     output     SSEG_K_1_OUT          , // 
//     output     SSEG_K_2_OUT          , // 
//     output     SSEG_K_3_OUT          , // 
//     output     SSEG_K_4_OUT          , // 
//     output     SSEG_K_5_OUT          , // 
//     output     SSEG_K_6_OUT          , // 
//     output     SSEG_K_7_OUT          , //

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
   
//-------------------------------------------------------------
// Wires for the interfaces which are at board level.
//-------------------------------------------------------------
   reg 	       CLK;

     // Flash signals. Only RAM used on the board.
     wire     FLASH_CS              ; //  output 
     wire     FLASH_RP              ; //  output 
     wire     FLASH_ST_STS          = 1'b0; //  input  
 
     // wire
     wire     LED_0                 ; // output 
     wire     LED_1                 ; // output 
     wire     LED_2                 ; // output 
     wire     LED_3                 ; // output 
     wire     LED_4                 ; // output 
     wire     LED_5                 ; // output 
     wire     LED_6                 ; // output 
     wire     LED_7                 ; // output 
     wire [7:0] LED = {LED_7, LED_6, LED_5, LED_4, LED_3, LED_2, LED_1, LED_0};
   
     // wire address [23:1]
     wire     MEM_ADDR_1            ; // output 
     wire     MEM_ADDR_2            ; // output 
     wire     MEM_ADDR_3            ; // output 
     wire     MEM_ADDR_4            ; // output 
     wire     MEM_ADDR_5            ; // output 
     wire     MEM_ADDR_6            ; // output 
     wire     MEM_ADDR_7            ; // output 
     wire     MEM_ADDR_8            ; // output 
     wire     MEM_ADDR_9            ; // output 
     wire     MEM_ADDR_10           ; // output 
     wire     MEM_ADDR_11           ; // output 
     wire     MEM_ADDR_12           ; // output 
     wire     MEM_ADDR_13           ; // output 
     wire     MEM_ADDR_14           ; // output 
     wire     MEM_ADDR_15           ; // output 
     wire     MEM_ADDR_16           ; // output 
     wire     MEM_ADDR_17           ; // output 
     wire     MEM_ADDR_18           ; // output 
     wire     MEM_ADDR_19           ; // output 
     wire     MEM_ADDR_20           ; // output 
     wire     MEM_ADDR_21           ; // output 
     wire     MEM_ADDR_22           ; // output 
     wire     MEM_ADDR_23           ; // output 
     wire [23:1] MEM_ADDR = {MEM_ADDR_23, MEM_ADDR_22, MEM_ADDR_21, MEM_ADDR_20,
			     MEM_ADDR_19, MEM_ADDR_18, MEM_ADDR_17, MEM_ADDR_16,
			     MEM_ADDR_15, MEM_ADDR_14, MEM_ADDR_13, MEM_ADDR_12,
			     MEM_ADDR_11, MEM_ADDR_10, MEM_ADDR_9 , MEM_ADDR_8 ,
			     MEM_ADDR_7 , MEM_ADDR_6 , MEM_ADDR_5 , MEM_ADDR_4 ,
			     MEM_ADDR_3 , MEM_ADDR_2 , MEM_ADDR_1               };
   
   // wire Control
     wire     MEM_OE                ; // output 
     wire     MEM_WR                ; // output 
 
     // wire control
     wire     RAM_ADV               ; // output 
     wire     RAM_CLK               ; // output 
     wire     RAM_CRE               ; // output 
     wire     RAM_CS                ; // output 
     wire     RAM_LB                ; // output 
     wire     RAM_UB                ; // output 
     wire     RAM_WAIT              ; // input  
 
     // wire-Segment displays
     wire     SSEG_AN_0             ; // output 
     wire     SSEG_AN_1             ; // output 
     wire     SSEG_AN_2             ; // output 
     wire     SSEG_AN_3             ; // output 
     wire     SSEG_K_0              ; // output 
     wire     SSEG_K_1              ; // output 
     wire     SSEG_K_2              ; // output 
     wire     SSEG_K_3              ; // output 
     wire     SSEG_K_4              ; // output 
     wire     SSEG_K_5              ; // output 
     wire     SSEG_K_6              ; // output 
     wire     SSEG_K_7              ; // output 

   wire [15:0] MEM_DATA;

//-------------------------------------------------------------
// Board-level BFMs
//-------------------------------------------------------------

   // Clock gen (50MHz)
   initial
     begin
        CLK = 1'b0;
     end
   always #10 CLK = !CLK;

cellram cellram
   (
    .clk     (RAM_CLK   ), 
    .adv_n   (RAM_ADV   ),
    .cre     (RAM_CRE   ), 
    .o_wait  (RAM_WAIT  ),
    .ce_n    (RAM_CS    ),
    .oe_n    (MEM_OE    ),
    .we_n    (MEM_WR    ),
    .lb_n    (RAM_LB    ),
    .ub_n    (RAM_UB    ),
    .addr    (MEM_ADDR  ),
    .dq      (MEM_DATA  )
); 


FPGA_TOP fpga_top
   (

    .BTN_0_IN              (BTN_0_IN               ), // 
    .BTN_1_IN              (BTN_1_IN               ), // 
    .BTN_2_IN              (BTN_2_IN               ), // 
    .BTN_3_IN              (BTN_3_IN               ), //

    .CLK_IN                (CLK                    ), //

    .EPP_ASTB_IN           (EPP_ASTB_IN            ), // 
    .EPP_DSTB_IN           (EPP_DSTB_IN            ), // 
    .EPP_WAIT_OUT          (EPP_WAIT_OUT           ), //

    .FLASH_CS_OUT          (FLASH_CS               ), // 
    .FLASH_RP_OUT          (FLASH_RP               ), // 
    .FLASH_ST_STS_IN       (FLASH_ST_STS           ), //

    .LED_0_OUT             (LED_0                  ), // 
    .LED_1_OUT             (LED_1                  ), // 
    .LED_2_OUT             (LED_2                  ), // 
    .LED_3_OUT             (LED_3                  ), // 
    .LED_4_OUT             (LED_4                  ), // 
    .LED_5_OUT             (LED_5                  ), // 
    .LED_6_OUT             (LED_6                  ), // 
    .LED_7_OUT             (LED_7                  ), //

    .MEM_ADDR_1_OUT        (MEM_ADDR_1             ), // 
    .MEM_ADDR_2_OUT        (MEM_ADDR_2             ), // 
    .MEM_ADDR_3_OUT        (MEM_ADDR_3             ), // 
    .MEM_ADDR_4_OUT        (MEM_ADDR_4             ), // 
    .MEM_ADDR_5_OUT        (MEM_ADDR_5             ), // 
    .MEM_ADDR_6_OUT        (MEM_ADDR_6             ), // 
    .MEM_ADDR_7_OUT        (MEM_ADDR_7             ), // 
    .MEM_ADDR_8_OUT        (MEM_ADDR_8             ), // 
    .MEM_ADDR_9_OUT        (MEM_ADDR_9             ), // 
    .MEM_ADDR_10_OUT       (MEM_ADDR_10            ), // 
    .MEM_ADDR_11_OUT       (MEM_ADDR_11            ), // 
    .MEM_ADDR_12_OUT       (MEM_ADDR_12            ), // 
    .MEM_ADDR_13_OUT       (MEM_ADDR_13            ), // 
    .MEM_ADDR_14_OUT       (MEM_ADDR_14            ), // 
    .MEM_ADDR_15_OUT       (MEM_ADDR_15            ), // 
    .MEM_ADDR_16_OUT       (MEM_ADDR_16            ), // 
    .MEM_ADDR_17_OUT       (MEM_ADDR_17            ), // 
    .MEM_ADDR_18_OUT       (MEM_ADDR_18            ), // 
    .MEM_ADDR_19_OUT       (MEM_ADDR_19            ), // 
    .MEM_ADDR_20_OUT       (MEM_ADDR_20            ), // 
    .MEM_ADDR_21_OUT       (MEM_ADDR_21            ), // 
    .MEM_ADDR_22_OUT       (MEM_ADDR_22            ), // 
    .MEM_ADDR_23_OUT       (MEM_ADDR_23            ), //
    
    .MEM_DATA_0_INOUT      (MEM_DATA[0]            ), // 
    .MEM_DATA_1_INOUT      (MEM_DATA[1]            ), // 
    .MEM_DATA_2_INOUT      (MEM_DATA[2]            ), // 
    .MEM_DATA_3_INOUT      (MEM_DATA[3]            ), // 
    .MEM_DATA_4_INOUT      (MEM_DATA[4]            ), // 
    .MEM_DATA_5_INOUT      (MEM_DATA[5]            ), // 
    .MEM_DATA_6_INOUT      (MEM_DATA[6]            ), // 
    .MEM_DATA_7_INOUT      (MEM_DATA[7]            ), // 
    .MEM_DATA_8_INOUT      (MEM_DATA[8]            ), // 
    .MEM_DATA_9_INOUT      (MEM_DATA[9]            ), // 
    .MEM_DATA_10_INOUT     (MEM_DATA[10]           ), // 
    .MEM_DATA_11_INOUT     (MEM_DATA[11]           ), // 
    .MEM_DATA_12_INOUT     (MEM_DATA[12]           ), // 
    .MEM_DATA_13_INOUT     (MEM_DATA[13]           ), // 
    .MEM_DATA_14_INOUT     (MEM_DATA[14]           ), // 
    .MEM_DATA_15_INOUT     (MEM_DATA[15]           ), //

    .MEM_OE_OUT            (MEM_OE                 ), // 
    .MEM_WR_OUT            (MEM_WR                 ), //

    .PS2_CLK_INOUT         (PS2_CLK_INOUT          ), // 
    .PS2_DATA_INOUT        (PS2_DATA_INOUT         ), //

    .RAM_ADV_OUT           (RAM_ADV                ), // 
    .RAM_CLK_OUT           (RAM_CLK                ), // 
    .RAM_CRE_OUT           (RAM_CRE                ), // 
    .RAM_CS_OUT            (RAM_CS                 ), // 
    .RAM_LB_OUT            (RAM_LB                 ), // 
    .RAM_UB_OUT            (RAM_UB                 ), // 
    .RAM_WAIT_IN           (RAM_WAIT               ), //

    .RS232_RX_IN           (RS232_RX_IN            ), // 
    .RS232_TX_INOUT        (RS232_TX_INOUT         ), //

    .SSEG_AN_0_OUT         (SSEG_AN_0              ), // 
    .SSEG_AN_1_OUT         (SSEG_AN_1              ), // 
    .SSEG_AN_2_OUT         (SSEG_AN_2              ), // 
    .SSEG_AN_3_OUT         (SSEG_AN_3              ), // 
    .SSEG_K_0_OUT          (SSEG_K_0               ), // 
    .SSEG_K_1_OUT          (SSEG_K_1               ), // 
    .SSEG_K_2_OUT          (SSEG_K_2               ), // 
    .SSEG_K_3_OUT          (SSEG_K_3               ), // 
    .SSEG_K_4_OUT          (SSEG_K_4               ), // 
    .SSEG_K_5_OUT          (SSEG_K_5               ), // 
    .SSEG_K_6_OUT          (SSEG_K_6               ), // 
    .SSEG_K_7_OUT          (SSEG_K_7               ), //

    .SW_0_IN               (SW_0_IN                ), // 
    .SW_1_IN               (SW_1_IN                ), // 
    .SW_2_IN               (SW_2_IN                ), // 
    .SW_3_IN               (SW_3_IN                ), // 
    .SW_4_IN               (SW_4_IN                ), // 
    .SW_5_IN               (SW_5_IN                ), // 
    .SW_6_IN               (SW_6_IN                ), // 
    .SW_7_IN               (SW_7_IN                ), //

    .USB_ADDR_0_OUT        (USB_ADDR_0_OUT         ), // 
    .USB_ADDR_1_OUT        (USB_ADDR_1_OUT         ), // 
    .USB_CLK_IN            (USB_CLK_IN             ), // 
    .USB_DATA_0_INOUT      (USB_DATA_0_INOUT       ), // 
    .USB_DATA_1_INOUT      (USB_DATA_1_INOUT       ), // 
    .USB_DATA_2_INOUT      (USB_DATA_2_INOUT       ), // 
    .USB_DATA_3_INOUT      (USB_DATA_3_INOUT       ), // 
    .USB_DATA_4_INOUT      (USB_DATA_4_INOUT       ), // 
    .USB_DATA_5_INOUT      (USB_DATA_5_INOUT       ), // 
    .USB_DATA_6_INOUT      (USB_DATA_6_INOUT       ), // 
    .USB_DATA_7_INOUT      (USB_DATA_7_INOUT       ), // 
    .USB_DIR_IN            (USB_DIR_IN             ), // 
    .USB_FLAG_IN           (USB_FLAG_IN            ), // 
    .USB_MODE_IN           (USB_MODE_IN            ), // 
    .USB_OE_OUT            (USB_OE_OUT             ), // 
    .USB_PKTEND_OUT        (USB_PKTEND_OUT         ), // 
    .USB_WR_OUT            (USB_WR_OUT             ), //

    .VGA_BLUE_0_OUT        (VGA_BLUE_0_OUT         ), // 
    .VGA_BLUE_1_OUT        (VGA_BLUE_1_OUT         ), // 
    .VGA_GREEN_0_OUT       (VGA_GREEN_0_OUT        ), // 
    .VGA_GREEN_1_OUT       (VGA_GREEN_1_OUT        ), // 
    .VGA_GREEN_2_OUT       (VGA_GREEN_2_OUT        ), // 
    .VGA_HSYNC_OUT         (VGA_HSYNC_OUT          ), // 
    .VGA_RED_0_OUT         (VGA_RED_0_OUT          ), // 
    .VGA_RED_1_OUT         (VGA_RED_1_OUT          ), // 
    .VGA_RED_2_OUT         (VGA_RED_2_OUT          ), // 
    .VGA_VSYNC_OUT         (VGA_VSYNC_OUT          )  // 

    );



   

endmodule
