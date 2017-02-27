// Asynchronous FIFO Pointer sync from read to write clock.
// Copied and pasted from Cliff Cummings' 2002 SNUG paper Rev 1.2
module ASYNC_FIFO_SYNC_R2W 
  #(parameter ADDRSIZE = 4)
   (output reg [ADDRSIZE:0] wq2_rptr,
    input [ADDRSIZE:0] rptr,
    input wclk, wrst_n);
   
   reg [ADDRSIZE:0] wq1_rptr;

   always @(posedge wclk or negedge wrst_n)
     if (!wrst_n) {wq2_rptr,wq1_rptr} <= 0;
     else {wq2_rptr,wq1_rptr} <= {wq1_rptr,rptr};

endmodule

