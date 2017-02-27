module TESTCASE ();

`include "tb_defines.v"

     integer progLoop = 0;
     integer regLoop = 0;
     integer regFile;
      

   // **************************** Main sequencer for test *************************
   // Do all the initialisation and checking here. Might be worth putting in separate module later..
   initial
      begin : main_test
	 
	 logic [7:0] intMask = 8'b00000001;
         int         testFail = 0;
         
	 // Initialise program code BFM
	 
	 $readmemh ("testcase.hex", `TB.inst_wb_slave_bfm.MemArray);
	 
	 // Wait for the end of reset
	 while (`RST)
	    @(posedge `CLK);

	 $display("[INFO ] Out of reset at time %t", $time);

         while (8'h04 != intMask)
         begin : INT_MASK_LOOP
            
            while (!`TB.COP0_INT)
               @(posedge `TB.Clk);
	    $display("[INFO ] Interrupt seen, waiting for data write to 0x%0x to confirm Status.IntMask at time  %t", intMask, $time);

            while (! (   `TB.DATA_CYC 
		         && `TB.DATA_STB 
		         && `TB.DATA_WE 
		         && (32'h0000_0010 == `TB.DATA_ADR)))
	       @(posedge `TB.Clk);
            

            if (intMask !== `TB.DATA_DAT_WR[7:0])
            begin
               $display("[ERROR] Status.IntMask mismatch, expected = 0x%x, actual = 0x%x at time %t", intMask, `TB.DATA_DAT_WR[7:0], $time);
               testFail++;
            end
            else
            begin
               $display("[INFO ] Status IntMask field write match at time %t", $time);
            end

            // Shift the intmask left by one, ready for next irq
            intMask = {intMask[6:0], 1'b0};

         end
	 
         if (0 == testFail)
         begin
	    $display("");
	    $display("[PASS ] TEST PASSED at time %t", $time);
	    $display("");
         end
         else
         begin
       	    $display("");
	    $display("[FAIL ] TEST FAILED with %d errors at time %t", testFail, $time);
	    $display("");
         end

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
