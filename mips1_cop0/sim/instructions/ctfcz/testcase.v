module TESTCASE ();

`include "tb_defines.v"

   // A data write of 1 indicates a test passed. A 0 shows a fail ..


   initial
      begin

	 // Load the program into the instruction BFM
	 $display("[INFO ] Loading test into instruction BFM at time %t", $time);
	 $readmemh ("testcase.hex", `TB.inst_wb_slave_bfm.MemArray);

	 // Wait for the end of reset
	 while (`RST)
	    @(posedge `CLK);

	 $display("[INFO ] Out of reset at time %t", $time);
	 
	 // Wait for a data write
	 while (!(`TB.DATA_CYC && `TB.DATA_STB && `TB.DATA_WE))
	    @(posedge `TB.Clk);

	 $display("[INFO ] Detected data write, checking value at time %t", $time);
	 
	 if (32'd1 == `TB.DATA_DAT_WR) 
	 begin
	    $display("");
	    $display("[PASS ] TEST PASSED at time %t", $time);
	    $display("");
	    $finish();
	 end
	 else
	 begin
	    $display("");
	    $display("[FAIL ] TEST FAILED at time %t", $time);
	    $display("");
	    $finish();
	 end
	 
      end

endmodule