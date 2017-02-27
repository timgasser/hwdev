// Asynchronous FIFO Top-level. Instantiates the pointers, sync blocks, and RAM/storage.
// Copied and pasted from Cliff Cummings' 2002 SNUG paper Rev 1.2
module ASYNC_FIFO
  #(parameter DSIZE = 8,
    parameter ASIZE = 4)
   (
    output [DSIZE-1:0] rdata,
    output wfull,
    output rempty,
    input [DSIZE-1:0] wdata,
    input winc, wclk, wrst_n,
    input rinc, rclk, rrst_n
    );

   wire [ASIZE-1:0] waddr, raddr;
   wire [ASIZE:0]   wptr, rptr, wq2_rptr, rq2_wptr;

   ASYNC_FIFO_SYNC_R2W 
      #(.ADDRSIZE (ASIZE))
      sync_r2w 
     (
      .wq2_rptr  (wq2_rptr  ), 
      .rptr      (rptr      ),
      .wclk      (wclk      ), 
      .wrst_n    (wrst_n    )
      );

   ASYNC_FIFO_SYNC_W2R 
      #(.ADDRSIZE (ASIZE))
   sync_w2r 
      (
       .rq2_wptr  (rq2_wptr  ), 
       .wptr      (wptr      ),
       .rclk      (rclk      ), 
       .rrst_n    (rrst_n    )
       );
   
   ASYNC_FIFO_FIFOMEM 
     #(.DATASIZE  (DSIZE), 
       .ADDRSIZE  (ASIZE) ) 
   fifomem
     (
      .rdata     (rdata    ), 
      .wdata     (wdata    ),
      .waddr     (waddr    ), 
      .raddr     (raddr    ),
      .wclken    (winc     ), 
      .wfull     (wfull    ),
      .wclk      (wclk     )
      );

   ASYNC_FIFO_RPTR_EMPTY
     #(.ADDRSIZE (ASIZE) )
   rptr_empty
     (.rempty    (rempty   ),
      .raddr     (raddr    ),
      .rptr      (rptr     ), 
      .rq2_wptr  (rq2_wptr ),
      .rinc      (rinc     ), 
      .rclk      (rclk     ),
      .rrst_n    (rrst_n   )
      );

   ASYNC_FIFO_WPTR_FULL 
     #(.ADDRSIZE (ASIZE) )
   wptr_full
     (.wfull     (wfull    ), 
      .waddr     (waddr    ),
      .wptr      (wptr     ), 
      .wq2_rptr  (wq2_rptr ),
      .winc      (winc     ), 
      .wclk      (wclk     ),
      .wrst_n    (wrst_n   )
      );

endmodule
