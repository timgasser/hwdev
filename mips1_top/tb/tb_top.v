module TB_TOP ();

   // Testbench for the MIPS1_TOP integration tests. Instantiates the following
   // 1. MIPS1_TOP. Top level of MIPS IP. Includes CPU core, COP0, (COP2), I-Cache, and D-TCM
   // 2. SRAM Slave. Corresponds to the PSX Platform SDRAM, inserts wait states on transactions.
   //    -> Address range is 0x0000_0000 to 0x0020_0000
   // 3. BOOTROM Slave.
   //    -> Address range is 0x1fc0_0000 to 0x1fc8_0000

   // Read in the platform addresses and sizes from this file   
`include "mips1_top_defines.v"
`include "tb_defines.v"
   
   // Clocks and resets
   wire Clk;
   wire Rst;

   // Wishbone signals
   wire [31:0] WbAdr       ;
   wire        WbCyc       ;
   wire        WbStb       ;
   wire        WbWe        ;
   wire [ 3:0] WbSel       ;
   wire [ 2:0] WbCti       ;
   wire [ 1:0] WbBte       ;

   wire        WbAck       ;
   wire        WbStall     ;
   wire        WbErr       ;

   wire [31:0] WbDatRd     ; 
   wire [31:0] WbDatWr     ;


   // Hardware interrupts. 
   wire [5:0]  HwIrq = 6'd0;
   
   // Generate clocks and resets
   CLK_RST_GEN
      #(.CLK_HALF_PERIOD (5) // 100MHz clock
	)
   clk_rst_gen
      (
       .CLK_OUT   (Clk   ),
       .RST_OUT   (Rst   )
       );

   TESTCASE testcase ();
   
   // MIPS1 top-level
   MIPS1_TOP  mips1_top
      (
       .CLK            (Clk         ),
       .RST_SYNC       (Rst         ),
      
       .WB_ADR_OUT     (WbAdr       ),
       .WB_CYC_OUT     (WbCyc       ),
       .WB_STB_OUT     (WbStb       ),
       .WB_WE_OUT      (WbWe        ),
       .WB_SEL_OUT     (WbSel       ),
       .WB_CTI_OUT     (WbCti       ),
       .WB_BTE_OUT     (WbBte       ),
      
       .WB_ACK_IN      (WbAck       ),
       .WB_STALL_IN    (WbStall     ),
       .WB_ERR_IN      (WbErr       ),
      
       .WB_DAT_RD_IN   (WbDatRd     ), 
       .WB_DAT_WR_OUT  (WbDatWr     ),
      
       .HW_IRQ_IN      (HwIrq       )  
      
       );


   WB_SLAVE_BFM 
      #(.VERBOSE     (0),
	.READ_ONLY   (0),
	.MEM_BASE    (32'h0000_0000 ),
	.MEM_SIZE_P2 (21), // 2MB
	.MAX_LATENCY (4)
	)
   wb_slave_bfm_platform_ram
      (
       .CLK                   (Clk  ),
       .RST_SYNC              (Rst  ),
      
       .WB_ADR_IN      (WbAdr        ),
       .WB_CYC_IN      (WbCyc        ),
       .WB_STB_IN      (WbStb        ),
       .WB_WE_IN       (WbWe         ),
       .WB_SEL_IN      (WbSel        ),
       .WB_CTI_IN      (WbCti        ),
       .WB_BTE_IN      (WbBte        ),
      
       .WB_ACK_OUT     (WbAck        ),
       .WB_STALL_OUT   (WbStall      ),
       .WB_ERR_OUT     (WbErr        ),
      
       .WB_DAT_RD_OUT  (WbDatRd      ),
       .WB_DAT_WR_IN   (WbDatWr      )
      
       );


   // todo ! Add a bootrom test here
   

   

endmodule
