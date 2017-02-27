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

	 string inputFileName = "frame_in.bin.rgb";
	 int 	inputFile;
	 int 	r;

	 byte 	writeByte;
	 int 	filePosition;
	 
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

	 addrLoop = 0;

	 // Stream the random array into the EPP regs
	 $display("[INFO ] Storing %d pixels data in VGA memory at time %t", RAM_SIZE_PIXELS, $time);

	 // First set the address to 0x0000_0000
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR0, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR1, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR2, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR3, 8'h00);

	 // Select the streaming register
	 `EPP_MASTER.doEppAddrWrite(ERW_STREAM);

	 $display("[INFO ] Initialising SDRAM with incrementing data values");
	 for (int wordLoop = 0 ; wordLoop < 1024 ; wordLoop++)
	 begin
	    `CRAM.memory_write(wordLoop, 2'b00, wordLoop);
	    readData = `CRAM.memory_read(wordLoop);
	    if (readData !== wordLoop)
	    begin
	       $display("[ERROR] SDRAM readback failed. Expectged 0x%x, read 0x%x", wordLoop, readData);
	    end
	 end
	 
//	 // Stream the input file into the memory
//	 // Open the file (binary format)
//	 inputFile = $fopen(inputFileName, "rb");
//	 filePosition = 0;
//	 
//	 while (!$feof(inputFile))
//	 begin
//	    r = $fread(writeByte, inputFile, filePosition, 1);
// 	    writeByte = $fscanf(inputFile, "%b", "b");
//	    `EPP_MASTER.doEppDataWrite(writeByte);
//	    filePosition++;
//	 end
//
	 

//	 for (int i = 0 ; i < 1024 ; i++)
//	 begin
//	    `EPP_MASTER.doEppDataWrite(i);
//	 end
	 
	 // Turn on the VGA controller
	 $display("[INFO ] Turning on VGA driver at time %t", $time);
	 `TB.btn_sw_bfm.SwClose(0);

	 // Wait for a whole frame
	 @(negedge `TB.VGA_VSYNC);
	 $display("[INFO ] Start of frame at time %t", $time);
	 @(negedge `TB.VGA_VSYNC);
	 $display("[INFO ] End of frame at time %t", $time);

//	 // Verify the VGA frame buffer
//	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_2PIXELS ; addrLoop++)
//	 begin
//	    $display("[INFO ] Need to add a pixel data readback at time %t", $time);
//	    testPass = 0;
//	 end
//

	 if (!testPass)
	 begin
	    $display("[FAIL ] Test FAILED !");
	 end
	 else
	 begin
	    $display("[PASS ] Test PASSED !");
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
