module TESTCASE ();

`include "mem_map.v"
`include "tb_defines.v"
   
   integer dataLoop;
   integer ramAddrLoop;

   reg [31:0] dataBfmArrayWd;
   
   reg [31:0] randomData [RAM_SIZE_WORD-1:0];
	      
   initial
      begin
	 for (dataLoop = 0 ; dataLoop < RAM_SIZE_WORD ; dataLoop = dataLoop + 1)
	 begin
	    randomData[dataLoop] = $random();
	 end
      end
   
   initial
      begin

	 $display("[INFO ] ***** DATA RAM TEST: Running 32 bit incremental test *****");
	 for (ramAddrLoop = 0 ; ramAddrLoop < RAM_SIZE_WORD ; ramAddrLoop = ramAddrLoop + 1)
	 begin
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'hF, randomData[ramAddrLoop]);
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'hF, randomData[ramAddrLoop]);
	 end
	 
	 $display("[INFO ] ***** Checking and Clearing Data Ram ***** ");
	 for (ramAddrLoop = 0 ; ramAddrLoop < RAM_SIZE_WORD ; ramAddrLoop = ramAddrLoop + 1)
	 begin
	    // combine the byte RAMs into a word
	    dataBfmArrayWd = {`dataBfmArrayB3[ramAddrLoop], `dataBfmArrayB2[ramAddrLoop], `dataBfmArrayB1[ramAddrLoop], `dataBfmArrayB0[ramAddrLoop]};
	    
	    if (randomData[ramAddrLoop] === dataBfmArrayWd)
	    begin
	       `dataBfmArrayB3[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB2[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB1[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB0[ramAddrLoop] = 8'hxx;
	    end
	    else
	    begin
	       $display("[ERROR] RAM Data at Address 0x%h is 0x%h, Expected 0x%h", ramAddrLoop, dataBfmArrayWd, randomData[ramAddrLoop]);
	    end
	 end
	 
 	 $display("[INFO ] ***** DATA RAM TEST: Running 16 bit incremental test *****");
	 for (ramAddrLoop = 0 ; ramAddrLoop < RAM_SIZE_WORD ; ramAddrLoop = ramAddrLoop + 1)
	 begin
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h3, {16'h0000, randomData[ramAddrLoop][15:0]}); 
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h3, {16'h0000, randomData[ramAddrLoop][15:0]});
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'hC, {randomData[ramAddrLoop][31:16], 16'h0000}); 
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'hC, {randomData[ramAddrLoop][31:16], 16'h0000});
	 end
	 
	 $display("[INFO ] ***** Checking and Clearing Data Ram ***** ");
	 for (ramAddrLoop = 0 ; ramAddrLoop < RAM_SIZE_WORD ; ramAddrLoop = ramAddrLoop + 1)
	 begin
	    // combine the byte RAMs into a word
	    dataBfmArrayWd = {`dataBfmArrayB3[ramAddrLoop], `dataBfmArrayB2[ramAddrLoop], `dataBfmArrayB1[ramAddrLoop], `dataBfmArrayB0[ramAddrLoop]};
	    
	    if (randomData[ramAddrLoop] === dataBfmArrayWd)
	    begin
	       `dataBfmArrayB3[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB2[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB1[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB0[ramAddrLoop] = 8'hxx;
	    end
	    else
	    begin
	       $display("[ERROR] RAM Data at Address 0x%h is 0x%h, Expected 0x%h", ramAddrLoop, dataBfmArrayWd, randomData[ramAddrLoop]);
	    end
	 end
	 
 	 $display("[INFO ] ***** DATA RAM TEST: Running 8 bit incremental test *****");
	 for (ramAddrLoop = 0 ; ramAddrLoop < RAM_SIZE_WORD ; ramAddrLoop = ramAddrLoop + 1)
	 begin
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h1, {24'h000000, randomData[ramAddrLoop][ 7: 0]}); 
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h1, {24'h000000, randomData[ramAddrLoop][ 7: 0]});
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h2, {16'h0000, randomData[ramAddrLoop][15: 8], 8'h00}); 
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h2, {16'h0000, randomData[ramAddrLoop][15: 8], 8'h00});
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h4, {8'h00, randomData[ramAddrLoop][23:16], 16'h0000}); 
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h4, {8'h00, randomData[ramAddrLoop][23:16], 16'h0000});
	    `dataBfm.wbWrite       (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h8, {randomData[ramAddrLoop][31:24] , 24'h000000 }); 
	    `dataBfm.wbReadCompare (DATA_RAM_BASE + (ramAddrLoop << 2), 4'h8, {randomData[ramAddrLoop][31:24] , 24'h000000 });
	 end
	 
	 $display("[INFO ] ***** Checking and Clearing Data Ram ***** ");
	 for (ramAddrLoop = 0 ; ramAddrLoop < RAM_SIZE_WORD ; ramAddrLoop = ramAddrLoop + 1)
	 begin
	    // combine the byte RAMs into a word
	    dataBfmArrayWd = {`dataBfmArrayB3[ramAddrLoop], `dataBfmArrayB2[ramAddrLoop], `dataBfmArrayB1[ramAddrLoop], `dataBfmArrayB0[ramAddrLoop]};
	    
	    if (randomData[ramAddrLoop] === dataBfmArrayWd)
	    begin
	       `dataBfmArrayB3[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB2[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB1[ramAddrLoop] = 8'hxx;
	       `dataBfmArrayB0[ramAddrLoop] = 8'hxx;
	    end
	    else
	    begin
	       $display("[ERROR] RAM Data at Address 0x%h is 0x%h, Expected 0x%h", ramAddrLoop, dataBfmArrayWd, randomData[ramAddrLoop]);
	    end
	 end

	 $display("[INFO ] **********************************************************");

	 $display("");
	 $display("");
	 
	 
	 
	 #1000;

	 $finish();
	 
      end


endmodule // TESTCASE
