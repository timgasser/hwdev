// Bus Access test for the memory

module TESTCASE ();

`define TB SDRAM_CONTROLLER_TB
`define BFM SDRAM_CONTROLLER_TB.wb_master_bfm

   // Test writes and reads all register
   initial
      begin

	 int writeData;
	 int readData;

	 bit verifyOk = 0;
	 bit testPass = 0;
	 
	 // Wait until Reset de-asserted
	 @(negedge `TB.Rst);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 writeData =$urandom();
	 
	 `BFM.wbWrite (32'h0000_0100, 4'b1111, writeData);
	 `BFM.wbRead  (32'h0000_0100, 4'b1111, readData );

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
