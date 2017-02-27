/* INSERT MODULE HEADER */




/*****************************************************************************/

// todo ! These are in the global namespace, move to a package ..


module TB_TOP ();

   import CPU_CORE_MONITOR_PKG::regWriteEvent;
   import CPU_CORE_MONITOR_PKG::dataEvent;
   
   
  
// `define TESTSTR "code.hex"
   // Use queues to handle the predicted actions the CPU should be taking.


// `include "cpu_defs.v"

   
   parameter CLK_HALF_PERIOD = 5;  // 100MHz clock
   parameter RST_SYNC_TIME   = (3 * CLK_HALF_PERIOD) + 1; // reset asserted for this long

   // Wire definitions
   reg Clk;
   reg RstSync;


     // Wishbone interface (Instructions)
    wire    [31:0] INST_ADR         ;
    wire           INST_CYC         ;
    wire           INST_STB         ;
    wire           INST_WE          ;
    wire    [ 3:0] INST_SEL         ;
    wire    [ 2:0] INST_CTI         ;
    wire    [ 1:0] INST_BTE         ;
    wire           INST_ACK         ;
    wire           INST_STALL       ; 
    wire           INST_ERR         ;
    wire    [31:0] INST_DAT_RD      ;
    wire    [31:0] INST_DAT_WR      ;
    
   // Wishbone interface (Data)
    wire    [31:0] DATA_ADR         ;
    wire           DATA_CYC         ;
    wire           DATA_STB         ;
    wire           DATA_WE          ;
    wire    [ 3:0] DATA_SEL         ;
    wire    [ 2:0] DATA_CTI         ;
    wire    [ 1:0] DATA_BTE         ;
    wire           DATA_ACK         ;
    wire           DATA_STALL       ; 
    wire           DATA_ERR         ;
    wire    [31:0] DATA_DAT_RD      ;
    wire    [31:0] DATA_DAT_WR      ;
   
   wire            CORE_MONITOR_ERROR;
   
    // Co-processor 0 interface
    wire          COP0_INST_EN         ;
    wire    [4:0] COP0_INST            ;

    wire          COP0_RD_EN          ;
//    wire          COP0_RD_ACK          ;
    wire          COP0_RD_CTRL_SEL     ;
    wire    [4:0] COP0_RD_SEL          ;
    wire   [31:0] COP0_RD_DATA         ;

    wire          COP0_WR_EN           ;
    wire          COP0_WR_CTRL_SEL     ;
    wire    [4:0] COP0_WR_SEL          ;
    wire   [31:0] COP0_WR_DATA         ;

