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

         // The address to the data BFM is truncated. Hijack the data BFM 
         // interface when the address is written for the exception

         // Wait for a data read to address 0x10, force an error
	 while (!(`TB.DATA_CYC && `TB.DATA_STB 
                  && !`TB.DATA_WE && (32'h0000_0010 == `TB.DATA_ADR)))
	    @(negedge `CLK);

	 $display("[INFO ] Detected data read to address 0x10, stalling a couple of cycles and forcing a bus exception at time %t", $time);
         #1;
         force `TB.DATA_STALL = 1'b1;
         force `TB.DATA_ACK   = 1'b0;
         force `TB.DATA_ERR   = 1'b0;

	 @(posedge `CLK);
	 @(posedge `CLK);
         #1;
         force `TB.DATA_STALL = 1'b0;
         force `TB.DATA_ERR = 1'b1;

	 @(posedge `CLK);
         #1;
         force `TB.DATA_ACK = 1'b0;
         force `TB.DATA_ERR = 1'b0;

         // Wait for another address strobe to the data BFM and then release forces
         while (!(`TB.DATA_CYC && `TB.DATA_STB))
	    @(negedge `CLK);

         #1;
    	 $display("[INFO ] Releasing forces on data at time %t", $time);     
         release `TB.DATA_STALL;
         release `TB.DATA_ACK  ;
         release `TB.DATA_ERR  ;
         
	 while (!(`TB.DATA_CYC && `TB.DATA_STB && (32'h0000_0000 == `TB.DATA_ADR)))
	    @(posedge `CLK);

	 $display("[INFO ] Detected data write to 0, checking result at time %t", $time);

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
