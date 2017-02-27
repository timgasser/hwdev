// PSX Reference top-level. Uses ideal BFMs for ROM, DRAM, and GPU RAM
module TB_TOP ();

`include "psx_mem_map.vh"
`include "tb_defines.v"
   
   // Clocks and resets
   wire Clk;
   wire Rst;


   wire [31:0] WbSysAdr         ;
   wire        WbSysRomCyc      ;
   wire        WbSysRomStb      ;
   wire        WbSysDramCyc     ;
   wire        WbSysDramStb     ;   
   wire        WbSysWe          ;
   wire [ 3:0] WbSysSel         ;
   wire [ 2:0] WbSysCti         ;
   wire [ 1:0] WbSysBte         ;
   
   wire        WbSysRomAck      ;
   wire        WbSysRomStall    ;
   wire        WbSysRomErr      ;   
   wire        WbSysDramAck     ;
   wire        WbSysDramStall   ;
   wire        WbSysDramErr     ;

   wire [31:0] WbSysDatRomRd    ;
   wire [31:0] WbSysDatDramRd   ;
   wire [31:0] WbSysDatWr       ;
   
   wire [31:0] WbGpuAdr         ;
   wire        WbGpuCyc         ;
   wire        WbGpuStb         ;
   wire        WbGpuWe          ;
   wire [ 3:0] WbGpuSel         ;
   wire [ 2:0] WbGpuCti         ;
   wire [ 1:0] WbGpuBte         ;

   wire        WbGpuAck         ;
   wire        WbGpuStall       ;
   wire        WbGpuErr         ;

   wire [31:0] WbGpuDatRd       ;
   wire [31:0] WbGpuDatWr       ;
   

// Don't instantiate the instruction trace or C model in the BFM sims   
`ifndef CPU_CORE_BFM
   // CPU Core Monitor
   MIPS1_CORE_MONITOR 
      #(.VERBOSE (0))
      mips1_core_monitor ();


//      // CPU Instruction Trace
//   WB_SLAVE_TRACE
//   #(.FILE      ("cpu_inst_trace.trc"),
//     .VERBOSE   ( 0)  
//     ) 
//   wb_slave_trace_cpu_inst
//   (
//    .CLK            (Clk      ),
//    .RST_SYNC       (Rst      ),
//    .WB_ADR_IN      (`CPU.CORE_INST_ADR_OUT     ),
//    .WB_CYC_IN      (`CPU.CORE_INST_CYC_OUT     ),
//    .WB_STB_IN      (`CPU.CORE_INST_STB_OUT     ),
//    .WB_WE_IN       (`CPU.CORE_INST_WE_OUT      ),
//    .WB_SEL_IN      (`CPU.CORE_INST_SEL_OUT     ),
//    .WB_CTI_IN      (`CPU.CORE_INST_CTI_OUT     ),
//    .WB_BTE_IN      (`CPU.CORE_INST_BTE_OUT     ),
//    .WB_STALL_IN    (`CPU.CORE_INST_STALL_IN    ),
//    .WB_ACK_IN      (`CPU.CORE_INST_ACK_IN      ),
//    .WB_ERR_IN      (`CPU.CORE_INST_ERR_IN      ),
//    .WB_DAT_RD_IN   (`CPU.CORE_INST_DAT_RD_IN   ),
//    .WB_DAT_WR_IN   (`CPU.CORE_INST_DAT_WR_OUT  ) 
//    );
//
   
