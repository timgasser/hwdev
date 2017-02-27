// Insert module header here.
module DMAC_PERI
  #(parameter BLK_FIFO_DEPTH = 16,
    parameter BLK_FIFO_WIDTH = 32
    )
  (
   input         CLK         ,
   input         EN          ,
   input         RST_SYNC    ,
   input         RST_ASYNC   ,

   // Config inputs
   input         CFG_DMA_CHCR_TR_IN       ,
   output        CFG_DMA_CHCR_TR_CLR_OUT  ,
   input         CFG_DMA_CHCR_CO_IN       ,
   input         CFG_DMA_CHCR_DR_IN       ,
   input  [31:0] CFG_DMA_MADR_IN          , // bottom 2 bits dropped inside
   input  [15:0] CFG_DMA_BLK_CNT_IN       ,
   input  [15:0] CFG_DMA_BLK_SIZE_IN      ,

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

   parameter  [2:0] DPFSM_IDLE         = 3'h0;
   parameter  [2:0] DPFSM_REG_CFG      = 3'h1;
   parameter  [2:0] DPFSM_SRC_RD       = 3'h2;
   parameter  [2:0] DPFSM_SRC_RD_DONE  = 3'h3;
   parameter  [2:0] DPFSM_DST_WR       = 3'h4;
   parameter  [2:0] DPFSM_DST_WR_DONE  = 3'h5;
   parameter  [2:0] DPFSM_DMA_ACK      = 3'h6;

   

   /////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // Registered config from register block
   reg          CfgDmaChcrDrReg  ; // Registered DR bit on FsmCfcRegEn
   reg   [ 4:0] CfgDmaBlkSizeReg ; // Registered block size (for Bus Master)

   
   // Muxed source and dest bus control
   wire  [31:0] SrcAddr        ; // Source Address
   wire         SrcBusAddrInc  ; // Source Bus Address increment
   wire  [31:0] DstAddr        ; // Dest Address
   wire         DstAddrInc     ; // Dest Bus Address increment
   
   // Counter and Timers
   reg   [31:2] AddrCntVal     ; // Address counter in units of 32 bit words
   wire  [31:0] AddrCntValByte ; // Address counter in units of 32 bit words
   reg   [15:0] BlkTmrVal      ; // Block Timer (units of CfgDmaBlkSizeReg) 

   // FSM State variables
   reg   [ 2:0] DpfsmStateCur  ;
   reg   [ 2:0] DpfsmStateNxt  ;

   // FSM Outputs
   reg          FsmCfgRegEn    ;
   reg [31:0]   BusAddrNxt     ;
   reg [31:0]   BusAddr        ; // -> BUS_START_ADDR_OUT
   reg          BusAddrIncNxt  ;
   reg          BusAddrInc     ; // -> BUS_BURST_ADDR_INC_OUT
   reg          BusRegEn       ;
   reg          BusReadReqNxt  ;
   reg          BusReadReq     ; // -> BUS_READ_REQ_OUT
   reg          BusWriteReqNxt ;
   reg          BusWriteReq    ; // -> BUS_WRITE_REQ_OUT
   reg          DmacAckNxt     ;
   reg          DmacAck        ; // -> DMAC_ACK_OUT

   // Fifo full / empty indicators
   wire         FifoWrFull     ;
   wire         FifoRdEmpty    ;
   

   
   /////////////////////////////////////////////////////////////////////////////
   // Internal assigns

   // Mux the source and destination address and increments
   assign SrcAddr        = CfgDmaChcrDrReg ? AddrCntValByte : GPU_DATA       ; // todo add include for this address
   assign DstAddr        = CfgDmaChcrDrReg ? GPU_DATA       : AddrCntValByte ; // todo add include for this address
   assign DstAddrInc     = CfgDmaChcrDrReg ? 1'b0 : 1'b1 ;
   assign SrcBusAddrInc  = CfgDmaChcrDrReg ? 1'b1 : 1'b0 ;
   assign DstBusAddrInc  = CfgDmaChcrDrReg ? 1'b0 : 1'b1 ;

   // convert the Address Counter into a byte value
   assign AddrCntValByte = {AddrCntVal, 2'b00};

   
   /////////////////////////////////////////////////////////////////////////////
   // External assigns

   // FSM outputs to outside world (registered)
   assign BUS_READ_REQ_OUT       = BusReadReq       ;
   assign BUS_WRITE_REQ_OUT      = BusWriteReq      ;
   assign BUS_START_ADDR_OUT     = BusAddr          ;
   assign BUS_SIZE_OUT           = 2'b10            ; // 32-bit accesses 
   assign BUS_LEN_OUT            = CfgDmaBlkSizeReg ;
   assign BUS_BURST_ADDR_INC_OUT = BusAddrInc       ;
   
   // DMA outputs
   assign DMAC_ACK_OUT           = DmacAck          ;
   assign DMAC_IRQ_OUT           = DmacAck          ;
 
   // TR clear pulse
   assign CFG_DMA_CHCR_TR_CLR_OUT = DmacAck  ;
   
   /////////////////////////////////////////////////////////////////////////////
   // Always blocks


   // Register DR configuration bit at the start of the DMA transaction
   always @(posedge CLK or posedge RST_ASYNC)
   begin : CHCR_DR_REG
      if (RST_ASYNC)
      begin
         CfgDmaChcrDrReg <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         CfgDmaChcrDrReg <= 1'b0;
      end
      else if (EN && FsmCfgRegEn)
      begin
         CfgDmaChcrDrReg <= CFG_DMA_CHCR_DR_IN;
      end
   end

   // Register Block size config at sytart of transaction
   always @(posedge CLK or posedge RST_ASYNC)
   begin : BLK_SIZE_REG
      if (RST_ASYNC)
      begin
         CfgDmaBlkSizeReg <= 5'd0;
      end
      else if (RST_SYNC)
      begin
         CfgDmaBlkSizeReg <= 5'd0;
      end
      else if (EN && FsmCfgRegEn)
      begin
         CfgDmaBlkSizeReg <= CFG_DMA_BLK_SIZE_IN[4:0];
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
         AddrCntVal <= 30'd0;
      end
      else if (RST_SYNC)
      begin
         AddrCntVal <= 30'd0;
      end
      else if (EN)
      begin

         if (FsmCfgRegEn)
         begin
            AddrCntVal <= CFG_DMA_MADR_IN[31:2];
         end
         else if (BUS_LAST_ACK_IN)
         begin
            AddrCntVal <= AddrCntVal + CfgDmaBlkSizeReg;
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
         BlkTmrVal <= 16'h0000;
      end
      else if (RST_SYNC)
      begin
         BlkTmrVal <= 16'h0000;
      end
      else if (EN)
      begin
         if (FsmCfgRegEn)
         begin
            BlkTmrVal <= CFG_DMA_BLK_CNT_IN;
         end
         else if (BUS_LAST_ACK_IN)
         begin
            BlkTmrVal <= BlkTmrVal - CfgDmaBlkSizeReg;
         end
      end
   end
   
   // FSM - Combinatorial process
   always @*
   begin : DPFSM_ST

      // Default values
      DpfsmStateNxt   = DpfsmStateCur;

      FsmCfgRegEn     = 1'b0;
      BusAddrNxt      = 32'h0000_0000;
      BusAddrIncNxt   = 1'b0;
      BusRegEn        = 1'b0;
      BusReadReqNxt   = 1'b0;     
      BusWriteReqNxt  = 1'b0;
      DmacAckNxt      = 1'b0;


      case (DpfsmStateCur)


        DPFSM_IDLE        :
          begin
             if (CFG_DMA_CHCR_TR_IN && CFG_DMA_CHCR_CO_IN)
             begin
                // Outputs
                FsmCfgRegEn = 1'b1;
                // Next state
                DpfsmStateNxt = DPFSM_REG_CFG;
             end
          end
        
        DPFSM_REG_CFG     :
          begin
             if (CfgDmaChcrDrReg                   // From memory, begin filling FIFO
             || (!CfgDmaChcrDrReg && DMAC_REQ_IN)) // From GPU, wait for REQ
             begin
                // Outputs
                BusAddrNxt    = SrcAddr;
                BusAddrIncNxt = SrcBusAddrInc;
                BusRegEn      = 1'b1;
                BusReadReqNxt = 1'b1;
                // Next state
                DpfsmStateNxt  = DPFSM_SRC_RD;
             end
          end
        
        DPFSM_SRC_RD      :
          begin
             // Current outputs
             BusReadReqNxt = 1'b1;

             if (BUS_LAST_ACK_IN && FifoWrFull)
             begin
                // Outputs
                BusReadReqNxt  = 1'b0;
                // Next state
                DpfsmStateNxt  = DPFSM_SRC_RD_DONE;
             end
          end
        
        DPFSM_SRC_RD_DONE :
          begin

             if ((CfgDmaChcrDrReg && DMAC_REQ_IN)
              || !CfgDmaChcrDrReg)
             begin
                // Outputs
                BusAddrNxt     = GPU_DATA;
                BusAddrIncNxt  = DstBusAddrInc;
                BusRegEn       = 1'b1;
                BusWriteReqNxt = 1'b1;
                // Next state
                DpfsmStateNxt  = DPFSM_DST_WR;
             end
          end
        
        DPFSM_DST_WR      :
          begin
             // Current outputs
             BusWriteReqNxt = 1'b1;

             if (BUS_LAST_ACK_IN && FifoRdEmpty)
             begin
                // Outputs
                BusWriteReqNxt  = 1'b0;
                // Next state
                DpfsmStateNxt   = DPFSM_DST_WR_DONE;
             end
          end
        
        DPFSM_DST_WR_DONE :
          begin
             // If the block timer is 0, the DMA data has all been transferred, issue
             // ACK and go back to IDLE
             if (16'h0000 == BlkTmrVal)
             begin
                // Next state outputs
                DmacAckNxt = 1'b1;
                // Next state
                DpfsmStateNxt = DPFSM_DMA_ACK;
             end

             // Otherwise start the next source read
             else
             begin
                // Outputs
                BusAddrNxt    = SrcAddr;
                BusAddrIncNxt = SrcBusAddrInc;
                BusRegEn      = 1'b1;
                BusReadReqNxt = 1'b1;
                // Next state
                DpfsmStateNxt  = DPFSM_SRC_RD;
             end
          end
        
        DPFSM_DMA_ACK :
          begin
             // Next state
             DpfsmStateNxt  = DPFSM_IDLE;
          end

        default : DpfsmStateNxt  = DPFSM_IDLE;
        
      endcase
   end
   


   // FSM - Clocked  process
   always @(posedge CLK or posedge RST_ASYNC)
   begin : DPFSM_CP
      if (RST_ASYNC)
      begin
         DpfsmStateCur <= DPFSM_IDLE;

         BusReadReq    <= 1'b0; 
         BusWriteReq   <= 1'b0;
         DmacAck       <= 1'b0;

         BusAddr       <= 32'h0000_0000;
         BusAddrInc    <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         DpfsmStateCur <= DPFSM_IDLE;

         BusReadReq    <= 1'b0; 
         BusWriteReq   <= 1'b0;
         DmacAck       <= 1'b0;

         BusAddr       <= 32'h0000_0000;
         BusAddrInc    <= 1'b0;
      end
      else if (EN)
      begin
         // Next state register
         DpfsmStateCur <= DpfsmStateNxt  ;

         // Direct outputs from FSM
         BusReadReq    <= BusReadReqNxt  ;
         BusWriteReq   <= BusWriteReqNxt ;
         DmacAck       <= DmacAckNxt     ;

         // Bus-registered outputs
         if (BusRegEn)
         begin
            BusAddr    <= BusAddrNxt    ;
            BusAddrInc <= BusAddrIncNxt ;
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

    .WRITE_EN_IN    (BusReadReq  & BUS_READ_ACK_IN  ),
    .WRITE_DATA_IN  (BUS_READ_DATA_IN ),
    .WRITE_FULL_OUT (FifoWrFull       ),

    .READ_EN_IN     (BusWriteReq & BUS_WRITE_ACK_IN ),
    .READ_DATA_OUT  (BUS_WRITE_DATA_OUT ),
    .READ_EMPTY_OUT (FifoRdEmpty        ) 
    );



   
endmodule




