// Insert module header here
module PSX_BUS
   (
    ////////////////////////////////////////////////////////////////////////////
    // Clocks and resets
    input           CLK_SYS        ,
    input           EN_SYS         ,
    input           RST_SYNC_SYS   ,
    input           RST_ASYNC_SYS  ,

    input           CLK_REGS       ,
    input           EN_REGS        ,
    input           RST_SYNC_REGS  ,
    input           RST_ASYNC_REGS ,

    ////////////////////////////////////////////////////////////////////////////
    // DMAC Master (highest priority)
    input   [31:0] WB_MIPS_ADR_IN     ,
    input          WB_MIPS_CYC_IN     ,
    input          WB_MIPS_STB_IN     ,
    input          WB_MIPS_WE_IN      ,
    input   [ 3:0] WB_MIPS_SEL_IN     ,
    input   [ 2:0] WB_MIPS_CTI_IN     ,
    input   [ 1:0] WB_MIPS_BTE_IN     ,

    output         WB_MIPS_STALL_OUT  ,
    output         WB_MIPS_ACK_OUT    ,
    output         WB_MIPS_ERR_OUT    ,
    
    output  [31:0] WB_MIPS_RD_DAT_OUT ,
    input   [31:0] WB_MIPS_WR_DAT_IN  ,

    ////////////////////////////////////////////////////////////////////////////
    // MIPS1 Master 
    input   [31:0] WB_DMAC_ADR_IN     ,
    input          WB_DMAC_CYC_IN     ,
    input          WB_DMAC_STB_IN     ,
    input          WB_DMAC_WE_IN      ,
    input   [ 3:0] WB_DMAC_SEL_IN     ,
    input   [ 2:0] WB_DMAC_CTI_IN     ,
    input   [ 1:0] WB_DMAC_BTE_IN     ,

    output         WB_DMAC_STALL_OUT  ,
    output         WB_DMAC_ACK_OUT    ,
    output         WB_DMAC_ERR_OUT    ,

    output  [31:0] WB_DMAC_RD_DAT_OUT ,
    input   [31:0] WB_DMAC_WR_DAT_IN  ,

    ////////////////////////////////////////////////////////////////////////////
    // System Bus ( also routed to the Register slave at this level).
    // The following slaves are on the System Bus (ROM, DRM, GPU, REGS bus slave)

    // System Bus - Master to Slave Common signals to all slaves
    // (ADR, WE, SEL, DAT_WR)
    output  [31:0] WB_SYS_ADR_OUT      ,
    output         WB_SYS_WE_OUT       ,
    output  [ 3:0] WB_SYS_SEL_OUT      ,
    output  [ 2:0] WB_SYS_CTI_OUT      ,
    output  [ 1:0] WB_SYS_BTE_OUT      ,
    output  [31:0] WB_SYS_DAT_WR_OUT   ,
    
    // Slave-specific MAster -> Slave signals (CYC, STB)    
    output         WB_SYS_ROM_CYC_OUT  ,
    output         WB_SYS_ROM_STB_OUT  ,
    output         WB_SYS_DRAM_CYC_OUT ,
    output         WB_SYS_DRAM_STB_OUT ,
    output         WB_SYS_GPU_CYC_OUT  ,
    output         WB_SYS_GPU_STB_OUT  ,
 
   // Slave specific Slave -> Master signals (ACK, STALL, ER, Read data)
    input          WB_SYS_ROM_ACK_IN     ,
    input          WB_SYS_ROM_STALL_IN   ,
    input          WB_SYS_ROM_ERR_IN     ,
    input   [31:0] WB_SYS_ROM_DAT_RD_IN  ,
    input          WB_SYS_DRAM_ACK_IN    ,
    input          WB_SYS_DRAM_STALL_IN  ,
    input          WB_SYS_DRAM_ERR_IN    ,
    input   [31:0] WB_SYS_DRAM_DAT_RD_IN ,
    input          WB_SYS_GPU_ACK_IN     ,
    input          WB_SYS_GPU_STALL_IN   ,
    input          WB_SYS_GPU_ERR_IN     ,
    input   [31:0] WB_SYS_GPU_DAT_RD_IN  ,
   
    
    ////////////////////////////////////////////////////////////////////////////
    // Registers Bus
    // Registers Bus - Master to Slave Common signals to all slaves
    // (ADR, WE, SEL, DAT_WR)
    output  [31:0] WB_REGS_ADR_OUT      ,
    output         WB_REGS_WE_OUT       ,
    output  [ 3:0] WB_REGS_SEL_OUT      ,
    output  [31:0] WB_REGS_DAT_WR_OUT   ,
   
    // Slave-specific MAster -> Slave signals (CYC, STB)    
    output         WB_REGS_RCNT_CYC_OUT     ,
    output         WB_REGS_RCNT_STB_OUT     ,
    output         WB_REGS_INTC_CYC_OUT     ,
    output         WB_REGS_INTC_STB_OUT     ,
    output         WB_REGS_DMAC_CYC_OUT     ,
    output         WB_REGS_DMAC_STB_OUT     ,
    output         WB_REGS_BIOS_CYC_OUT     ,
    output         WB_REGS_BIOS_STB_OUT     ,
    output         WB_REGS_MDEC_CYC_OUT     ,
    output         WB_REGS_MDEC_STB_OUT     ,
    output         WB_REGS_MEMCARD_CYC_OUT  ,
    output         WB_REGS_MEMCARD_STB_OUT  ,
    output         WB_REGS_SPU_CYC_OUT      ,
    output         WB_REGS_SPU_STB_OUT      ,
    output         WB_REGS_CDROM_CYC_OUT    ,
    output         WB_REGS_CDROM_STB_OUT    ,
    output         WB_REGS_PAD_CYC_OUT      ,
    output         WB_REGS_PAD_STB_OUT      ,
   
    // Slave specific Slave -> Master signals (ACK, STALL, ER, Read data)
    input          WB_REGS_RCNT_ACK_IN        ,
    input          WB_REGS_RCNT_STALL_IN      ,
    input          WB_REGS_RCNT_ERR_IN        ,
    input   [31:0] WB_REGS_RCNT_DAT_RD_IN     ,
    input          WB_REGS_INTC_ACK_IN        ,
    input          WB_REGS_INTC_STALL_IN      ,
    input          WB_REGS_INTC_ERR_IN        ,
    input   [31:0] WB_REGS_INTC_DAT_RD_IN     ,
    input          WB_REGS_DMAC_ACK_IN        ,
    input          WB_REGS_DMAC_STALL_IN      ,
    input          WB_REGS_DMAC_ERR_IN        ,
    input   [31:0] WB_REGS_DMAC_DAT_RD_IN     ,
    input          WB_REGS_BIOS_ACK_IN        ,
    input          WB_REGS_BIOS_STALL_IN      ,
    input          WB_REGS_BIOS_ERR_IN        ,
    input   [31:0] WB_REGS_BIOS_DAT_RD_IN     ,
    input          WB_REGS_MDEC_ACK_IN        ,
    input          WB_REGS_MDEC_STALL_IN      ,
    input          WB_REGS_MDEC_ERR_IN        ,
    input   [31:0] WB_REGS_MDEC_DAT_RD_IN     ,
    input          WB_REGS_MEMCARD_ACK_IN     ,
    input          WB_REGS_MEMCARD_STALL_IN   ,
    input          WB_REGS_MEMCARD_ERR_IN     ,
    input   [31:0] WB_REGS_MEMCARD_DAT_RD_IN  ,
    input          WB_REGS_SPU_ACK_IN         ,
    input          WB_REGS_SPU_STALL_IN       ,
    input          WB_REGS_SPU_ERR_IN         ,
    input   [31:0] WB_REGS_SPU_DAT_RD_IN      ,
    input          WB_REGS_CDROM_ACK_IN       ,
    input          WB_REGS_CDROM_STALL_IN     ,
    input          WB_REGS_CDROM_ERR_IN       ,
    input   [31:0] WB_REGS_CDROM_DAT_RD_IN    ,
    input          WB_REGS_PAD_ACK_IN         ,
    input          WB_REGS_PAD_STALL_IN       ,
    input          WB_REGS_PAD_ERR_IN         ,
    input   [31:0] WB_REGS_PAD_DAT_RD_IN      
       
    );
