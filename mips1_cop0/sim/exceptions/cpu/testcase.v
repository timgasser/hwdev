module TESTCASE ();

`include "tb_defines.v"   

     integer progLoop = 0;
     integer regLoop = 0;
     integer regFile;
      

   // **************************** Main sequencer for test *************************
   // Do all the initialisation and checking here. Might be worth putting in separate module later..
   initial
      begin : main_test
	 
	 
	 // Initialise program code BFM
	 
	 $readmemh ("testcase.hex", `TB.inst_wb_slave_bfm.MemArray);
	 
	 // Wait for the end of reset
	 while (`RST)
	    @(posedge `CLK);

	 $display("[INFO ] Out of reset at time %t", $time);
	 
	 // Wait for a data write
	 while (!(`TB.DATA_CYC && `TB.DATA_STB && (32'h0000_0000 == `TB.DATA_ADR)))
	    @(posedge `TB.Clk);

	 $display("[INFO ] Detected data write, checking value at time %t", $time);
	 
	 if (32'd0 == `TB.DATA_DAT_WR) 
	 begin
	    $display("");
	    $display("[PASS ] TEST PASSED at time %t", $time);
	    $display("");
	 end
	 else
	 begin
	    $display("");
	    $display("[FAIL ] TEST FAILED with %d errors at time %t", `TB.DATA_DAT_WR, $time);
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
