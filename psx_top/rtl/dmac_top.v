// Insert module header here..
module DMAC_TOP
   (

    // Clocks and resets
    input           CLK       ,
    input           EN        ,
    input           RST_SYNC  ,
    input           RST_ASYNC ,

    // Wishbone SLAVE interface (goes to regs block)
    input   [31:0] WB_REGS_ADR_IN      ,
    input          WB_REGS_DMAC_CYC_IN      ,
    input          WB_REGS_DMAC_STB_IN      ,
    input          WB_REGS_WE_IN       ,
    input   [ 3:0] WB_REGS_SEL_IN      ,
    output         WB_REGS_DMAC_ACK_OUT     ,
    output         WB_REGS_DMAC_STALL_OUT   ,
    output         WB_REGS_DMAC_ERR_OUT     ,
    output  [31:0] WB_REGS_DMAC_DAT_RD_OUT  ,
    input   [31:0] WB_REGS_DAT_WR_IN   ,
    
    // Wishbone interface (Master)
    output [31:0]  WB_ADR_OUT     ,
    output         WB_CYC_OUT     ,
    output         WB_STB_OUT     ,
    output         WB_WE_OUT      ,
    output [ 3:0]  WB_SEL_OUT     ,
    output [ 2:0]  WB_CTI_OUT     ,
    output [ 1:0]  WB_BTE_OUT     ,
    input          WB_ACK_IN      ,
    input          WB_STALL_IN    ,
    input          WB_ERR_IN      ,
    input  [31:0]  WB_DAT_RD_IN   ,
    output [31:0]  WB_DAT_WR_OUT  ,

    // DMA Request and Acknowledge
    input    [6:0] DMAC_REQ_IN    ,
    output   [6:0] DMAC_ACK_OUT   ,

    // DMA IRQ out
    output         DMAC_IRQ_OUT

    
    );
