// Bus Access test for the memory

module TESTCASE ();

// `define TB TB_ADI
// `define EPP_MASTER TB_ADI.epp_master_bfm

`include "epp_bus_bridge_defs.v"

   // Test writes and reads all register
   initial
      begin

	 int addrLoop;
	 
	 bit verifyOk = 0;
	 bit testPass = 1;
	 
	 // Wait until Reset de-asserted
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 addrLoop = 0;
	 
//	 for (addrLoop = 0 ; addrLoop < (2**6) ; addrLoop++)
//	 begin
	    `EPP_MASTER.doBusVerify(addrLoop << 2, verifyOk);
	    if (testPass && !verifyOk) testPass = 0;
//	 end
	    
	 if (testPass)
	 begin
	    $display("[PASS ] Test PASSED at time %t", $time);
	    $display("");
	 end
	 else
	 begin
	    $display("[FAIL ] Test FAILED at time %t", $time);
	    $display("");
	 end
	 
	 
	 #1000ns;
	 $finish();

      end

   initial
      begin
	 #100ms;
	 $display("[FAIL] Epp test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
