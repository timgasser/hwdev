//
// Dual-Port RAM with Enable on Each Port
//
// From http://www.xilinx.com/itp/xilinx10/books/docs/xst/xst.pdf page 195
//
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
//
// Synthesis report from Xilinx XST 12
// 
// Synthesizing (advanced) Unit <DPRAM>.                                                     
// INFO:Xst:3041 - The RAM <Mram_RamArray>, combined with <Mram_RamArray_ren>, will be implem
//     -----------------------------------------------------------------------               
//     | ram_type           | Block                               |          |               
//     -----------------------------------------------------------------------               
//     | Port A                                                              |               
//     |     aspect ratio   | 512-word x 32-bit                   |          |               
//     |     mode           | write-first                         |          |                   
//     |     clkA           | connected to signal <CLK>           | rise     |               
//     |     enA            | connected to signal <ENA>           | high     |               
//     |     weA            | connected to signal <WRITE_EN_A_IN> | high     |               
//     |     addrA          | connected to signal <ADDR_A_IN>     |          |               
//     |     diA            | connected to signal <WRITE_DATA_A_IN> |          |             
//     |     doA            | connected to signal <READ_DATA_A_OUT> |          |             
//     -----------------------------------------------------------------------               
//     | optimization       | speed                               |          |               
//     -----------------------------------------------------------------------                   
//     | Port B                                                              |               
//     |     aspect ratio   | 512-word x 32-bit                   |          |               
//     |     mode           | write-first                         |          |               
//     |     clkB           | connected to signal <CLK>           | rise     |               
//     |     enB            | connected to signal <ENB>           | high     |               
//     |     addrB          | connected to signal <ADDR_B_IN>     |          |               
//     |     doB            | connected to signal <READ_DATA_B_OUT> |          |             
//     -----------------------------------------------------------------------               
//     | optimization       | speed                               |          |                   
//       -----------------------------------------------------------------------               
//   Unit <DPRAM> synthesized (advanced).                                                      
//
//
//

module DPRAM
   #(parameter ADDR_WIDTH = 9 ,  // Default gives a 512 x 32 instance
     parameter DATA_WIDTH = 32
     )
   (
    input                    CLK              ,
    input                    ENA              ,
    input                    ENB              ,
    input                    WRITE_EN_A_IN    ,
    input   [ADDR_WIDTH-1:0] ADDR_A_IN        ,
    input   [ADDR_WIDTH-1:0] ADDR_B_IN        ,
    input   [DATA_WIDTH-1:0] WRITE_DATA_A_IN  ,
    output  [DATA_WIDTH-1:0] READ_DATA_A_OUT  ,
    output  [DATA_WIDTH-1:0] READ_DATA_B_OUT
    );


   reg [DATA_WIDTH-1:0] 	 RamArray [(2 ** ADDR_WIDTH)-1:0];

   reg [ADDR_WIDTH-1:0] 	 ReadAddrA;
   reg [ADDR_WIDTH-1:0] 	 ReadAddrB;

   assign READ_DATA_A_OUT = RamArray[ReadAddrA];
   assign READ_DATA_B_OUT = RamArray[ReadAddrB];

   always @(posedge CLK) begin
      if (ENA)
      begin
	 if (WRITE_EN_A_IN)
	    RamArray[ADDR_A_IN] <= WRITE_DATA_A_IN;
	 ReadAddrA <= ADDR_A_IN; // Note this line doesn't depend on WRITE_EN_A_IN
      end
      if (ENB)
	 ReadAddrB <= ADDR_B_IN;
   end
   
endmodule