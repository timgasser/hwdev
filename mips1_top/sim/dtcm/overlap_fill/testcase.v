// This test calls a specific function to do overlapping address and data accesses to the TCM. 
// It checks for a single cycle latency access to D-TCM.

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();

`include "tb_defines.v"
`include "mips1_top_defines.v"
   
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
	 
	 `DBFM.wbOverlapWriteVerify(DATA_TCM_BASE, DATA_TCM_SIZE, testPass);

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
