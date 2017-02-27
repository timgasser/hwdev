`define PCLK TB_BOARD_TOP.board_top.fpga_top.fpga_bus_top.digital_top.vga_top.CLK_VGA

/* Insert module header here */
module TB_BOARD_TOP ();

    // Push-buttons
    wire       BTN_0  ; // 
    wire       BTN_1  ; // 
    wire       BTN_2  ; // 
    wire       BTN_3  ; //

//    // 50MHz master clock wire 
//    wire       CLK                   ; //

    // EPP interface to USB chip
    wire       EPP_ASTB              ; // 
    wire       EPP_DSTB              ; // 
    wire       EPP_WAIT              ; //

    // PS2 Interface
    wire       PS2_CLK               = 1'b0; // 
    wire       PS2_DATA              = 1'b0; //

    // RS232 port
    wire       RS232_RX              = 1'b0; // 
    wire       RS232_TX              = 1'b0; //

    // Slider switches
    wire       SW_0   ; // 
    wire       SW_1   ; // 
    wire       SW_2   ; // 
    wire       SW_3   ; // 
    wire       SW_4   ; // 
    wire       SW_5   ; // 
    wire       SW_6   ; // 
    wire       SW_7   ; //

    // USB control
    wire       USB_ADDR_0            ; // 
    wire       USB_ADDR_1            ; // 
    wire       USB_CLK               = 1'b0; // 
    wire       USB_DATA_0            ; // 
    wire       USB_DATA_1            ; // 
    wire       USB_DATA_2            ; // 
    wire       USB_DATA_3            ; // 
    wire       USB_DATA_4            ; // 
    wire       USB_DATA_5            ; // 
    wire       USB_DATA_6            ; // 
    wire       USB_DATA_7            ; // 
    wire       USB_DIR               = 1'b0; // 
    wire       USB_FLAG              ; // 
    wire       USB_MODE              = 1'b0; // 
    wire       USB_OE                ; // 
    wire       USB_PKTEND            ; // 
    wire       USB_WR                ; //

    // VGA Interface
    wire       VGA_BLUE_0            ; // 
    wire       VGA_BLUE_1            ; // 
    wire       VGA_GREEN_0           ; // 
    wire       VGA_GREEN_1           ; // 
    wire       VGA_GREEN_2           ; // 
    wire       VGA_HSYNC             ; // 
    wire       VGA_RED_0             ; // 
    wire       VGA_RED_1             ; // 
    wire       VGA_RED_2             ; // 
    wire       VGA_VSYNC             ; // 

   wire  [2:0] VgaRed     = {VGA_RED_2  , VGA_RED_1  , VGA_RED_0}; 
   wire  [2:0] VgaGreen   = {VGA_GREEN_2, VGA_GREEN_1, VGA_GREEN_0}; 
   wire  [1:0] VgaBlue    = {VGA_BLUE_1 , VGA_BLUE_0}; 
   
   wire [7:0] VgaRed8b    = VgaRed   * 36 ; 
   wire [7:0] VgaGreen8b  = VgaGreen * 36 ; 
   wire [7:0] VgaBlue8b   = VgaBlue  * 85 ; 

   // testcase
   TESTCASE testcase();

   // required for the BUFGCE
   glbl glbl ();
   
   // BFMs
   VGA_SLAVE_MONITOR 
      #( .STORE_IMAGES         (  1),
      
	 .HORIZ_SYNC           ( 96),
	 .HORIZ_BACK_PORCH     ( 48),
	 .HORIZ_ACTIVE_WIDTH   (640),
	 .HORIZ_FRONT_PORCH    ( 16),
      
	 .VERT_SYNC            (  2),
	 .VERT_BACK_PORCH      ( 33),
	 .VERT_ACTIVE_HEIGHT   (480),
	 .VERT_FRONT_PORCH     ( 10),
      
	 .R_HI         	       ( 23),
	 .R_LO         	       ( 16),
	 .G_HI         	       ( 15),
	 .G_LO         	       (  8),
	 .B_HI         	       (  7),
	 .B_LO         	       (  0),
      
	 .COLOUR_DEPTH         (  8)
	 )
   vga_slave_monitor
      (
       .PCLK       (`PCLK      ),
       .VSYNC_IN   (VGA_VSYNC  ),
       .HSYNC_IN   (VGA_HSYNC  ),   
       .RED_IN     (VgaRed8b   ),
       .GREEN_IN   (VgaGreen8b ),
       .BLUE_IN    (VgaBlue8b  )
       );

   EPP_MASTER_BFM epp_master_bfm
      (
       .EPP_DATA_INOUT  ({USB_DATA_7, USB_DATA_6, USB_DATA_5, USB_DATA_4,
			  USB_DATA_3, USB_DATA_2, USB_DATA_1, USB_DATA_0}),
       .EPP_WRITE_OUT   (USB_FLAG ),
       .EPP_ASTB_OUT    (EPP_ASTB ),
       .EPP_DSTB_OUT    (EPP_DSTB ),
       .EPP_WAIT_IN     (EPP_WAIT ),

       .EPP_INT_IN      (1'b0     ),
       .EPP_RESET_OUT   ( ) 
       );

BTN_SW_BFM btn_sw_bfm
   (
    .BTN_0        (BTN_0  ),
    .BTN_1        (BTN_1  ),
    .BTN_2        (BTN_2  ),
    .BTN_3        (BTN_3  ),

    .SW_0         (SW_0   ),
    .SW_1         (SW_1   ),
    .SW_2         (SW_2   ),
    .SW_3         (SW_3   ),
    .SW_4         (SW_4   ),
    .SW_5         (SW_5   ),
    .SW_6         (SW_6   ),
    .SW_7         (SW_7   )
    );

   BOARD_TOP board_top
      (

       .BTN_0_IN              (BTN_0                  ), // 
       .BTN_1_IN              (BTN_1                  ), // 
       .BTN_2_IN              (BTN_2                  ), // 
       .BTN_3_IN              (BTN_3                  ), //

       .EPP_ASTB_IN           (EPP_ASTB               ), // 
       .EPP_DSTB_IN           (EPP_DSTB               ), // 
       .EPP_WAIT_OUT          (EPP_WAIT               ), //

       .PS2_CLK_INOUT         (PS2_CLK                ), // 
       .PS2_DATA_INOUT        (PS2_DATA               ), //

       .RS232_RX_IN           (RS232_RX               ), // 
       .RS232_TX_INOUT        (RS232_TX               ), //

       .SW_0_IN               (SW_0                   ), // 
       .SW_1_IN               (SW_1                   ), // 
       .SW_2_IN               (SW_2                   ), // 
       .SW_3_IN               (SW_3                   ), // 
       .SW_4_IN               (SW_4                   ), // 
       .SW_5_IN               (SW_5                   ), // 
       .SW_6_IN               (SW_6                   ), // 
       .SW_7_IN               (SW_7                   ), //

       .USB_ADDR_0_OUT        (USB_ADDR_0             ), // 
       .USB_ADDR_1_OUT        (USB_ADDR_1             ), // 
       .USB_CLK_IN            (USB_CLK                ), // 
       .USB_DATA_0_INOUT      (USB_DATA_0             ), // 
       .USB_DATA_1_INOUT      (USB_DATA_1             ), // 
       .USB_DATA_2_INOUT      (USB_DATA_2             ), // 
       .USB_DATA_3_INOUT      (USB_DATA_3             ), // 
       .USB_DATA_4_INOUT      (USB_DATA_4             ), // 
       .USB_DATA_5_INOUT      (USB_DATA_5             ), // 
       .USB_DATA_6_INOUT      (USB_DATA_6             ), // 
       .USB_DATA_7_INOUT      (USB_DATA_7             ), // 
       .USB_DIR_IN            (USB_DIR                ), // 
       .USB_FLAG_IN           (USB_FLAG               ), // 
       .USB_MODE_IN           (USB_MODE               ), // 
       .USB_OE_OUT            (USB_OE                 ), // 
       .USB_PKTEND_OUT        (USB_PKTEND             ), // 
       .USB_WR_OUT            (USB_WR                 ), //

       .VGA_BLUE_0_OUT        (VGA_BLUE_0             ), // 
       .VGA_BLUE_1_OUT        (VGA_BLUE_1             ), // 
       .VGA_GREEN_0_OUT       (VGA_GREEN_0            ), // 
       .VGA_GREEN_1_OUT       (VGA_GREEN_1            ), // 
       .VGA_GREEN_2_OUT       (VGA_GREEN_2            ), // 
       .VGA_HSYNC_OUT         (VGA_HSYNC              ), // 
       .VGA_RED_0_OUT         (VGA_RED_0              ), // 
       .VGA_RED_1_OUT         (VGA_RED_1              ), // 
       .VGA_RED_2_OUT         (VGA_RED_2              ), // 
       .VGA_VSYNC_OUT         (VGA_VSYNC              )  // 

       );
    
    
endmodule // TB_FPGA_TOP