// includes
`include "psx_mem_map.vh"

   
   // parameters

   /////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // Configuration registers
    wire    [31:0] CfgDmacIcr    ;
    wire    [31:0] CfgDmacPcr    ;

   // Use 2d arrays for the common buses
    wire    [31:0] CfgDmacMadr  [6:0]  ;
    wire    [31:0] CfgDmacBcr   [6:0]  ;
   // Split the CHCR into individual bits
   wire       [ 6:0] CfgDmacChcrDr     ;
   wire       [ 6:0] CfgDmacChcrCo     ;
   wire       [ 6:0] CfgDmacChcrLi     ;
   wire       [ 6:0] CfgDmacChcrTr     ;  
   wire       [ 6:0] CfgDmacChcrTrClr  ;  

   // Wires to format the config and requests into convenient arbitration form
   wire [ 6:0]       DmacPcrEn         ;
   wire [ 6:0]       DmacArbSel        ;
   
   // Not 1-to-1 req and ack relationship. For example CH2 can come from either
   // the LI or VRAM copies. Use wires and combine at this level
   wire       [ 6:0] DmacReq   ;
   wire       [ 6:0] DmacAck   ;
   wire       [ 6:0] DmacIrq   ;

   // The DMA CH2 can be either the PERI (VRAM copies) or LI (linked list graphics)
   // Need to double up all the outputs, and then OR together (they're mutually exclusive)
   wire              GpuLiAck   ;
   wire              GpuPeriAck ;
   wire              GpuLiIrq   ;
   wire              GpuPeriIrq ;
   wire              GpuLiChcrTrClr   ;
   wire              GpuPeriChcrTrClr ;


   wire   [31:0] GpuPeriChBusStartAddr    ;
   wire          GpuPeriChBusReadReq      ;
   wire          GpuPeriChBusWriteReq     ;
   wire   [ 1:0] GpuPeriChBusSize         ;
   wire   [ 4:0] GpuPeriChBusLen          ; 
   wire          GpuPeriChBusBurstAddrInc ;
   wire   [31:0] GpuPeriChBusWriteData    ;

   wire   [31:0] GpuLiChBusStartAddr      ;
   wire          GpuLiChBusReadReq        ;
   wire          GpuLiChBusWriteReq       ;
   wire   [ 1:0] GpuLiChBusSize           ;
   wire   [ 4:0] GpuLiChBusLen            ; 
   wire          GpuLiChBusBurstAddrInc   ;
   wire   [31:0] GpuLiChBusWriteData      ;


   
   // Dmac bus interfaces
   wire   [31:0]       ChBusStartAddr    [6:0] ;
   wire          [6:0] ChBusReadReq            ;
   wire          [6:0] ChBusReadAck            ;
   wire          [6:0] ChBusWriteReq           ;
   wire          [6:0] ChBusWriteAck           ;
   wire          [6:0] ChBusLastAck            ;
   wire   [ 1:0]       ChBusSize         [6:0] ;
   wire   [ 4:0]       ChBusLen          [6:0] ; 
   wire          [6:0] ChBusBurstAddrInc       ;
   wire   [31:0]       ChBusReadData     [6:0] ;
   wire   [31:0]       ChBusWriteData    [6:0] ;

   // Dmac channel arbiter interface to Bus Master
   wire   [31:0] ArbBusStartAddr        ;
   wire          ArbBusReadReq          ;
   wire          ArbBusReadAck          ;
   wire          ArbBusWriteReq         ;
   wire          ArbBusWriteAck         ;
   wire          ArbBusLastAck          ;
   wire   [ 1:0] ArbBusSize             ;
   wire   [ 4:0] ArbBusLen              ; 
   wire          ArbBusBurstAddrInc     ;
   wire   [31:0] ArbBusReadData         ;
   wire   [31:0] ArbBusWriteData        ;

  
   /////////////////////////////////////////////////////////////////////////////
   // combinatorial assigns

   assign DMAC_ACK_OUT[DMAC_MDECIN_CH  ] = 1'b0;
   assign DMAC_ACK_OUT[DMAC_MDECOUT_CH ] = 1'b0;
   assign DMAC_ACK_OUT[DMAC_GPU_CH     ] = GpuLiAck | GpuPeriAck;
   assign DMAC_ACK_OUT[DMAC_CDROM_CH   ] = 1'b0;
   assign DMAC_ACK_OUT[DMAC_SPU_CH     ] = 1'b0;
   assign DMAC_ACK_OUT[DMAC_PIO_CH     ] = 1'b0;
   assign DMAC_ACK_OUT[DMAC_OT_CH      ] = 1'b0;
   assign DmacReq = DMAC_REQ_IN; // Can add gating later if needed here

   // Mux the Bus signals from the DMA Channel to Arbiter according to whether it's a continuous transfer
   assign ChBusStartAddr    [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusStartAddr    : GpuLiChBusStartAddr   ;
   assign ChBusReadReq      [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusReadReq      : GpuLiChBusReadReq     ;
   assign ChBusWriteReq     [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusWriteReq     : GpuLiChBusWriteReq    ;
   assign ChBusSize         [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusSize         : GpuLiChBusSize        ;
   assign ChBusLen          [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusLen          : GpuLiChBusLen         ;
   assign ChBusBurstAddrInc [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusBurstAddrInc : GpuLiChBusBurstAddrInc;
   assign ChBusWriteData    [DMAC_GPU_CH] = CfgDmacChcrCo [DMAC_GPU_CH] ? GpuPeriChBusWriteData    : GpuLiChBusWriteData   ; 
                            
   // Tie off the unused DMA Channels (MDECIN, MDECOUT, CDROM, SPU, and PIO
   assign ChBusStartAddr    [DMAC_MDECIN_CH]  = 32'h0000_0000;
   assign ChBusReadReq      [DMAC_MDECIN_CH]  = 1'b0;
   assign ChBusWriteReq     [DMAC_MDECIN_CH]  = 1'b0;
   assign ChBusSize         [DMAC_MDECIN_CH]  = 2'b00;
   assign ChBusLen          [DMAC_MDECIN_CH]  = 5'd0;
   assign ChBusBurstAddrInc [DMAC_MDECIN_CH]  = 1'b0;
   assign ChBusWriteData    [DMAC_MDECIN_CH]  = 32'h0000_0000;

   assign ChBusStartAddr    [DMAC_MDECOUT_CH] = 32'h0000_0000;
   assign ChBusReadReq      [DMAC_MDECOUT_CH] = 1'b0;
   assign ChBusWriteReq     [DMAC_MDECOUT_CH] = 1'b0;
   assign ChBusSize         [DMAC_MDECOUT_CH] = 2'b00;
   assign ChBusLen          [DMAC_MDECOUT_CH] = 5'd0;
   assign ChBusBurstAddrInc [DMAC_MDECOUT_CH] = 1'b0;
   assign ChBusWriteData    [DMAC_MDECOUT_CH] = 32'h0000_0000;

   assign ChBusStartAddr    [DMAC_CDROM_CH]   = 32'h0000_0000;
   assign ChBusReadReq      [DMAC_CDROM_CH]   = 1'b0;
   assign ChBusWriteReq     [DMAC_CDROM_CH]   = 1'b0;
   assign ChBusSize         [DMAC_CDROM_CH]   = 2'b00;
   assign ChBusLen          [DMAC_CDROM_CH]   = 5'd0;
   assign ChBusBurstAddrInc [DMAC_CDROM_CH]   = 1'b0;
   assign ChBusWriteData    [DMAC_CDROM_CH]   = 32'h0000_0000;

   assign ChBusStartAddr    [DMAC_SPU_CH]     = 32'h0000_0000;
   assign ChBusReadReq      [DMAC_SPU_CH]     = 1'b0;
   assign ChBusWriteReq     [DMAC_SPU_CH]     = 1'b0;
   assign ChBusSize         [DMAC_SPU_CH]     = 2'b00;
   assign ChBusLen          [DMAC_SPU_CH]     = 5'd0;
   assign ChBusBurstAddrInc [DMAC_SPU_CH]     = 1'b0;
   assign ChBusWriteData    [DMAC_SPU_CH]     = 32'h0000_0000;

   assign ChBusStartAddr    [DMAC_PIO_CH]     = 32'h0000_0000;
   assign ChBusReadReq      [DMAC_PIO_CH]     = 1'b0;
   assign ChBusWriteReq     [DMAC_PIO_CH]     = 1'b0;
   assign ChBusSize         [DMAC_PIO_CH]     = 2'b00;
   assign ChBusLen          [DMAC_PIO_CH]     = 5'd0;
   assign ChBusBurstAddrInc [DMAC_PIO_CH]     = 1'b0;
   assign ChBusWriteData    [DMAC_PIO_CH]     = 32'h0000_0000;

   // AND mask the Arbiter to DMA channel signals using the arbiter output
   // This includes the Write/Read/Last Ack. Read data can be sent to all
   assign ChBusReadAck  = DmacArbSel & {7{ArbBusReadAck  }};
   assign ChBusWriteAck = DmacArbSel & {7{ArbBusWriteAck }};
   assign ChBusLastAck  = DmacArbSel & {7{ArbBusLastAck  }};
   // Could gate the read data, but it is a don't care
   assign ChBusReadData [DMAC_MDECIN_CH  ] = ArbBusReadData;
   assign ChBusReadData [DMAC_MDECOUT_CH ] = ArbBusReadData;
   assign ChBusReadData [DMAC_GPU_CH     ] = ArbBusReadData;
   assign ChBusReadData [DMAC_CDROM_CH   ] = ArbBusReadData;
   assign ChBusReadData [DMAC_SPU_CH     ] = ArbBusReadData;
   assign ChBusReadData [DMAC_PIO_CH     ] = ArbBusReadData;
   assign ChBusReadData [DMAC_OT_CH      ] = ArbBusReadData;

   // DMAC Engine buses wiring
   assign DmacPcrEn = {CfgDmacPcr [DMAC_PCR_CH6_EN_BIT],
                       CfgDmacPcr [DMAC_PCR_CH5_EN_BIT],
                       CfgDmacPcr [DMAC_PCR_CH4_EN_BIT],
                       CfgDmacPcr [DMAC_PCR_CH3_EN_BIT],
                       CfgDmacPcr [DMAC_PCR_CH2_EN_BIT],
                       CfgDmacPcr [DMAC_PCR_CH1_EN_BIT],
                       CfgDmacPcr [DMAC_PCR_CH0_EN_BIT]
                       };
                              
   // Arbiter combining with the 7 DMA channels
   
   /////////////////////////////////////////////////////////////////////////////
   // external assigns

   assign DMAC_ACK_OUT = DmacAck ;

   
   /////////////////////////////////////////////////////////////////////////////
   // always blocks

                                           
                                           
   /////////////////////////////////////////////////////////////////////////////
   // Wishbone Slave regs
   DMAC_WB_REGS dmac_wb_regs
      (
       .CLK                       (CLK          ),
       .EN                        (EN           ),
       .RST_SYNC                  (RST_SYNC     ),
       .RST_ASYNC                 (RST_ASYNC    ),

       .WB_REGS_ADR_IN            (WB_REGS_ADR_IN            ),
       .WB_REGS_DMAC_CYC_IN       (WB_REGS_DMAC_CYC_IN       ),
       .WB_REGS_DMAC_STB_IN       (WB_REGS_DMAC_STB_IN       ),
       .WB_REGS_WE_IN       	  (WB_REGS_WE_IN             ),
       .WB_REGS_SEL_IN      	  (WB_REGS_SEL_IN            ),
       .WB_REGS_DMAC_ACK_OUT      (WB_REGS_DMAC_ACK_OUT      ),
       .WB_REGS_DMAC_STALL_OUT    (WB_REGS_DMAC_STALL_OUT    ),
       .WB_REGS_DMAC_ERR_OUT      (WB_REGS_DMAC_ERR_OUT      ),
       .WB_REGS_DMAC_DAT_RD_OUT   (WB_REGS_DMAC_DAT_RD_OUT   ),
       .WB_REGS_DAT_WR_IN         (WB_REGS_DAT_WR_IN         ),
      
       .CFG_DMAC_ICR_OUT          (CfgDmacIcr           ),
       .CFG_DMAC_PCR_OUT          (CfgDmacPcr           ),
      
       .CFG_DMAC_MADR0_OUT        (CfgDmacMadr[0]       ),
       .CFG_DMAC_MADR1_OUT        (CfgDmacMadr[1]       ),
       .CFG_DMAC_MADR2_OUT        (CfgDmacMadr[2]       ),
       .CFG_DMAC_MADR3_OUT        (CfgDmacMadr[3]       ),
       .CFG_DMAC_MADR4_OUT        (CfgDmacMadr[4]       ),
       .CFG_DMAC_MADR5_OUT        (CfgDmacMadr[5]       ),
       .CFG_DMAC_MADR6_OUT        (CfgDmacMadr[6]       ),
      
       .CFG_DMAC_BCR0_OUT         (CfgDmacBcr[0]        ),
       .CFG_DMAC_BCR1_OUT         (CfgDmacBcr[1]        ),
       .CFG_DMAC_BCR2_OUT         (CfgDmacBcr[2]        ),
       .CFG_DMAC_BCR3_OUT         (CfgDmacBcr[3]        ),
       .CFG_DMAC_BCR4_OUT         (CfgDmacBcr[4]        ),
       .CFG_DMAC_BCR5_OUT         (CfgDmacBcr[5]        ),
       .CFG_DMAC_BCR6_OUT         (CfgDmacBcr[6]        ),

       .CFG_DMAC_CHCR_DR_OUT      (CfgDmacChcrDr        ), 
       .CFG_DMAC_CHCR_CO_OUT      (CfgDmacChcrCo        ), 
       .CFG_DMAC_CHCR_LI_OUT      (CfgDmacChcrLi        ), 
       .CFG_DMAC_CHCR_TR_OUT      (CfgDmacChcrTr        ), 
       .CFG_DMAC_CHCR_TR_CLR_IN   (CfgDmacChcrTrClr     )

       
       
       );


   /////////////////////////////////////////////////////////////////////////////
   // DMAC Arbiter - Generates one-hot DMA channel enable based on requests,
   //                the PCR register enables and current bus activity.
   //                TODO ! Add a programmable priority encoder here
   //
   DMAC_ARB dmac_arb
      (
       .CLK                 (CLK             ),
       .EN                  (EN              ),
       .RST_SYNC            (RST_SYNC        ),
       .RST_ASYNC           (RST_ASYNC       ),

       .DMAC_PCR_CH_EN_IN   (DmacPcrEn       ),

       .DMAC_REQ_IN         (DMAC_REQ_IN     ),
       .DMAC_ACK_IN         (DMAC_ACK_OUT    ),
       .BUS_LAST_ACK_IN     (ArbBusLastAck   ),

       .DMAC_CH_SEL_OUT     (DmacArbSel      )  
       );




   

   /////////////////////////////////////////////////////////////////////////////
   // DMAC Channel 2 - Can be either normal peripheral (DMA transfer) 
   //                  or Linked List GPU packets. 
   // 
   DMAC_PERI dmac_gpu_peri_ch2
      (
       .CLK                      (CLK               ),
       .EN                       (EN                ),
       .RST_SYNC                 (RST_SYNC          ),
       .RST_ASYNC                (RST_ASYNC         ),

       .CFG_DMA_CHCR_TR_IN       (CfgDmacChcrTr     [DMAC_GPU_CH]),
       .CFG_DMA_CHCR_TR_CLR_OUT  (GpuPeriChcrTrClr           ),
       .CFG_DMA_CHCR_CO_IN       (CfgDmacChcrCo     [DMAC_GPU_CH]),
       .CFG_DMA_CHCR_DR_IN       (CfgDmacChcrDr     [DMAC_GPU_CH]),
       .CFG_DMA_MADR_IN          (CfgDmacMadr       [DMAC_GPU_CH]),
       .CFG_DMA_BLK_CNT_IN       (CfgDmacBcr        [DMAC_GPU_CH]
                                  [DMAC_BCR_BLK_CNT_MSB 
                                   :DMAC_BCR_BLK_CNT_LSB ]),
       .CFG_DMA_BLK_SIZE_IN      (CfgDmacBcr        [DMAC_GPU_CH]
                                  [DMAC_BCR_BLK_SIZE_MSB
                                   :DMAC_BCR_BLK_SIZE_LSB]),
//       .CFG_DMAC_MADR_IN         (CfgDmacMadr       [DMAC_GPU_CH]),
//       .CFG_DMAC_CHCR_IN         (CfgDmacChcr       [DMAC_GPU_CH]),
//       .CFG_DMAC_BCR_IN          (CfgDmacBcr        [DMAC_GPU_CH]),

       .BUS_START_ADDR_OUT       (GpuPeriChBusStartAddr                  ),
       .BUS_READ_REQ_OUT         (GpuPeriChBusReadReq                    ),
       .BUS_READ_ACK_IN          (ChBusReadAck             [DMAC_GPU_CH] ),
       .BUS_WRITE_REQ_OUT        (GpuPeriChBusWriteReq                   ),
       .BUS_WRITE_ACK_IN         (ChBusWriteAck            [DMAC_GPU_CH] ),
       .BUS_LAST_ACK_IN          (ChBusLastAck             [DMAC_GPU_CH] ),
       .BUS_SIZE_OUT             (GpuPeriChBusSize                       ),
       .BUS_LEN_OUT              (GpuPeriChBusLen                        ), 
       .BUS_BURST_ADDR_INC_OUT   (GpuPeriChBusBurstAddrInc               ), 
       .BUS_READ_DATA_IN         (ChBusReadData            [DMAC_GPU_CH] ),
       .BUS_WRITE_DATA_OUT       (GpuPeriChBusWriteData                  ),

       .DMAC_REQ_IN              (DmacReq           [DMAC_GPU_CH]),
       .DMAC_ACK_OUT             (GpuPeriAck                 ),
       .DMAC_IRQ_OUT             (GpuPeriIrq                 )
       );


   // Linked list DMA CH2 (GPU)
   DMAC_LI 
      #(
        .FIFO_DEPTH (16),
        .FIFO_WIDTH (32)
        )
   dmac_gpu_li_ch2
      (
       .CLK                      (CLK          ),
       .EN                       (EN           ),
       .RST_SYNC                 (RST_SYNC     ),
       .RST_ASYNC                (RST_ASYNC    ),

       .CFG_DMA_CHCR_TR_IN       (CfgDmacChcrTr     [DMAC_GPU_CH] ),
       .CFG_DMA_CHCR_TR_CLR_OUT  (GpuLiChcrTrClr                  ),
       .CFG_DMA_CHCR_LI_IN       (CfgDmacChcrLi     [DMAC_GPU_CH] ),
       .CFG_DMA_MADR_IN          (CfgDmacMadr       [DMAC_GPU_CH] ),

       .BUS_READ_REQ_OUT         (GpuLiChBusReadReq   ),
       .BUS_READ_ACK_IN          (ChBusReadAck             [DMAC_GPU_CH]  ),
       .BUS_WRITE_REQ_OUT        (GpuLiChBusWriteReq  ),
       .BUS_WRITE_ACK_IN         (ChBusWriteAck            [DMAC_GPU_CH]  ),
       .BUS_LAST_ACK_IN          (ChBusLastAck             [DMAC_GPU_CH]  ),

       .BUS_START_ADDR_OUT       (GpuLiChBusStartAddr       ),
       .BUS_SIZE_OUT             (GpuLiChBusSize            ),
       .BUS_LEN_OUT              (GpuLiChBusLen             ),
       .BUS_BURST_ADDR_INC_OUT   (GpuLiChBusBurstAddrInc    ),
      
       .BUS_WRITE_DATA_OUT       (GpuLiChBusWriteData       ),
       .BUS_READ_DATA_IN         (ChBusReadData            [DMAC_GPU_CH]  ),

       .DMAC_REQ_IN              (DmacReq           [DMAC_GPU_CH] ),
       .DMAC_ACK_OUT             (GpuLiAck     ),
       .DMAC_IRQ_OUT             (GpuLiIrq     )
       );






   
   /////////////////////////////////////////////////////////////////////////////
   // DMAC Channel 6 - Ordering Table Memory Writes
   // Mem-to-mem DMA transaction, no DMAC REQ/ACK used.
   // Use the TR bit as the REQ, and TR_CLR bit as an ACK to keep it consistent
   DMAC_OT dmac_ot_ch6
      (
       .CLK                      (CLK          ),
       .EN                       (EN           ),
       .RST_SYNC                 (RST_SYNC     ),
       .RST_ASYNC                (RST_ASYNC    ),
      
       .CFG_DMAC_MADR_IN         (CfgDmacMadr       [DMAC_OT_CH]),
       .CFG_DMAC_BCR_IN          (CfgDmacBcr        [DMAC_OT_CH]),
       .CFG_DMAC_CHCR_TR_IN      (CfgDmacChcrTr     [DMAC_OT_CH]),
       .CFG_DMAC_CHCR_TR_CLR_OUT (CfgDmacChcrTrClr  [DMAC_OT_CH]),

       .BUS_START_ADDR_OUT       (ChBusStartAddr    [DMAC_OT_CH]),
       .BUS_READ_REQ_OUT         (ChBusReadReq      [DMAC_OT_CH]),
       .BUS_READ_ACK_IN          (ChBusReadAck      [DMAC_OT_CH]),
       .BUS_WRITE_REQ_OUT        (ChBusWriteReq     [DMAC_OT_CH]),
       .BUS_WRITE_ACK_IN         (ChBusWriteAck     [DMAC_OT_CH]),
       .BUS_LAST_ACK_IN          (ChBusLastAck      [DMAC_OT_CH]),
       .BUS_SIZE_OUT             (ChBusSize         [DMAC_OT_CH]),
       .BUS_LEN_OUT              (ChBusLen          [DMAC_OT_CH]), 
       .BUS_BURST_ADDR_INC_OUT   (ChBusBurstAddrInc [DMAC_OT_CH]), 
       .BUS_READ_DATA_IN         (ChBusReadData     [DMAC_OT_CH]),
       .BUS_WRITE_DATA_OUT       (ChBusWriteData    [DMAC_OT_CH])
       );

   
   /////////////////////////////////////////////////////////////////////////////
   // Wishbone Master arbiter (7-M to 1-S)


   

   /////////////////////////////////////////////////////////////////////////////
   // Wishbone Master for all the DMA sources
   WB_MASTER wb_master_dmac
      (
       .CLK                   (CLK              ),
       .EN                    (EN               ),
       .RST_SYNC              (RST_SYNC         ),
       .RST_ASYNC             (RST_ASYNC        ), 

       .WB_ADR_OUT            (WB_ADR_OUT       ),
       .WB_CYC_OUT            (WB_CYC_OUT       ),
       .WB_STB_OUT            (WB_STB_OUT       ),
       .WB_WE_OUT             (WB_WE_OUT        ),
       .WB_SEL_OUT            (WB_SEL_OUT       ),
       .WB_CTI_OUT            (WB_CTI_OUT       ),
       .WB_BTE_OUT            (WB_BTE_OUT       ),
       .WB_ACK_IN             (WB_ACK_IN        ),
       .WB_STALL_IN           (WB_STALL_IN      ),
       .WB_ERR_IN             (WB_ERR_IN        ),
       .WB_DAT_RD_IN          (WB_DAT_RD_IN     ),
       .WB_DAT_WR_OUT         (WB_DAT_WR_OUT    ),
      
       .BUS_START_ADDR_IN     (ArbBusStartAddr     ),
      
       .BUS_READ_REQ_IN       (ArbBusReadReq       ),
       .BUS_READ_ACK_OUT      (ArbBusReadAck       ),
       .BUS_WRITE_REQ_IN      (ArbBusWriteReq      ),
       .BUS_WRITE_ACK_OUT     (ArbBusWriteAck      ),
       .BUS_LAST_ACK_OUT      (ArbBusLastAck       ),
      
       .BUS_SIZE_IN           (ArbBusSize          ),
       .BUS_LEN_IN            (ArbBusLen           ), 
       .BUS_BURST_ADDR_INC_IN (ArbBusBurstAddrInc  ),
      
       .BUS_READ_DATA_OUT     (ArbBusReadData      ),
       .BUS_WRITE_DATA_IN     (ArbBusWriteData     )
      
       );
   


   
endmodule
