// This test bench has a 
// - WB Master (with burst accesses)
// - SDRAM_CONTROLLER
// - Cellular RAM model from Micron to represent the RAM on the board

module SDRAM_CONTROLLER_TB ();

   parameter CLK_HALF_PERIOD = 16; // 16ns ~ 33MHz
   
   // Wishbone Interface
   wire [31:0]  WbAdr   ;
   wire 	WbCyc   ;
   wire 	WbStb   ;
   wire 	WbWe    ;
   wire [ 3:0] 	WbSel   ;
   wire [ 2:0] 	WbCti   ;
   wire [ 1:0] 	WbBte   ;
   
   wire 	WbAck   ; 
   wire 	WbStall ;
   wire 	WbErr   ;
   
   wire [31:0] 	WbWrDat ;
   wire [31:0] 	WbRdDat ;

   // SDRAM Interface
   wire  [23:1]   SdrAddr   ;
   wire  	  SdrCre    ;
   wire  	  SdrAdvb   ;
   wire  	  SdrCeb    ;
   wire  	  SdrOeb    ;
   wire  	  SdrWeb    ;
   wire  	  SdrWait   ;
   wire  	  SdrLbb    ;
   wire  	  SdrUbb    ;
     
   wire [15:0] 	  SdrData   ; 
   
   // Clock and reset block
   reg 		Clk       ;
   wire		ClkDly    ;
   reg 		Rst       ;
   wire 	ClkSdrEn  ;

   // Delay the clock to the SDRAM by a quarter clock cycle
   assign  # (CLK_HALF_PERIOD) ClkDly = Clk;  
   
   // **************************** Reset and Clock Gen *************************
   CLK_RST_GEN 
      #(.CLK_HALF_PERIOD (CLK_HALF_PERIOD))
   clk_rst_gen
      (.CLK_OUT  (Clk),
       .RST_OUT  (Rst)
       );
   
   // **************************** Testcase *************************
   TESTCASE testcase();
   
   // **************************** Wishbone Master *************************
   
   WB_MASTER_BFM wb_master_bfm
      (
    .CLK            (Clk      ),
    .RST_SYNC       (Rst      ),
    
    .WB_ADR_OUT     (WbAdr    ), 
    .WB_CYC_OUT     (WbCyc    ), 
    .WB_STB_OUT     (WbStb    ), 
    .WB_WE_OUT      (WbWe     ), 
    .WB_SEL_OUT     (WbSel    ), 
    .WB_CTI_OUT     (WbCti    ), 
    .WB_BTE_OUT     (WbBte    ), 

    .WB_ACK_IN      (WbAck    ), 
    .WB_STALL_IN    (WbStall  ), 
    .WB_ERR_IN      (WbErr    ), 
		             
    .WB_DAT_RD_IN   (WbRdDat  ), 
    .WB_DAT_WR_OUT  (WbWrDat  )  
    
    );


   SDRAM_CONTROLLER
   #(
     .WBA   (32'h0000_0000), // Wishbone Base Address
     .WS_P2 (24)             // Wishbone size as power-of-2 bytes
     )
   sdram_controller
      (
       .CLK              (Clk      ),
       .EN               (1'b1     ),
       .RST_SYNC         (1'b0     ),
       .RST_ASYNC        (Rst      ),
       .CLK_SDR_EN_OUT   (ClkSdrEn ),
       
       .WB_ADR_IN        (WbAdr    ),
       .WB_CYC_IN        (WbCyc    ),
       .WB_STB_IN        (WbStb    ),
       .WB_WE_IN         (WbWe     ),
       .WB_SEL_IN        (WbSel    ),
       .WB_CTI_IN        (WbCti    ),
       .WB_BTE_IN        (WbBte    ),
       
       .WB_ACK_OUT       (WbAck    ),
       .WB_STALL_OUT     (WbStall  ),
       .WB_ERR_OUT       (WbErr    ),
       
       .WB_WR_DAT_IN     (WbWrDat  ),
       .WB_RD_DAT_OUT    (WbRdDat  ),
      
       .SDR_ADDR_OUT     (SdrAddr  ),
       .SDR_CRE_OUT      (SdrCre   ),
       .SDR_ADVB_OUT     (SdrAdvb  ),
       .SDR_CEB_OUT      (SdrCeb   ),
       .SDR_OEB_OUT      (SdrOeb   ),
       .SDR_WEB_OUT      (SdrWeb   ),
       .SDR_WAIT_IN      (SdrWait  ),
      
       .SDR_LBB_OUT      (SdrLbb   ),
       .SDR_UBB_OUT      (SdrUbb   ),
      
       .SDR_DATA_INOUT   (SdrData  )
      
       );

   cellram cellram_i
      (
       .clk      (ClkDly & ClkSdrEn),
       .adv_n    (SdrAdvb ),
       .cre      (SdrCre  ), 
       .o_wait   (SdrWait ), // output
       .ce_n     (SdrCeb  ),
       .oe_n     (SdrOeb  ),
       .we_n     (SdrWeb  ),
       .lb_n     (SdrLbb  ),
       .ub_n     (SdrUbb  ),
       .addr     (SdrAddr ),
       .dq       (SdrData )  // bi-directional
       ); 

   
endmodule // SDRAM_CONTROLLER_TB
