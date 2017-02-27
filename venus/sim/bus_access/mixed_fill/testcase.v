// Bus Access test for the memory

module TESTCASE ();

// `define TB TB_ADI
// `define EPP_MASTER TB_ADI.epp_master_bfm

`include "epp_bus_bridge_defs.v"

   parameter RAM_SIZE_32B = 1024;
   
   logic [31:0] randomData [RAM_SIZE_32B-1:0];
   
   // Test writes and reads all register
   initial
      begin

	 int dataLoop;
	 int addrLoop;

	 int fillType;
	 
	 int readData;
 
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
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 addrLoop = 0;

	 // Fill the memory with mixed writes
	 $display("[INFO ] Filling Memory (mixed accesses) at time %t", $time);
	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_32B ; addrLoop++)
	 begin

	    // Randomise the access type for writes
	    fillType = $urandom_range(0, 2);

	    case (fillType)
	      0 : // Bytes
		 begin
		    // doBusWrite(input [31:0] BusAddr, input [31:0] BusWriteData, input [1:0] BusSize);
  		    `EPP_MASTER.doBusWrite((addrLoop << 2) + 3, {24'hDEADDE, randomData[addrLoop][31:24]}, fillType);
  		    `EPP_MASTER.doBusWrite((addrLoop << 2) + 1, {24'hDEADDE, randomData[addrLoop][15: 8]}, fillType);
  		    `EPP_MASTER.doBusWrite((addrLoop << 2) + 0, {24'hDEADDE, randomData[addrLoop][ 7: 0]}, fillType);
  		    `EPP_MASTER.doBusWrite((addrLoop << 2) + 2, {24'hDEADDE, randomData[addrLoop][23:16]}, fillType);
		 end
	      1 : // 16 bits
		 begin
	    	    `EPP_MASTER.doBusWrite((addrLoop << 2) + 2, {16'hDEAD, randomData[addrLoop][31:16]}, fillType);
		    `EPP_MASTER.doBusWrite((addrLoop << 2) + 0, {16'hDEAD, randomData[addrLoop][15: 0]}, fillType);
		 end
	      2 : // 32 bits
		 begin
		    `EPP_MASTER.doBusWrite((addrLoop << 2) + 0, randomData[addrLoop][31: 0], fillType);
		 end
	    endcase // case (fillType)
	    
	 end
	   
	 $display("[INFO ] Reading back memory contents (word accesses) at time %t", $time);
	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_32B ; addrLoop++)
	 begin

	    // Randomise the access type for the readbacks
	    fillType = $urandom_range(0, 2);

	    case (fillType)
	      0 : // Bytes
		 begin
		    // doBusWrite(input [31:0] BusAddr, input [31:0] BusReadData, input [1:0] BusSize);
  		    `EPP_MASTER.doBusRead((addrLoop << 2) + 2, readData8[2], fillType);
  		    `EPP_MASTER.doBusRead((addrLoop << 2) + 1, readData8[1], fillType);
  		    `EPP_MASTER.doBusRead((addrLoop << 2) + 3, readData8[3], fillType);
  		    `EPP_MASTER.doBusRead((addrLoop << 2) + 0, readData8[0], fillType);
		    readData = {readData8[3], readData8[2], readData8[1], readData8[0]};
		 end
	      1 : // 16 bits
		 begin
	    	    `EPP_MASTER.doBusRead((addrLoop << 2) + 2, readData16[1] , fillType);
		    `EPP_MASTER.doBusRead((addrLoop << 2) + 0, readData16[0] , fillType);
		    readData = {readData16[1][15:0], readData16[0][15:0]};
		    
		 end
	      2 : // 32 bits
		 begin
		    `EPP_MASTER.doBusRead((addrLoop << 2) + 0, readData, fillType);
		 end
	    endcase // case (fillType)

	    
//	    `EPP_MASTER.doBusRead((addrLoop << 2) + 0, readData, ERW_SIZE_WORD);

	    if (randomData[addrLoop] === readData) 
	    begin
	       $display("[INFO ] EPP Data readback of Address 0x%x verified at time %t", addrLoop << 2, $time);
	    end
	    else
	    begin
	       $display("[ERROR] EPP Data readback of Address 0x%x FAILED, Read 0x%x, Expected 0x%x at time %t", addrLoop << 2, readData, randomData[addrLoop], $time); 	       testPass = 0;
	    end
	    
	 end
	 
	   
 
	 if (testPass)
	 begin
	    $display("[PASS ] Test PASSED at time %t", $time);
	    $display("");
	 end
	 else
	 begin
	    $display("[FAIL ] Test FAILED at time %t", $time);
	    $display("");
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
