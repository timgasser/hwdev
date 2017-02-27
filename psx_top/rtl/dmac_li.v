 // Insert module header here.

module DMAC_LI
  #(parameter FIFO_DEPTH = 16,
    parameter FIFO_WIDTH = 32
    )
  (

   input         CLK         ,
   input         EN          ,
   input         RST_SYNC    ,
   input         RST_ASYNC   ,

   // Config inputs
   input         CFG_DMA_CHCR_TR_IN     ,
   output        CFG_DMA_CHCR_TR_CLR_OUT  ,
   input         CFG_DMA_CHCR_LI_IN     ,
// input         CFG_DMA_CHCR_DR_IN     , <- Don't need TR for LI DMA, always MEM->GPU
   input  [31:0] CFG_DMA_MADR_IN        , // bottom 2 bits dropped inside
//   input  [15:0] CFG_DMA_BLK_CNT_IN   , <- Not used in LI Mode
//   input  [15:0] CFG_DMA_BLK_SIZE_IN  , <- Not used in LI Mode

   // Bus Master interface
   output        BUS_READ_REQ_OUT       ,
   input         BUS_READ_ACK_IN        ,
   output        BUS_WRITE_REQ_OUT      ,
   input         BUS_WRITE_ACK_IN       ,
   input         BUS_LAST_ACK_IN        ,

   output [31:0] BUS_START_ADDR_OUT     ,
   output [ 1:0] BUS_SIZE_OUT           ,
   output [ 4:0] BUS_LEN_OUT            ,
   output        BUS_BURST_ADDR_INC_OUT ,
   
   output [31:0] BUS_WRITE_DATA_OUT     ,
   input  [31:0] BUS_READ_DATA_IN       ,

   // DMA Peripheral interface
   input         DMAC_REQ_IN            ,
   output        DMAC_ACK_OUT           ,
   output        DMAC_IRQ_OUT           
   );


   /////////////////////////////////////////////////////////////////////////////
   // includes
