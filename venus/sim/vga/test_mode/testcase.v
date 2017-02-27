// Streaming access testcase

module TESTCASE ();

// `define TB TB_ADI
// `define EPP_MASTER TB_ADI.epp_master_bfm

`include "epp_bus_bridge_defs.v"

   parameter RAM_SIZE_PIXELS  = (640 * 480); // (640 * 480 * 3) ;
   parameter RAM_SIZE_2PIXELS = RAM_SIZE_PIXELS >> 1;
//   logic [31:0] randomData [RAM_SIZE_32B-1:0];
   
   // Test writes and reads all register
   initial
      begin

	 int dataLoop;
	 int addrLoop;

	 int fillType;
	 
	 int readData;
 
	 int readData16 [1:0] ;
	 byte readData8  [3:0] ;
	 
	 bit verifyOk = 0;
	 bit testPass = 1;
	 
//	 for (dataLoop = 0 ; dataLoop < RAM_SIZE_32B ; dataLoop = dataLoop + 1)
//	 begin
//	    randomData[dataLoop] = $urandom();
// //	    $display("[INFO ] Randomising data array. Element %d = 0x%x", dataLoop, randomData[dataLoop]);
// 	 end
   	 
	 // Wait until Reset de-asserted
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 // Turn on the VGA controller
	 $display("[INFO ] Turning on VGA in test mode at time %t", $time);
	 `TB.btn_sw_bfm.SwClose(1);
	 `TB.btn_sw_bfm.SwClose(0);

	 // Wait for a whole frame
	 @(negedge `TB.VGA_VSYNC);
	 $display("[INFO ] Start of frame at time %t", $time);
	 @(negedge `TB.VGA_VSYNC);
	 $display("[INFO ] End of frame at time %t", $time);

	 // Let the sim run for a few more lines to check the end of frame timing
	 repeat (10)
	    @(negedge `TB.VGA_HSYNC);

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
