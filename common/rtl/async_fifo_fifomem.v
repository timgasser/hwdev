// Asynchronous FIFO Memory Storage.
// Copied and pasted from Cliff Cummings' 2002 SNUG paper Rev 1.2

module ASYNC_FIFO_FIFOMEM 
  #(parameter DATASIZE = 8, // Memory data word width
    parameter ADDRSIZE = 4
    ) // Number of mem address bits
   (
    output  [DATASIZE-1:0] rdata,
    input   [DATASIZE-1:0] wdata,
    input   [ADDRSIZE-1:0] waddr, raddr,
    input   wclken, wfull, wclk);


// Added a Xilinx DP RAM inside
// Port A = Write, B = Read
   DPRAM 
   #(.ADDR_WIDTH  (ADDRSIZE), 
     .DATA_WIDTH  (DATASIZE)
     )
   dpram_async_fifo
   (
    .CLK              (wclk             ),
    .ENA              (1'b1             ),
    .ENB              (1'b1             ),      
    .WRITE_EN_A_IN    (wclken && !wfull ),
    .ADDR_A_IN        (waddr            ),
    .ADDR_B_IN        (raddr            ),
    .WRITE_DATA_A_IN  (wdata            ),
    .READ_DATA_A_OUT  ( ), // Port A is write-only
    .READ_DATA_B_OUT  (rdata            )
    );

   
   
// `ifdef VENDORRAM
//    // instantiation of a vendor's dual-port RAM
//    vendor_ram mem (.dout(rdata), .din(wdata),
// 		   .waddr(waddr), .raddr(raddr),
// 		   .wclken(wclken),
// 		   .wclken_n(wfull), .clk(wclk));
// 
// `else
//    // RTL Verilog memory model
//    localparam DEPTH = 1<<ADDRSIZE;
//    reg [DATASIZE-1:0] mem [0:DEPTH-1];
//    assign rdata = mem[raddr];
//    always @(posedge wclk)
//      if (wclken && !wfull) mem[waddr] <= wdata;
//`endif
//
   
endmodule
