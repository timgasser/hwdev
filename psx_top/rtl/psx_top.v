// insert module header here
module PSX_TOP
   (

    // Clocks and resets
    input           CLK       ,
    input           EN        ,
    input           RST_SYNC  ,
    input           RST_ASYNC ,

    // System bus to SDRAM interface
    output [31:0]  WB_SYS_ADR_OUT         ,
    output         WB_SYS_ROM_CYC_OUT     ,
    output         WB_SYS_ROM_STB_OUT     ,
    output         WB_SYS_DRAM_CYC_OUT   ,
    output         WB_SYS_DRAM_STB_OUT   ,
    output         WB_SYS_WE_OUT          ,
    output [ 3:0]  WB_SYS_SEL_OUT         ,
    output [ 2:0]  WB_SYS_CTI_OUT         ,
    output [ 1:0]  WB_SYS_BTE_OUT         ,

    input          WB_SYS_ROM_ACK_IN      ,
    input          WB_SYS_ROM_STALL_IN    ,
    input          WB_SYS_ROM_ERR_IN      ,
    input          WB_SYS_DRAM_ACK_IN    ,
    input          WB_SYS_DRAM_STALL_IN  ,
    input          WB_SYS_DRAM_ERR_IN    ,

    input  [31:0]  WB_SYS_DAT_ROM_RD_IN     ,
    input  [31:0]  WB_SYS_DAT_DRAM_RD_IN   ,
    output [31:0]  WB_SYS_DAT_WR_OUT        ,
   
    // Point-to-point GPU RAM interface
    output [31:0]  WB_GPU_ADR_OUT     ,
    output         WB_GPU_CYC_OUT     ,
    output         WB_GPU_STB_OUT     ,
    output         WB_GPU_WE_OUT      ,
    output [ 3:0]  WB_GPU_SEL_OUT     ,
    output [ 2:0]  WB_GPU_CTI_OUT     ,
    output [ 1:0]  WB_GPU_BTE_OUT     ,

    input          WB_GPU_ACK_IN      ,
    input          WB_GPU_STALL_IN    ,
    input          WB_GPU_ERR_IN      ,

    input  [31:0]  WB_GPU_DAT_RD_IN   ,
    output [31:0]  WB_GPU_DAT_WR_OUT  
   
   
   
   
    );
   // include

   // parameters
   
   ////////////////////////////////////////////////////////////////////////////////
   // wires / regs

   // MIPS1 Top Wishbone Master signals to PSX_BUS
   wire [31:0] 	   WbMipsAdr     ;
   wire            WbMipsCyc     ;
   wire            WbMipsStb     ;
   wire            WbMipsWe      ;
   wire [ 3:0] 	   WbMipsSel     ;
   wire [ 2:0] 	   WbMipsCti     ;
   wire [ 1:0] 	   WbMipsBte     ;
   wire            WbMipsAck     ;
   wire            WbMipsStall   ;
   wire            WbMipsErr     ;
   wire [31:0] 	   WbMipsDatRd   ;
   wire [31:0] 	   WbMipsDatWr   ;
   wire [5:0] 	   MipsTopHwIrq     ;

   // Root counter signals
   wire            WbVsStb     ;
   wire            WbHsStb     ;
   wire            WbActiveRow ;
   wire            WbActiveCol ;
   wire [3:0] 	   RcntIrq     ;
   
   // Interrupt controller signals
   wire [10:0] 	   IntSource   ;
   wire            MipsHwInt   ;

   // DMA Wishbone Master signals to PSX_BUS
   wire [31:0] 	   WbDmacAdr     ;
   wire            WbDmacCyc     ;
   wire            WbDmacStb     ;
   wire            WbDmacWe      ;
   wire [ 3:0] 	   WbDmacSel     ;
   wire [ 2:0] 	   WbDmacCti     ;
   wire [ 1:0] 	   WbDmacBte     ;
   wire            WbDmacAck     ;
   wire            WbDmacStall   ;
   wire            WbDmacErr     ;
   wire [31:0] 	   WbDmacDatRd   ;
   wire [31:0] 	   WbDmacDatWr   ;

   // Dma Request / Acknowledge and IRQ
   wire [6:0] 	   DmacReq = 7'b000_0000; // todo add DMA requests on
   wire [6:0] 	   DmacAck ;
   wire            DmacIrq ;
   
   // There are the following slaves on the regs bus:
   // Root Counter          - Rcnt
   // Interrrupt Controller - Intc
   // Dma Controller        - Dmac
   // Bios                  - Bios
   // MDEC decoder          - Mdec
   // Memory Card           - MemCard
   // Sound Processing Unit - Spu
   // CDROM Controller      - Cdrom
   // Pad                   - Pad
   
   // System Bus - Master to Slave Common signals to all slaves
   // (ADR, WE, SEL, DAT_WR)
   // These are wired to top level ports directly. 
   wire [31:0] 	   WbSysAdr     ;
   wire            WbSysCyc     ;
   wire            WbSysStb     ;
   wire            WbSysWe      ;
   wire [ 3:0] 	   WbSysSel     ;
   wire [ 2:0] 	   WbSysCti     ;
   wire [ 1:0] 	   WbSysBte     ;
   wire [31:0] 	   WbSysDatWr   ;

   // Slave-specific MAster -> Slave signals (CYC, STB)
   wire 	   WbSysRomCyc      ;
   wire 	   WbSysRomStb      ;
   wire 	   WbSysDramCyc     ;
   wire 	   WbSysDramStb     ;
   wire 	   WbSysGpuCyc      ;
   wire 	   WbSysGpuStb      ;

   // Slave specific Slave -> Master signals
   wire 	   WbSysRomAck      ;
   wire 	   WbSysRomStall    ;
   wire 	   WbSysRomErr      ;
   wire [31:0] 	   WbSysRomDatRd    ;
   wire 	   WbSysDramAck     ;
   wire 	   WbSysDramStall   ;
   wire 	   WbSysDramErr     ;
   wire [31:0] 	   WbSysDramDatRd   ;
   wire 	   WbSysGpuAck      ;
   wire 	   WbSysGpuStall    ;
   wire 	   WbSysGpuErr      ;
   wire [31:0] 	   WbSysGpuDatRd    ;

   // Registers Bus - Master to Slave Common signals to all slaves
   // (ADR, WE, SEL, DAT_WR)
   wire [31:0] 	   WbRegsAdr      ;
   wire            WbRegsWe       ;
   wire [ 3:0] 	   WbRegsSel      ;
   wire [31:0] 	   WbRegsDatWr    ;

   // Slave-spefic MAster -> Slave signals (CYC, STB)
   wire 	   WbRegsRcntCyc      ;
   wire 	   WbRegsRcntStb      ;
   wire 	   WbRegsIntcCyc      ;
   wire 	   WbRegsIntcStb      ;
   wire 	   WbRegsDmacCyc      ;
   wire 	   WbRegsDmacStb      ;
   wire 	   WbRegsBiosCyc      ;
   wire 	   WbRegsBiosStb      ;
   wire 	   WbRegsMdecCyc      ;
   wire 	   WbRegsMdecStb      ;
   wire 	   WbRegsMemCardStb   ;
   wire 	   WbRegsMemCardCyc   ;
   wire 	   WbRegsSpuCyc       ;
   wire 	   WbRegsSpuStb       ;
   wire 	   WbRegsCdromStb     ;
   wire 	   WbRegsCdromCyc     ;
   wire 	   WbRegsPadStb       ;
   wire 	   WbRegsPadCyc       ;

   // Slave specific Slave -> Master signals
   wire 	   WbRegsRcntAck      ;
   wire 	   WbRegsRcntStall    ;
   wire 	   WbRegsRcntErr      ;
   wire [31:0] 	   WbRegsRcntDatRd    ;
   wire 	   WbRegsIntcAck      ;
   wire 	   WbRegsIntcStall    ;
   wire 	   WbRegsIntcErr      ;
   wire [31:0] 	   WbRegsIntcDatRd    ;
   wire 	   WbRegsDmacAck      ;
   wire 	   WbRegsDmacStall    ;
   wire 	   WbRegsDmacErr      ;
   wire [31:0] 	   WbRegsDmacDatRd    ;
   wire 	   WbRegsBiosAck      ;
   wire 	   WbRegsBiosStall    ;
   wire 	   WbRegsBiosErr      ;
   wire [31:0] 	   WbRegsBiosDatRd    ;
   wire 	   WbRegsMdecAck      ;
   wire 	   WbRegsMdecStall    ;
   wire 	   WbRegsMdecErr      ;
   wire [31:0] 	   WbRegsMdecDatRd    ;
   wire 	   WbRegsMemCardAck   ;
   wire 	   WbRegsMemCardStall ;
   wire 	   WbRegsMemCardErr   ;
   wire [31:0] 	   WbRegsMemCardDatRd ;
   wire 	   WbRegsSpuAck       ;
   wire 	   WbRegsSpuStall     ;
   wire 	   WbRegsSpuErr       ;
   wire [31:0] 	   WbRegsSpuDatRd     ; 
   wire 	   WbRegsCdromAck     ;
   wire 	   WbRegsCdromStall   ;
   wire 	   WbRegsCdromErr     ;
   wire [31:0] 	   WbRegsCdromDatRd   ;
   wire 	   WbRegsPadAck       ;
   wire 	   WbRegsPadStall     ;
   wire 	   WbRegsPadErr       ;
   wire [31:0] 	   WbRegsPadDatRd     ;



   
   
   // combinatorial assigns
   // external assigns

   // Tie off the GPU local bus before the GPU is designed
    assign WB_GPU_ADR_OUT     = 32'h0000_0000;
    assign WB_GPU_CYC_OUT     = 1'b0;
    assign WB_GPU_STB_OUT     = 1'b0;
    assign WB_GPU_WE_OUT      = 1'b0;
    assign WB_GPU_SEL_OUT     = 4'd0;
    assign WB_GPU_CTI_OUT     = 3'd0;
    assign WB_GPU_BTE_OUT     = 2'd0;
    assign WB_GPU_DAT_WR_OUT  = 32'h0000_0000; 

   // always blocks

   // instantiations


   MIPS1_TOP mips1_top
      (
       .CLK            (CLK           ),
       .RST_SYNC       (RST_SYNC      ),
      
       .WB_ADR_OUT     (WbMipsAdr     ),
       .WB_CYC_OUT     (WbMipsCyc     ),
       .WB_STB_OUT     (WbMipsStb     ),
       .WB_WE_OUT      (WbMipsWe      ),
       .WB_SEL_OUT     (WbMipsSel     ),
       .WB_CTI_OUT     (WbMipsCti     ),
       .WB_BTE_OUT     (WbMipsBte     ),
       .WB_ACK_IN      (WbMipsAck     ),
       .WB_STALL_IN    (WbMipsStall   ),
       .WB_ERR_IN      (WbMipsErr     ),
       .WB_DAT_RD_IN   (WbMipsDatRd   ),
       .WB_DAT_WR_OUT  (WbMipsDatWr   ),
      
       .HW_IRQ_IN      ({5'd0, MipsHwInt})  // todo ! Check which COP0 irq is used
       );

   DMAC_TOP dmac_top
      (

       .CLK                      (CLK        ),
       .EN                       (EN         ),
       .RST_SYNC                 (RST_SYNC   ),
       .RST_ASYNC                (RST_ASYNC  ),
      
       .WB_REGS_ADR_IN           (WbRegsAdr       ),
       .WB_REGS_DMAC_CYC_IN      (WbRegsDmacCyc   ),
       .WB_REGS_DMAC_STB_IN      (WbRegsDmacStb   ),
       .WB_REGS_WE_IN            (WbRegsWe        ),
       .WB_REGS_SEL_IN           (WbRegsSel       ),
       .WB_REGS_DMAC_ACK_OUT     (WbRegsDmacAck   ),
       .WB_REGS_DMAC_STALL_OUT   (WbRegsDmacStall ),
       .WB_REGS_DMAC_ERR_OUT     (WbRegsDmacErr   ),
       .WB_REGS_DMAC_DAT_RD_OUT  (WbRegsDmacDatRd ),
       .WB_REGS_DAT_WR_IN        (WbRegsDatWr     ),
      
       .WB_ADR_OUT               (WbDmacAdr      ),
       .WB_CYC_OUT               (WbDmacCyc      ),
       .WB_STB_OUT               (WbDmacStb      ),
       .WB_WE_OUT                (WbDmacWe       ),
       .WB_SEL_OUT               (WbDmacSel      ),
       .WB_CTI_OUT               (WbDmacCti      ),
       .WB_BTE_OUT               (WbDmacBte      ),
       .WB_ACK_IN                (WbDmacAck      ),
       .WB_STALL_IN              (WbDmacStall    ),
       .WB_ERR_IN                (WbDmacErr      ),
       .WB_DAT_RD_IN             (WbDmacDatRd    ),
       .WB_DAT_WR_OUT            (WbDmacDatWr    ),

       .DMAC_REQ_IN              (DmacReq        ),
       .DMAC_ACK_OUT             (DmacAck        ),

       .DMAC_IRQ_OUT             (DmacIrq        )
       );

   


   
   ROOT_CNT root_cnt
      (
       .CLK                      (CLK        ),
       .EN                       (EN         ),
       .RST_SYNC                 (RST_SYNC   ),
       .RST_ASYNC                (RST_ASYNC  ),
      
       .WB_REGS_ADR_IN           (WbRegsAdr        ),
       .WB_REGS_RCNT_CYC_IN      (WbRegsRcntCyc    ),
       .WB_REGS_RCNT_STB_IN      (WbRegsRcntStb    ),
       .WB_REGS_WE_IN            (WbRegsWe         ),
       .WB_REGS_SEL_IN           (WbRegsSel        ),
       .WB_REGS_RCNT_ACK_OUT     (WbRegsRcntAck    ),
       .WB_REGS_RCNT_STALL_OUT   (WbRegsRcntStall  ),
       .WB_REGS_RCNT_ERR_OUT     (WbRegsRcntErr    ),
       .WB_REGS_RCNT_DAT_RD_OUT  (WbRegsRcntDatRd  ),
       .WB_REGS_DAT_WR_IN        (WbRegsDatWr      ),
      
       .WB_VS_STB_IN             (WbVsStb          ),
       .WB_HS_STB_IN             (WbHsStb          ),
       .WB_ACTIVE_ROW_IN         (WbActiveRow      ),
       .WB_ACTIVE_COL_IN         (WbActiveCol      ),

       .RCNT_IRQ_OUT             (RcntIrq          )
       );

   INTC intc
      (
       .CLK                 (CLK        ),
       .EN                  (EN         ),
       .RST_SYNC            (RST_SYNC   ),
       .RST_ASYNC           (RST_ASYNC  ),
      
       .WB_REGS_ADR_IN      (WbRegsAdr       ),
       .WB_INTC_CYC_IN      (WbRegsIntcCyc   ),
       .WB_INTC_STB_IN      (WbRegsIntcStb   ),
       .WB_REGS_WE_IN       (WbRegsWe        ),
       .WB_REGS_SEL_IN      (WbRegsSel       ),
       .WB_INTC_ACK_OUT     (WbRegsIntcAck   ),
       .WB_INTC_STALL_OUT   (WbRegsIntcStall ),
       .WB_INTC_ERR_OUT     (WbRegsIntcErr   ),
       .WB_INTC_DAT_RD_OUT  (WbRegsIntcDatRd ),
       .WB_REGS_DAT_WR_IN   (WbRegsDatWr     ),

       .INT_SOURCE_IN        (IntSource      ),
       .MIPS_HW_INT_OUT      (MipsHwInt      ) 
       );

   /////////////////////////////////////////////////////////////////////////////
   PSX_BUS psx_bus
      (
       .CLK_SYS                    (CLK            ),
       .EN_SYS                     (EN             ),
       .RST_SYNC_SYS               (RST_SYNC       ),
       .RST_ASYNC_SYS              (RST_ASYNC      ),

       .CLK_REGS                   (CLK            ),
       .EN_REGS                    (EN             ),
       .RST_SYNC_REGS              (RST_SYNC       ),
       .RST_ASYNC_REGS             (RST_ASYNC      ),

       .WB_MIPS_ADR_IN             (WbMipsAdr      ),
       .WB_MIPS_CYC_IN             (WbMipsCyc      ),
       .WB_MIPS_STB_IN             (WbMipsStb      ),
       .WB_MIPS_WE_IN              (WbMipsWe       ),
       .WB_MIPS_SEL_IN             (WbMipsSel      ),
       .WB_MIPS_CTI_IN             (WbMipsCti      ),
       .WB_MIPS_BTE_IN             (WbMipsBte      ),

       .WB_MIPS_STALL_OUT          (WbMipsStall    ),
       .WB_MIPS_ACK_OUT            (WbMipsAck      ),
       .WB_MIPS_ERR_OUT            (WbMipsErr      ),
      
       .WB_MIPS_RD_DAT_OUT         (WbMipsDatRd    ),
       .WB_MIPS_WR_DAT_IN          (WbMipsDatWr    ),

       .WB_DMAC_ADR_IN             (WbDmacAdr      ),
       .WB_DMAC_CYC_IN             (WbDmacCyc      ),
       .WB_DMAC_STB_IN             (WbDmacStb      ),
       .WB_DMAC_WE_IN              (WbDmacWe       ),
       .WB_DMAC_SEL_IN             (WbDmacSel      ),
       .WB_DMAC_CTI_IN             (WbDmacCti      ),
       .WB_DMAC_BTE_IN             (WbDmacBte      ),
      
       .WB_DMAC_STALL_OUT          (WbDmacStall    ),
       .WB_DMAC_ACK_OUT            (WbDmacAck      ),
       .WB_DMAC_ERR_OUT            (WbDmacErr      ),
      
       .WB_DMAC_RD_DAT_OUT         (WbDmacDatRd    ),
       .WB_DMAC_WR_DAT_IN          (WbDmacDatWr    ),

       .WB_SYS_ADR_OUT             (WB_SYS_ADR_OUT         ), // WbSysAdr          ),
       .WB_SYS_WE_OUT              (WB_SYS_WE_OUT          ), // WbSysWe           ),
       .WB_SYS_SEL_OUT             (WB_SYS_SEL_OUT         ), // WbSysSel          ),
       .WB_SYS_CTI_OUT             (WB_SYS_CTI_OUT         ), // WbSysCti          ),
       .WB_SYS_BTE_OUT             (WB_SYS_BTE_OUT         ), // WbSysBte          ),
       .WB_SYS_DAT_WR_OUT          (WB_SYS_DAT_WR_OUT      ), // WbSysDatWr        ),  
      
       .WB_SYS_ROM_CYC_OUT         (WB_SYS_ROM_CYC_OUT     ), // WbSysRomCyc       ),
       .WB_SYS_ROM_STB_OUT         (WB_SYS_ROM_STB_OUT     ), // WbSysRomStb       ),
       .WB_SYS_DRAM_CYC_OUT        (WB_SYS_DRAM_CYC_OUT    ), // WbSysDramCyc   ),
       .WB_SYS_DRAM_STB_OUT        (WB_SYS_DRAM_STB_OUT    ), // WbSysDramStb   ),
       .WB_SYS_GPU_CYC_OUT         (WB_GPU_CYC_OUT         ), // WbSysGpuCyc       ),
       .WB_SYS_GPU_STB_OUT         (WB_GPU_STB_OUT         ), // WbSysGpuStb       ),
      
       .WB_SYS_ROM_ACK_IN          (WB_SYS_ROM_ACK_IN      ), // WbSysRomAck       ),
       .WB_SYS_ROM_STALL_IN        (WB_SYS_ROM_STALL_IN    ), // WbSysRomStall     ),
       .WB_SYS_ROM_ERR_IN          (WB_SYS_ROM_ERR_IN      ), // WbSysRomErr       ),
       .WB_SYS_ROM_DAT_RD_IN       (WB_SYS_DAT_ROM_RD_IN   ), // WbSysRomDatRd     ),
       .WB_SYS_DRAM_ACK_IN         (WB_SYS_DRAM_ACK_IN     ), // WbSysDramAck      ),
       .WB_SYS_DRAM_STALL_IN       (WB_SYS_DRAM_STALL_IN   ), // WbSysDramStall    ),
       .WB_SYS_DRAM_ERR_IN         (WB_SYS_DRAM_ERR_IN     ), // WbSysDramErr      ),
       .WB_SYS_DRAM_DAT_RD_IN      (WB_SYS_DAT_DRAM_RD_IN  ), // WbSysDramDatRd    ),
       .WB_SYS_GPU_ACK_IN          (WB_GPU_ACK_IN          ), // WbSysGpuAck       ),
       .WB_SYS_GPU_STALL_IN        (WB_GPU_STALL_IN        ), // WbSysGpuStall     ),
       .WB_SYS_GPU_ERR_IN          (WB_GPU_ERR_IN          ), // WbSysGpuErr       ),
       .WB_SYS_GPU_DAT_RD_IN       (WB_GPU_DAT_RD_IN       ), // WbSysGpuDatRd     ),
      
       .WB_REGS_ADR_OUT            (WbRegsAdr         ),
       .WB_REGS_WE_OUT             (WbRegsWe          ),
       .WB_REGS_SEL_OUT            (WbRegsSel         ),
       .WB_REGS_DAT_WR_OUT         (WbRegsDatWr       ),
      
       .WB_REGS_RCNT_CYC_OUT       (WbRegsRcntCyc     ),
       .WB_REGS_RCNT_STB_OUT       (WbRegsRcntStb     ),
       .WB_REGS_INTC_CYC_OUT       (WbRegsIntcCyc     ),
       .WB_REGS_INTC_STB_OUT       (WbRegsIntcStb     ),
       .WB_REGS_DMAC_CYC_OUT       (WbRegsDmacCyc     ),
       .WB_REGS_DMAC_STB_OUT       (WbRegsDmacStb     ),
       .WB_REGS_BIOS_CYC_OUT       (WbRegsBiosCyc     ),
       .WB_REGS_BIOS_STB_OUT       (WbRegsBiosStb     ),
       .WB_REGS_MDEC_CYC_OUT       (WbRegsMdecCyc     ),
       .WB_REGS_MDEC_STB_OUT       (WbRegsMdecStb     ),
       .WB_REGS_MEMCARD_CYC_OUT    (WbRegsMemCardStb  ),
       .WB_REGS_MEMCARD_STB_OUT    (WbRegsMemCardCyc  ),
       .WB_REGS_SPU_CYC_OUT        (WbRegsSpuCyc      ),
       .WB_REGS_SPU_STB_OUT        (WbRegsSpuStb      ),
       .WB_REGS_CDROM_CYC_OUT      (WbRegsCdromStb    ),
       .WB_REGS_CDROM_STB_OUT      (WbRegsCdromCyc    ),
       .WB_REGS_PAD_CYC_OUT        (WbRegsPadStb      ),
       .WB_REGS_PAD_STB_OUT        (WbRegsPadCyc      ),
      
       .WB_REGS_RCNT_ACK_IN        (WbRegsRcntAck      ),
       .WB_REGS_RCNT_STALL_IN      (WbRegsRcntStall    ),
       .WB_REGS_RCNT_ERR_IN        (WbRegsRcntErr      ),
       .WB_REGS_RCNT_DAT_RD_IN     (WbRegsRcntDatRd    ),
       .WB_REGS_INTC_ACK_IN        (WbRegsIntcAck      ),
       .WB_REGS_INTC_STALL_IN      (WbRegsIntcStall    ),
       .WB_REGS_INTC_ERR_IN        (WbRegsIntcErr      ),
       .WB_REGS_INTC_DAT_RD_IN     (WbRegsIntcDatRd    ),
       .WB_REGS_DMAC_ACK_IN        (WbRegsDmacAck      ),
       .WB_REGS_DMAC_STALL_IN      (WbRegsDmacStall    ),
       .WB_REGS_DMAC_ERR_IN        (WbRegsDmacErr      ),
       .WB_REGS_DMAC_DAT_RD_IN     (WbRegsDmacDatRd    ),
       .WB_REGS_BIOS_ACK_IN        (WbRegsBiosAck      ),
       .WB_REGS_BIOS_STALL_IN      (WbRegsBiosStall    ),
       .WB_REGS_BIOS_ERR_IN        (WbRegsBiosErr      ),
       .WB_REGS_BIOS_DAT_RD_IN     (WbRegsBiosDatRd    ),
       .WB_REGS_MDEC_ACK_IN        (WbRegsMdecAck      ),
       .WB_REGS_MDEC_STALL_IN      (WbRegsMdecStall    ),
       .WB_REGS_MDEC_ERR_IN        (WbRegsMdecErr      ),
       .WB_REGS_MDEC_DAT_RD_IN     (WbRegsMdecDatRd    ),
       .WB_REGS_MEMCARD_ACK_IN     (WbRegsMemCardAck   ),
       .WB_REGS_MEMCARD_STALL_IN   (WbRegsMemCardStall ),
       .WB_REGS_MEMCARD_ERR_IN     (WbRegsMemCardErr   ),
       .WB_REGS_MEMCARD_DAT_RD_IN  (WbRegsMemCardDatRd ),
       .WB_REGS_SPU_ACK_IN         (WbRegsSpuAck       ),
       .WB_REGS_SPU_STALL_IN       (WbRegsSpuStall     ),
       .WB_REGS_SPU_ERR_IN         (WbRegsSpuErr       ),
       .WB_REGS_SPU_DAT_RD_IN      (WbRegsSpuDatRd     ),
       .WB_REGS_CDROM_ACK_IN       (WbRegsCdromAck     ),
       .WB_REGS_CDROM_STALL_IN     (WbRegsCdromStall   ),
       .WB_REGS_CDROM_ERR_IN       (WbRegsCdromErr     ),
       .WB_REGS_CDROM_DAT_RD_IN    (WbRegsCdromDatRd   ),
       .WB_REGS_PAD_ACK_IN         (WbRegsPadAck       ),
       .WB_REGS_PAD_STALL_IN       (WbRegsPadStall     ),
       .WB_REGS_PAD_ERR_IN         (WbRegsPadErr       ),
       .WB_REGS_PAD_DAT_RD_IN      (WbRegsPadDatRd     )
      
       );

   /////////////////////////////////////////////////////////////////////////////
   // Use a dummy block for all unconnected WB regs slaves
   // This will return an ACK to the Master, but not store data.
   // Read data will be all 0s

   // BIOS Slave
   assign WbRegsBiosDatRd = 32'h0000_0000;
   
   WB_SLAVE_CTRL 
      #(
        .DEFAULT_SLAVE   (1), // Removes address decode, will always return ..
        .DEFAULT_ERR     (0)  // an ACK as this parameter is 0
        )
   wb_slave_ctrl_bios
      (
       .CLK                 (CLK         ),
       .EN                  (EN          ),
       .RST_SYNC            (RST_SYNC    ),
       .RST_ASYNC           (RST_ASYNC   ),

       .WB_REGS_ADR_IN      (WbRegsAdr   ), 
       .WB_REGS_CYC_IN      (WbRegsBiosCyc ), 
       .WB_REGS_STB_IN      (WbRegsBiosStb ), 
       .WB_REGS_WE_IN       (WbRegsWe ), 
       .WB_REGS_SEL_IN      (WbRegsSel ), 
       .WB_REGS_ACK_OUT     (WbRegsBiosAck ), 
       .WB_REGS_STALL_OUT   (WbRegsBiosStall ), 
       .WB_REGS_ERR_OUT     (WbRegsBiosErr   ), 

       // Don't use the core-side outputs 
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );

   // MDEC Slave
   assign WbRegsMdecDatRd = 32'h0000_0000;
   
   WB_SLAVE_CTRL 
      #(
        .DEFAULT_SLAVE   (1), // Removes address decode, will always return ..
        .DEFAULT_ERR     (0)  // an ACK as this parameter is 0
        )
   wb_slave_ctrl_mdec
      (
       .CLK                 (CLK         ),
       .EN                  (EN          ),
       .RST_SYNC            (RST_SYNC    ),
       .RST_ASYNC           (RST_ASYNC   ),

       .WB_REGS_ADR_IN      (WbRegsAdr       ), 
       .WB_REGS_CYC_IN      (WbRegsMdecCyc   ), 
       .WB_REGS_STB_IN      (WbRegsMdecStb   ), 
       .WB_REGS_WE_IN       (WbRegsWe        ), 
       .WB_REGS_SEL_IN      (WbRegsSel       ), 
       .WB_REGS_ACK_OUT     (WbRegsMdecAck   ), 
       .WB_REGS_STALL_OUT   (WbRegsMdecStall ), 
       .WB_REGS_ERR_OUT     (WbRegsMdecErr   ), 

       // Don't use the core-side outputs 
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );

   // MEMCARD Slave
   assign WbRegsMemCardDatRd = 32'h0000_0000;
   
   WB_SLAVE_CTRL 
      #(
        .DEFAULT_SLAVE   (1), // Removes address decode, will always return ..
        .DEFAULT_ERR     (0)  // an ACK as this parameter is 0
        )
   wb_slave_ctrl_memcard
      (
       .CLK                 (CLK         ),
       .EN                  (EN          ),
       .RST_SYNC            (RST_SYNC    ),
       .RST_ASYNC           (RST_ASYNC   ),

       .WB_REGS_ADR_IN      (WbRegsAdr          ), 
       .WB_REGS_CYC_IN      (WbRegsMemCardCyc   ), 
       .WB_REGS_STB_IN      (WbRegsMemCardStb   ), 
       .WB_REGS_WE_IN       (WbRegsWe           ), 
       .WB_REGS_SEL_IN      (WbRegsSel          ), 
       .WB_REGS_ACK_OUT     (WbRegsMemCardAck   ), 
       .WB_REGS_STALL_OUT   (WbRegsMemCardStall ), 
       .WB_REGS_ERR_OUT     (WbRegsMemCardErr   ), 

       // Don't use the core-side outputs 
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );

   // SPU Slave
   assign WbRegsSpuDatRd = 32'h0000_0000;
   
   WB_SLAVE_CTRL 
      #(
        .DEFAULT_SLAVE   (1), // Removes address decode, will always return ..
        .DEFAULT_ERR     (0)  // an ACK as this parameter is 0
        )
   wb_slave_ctrl_spu
      (
       .CLK                 (CLK         ),
       .EN                  (EN          ),
       .RST_SYNC            (RST_SYNC    ),
       .RST_ASYNC           (RST_ASYNC   ),

       .WB_REGS_ADR_IN      (WbRegsAdr      ), 
       .WB_REGS_CYC_IN      (WbRegsSpuCyc   ), 
       .WB_REGS_STB_IN      (WbRegsSpuStb   ), 
       .WB_REGS_WE_IN       (WbRegsWe       ), 
       .WB_REGS_SEL_IN      (WbRegsSel      ), 
       .WB_REGS_ACK_OUT     (WbRegsSpuAck   ), 
       .WB_REGS_STALL_OUT   (WbRegsSpuStall ), 
       .WB_REGS_ERR_OUT     (WbRegsSpuErr   ), 

       // Don't use the core-side outputs 
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );


   // CDROM Slave
   assign WbRegsCdromDatRd = 32'h0000_0000;
   
   WB_SLAVE_CTRL 
      #(
        .DEFAULT_SLAVE   (1), // Removes address decode, will always return ..
        .DEFAULT_ERR     (0)  // an ACK as this parameter is 0
        )
   wb_slave_ctrl_cdrom
      (
       .CLK                 (CLK         ),
       .EN                  (EN          ),
       .RST_SYNC            (RST_SYNC    ),
       .RST_ASYNC           (RST_ASYNC   ),

       .WB_REGS_ADR_IN      (WbRegsAdr        ), 
       .WB_REGS_CYC_IN      (WbRegsCdromCyc   ), 
       .WB_REGS_STB_IN      (WbRegsCdromStb   ), 
       .WB_REGS_WE_IN       (WbRegsWe         ), 
       .WB_REGS_SEL_IN      (WbRegsSel        ), 
       .WB_REGS_ACK_OUT     (WbRegsCdromAck   ), 
       .WB_REGS_STALL_OUT   (WbRegsCdromStall ), 
       .WB_REGS_ERR_OUT     (WbRegsCdromErr   ), 

       // Don't use the core-side outputs 
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );

   
   // PAD Slave
   assign WbRegsPadDatRd = 32'h0000_0000;
   
   WB_SLAVE_CTRL 
      #(
        .DEFAULT_SLAVE   (1), // Removes address decode, will always return ..
        .DEFAULT_ERR     (0)  // an ACK as this parameter is 0
        )
   wb_slave_ctrl_pad
      (
       .CLK                 (CLK         ),
       .EN                  (EN          ),
       .RST_SYNC            (RST_SYNC    ),
       .RST_ASYNC           (RST_ASYNC   ),

       .WB_REGS_ADR_IN      (WbRegsAdr      ), 
       .WB_REGS_CYC_IN      (WbRegsPadCyc   ), 
       .WB_REGS_STB_IN      (WbRegsPadStb   ), 
       .WB_REGS_WE_IN       (WbRegsWe       ), 
       .WB_REGS_SEL_IN      (WbRegsSel      ), 
       .WB_REGS_ACK_OUT     (WbRegsPadAck   ), 
       .WB_REGS_STALL_OUT   (WbRegsPadStall ), 
       .WB_REGS_ERR_OUT     (WbRegsPadErr   ), 

       // Don't use the core-side outputs 
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );





   
endmodule
