// This uses the data bus to do single accesses of various widths.

// Use the BFM-based CPU_CORE wrapper for the test
`define CPU_CORE_BFM

module TESTCASE ();

`include "tb_defines.v"

   parameter RAM_SIZE_32B = (32'h0020_0000 >> 2); // 2MB
   
   logic [31:0] randomData [RAM_SIZE_32B-1:0];

   
   // Test writes and reads all register
   initial
      begin

	 const int addrInc = 32'h0000_1000;

	 int dataLoop;
	 int addrLoop;

	 int fillType;
	 
	 int readData;

	 int readData32 [3:0] ;
	 int readData16 [1:0] ;
	 byte readData8  [3:0] ;
	 
	 bit verifyOk = 0;
	 bit testPass = 1;
	 
	 for (dataLoop = 0 ; dataLoop < RAM_SIZE_32B ; dataLoop = dataLoop + 1)
	 begin
	    randomData[dataLoop] = $urandom();
//	    $display("[INFO ] Randomising data array. Element %d = 0x%x", dataLoop, randomData[dataLoop]);
	 end
   	 
	 // Wait until Reset de-asserted
	 while (1'b0 !== `RST)
	    @(posedge `CLK);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 addrLoop = 0;

	 // Fill the memory with mixed writes
	 $display("[INFO ] Filling Memory (mixed accesses) at time %t", $time);
	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_32B ; addrLoop = addrLoop + addrInc)
	 begin

	    // Randomise the access type for writes
	    fillType = $urandom_range(0, 2);

	    case (fillType)
	      0 : // Bytes
		 begin
		    // doBusWrite(input [31:0] BusAddr, input [31:0] BusWriteData, input [1:0] BusSize);
  		    `DBFM.wbWrite((addrLoop << 2), 4'b1000, {randomData[addrLoop][31:24], 24'hDEADDE});
  		    `DBFM.wbWrite((addrLoop << 2), 4'b0010, {16'hDEAD, randomData[addrLoop][15: 8], 8'hDE});
  		    `DBFM.wbWrite((addrLoop << 2), 4'b0001, {24'hDEADDE, randomData[addrLoop][ 7: 0]});
  		    `DBFM.wbWrite((addrLoop << 2), 4'b0100, {8'hDE, randomData[addrLoop][23:16], 16'hDEAD});
		 end
	      1 : // 16 bits
		 begin
	    	    `DBFM.wbWrite((addrLoop << 2), 4'b1100, {randomData[addrLoop][31:16], 16'hDEAD});
		    `DBFM.wbWrite((addrLoop << 2), 4'b0011, {16'hDEAD, randomData[addrLoop][15: 0]});
		 end
	      2 : // 32 bits
		 begin
		    `DBFM.wbWrite((addrLoop << 2), 4'b1111, randomData[addrLoop][31: 0]);
		 end
	    endcase // case (fillType)
	    
	 end
	   
	 $display("[INFO ] Reading back memory contents (word accesses) at time %t", $time);
	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_32B ; addrLoop = addrLoop + addrInc)
	 begin

	    // Randomise the access type for the readbacks
	    fillType = $urandom_range(0, 2);

	    case (fillType)
	      0 : // Bytes
		 begin
  		    `DBFM.wbRead((addrLoop << 2), 4'b0100, readData32[2]);
  		    `DBFM.wbRead((addrLoop << 2), 4'b0010, readData32[1]);
  		    `DBFM.wbRead((addrLoop << 2), 4'b1000, readData32[3]);
  		    `DBFM.wbRead((addrLoop << 2), 4'b0001, readData32[0]);
		    readData = {readData32[3][31:24], readData32[2][23:16], readData32[1][15:8], readData32[0][7:0]};
		 end
	      1 : // 16 bits
		 begin
	    	    `DBFM.wbRead((addrLoop << 2), 4'b1100, readData32[1]);
		    `DBFM.wbRead((addrLoop << 2), 4'b0011, readData32[0]);
		    readData = {readData32[1][31:16], readData32[0][15:0]};
		    
		 end
	      2 : // 32 bits
		 begin
		    `DBFM.wbRead((addrLoop << 2), 4'b1111, readData);
		 end
	    endcase // case (fillType)

	    
	    if (randomData[addrLoop] === readData) 
	    begin
	       $display("[INFO ] EPP Data readback of Address 0x%x verified at time %t", addrLoop << 2, $time);
	    end
	    else
	    begin
	       $display("[ERROR] EPP Data readback of Address 0x%x FAILED, Read 0x%x, Expected 0x%x at time %t", addrLoop << 2, readData, randomData[addrLoop], $time); 	       
	       testPass = 0;
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

//   initial
//      begin
//	 #100ms;
//	 $display("[FAIL] Epp test FAILED (timed out) at time %t", $time);
//	 $display("");
//	 $finish();
//      end
   

   
endmodule // TESTCASE
