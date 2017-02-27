// Simple Data bus test. Does a single write, read, and verify to check basic connectivity.

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();
   
`include "tb_defines.v"
`include "psx_mem_map.vh"
`include "mips1_top_defines.v"
   
   parameter ROM_VERIFY_SIZE_8B = 2 ** ROM_SIZE_P2;
   parameter WORD_SIZE_8B = 4;
   parameter WORD_STEP_SIZE = 4;

   
   parameter ROM_BASE_ADDR = BOOTROM_KSEG1_BASE; // un-cached
   
   // TB-side random number array to track reads
   logic [7:0] TbRomArray [(2 ** ROM_VERIFY_SIZE_8B)-1:0];
   
   // Test writes and reads all register
   initial
      begin

	 logic [31:0] romData;
	 logic [31:0] readData;

	 bit verifyOk = 0;
	 bit testPass = 1;

         int romArrayLoop;
         int wordByteLoop;
         int randomWord;
         
	 // Wait until Reset de-asserted
	 @(posedge `CLK);
	 while (`RST)
	    @(posedge `CLK);
	 $display("[INFO ] Reset de-asserted at time %t", $time);
         
	 $display("[INFO ] Randomising Rom Array data at time %t", $time);
         // Main loop of 32 bit instructions to store in the ROM array (a byte-at-a-time)
         for (romArrayLoop = 0 ; 
              romArrayLoop < ROM_VERIFY_SIZE_8B ; 
              romArrayLoop = romArrayLoop + (WORD_STEP_SIZE * 4))
         begin
            randomWord = $urandom();
//            $display("[DEBUG] ROM Address 0x%x, Data = 0x%x", romArrayLoop, randomWord);

            // Divide the 32 bit word into bytes and store in the ROM array
            for (wordByteLoop = 0 ; wordByteLoop < WORD_SIZE_8B ; wordByteLoop++)
            begin
               `ROM_BYTE_ARRAY[romArrayLoop + 3] = randomWord[31:24];
               `ROM_BYTE_ARRAY[romArrayLoop + 2] = randomWord[23:16];
               `ROM_BYTE_ARRAY[romArrayLoop + 1] = randomWord[15: 8];
               `ROM_BYTE_ARRAY[romArrayLoop + 0] = randomWord[ 7: 0];
            end
         end
         
         $display("[INFO ] Reading back ROM at time %t", $time);
         for (romArrayLoop = ROM_BASE_ADDR ; 
              romArrayLoop < ROM_BASE_ADDR + ROM_VERIFY_SIZE_8B ; 
              romArrayLoop = romArrayLoop + (WORD_STEP_SIZE * 4))
         begin
            `DBFM.wbRead(romArrayLoop, 4'b1111, readData );
            romData = {`ROM_BYTE_ARRAY[romArrayLoop - ROM_BASE_ADDR + 3],
                       `ROM_BYTE_ARRAY[romArrayLoop - ROM_BASE_ADDR + 2],
                       `ROM_BYTE_ARRAY[romArrayLoop - ROM_BASE_ADDR + 1],
                       `ROM_BYTE_ARRAY[romArrayLoop - ROM_BASE_ADDR + 0]                     
                       };
            
            if (romData !== readData)
            begin
               $display("[ERROR] ROM Read Addr 0x%x, Expected 0x%x, Read 0x%x at time %t",
                        romArrayLoop, romData, readData, $time);
               testPass = 0;
            end
            else
            begin
               $display("[DEBUG] ROM Read Match Addr 0x%x at time %t", romArrayLoop, $time);
            end
         end

         
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
	 $display("[FAIL] Test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
