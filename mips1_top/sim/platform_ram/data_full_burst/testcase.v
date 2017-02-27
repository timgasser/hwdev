// 32 burst access across the entire memory space of the platform RAM 

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();

`include "tb_defines.v"
`include "mips1_top_defines.v"
   
   // Test writes and reads all register
   initial
      begin

	 // Slightly tweak the random bursts to check across the 2MB RAM range
	 const int NumBursts = 32;
	 int 	   currentBurst;
	 int BurstLength; // = $urandom_range(2, 64);
	 // const int     AddrBase    = 32'h0000_0100;
	 int AddrBase; 

	 int testPass = 1;
	 
	 int 	       Addr      [];
	 int 	       WriteData [];
	 int 	       ReadData  [];

	 // Wait until Reset de-asserted
	 while (1'b0 !== `RST)
	    @(posedge `CLK);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 for (currentBurst = 1 ; currentBurst < NumBursts+1 ; currentBurst++)
	 begin : BURST_LOOP
	    
	    BurstLength = $urandom_range(2, 256);
	    AddrBase    = (currentBurst * 32'h0001_0000) - (BurstLength << 2);
	    AddrBase    = AddrBase & 32'hffff_fffc; // 32 bit aligned
	    $display("[INFO ] Beginning Burst: Address 0x%x, Length %d", AddrBase, BurstLength);
	    
	    
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


	    `DBFM.wbBurstWrite32b(Addr, WriteData);
	    `DBFM.wbBurstRead32b(Addr, ReadData);
	    
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

	    Addr.delete();
	    WriteData.delete();
	    ReadData.delete();

	 end
	 
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
	 $display("[FAIL] Test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