`include "psx_mem_map.vh"
`include "wb_defs.v"
   
   ////////////////////////////////////////////////////////////////////////////
   // wires and regs

   // SYS bus arbiter Master
   wire [31:0]     WbSysAdr     ;
   wire            WbSysCyc     ;
   wire            WbSysStb     ;
   wire            WbSysWe      ;
   wire [ 3:0]     WbSysSel     ;
   wire [ 2:0]     WbSysCti     ;
   wire [ 1:0]     WbSysBte     ;
   wire            WbSysAck     ;
   wire            WbSysStall   ;
   wire            WbSysErr     ;
   wire [31:0]     WbSysDatRd   ;
   wire [31:0]     WbSysDatWr   ;

   // SYS Slave Select and registered version for data phase. 4 possible slaves on
   // this bus (ROM, DRAM, GPU, and REGS slave). If these aren't selected, the default
   // slave is selected which returns an error
   wire            WbSysRomSel      ;
   reg             WbSysRomSelReg   ;
   wire            WbSysRomCyc      ; // Extend the CYC going to the slave until it returns ACK
   wire            WbSysRomStb      ;
   wire            WbSysDramSel     ;
   reg             WbSysDramSelReg  ;
   wire            WbSysDramCyc     ; // Extend the CYC going to the slave until it returns ACK
   wire            WbSysDramStb     ;
   wire            WbSysGpuSel      ;
   reg             WbSysGpuSelReg   ;
   wire            WbSysGpuCyc      ; // Extend the CYC going to the slave until it returns ACK
   wire            WbSysGpuStb      ;
   wire            WbSysRegsSel     ;
   reg             WbSysRegsSelReg  ; 
   wire            WbSysRegsCyc     ; // Extend the CYC going to the slave until it returns ACK
   wire            WbSysRegsStb     ;
   wire            WbSysDefaultSel     ;
   reg             WbSysDefaultSelReg  ; 
   wire            WbSysDefaultCyc     ; // Extend the CYC going to the slave until it returns ACK
   wire            WbSysDefaultStb     ;

   // Slave specific Slave -> Master signals
