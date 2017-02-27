//
// Single-ported RAM
// Write-First Mode (template 1)
// From http://www.xilinx.com/itp/xilinx10/books/docs/xst/xst.pdf page 169
//
// Available sizes (from http://www.xilinx.com/support/documentation/user_guides/ug331.pdf page 155)
//
// 16Kx1
// 8Kx2
// 4Kx4
// 2Kx8 (no parity)
// 2Kx9 (x8 + parity)
// 1Kx16 (no parity)
// 1Kx18 (x16 + 2 parity)
// 512x32 (no parity)
// 512x36 (x32 + 4 parity)
// 256x72 (single-port only)

// Synthesised in XST 12.2 M.63c as below:
// 
// INFO:Xst:3040 - The RAM <Mram_RamArray> will be implemented as a BLOCK RAM, absorbing the following register(s): <READ_DATA_OUT>
//     -----------------------------------------------------------------------
//     | ram_type           | Block                               |          |
//     -----------------------------------------------------------------------
//     | Port A                                                              |
//     |     aspect ratio   | 512-word x 32-bit                   |          |
//     |     mode           | write-first                         |          |
//     |     clkA           | connected to signal <CLK>           | rise     |
//     |     enA            | connected to signal <EN>            | high     |
//     |     weA            | connected to signal <WRITE_EN_IN>   | high     |
//     |     addrA          | connected to signal <ADDR_IN>       |          |
//     |     diA            | connected to signal <WRITE_DATA_IN> |          |
//     |     doA            | connected to signal <READ_DATA_OUT> |          |
//     -----------------------------------------------------------------------
//     | optimization       | speed                               |          |
//     -----------------------------------------------------------------------
// Unit <SPRAM> synthesized (advanced).
// 

module SPRAM 
   #(parameter ADDR_WIDTH = 9 ,  // Default gives a 512 x 32 instance
     parameter DATA_WIDTH = 32
     )
     (
      input                          CLK            ,
      input                          EN             ,
      input                          WRITE_EN_IN    ,
      input       [ADDR_WIDTH-1:0]   ADDR_IN        ,
      input       [DATA_WIDTH-1:0]   WRITE_DATA_IN  ,
      output reg  [DATA_WIDTH-1:0]   READ_DATA_OUT
      );

   
   reg [DATA_WIDTH-1:0]  RamArray [(2 ** ADDR_WIDTH)-1:0];
   
   always @(posedge CLK)
   begin
      if (EN)
      begin
	 if (WRITE_EN_IN)
	 begin
	    RamArray[ADDR_IN] <= WRITE_DATA_IN;
	    READ_DATA_OUT     <= WRITE_DATA_IN;
	 end
	 else
	    READ_DATA_OUT <= RamArray[ADDR_IN];
      end
   end
   
endmodule