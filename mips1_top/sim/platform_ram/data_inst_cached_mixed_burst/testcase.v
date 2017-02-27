// This test uses simultaneous accesses from both Data BFM and Inst BFM to separate areas of platform RAM.
// parameters below control the burst lengths and number of bursts for both BFMs.

// Coverage : Check the arbiter can handle simultaneous accesses by the BFMs

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();

`include "tb_defines.v"
`include "mips1_top_defines.v"

   parameter MIN_BURST_LEN = 1;
   parameter MAX_BURST_LEN = 32;
   
   parameter MIN_BURSTS = 1;
   parameter MAX_BURSTS = 32;
   
   // Test writes and reads all register
   initial
      begin

	 // Dynamic array of addresses and writes
	 const int NumBursts = $urandom_range(MIN_BURSTS, MAX_BURSTS);
//	 int BurstLength; // = $urandom_range(2, 64); <- needs to be duplicated for parallel BFMs
	 // const int     AddrBase    = 32'h0000_0100;
	 int InstAddrBase  = USER_RAM_KSEG1_BASE;
	 int DataAddrBase  = USER_RAM_SIZE >> 1;  
	 int ReadWriteSize = USER_RAM_SIZE >> 1;
	 
	 int testPass = 1;
	 
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
	 
	 // Now fork two processes, one for the Instruction BFM, and one for the Data BFM.
	 // The processes operate in their own regions of RAM.
	 // Inst BFM RAM range is 0 to middle of the RAM.
	 // Data BFM RAM range is middle of RAM to top of RAM.
	 fork
	    begin : IBFM_THREAD

	       int IbfmAddrBase;
	       int IbfmBurstLength;

	       int Addr      [];
	       int WriteData [];
	       int ReadData  [];

	       repeat (NumBursts)
	       begin : BURST_LOOP
		  IbfmBurstLength = $urandom_range(MIN_BURST_LEN, MAX_BURST_LEN);
		  IbfmAddrBase    = $urandom_range(InstAddrBase, InstAddrBase + ReadWriteSize - (IbfmBurstLength << 2));
		  IbfmAddrBase    = IbfmAddrBase & 32'hffff_fffc; // 32 bit aligned
		  $display("[INFO ] IBFM : Beginning Burst: Start Address 0x%x, Length %d at time %t", IbfmAddrBase, IbfmBurstLength, $time);
		  
		  Addr      = new[IbfmBurstLength];
		  WriteData = new[IbfmBurstLength];
		  ReadData  = new[IbfmBurstLength];
		  
		  foreach (WriteData[i])
		     begin : WRITE_DATA_RANDOMISE
			WriteData[i] = $urandom();
		     end

		  // For Write accesses, use the uncached base address
		  foreach (Addr[i])
		     begin : ADDR_STORE
			Addr[i] = IbfmAddrBase + (i << 2);
		     end
		  $display("[INFO ] IBFM : Beginning Write Burst: Start Address 0x%x, Length %d at time %t", Addr[0], IbfmBurstLength, $time);
		  `IBFM.wbBurstWrite32b(Addr, WriteData); // Write through the uncached addresses

		  // For the reads, change them to come back through the cache
		  foreach (Addr[i])
		     begin : ADDR_STORE
			Addr[i] = IbfmAddrBase + (i << 2) - USER_RAM_KSEG1_BASE;
		     end
		  $display("[INFO ] IBFM : Beginning Read Burst: Start Address 0x%x, Length %d at time %t", Addr[0], IbfmBurstLength, $time);
		  `IBFM.wbBurstRead32b (Addr, ReadData ); // Read through the cached addresses
		  
		  $display("[INFO ] IBFM : Verifying Read Data ...");
		  foreach (WriteData[i])
		     begin : READ_DATA_CHECK
			if (ReadData[i] == WriteData[i])
			begin
			   $display("[INFO ] IBFM : Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
			end
			else 
			begin
			   $display("[ERROR] IBFM : Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
			   testPass = 0;
			end
		     end

		  Addr.delete();
		  WriteData.delete();
		  ReadData.delete();

		  // Insert a random wait here
		  repeat ($urandom_range(0, 8))
		     @(posedge `CLK);
		  
	       end 
	    end

	    begin : DBFM_THREAD

	       int DbfmAddrBase;
	       int DbfmBurstLength; 

	       int Addr      [];
	       int WriteData [];
	       int ReadData  [];

	       repeat (NumBursts)
	       begin : BURST_LOOP
		  DbfmBurstLength = $urandom_range(MIN_BURST_LEN, MAX_BURST_LEN);
		  DbfmAddrBase    = $urandom_range(DataAddrBase, DataAddrBase + ReadWriteSize - (DbfmBurstLength << 2));
		  DbfmAddrBase    = DbfmAddrBase & 32'hffff_fffc; // 32 bit aligned
		  $display("[INFO ] DBFM : Beginning Burst: Start Address 0x%x, Length %d at time %t", DbfmAddrBase, DbfmBurstLength, $time);
		  
		  Addr      = new[DbfmBurstLength];
		  WriteData = new[DbfmBurstLength];
		  ReadData  = new[DbfmBurstLength];
		  
		  foreach (Addr[i])
		     begin : ADDR_STORE
			Addr[i] = DbfmAddrBase + (i << 2);
		     end

		  foreach (WriteData[i])
		     begin : WRITE_DATA_RANDOMISE
			WriteData[i] = $urandom();
		     end

		  $display("[INFO ] DBFM : Beginning Write Burst: Start Address 0x%x, Length %d at time %t", Addr[0], DbfmBurstLength, $time);
		  `DBFM.wbBurstWrite32b(Addr, WriteData);
		  $display("[INFO ] DBFM : Beginning Read Burst: Start Address 0x%x, Length %d at time %t", Addr[0], DbfmBurstLength, $time);
		  `DBFM.wbBurstRead32b(Addr, ReadData);
		  
		  $display("[INFO ] DBFM : Verifying Read Data ...");
		  foreach (WriteData[i])
		     begin : READ_DATA_CHECK
			if (ReadData[i] == WriteData[i])
			begin
			   $display("[INFO ] DBFM : Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
			end
			else 
			begin
			   $display("[ERROR] DBFM : Index %02d : Write Data = 0x%x, Read Data = 0x%x", i, WriteData[i], ReadData[i]);
			   testPass = 0;
			end
		     end

		  Addr.delete();
		  WriteData.delete();
		  ReadData.delete();

		  // Insert a random wait here, or the arbiter will never switch over
		  repeat ($urandom_range(0, 8))
		     @(posedge `CLK);
		  
	       end
	    end // block: DBFM_THREAD
	 join
	 
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