`include "psx_mem_map.vh"


   
   /////////////////////////////////////////////////////////////////////////////
   // parameters

   parameter  [3:0] DGLFSM_IDLE         = 4'h0;
   parameter  [3:0] DGLFSM_REG_CFG      = 4'h1;
   parameter  [3:0] DGLFSM_HDR_RD_REQ   = 4'h2;
   parameter  [3:0] DGLFSM_HDR_RD_ACK   = 4'h3;
   parameter  [3:0] DGLFSM_PAY_RD_REQ   = 4'h4;
   parameter  [3:0] DGLFSM_PAY_RD_ACK   = 4'h5;
   parameter  [3:0] DGLFSM_PAY_WR       = 4'h6;
   parameter  [3:0] DGLFSM_TMR_CHK      = 4'h6;
   parameter  [3:0] DGLFSM_DMA_ACK      = 4'h7;

   

   /////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // Registered config from register block
   reg   [23:0] LiNextAddrReg    ; // Address of the next LI packet
      
   // Counter and Timers
   reg   [23:2] AddrCntVal     ; // Address counter in units of 32 bit words
   wire  [23:0] AddrCntValByte ; // Address counter in units of 32 bit words
   reg   [ 7:0] BlkTmrVal      ; // Block Timer (units of CfgDmaBlkSizeReg) 

   // FSM State variables
   reg   [ 3:0] DglfsmStateCur ;
   reg   [ 3:0] DglfsmStateNxt ;

   // FSM Outputs
   reg          FsmCfgRegEn      ;
   reg [31:0]   BusAddrNxt       ;
   reg [31:0]   BusAddr          ; // -> BUS_START_ADDR_OUT
   reg          BusAddrIncNxt    ;
   reg          BusAddrInc       ; // -> BUS_BURST_ADDR_INC_OUT
   reg          BusLenNxt        ;
   reg          BusLen           ; // -> BUS_LEN_OUT
   reg          BusRegEn         ;
   reg          LiHdrReadReqNxt  ;
   reg          LiHdrReadReq     ;
   reg          LiPayReadReqNxt  ;
   reg          LiPayReadReq     ;
   reg          LiPayWriteReqNxt ;
   reg          LiPayWriteReq    ;
   reg          DmacAckNxt       ;
   reg          DmacAck          ; // -> DMAC_ACK_OUT
   reg          AddrCntLdLi      ;

   
   // Fifo full / empty indicators
   wire         FifoWrFull     ;
   wire         FifoRdEmpty    ;
   
   wire [4:0]   MinBlkSize     ;
   
   /////////////////////////////////////////////////////////////////////////////
   // Internal assigns

   // convert the Address Counter into a byte value
   assign AddrCntValByte = {AddrCntVal, 2'b00};

   // Select either FIFO size of minimum timer value
   assign MinBlkSize = (BlkTmrVal < FIFO_DEPTH) ? BlkTmrVal : FIFO_DEPTH;
   
   /////////////////////////////////////////////////////////////////////////////
   // External assigns

   // FSM outputs to outside world (registered)
   assign BUS_READ_REQ_OUT       = LiHdrReadReq | LiPayReadReq  ;
   assign BUS_WRITE_REQ_OUT      = LiPayWriteReq    ;
   assign BUS_START_ADDR_OUT     = BusAddr          ;
   assign BUS_SIZE_OUT           = 2'b10            ; // 32-bit accesses 
   assign BUS_LEN_OUT            = BusLen           ;
   assign BUS_BURST_ADDR_INC_OUT = BusAddrInc       ;
   
   // DMA outputs
   assign DMAC_ACK_OUT           = DmacAck          ;
   assign DMAC_IRQ_OUT           = DmacAck          ;
  
   // TR clear pulse
   assign CFG_DMA_CHCR_TR_CLR_OUT = DmacAck  ;

   /////////////////////////////////////////////////////////////////////////////
   // Always blocks


   // Register the address of the next LI packet
   always @(posedge CLK or posedge RST_ASYNC)
   begin : LI_NXT_ADDR_REG
      if (RST_ASYNC)
      begin
         LiNextAddrReg <= 24'h00_0000;
      end
      else if (RST_SYNC)
      begin
         LiNextAddrReg <= 24'h00_0000;
      end
      else if (EN && LiHdrReadReq && BUS_LAST_ACK_IN)
      begin
         LiNextAddrReg <= BUS_READ_DATA_IN[23:0];
      end
   end

   // DMA Address Counter
   // Load : MADR register value with the FsmCfgRegEn is pulsed by FSM
   // Inc  : Use CfgDmaBlkSizeReg  as the increment value on BUS_LAST_ACK_IN
   // NOTE Units are 32-bit words, so only 30-bit value used.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMA_ADDR_CNT
      if (RST_ASYNC)
      begin
         AddrCntVal <= 22'd0;
      end
      else if (RST_SYNC)
      begin
         AddrCntVal <= 22'd0;
      end
      else if (EN)
      begin
         // First Li packet address comes from config reg
         if (FsmCfgRegEn)
         begin
            AddrCntVal <= CFG_DMA_MADR_IN[31:2];
         end
         // Next packet in the sequence comes from the Next LLI Reg
         else if (AddrCntLdLi)
         begin
            AddrCntVal <= LiNextAddrReg[23:2];
         end
         // If it's the last transaction on the bus, increment by 
         else if (BUS_LAST_ACK_IN)
         begin
            AddrCntVal <= AddrCntVal + BusLen;
         end
      end
   end
   
   // DMA Block Timer
   // Load : BLK_CNT register value with the FsmCfgRegEn is pulsed by FSM
   // Dec  : On BUS_LAST_ACK, decrement by CfgDmaBlkSizeReg
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DMA_BLK_TMR
      if (RST_ASYNC)
      begin
         BlkTmrVal <= 8'h00;
      end
      else if (RST_SYNC)
      begin
         BlkTmrVal <= 8'h00;
      end
      else if (EN)
      begin
         // Load a new transfer size every time the header is read
         if (LiHdrReadReq && BUS_LAST_ACK_IN)
         begin
            BlkTmrVal <= BUS_READ_DATA_IN[31:24];
         end
         // Decrement by the bus transaction length when it completes
         else if (LiPayWriteReq && BUS_LAST_ACK_IN)
         begin
            BlkTmrVal <= BlkTmrVal - BusLen;
         end
      end
   end
   
   // FSM - Combinatorial process
   always @*
   begin : DGLFSM_ST

      // Default values
      DglfsmStateNxt   = DglfsmStateCur;

      FsmCfgRegEn      = 1'b0;
      BusAddrNxt       = 32'h0000_0000;
      BusAddrIncNxt    = 1'b0;
      BusLenNxt        = 5'd0;
      BusRegEn         = 1'b0;
      LiHdrReadReqNxt  = 1'b0;     
      LiPayReadReqNxt  = 1'b0;
      LiPayWriteReqNxt = 1'b0;
      DmacAckNxt       = 1'b0;
      AddrCntLdLi      = 1'b0;

      case (DglfsmStateCur)


        DGLFSM_IDLE        :
          begin
             if (CFG_DMA_CHCR_TR_IN && CFG_DMA_CHCR_LI_IN)
             begin
                // Outputs
                FsmCfgRegEn = 1'b1;
                // Next state
                DglfsmStateNxt = DGLFSM_REG_CFG;
             end
          end
        
        DGLFSM_REG_CFG     :
          begin
             // Outputs
             BusAddrNxt       = AddrCntValByte;
             BusAddrIncNxt    = 1'b1;
             BusLenNxt        = 5'd1;
             BusRegEn         = 1'b1;
             LiHdrReadReqNxt  = 1'b1;
             // Next state
             DglfsmStateNxt   = DGLFSM_HDR_RD_REQ;
          end
        
        DGLFSM_HDR_RD_REQ      :
          begin
             // Current outputs
             LiHdrReadReqNxt  = 1'b1;

             if (BUS_LAST_ACK_IN)
             begin
                // Outputs
                LiHdrReadReqNxt = 1'b0;
                // Next state
                DglfsmStateNxt  = DGLFSM_HDR_RD_ACK;
             end
          end
        
        DGLFSM_HDR_RD_ACK :
          begin
             // Outputs
             BusAddrNxt      = AddrCntValByte;
             BusAddrIncNxt   = 1'b1;
             BusLenNxt       = MinBlkSize;
             BusRegEn        = 1'b1;
             LiPayReadReqNxt = 1'b1;
             // Next state
             DglfsmStateNxt  = DGLFSM_PAY_RD_REQ;
          end
        
        DGLFSM_PAY_RD_REQ      :
          begin
             // Current outputs
             LiPayReadReqNxt = 1'b1;

             if (BUS_LAST_ACK_IN)
             begin
                // Outputs
                LiPayReadReqNxt = 1'b0;
                // Next state
                DglfsmStateNxt  = DGLFSM_PAY_RD_ACK;
             end
          end
        
        DGLFSM_PAY_RD_ACK :
          begin
             // The FIFO is full of payload data, ready to be written to the
             // GPU. Wait until the REQ comes in before writing
             if (DMAC_REQ_IN)
             begin
                // Next state outputs
                BusAddrNxt       = GPU_DATA;
                BusAddrIncNxt    = 1'b0;
                BusLenNxt        = MinBlkSize;
                BusRegEn         = 1'b1;
                LiPayWriteReqNxt = 1'b1;
                // Next state
                DglfsmStateNxt   = DGLFSM_DMA_ACK;
             end
          end
        
        DGLFSM_PAY_WR :
          begin
             // Current outputs
             LiPayWriteReqNxt = 1'b1;
             if (BUS_LAST_ACK_IN)
             begin
                // Next outputs
                LiPayWriteReqNxt = 1'b0;
                // Next state
                DglfsmStateNxt   = DGLFSM_TMR_CHK;
             end
          end

        DGLFSM_TMR_CHK :
          begin
             // Once the current block transfer has finished, check for:
             // 1. This is the last block of last packet.
             // 2. This is the last block of the current (not-last) packet
             // 3. This is a block in the current packet

             // 1 => Complete, ACK the DMA
             if ((5'd0 == MinBlkSize) && (24'hff_ffff == LiNextAddrReg))
             begin
                // Next state outputs
                DmacAckNxt     = 1'b1;
                // Next state
                DglfsmStateNxt = DGLFSM_DMA_ACK;
             end

             // 2 => Load next packet header
             else if (5'd0 == MinBlkSize)
             begin
                // Next state outputs
                BusAddrNxt       = LiNextAddrReg;
                BusAddrIncNxt    = 1'b1;
                BusLenNxt        = 5'd1;
                BusRegEn         = 1'b1;
                AddrCntLdLi      = 1'b1;
                // Next state
                DglfsmStateNxt   = DGLFSM_DMA_ACK;
             end

             // 3 => Keep reading the payload body
             else
             begin
                // Next state outputs
                BusAddrNxt       = AddrCntValByte;
                BusAddrIncNxt    = 1'b1;
                BusLenNxt        = MinBlkSize;
                BusRegEn         = 1'b1;
                LiHdrReadReqNxt  = 1'b1;
                // Next state
                DglfsmStateNxt   = DGLFSM_PAY_RD_REQ;
             end
          end
        
        DGLFSM_DMA_ACK :
          begin
             // Next state
             DglfsmStateNxt   = DGLFSM_IDLE;
          end

        default : DglfsmStateNxt   = DGLFSM_IDLE;
        
      endcase
   end
   


   // FSM - Clocked  process
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DGLFSM_CP
      if (RST_ASYNC)
      begin
         DglfsmStateCur <= DGLFSM_IDLE;

         BusAddr       <= 32'h0000_0000;
         BusAddrInc    <= 1'b0;
         BusLen        <= 5'd0;
         LiHdrReadReq  <= 1'b0; 
         LiPayReadReq  <= 1'b0; 
         LiPayWriteReq <= 1'b0;
         DmacAck       <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         DglfsmStateCur <= DGLFSM_IDLE;

         BusAddr       <= 32'h0000_0000;
         BusAddrInc    <= 1'b0;
         BusLen        <= 5'd0;
         LiHdrReadReq  <= 1'b0; 
         LiPayReadReq  <= 1'b0; 
         LiPayWriteReq <= 1'b0;
         DmacAck       <= 1'b0;
      end
      else if (EN)
      begin
         // Next state register
         DglfsmStateCur <= DglfsmStateNxt   ;

         // Direct outputs from FSM
         LiHdrReadReq   <= LiHdrReadReqNxt  ; 
         LiPayReadReq   <= LiPayReadReqNxt  ; 
         LiPayWriteReq  <= LiPayWriteReqNxt ;

         DmacAck        <= DmacAckNxt       ;

         // Bus-registered outputs
         if (BusRegEn)
         begin
            BusAddr    <= BusAddrNxt    ;
            BusAddrInc <= BusAddrIncNxt ;
            BusLen     <= BusLenNxt     ;
         end
      end
   end
   

   /////////////////////////////////////////////////////////////////////////////
   // Module instantiations

   // SYNC fifo to buffer source reads, and write to destination
   SYNC_FIFO 
     #(
       .D_P2       ( 4) ,
       .BW         (32) ,
       .WWM        ( 1) ,
       .RWM        ( 1) ,
       .USE_RAM    ( 0)  
       )
   sync_fifo
   (
    .WR_CLK         (CLK       ), 
    .RD_CLK         (CLK       ),
    .RST_SYNC       (RST_SYNC  ),
    .RST_ASYNC      (RST_ASYNC ),

    .WRITE_EN_IN    (BUS_READ_REQ_OUT  & BUS_READ_ACK_IN  ),
    .WRITE_DATA_IN  (BUS_READ_DATA_IN ),
    .WRITE_FULL_OUT (FifoWrFull       ),

    .READ_EN_IN     (BUS_WRITE_REQ_OUT & BUS_WRITE_ACK_IN ),
    .READ_DATA_OUT  (BUS_WRITE_DATA_OUT ),
    .READ_EMPTY_OUT (FifoRdEmpty        ) 
    );


endmodule






