// Wishbone Write Buffer
//
// Only Memory writes should be routed to this slave. Peripheral transactions
// should be sent without going through this block. The writes are merged if
// the Addresses match, and bytes are overwritten if a new value is written.
// If the write buffer is full, or a read transaction comes in, the buffer
// is written out (in a burst if possible), then the read transaction is done.
//
// The read transaction just connects the WB slave to WB Master, there is no
// registering of data done inside the block. This could be added later based 
// on a parameter.
//
module WB_WRITE_BUFFER
   #(parameter WBD_P2 = 2 ) // Write Buffer Depth (Power-of-2)
   (
    // Clocks and resets (Source clock domain)
    input             CLK              ,
    input             EN               ,
    input             RST_SYNC         ,
    input             RST_ASYNC        , 

    // Wishbone interface (Slave)
    input      [31:0] WB_S_ADR_IN      ,
    input             WB_S_CYC_IN      ,
    input             WB_S_STB_IN      ,
    input             WB_S_WE_IN       ,
    input      [ 3:0] WB_S_SEL_IN      ,
    input      [ 2:0] WB_S_CTI_IN      ,
    input      [ 1:0] WB_S_BTE_IN      ,
    
    output            WB_S_STALL_OUT   ,
    output            WB_S_ACK_OUT     ,
    output            WB_S_ERR_OUT     ,
    
    output     [31:0] WB_S_DAT_RD_OUT  ,
    input      [31:0] WB_S_DAT_WR_IN   , 
   
    // Wishbone interface (Master)
    output    [31:0]  WB_M_ADR_OUT     ,
    output            WB_M_CYC_OUT     ,
    output            WB_M_STB_OUT     ,
    output            WB_M_WE_OUT      ,
    output    [ 3:0]  WB_M_SEL_OUT     ,
    output    [ 2:0]  WB_M_CTI_OUT     ,
    output    [ 1:0]  WB_M_BTE_OUT     , 

    input             WB_M_ACK_IN      ,
    input             WB_M_STALL_IN    ,
    input             WB_M_ERR_IN      ,

    input     [31:0]  WB_M_DAT_RD_IN   ,
    output    [31:0]  WB_M_DAT_WR_OUT  
   
    );
   

   /////////////////////////////////////////////////////////////////////////////
   // includes
