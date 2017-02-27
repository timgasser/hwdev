// This test does a simple burst of length 2 to uncached instruction RAM space.

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();

`include "tb_defines.v"
`include "mips1_top_defines.v"
   
   // Test writes and reads all register
   initial
      begin

	 // Dynamic array of addresses and writes
	 const int BurstLength = $urandom_range(2, 2);
	 const int AddrBase    = USER_RAM_KSEG1_BASE;

	 int testPass = 1;
	 
	 int Addr      [];
	 int WriteData [];
	 int ReadData  [];

	 Addr      = new[BurstLength];
	 WriteData = new[BurstLength];
	 ReadData  = new[BurstLength];

	 
	 foreach (Addr[i])
	    begin : ADDR_STORE
	       Addr[i] = AddrBase + (i << 2);
	    end

	 foreach (WriteData[i])
	    begin : WRITE_DATA_RANDOMISE
	       WriteData[i] = $urandom();
	    end

	 // Wait until Reset de-asserted
	 while (1'b0 !== `RST)
	    @(posedge `CLK);

	 `IBFM.wbBurstWrite32b(Addr, WriteData);
	 `IBFM.wbBurstRead32b(Addr, ReadData);
	 
	 $display("[INFO ] Verifying Read Data ...");
	 foreach (WriteData[i])
	    begin : READ_DATA_CHECK
	       if (ReadData[i] == WriteData[i])
	       begin
		  $display("[INFO ] Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
	       end
	       else 
	       begin
		  $display("[ERROR] Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
		  testPass = 0;
	       end
	    end

	 #1000ns;

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
	 $display("[FAIL] SDRAM test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
