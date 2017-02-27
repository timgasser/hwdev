// Streaming access testcase

module TESTCASE ();

`include "tb_defines.v"
   
   // Test writes and reads all register
   initial
      begin

	 $display("[INFO ] Setting VGA Test Mode input at time %t", $time);
	 force `VGA_TEST_EN = 1'b1;

	 // Wait until Reset de-asserted
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 // Wait for a whole frame
	 @(negedge `TB.VgaVs);
	 $display("[INFO ] Start of frame at time %t", $time);
	 @(negedge `TB.VgaVs);
	 $display("[INFO ] End of frame at time %t", $time);

	 // Let the sim run for a few more lines to check the end of frame timing
	 repeat (10)
	    @(negedge `TB.VgaHs);

//	 // Verify the VGA frame buffer
//	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_2PIXELS ; addrLoop++)
//	 begin
//	    $display("[INFO ] Need to add a pixel data readback at time %t", $time);
//	    testPass = 0;
//	 end
//
//
//	 if (!testPass)
//	 begin
//	    $display("[FAIL ] Test FAILED !");
//	 end
//	 else
//	 begin
//	    $display("[PASS ] Test PASSED !");
//	 end
//	 
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
