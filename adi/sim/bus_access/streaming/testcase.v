// Streaming access testcase

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

	 // Stream the random array into the EPP regs
	 $display("[INFO ] Filling Memory (streaming accesses) at time %t", $time);

	 // First set the address to 0x0000_0000
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR0, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR1, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR2, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR3, 8'h00);

	 // Select the streaming register
	 `EPP_MASTER.doEppAddrWrite(ERW_STREAM);
	 
	 // Stream the data into the register as little endian
	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_32B ; addrLoop++)
	 begin
	    `EPP_MASTER.doEppDataWrite(randomData[addrLoop][ 7: 0]);
	    `EPP_MASTER.doEppDataWrite(randomData[addrLoop][15: 8]);
	    `EPP_MASTER.doEppDataWrite(randomData[addrLoop][23:16]);
	    `EPP_MASTER.doEppDataWrite(randomData[addrLoop][31:24]);
	 end

	 // Stream the random array into the EPP regs
	 $display("[INFO ] Reading back the Memory (streaming accesses) at time %t", $time);
	 // First set the address to 0x0000_0000
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR0, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR1, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR2, 8'h00);
	 `EPP_MASTER.doEppRegWrite(ERW_ADDR3, 8'h00);

	 // Select the streaming register
	 `EPP_MASTER.doEppAddrWrite(ERW_STREAM);
	 
	 // Stream the data back out of the memory
	 for (addrLoop = 0 ; addrLoop < RAM_SIZE_32B ; addrLoop++)
	 begin
	    
	    `EPP_MASTER.doEppDataRead(readData8[0]);
	    `EPP_MASTER.doEppDataRead(readData8[1]);
	    `EPP_MASTER.doEppDataRead(readData8[2]);
	    `EPP_MASTER.doEppDataRead(readData8[3]);
	    
	    readData = {readData8[3], readData8[2], readData8[1], readData8[0]};
	    
	    if (randomData[addrLoop] === readData) 
	    begin
	       $display("[INFO ] EPP Data readback of Address 0x%x verified at time %t", addrLoop << 2, $time);
	    end
	    else
	    begin
	       $display("[ERROR] EPP Data readback of Address 0x%x FAILED, Read 0x%x, Expected 0x%x at time %t", addrLoop << 2, readData, randomData[addrLoop], $time); 	       testPass = 0;
	    end
	 end

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
