module TESTCASE ();

//`define TB TB_ADI
//`define EPP_MASTER TB_ADI.epp_master_bfm

`include "epp_bus_bridge_defs.v"
   
   initial
      begin

	 int writeData = 8'hA5;
	 int readData;

	 int testPass = 1;

	 // Wait until Reset de-asserted
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 // Do Address write/read/verify
	 $display("[INFO ] Writing EPP Address register at time %t", $time);
	 `EPP_MASTER.doEppAddrWrite(writeData);

	 $display("[INFO ] Reading back EPP Address register at time %t", $time);
	 `EPP_MASTER.doEppAddrRead(readData);

	 if (writeData === readData) 
	 begin
	    $display("[INFO ] EPP Address readback verified at time %t", $time);
	 end
	 else
	 begin
	    $display("[ERROR] EPP Address readback FAILED at time %t", $time);
	    testPass = 0;
	 end
	 
	 // Do Data write/read/verify from address 0x13
	 `EPP_MASTER.doEppAddrWrite(ERW_DATA3);

	 $display("[INFO ] Writing EPP Address register at time %t", $time);
	 `EPP_MASTER.doEppDataWrite(writeData);

	 $display("[INFO ] Reading back EPP Address register at time %t", $time);
	 `EPP_MASTER.doEppDataRead(readData);

	 if (writeData === readData) 
	 begin
	    $display("[INFO ] EPP Data readback verified at time %t", $time);
	 end
	 else
	 begin
	    $display("[ERROR] EPP Data readback FAILED at time %t", $time);
	    testPass = 0;
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
	 #100us;
	 $display("[ERROR] Epp test timed out at time %t", $time);
	 $finish();
      end
   
   
endmodule // TESTCASE
