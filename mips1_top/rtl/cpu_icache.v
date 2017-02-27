// *** INSERT MODULE HEADER *** 


// Cache parameters
// - Direct mapped
// - 4kB
// - Line width is 4 words (16 bytes)
//
// [31:12] (20 bits) - Physical TAG
// [11: 4] ( 8 bits) - Line index (4 kB / (4 x 32)) = 256. 8 bits are required to index 256 lines
// [ 2: 0] ( 3 bits) - Word offset within line index. Must be 3 bits as 8 words per line

module CPU_ICACHE
   (
    input           CLK       ,
    input           RST_SYNC  ,

    // Core-side Instruction Memory (IM) - Pipelined wishbone B4 Spec
    input   [31:0] CORE_ADR_IN      , // Master: Address of current transfer
    input          CORE_CYC_IN      , // Master: High while whole transfer is in progress
    input          CORE_STB_IN      , // Master: High while the current beat in burst is active
    input          CORE_WE_IN       , // Master: Write Enable (1), Read if 0
    input   [ 3:0] CORE_SEL_IN      , // Master: Byte enables of write (one-hot)
    output         CORE_STALL_OUT   , // Slave : Not ready to accept new address
    output         CORE_ACK_OUT     , // Slave:  Acknowledge of transaction
    output         CORE_ERR_OUT     , // Slave:  Transaction caused error
    output  [31:0] CORE_DAT_RD_OUT  , // Slave:  Read data
    input   [31:0] CORE_DAT_WR_IN   , // Master: Write data
    
    // Memory-side connections (IC) - Pipelined wishbone B4 Spec
    output  [31:0] CACHE_ADR_OUT    , // Master: Address of current transfer
    output         CACHE_CYC_OUT    , // Master: High while whole transfer is in progress
    output         CACHE_STB_OUT    , // Master: High while the current beat in burst is active
    output         CACHE_WE_OUT     , // Master: Write Enable (1), Read if 0
    output  [ 3:0] CACHE_SEL_OUT    , // Master: Byte enables of write (one-hot)
    output [ 2:0]  CACHE_CTI_OUT    , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    output [ 1:0]  CACHE_BTE_OUT    , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap

    input          CACHE_ACK_IN     , // Slave:  Acknowledge of transaction
    input          CACHE_STALL_IN   , // Slave:  Not ready to accept a new address
    input          CACHE_ERR_IN     , // Slave:  Not ready to accept a new address

    input   [31:0] CACHE_DAT_RD_IN  , // Slave:  Read data
    output  [31:0] CACHE_DAT_WR_OUT   // Master: Write data
   
    );