`include "wb_defs.v"

   /////////////////////////////////////////////////////////////////////////////
   // parameters
   parameter WBD = (2 ** WBD_P2);

   /////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // Wishbone Read Wires / Regs. All WB Reads are registered first, and then 
   // issued if there's no write buffer flush ongoing, or issued after the 
   // Write buffer flush.
   wire               WbReadAddrStb  ; // Strobe from WB Slave inputs
   reg                WbReadReq      ; // Held request for WB Read
//   reg                WbReadAck      ; // ACK for WB Read request
//   wire               WbReadActive   ; // Arbitrated WB Read (high while in progress)
   reg   [31:0]       WbReadAddrReg  ; // Registered WB Read Address
   reg   [ 3:0]       WbReadSelReg   ; // Registered WB Read SEL
   wire               WbReadEnd      ; // Either ACK or ERR to end the WB read operation
   
   // Wishbone Write Wires / Regs. WB Writes are stored in the write buffer if
   // there is space available. If no space is available, the buffer is flushed
   // and then the data is stored.
   wire               WbWriteAddrDataStb    ; // Stobe from WB Slave inputs
//   reg                WbWriteAddrDataStbReg ; // Registered (free-running) WB Write strobe

   // Write Buffer flush REQ/ACK and shift
   wire               BufferFlushStb      ;
   reg                BufferFlushReq      ;
   wire               BufferFlushLastAck  ;
   wire               BufferFlushLastAddr ;
   wire               BufferShiftDown     ;

   // Arbitrated buffer flush / WB Read signals
   wire               BufferFlushActive   ; // 1st priority is to flush write buffer
   wire               WbReadActive        ; // before handling WB reads
   
   // Write Buffer counter/timer
   reg     [ WBD_P2:0]   WbCntVal          ; // Need extra bit to check for full 
//   wire  [ WBD-1:0]   WbCntValOneHot    ; // Used to decode where to store data
   wire               WriteBufferEmpty  ; // Empty and Full signals
   wire               WriteBufferFull   ;
   wire               WriteBufferStore     ; // Strobe when write data is stored into write buffer
   reg                WriteBufferStoreReg  ; // Registered strobe to return ACK
   
   wire      [WBD-1:0]  WbAddrMatchOneHot ; // One hot encoding of write buffer addr = WB addr
   wire      [WBD-1:0]  WbAddrMatch       ; // Priority encoding of write buffer addr = WB addr
   reg       [WBD-1:0]  WbAddrSelRegEn    ; // One-hot enable to store current write in buffer
//   wire      [WBD-1:0]  NewWbSel          ; // Combined OR of current write buffer and new write
//   reg       [    3:0]  CurrWbSel         ; // WbSelReg indexed with WbAddrMatch 
//   wire      [ 3:0]   CurrWbSelAnd   [WBD-1:0]  ; // AND mask of WbSelReg with WbAddrMatch
//   wire      [ 3:0]   CurrWbSelAndOr [3:0]  ; // OR together of AND-masked WbSelReg 
//   wire [(WBD*4)-1:0] CurrWbSelAndFlat ;  // Flattened version of WbSelReg (to AND/OR mux it into CurrWbsel)

   // Write Buffer Wishbone signals
   reg                BufferWbCyc   ;
   reg                WbReadWbCyc   ;
   reg                BufferWbStb   ;
   reg                WbReadWbStb   ;
   wire  [31:0]       BufferWbAddr  ;
   wire  [ 3:0]       BufferWbSel   ;
   reg   [ 2:0]       BufferWbCti   ;

   // Burst decoding logic (sets CTI for write buffer)
   wire               WbAddrIncrBurst ;
   wire               WbSelIncrBurst  ;
   reg                LastWbAddrIncrBurst ;
   reg                LastWbSelIncrBurst  ;
   reg   [ 2:0]       LastWbCti           ;

   
   // Write Buffer Storage (flops) - parameterised with WBD
   reg  [31:2]         WbAddrReg   [WBD-1:0]  ; // Addresses (32-bit aligned)
   reg  [ 3:0]         WbSelReg    [WBD-1:0]  ; // SELs (used as byte-valids)
   reg  [ 7:0]         WbWrDatReg0 [WBD-1:0]  ; // Byte-wise write data (so
   reg  [ 7:0]         WbWrDatReg1 [WBD-1:0]  ; // individual bytes can be 
   reg  [ 7:0]         WbWrDatReg2 [WBD-1:0]  ; // overwritten and merged with
   reg  [ 7:0]         WbWrDatReg3 [WBD-1:0]  ; // others 
   
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns

   // WB slave decodes
   assign WbReadAddrStb       = WB_S_CYC_IN & WB_S_STB_IN & ~WB_S_WE_IN & ~WB_S_STALL_OUT;
   assign WbWriteAddrDataStb  = WB_S_CYC_IN & WB_S_STB_IN &  WB_S_WE_IN & ~WB_S_STALL_OUT;

   // REQ/ACK handshaking
   assign WbReadAck           = WbReadActive & WB_M_ACK_IN;
   assign BufferFlushLastAddr = BufferFlushActive & ~WB_M_STALL_IN & (1 == WbCntVal);
   assign BufferFlushStb      =  (WriteBufferFull
                               | (WbReadAddrStb & (0 != WbCntVal))
                                  & ~BufferFlushReq);
   assign BufferFlushLastAck  = BufferFlushActive &  WB_M_ACK_IN   & (0 == WbCntVal);
   assign BufferShiftDown     = BufferFlushActive & ~WB_M_STALL_IN & (0 != WbCntVal);

   // Arbitrate the Buffer and WB reads, 1st priority is buffer flush
   assign BufferFlushActive   = BufferFlushReq;
   assign WbReadActive        = ~BufferFlushReq & WbReadReq;

   // Write buffer combinatorial logic
   assign WriteBufferFull   = ((WbCntVal == 3'd4) && (4'hf == WbSelReg[WBD-1])) ? 1'b1 : 1'b0;
   assign WriteBufferStore  = | WbAddrSelRegEn;
        
//   assign NewWbSel  = CurrWbSel | WB_S_SEL_IN; // Overwrite SEL with OR of incoming transaction and current
   
   // Combinatorial WB Master assigns
   assign BufferWbAddr = {32{BufferWbStb }} & {WbAddrReg[0], 2'b00};
   assign BufferWbSel  = { 4{BufferWbStb }} & WbSelReg[0];

   // CTI burst decodes
   assign WbAddrIncrBurst = (WbAddrReg[1] == (WbAddrReg[0] + 30'd1));
   assign WbSelIncrBurst  = ((4'hf == WbSelReg[1]) & (4'hf == WbSelReg[0]));
                             
   assign WbReadEnd = WbReadActive & (WB_M_ACK_IN | WB_M_ERR_IN); // Wishbone read completes on either ERR or ACK response
   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns


   // Wb Master assigns. These come from the Write buffer if a flush is in
   // process, or from the WB Slave directly on a read.
   assign WB_M_ADR_OUT    =  ({32{BufferFlushActive }} & BufferWbAddr  )
                           | ({32{WbReadActive      }} & WbReadAddrReg );
   
   assign WB_M_CYC_OUT    =  (BufferFlushActive & BufferWbCyc )
                           | (WbReadActive      & WbReadWbCyc );
   
   assign WB_M_STB_OUT    =  (BufferFlushActive & BufferWbStb )
                           | (WbReadActive      & WbReadWbStb );
   
   assign WB_M_WE_OUT     = BufferFlushActive;
   
   assign WB_M_SEL_OUT    =  ({4{BufferFlushActive }} & BufferWbSel  )
                           | ({4{WbReadActive      }} & ({4{WbReadWbStb}} & WbReadSelReg ));
   
   assign WB_M_CTI_OUT    = BufferWbCti; // Decoded in always block
   
   assign WB_M_BTE_OUT    = BTE_LINEAR_BURST; // No wrapping bursts
   
   assign WB_M_DAT_WR_OUT = {32{BufferFlushActive}} & {WbWrDatReg3[0],
                                                       WbWrDatReg2[0],
                                                       WbWrDatReg1[0],
                                                       WbWrDatReg0[0]
                                                       };
      
   // Slave-side outputs
   assign WB_S_STALL_OUT =  WriteBufferFull // (3'd4 == WbCntVal) 
                          | (BufferFlushActive)
                          | (WbReadActive      &  ~WbReadAck);

   assign WB_S_ACK_OUT   = ( (WbReadActive       & WbReadAck       )
                           | (~BufferFlushActive & ~WbReadActive & WriteBufferStoreReg )
                             );
   
   assign WB_S_ERR_OUT     = WB_M_ERR_IN;
   assign WB_S_DAT_RD_OUT  = {32{WbReadActive  }} & WB_M_DAT_RD_IN;

  
   /////////////////////////////////////////////////////////////////////////////
   // Always blocks - Wishbone slave and REQ/ACK for buffer flush and read req

   // Register when a read has taken place (it may not be issued immediately
   // if a buffer flush is in progress)
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_WB_READ_REG
      if (RST_ASYNC)
      begin
	 WbReadReq <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WbReadReq <= 1'b0;
      end
      else if (EN)
      begin
         // 1st priority has to be to request a new read, as a new read address
         // can come in at the same time as the previous read completes.
         if (WbReadAddrStb)
         begin
            WbReadReq <= 1'b1;
         end
         // Use WbReadEnd to clear REQ (can be either ERR or ACK response)
         else if (WbReadEnd)
         begin
            WbReadReq <= 1'b0;
         end
      end
   end

   // Register the READ Address and SEL to be issued on the next cycle if no 
   // buffer flush is ongoing, it can be issued on the next cycle
   always @(posedge CLK or posedge RST_ASYNC)
   begin : EN_WB_READ_ADDR_REG
      if (RST_ASYNC)
      begin
	 WbReadAddrReg <= 32'h0000_0000;
      end
      else if (RST_SYNC)
      begin
	 WbReadAddrReg <= 32'h0000_0000;
      end
      else if (EN && WbReadAddrStb)
      begin
         WbReadAddrReg <= WB_S_ADR_IN;
      end
   end
   
   // Also Register the READ SEL to be issued later
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_WB_READ_SEL_REG
      if (RST_ASYNC)
      begin
	 WbReadSelReg <= 4'h0;
      end
      else if (RST_SYNC)
      begin
	 WbReadSelReg <= 4'h0;
      end
      else if (EN && WbReadAddrStb)
      begin
         WbReadSelReg <= WB_S_SEL_IN;
      end
   end

   // Register the Write strobe. This is used to generate an ACK on the next
   // cycle if it can be stored in the buffer.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_WRITE_STB_REG
      if (RST_ASYNC)
      begin
	WriteBufferStoreReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WriteBufferStoreReg <= 1'b0;
      end
      else if (EN)
      begin
         WriteBufferStoreReg <= WriteBufferStore;
      end
   end

   // Buffer flush REQ/ACK handshaking
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_BUFF_FLUSH_REQ
      if (RST_ASYNC)
      begin
	BufferFlushReq <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 BufferFlushReq <= 1'b0;
      end
      else if (EN)
      begin
         if (BufferFlushLastAck)
         begin
            BufferFlushReq <= 1'b0;
         end
         else if (BufferFlushStb)
         begin
            BufferFlushReq <= 1'b1;
         end
      end
   end


   /////////////////////////////////////////////////////////////////////////////
   // Always blocks - Write Buffer Address, Sel, and Data storage

   
   // Decode where the current transaction can be stored
   always @*
   begin : WRITE_BUFF_DECODE

      WbAddrSelRegEn = 4'h0;

      if (!BufferFlushActive && WbWriteAddrDataStb)
      begin
         // 1st priority : If any WB addresses match (one-hot bus) then store in that location
         if (| WbAddrMatch)
         begin
            WbAddrSelRegEn = WbAddrMatch;
         end
         // Otherwise, store at next available write buffer location.
         else
         begin
            WbAddrSelRegEn[WbCntVal] = 1'b1;
         end
      end
   end

   // Write buffer counter / timer
   always @(posedge CLK or posedge RST_ASYNC)
   begin : WB_COUNTER_TIMER
      if (RST_ASYNC)
      begin
         WbCntVal <= 3'd0;
      end
      else if (RST_SYNC)
      begin
         WbCntVal <= 3'd0;
      end
      else if (EN)
      begin
         // Only increment the write pointer if there isn't a matching address
         if (!WriteBufferFull && WbWriteAddrDataStb && !(| WbAddrMatch))
         begin
            WbCntVal <= WbCntVal + 3'd1;
         end
         else if (BufferShiftDown)
         begin
            WbCntVal <= WbCntVal - 3'd1;
         end
      end
   end


  
   
   // Generate loop to iterate through each of the write buffer entries
   genvar WriteBuffLoop;

   generate for (WriteBuffLoop = 0 
               ; WriteBuffLoop < WBD 
               ; WriteBuffLoop = WriteBuffLoop + 1)
   begin : GEN_WRITE_BUFF_STORE


      // Work out which addresses match (one-hot). 
      assign WbAddrMatchOneHot[WriteBuffLoop] = ((WB_S_ADR_IN[31:2] == WbAddrReg[WriteBuffLoop][31:2]) ? 1'b1 : 1'b0) &
                                                 (WbCntVal > WriteBuffLoop);

      // if statements inside generates are generate if by default
      if (0 == WriteBuffLoop)
      begin
         assign WbAddrMatch[WriteBuffLoop] = WbAddrMatchOneHot[WriteBuffLoop];   
      end
      else
      begin
         assign WbAddrMatch[WriteBuffLoop] = WbAddrMatchOneHot[WriteBuffLoop] &
                                             ~(| WbAddrMatchOneHot[WriteBuffLoop-1:0]);
      end
      
      // Register the 32-bit addresses. Shift down as the buffer flush proceeds.
      always @(posedge CLK or posedge RST_ASYNC)
      begin : BUFF_ADDR_REG
         if (RST_ASYNC)
         begin
	    WbAddrReg[WriteBuffLoop] <= 30'h0000_0000;
         end
         else if (RST_SYNC)
         begin
	    WbAddrReg[WriteBuffLoop] <= 30'h0000_0000;
         end
         if (EN)
         begin
            // 1st priority is to shift the buffer entries down
            if (BufferShiftDown)
            begin
               // Top Write Buffer entry is zero'ed
               if (WBD-1 == WriteBuffLoop)
               begin
	          WbAddrReg[WriteBuffLoop] <= 30'h0000_0000;
               end
               // Rest of entries store value from address above
               else
               begin
                  WbAddrReg[WriteBuffLoop] <= WbAddrReg[WriteBuffLoop+1];
               end
            end
            // Otherwise if a new address is registered, store the address
            else if (WbAddrSelRegEn[WriteBuffLoop])
            begin
               WbAddrReg[WriteBuffLoop] <= WB_S_ADR_IN[31:2];
            end
            
         end
      end

      // Register the WB SEL values, OR the previous value so all the individual
      // bytes accumulate prior to writing them out.
      // Shift down as the buffer flush proceeds.
      always @(posedge CLK or posedge RST_ASYNC)
      begin : BUFF_SEL_REG
         if (RST_ASYNC)
         begin
	    WbSelReg[WriteBuffLoop] <= 4'h0;
         end
         else if (RST_SYNC)
         begin
	    WbSelReg[WriteBuffLoop] <= 4'h0;
         end
         if (EN)
         begin
            // 1st priority is to shift the buffer entries down
            if (BufferShiftDown)
            begin
               // Top Write Buffer entry is zero'ed
               if (WBD-1 == WriteBuffLoop)
               begin
	          WbSelReg[WriteBuffLoop] <= 4'h0;
               end
               // Rest of entries store value from address above
               else
               begin
                  WbSelReg[WriteBuffLoop] <= WbSelReg[WriteBuffLoop+1];
               end
            end
            // Otherwise if a new address is registered, store the address
            else if (WbAddrSelRegEn[WriteBuffLoop])
            begin
               WbSelReg[WriteBuffLoop] <= WbSelReg[WriteBuffLoop] | WB_S_SEL_IN;
            end
         end
      end

      // Register Byte 0 using WB_S_SEL_IN as an enable
      always @(posedge CLK or posedge RST_ASYNC)
      begin : BUFF_DATA0_REG
         if (RST_ASYNC)
         begin
	    WbWrDatReg0[WriteBuffLoop] <= 8'h00;
         end
         else if (RST_SYNC)
         begin
	    WbWrDatReg0[WriteBuffLoop] <= 8'h00;
         end
         if (EN)
         begin
            // 1st priority is to shift the buffer entries down
            if (BufferShiftDown)
            begin
               // Top Write Buffer entry is zero'ed
               if (WBD-1 == WriteBuffLoop)
               begin
	          WbWrDatReg0[WriteBuffLoop] <= 8'h00;
               end
               // Rest of entries store value from address above
               else
               begin
                  WbWrDatReg0[WriteBuffLoop] <= WbWrDatReg0[WriteBuffLoop+1];
               end
            end
            // Otherwise if a new address is registered, store the address
            else if (!BufferFlushActive 
                     && WB_S_SEL_IN[0]
                     && WbAddrSelRegEn[WriteBuffLoop])
            begin
               WbWrDatReg0[WriteBuffLoop] <= WB_S_DAT_WR_IN[7:0];
            end
         end
      end

      // Register Byte 1 using WB_S_SEL_IN as an enable
      always @(posedge CLK or posedge RST_ASYNC)
      begin : BUFF_DATA1_REG
         if (RST_ASYNC)
         begin
	    WbWrDatReg1[WriteBuffLoop] <= 8'h00;
         end
         else if (RST_SYNC)
         begin
	    WbWrDatReg1[WriteBuffLoop] <= 8'h00;
         end
         if (EN)
         begin
            // 1st priority is to shift the buffer entries down
            if (BufferShiftDown)
            begin
               // Top Write Buffer entry is zero'ed
               if (WBD-1 == WriteBuffLoop)
               begin
	          WbWrDatReg1[WriteBuffLoop] <= 8'h00;
               end
               // Rest of entries store value from address above
               else
               begin
                  WbWrDatReg1[WriteBuffLoop] <= WbWrDatReg1[WriteBuffLoop+1];
               end
            end
            // Otherwise if a new address is registered, store the address
            else if (!BufferFlushActive 
                     && WB_S_SEL_IN[1]
                     && WbAddrSelRegEn[WriteBuffLoop])
            begin
               WbWrDatReg1[WriteBuffLoop] <= WB_S_DAT_WR_IN[15:8];
            end
         end
      end

       // Register Byte 2 using WB_S_SEL_IN as an enable
      always @(posedge CLK or posedge RST_ASYNC)
      begin : BUFF_DATA2_REG
         if (RST_ASYNC)
         begin
	    WbWrDatReg2[WriteBuffLoop] <= 8'h00;
         end
         else if (RST_SYNC)
         begin
	    WbWrDatReg2[WriteBuffLoop] <= 8'h00;
         end
         if (EN)
         begin
            // 1st priority is to shift the buffer entries down
            if (BufferShiftDown)
            begin
               // Top Write Buffer entry is zero'ed
               if (WBD-1 == WriteBuffLoop)
               begin
	          WbWrDatReg2[WriteBuffLoop] <= 8'h00;
               end
               // Rest of entries store value from address above
               else
               begin
                  WbWrDatReg2[WriteBuffLoop] <= WbWrDatReg2[WriteBuffLoop+1];
               end
            end
            // Otherwise if a new address is registered, store the address
            else if (!BufferFlushActive 
                     && WB_S_SEL_IN[2]
                     && WbAddrSelRegEn[WriteBuffLoop])
            begin
               WbWrDatReg2[WriteBuffLoop] <= WB_S_DAT_WR_IN[23:16];
            end
         end
      end

      // Register Byte 3 using WB_S_SEL_IN as an enable
      always @(posedge CLK or posedge RST_ASYNC)
      begin : BUFF_DATA3_REG
         if (RST_ASYNC)
         begin
	    WbWrDatReg3[WriteBuffLoop] <= 8'h00;
         end
         else if (RST_SYNC)
         begin
	    WbWrDatReg3[WriteBuffLoop] <= 8'h00;
         end
         if (EN)
         begin
            // 1st priority is to shift the buffer entries down
            if (BufferShiftDown)
            begin
               // Top Write Buffer entry is zero'ed
               if (WBD-1 == WriteBuffLoop)
               begin
	          WbWrDatReg3[WriteBuffLoop] <= 8'h00;
               end
               // Rest of entries store value from address above
               else
               begin
                  WbWrDatReg3[WriteBuffLoop] <= WbWrDatReg3[WriteBuffLoop+1];
               end
            end
            // Otherwise if a new address is registered, store the address
            else if (!BufferFlushActive 
                     && WB_S_SEL_IN[3]
                     && WbAddrSelRegEn[WriteBuffLoop])
            begin
               WbWrDatReg3[WriteBuffLoop] <= WB_S_DAT_WR_IN[31:24];
            end
         end
      end


   end
   endgenerate
   
   
   // Combinatorial block to decode if the current write buffer flush forms a
   // burst (and sets CTI accordingly).
   // In a burst, all the address strobes are 'CTI_INCR_ADDR' apart from the
   // last one which is CTI_END_BURST
   always @*
   begin : BUFFER_WB_CTI_DECODE

      BufferWbCti = CTI_CLASSIC;
      
      if (BufferWbStb)
      begin

         // If it's the last address being strobed to the slave, set CTI to
         // end-of-burst if the last CTI was incr-burst
//         if (BufferFlushLastAddr)
//         begin
            if ((1 == WbCntVal )
                && (CTI_INCR_ADDR == LastWbCti)
                && LastWbAddrIncrBurst
                && LastWbSelIncrBurst)
            begin
               BufferWbCti = CTI_END_BURST;
            end
//         end
//
//         // Otherwise, if the next address is 1-higher (addr is [31:2]) and
//         // the SELs for current and next address are 4'hf, set incr burst
         else if (WbAddrIncrBurst && WbSelIncrBurst)
         begin
            BufferWbCti = CTI_INCR_ADDR;
         end
      end
   end
   
   /////////////////////////////////////////////////////////////////////////////
   // Always blocks for WB Master interface


   // SR Flop to set the CYC for buffer writes
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_BUFFER_WB_CYC
      if (RST_ASYNC)
      begin
	 BufferWbCyc <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 BufferWbCyc <= 1'b0;
      end
      else if (EN)
      begin
         if (BufferFlushLastAck)
         begin
            BufferWbCyc <= 1'b0;
         end
         else if (BufferFlushStb)
         begin
            BufferWbCyc <= 1'b1;
         end
      end
   end

   // SR Flop to set the CYC for WB Reads
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_WB_READ_WB_CYC
      if (RST_ASYNC)
      begin
	 WbReadWbCyc <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WbReadWbCyc <= 1'b0;
      end
      else if (EN)
      begin
         // You can get another Read Strobe on the same cycle as the current one
         // completing, as the ACK is asserted and STALL de-asserted then. For
         // this reason, the set has to be highest priority
         if (WbReadAddrStb)
         begin
            WbReadWbCyc <= 1'b1;
         end
         else if (WbReadActive && WB_M_ACK_IN)
         begin
            WbReadWbCyc <= 1'b0;
         end
      end
   end

   // SR Flop to set the STB for buffer writes
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_BUFFER_WB_STB
      if (RST_ASYNC)
      begin
	 BufferWbStb <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 BufferWbStb <= 1'b0;
      end
      else if (EN)
      begin
         if (BufferFlushLastAddr)
         begin
            BufferWbStb <= 1'b0;
         end
         else if (BufferFlushStb)
         begin
            BufferWbStb <= 1'b1;
         end
      end
   end

   // SR Flop to set the STB for WB Reads
   always @(posedge CLK or posedge RST_ASYNC)
   begin : SR_WB_READ_WB_STB
      if (RST_ASYNC)
      begin
	 WbReadWbStb <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 WbReadWbStb <= 1'b0;
      end
      else if (EN)
      begin
         // You can get another Read Strobe on the same cycle as the current one
         // completing, as the ACK is asserted and STALL de-asserted then. For
         // this reason, the set has to be highest priority
         if (WbReadAddrStb)
         begin
            WbReadWbStb <= 1'b1;
         end
         else if (WbReadActive && !WB_M_STALL_IN)
         begin
            WbReadWbStb <= 1'b0;
         end
      end
   end // block: SR_WB_READ_WB_STB


   // Register the previous burst parameters to decode the next one
   always @(posedge CLK or posedge RST_ASYNC)
   begin : CTI_REG
      if (RST_ASYNC)
      begin
	 LastWbCti <= 3'b000;
         LastWbAddrIncrBurst <= 1'b0;
         LastWbSelIncrBurst  <= 1'b0;
      end
      else if (RST_SYNC)
      begin
	 LastWbCti <= 3'b000;
         LastWbAddrIncrBurst <= 1'b0;
         LastWbSelIncrBurst  <= 1'b0;
      end
      else if (EN && BufferFlushActive && !WB_M_STALL_IN)
      begin
	 LastWbCti <= WB_M_CTI_OUT;
         LastWbAddrIncrBurst <= WbAddrIncrBurst ;
         LastWbSelIncrBurst  <= WbSelIncrBurst  ;
     end
   end

   
endmodule
