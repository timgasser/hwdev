// Streaming access testcase

module TESTCASE ();

`include "tb_defines.v"

   parameter FRAME_SIZE_BYTE = (1024 * 512 * 2); // PSX frame buffer is 1MB (1024 x 512 16 bit pixel values)
    
   // Test writes and reads all register
   initial
      begin

	 int dataLoop;
	 int byteLoop;

	 int fillType;
	 
	 int readData;
 
	 int readData16 [1:0] ;
	 byte readData8  [3:0] ;
	 
	 bit verifyOk = 0;
	 bit testPass = 1;

	 logic [47:0] FirstTwoPixels;

//	 for (dataLoop = 0 ; dataLoop < RAM_SIZE_32B ; dataLoop = dataLoop + 1)
//	 begin
//	    randomData[dataLoop] = $urandom();
// //	    $display("[INFO ] Randomising data array. Element %d = 0x%x", dataLoop, randomData[dataLoop]);
// 	 end

	 // Stream the random array into the EPP regs
	 $display("[INFO ] Storing %d bytes of pixel data directly in VGA memory at time %t", FRAME_SIZE_BYTE, $time);

	 byteLoop = 0;

	 while (byteLoop < FRAME_SIZE_BYTE)
	 begin
	    `VGA_RAM[byteLoop++] = 8'h00; // Red
	    `VGA_RAM[byteLoop++] = 8'h00; // Green
	    `VGA_RAM[byteLoop++] = 8'h00; // Blue  
	    `VGA_RAM[byteLoop++] = 8'hff; // Red   
	    `VGA_RAM[byteLoop++] = 8'hff; // Green 
	    `VGA_RAM[byteLoop++] = 8'hff; // Blue  
	 end

	 // Wait until Reset de-asserted
	 `TB.EnVga = 1'b0;
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);


	 FirstTwoPixels = {`VGA_RAM[5], `VGA_RAM[4], `VGA_RAM[3], `VGA_RAM[2], `VGA_RAM[1], `VGA_RAM[0]};
	 
	 $display("[DEBUG] Reading back first 2 pixels of data = 0x%x at time %t", FirstTwoPixels, $time);

//	 // Turn on the VGA controller
	 `TB.EnVga = 1'b1;

	 
//	 $display("[INFO ] Turning on VGA driver at time %t", $time);
//	 `TB.btn_sw_bfm.SwClose(0);

	 // Wait for a whole frame
	 @(negedge `TB.VgaVs);
	 $display("[INFO ] Start of frame at time %t", $time);
	 @(negedge `TB.VgaVs);
	 $display("[INFO ] End of frame at time %t", $time);

	 #1000ns;
	 $finish();

      end

   initial
      begin
	 #100ms;
	 $display("[FAIL] Test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
