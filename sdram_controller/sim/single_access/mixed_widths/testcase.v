// Bus Access test for the memory

module TESTCASE ();

`define TB SDRAM_CONTROLLER_TB
`define BFM SDRAM_CONTROLLER_TB.wb_master_bfm

   // Test writes and reads all register
   initial
      begin

	 int Addr;
	 int writeData;
	 int readData;

	 bit verifyOk = 0;
	 bit testPass = 1;
	 
	 // Wait until Reset de-asserted
	 @(negedge `TB.Rst);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 writeData =$urandom();
	 Addr = 32'h0000_0100;
	 `BFM.wbWrite(Addr, 4'b1111, writeData);
	 `BFM.wbRead (Addr, 4'b1111, readData );
	 if (writeData != readData) testPass = 0;

	 
	 writeData =$urandom();	 
	 Addr = 32'h0000_0200;
	 `BFM.wbWrite (Addr, 4'b0011, writeData);
	 `BFM.wbRead  (Addr, 4'b0011, readData );
	 if (writeData[15:0] != readData[15:0]) testPass = 0;

	 `BFM.wbWrite (Addr+4, 4'b1100, writeData);
	 `BFM.wbRead  (Addr+4, 4'b1100, readData );
	 if (writeData[31:16] != readData[31:16]) testPass = 0;

	 writeData =$urandom();	 
	 Addr = 32'h0000_0300;
	 `BFM.wbWrite (Addr   , 4'b0001, writeData);
	 `BFM.wbRead  (Addr   , 4'b0001, readData );
	 if (writeData[7:0] != readData[7:0]) testPass = 0;
	 
	 `BFM.wbWrite (Addr+4 , 4'b0010, writeData);
	 `BFM.wbRead  (Addr+4 , 4'b0010, readData );
	 if (writeData[15:8] != readData[15:8]) testPass = 0;
	 
	 `BFM.wbWrite (Addr+8 , 4'b0100, writeData);
	 `BFM.wbRead  (Addr+8 , 4'b0100, readData );
	 if (writeData[23:16] != readData[23:16]) testPass = 0;
	 
	 `BFM.wbWrite (Addr+12, 4'b1000, writeData);
	 `BFM.wbRead  (Addr+12, 4'b1000, readData );
	 if (writeData[31:24] != readData[31:24]) testPass = 0;

	 #1000ns;

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
	 $display("[FAIL] SDRAM test FAILED (timed out) at time %t", $time);
	 $display("");
	 $finish();
      end
   

   
endmodule // TESTCASE