//   wire          WbSysRomAck      ; <- commented ones come from top ports
//   wire          WbSysRomStall    ;
//   wire          WbSysRomErr      ;
//   wire [31:0]           WbSysRomDatRd    ;
//   wire          WbSysDramAck     ;
//   wire          WbSysDramStall   ;
//   wire          WbSysDramErr     ;
//   wire [31:0]           WbSysDramDatRd   ;
//   wire          WbSysGpuAck      ;
//   wire          WbSysGpuStall    ;
//   wire          WbSysGpuErr      ;
//   wire [31:0]           WbSysGpuDatRd    ;
   wire            WbSysRegsAck     ;
   wire            WbSysRegsStall   ;
   wire            WbSysRegsErr     ;
   wire [31:0]     WbSysRegsDatRd   ;
   
   wire            WbSysDefaultAck     ;
   wire            WbSysDefaultStall   ;
   wire            WbSysDefaultErr     ;
   wire [31:0]     WbSysDefaultDatRd   = 32'h0000_0000;
   
   // REGS bus Master
   wire [31:0]     WbRegsAdr     ;
   wire            WbRegsCyc     ;
   wire            WbRegsStb     ;
   wire            WbRegsWe      ;
   wire [ 3:0]     WbRegsSel     ;
   wire [ 2:0]     WbRegsCti     ;
   wire [ 1:0]     WbRegsBte     ;
   wire            WbRegsAck     ;
   wire            WbRegsStall   ;
   wire            WbRegsErr     ;
   wire [31:0]     WbRegsDatRd   ;
   wire [31:0]     WbRegsDatWr   ;

   // Master to Slave REGS Slave select and registered slave select
   reg             WbRegsRcntSel       ;
   reg             WbRegsRcntSelReg    ;
   wire            WbRegsRcntCyc       ;
   wire            WbRegsRcntStb       ;
   reg             WbRegsIntcSel       ;
   reg             WbRegsIntcSelReg    ;
   wire            WbRegsIntcCyc       ;
   wire            WbRegsIntcStb       ;
   reg             WbRegsDmacSel       ;
   reg             WbRegsDmacSelReg    ;
   wire            WbRegsDmacCyc       ;
   wire            WbRegsDmacStb       ;
   reg             WbRegsBiosSel       ;
   reg             WbRegsBiosSelReg    ;
   wire            WbRegsBiosCyc       ;
   wire            WbRegsBiosStb       ;
   reg             WbRegsMdecSel       ;
   reg             WbRegsMdecSelReg    ;
   wire            WbRegsMdecCyc       ;
   wire            WbRegsMdecStb       ;
   reg             WbRegsMemcardSel    ;
   reg             WbRegsMemcardSelReg ;
   wire            WbRegsMemcardCyc    ;
   wire            WbRegsMemcardStb    ;
   reg             WbRegsSpuSel        ;
   reg             WbRegsSpuSelReg     ;
   wire            WbRegsSpuCyc        ;
   wire            WbRegsSpuStb        ;
   reg             WbRegsCdromSel      ;
   reg             WbRegsCdromSelReg   ;
   wire            WbRegsCdromCyc      ;
   wire            WbRegsCdromStb      ;
   reg             WbRegsPadSel        ;
   reg             WbRegsPadSelReg     ;
   wire            WbRegsPadCyc        ;
   wire            WbRegsPadStb        ;
   reg             WbRegsDefaultSel        ;
   reg             WbRegsDefaultSelReg     ;
   wire            WbRegsDefaultCyc        ;
   wire            WbRegsDefaultStb        ;

   // Default slave Slave to Master signals (local to this level)
   wire            WbRegsDefaultAck     ;
   wire            WbRegsDefaultStall   ;
   wire            WbRegsDefaultErr     ;
   wire [31:0]     WbRegsDefaultDatRd = 32'h0000_0000;
   
   ////////////////////////////////////////////////////////////////////////////
   // Combinatorial assigns

   // ----- SYS bus -----

   // SYS bus slave selects. Note the GPU is within the regs range (bad mapping)
   // so decode the GPU select first, and gate the regs select if this is high
   // see the psx_mem_map.vh for more details of the parameters
   assign  WbSysRomSel     = WbSysCyc & WbSysStb & (ROM_SEL_VAL  == WbSysAdr[ROM_SEL_MSB :ROM_SEL_LSB  ]);
   assign  WbSysDramSel    = WbSysCyc & WbSysStb & (DRAM_SEL_VAL == WbSysAdr[DRAM_SEL_MSB:DRAM_SEL_LSB ]);
   assign  WbSysGpuSel     = WbSysCyc & WbSysStb & (GPU_SEL_VAL  == WbSysAdr[GPU_SEL_MSB :GPU_SEL_LSB  ]);
   assign  WbSysRegsSel    = WbSysCyc & WbSysStb & (REGS_SEL_VAL == WbSysAdr[REGS_SEL_MSB:REGS_SEL_LSB ]
                           & ~WbSysGpuSel); 
   // If no slaves are selected, use the default slave..
   assign WbSysDefaultSel  = WbSysCyc & WbSysStb & ~(WbSysRomSel | WbSysDramSel | WbSysGpuSel | WbSysRegsSel);
   
   // CYC is a special signal, as it has to be extended until the ACK is returned
   // for each slave, even if another slave was addressed before the current slave
   // returned an ACK.
   // So combine the registered select and CYC for each slave here
   assign  WbSysRomCyc     = WbSysCyc & (WbSysRomSel     | WbSysRomSelReg    );
   assign  WbSysDramCyc    = WbSysCyc & (WbSysDramSel    | WbSysDramSelReg   );
   assign  WbSysGpuCyc     = WbSysCyc & (WbSysGpuSel     | WbSysGpuSelReg    );
   assign  WbSysRegsCyc    = WbSysCyc & (WbSysRegsSel    | WbSysRegsSelReg   );
   assign  WbSysDefaultCyc = WbSysCyc & (WbSysDefaultSel | WbSysDefaultSelReg);
   
   // The STB is only associated with the address phase, so use the SEL only
   assign  WbSysRomStb     = WbSysStb & WbSysRomSel ;
   assign  WbSysDramStb    = WbSysStb & WbSysDramSel;
   assign  WbSysGpuStb     = WbSysStb & WbSysGpuSel ;
   assign  WbSysRegsStb    = WbSysStb & WbSysRegsSel;
   assign  WbSysDefaultStb = WbSysStb & WbSysDefaultSel;

   // ----- REGS bus -----
   // REGS - CYC gating (extend for read data phase too)
   assign  WbRegsRcntCyc     = WbRegsCyc & (WbRegsRcntSel     | WbRegsRcntSelReg    );
   assign  WbRegsIntcCyc     = WbRegsCyc & (WbRegsIntcSel     | WbRegsIntcSelReg    );
   assign  WbRegsDmacCyc     = WbRegsCyc & (WbRegsDmacSel     | WbRegsDmacSelReg    );
   assign  WbRegsBiosCyc     = WbRegsCyc & (WbRegsBiosSel     | WbRegsBiosSelReg    );
   assign  WbRegsMdecCyc     = WbRegsCyc & (WbRegsMdecSel     | WbRegsMdecSelReg    );
   assign  WbRegsMemcardCyc  = WbRegsCyc & (WbRegsMemcardSel  | WbRegsMemcardSelReg );
   assign  WbRegsSpuCyc      = WbRegsCyc & (WbRegsSpuSel      | WbRegsSpuSelReg     );
   assign  WbRegsCdromCyc    = WbRegsCyc & (WbRegsCdromSel    | WbRegsCdromSelReg   );
   assign  WbRegsPadCyc      = WbRegsCyc & (WbRegsPadSel      | WbRegsPadSelReg     );
   assign  WbRegsDefaultCyc  = WbRegsCyc & (WbRegsDefaultSel  | WbRegsDefaultSelReg );

   // REGS - STB gating 
   assign  WbRegsRcntStb     = WbRegsStb & WbRegsRcntSel   ;
   assign  WbRegsIntcStb     = WbRegsStb & WbRegsIntcSel   ;
   assign  WbRegsDmacStb     = WbRegsStb & WbRegsDmacSel   ;
   assign  WbRegsBiosStb     = WbRegsStb & WbRegsBiosSel   ;
   assign  WbRegsMdecStb     = WbRegsStb & WbRegsMdecSel   ;
   assign  WbRegsMemcardStb  = WbRegsStb & WbRegsMemcardSel;
   assign  WbRegsSpuStb      = WbRegsStb & WbRegsSpuSel    ;
   assign  WbRegsCdromStb    = WbRegsStb & WbRegsCdromSel  ;
   assign  WbRegsPadStb      = WbRegsStb & WbRegsPadSel    ;
   assign  WbRegsDefaultStb  = WbRegsStb & WbRegsDefaultSel;

   // REGS - Mux the Slave -> Master signals
   assign WbRegsAck      = ( ( WbRegsRcntSelReg      & WB_REGS_RCNT_ACK_IN       ) 
                           | ( WbRegsIntcSelReg      & WB_REGS_INTC_ACK_IN       ) 
                           | ( WbRegsDmacSelReg      & WB_REGS_DMAC_ACK_IN       )
                           | ( WbRegsBiosSelReg      & WB_REGS_BIOS_ACK_IN       )
                           | ( WbRegsMdecSelReg      & WB_REGS_MDEC_ACK_IN       )                     
                           | ( WbRegsMemcardSelReg   & WB_REGS_MEMCARD_ACK_IN    ) 
                           | ( WbRegsSpuSelReg       & WB_REGS_SPU_ACK_IN        )
                           | ( WbRegsCdromSelReg     & WB_REGS_CDROM_ACK_IN      )
                           | ( WbRegsPadSelReg       & WB_REGS_PAD_ACK_IN        )                     
                           | ( WbRegsDefaultSelReg   & WbRegsDefaultAck          )                     
                           );
   
   // Stall is a special case. You need to use the Address-phase select to return the
   // STALLs, and the data phase select to invert ACK and return this as STALL.
   // This prevents the master from issuing a new transaction to another slave
   // before the current one has completed
   assign WbRegsStall    =(  ( WbRegsRcntSel         & WB_REGS_RCNT_STALL_IN     ) 
                           | ( WbRegsIntcSel         & WB_REGS_INTC_STALL_IN     ) 
                           | ( WbRegsDmacSel         & WB_REGS_DMAC_STALL_IN     )
                           | ( WbRegsBiosSel         & WB_REGS_BIOS_STALL_IN     )
                           | ( WbRegsMdecSel         & WB_REGS_MDEC_STALL_IN     )                     
                           | ( WbRegsMemcardSel      & WB_REGS_MEMCARD_STALL_IN  ) 
                           | ( WbRegsSpuSel          & WB_REGS_SPU_STALL_IN      )
                           | ( WbRegsCdromSel        & WB_REGS_CDROM_STALL_IN    )
                           | ( WbRegsPadSel          & WB_REGS_PAD_STALL_IN      )                     
                           | ( WbRegsDefaultSel      & WbRegsDefaultStall        )                     
                           | ( WbRegsRcntSelReg      & ~WB_REGS_RCNT_ACK_IN      ) 
                           | ( WbRegsIntcSelReg      & ~WB_REGS_INTC_ACK_IN      ) 
                           | ( WbRegsDmacSelReg      & ~WB_REGS_DMAC_ACK_IN      )
                           | ( WbRegsBiosSelReg      & ~WB_REGS_BIOS_ACK_IN      )
                           | ( WbRegsMdecSelReg      & ~WB_REGS_MDEC_ACK_IN      )                     
                           | ( WbRegsMemcardSelReg   & ~WB_REGS_MEMCARD_ACK_IN   ) 
                           | ( WbRegsSpuSelReg       & ~WB_REGS_SPU_ACK_IN       )
                           | ( WbRegsCdromSelReg     & ~WB_REGS_CDROM_ACK_IN     )
                           | ( WbRegsPadSelReg       & ~WB_REGS_PAD_ACK_IN       )                     
                           | ( WbRegsDefaultSelReg   & ~WbRegsDefaultAck         )
                             );
   
   assign WbRegsErr      = ( ( WbRegsRcntSelReg      & WB_REGS_RCNT_ERR_IN       ) 
                           | ( WbRegsIntcSelReg      & WB_REGS_INTC_ERR_IN       ) 
                           | ( WbRegsDmacSelReg      & WB_REGS_DMAC_ERR_IN       )
                           | ( WbRegsBiosSelReg      & WB_REGS_BIOS_ERR_IN       )
                           | ( WbRegsMdecSelReg      & WB_REGS_MDEC_ERR_IN       )                     
                           | ( WbRegsMemcardSelReg   & WB_REGS_MEMCARD_ERR_IN    ) 
                           | ( WbRegsSpuSelReg       & WB_REGS_SPU_ERR_IN        )
                           | ( WbRegsCdromSelReg     & WB_REGS_CDROM_ERR_IN      )
                           | ( WbRegsPadSelReg       & WB_REGS_PAD_ERR_IN        )                     
                           | ( WbRegsDefaultSelReg   & WbRegsDefaultErr          )                     
                           );
   
   assign WbRegsDatRd    = ( ( {DAT_W {WbRegsRcntSelReg}}      & WB_REGS_RCNT_DAT_RD_IN     ) 
                           | ( {DAT_W {WbRegsIntcSelReg}}      & WB_REGS_INTC_DAT_RD_IN     ) 
                           | ( {DAT_W {WbRegsDmacSelReg}}      & WB_REGS_DMAC_DAT_RD_IN     )
                           | ( {DAT_W {WbRegsBiosSelReg}}      & WB_REGS_BIOS_DAT_RD_IN     )
                           | ( {DAT_W {WbRegsMdecSelReg}}      & WB_REGS_MDEC_DAT_RD_IN     )                     
                           | ( {DAT_W {WbRegsMemcardSelReg}}   & WB_REGS_MEMCARD_DAT_RD_IN  ) 
                           | ( {DAT_W {WbRegsSpuSelReg}}       & WB_REGS_SPU_DAT_RD_IN      )
                           | ( {DAT_W {WbRegsCdromSelReg}}     & WB_REGS_CDROM_DAT_RD_IN    )
                           | ( {DAT_W {WbRegsPadSelReg}}       & WB_REGS_PAD_DAT_RD_IN      )                     
                           | ( {DAT_W {WbRegsDefaultSelReg}}   & WbRegsDefaultDatRd         )                     
                           );

   // Assign the Bus-side Master to Slave outputs
   assign  WB_REGS_ADR_OUT     = WbRegsAdr   ;
   assign  WB_REGS_WE_OUT      = WbRegsWe    ;
   assign  WB_REGS_SEL_OUT     = WbRegsSel   ;
