// Simple Data bus test. Does a single write, read, and verify to check basic connectivity.

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();
   
`include "tb_defines.v"
   
   // Test writes and reads all register
   initial
      begin

	 int writeData;
	 int readData;

	 bit verifyOk = 0;
	 bit testPass = 0;

	 // Wait until Reset de-asserted
	 @(posedge `CLK);
	 while (`RST)
	    @(posedge `CLK);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 writeData =$urandom();
	 
	 `DBFM.wbWrite (32'h0000_0100, 4'b1111, writeData);
	 `DBFM.wbRead  (32'h0000_0100, 4'b1111, readData );

	 if (writeData == readData) testPass = 1;
	 
	 if (testPass)
	 begin
	    $display("");
	    $display("[PASS ] Test PASSED at time %t", $time);
	    $display("");
	 end
	 else
	 begin
	    $display("");
	    $display("[FAIL ] Test FAILED at time %t", $time);
	    $display("");
	 end
	 
	 #1000ns;
	 $finish();

      end

   initial
      begin
	 #10ms;
	 $display("[FAIL] SDRAM test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