//    wire    [1:0] SW_IRQ               ;
    wire    [5:0] HW_IRQ               = 6'b000000;
    wire          COUNT_IRQ            ; 

    wire    [3:0] COP_USABLE           ; // 

    wire   	  COP0_INT             ; //
    
    wire          CORE_EXC_EN          ;
    wire    [1:0] CORE_EXC_CE          ;
    wire    [4:0] CORE_EXC_CODE        ;
    wire          CORE_EXC_BD          ;
    wire   [31:0] CORE_EXC_EPC         ;
    wire   [31:0] CORE_EXC_BADVA       ;
    wire   [31:0] CORE_EXC_VECTOR      ;

    wire          CACHE_ISO            ;
    wire          CACHE_SWAP           ;
    wire          CACHE_MISS           ;


   // **************************** Reset and Clock Gen *************************
   //
   initial
     begin
        Clk = 1'b0;
        RstSync = 1'b1;
        #RST_SYNC_TIME  RstSync = 1'b0;
     end

   always #CLK_HALF_PERIOD Clk = !Clk;
   
   // *************************************************************************

   // **************************** Watchdog  *************************
   //
   initial
     begin
	 integer regFile;
	 integer regLoop;

        #10_000;
	
	$display("[FAIL ] Watchdog timeout at time %t", $time);
	$display("[INFO ] Dumping register and memory hex files at time $t", $time);
	
	$writememh("inst_mem_dump.hex", inst_wb_slave_bfm.MemArray);
	$writememh("data_mem_dump.hex", data_wb_slave_bfm.MemArray);

	// Dump out all the registers 
	regFile = $fopen("regfile_dump.hex", "w");
	for (regLoop = 0 ; regLoop < 32 ; regLoop = regLoop + 1)
	begin
	   $fwrite(regFile, "%h\n", cpu_core.RegArray[regLoop]);
	end
	$fwrite(regFile, "%h\n", cpu_core.LoVal);
	$fwrite(regFile, "%h\n", cpu_core.HiVal);
	$fclose (regFile);

	$finish();
	
     end

  
   // *************************************************************************

   // **************************** Test specific testcase  *************************
   TESTCASE testcase();
   // *************************************************************************


   // **************************** Main sequencer for test *************************
   // Do all the initialisation and checking here. Might be worth putting in separate module later..
   initial
      begin : main_test

	 integer regFile;
	 integer regLoop;

	 int 	 flushCnt = 0;
	 
	 integer progLoop = 0;
	 
	 
 	 // Initialise program code BFM
	 
	 $readmemh ("testcase.hex", inst_wb_slave_bfm.MemArray);
	 

	 // Wait for the end of reset
	 while (RstSync)
	    @(posedge Clk);

	 $display("[INFO ] Out of reset at time %t", $time);
	 
	 // Wait for a data write
	 while (!(INST_CYC && INST_STB && INST_ACK && ((32'hxxxx_xxxx === INST_DAT_RD) || (32'h0000_000d === INST_DAT_RD))))
	    @(posedge Clk);

	 $display("[INFO ] Detected out-of-range instruction read .. flushing testbench queues at time %t", $time);
	 $display("[INFO ] INST Queue size = %d", cpu_core_monitor.pcQueue.size());
	 $display("[INFO ] REGS Queue size = %d", cpu_core_monitor.regQueue.size());
	 $display("[INFO ] DATA Queue size = %d", cpu_core_monitor.dataQueue.size());
	 $display("[INFO ] Lo/Hi Queue size = %d", cpu_core_monitor.loQueue.size() + cpu_core_monitor.hiQueue.size());

	 while (  (   (cpu_core_monitor.pcQueue.size()   > 0)
	              || (cpu_core_monitor.regQueue.size()  > 0)
	              || (cpu_core_monitor.dataQueue.size() > 0)
	              || (cpu_core_monitor.loQueue.size() > 0)
	              || (cpu_core_monitor.hiQueue.size() > 0)
		      )
		  && (flushCnt < 35) // Longest instruction could take 32 cycles for div / mult
		  )
	 begin
	    //	 $write(".");
	    @(posedge Clk);
	    flushCnt++;
	 end
	 
	 // repeat (10)
	 //    @(posedge Clk);

	 $display("[INFO ] Flush counter expired, checking queues");
	 $display("[INFO ] INST Queue size = %d", cpu_core_monitor.pcQueue.size());
	 $display("[INFO ] REGS Queue size = %d", cpu_core_monitor.regQueue.size());
	 $display("[INFO ] DATA Queue size = %d", cpu_core_monitor.dataQueue.size());
	 $display("[INFO ] Lo/Hi Queue size = %d", cpu_core_monitor.loQueue.size() + cpu_core_monitor.hiQueue.size());

	 if (     (cpu_core_monitor.pcQueue.size()   > 0)
		  || (cpu_core_monitor.regQueue.size()  > 0)
		  || (cpu_core_monitor.dataQueue.size() > 0)
		  || (cpu_core_monitor.loQueue.size() > 0)
		  || (cpu_core_monitor.hiQueue.size() > 0)
		  )
	 begin
	    $display("[ERROR] Remaining queue entries after pipeline flushed");
	 end
	 
	 $display("[INFO ] Dumping register and memory hex files at time $t", $time);
	 
	 $writememh("inst_mem_dump.hex", inst_wb_slave_bfm.MemArray);
	 $writememh("data_mem_dump.hex", data_wb_slave_bfm.MemArray);

	 // Dump out all the registers 
	 regFile = $fopen("regfile_dump.hex", "w");
	 for (regLoop = 0 ; regLoop < 32 ; regLoop = regLoop + 1)
	 begin
	    $fwrite(regFile, "%h\n", cpu_core.RegArray[regLoop]);
	 end
	 $fwrite(regFile, "%h\n", cpu_core.LoVal);
	 $fwrite(regFile, "%h\n", cpu_core.HiVal);
	 $fclose (regFile);

         if (CORE_MONITOR_ERROR)
         begin
   	    $display("[FAIL ] Test FAILED !");
         end
         else
         begin
	    $display("[PASS ] Test PASSED !");            
         end
         
         // cpuEnd();
	 $finish();
	 
      end
   
   // *************************************************************************



     
   // **************************** Instruction BFM *************************
   parameter IMEM_SIZE_P2 = 10;
   
   WB_SLAVE_BFM 
  #(.VERBOSE     (0),
    .READ_ONLY   (1),
    .MEM_BASE    (32'h0000_0000),
    .MEM_SIZE_P2 (IMEM_SIZE_P2),
    .MAX_LATENCY (4),
    .ADDR_LIMIT  (1)
 //   .INIT_FILE   ("/home/tim/projects/hwdev/r4300i/sim/bfm_test/inst.hex"),
 //   .INIT_EN     (1)
    )
   inst_wb_slave_bfm
   (
    .CLK               	    (Clk),
    .RST_SYNC          	    (RstSync),
      
    // Wishbone interface
    .WB_ADR_IN      ({ {(32 - IMEM_SIZE_P2){1'b0}} , INST_ADR[IMEM_SIZE_P2-1:0]}), // Truncate the address to the size of the memory
    .WB_CYC_IN      (INST_CYC    ), 
    .WB_STB_IN      (INST_STB    ),
    .WB_WE_IN       (INST_WE     ),     
    .WB_SEL_IN      (INST_SEL    ),
    .WB_CTI_IN      (INST_CTI    ),
    .WB_BTE_IN      (INST_BTE    ),  
    .WB_STALL_OUT   (INST_STALL  ),
    .WB_ACK_OUT     (INST_ACK    ),
    .WB_ERR_OUT     (INST_ERR    ),
    .WB_DAT_RD_OUT  (INST_DAT_RD ), 
    .WB_DAT_WR_IN   (INST_DAT_WR )   
    );
   // *************************************************************************

   // **************************** Data BFM *************************
   parameter DMEM_SIZE_P2 = 10;

   WB_SLAVE_BFM 
  #(.VERBOSE     (0),
    .READ_ONLY   (0),
    .MEM_BASE    (32'h0000_0000),
    .MEM_SIZE_P2 (DMEM_SIZE_P2),
    .MAX_LATENCY (4),
    .ADDR_LIMIT  (1)
//    .INIT_FILE   ("dontcare.hex"),
//    .INIT_EN     (0)
    )
   data_wb_slave_bfm
   (
    .CLK               	    (Clk),
    .RST_SYNC          	    (RstSync),
      
    // Wishbone interface
    .WB_ADR_IN      ({ {(32 - IMEM_SIZE_P2){1'b0}} , DATA_ADR[IMEM_SIZE_P2-1:0]}),  // Truncate the address to the size of the memory
    .WB_CYC_IN      (DATA_CYC      ), 
    .WB_STB_IN      (DATA_STB      ), 
    .WB_WE_IN       (DATA_WE       ), 
    .WB_SEL_IN      (DATA_SEL      ),
    .WB_CTI_IN      (DATA_CTI      ),
    .WB_BTE_IN      (DATA_BTE      ),
    .WB_STALL_OUT   (DATA_STALL    ),
    .WB_ACK_OUT     (DATA_ACK      ),
    .WB_ERR_OUT     (DATA_ERR      ),
    .WB_DAT_RD_OUT  (DATA_DAT_RD   ), 
    .WB_DAT_WR_IN   (DATA_DAT_WR   )   
    );
   // *************************************************************************


      
   // ******************************* MODULE: DUT *****************************
   // 
   CPU_CORE 
  #(.PC_RST_VALUE  (32'h0000_0000))
      cpu_core
   (
    .CLK               	    (Clk),
    .RST_SYNC          	    (RstSync),

    // todo : connect these up properly 
    .CORE_INST_ADR_OUT      (INST_ADR      ),
    .CORE_INST_CYC_OUT      (INST_CYC      ),
    .CORE_INST_STB_OUT      (INST_STB      ),
    .CORE_INST_WE_OUT       (INST_WE       ),
    .CORE_INST_SEL_OUT      (INST_SEL      ),
    .CORE_INST_CTI_OUT      (INST_CTI      ),
    .CORE_INST_BTE_OUT      (INST_BTE      ),
    .CORE_INST_ACK_IN       (INST_ACK      ),
    .CORE_INST_STALL_IN     (INST_STALL    ),
    .CORE_INST_ERR_IN       (INST_ERR      ),
    .CORE_INST_DAT_RD_IN    (INST_DAT_RD   ),
    .CORE_INST_DAT_WR_OUT   (INST_DAT_WR   ),
    
    .CORE_DATA_ADR_OUT      (DATA_ADR      ),
    .CORE_DATA_CYC_OUT      (DATA_CYC      ),
    .CORE_DATA_STB_OUT      (DATA_STB      ),
    .CORE_DATA_WE_OUT       (DATA_WE       ),
    .CORE_DATA_SEL_OUT      (DATA_SEL      ),
    .CORE_DATA_CTI_OUT      (DATA_CTI      ),
    .CORE_DATA_BTE_OUT      (DATA_BTE      ),
    .CORE_DATA_ACK_IN       (DATA_ACK      ),
    .CORE_DATA_STALL_IN     (DATA_STALL    ),
    .CORE_DATA_ERR_IN       (DATA_ERR      ),
    .CORE_DATA_DAT_RD_IN    (DATA_DAT_RD   ),
    .CORE_DATA_DAT_WR_OUT   (DATA_DAT_WR   ),

    // Co-processor 0 interface - tied off for now
    .COP0_INST_EN_OUT       (COP0_INST_EN       ), //        
    .COP0_INST_OUT          (COP0_INST          ), //  [4:0] 
    			                          
    .COP0_RD_EN_OUT         (COP0_RD_EN         ), //        
//    .COP0_RD_ACK_IN         (COP0_RD_ACK        ), //        
    .COP0_RD_CTRL_SEL_OUT   (COP0_RD_CTRL_SEL   ), //        
    .COP0_RD_SEL_OUT        (COP0_RD_SEL        ), //  [4:0] 
    .COP0_RD_DATA_IN        (COP0_RD_DATA       ), // [31:0] 
    			                          
    .COP0_WR_EN_OUT         (COP0_WR_EN         ), //        
    .COP0_WR_CTRL_SEL_OUT   (COP0_WR_CTRL_SEL   ), //        
    .COP0_WR_SEL_OUT        (COP0_WR_SEL        ), //  [4:0] 
    .COP0_WR_DATA_OUT       (COP0_WR_DATA       ), // [31:0] 
    			                          
    .COP_USABLE_IN          (COP_USABLE         ), //  [3:0] 
    			                          
    .COP0_INT_IN            (COP0_INT           ), //
    			                       
    .CORE_EXC_EN_OUT        (CORE_EXC_EN        ), //
    .CORE_EXC_CE_OUT        (CORE_EXC_CE        ), // 
    .CORE_EXC_CODE_OUT      (CORE_EXC_CODE      ), //  [4:0] 
    .CORE_EXC_BD_OUT        (CORE_EXC_BD        ), //        
    .CORE_EXC_EPC_OUT       (CORE_EXC_EPC       ), // [31:0] 
    .CORE_EXC_BADVA_OUT     (CORE_EXC_BADVA     ), // [31:0] 
    .CORE_EXC_VECTOR_IN     (CORE_EXC_VECTOR    )  // [31:0] 


    );
   // *************************************************************************





   // *************************************************************************

COP0 cop0
   (
    .CLK               	    (Clk),
    .RST_SYNC          	    (RstSync),

    .COP0_INST_EN_IN      (COP0_INST_EN       ),
    .COP0_INST_IN         (COP0_INST          ),
			                   
    .COP0_RD_EN_IN        (COP0_RD_EN         ),
//    .COP0_RD_ACK_OUT      (COP0_RD_ACK        ),
    .COP0_RD_CTRL_SEL_IN  (COP0_RD_CTRL_SEL   ),
    .COP0_RD_SEL_IN       (COP0_RD_SEL        ),
    .COP0_RD_DATA_OUT     (COP0_RD_DATA       ),
			                   
    .COP0_WR_EN_IN        (COP0_WR_EN         ),
    .COP0_WR_CTRL_SEL_IN  (COP0_WR_CTRL_SEL   ),
    .COP0_WR_SEL_IN       (COP0_WR_SEL        ),
    .COP0_WR_DATA_IN      (COP0_WR_DATA       ),
			                   
//    .SW_IRQ_OUT           (SW_IRQ             ),
    .HW_IRQ_IN            (HW_IRQ             ),
    .COUNT_IRQ_OUT        (COUNT_IRQ          ), 
			                   
    .COP_USABLE_OUT       (COP_USABLE         ), 
			                   
    .COP0_INT_OUT         (COP0_INT           ),
    			                   
    .CORE_EXC_EN_IN       (CORE_EXC_EN        ),
    .CORE_EXC_CE_IN       (CORE_EXC_CE        ),
    .CORE_EXC_CODE_IN     (CORE_EXC_CODE      ),
    .CORE_EXC_BD_IN       (CORE_EXC_BD        ),
    .CORE_EXC_EPC_IN      (CORE_EXC_EPC       ),
    .CORE_EXC_BADVA_IN    (CORE_EXC_BADVA     ),
    .CORE_EXC_VECTOR_OUT  (CORE_EXC_VECTOR    ),
			                   
    .CACHE_ISO_OUT        (CACHE_ISO          ),
    .CACHE_SWAP_OUT       (CACHE_SWAP         ),
    .CACHE_MISS_IN        (CACHE_MISS         ) 

    );

   // *************************************************************************



   // ******************************* MODULE: MODEL *****************************
   // 
   CPU_CORE_MONITOR cpu_core_monitor
   (
    .CLK               	    (Clk),
    .RST_SYNC          	    (RstSync),

    .CORE_INST_ADR_IN       (INST_ADR      ),
    .CORE_INST_CYC_IN       (INST_CYC      ),
    .CORE_INST_STB_IN       (INST_STB      ),
    .CORE_INST_WE_IN        (INST_WE       ),
    .CORE_INST_SEL_IN       (INST_SEL      ),
    .CORE_INST_CTI_IN       (INST_CTI      ),
    .CORE_INST_BTE_IN       (INST_BTE      ),
    .CORE_INST_ACK_IN       (INST_ACK      ),
    .CORE_INST_STALL_IN     (INST_STALL    ),
    .CORE_INST_ERR_IN       (INST_ERR      ),
    .CORE_INST_DAT_RD_IN    (INST_DAT_RD   ),
    .CORE_INST_DAT_WR_IN    (INST_DAT_WR   ),
    
    .CORE_DATA_ADR_IN       (DATA_ADR      ),
    .CORE_DATA_CYC_IN       (DATA_CYC      ),
    .CORE_DATA_STB_IN       (DATA_STB      ),
    .CORE_DATA_WE_IN        (DATA_WE       ),
    .CORE_DATA_SEL_IN       (DATA_SEL      ),
    .CORE_DATA_CTI_IN       (DATA_CTI      ),
    .CORE_DATA_BTE_IN       (DATA_BTE      ),
    .CORE_DATA_ACK_IN       (DATA_ACK      ),
    .CORE_DATA_STALL_IN     (DATA_STALL    ),
    .CORE_DATA_ERR_IN       (DATA_ERR      ),
    .CORE_DATA_DAT_RD_IN    (DATA_DAT_RD   ),
    .CORE_DATA_DAT_WR_IN    (DATA_DAT_WR   ),

    .CORE_MONITOR_ERROR_OUT (CORE_MONITOR_ERROR)

    );
   // *************************************************************************





endmodule
/*****************************************************************************/
