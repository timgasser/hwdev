// Streaming access testcase

module TESTCASE ();


   parameter FRAME_SIZE_BYTE = (1024 * 512 * 2); // PSX frame buffer is 1MB (1024 x 512 16 bit pixel values)
    
   // Test writes and reads all register
   initial
      begin

	 int dataLoop;
	 int wordLoop;

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

	 wordLoop = 0;

	 while (wordLoop < 16) // (FRAME_SIZE_BYTE >> 1))
	 begin
	    `CRAM.memory_write(wordLoop, 2'b00, wordLoop);
	    wordLoop++;
	    
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'h00ff); // GR
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'h0000); // RB
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'h00ff); // BG
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'h0000); // GR
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'hffff); // RB
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'h0000); // BG
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'hff00); // GR
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'h0000); // RB
//	    `CRAM.memory_write(wordLoop++, 2'b00, 16'hff00); // BG
	 end

	 $display("[INFO ] Programmed %d 16-bit words", wordLoop);
//	 $display("[INFO ] Pixel 0 : R = %3d, G = %3d, B = %3d", `CRAM.memory[2 ], `CRAM.memory[1 ], `CRAM.memory[0 ][);
//	 $display("[INFO ] Pixel 1 : R = %3d, G = %3d, B = %3d", `CRAM.memory[5 ], `CRAM.memory[4 ], `CRAM.memory[3 ]);
//	 $display("[INFO ] Pixel 2 : R = %3d, G = %3d, B = %3d", `CRAM.memory[8 ], `CRAM.memory[7 ], `CRAM.memory[6 ]);
//	 $display("[INFO ] Pixel 3 : R = %3d, G = %3d, B = %3d", `CRAM.memory[11], `CRAM.memory[10], `CRAM.memory[9 ]);
//	 $display("[INFO ] Pixel 4 : R = %3d, G = %3d, B = %3d", `CRAM.memory[14], `CRAM.memory[13], `CRAM.memory[12]);
//	 $display("[INFO ] Pixel 5 : R = %3d, G = %3d, B = %3d", `CRAM.memory[17], `CRAM.memory[16], `CRAM.memory[15]);
//

	 wordLoop = 0;

	 while (wordLoop < 16)
	 begin
	    $display("[INFO ] Cellular RAM Word %3d = 0x%x", wordLoop, `CRAM.memory_read(wordLoop++));
	 end
	 
	 // Wait until Reset de-asserted
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);
	 
	 FirstTwoPixels = {`CRAM.memory[5], `CRAM.memory[4], `CRAM.memory[3], `CRAM.memory[2], `CRAM.memory[1], `CRAM.memory[0]};
	 
	 $display("[DEBUG] Reading back first 2 pixels of data = 0x%x at time %t", FirstTwoPixels, $time);


	 $finish();
	 
	 // Turn on the VGA controller
	 $display("[INFO ] Turning on VGA in test mode at time %t", $time);
//	 `TB.btn_sw_bfm.SwClose(1);
	 `TB.btn_sw_bfm.SwClose(0);

	 // Wait for a whole frame
	 @(negedge `TB.VGA_VSYNC);
	 $display("[INFO ] Start of frame at time %t", $time);
	 @(negedge `TB.VGA_VSYNC);
	 $display("[INFO ] End of frame at time %t", $time);

	 // rsim will do a diff with a golden reference file
	 
	 #1000ns;
	 $display("[INFO ] Test completed (without check) at time %t", $time);
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
