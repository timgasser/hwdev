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

	 string inputFileName = "frame_in.bin.rgb";
	 int 	inputFile;
	 int 	r;
	 
	 // Stream the random array into the EPP regs
	 $display("[INFO ] Loading file %s to WB Slave memory at time %t",inputFileName, $time);

	 // Open the file (binary format)
	 inputFile = $fopen(inputFileName, "rb");
	 r = $fread(`VGA_RAM, inputFile);

	 $display("[INFO ] Checking first values of memory array - 0x%x, 0x%x, 0x%x", `VGA_RAM[0], `VGA_RAM[1], `VGA_RAM[2]);

	 // Wait until Reset de-asserted
	 `TB.EnVga = 1'b0;
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

//	 // Turn on the VGA controller
	 `TB.EnVga = 1'b1;

	 
//	 $display("[INFO ] Turning on VGA driver at time %t", $time);
//	 `TB.btn_sw_bfm.SwClose(0);

	 // Wait for a whole frame
	 @(negedge `TB.VgaVs);
	 $display("[INFO ] Start of frame at time %t", $time);
	 @(negedge `TB.VgaVs);
	 $display("[INFO ] End of frame at time %t", $time);

	 // rsim will do a diff with a golden reference file
	 
	 #1000ns;         
//	 $display("[INFO ] Test completed (without check) at time %t", $time);
         $fclose(inputFile);
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
