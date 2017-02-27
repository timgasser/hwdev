module TESTCASE ();

`include "mem_map.v"
`include "tb_defines.v"
   
  
   integer dataLoop;
   integer romAddrLoop;
	   
   reg [31:0] randomData [ROM_SIZE_WORD-1:0];

   initial
      begin
	 for (dataLoop = 0 ; dataLoop < ROM_SIZE_WORD ; dataLoop = dataLoop + 1)
	 begin
	    randomData[dataLoop] = $random();
	 end
      end
   
   initial
      begin

	 $display("[INFO ] ***** INST ROM TEST  *****");

	 $display("[INFO ] Storing random data in ROM Array");
	 for (romAddrLoop = 0 ; romAddrLoop < ROM_SIZE_WORD ; romAddrLoop = romAddrLoop + 1)
	 begin
	    `instBfmArray[romAddrLoop] = randomData[romAddrLoop];
	 end

	 $display("[INFO ] Reading ROM array back");
	 for (romAddrLoop = 0 ; romAddrLoop < ROM_SIZE_WORD ; romAddrLoop = romAddrLoop + 1)
	 begin
	    `instBfm.wbReadCompare (INST_ROM_BASE + (romAddrLoop << 2), 4'hF, randomData[romAddrLoop]);
	 end
	 
	 #1000;

	 $finish();
	 
      end


endmodule // TESTCASE
