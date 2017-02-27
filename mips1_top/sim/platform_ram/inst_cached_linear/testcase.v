// This test checks the operation of the instruction cache. 
// All accesses are performed on the instruction BFM. The test:
//
// 1. Does a 1k byte-writes every 4 32-bit words to invalidate the cache line.
//    

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();

`include "tb_defines.v"
`include "mips1_top_defines.v"

   parameter RAM_SIZE_8B  = (32*1024); 
   parameter RAM_SIZE_32B = RAM_SIZE_8B >> 2;
   
   // Test writes and reads all register
   initial
      begin
	 
	 // Dynamic array of addresses and writes
	 const int NumBursts = $urandom_range(10, 20);
	 int BurstLength; // = $urandom_range(2, 64);
	 // const int     AddrBase    = 32'h0000_0100;
	 int AddrBase; 

	 int testPass = 1;
	 
	 int 	       Addr      [];
	 int 	       WriteData [];
	 int 	       ReadData  [];

	 int 	       AddrLoop;

	 // Wait until Reset de-asserted
	 while (1'b0 !== `RST)
	    @(posedge `CLK);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 // Flush the cache, invalidating all data and clearing X out of TAG RAM
	 $display("[INFO ] Flushing Cache at time %t", $time);	 
	 for (AddrLoop = 0 ; AddrLoop < 2 ** 10 ; AddrLoop++)
	 begin : CACHE_FLUSH
	    // 2+2 because you want to write a byte every 4x32bit words
	    `IBFM.wbWriteByte(AddrLoop << (2 + 2), 8'h00);
	 end
	 
	 // Now fill up the platform RAM (2MB) by writing random data using uncached instruction path
	 $display("[INFO ] Randomising platform RAM array, writing over uncached IBFM path at time %t", $time);	 
	 
	 Addr      = new[RAM_SIZE_32B];
	 WriteData = new[RAM_SIZE_32B];
	 ReadData  = new[RAM_SIZE_32B];

	 foreach (Addr[i])
	    begin : ADDR_STORE
	       Addr[i] = USER_RAM_KSEG1_BASE + (i << 2);
	    end

	 foreach (WriteData[i])
	    begin : WRITE_DATA_RANDOMISE
	       WriteData[i] = $urandom();
	    end

	 $display("[INFO ] Writing random data over the uncached IBFM path at time %t", $time);	 
	 `IBFM.wbBurstWrite32b(Addr, WriteData);
	 `IBFM.wbBurstRead32b(Addr, ReadData);

	 $display("[INFO ] Verifying Read Data ...");
	 foreach (WriteData[i])
	    begin : READ_DATA_CHECK
	       if (ReadData[i] == WriteData[i])
	       begin
//		  $display("[INFO ] Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
	       end
	       else 
	       begin
		  $display("[ERROR] Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
		  testPass = 0;
	       end
	    end // block: READ_DATA_CHECK

	 if (testPass)
	 begin
	    $display("[INFO ] Read Data Verify completed");
	 end
	 else
	 begin
	    $display("[ERROR] Read Data Mismatch !");
	 end

	 $display("[INFO ] Changing address range to cached region at time %t", $time);	 
	 foreach (Addr[i])
	    begin : ADDR_STORE
	       Addr[i] = USER_RAM_KUSEG_BASE + (i << 2);
	    end
	 
	 $display("[INFO ] Reading back through I-Cache at time %t", $time);	 
	 `IBFM.wbBurstRead32b(Addr, ReadData);

	 testPass = 1;
	 
	 $display("[INFO ] Verifying Read Data ...");
	 foreach (WriteData[i])
	    begin : READ_DATA_CHECK
	       if (ReadData[i] == WriteData[i])
	       begin
//		  $display("[INFO ] Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
	       end
	       else 
	       begin
		  $display("[ERROR] Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
		  testPass = 0;
	       end
	    end // block: READ_DATA_CHECK
	 
	 if (!testPass)
	 begin
	    $display("[FAIL ] Test FAILED !");
	 end
	 else
	 begin
	    $display("[PASS ] Test PASSED !");
	 end
	 
	 $finish();
	 
      end
   
   initial
      begin
	 #10ms;
	 $display("[FAIL] MIPS1 test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
