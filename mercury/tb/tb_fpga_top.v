/* Insert module header here */
module TB_FPGA_TOP ();

   // Tie off inputs (can be forced from testcase.v
   
   reg BTN_0;
//   wire  BTN_0             = 1'b0;
   wire  BTN_1             = 1'b0;
   wire  BTN_2             = 1'b0;
   wire  BTN_3             = 1'b0;
   reg   CLK               ;
   wire  EPP_ASTB          = 1'b0;
   wire  EPP_DSTB          = 1'b0;
   wire  EPP_WAIT          ;
   wire  FLASH_CS          ;
   wire  FLASH_RP          ;
   wire  FLASH_ST_STS      = 1'b0;
   wire  LED_0             ;
   wire  LED_1             ;
   wire  LED_2             ;
   wire  LED_3             ;
   wire  LED_4             ;
   wire  LED_5             ;
   wire  LED_6             ;
   wire  LED_7             ;
   wire  MEM_ADDR_1        ;
   wire  MEM_ADDR_2        ;
   wire  MEM_ADDR_3        ;
   wire  MEM_ADDR_4        ;
   wire  MEM_ADDR_5        ;
   wire  MEM_ADDR_6        ;
   wire  MEM_ADDR_7        ;
   wire  MEM_ADDR_8        ;
   wire  MEM_ADDR_9        ;
   wire  MEM_ADDR_10       ;
   wire  MEM_ADDR_11       ;
   wire  MEM_ADDR_12       ;
   wire  MEM_ADDR_13       ;
   wire  MEM_ADDR_14       ;
   wire  MEM_ADDR_15       ;
   wire  MEM_ADDR_16       ;
   wire  MEM_ADDR_17       ;
   wire  MEM_ADDR_18       ;
   wire  MEM_ADDR_19       ;
   wire  MEM_ADDR_20       ;
   wire  MEM_ADDR_21       ;
   wire  MEM_ADDR_22       ;
   wire  MEM_ADDR_23       ;
   wire  MEM_DATA_0        = 1'b0;
   wire  MEM_DATA_1        = 1'b0;
   wire  MEM_DATA_2        = 1'b0;
   wire  MEM_DATA_3        = 1'b0;
   wire  MEM_DATA_4        = 1'b0;
   wire  MEM_DATA_5        = 1'b0;
   wire  MEM_DATA_6        = 1'b0;
   wire  MEM_DATA_7        = 1'b0;
   wire  MEM_DATA_8        = 1'b0;
   wire  MEM_DATA_9        = 1'b0;
   wire  MEM_DATA_10       = 1'b0;
   wire  MEM_DATA_11       = 1'b0;
   wire  MEM_DATA_12       = 1'b0;
   wire  MEM_DATA_13       = 1'b0;
   wire  MEM_DATA_14       = 1'b0;
   wire  MEM_DATA_15       = 1'b0;   
   wire  MEM_OE            ;
   wire  MEM_WR            ;
   wire  PS2_CLK           = 1'b0;
   wire  PS2_DATA          = 1'b0;   
   wire  RAM_ADV           ;
   wire  RAM_CLK           ;
   wire  RAM_CRE           ;
   wire  RAM_CS            ;
   wire  RAM_LB            ;
   wire  RAM_UB            ;
   wire  RAM_WAIT          = 1'b0;
   wire  RS232_RX          ;
   wire  RS232_TX          ;
   wire  SSEG_AN_0         ;
   wire  SSEG_AN_1         ;
   wire  SSEG_AN_2         ;
   wire  SSEG_AN_3         ;
   wire  SSEG_K_0          ;
   wire  SSEG_K_1          ;
   wire  SSEG_K_2          ;
   wire  SSEG_K_3          ;
   wire  SSEG_K_4          ;
   wire  SSEG_K_5          ;
   wire  SSEG_K_6          ;
   wire  SSEG_K_7          ;
   wire  SW_0              = 1'b0;
   wire  SW_1              = 1'b0;
   wire  SW_2              = 1'b0;
   wire  SW_3              = 1'b0;
   wire  SW_4              = 1'b0;
   wire  SW_5              = 1'b0;
   wire  SW_6              = 1'b0;
   wire  SW_7              = 1'b0;
   wire  USB_ADDR_0        ;
   wire  USB_ADDR_1        ;
   wire  USB_CLK           = 1'b0;
   wire  USB_DATA_0        = 1'b0;
   wire  USB_DATA_1        = 1'b0;
   wire  USB_DATA_2        = 1'b0;
   wire  USB_DATA_3        = 1'b0;
   wire  USB_DATA_4        = 1'b0;
   wire  USB_DATA_5        = 1'b0;
   wire  USB_DATA_6        = 1'b0;
   wire  USB_DATA_7        = 1'b0;   
   wire  USB_DIR           = 1'b0;
   wire  USB_FLAG          = 1'b0;
   wire  USB_MODE          = 1'b0;
   wire  USB_OE            ;
   wire  USB_PKTEND        ;
   wire  USB_WR            ;
   wire  VGA_BLUE_0        ;
   wire  VGA_BLUE_1        ;
   wire  VGA_GREEN_0       ;
   wire  VGA_GREEN_1       ;
   wire  VGA_GREEN_2       ;
   wire  VGA_HSYNC         ;
   wire  VGA_RED_0         ;
   wire  VGA_RED_1         ;
   wire  VGA_RED_2         ;
   wire  VGA_VSYNC         ;


   // Clock gen (50MHz)
   initial
     begin
        CLK = 1'b0;
     end
   always #10 CLK = !CLK;


   // Press Button 0 to reset platform
   initial
      begin
	 BTN_0 = 1'b1;
	 @(posedge CLK);
	 @(posedge CLK);
	 @(posedge CLK);	 
	 @(posedge CLK);	 
	 BTN_0 = 1'b0;
      end
   
   // *************************************************************************


   // Insert models of RAM, ROM, etc in here

   // ARG ! Need this to instantiate the pipelined divider :-(

   glbl glbl ();
   
   // testcase
   TESTCASE testcase();
   
   // FPGA Top-level
   FPGA_TOP fpga_top
   (
    .BTN_0_IN              (BTN_0            ), // 
    .BTN_1_IN              (BTN_1            ), // 
    .BTN_2_IN              (BTN_2            ), // 
    .BTN_3_IN              (BTN_3            ), //
    .CLK_IN                (CLK              ), //
    .EPP_ASTB_IN           (EPP_ASTB         ), // 
    .EPP_DSTB_IN           (EPP_DSTB         ), // 
    .EPP_WAIT_OUT          (EPP_WAIT         ), //
    .FLASH_CS_OUT          (FLASH_CS         ), // 
    .FLASH_RP_OUT          (FLASH_RP         ), // 
    .FLASH_ST_STS_IN       (FLASH_ST_STS     ), //
    .LED_0_OUT             (LED_0            ), // 
    .LED_1_OUT             (LED_1            ), // 
    .LED_2_OUT             (LED_2            ), // 
    .LED_3_OUT             (LED_3            ), // 
    .LED_4_OUT             (LED_4            ), // 
    .LED_5_OUT             (LED_5            ), // 
    .LED_6_OUT             (LED_6            ), // 
    .LED_7_OUT             (LED_7            ), //
    .MEM_ADDR_1_OUT        (MEM_ADDR_1       ), // 
    .MEM_ADDR_2_OUT        (MEM_ADDR_2       ), // 
    .MEM_ADDR_3_OUT        (MEM_ADDR_3       ), // 
    .MEM_ADDR_4_OUT        (MEM_ADDR_4       ), // 
    .MEM_ADDR_5_OUT        (MEM_ADDR_5       ), // 
    .MEM_ADDR_6_OUT        (MEM_ADDR_6       ), // 
    .MEM_ADDR_7_OUT        (MEM_ADDR_7       ), // 
    .MEM_ADDR_8_OUT        (MEM_ADDR_8       ), // 
    .MEM_ADDR_9_OUT        (MEM_ADDR_9       ), // 
    .MEM_ADDR_10_OUT       (MEM_ADDR_10      ), // 
    .MEM_ADDR_11_OUT       (MEM_ADDR_11      ), // 
    .MEM_ADDR_12_OUT       (MEM_ADDR_12      ), // 
    .MEM_ADDR_13_OUT       (MEM_ADDR_13      ), // 
    .MEM_ADDR_14_OUT       (MEM_ADDR_14      ), // 
    .MEM_ADDR_15_OUT       (MEM_ADDR_15      ), // 
    .MEM_ADDR_16_OUT       (MEM_ADDR_16      ), // 
    .MEM_ADDR_17_OUT       (MEM_ADDR_17      ), // 
    .MEM_ADDR_18_OUT       (MEM_ADDR_18      ), // 
    .MEM_ADDR_19_OUT       (MEM_ADDR_19      ), // 
    .MEM_ADDR_20_OUT       (MEM_ADDR_20      ), // 
    .MEM_ADDR_21_OUT       (MEM_ADDR_21      ), // 
    .MEM_ADDR_22_OUT       (MEM_ADDR_22      ), // 
    .MEM_ADDR_23_OUT       (MEM_ADDR_23      ), //
    .MEM_DATA_0_INOUT      (MEM_DATA_0       ), // 
    .MEM_DATA_1_INOUT      (MEM_DATA_1       ), // 
    .MEM_DATA_2_INOUT      (MEM_DATA_2       ), // 
    .MEM_DATA_3_INOUT      (MEM_DATA_3       ), // 
    .MEM_DATA_4_INOUT      (MEM_DATA_4       ), // 
    .MEM_DATA_5_INOUT      (MEM_DATA_5       ), // 
    .MEM_DATA_6_INOUT      (MEM_DATA_6       ), // 
    .MEM_DATA_7_INOUT      (MEM_DATA_7       ), // 
    .MEM_DATA_8_INOUT      (MEM_DATA_8       ), // 
    .MEM_DATA_9_INOUT      (MEM_DATA_9       ), // 
    .MEM_DATA_10_INOUT     (MEM_DATA_10      ), // 
    .MEM_DATA_11_INOUT     (MEM_DATA_11      ), // 
    .MEM_DATA_12_INOUT     (MEM_DATA_12      ), // 
    .MEM_DATA_13_INOUT     (MEM_DATA_13      ), // 
    .MEM_DATA_14_INOUT     (MEM_DATA_14      ), // 
    .MEM_DATA_15_INOUT     (MEM_DATA_15      ), //
    .MEM_OE_OUT            (MEM_OE           ), // 
    .MEM_WR_OUT            (MEM_WR           ), //
    .PS2_CLK_INOUT         (PS2_CLK          ), // 
    .PS2_DATA_INOUT        (PS2_DATA         ), //
    .RAM_ADV_OUT           (RAM_ADV          ), // 
    .RAM_CLK_OUT           (RAM_CLK          ), // 
    .RAM_CRE_OUT           (RAM_CRE          ), // 
    .RAM_CS_OUT            (RAM_CS           ), // 
    .RAM_LB_OUT            (RAM_LB           ), // 
    .RAM_UB_OUT            (RAM_UB           ), // 
    .RAM_WAIT_IN           (RAM_WAIT         ), //
    .RS232_RX_IN           (RS232_TX         ), // Loop the UART data back .. 
    .RS232_TX_INOUT        (RS232_TX         ), //
    .SSEG_AN_0_OUT         (SSEG_AN_0        ), // 
    .SSEG_AN_1_OUT         (SSEG_AN_1        ), // 
    .SSEG_AN_2_OUT         (SSEG_AN_2        ), // 
    .SSEG_AN_3_OUT         (SSEG_AN_3        ), // 
    .SSEG_K_0_OUT          (SSEG_K_0         ), // 
    .SSEG_K_1_OUT          (SSEG_K_1         ), // 
    .SSEG_K_2_OUT          (SSEG_K_2         ), // 
    .SSEG_K_3_OUT          (SSEG_K_3         ), // 
    .SSEG_K_4_OUT          (SSEG_K_4         ), // 
    .SSEG_K_5_OUT          (SSEG_K_5         ), // 
    .SSEG_K_6_OUT          (SSEG_K_6         ), // 
    .SSEG_K_7_OUT          (SSEG_K_7         ), //
    .SW_0_IN               (SW_0             ), // 
    .SW_1_IN               (SW_1             ), // 
    .SW_2_IN               (SW_2             ), // 
    .SW_3_IN               (SW_3             ), // 
    .SW_4_IN               (SW_4             ), // 
    .SW_5_IN               (SW_5             ), // 
    .SW_6_IN               (SW_6             ), // 
    .SW_7_IN               (SW_7             ), //
    .USB_ADDR_0_OUT        (USB_ADDR_0       ), // 
    .USB_ADDR_1_OUT        (USB_ADDR_1       ), // 
    .USB_CLK_IN            (USB_CLK          ), // 
    .USB_DATA_0_INOUT      (USB_DATA_0       ), // 
    .USB_DATA_1_INOUT      (USB_DATA_1       ), // 
    .USB_DATA_2_INOUT      (USB_DATA_2       ), // 
    .USB_DATA_3_INOUT      (USB_DATA_3       ), // 
    .USB_DATA_4_INOUT      (USB_DATA_4       ), // 
    .USB_DATA_5_INOUT      (USB_DATA_5       ), // 
    .USB_DATA_6_INOUT      (USB_DATA_6       ), // 
    .USB_DATA_7_INOUT      (USB_DATA_7       ), // 
    .USB_DIR_IN            (USB_DIR          ), // 
    .USB_FLAG_IN           (USB_FLAG         ), // 
    .USB_MODE_IN           (USB_MODE         ), // 
    .USB_OE_OUT            (USB_OE           ), // 
    .USB_PKTEND_OUT        (USB_PKTEND       ), // 
    .USB_WR_OUT            (USB_WR           ), //
    .VGA_BLUE_0_OUT        (VGA_BLUE_0       ), // 
    .VGA_BLUE_1_OUT        (VGA_BLUE_1       ), // 
    .VGA_GREEN_0_OUT       (VGA_GREEN_0      ), // 
    .VGA_GREEN_1_OUT       (VGA_GREEN_1      ), // 
    .VGA_GREEN_2_OUT       (VGA_GREEN_2      ), // 
    .VGA_HSYNC_OUT         (VGA_HSYNC        ), // 
    .VGA_RED_0_OUT         (VGA_RED_0        ), // 
    .VGA_RED_1_OUT         (VGA_RED_1        ), // 
    .VGA_RED_2_OUT         (VGA_RED_2        ), // 
    .VGA_VSYNC_OUT         (VGA_VSYNC        )  // 
    
    );
    
    
    
    
endmodule // TB_FPGA_TOP