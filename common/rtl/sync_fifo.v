module SYNC_FIFO
  #(
    parameter D_P2   = 4 , // Depth of the fifo (power-of-2) in units of write width
    parameter BW     = 8 , // Base width for write and read data widths
    parameter WWM    = 1 , // Write Width Multiplier for Write Data 
    parameter RWM    = 1 , // Read  Width Multiplier for Write Data
    parameter USE_RAM   = 0   // Use a RAM for the FIFO storage? 1 = RAM, 0 = registers.
    )
   (
    input                   WR_CLK         , // Write and read clocks are balanced
    input                   RD_CLK         ,
//    input                   EN             ,
    input                   RST_SYNC       ,
    input                   RST_ASYNC      ,

    input                   WRITE_EN_IN    ,
    input  [(BW * WWM)-1:0] WRITE_DATA_IN  ,
    output                  WRITE_FULL_OUT ,

    input                   READ_EN_IN     ,
    output [(BW * RWM)-1:0] READ_DATA_OUT  ,
    output                  READ_EMPTY_OUT 
    );


   // How it works
   // Write pointer : Increments on every write (regardless of write width). The FifoDataReg uses
   // the write pointer to index it.
   // Read pointer : Increments on every read by the read width (in bits), as the FifoDataReg has
   // to be flattened before being indexed by the read pointer.
   // Fifo counter : Units of the base width. Increments by the write width multiplier on a write, 
   // and decrements by the read width multiplier on a read.
   
   // Derived parameters
   parameter D   = (2 ** D_P2)                 ; // Depth (units of write width)
   parameter RD  = (2 ** (D_P2 + WWM - RWM))   ; // Read Depth (units of read width)
   parameter WW  = BW * WWM                    ; // Write width (bits)
   parameter RW  = BW * RWM                    ; // Read Width (bits)
//   parameter FCW = D_P2 + WWM + RWM            ; // Fifo Counter Width (units of Write Width multiples)

   parameter WPW = D_P2                        ; // Write Pointer width (write unit width multiples)
   parameter RPW = D_P2 + WWM - RWM            ; // Read Pointer width 
   
   // wires / regs

   // Pointers: They both increment by 1 when read or written. They have an extra bit to check
   // for FIFO full and empty conditions 
   reg  [WPW  :0]  WritePtr                         ; // Depth in units of Write Width
   wire [WPW-1:0]  WritePtrWrap = WritePtr[WPW-1:0] ; // Wrapping write pointer 
   reg  [RPW  :0]  ReadPtr                          ; // Read Pointer in units of read width
   wire [RPW-1:0]  ReadPtrWrap  = ReadPtr[RPW-1:0]  ; // Wrapping read pointer

   wire  WriteEn   ;
   wire  ReadEn    ;
   wire  WriteFull ;
   wire  ReadEmpty ;

   wire  PtrMatch  ; // Set if the REad and write pointers match (without checking MSB for empty/full)

   generate if (WPW > RPW)
   begin : WRITE_GT_READ
      assign PtrMatch = (WritePtr[WPW-1:WPW-RPW] == ReadPtr[RPW-1:0]); // have to truncate the write pointer to match read width
   end
   else if (WPW == RPW)
   begin : WRITE_EQ_READ
     assign  PtrMatch = (WritePtr[WPW-1:0] == ReadPtr[RPW-1:0]); // can compare directly
   end
   else if (WPW < RPW)
   begin : WRITE_LT_READ
      assign PtrMatch = (WritePtr[WPW-1:0] == ReadPtr[RPW-1:RPW-WPW]); // have to truncate the read pointer to match write width
   end
   endgenerate
   
   
   // Gate the write and read enables with FIFO full/empty.
   // Use these wires, not the READ/WRITE_EN_INs
   assign   WriteEn = WRITE_EN_IN & ~WriteFull;
   assign   ReadEn  = READ_EN_IN  & ~ReadEmpty;

   // Internal assigns
   assign WriteFull = ((WritePtr[WPW] ^  ReadPtr[RPW]) && PtrMatch);
   assign ReadEmpty = ((WritePtr[WPW] == ReadPtr[RPW]) && PtrMatch);
   
   // External assigns
   assign WRITE_FULL_OUT = WriteFull;
   assign READ_EMPTY_OUT = ReadEmpty;

