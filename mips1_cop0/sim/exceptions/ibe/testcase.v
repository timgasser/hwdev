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
	 
	 // Wait for a data read strobe for address 0x10
	 while (!(   `TB.INST_CYC 
                  && `TB.INST_STB 
                  && !`TB.INST_STALL
                  && (32'hbfc0_0010 == `TB.INST_ADR)))
	    @(posedge `CLK);
	 $display("[INFO ] Instruction Address strobe (0x10) at time %t", $time);

	 @(negedge `CLK);
         
         // When ACK comes back, gate and assert error
         while (!`TB.INST_ACK)
	    @(negedge `CLK);
	 $display("[INFO ] Forcing ERR on negedge ACK at time %t", $time);

	 // Force the error input
	 force `TB.INST_ERR = 1'b1;
	 force `TB.INST_ACK = 1'b0;
	 @(posedge `CLK);
	 #1;
	 release `TB.INST_ERR;
	 release `TB.INST_ACK;

	 $display("[INFO ] Releasing ERR force at time %t", $time);

//	 // Wait for a data read to address 0x10, force an error
	 while (!(`TB.DATA_CYC && `TB.DATA_STB && (32'h0000_0000 == `TB.DATA_ADR)))
	    @(posedge `CLK);

	 $display("[INFO ] Detected data write, checking value at time %t", $time);


	 while (!(   `TB.DATA_CYC 
                  && `TB.DATA_STB
                  && `TB.DATA_WE
                  && (32'h0000_0000 == `TB.DATA_ADR)))
	    @(posedge `CLK);

         
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

	 @(posedge `CLK);
	 @(posedge `CLK);
         
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
