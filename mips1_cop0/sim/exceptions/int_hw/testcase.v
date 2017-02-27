module TESTCASE ();

`include "tb_defines.v"
   
     integer progLoop = 0;
     integer regLoop = 0;
     integer regFile;
      

   // **************************** Main sequencer for test *************************
   // Do all the initialisation and checking here. Might be worth putting in separate module later..
   initial
      begin : main_test

	 integer intLoop;
	 
	 logic [6:0] intMask = 0;
	 logic [5:0] intMaskFromCpu;
	 
	 // Initialise program code BFM
	 
	 $readmemh ("testcase.hex", `TB.inst_wb_slave_bfm.MemArray);
	 
	 // Wait for the end of reset
	 while (`RST)
	    @(posedge `CLK);

	 $display("[INFO ] Out of reset at time %t", $time);


	 for (intLoop = 0 ; intLoop < 6 ; intLoop++)
	 begin
	    
	    $display("");
	    $display("[INFO ] ***** Testing HW IRQ bit %d at time %t *****", intLoop, $time);

	    // Wait for HW interrupt request
	    $display("");
	    $display("[INFO ] Waiting for a write to 0x10 at time %t", $time);
	    while (! (   `TB.DATA_CYC && `TB.DATA_STB && `TB.DATA_WE 
			 && (32'h0000_0010 == `TB.DATA_ADR)))
	       @(posedge `TB.Clk);

	    // Set HW interrupt
	    intMask = `TB.DATA_DAT_WR[5:0];
	    $display("[INFO ] Data write to 0x10, value is 0x%h at time %t", `TB.DATA_DAT_WR, $time);
	    @(posedge `TB.Clk);
	    $display("[INFO ] Setting interrupt 0x%h at time %t", intMask, $time);
	    force  `TB.HW_IRQ = intMask;
	    
	    // Wait for Code write to 0x04
	    $display("");
	    $display("[INFO ] Waiting for a Code write to 0x04 at time (should be 0) %t", $time);
	    while (! (   `TB.DATA_CYC && `TB.DATA_STB && `TB.DATA_WE  
			 && (32'h0000_0004 == `TB.DATA_ADR)))
	       @(posedge `TB.Clk);
	    $display("[INFO ] Data write to 0x04, value is 0x%h at time %t", `TB.DATA_DAT_WR, $time);
	    if (| `TB.DATA_DAT_WR)
	    begin
	       $display("");
	       $display("[ERROR] Non-zero code value of 0x%h seen, expected 0x00000000 at time %t", `TB.DATA_DAT_WR, $time);
	       $display("");
	       $display("[FAIL ] TEST FAILED at time %t", $time);
	       $display("");
	       $finish();
	    end
	    else
	    begin
	       $display("[INFO ] Interrupt Code of %d seen, matches expected value of 0 at time %t", `TB.DATA_DAT_WR, $time);
	    end // else: !if(intMaskFromCpu != intMask)

	    
	    // Wait for a onehot interrupt mask write to 0x00
	    $display("");
	    $display("[INFO ] Waiting for an IntMask write to 0x00 at time %t", $time);
	    while (! (   `TB.DATA_CYC && `TB.DATA_STB && `TB.DATA_WE  
			 && (32'h0000_0000 == `TB.DATA_ADR)))
	       @(posedge `TB.Clk);
	    
	    intMaskFromCpu = `TB.DATA_DAT_WR[5:0];
	    $display("[INFO ] Data write to 0x00, value is 0x%h at time %t", `TB.DATA_DAT_WR, $time);
	    @(posedge `TB.Clk);
	    
	    if (intMaskFromCpu != intMask)
	    begin
	       $display("");
	       $display("[ERROR] Interrupt mask of 0x%h seen, expected 0x%h at time %t", intMaskFromCpu, intMask, $time);
	       $display("");
	       $display("[FAIL ] TEST FAILED at time %t", $time);
	       $display("");
	       $finish();
	    end
	    else
	    begin
	       $display("[INFO ] Interrupt mask of 0x%h seen, matches expected 0x%h at time %t", intMaskFromCpu, intMask, $time);

	    end // else: !if(intMaskFromCpu != intMask)

	    // Wait for a onehot interrupt mask write to 0x00
	    $display("");
	    $display("[INFO ] Waiting for an IntMask write of 0 to 0x10 to de-assert IRQs at time %t", $time);
	    while (! (   `TB.DATA_CYC && `TB.DATA_STB && `TB.DATA_WE  
			 && (32'h0000_0010 == `TB.DATA_ADR)))
	       @(posedge `TB.Clk);
	    
	    if (| `TB.DATA_DAT_WR)
	    begin
	       $display("[ERROR] Expected Write 0x00 <- 0, saw Write 0x%h <- 0x%h at time %t", `TB.DATA_ADR, `TB.DATA_DAT_WR, $time);
	       $display("");
	       $display("[FAIL ] TEST FAILED at time %t", $time);
	       $display("");
	       $finish();
	    end
	    else
	    begin
	       $display("[INFO ] Data write of 0 to 0x00 seen, de-asserting HW IRQs at time %t", $time);
	       $display("");

	       @(posedge `TB.Clk);

	       release  `TB.HW_IRQ;
	       
	    end // else: !if(intMaskFromCpu != intMask)

	 end // while (| intMask)
	 

	 $display("");
	 $display("[PASS ] TEST PASSED at time %t", $time);
	 $display("");
      

	 $display("INFO: Dumping register and memory hex files at time $t", $time);
	 
	 $writememh("inst_mem_dump.hex", `TB.inst_wb_slave_bfm.MemArray);
	 $writememh("data_mem_dump.hex", `TB.data_wb_slave_bfm.MemArray);

	 // Dump out all the registers 
	 regFile = $fopen("regfile_dump.hex", "w");
	 for (regLoop = 0 ; regLoop < 32 ; regLoop = regLoop + 1)
	 begin
	    $fwrite(regFile, "%h\n", `TB.cpu_core.RegArray[regLoop]);
	 end
	 $fwrite(regFile, "%h\n", `TB.cpu_core.LoVal);
	 $fwrite(regFile, "%h\n", `TB.cpu_core.HiVal);
	 $fclose (regFile);
         
	 $finish();
	 
      end

   // *************************************************************************



   

endmodule // TESTCASE
