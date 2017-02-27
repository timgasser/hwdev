// CDC for VGA Controller.
// Converts incoming pixel data from WB clock to VGA Pixel clock.
// Converts HSYNC and VSYNC falling edges for WB clock pulse

module VGA_CDC
  (
    // Clocks and resets
   input         CLK_VGA        , // VGA Pixel clock
   input         RST_ASYNC_VGA  , // Reset de-asserted with PCLK
   
   input         CLK_WB         , // Framebuffer clock
   input         RST_ASYNC_WB   , // Reset de-asserted with FB clock

   // VGA-side ports
   output  [7:0] VGA_DATA_OUT       ,
   input         VGA_DATA_REQ_IN    ,
   input         VGA_ACTIVE_LINE_IN ,
   input         VGA_HS_IN          ,
   input         VGA_VS_IN          ,

   // WB-side ports
   input         WB_DATA_EN_IN      ,
   input   [7:0] WB_DATA_IN         ,
   output        WB_DATA_FULL_OUT   ,
   output        WB_ACTIVE_LINE_OUT ,
   output        WB_VS_STB_OUT      ,
   output        WB_HS_STB_OUT      ,

   // Root Counter ports
   output        WB_RCNT_ACTIVE_ROW_OUT ,
   output        WB_RCNT_ACTIVE_COL_OUT

   );

   // wires/regs
   reg [2:0] 	 VgaVsPipe;
   reg [2:0] 	 VgaHsPipe;
   reg [1:0] 	 VgaActiveLinePipe;
   reg [1:0] 	 VgaDataReqPipe;

   wire 	 FifoReadEmpty;
   
   // internal assigns

   // external assigns
   assign WB_VS_STB_OUT      = (VgaVsPipe[2] & ~VgaVsPipe[1]);
   assign WB_HS_STB_OUT      = (VgaHsPipe[2] & ~VgaHsPipe[1]);
   assign WB_ACTIVE_LINE_OUT =  VgaActiveLinePipe[1];

   assign WB_RCNT_ACTIVE_ROW_OUT = VgaActiveLinePipe[1];
   assign WB_RCNT_ACTIVE_COL_OUT = VgaDataReqPipe[1];
   
   // VSYNC resync pipe. Generate a CLK_WB pulse on a falling edge of VSYNC
   always @(posedge CLK_WB or posedge RST_ASYNC_WB)
   begin : VSYNC_RESYNC
      if (RST_ASYNC_WB)
      begin
	 VgaVsPipe <= 3'b000;
      end
      else 
      begin
	 VgaVsPipe <= {VgaVsPipe[1:0], VGA_VS_IN};
      end
   end
   
   // HSYNC resync pipe. Generate a CLK_WB pulse on a falling edge of HSYNC
   always @(posedge CLK_WB or posedge RST_ASYNC_WB)
   begin : HSYNC_RESYNC
      if (RST_ASYNC_WB)
      begin
	 VgaHsPipe <= 3'b000;
      end
      else 
      begin
	 VgaHsPipe <= {VgaHsPipe[1:0], VGA_HS_IN};
      end
   end

   // VGA Active resync pipe. Send level back to WB-domain DMA
   // Delayed de-assertion is ok, as the DMA knows how much data to read
   always @(posedge CLK_WB or posedge RST_ASYNC_WB)
   begin : VGA_ACTIVE_RESYNC
      if (RST_ASYNC_WB)
      begin
	VgaActiveLinePipe <= 2'b00;
      end
      else 
      begin
	 VgaActiveLinePipe <= {VgaActiveLinePipe[0], VGA_ACTIVE_LINE_IN};
      end
   end
   
   // VGA Active column pipe (used by root counter)
   always @(posedge CLK_WB or posedge RST_ASYNC_WB)
   begin : VGA_DATA_REQ_RESYNC
      if (RST_ASYNC_WB)
      begin
	VgaDataReqPipe <= 2'b00;
      end
      else 
      begin
	 VgaDataReqPipe <= {VgaDataReqPipe[0], VGA_DATA_REQ_IN};
      end
   end
   
   // Asynchronous FIFO declaration
   
   ASYNC_FIFO 
  #(
    .DSIZE ( 8),
    .ASIZE (10)
    )
   async_fifo_vga
     (
      .wclk   (CLK_WB         	),
      .wrst_n (~RST_ASYNC_WB  	),
      
      .rclk   (CLK_VGA        	),
      .rrst_n (~RST_ASYNC_VGA 	),
      
      .winc   (WB_DATA_EN_IN  	),
      .wfull  (WB_DATA_FULL_OUT	),
      .wdata  (WB_DATA_IN     	),
      
      .rinc   (VGA_DATA_REQ_IN	),
      .rempty (FifoReadEmpty	),
      .rdata  (VGA_DATA_OUT   	)  
       
      );
   
endmodule // VGA_CDC
