module TESTCASE ();

`include "tb_defines.v"

   initial
      begin : main_test
	 
	 @(TB_FPGA_TOP.fpga_top.fpga_bus_top.digital_top.cpu_core.EndOfSim);
	 
	 $display("INFO: Break instruction detected in EX stage at time $t", $time);
	 $display("INFO: Flushing nops through the pipeline at time $t", $time);
	 
	 @(posedge TB_FPGA_TOP.CLK);
	 @(posedge TB_FPGA_TOP.CLK);
	 @(posedge TB_FPGA_TOP.CLK);
	 @(posedge TB_FPGA_TOP.CLK);
	 @(posedge TB_FPGA_TOP.CLK);
	 
	 $display("INFO: Waiting for a loong time for UART to loop back $t", $time);
	 #10_000;
	 
	 $display("INFO: Test finished at $t", $time);

	 $finish();
	 
      end // block: main_test
   
   
   
endmodule