//   assign  WB_REGS_CTI_OUT     = 3'b000   ; // Not valid for a registers access
//   assign  WB_REGS_BTE_OUT     = 2'b00    ; // Not valid for a registers access
   assign  WB_REGS_DAT_WR_OUT  = WbRegsDatWr ;
   
   // Assign the Slave-specific Master to Slave outputs
   assign  WB_REGS_RCNT_CYC_OUT    = WbRegsRcntCyc    ;
   assign  WB_REGS_RCNT_STB_OUT    = WbRegsRcntStb    ;
   assign  WB_REGS_INTC_CYC_OUT    = WbRegsIntcCyc    ;
   assign  WB_REGS_INTC_STB_OUT    = WbRegsIntcStb    ;
   assign  WB_REGS_DMAC_CYC_OUT    = WbRegsDmacCyc    ;
   assign  WB_REGS_DMAC_STB_OUT    = WbRegsDmacStb    ;
   assign  WB_REGS_BIOS_CYC_OUT    = WbRegsBiosCyc    ;
   assign  WB_REGS_BIOS_STB_OUT    = WbRegsBiosStb    ;
   assign  WB_REGS_MDEC_CYC_OUT    = WbRegsMdecCyc    ;
   assign  WB_REGS_MDEC_STB_OUT    = WbRegsMdecStb    ;  
   assign  WB_REGS_MEMCARD_CYC_OUT = WbRegsMemcardCyc ;
   assign  WB_REGS_MEMCARD_STB_OUT = WbRegsMemcardStb ;
   assign  WB_REGS_SPU_CYC_OUT     = WbRegsSpuCyc     ;
   assign  WB_REGS_SPU_STB_OUT     = WbRegsSpuStb     ;
   assign  WB_REGS_CDROM_CYC_OUT   = WbRegsCdromCyc   ;
   assign  WB_REGS_CDROM_STB_OUT   = WbRegsCdromStb   ;
   assign  WB_REGS_PAD_CYC_OUT     = WbRegsPadCyc     ;
   assign  WB_REGS_PAD_STB_OUT     = WbRegsPadStb     ;
   
   ////////////////////////////////////////////////////////////////////////////
   // External assigns
    // OUTPUTS: System Bus - Master to Slave Common signals to all slaves
   assign  WB_SYS_ADR_OUT     = WbSysAdr   ;
   assign  WB_SYS_WE_OUT      = WbSysWe    ;
   assign  WB_SYS_SEL_OUT     = WbSysSel   ;
   assign  WB_SYS_CTI_OUT     = WbSysCti   ;
   assign  WB_SYS_BTE_OUT     = WbSysBte   ;

   assign  WB_SYS_DAT_WR_OUT  = WbSysDatWr ;
   
   // OUTPUTS: Slave-specific MAster -> Slave signals (CYC; STB)  
   // Regs wiring is within this level, so not sent to top ports
   assign WB_SYS_ROM_CYC_OUT  = WbSysRomCyc ;
   assign WB_SYS_ROM_STB_OUT  = WbSysRomStb ;
   assign WB_SYS_DRAM_CYC_OUT = WbSysDramCyc;
   assign WB_SYS_DRAM_STB_OUT = WbSysDramStb;
   assign WB_SYS_GPU_CYC_OUT  = WbSysGpuCyc ;
   assign WB_SYS_GPU_STB_OUT  = WbSysGpuStb ;

   // INPUTS : Slave -> Master signals. Gate with appropriate selects
   // Address phase signal: STALL
   // Data phase signal   : ACK, ERR, DAT_RD

   assign WbSysAck      = ( (WbSysRomSelReg      & WB_SYS_ROM_ACK_IN  ) 
                          | (WbSysDramSelReg     & WB_SYS_DRAM_ACK_IN ) 
                          | (WbSysGpuSelReg      & WB_SYS_GPU_ACK_IN  )
                          | (WbSysRegsSelReg     & WbSysRegsAck       )
                          | (WbSysDefaultSelReg  & WbSysDefaultAck    )                     
                          );
   
   // Stall is a special case. You need to use the Address-phase select to return the
   // STALLs, and the data phase select to invert ACK and return this as STALL.
   // This prevents the master from issuing a new transaction to another slave
   // before the current one has completed
   assign WbSysStall    = ( (WbSysRomSel         & WB_SYS_ROM_STALL_IN  ) 
                          | (WbSysDramSel        & WB_SYS_DRAM_STALL_IN ) 
                          | (WbSysGpuSel         & WB_SYS_GPU_STALL_IN  )
                          | (WbSysRegsSel        & WbSysRegsStall       )
                          | (WbSysDefaultSel     & WbSysDefaultStall    )                           
                          | (WbSysRomSelReg      & ~WB_SYS_ROM_ACK_IN   ) 
                          | (WbSysDramSelReg     & ~WB_SYS_DRAM_ACK_IN  ) 
                          | (WbSysGpuSelReg      & ~WB_SYS_GPU_ACK_IN   )
                          | (WbSysRegsSelReg     & ~WbSysRegsAck        )
                          | (WbSysDefaultSelReg  & ~WbSysDefaultAck     )                                
                            );
   
   assign WbSysErr      = ( (WbSysRomSelReg      & WB_SYS_ROM_ERR_IN  ) 
                          | (WbSysDramSelReg     & WB_SYS_DRAM_ERR_IN ) 
                          | (WbSysGpuSelReg      & WB_SYS_GPU_ERR_IN  )
                          | (WbSysRegsSelReg     & WbSysRegsErr       )
                          | (WbSysDefaultSelReg  & WbSysDefaultErr    )                     
                          ) ;

   assign WbSysDatRd    = ( ({DAT_W {WbSysRomSelReg}}      & WB_SYS_ROM_DAT_RD_IN  ) 
                          | ({DAT_W {WbSysDramSelReg}}     & WB_SYS_DRAM_DAT_RD_IN ) 
                          | ({DAT_W {WbSysGpuSelReg}}      & WB_SYS_GPU_DAT_RD_IN  )
                          | ({DAT_W {WbSysRegsSelReg}}     & WbSysRegsDatRd        )
                          | ({DAT_W {WbSysDefaultSelReg}}  & WbSysDefaultDatRd     )
                          );

   
   ////////////////////////////////////////////////////////////////////////////
   // Slave select and register for overlapping multiple slave address/data phases
   // Register the Select in the Address Phase (to return data from correct slave
   // for the overlapping address / data case)

   // SYS - Rom Select
   always @(posedge CLK_SYS or posedge RST_ASYNC_SYS)
   begin
      if (RST_ASYNC_SYS)
      begin
         WbSysRomSelReg   <= 1'b0;
      end
      else if (RST_SYNC_SYS)
      begin
         WbSysRomSelReg   <= 1'b0;
      end
      else if (EN_SYS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbSysCyc && WbSysStb && !WbSysStall && WbSysRomSel)
         begin
            WbSysRomSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbSysCyc && (WB_SYS_ROM_ACK_IN || WB_SYS_ROM_ERR_IN))
         begin
            WbSysRomSelReg   <= 1'b0;
         end
      end
   end

   // SYS - Dram Select
   always @(posedge CLK_SYS or posedge RST_ASYNC_SYS)
   begin
      if (RST_ASYNC_SYS)
      begin
         WbSysDramSelReg   <= 1'b0;
      end
      else if (RST_SYNC_SYS)
      begin
         WbSysDramSelReg   <= 1'b0;
      end
      else if (EN_SYS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbSysCyc && WbSysStb && !WbSysStall && WbSysDramSel)
         begin
            WbSysDramSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbSysCyc && (WB_SYS_DRAM_ACK_IN || WB_SYS_DRAM_ERR_IN))
         begin
            WbSysDramSelReg   <= 1'b0;
         end
      end
   end

   // SYS - Gpu Select
   always @(posedge CLK_SYS or posedge RST_ASYNC_SYS)
   begin
      if (RST_ASYNC_SYS)
      begin
         WbSysGpuSelReg   <= 1'b0;
      end
      else if (RST_SYNC_SYS)
      begin
         WbSysGpuSelReg   <= 1'b0;
      end
      else if (EN_SYS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbSysCyc && WbSysStb && !WbSysStall && WbSysGpuSel)
         begin
            WbSysGpuSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbSysCyc && (WB_SYS_GPU_ACK_IN || WB_SYS_GPU_ERR_IN))
         begin
            WbSysGpuSelReg   <= 1'b0;
         end
      end
   end

   // SYS - Regs Select
   always @(posedge CLK_SYS or posedge RST_ASYNC_SYS)
   begin
      if (RST_ASYNC_SYS)
      begin
         WbSysRegsSelReg   <= 1'b0;
      end
      else if (RST_SYNC_SYS)
      begin
         WbSysRegsSelReg   <= 1'b0;
      end
      else if (EN_SYS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbSysCyc && WbSysStb && !WbSysStall && WbSysRegsSel)
         begin
            WbSysRegsSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbSysCyc && (WbSysRegsAck || WbSysRegsErr))
         begin
            WbSysRegsSelReg   <= 1'b0;
         end
      end
   end

   // SYS - Default Select
   always @(posedge CLK_SYS or posedge RST_ASYNC_SYS)
   begin
      if (RST_ASYNC_SYS)
      begin
         WbSysDefaultSelReg   <= 1'b0;
      end
      else if (RST_SYNC_SYS)
      begin
         WbSysDefaultSelReg   <= 1'b0;
      end
      else if (EN_SYS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbSysCyc && WbSysStb && !WbSysStall && WbSysDefaultSel)
         begin
            WbSysDefaultSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbSysCyc && (WbSysDefaultAck || WbSysDefaultErr))
         begin
            WbSysDefaultSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Need a priority encoded decode, as the ranges aren't mutually exclusive..
   always @*
   begin : REGS_SEL_DECODE

      WbRegsRcntSel    = 1'b0;
      WbRegsIntcSel    = 1'b0;
      WbRegsDmacSel    = 1'b0;   
      WbRegsBiosSel    = 1'b0;
      WbRegsMdecSel    = 1'b0;
      WbRegsMemcardSel = 1'b0;
      WbRegsSpuSel     = 1'b0;
      WbRegsCdromSel   = 1'b0;
      WbRegsPadSel     = 1'b0;
      WbRegsDefaultSel = 1'b0;

      // Use a priority encoder, starting with highest address and check for
      // higher range
      if     (WbRegsAdr[REGS_SEL_LSB-1:0] >= SPU_REGS_BASE_WIRE[REGS_SEL_LSB-1:0]  )
      begin
         WbRegsSpuSel     = 1'b1;
      end
      else if(WbRegsAdr[REGS_SEL_LSB-1:0] >= MDEC_REGS_BASE_WIRE[REGS_SEL_LSB-1:0] )
      begin
         WbRegsMdecSel    = 1'b1;
      end
      // GPU decode is done on system bus, not regs (high bandwidth)
      //      else if(WbRegsAdr[REGS_SEL_LSB-1:0] > GPU_REGS_BASE_WIRE[REGS_SEL_LSB-1:0]  )
      //      begin
      //      end
      else if(WbRegsAdr[REGS_SEL_LSB-1:0] >= CDROM_REGS_BASE_WIRE[REGS_SEL_LSB-1:0])
      begin
         WbRegsCdromSel   = 1'b1;
      end
      else if(WbRegsAdr[REGS_SEL_LSB-1:0] >= RCNT_REGS_BASE_WIRE[REGS_SEL_LSB-1:0] )
      begin
         WbRegsRcntSel    = 1'b1;
      end
      else if(WbRegsAdr[REGS_SEL_LSB-1:0] >= DMAC_REGS_BASE_WIRE[REGS_SEL_LSB-1:0] )
      begin
         WbRegsDmacSel    = 1'b1;        
      end
      else if(WbRegsAdr[REGS_SEL_LSB-1:0] >= INTC_REGS_BASE_WIRE[REGS_SEL_LSB-1:0] )
      begin
         WbRegsIntcSel    = 1'b1;
      end
      // todo add select for the SIO
      //      else if(WbRegsAdr[REGS_SEL_LSB-1:0] > SIO_REGS_BASE_WIRE[REGS_SEL_LSB-1:0]  )
      //      begin
      //      end
      else if(WbRegsAdr[REGS_SEL_LSB-1:0] >= BIOS_REGS_BASE_WIRE[REGS_SEL_LSB-1:0] )
      begin
         WbRegsBiosSel    = 1'b1;
      end
      else
      begin
         WbRegsDefaultSel = 1'b1;
      end
   end

   // REGS - Rcnt Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsRcntSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsRcntSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsRcntSel)
         begin
            WbRegsRcntSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_RCNT_ACK_IN || WB_REGS_RCNT_ERR_IN))
         begin
            WbRegsRcntSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Intc Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsIntcSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsIntcSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsIntcSel)
         begin
            WbRegsIntcSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_INTC_ACK_IN || WB_REGS_INTC_ERR_IN))
         begin
            WbRegsIntcSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Dmac Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsDmacSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsDmacSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsDmacSel)
         begin
            WbRegsDmacSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_DMAC_ACK_IN || WB_REGS_DMAC_ERR_IN))
         begin
            WbRegsDmacSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Bios Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsBiosSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsBiosSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsBiosSel)
         begin
            WbRegsBiosSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_BIOS_ACK_IN || WB_REGS_BIOS_ERR_IN))
         begin
            WbRegsBiosSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Mdec Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsMdecSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsMdecSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsMdecSel)
         begin
            WbRegsMdecSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_MDEC_ACK_IN || WB_REGS_MDEC_ERR_IN))
         begin
            WbRegsMdecSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Memcard Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsMemcardSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsMemcardSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsMemcardSel)
         begin
            WbRegsMemcardSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_MDEC_ACK_IN || WB_REGS_MEMCARD_ERR_IN))
         begin
            WbRegsMemcardSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Spu Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsSpuSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsSpuSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsSpuSel)
         begin
            WbRegsSpuSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_SPU_ACK_IN || WB_REGS_SPU_ERR_IN))
         begin
            WbRegsSpuSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Cdrom Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsCdromSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsCdromSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsCdromSel)
         begin
            WbRegsCdromSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_CDROM_ACK_IN || WB_REGS_CDROM_ERR_IN))
         begin
            WbRegsCdromSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Pad Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsPadSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsPadSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsPadSel)
         begin
            WbRegsPadSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WB_REGS_PAD_ACK_IN || WB_REGS_PAD_ERR_IN))
         begin
            WbRegsPadSelReg   <= 1'b0;
         end
      end
   end

   // REGS - Default Select
   always @(posedge CLK_REGS or posedge RST_ASYNC_REGS)
   begin
      if (RST_ASYNC_REGS)
      begin
         WbRegsDefaultSelReg   <= 1'b0;
      end
      else if (RST_SYNC_REGS)
      begin
         WbRegsDefaultSelReg   <= 1'b0;
      end
      else if (EN_REGS)
      begin
         // Store the slave selected when a new address is accepted
         if (WbRegsCyc && WbRegsStb && !WbRegsStall && WbRegsDefaultSel)
         begin
            WbRegsDefaultSelReg   <= 1'b1;
         end
         // Clear Arb Select when last ACK/ERR comes back
         else if (WbRegsCyc && (WbRegsDefaultAck || WbRegsDefaultErr))
         begin
            WbRegsDefaultSelReg   <= 1'b0;
         end
      end
   end


   

   
  ////////////////////////////////////////////////////////////////////////////
   // External assigns

   ////////////////////////////////////////////////////////////////////////////
   // Always blocks

   
   ////////////////////////////////////////////////////////////////////////////
   // First-stage Arbiter
   // Master 0 has highest priority => DMA
   // Master 1 has second priority  => MIPS1
   

   WB_ARB_2M_1S wb_arb_2m_1s
      (
       .CLK               (CLK_SYS        ),
       .EN                (EN_SYS         ),
       .RST_SYNC          (RST_SYNC_SYS   ),
       .RST_ASYNC         (RST_ASYNC_SYS  ),
      
       .WB_SL0_ADR_IN     (WB_MIPS_ADR_IN       ),
       .WB_SL0_CYC_IN     (WB_MIPS_CYC_IN       ),
       .WB_SL0_STB_IN     (WB_MIPS_STB_IN       ),
       .WB_SL0_WE_IN      (WB_MIPS_WE_IN        ),
       .WB_SL0_SEL_IN     (WB_MIPS_SEL_IN       ),
       .WB_SL0_CTI_IN     (WB_MIPS_CTI_IN       ),
       .WB_SL0_BTE_IN     (WB_MIPS_BTE_IN       ),
      
       .WB_SL0_STALL_OUT  (WB_MIPS_STALL_OUT    ),
       .WB_SL0_ACK_OUT    (WB_MIPS_ACK_OUT      ),
       .WB_SL0_ERR_OUT    (WB_MIPS_ERR_OUT      ),
      
       .WB_SL0_RD_DAT_OUT (WB_MIPS_RD_DAT_OUT   ),
       .WB_SL0_WR_DAT_IN  (WB_MIPS_WR_DAT_IN    ),

       .WB_SL1_ADR_IN     (WB_DMAC_ADR_IN      ),
       .WB_SL1_CYC_IN     (WB_DMAC_CYC_IN      ),
       .WB_SL1_STB_IN     (WB_DMAC_STB_IN      ),
       .WB_SL1_WE_IN      (WB_DMAC_WE_IN       ),
       .WB_SL1_SEL_IN     (WB_DMAC_SEL_IN      ),
       .WB_SL1_CTI_IN     (WB_DMAC_CTI_IN      ),
       .WB_SL1_BTE_IN     (WB_DMAC_BTE_IN      ),
      
       .WB_SL1_STALL_OUT  (WB_DMAC_STALL_OUT   ),
       .WB_SL1_ACK_OUT    (WB_DMAC_ACK_OUT     ),
       .WB_SL1_ERR_OUT    (WB_DMAC_ERR_OUT     ),
      
       .WB_SL1_RD_DAT_OUT (WB_DMAC_RD_DAT_OUT  ),
       .WB_SL1_WR_DAT_IN  (WB_DMAC_WR_DAT_IN   ),

       .WB_M0_ADR_OUT     (WbSysAdr      ),
       .WB_M0_CYC_OUT     (WbSysCyc      ),
       .WB_M0_STB_OUT     (WbSysStb      ),
       .WB_M0_WE_OUT      (WbSysWe       ),
       .WB_M0_SEL_OUT     (WbSysSel      ),
       .WB_M0_CTI_OUT     (WbSysCti      ),
       .WB_M0_BTE_OUT     (WbSysBte      ),
       .WB_M0_STALL_IN    (WbSysStall    ),
       .WB_M0_ACK_IN      (WbSysAck      ),
       .WB_M0_ERR_IN      (WbSysErr      ),
       .WB_M0_RD_DAT_IN   (WbSysDatRd    ),
       .WB_M0_WR_DAT_OUT  (WbSysDatWr    )
       );

   // Default slave (SYS bus)
   WB_SLAVE_CTRL
      #(.DEFAULT_SLAVE ( 1),
        .DEFAULT_ERR   ( 0), // Don't return an ERR for an unknown address
        .WB_ADDR_MSB   (11), // or the CPU will jump to the IRQ address to 
        .WB_ADDR_LSB   ( 8), // service a bus error IRQ
        .WB_ADDR_VAL   ( 0)
        )
   wb_slave_ctrl_sys                         
      (
       .CLK                   (CLK_SYS        ),
       .EN                    (EN_SYS         ),
       .RST_SYNC              (RST_SYNC_SYS   ),
       .RST_ASYNC             (RST_ASYNC_SYS  ),
      
       .WB_REGS_ADR_IN        (WbSysAdr          ), 
       .WB_REGS_CYC_IN        (WbSysDefaultCyc   ), 
       .WB_REGS_STB_IN        (WbSysDefaultStb   ), 
       .WB_REGS_WE_IN         (WbSysWe           ), 
       .WB_REGS_SEL_IN        (WbSysSel          ), 
       .WB_REGS_ACK_OUT       (WbSysDefaultAck   ), 
       .WB_REGS_STALL_OUT     (WbSysDefaultStall ), 
       .WB_REGS_ERR_OUT       (WbSysDefaultErr   ), 
      
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );

   // Default slave (REGS bus)
   WB_SLAVE_CTRL
      #(.DEFAULT_SLAVE ( 1),
        .DEFAULT_ERR   ( 0), // Don't return an ERR for an unknown address or the 
        .WB_ADDR_MSB   (11), // CPU will jump to the ISR 
        .WB_ADDR_LSB   ( 8),
        .WB_ADDR_VAL   ( 0)
        )
   wb_slave_ctrl_regs                         
      (
       .CLK                   (CLK_REGS        ),
       .EN                    (EN_REGS         ),
       .RST_SYNC              (RST_SYNC_REGS   ),
       .RST_ASYNC             (RST_ASYNC_REGS  ),
      
       .WB_REGS_ADR_IN        (WbRegsAdr          ), 
       .WB_REGS_CYC_IN        (WbRegsDefaultCyc   ), 
       .WB_REGS_STB_IN        (WbRegsDefaultStb   ), 
       .WB_REGS_WE_IN         (WbRegsWe           ), 
       .WB_REGS_SEL_IN        (WbRegsSel          ), 
       .WB_REGS_ACK_OUT       (WbRegsDefaultAck   ), 
       .WB_REGS_STALL_OUT     (WbRegsDefaultStall ), 
       .WB_REGS_ERR_OUT       (WbRegsDefaultErr   ), 
      
       .WB_WRITE_ADDR_STB_OUT ( ),
       .WB_READ_ADDR_STB_OUT  ( ),
       .WB_VALID_OUT          ( )
       );

   WB_SYNC_BRIDGE wb_sync_bridge_regs
      (
       .CLK_SRC            (CLK_SYS             ),
       .EN_SRC             (EN_SYS              ),
       .RST_SRC_SYNC       (RST_SYNC_SYS        ),
       .RST_SRC_ASYNC      (RST_ASYNC_SYS       ), 
      
       .CLK_DST            (CLK_REGS            ),
       .EN_DST             (EN_REGS             ),
       .RST_DST_SYNC       (RST_SYNC_REGS       ),
       .RST_DST_ASYNC      (RST_ASYNC_REGS      ), 

       .WB_S_ADR_IN        (WbSysAdr            ),
       .WB_S_CYC_IN        (WbSysRegsCyc        ),
       .WB_S_STB_IN        (WbSysRegsStb        ),
       .WB_S_WE_IN         (WbSysWe             ),
       .WB_S_SEL_IN        (WbSysSel            ),
       .WB_S_CTI_IN        (WbSysCti            ),
       .WB_S_BTE_IN        (WbSysBte            ),
       .WB_S_STALL_OUT     (WbSysRegsStall      ),
       .WB_S_ACK_OUT       (WbSysRegsAck        ),
       .WB_S_ERR_OUT       (WbSysRegsErr        ),
       .WB_S_DAT_RD_OUT    (WbSysRegsDatRd      ),
       .WB_S_DAT_WR_IN     (WbSysDatWr          ), 
      
       .WB_M_ADR_OUT       (WbRegsAdr  	        ),
       .WB_M_CYC_OUT       (WbRegsCyc  	        ),
       .WB_M_STB_OUT       (WbRegsStb  	        ),
       .WB_M_WE_OUT        (WbRegsWe   	        ),
       .WB_M_SEL_OUT       (WbRegsSel  	        ),
       .WB_M_CTI_OUT       (WbRegsCti  	        ),
       .WB_M_BTE_OUT       (WbRegsBte  	        ), 
       .WB_M_ACK_IN        (WbRegsAck  	        ),
       .WB_M_STALL_IN      (WbRegsStall	        ),
       .WB_M_ERR_IN        (WbRegsErr  	        ),
       .WB_M_DAT_RD_IN     (WbRegsDatRd	        ),
       .WB_M_DAT_WR_OUT    (WbRegsDatWr	        ) 
      
       );
   


   
endmodule