`ifdef REPORT_FIFO
   initial
      begin
	 $display("");
	 $display("[INFO ] FIFO parameters for %m");
	 $display("[INFO ] --------------------------------------------");
	 $display("[INFO ] SIZE = %03d (bits)", (D*WW));
	 $display("[INFO ] D_P2 = %03d (Depth as power-of-2, units of WW = %03d)", D_P2, WW);
	 $display("[INFO ] D    = %03d (Write 2d array depth, units of WW = %03d)", D, WW);
	 $display("[INFO ] RD   = %03d (Read 2d array depth, units of RW = %03d)", RD, RW);
	 $display("[INFO ] BW   = %03d (Base width for read and write data widths)", BW);
	 $display("[INFO ] WWM  = %03d (Write width multiplier)" , WWM);
	 $display("[INFO ] RWM  = %03d (Read width multiplier)" , RWM);
	 $display("[INFO ] WW   = %03d (Write data width in bits)" , WW);
	 $display("[INFO ] RW   = %03d (Read data width in bits)", RW);
	 $display("[INFO ] WPW  = %03d (Write Pointer Width - in units of WW = %03d)", WPW, WW);
	 $display("[INFO ] RPW  = %03d (Read Pointer Width - in units of RW = %03d)", RPW, RW);
	 $display("");
      end
`endif
   
   // Write Pointer. Increments on write (if not full), and wraps.
   always @(posedge WR_CLK or posedge RST_ASYNC)
   begin
      if (RST_ASYNC)
      begin
	 WritePtr <= {WPW{1'b0}};
      end
      else if (RST_SYNC)
      begin
	 WritePtr <= {WPW{1'b0}};
      end
      else // if (EN)
      begin
	 if (WriteEn)
	 begin
	    WritePtr <= WritePtr + 1;
	 end
      end
   end
   
   // Read Pointer. Increments on read (if not empty), and wraps.
   always @(posedge RD_CLK or posedge RST_ASYNC)
   begin
      if (RST_ASYNC)
      begin
	 ReadPtr <= {RPW{1'b0}};
      end
      else if (RST_SYNC)
      begin
	 ReadPtr <= {RPW{1'b0}};
      end
      else // if (EN)
      begin
	 if (ReadEn)
	 begin
	    ReadPtr <= ReadPtr + 1;
	 end
      end
   end

   // Variable used to index fifo register data storage.
   genvar FifoVar;
   genvar i, j, k;

   genvar l, m;
   
   generate if (!USE_RAM)
   begin : FIFO_REGS_STORAGE

      // Use registers for the FIFO storage (not recommended for large > 1kB fifos)
      reg  [WW-1:0]     FifoDataReg    [D-1:0]; 
      wire [(D*WW)-1:0] ReadDataArray  ; // Flatten the read array
      wire [RW-1:0] 	ReadDataMem    [RD-1:0]; 

      
      for (i = 0 ; i < D ; i = i + 1)
      begin : FIFO_WRITE_DATA_REG
	 
	 always @(posedge WR_CLK or posedge RST_ASYNC)
	 begin
	    if (RST_ASYNC)
	    begin
	       FifoDataReg[i] <= {WW{1'b0}};
	    end
	    else if (RST_SYNC)
	    begin
	       FifoDataReg[i] <= {WW{1'b0}};
	    end
	    else // if (EN)
	    begin
	       if (WriteEn && (i == WritePtr[WPW-1:0]))
	       begin
		  // FifoDataReg[(WritePtr*BW) +: WW] <= WRITE_DATA_IN;
		  FifoDataReg[i] <= WRITE_DATA_IN;
	       end
	    end
	 end
      end

      // First loop goes between 0 and the depth of the write memory array
      for (j = 0 ; j < D ; j = j + 1)
      begin : READ_DATA_WORD_FLATTEN

	 // Second loop goes between 0 and the bit within the word of the mem array
	 for (k = 0 ; k < WW ; k = k + 1)
	 begin : READ_DATA_ARRAY_FILL
	    assign ReadDataArray[(j*WW) + k] = FifoDataReg[j][k];
	 end
	 
      end


      // First loop goes between 0 and the depth of the write memory array
      for (l = 0 ; l < RD; l = l + 1)
      begin : READ_DATA_WORD_PACK

	 // Second loop goes between 0 and the bit within the word of the mem array
	 for (m = 0 ; m < RW ; m = m + 1)
	 begin : READ_DATA_MEM_PACK
	    assign ReadDataMem[l][m] = ReadDataArray[(l * RW)+m];
	 end
	 
      end

      assign READ_DATA_OUT = ReadDataMem[ReadPtr[RPW-1:0]]; // ReadPtr has an extra bit for full/empty comparison

      
//      assign READ_DATA_OUT = FifoDataReg[(ReadPtr*BW) +: RW];
           
   end
   else
   begin : FIFO_RAM_STORAGE
      // Add a DPRAM into (probably used for VGA controller line buffer).
      
   end
   endgenerate
   
   
   
endmodule // SYNC_FIFO


