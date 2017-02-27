// Streaming access testcase

module TESTCASE ();


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

	 while (byteLoop <  FRAME_SIZE_BYTE)
	 begin
	    `VGA_RAM[byteLoop++] = 8'hff; // R
	    `VGA_RAM[byteLoop++] = 8'h00; // G
	    `VGA_RAM[byteLoop++] = 8'h00; // B
	    `VGA_RAM[byteLoop++] = 8'h00; // R
	    `VGA_RAM[byteLoop++] = 8'hff; // G
	    `VGA_RAM[byteLoop++] = 8'h00; // B
	    `VGA_RAM[byteLoop++] = 8'h00; // R
	    `VGA_RAM[byteLoop++] = 8'h00; // G
	    `VGA_RAM[byteLoop++] = 8'hff; // B
	 end

	 $display("[INFO ] Programmed %d bytes", byteLoop);
	 $display("[INFO ] Pixel 0 : R = %3d, G = %3d, B = %3d", `VGA_RAM[2 ], `VGA_RAM[1 ], `VGA_RAM[0 ]);
	 $display("[INFO ] Pixel 1 : R = %3d, G = %3d, B = %3d", `VGA_RAM[5 ], `VGA_RAM[4 ], `VGA_RAM[3 ]);
	 $display("[INFO ] Pixel 2 : R = %3d, G = %3d, B = %3d", `VGA_RAM[8 ], `VGA_RAM[7 ], `VGA_RAM[6 ]);
	 $display("[INFO ] Pixel 3 : R = %3d, G = %3d, B = %3d", `VGA_RAM[11], `VGA_RAM[10], `VGA_RAM[9 ]);
	 $display("[INFO ] Pixel 4 : R = %3d, G = %3d, B = %3d", `VGA_RAM[14], `VGA_RAM[13], `VGA_RAM[12]);
	 $display("[INFO ] Pixel 5 : R = %3d, G = %3d, B = %3d", `VGA_RAM[17], `VGA_RAM[16], `VGA_RAM[15]);
	 
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
	 $display("[FAIL] Epp test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