`endif      


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
   
   // Reference PSX instantiation
   PSX_TOP psx_top
      (

       .CLK                      (Clk      ),
       .EN                       (1'b1     ),
       .RST_SYNC                 (Rst      ),
       .RST_ASYNC                (Rst      ),

       .WB_SYS_ADR_OUT           (WbSysAdr          ),
       .WB_SYS_ROM_CYC_OUT       (WbSysRomCyc       ),
       .WB_SYS_ROM_STB_OUT       (WbSysRomStb       ),
       .WB_SYS_DRAM_CYC_OUT      (WbSysDramCyc      ),
       .WB_SYS_DRAM_STB_OUT      (WbSysDramStb      ),
       .WB_SYS_WE_OUT            (WbSysWe           ),
       .WB_SYS_SEL_OUT           (WbSysSel          ),
       .WB_SYS_CTI_OUT           (WbSysCti          ),
       .WB_SYS_BTE_OUT           (WbSysBte          ),
      
       .WB_SYS_ROM_ACK_IN        (WbSysRomAck       ),
       .WB_SYS_ROM_STALL_IN      (WbSysRomStall     ),
       .WB_SYS_ROM_ERR_IN        (WbSysRomErr       ),
       .WB_SYS_DRAM_ACK_IN       (WbSysDramAck      ),
       .WB_SYS_DRAM_STALL_IN     (WbSysDramStall    ),
       .WB_SYS_DRAM_ERR_IN       (WbSysDramErr      ),

       .WB_SYS_DAT_ROM_RD_IN     (WbSysDatRomRd    ),
       .WB_SYS_DAT_DRAM_RD_IN    (WbSysDatDramRd   ),
       .WB_SYS_DAT_WR_OUT        (WbSysDatWr       ),
      
       .WB_GPU_ADR_OUT           (WbGpuAdr     ),
       .WB_GPU_CYC_OUT           (WbGpuCyc     ),
       .WB_GPU_STB_OUT           (WbGpuStb     ),
       .WB_GPU_WE_OUT            (WbGpuWe      ),
       .WB_GPU_SEL_OUT           (WbGpuSel     ),
       .WB_GPU_CTI_OUT           (WbGpuCti     ),
       .WB_GPU_BTE_OUT           (WbGpuBte     ),
      
       .WB_GPU_ACK_IN            (WbGpuAck     ),
       .WB_GPU_STALL_IN          (WbGpuStall   ),
       .WB_GPU_ERR_IN            (WbGpuErr     ),
      
       .WB_GPU_DAT_RD_IN         (WbGpuDatRd   ),
       .WB_GPU_DAT_WR_OUT        (WbGpuDatWr   )
      
       );


   // ROM instantiation. 512kB memory, read-only, single cycle response   
   WB_SLAVE_BFM 
      #(
	.VERBOSE     (0),
	.READ_ONLY   (1),
	.MEM_BASE    (32'h1fc0_0000),
	.MEM_SIZE_P2 (ROM_SIZE_P2), 
	.MIN_LATENCY (0),
	.MAX_LATENCY (4),
	.ADDR_LIMIT  (1) 
	)
   wb_slave_bfm_rom
      (
       .CLK            (Clk            ),
       .RST_SYNC       (Rst            ),
      
       .WB_ADR_IN      (WbSysAdr       ),
       .WB_CYC_IN      (WbSysRomCyc    ),
       .WB_STB_IN      (WbSysRomStb    ),
       .WB_WE_IN       (WbSysWe        ),
       .WB_SEL_IN      (WbSysSel       ),
       .WB_CTI_IN      (WbSysCti       ),
       .WB_BTE_IN      (WbSysBte       ),
       .WB_STALL_OUT   (WbSysRomStall  ),
       .WB_ACK_OUT     (WbSysRomAck    ),
       .WB_ERR_OUT     (WbSysRomErr    ),
       .WB_DAT_RD_OUT  (WbSysDatRomRd  ),
       .WB_DAT_WR_IN   (WbSysDatWr     )   
      
       );

   // DRAM instantiation. 2MB memory, read-write, variable cycle response   
   WB_SLAVE_BFM 
      #(// .CHECK_SEL   (0), // Allow any combination of byte lane enables
	.VERBOSE     (0),
	.READ_ONLY   (0),
	.MEM_BASE    (32'h0000_0000),
	.MEM_SIZE_P2 (DRAM_SIZE_P2), 
	.MAX_LATENCY (4),
	.ADDR_LIMIT  (1) 
	)
   wb_slave_bfm_dram
      (
       .CLK            (Clk             ),
       .RST_SYNC       (Rst             ),
      
       .WB_ADR_IN      (WbSysAdr        ),
       .WB_CYC_IN      (WbSysDramCyc    ),
       .WB_STB_IN      (WbSysDramStb    ),
       .WB_WE_IN       (WbSysWe        	),
       .WB_SEL_IN      (WbSysSel       	),
       .WB_CTI_IN      (WbSysCti       	),
       .WB_BTE_IN      (WbSysBte       	),
       .WB_STALL_OUT   (WbSysDramStall  ),
       .WB_ACK_OUT     (WbSysDramAck    ),
       .WB_ERR_OUT     (WbSysDramErr    ),
       .WB_DAT_RD_OUT  (WbSysDatDramRd  ),
       .WB_DAT_WR_IN   (WbSysDatWr      )   
      
       );


   // GPU local SRAM memory. 1MB memory, read-write, single-cycle response   
   WB_SLAVE_BFM 
      #(
	.VERBOSE     (0),
	.READ_ONLY   (0),
	.MEM_BASE    (32'h0000_0000),
	.MEM_SIZE_P2 (20),
	.MAX_LATENCY (4),
	.ADDR_LIMIT  (1) 
	)
   wb_slave_bfm_gpu_local_ram
      (
       .CLK            (Clk             ),
       .RST_SYNC       (Rst             ),
      
       .WB_ADR_IN      (WbGpuAdr        ),
       .WB_CYC_IN      (WbGpuCyc        ),
       .WB_STB_IN      (WbGpuStb        ),
       .WB_WE_IN       (WbGpuWe        	),
       .WB_SEL_IN      (WbGpuSel       	),
       .WB_CTI_IN      (WbGpuCti       	),
       .WB_BTE_IN      (WbGpuBte       	),
       .WB_STALL_OUT   (WbGpuStall    	),
       .WB_ACK_OUT     (WbGpuAck      	),
       .WB_ERR_OUT     (WbGpuErr      	),
       .WB_DAT_RD_OUT  (WbGpuDatRd    	),
       .WB_DAT_WR_IN   (WbGpuDatWr      )   
       );




endmodule

