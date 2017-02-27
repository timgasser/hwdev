// Regs test for EPP. Writes and reads all the registers in the EPP space.

module TESTCASE ();

// `define TB TB_ADI
// `define EPP_MASTER TB_ADI.epp_master_bfm

`include "epp_bus_bridge_defs.v"

   // Test writes and reads all register
   initial
      begin

	 bit testPass = 1;
	 bit verifyOk;
	     
	 
	 // Wait until Reset de-asserted
	 @(negedge `RST);
	 $display("[INFO ] Reset de-asserted at time %t", $time);

	 
	 `EPP_MASTER.doEppRegVerify(ERW_ADDR0, verifyOk); testPass &= verifyOk;
	 `EPP_MASTER.doEppRegVerify(ERW_ADDR1, verifyOk); testPass &= verifyOk;
	 `EPP_MASTER.doEppRegVerify(ERW_ADDR2, verifyOk); testPass &= verifyOk;
	 `EPP_MASTER.doEppRegVerify(ERW_ADDR3, verifyOk); testPass &= verifyOk;
	 
	 `EPP_MASTER.doEppRegVerify(ERW_DATA0, verifyOk); testPass &= verifyOk;
	 `EPP_MASTER.doEppRegVerify(ERW_DATA1, verifyOk); testPass &= verifyOk;
	 `EPP_MASTER.doEppRegVerify(ERW_DATA2, verifyOk); testPass &= verifyOk;
	 `EPP_MASTER.doEppRegVerify(ERW_DATA3, verifyOk); testPass &= verifyOk;

	 // Don't do any write-sensitive reads or writes
//	 `EPP_MASTER.doEppRegVerify(ERW_TRANS, verifyOk, 8'b0001_0011); testPass &= verifyOk;

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
	 $display("[FAIL] Epp test FAILED at time %t", $time);
	 $finish();
      end
   

   
endmodule // TESTCASE
