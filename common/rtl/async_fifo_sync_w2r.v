// Asynchronous FIFO Write to Read Pointer synchronisation
// Copied and pasted from Cliff Cummings' 2002 SNUG paper Rev 1.2
module ASYNC_FIFO_SYNC_W2R #(parameter ADDRSIZE = 4)
   (output reg [ADDRSIZE:0] rq2_wptr,
    input [ADDRSIZE:0] wptr,
    input rclk, rrst_n);
   
   reg [ADDRSIZE:0] rq1_wptr;
   
   always @(posedge rclk or negedge rrst_n)
     if (!rrst_n) {rq2_wptr,rq1_wptr} <= 0;
     else {rq2_wptr,rq1_wptr} <= {rq1_wptr,wptr};
   
endmodule

