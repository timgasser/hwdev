module CLK_RST_GEN
   #(parameter CLK_HALF_PERIOD = 10 // 100MHz clock
//     parameter RST_TIME        = CLK_HALF_PERIOD * 10  // How long to assert the reset
   )
   (
    output     CLK_OUT,
    output reg RST_OUT
    );

   parameter RST_CLKS = 4;

   reg 	       Clk;

   assign CLK_OUT = Clk;
   
   initial
      begin
	 // Set the initial values of clock and reset
        Clk      = 1'b0;
        RST_OUT <= 1'b1; // Always use a non-blocking for reset, or it will be picked up on the same clock edge it deasserts on

	repeat (RST_CLKS)
           @(posedge Clk);

        RST_OUT <= 1'b0; // Always use a non-blocking for reset, or it will be picked up on the same clock edge it deasserts on

     end

   always #CLK_HALF_PERIOD Clk = !Clk;
   
   
endmodule
