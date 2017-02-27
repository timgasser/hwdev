module INST_ROM (clk, en, addr, data);
    input      clk;
    input      en;
    input      [12:0] addr;
    output reg [31:0] data;

    reg [31:0] 	      RomArray [2047:0]; // 8kB of ROM

   
    always @(posedge clk) begin
        if (en)
	begin
	   data <= RomArray[addr[12:0]]; // Address is byte aligned, drop bottom two bits 
	end
    end
   
endmodule