`include "wb_defs.v"
   
   // typedefs

   // Wires

   // Bus interface

//   wire [31:0] 	   BusStartAddr;
   wire 	   BusReadReq;
   wire 	   BusReadAck;
//   wire 	   BusWriteReq;
//   wire          BusWriteAck;
   wire 	   BusLastAck;
   wire [31:0] 	   BusReadData;
   
   // TAG RAM Interface (256 x 20)
   // Single port; write first BRAM
   wire 	   TagRamStoreEn;
   wire 	   TagRamFlushEn;
   reg  	   TagRamFlushEnReg;
   wire [9:2] 	   TagRamAddr         ; // Word aligned; 8 bit address - Line Index
   wire 	   TagRamWriteEn     ;
   wire [20:0] 	   TagRamWriteData   ; // {1 bit VALID, 20 bits TAG}
   wire [20:0] 	   TagRamReadData     ; // {1 bit VALID, 20 bits TAG}

   // CACHE RAM Interface (1024 x 32). 
   // Dual port
   wire [11:2] 	   CacheRamReadAddr  ; // Word aligned, 10 bit address {Line Index (8), Word offset (2)}
   wire [11:2] 	   CacheRamWriteAddr ; // Word aligned, 10 bit address {Line Index (8), Word offset (2)}
   wire 	   CacheRamWriteEn   ;
   wire [31:0] 	   CacheRamReadData   ;    
   wire [31:0] 	   CacheRamWriteData     ;   
   
   // Incoming address (used to index TAG ram and CACHE ram)
   wire [19:0] 	   Tag;
   wire [7:0] 	   LineIndex;
   wire [1:0] 	   WdIndex;

   // Registered address (used to compare against TAG ram)
   reg [31:0] 	   CoreAdrReg;
   reg [19:0] 	   TagReg;
   reg  [7:0] 	   LineIndexReg;
   reg  [1:0] 	   WdIndexReg;

   wire [9:0] 	   LineWdIndex;
    wire [9:0] 	   LineWdIndexReg;
  
   wire 	   CoreWriteAddrStb    ; // assign = CORE_CYC_IN & CORE_STB_IN & CORE_WE_IN & ~CORE_STALL_OUT
//   reg 		   CoreWriteAddrStbReg ;
   wire 	   CoreReadAddrStb     ; // assign = CORE_CYC_IN & CORE_STB_IN & ~CORE_WE_IN & ~CORE_STALL_OUT
   reg  	   CoreReadAddrStbReg  ; 
   wire 	   CoreAddrStb         ; // assign = CoreReadAddrStb | CoreWriteAddrStb

   wire 	   TagHit              ;
   wire 	   ValidHit            ;
   wire 	   ValidTagHit         ;

   // Fill counter
   reg [1:0] 	   FillCntVal;
   
   // Bus Master
    
   
   // assigns

   // Internal assigns
   assign Tag        = CORE_ADR_IN[31:12];
   assign LineIndex  = CORE_ADR_IN[11: 4]; // 4kB cache size 
   assign WdIndex    = CORE_ADR_IN[ 3: 2]; // 4-word lines

   assign TagReg        = CoreAdrReg[31:12];
   assign LineIndexReg  = CoreAdrReg[11: 4]; // 4kB cache size 
   assign WdIndexReg    = CoreAdrReg[ 3: 2]; // 4-word lines

   // Combinatorial assigns
   assign  CoreWriteAddrStb = CORE_CYC_IN & CORE_STB_IN &  CORE_WE_IN; //  & ~CORE_STALL_OUT; <- don't check stalls for writes
   assign  CoreReadAddrStb  = CORE_CYC_IN & CORE_STB_IN & ~CORE_WE_IN & ~CORE_STALL_OUT;
   assign  CoreAddrStb      = CoreReadAddrStb | CoreWriteAddrStb;

   // TAG-matching signals
   assign TagHit       = (TagRamReadData[19:0] == TagReg);
   assign ValidHit     = TagRamReadData[20];
   assign ValidTagHit  = ValidHit & TagHit;
   
   // Request a line fill when the address has been registered and there's no matching TAG / Valid
   assign BusReadReq = CORE_CYC_IN & CoreReadAddrStbReg & ~ValidTagHit;
   
   // CORE-side interface
   assign CORE_ACK_OUT    = TagRamFlushEn ? 1'b0 : TagRamFlushEnReg ? 1'b1 : ValidTagHit  ;
   assign CORE_STALL_OUT  = (TagRamFlushEnReg) | (CoreReadAddrStbReg & ~ValidTagHit);
   assign CORE_DAT_RD_OUT = CacheRamReadData ;
   assign CORE_ERR_OUT    = 1'b0;
   
   // TAG RAM interface
   assign TagRamStoreEn        	= BusReadReq & BusReadAck & BusLastAck; // Store TAG when last cache entry filled
   assign TagRamFlushEn        	= /* (4'hF != CORE_SEL_IN) & */ CORE_WE_IN & CoreWriteAddrStb & ~CORE_STALL_OUT; // Invalidate cache line on write
   assign TagRamAddr           	= BusReadReq ? LineIndexReg : LineIndex ; // TagRamFlushEn ? LineIndex : LineIndexReg;
   assign TagRamWriteEn        	= TagRamStoreEn | TagRamFlushEn;
   assign TagRamWriteData[20]  	= TagRamFlushEn ? 1'b0 : 1'b1;
   assign TagRamWriteData[19:0] = TagReg;

   // CACHE RAM interface
   // If the line is being filled, index the cache RAM with the registered address
   assign LineWdIndex     = {LineIndex, WdIndex};
   assign LineWdIndexReg  = {LineIndexReg, WdIndexReg};
   
   assign CacheRamReadAddr  = BusReadReq ? LineWdIndexReg : LineWdIndex;
   assign CacheRamWriteAddr = {LineIndexReg, FillCntVal };
   assign CacheRamWriteEn   = BusReadReq & BusReadAck;
   assign CacheRamWriteData = BusReadData;
   

   // Register the ANDed STB and CYC to return data on next cycle (pipelined)
   always @(posedge CLK)
   begin : CORE_ADR_REG
      if (RST_SYNC)
      begin
         // Synchronous Reset
         CoreAdrReg <= 32'h0000_0000;
      end
      else if (CoreAddrStb)
      begin
         // Clocked assignments
         CoreAdrReg <= CORE_ADR_IN;
      end
   end

   // Register the core address strobe to generate a stall if the line needs to be filled.
   // SET when the address strobe first comes in (already qualified with STALL)
   // CLR when the TAG RAM write enable is high (on the next cycle, the ACK will go high due to ValidTagHit matching)
   always @(posedge CLK)
   begin : CORE_ADDR_STB_REG
      if (RST_SYNC)
      begin
         CoreReadAddrStbReg <= 1'b0;
      end
       else if (CoreReadAddrStb)
      begin
         CoreReadAddrStbReg <= 1'b1;
      end
       else if (TagRamStoreEn || ValidTagHit)
      begin
	 CoreReadAddrStbReg <= 1'b0;
      end
      
   end

   // When flushing the cache, need to set the ACK a cycle later without checking RAM contents.
   // Otherwise the RAM X will feed back into the ACK line.
   always @(posedge CLK)
   begin : CORE_FLUSH_EN_REG
      if (RST_SYNC)
      begin
         // Synchronous Reset
         TagRamFlushEnReg <= 1'b0;
      end
      else 
      begin
         // Clocked assignments
         TagRamFlushEnReg <= TagRamFlushEn;
      end
   end
   

   // Count the amount of reads done in the current request burst
   always @(posedge CLK)
   begin : FILL_COUNTER
      if (RST_SYNC)
      begin
         // Synchronous Reset
         FillCntVal <= 2'd0;
      end
      // Always reset when there's an address strobe. May not need to count if it's a hit
      else if (CoreReadAddrStb)
      begin
         // Clocked assignments
         FillCntVal <= 2'd0;
      end
      else if (CacheRamWriteEn)
      begin
	 FillCntVal <= FillCntVal + 2'd1;
      end
   end
   
    // TAG RAM used to store the valid bit and TAG data
   SPRAM 
      #(.ADDR_WIDTH  ( 8),  // TAG RAM stores TAG and VALID bit (512 x 21)
        .DATA_WIDTH  (21)
        )
   tag_spram
      (
       .CLK            (CLK       ),
       .EN             (1'b1      ),
       .WRITE_EN_IN    (TagRamWriteEn   ),
       .ADDR_IN        (TagRamAddr      ),
       .WRITE_DATA_IN  (TagRamWriteData ),
       .READ_DATA_OUT  (TagRamReadData  )
       );
  
   // Dual ported RAM.
   // Write port used to store words read from slower backing store
   // Read port used to return data words to the core
   DPRAM
      #(.ADDR_WIDTH   (10) ,  // 1k x 32
        .DATA_WIDTH   (32)
        )
   cache_dpram
      (
       .CLK              (CLK  ),
       .ENA              (1'b1 ),
       .ENB              (1'b1 ),
       .WRITE_EN_A_IN    (CacheRamWriteEn    ), // A is the write channel
       .ADDR_A_IN        (CacheRamWriteAddr  ), // B is the read channel
       .ADDR_B_IN        (CacheRamReadAddr   ),
       .WRITE_DATA_A_IN  (BusReadData  ),
       .READ_DATA_A_OUT  ( ),
       .READ_DATA_B_OUT  (CacheRamReadData   )
       );


   // Wishbone Master used to refill cache lines
   WB_MASTER 
      #(.COMB_CYC              (1)        )
   wb_master
      (
       .CLK            	       (CLK       ),
       .EN             	       (1'b1      ),
       .RST_SYNC       	       (RST_SYNC  ),
       .RST_ASYNC      	       (RST_SYNC  ), 

       .WB_ADR_OUT     	       (CACHE_ADR_OUT      ),
       .WB_CYC_OUT     	       (CACHE_CYC_OUT      ),
       .WB_STB_OUT     	       (CACHE_STB_OUT      ),
       .WB_WE_OUT      	       (CACHE_WE_OUT       ),
       .WB_SEL_OUT     	       (CACHE_SEL_OUT      ),
       .WB_CTI_OUT     	       (CACHE_CTI_OUT      ),
       .WB_BTE_OUT     	       (CACHE_BTE_OUT      ),
      
       .WB_ACK_IN      	       (CACHE_ACK_IN       ),
       .WB_STALL_IN    	       (CACHE_STALL_IN     ),
       .WB_ERR_IN      	       (CACHE_ERR_IN       ),
      
       .WB_DAT_RD_IN   	       (CACHE_DAT_RD_IN    ),
       .WB_DAT_WR_OUT  	       (CACHE_DAT_WR_OUT   ),
      
       .BUS_START_ADDR_IN      ({TagReg, LineIndexReg, 4'd0}  ), 
      
       .BUS_READ_REQ_IN        (BusReadReq     ),
       .BUS_READ_ACK_OUT       (BusReadAck     ),
       .BUS_WRITE_REQ_IN       (1'b0 ),
       .BUS_WRITE_ACK_OUT      (     ),
       .BUS_LAST_ACK_OUT       (BusLastAck     ),

       .BUS_SIZE_IN            (2'd2           ),
       .BUS_LEN_IN             (5'd4           ), 
       .BUS_BURST_ADDR_INC_IN  (1'b1           ), 

       .BUS_READ_DATA_OUT      (BusReadData    ),
       .BUS_WRITE_DATA_IN      (32'h0000_0000  )
      
       );
   


endmodule
