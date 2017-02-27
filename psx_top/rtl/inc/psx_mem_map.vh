///////////////////////////////////////////////////////////////////////////////
// RAM and ROM sizes. Also includes decode of upper address for slave selects

// System bus slave address ranges.
// There are 4 slaves on the SYS bus:
// - DRAM
// - ROM
// - GPU
// - REGS (Which forwards the SYS request onto the REGS bus)

// ROM Address
// [31:29] ( 3 bits) - Always 0 as these are physical addresses
// [28:19] (10 bits) - This is the upper address decode section
// [18: 0] (19 bits) - The index for a 512kB ROM
//
parameter [31:0] ROM_BASE = 32'h1fc0_0000;
parameter ROM_SIZE_P2 = 19;                  // bits [18:0]
parameter ROM_ADDR_MSB = ROM_SIZE_P2 - 1;
parameter ROM_SEL_MSB = 31;
parameter ROM_SEL_LSB = ROM_SIZE_P2;
parameter [ROM_SEL_MSB:ROM_SEL_LSB] ROM_SEL_VAL = {12'h1fc, 1'b0}; // split into nibbles for better readability

parameter [31:0] DRAM_BASE = 32'h0000_0000; // size is 0x0020_0000 (2MB)
parameter DRAM_SIZE_P2 = 21;
parameter DRAM_ADDR_MSB = DRAM_SIZE_P2 - 1;
parameter DRAM_SEL_MSB = 31;
parameter DRAM_SEL_LSB = 21;
parameter [DRAM_SEL_MSB:DRAM_SEL_LSB] DRAM_SEL_VAL = 9'b0_0000_0000;

// No way to index a clean slave select for the GPU regs, as it's within the REGS range ..
parameter [31:0] GPU_BASE = 32'h1f80_1810;
parameter GPU_SIZE_P2 = 4;
parameter GPU_ADDR_MSB = GPU_SIZE_P2 - 1;
parameter GPU_SEL_MSB = 31;
parameter GPU_SEL_LSB = 4;
parameter [GPU_SEL_MSB:GPU_SEL_LSB] GPU_SEL_VAL = 28'h1f80_181;

// // D-TCM indexed within the mips1 top level
// parameter [31:0] DTCM_BASE = 32'h1f80_0000;
// parameter DTCM_SIZE_P2 = 19;
// parameter DTCM_ADDR_MSB = DTCM_SIZE_P2 - 1;
// parameter DTCM_SEL_MSB = 31;
// parameter DTCM_SEL_LSB = ;
// parameter [x:y] DTCM_SEL_VAL


parameter [31:0] REGS_BASE = 32'h1f80_1000;
parameter REGS_SIZE_P2 = 0; // is this used?
parameter REGS_ADDR_MSB = REGS_SIZE_P2 - 1;
parameter REGS_SEL_MSB = 31;
parameter REGS_SEL_LSB = 12;
parameter [REGS_SEL_MSB:REGS_SEL_LSB] REGS_SEL_VAL = 20'h1f80_1;



///////////////////////////////////////////////////////////////////////////////
// Register defines
//
// Can't do a parallel decode of these as their address bit ranges overlap !
// so do a priority encoded one..

// BIOS registers
parameter BIOS_REGS_BASE  = 32'h1f80_1000;
parameter BIOS_REG0 	  = 32'h1f80_1000;
parameter BIOS_REG1 	  = 32'h1f80_1004;
parameter BIOS_REG2 	  = 32'h1f80_1008;
parameter BIOS_REG3 	  = 32'h1f80_100c;
parameter BIOS_REG4 	  = 32'h1f80_1010;
parameter BIOS_REG5 	  = 32'h1f80_1014;
parameter BIOS_REG6 	  = 32'h1f80_1018;
parameter BIOS_REG7 	  = 32'h1f80_101c;
parameter BIOS_REG8 	  = 32'h1f80_1020;

// SIO registers <- todo check these !
parameter SIO_REGS_BASE   = 32'h1f80_1040;
parameter SIO_REG0  	  = 32'h1f80_1040;
parameter SIO_REG1  	  = 32'h1f80_105c;

// Interrupt regs
parameter INTC_REGS_BASE  = 32'h1f80_1070;
parameter INTC_IREG 	  = 32'h1f80_1070;
parameter INTC_MASK 	  = 32'h1f80_1074;

////////////////////////////////////////////////////////////////////////////////
// DMA Registers
//
parameter DMAC_REGS_BASE    = 32'h1f80_1080;
parameter DMAC_MDECIN_MADR  = 32'h1f80_1080;
parameter DMAC_MDECIN_BCR   = 32'h1f80_1084;
parameter DMAC_MDECIN_CHCR  = 32'h1f80_1088;
parameter DMAC_MDECOUT_MADR = 32'h1f80_1090;
parameter DMAC_MDECOUT_BCR  = 32'h1f80_1094;
parameter DMAC_MDECOUT_CHCR = 32'h1f80_1098;
parameter DMAC_GPU_MADR     = 32'h1f80_10a0;
parameter DMAC_GPU_BCR      = 32'h1f80_10a4;
parameter DMAC_GPU_CHCR     = 32'h1f80_10a8;
parameter DMAC_CDROM_MADR   = 32'h1f80_10b0;
parameter DMAC_CDROM_BCR    = 32'h1f80_10b4;
parameter DMAC_CDROM_CHCR   = 32'h1f80_10b8;
parameter DMAC_SPU_MADR     = 32'h1f80_10c0;
parameter DMAC_SPU_BCR      = 32'h1f80_10c4;
parameter DMAC_SPU_CHCR     = 32'h1f80_10c8;
parameter DMAC_PIO_MADR     = 32'h1f80_10d0;
parameter DMAC_PIO_BCR      = 32'h1f80_10d4;
parameter DMAC_PIO_CHCR     = 32'h1f80_10d8;
parameter DMAC_OT_MADR      = 32'h1f80_10e0;
parameter DMAC_OT_BCR       = 32'h1f80_10e4;
parameter DMAC_OT_CHCR      = 32'h1f80_10e8;
parameter DMAC_PCR          = 32'h1f80_10f0;
parameter DMAC_ICR          = 32'h1f80_10f4;

// Bit fields - DMAC_BCR
parameter DMAC_BCR_BLK_CNT_MSB  = 31;
parameter DMAC_BCR_BLK_CNT_LSB  = 16;
parameter DMAC_BCR_BLK_SIZE_MSB = 15;
parameter DMAC_BCR_BLK_SIZE_LSB =  0;

// Bit fields - DMAC_PCR
parameter DMAC_PCR_CH6_EN_BIT  = 27;
parameter DMAC_PCR_CH6_PRI_MSB = 26;
parameter DMAC_PCR_CH6_PRI_LSB = 24;
parameter DMAC_PCR_CH5_EN_BIT  = 23;
parameter DMAC_PCR_CH5_PRI_MSB = 22;
parameter DMAC_PCR_CH5_PRI_LSB = 20;
parameter DMAC_PCR_CH4_EN_BIT  = 19;
parameter DMAC_PCR_CH4_PRI_MSB = 18;
parameter DMAC_PCR_CH4_PRI_LSB = 16;
parameter DMAC_PCR_CH3_EN_BIT  = 15;
parameter DMAC_PCR_CH3_PRI_MSB = 14;
parameter DMAC_PCR_CH3_PRI_LSB = 12;
parameter DMAC_PCR_CH2_EN_BIT  = 11;
parameter DMAC_PCR_CH2_PRI_MSB = 10;
parameter DMAC_PCR_CH2_PRI_LSB =  8;
parameter DMAC_PCR_CH1_EN_BIT  =  7;
parameter DMAC_PCR_CH1_PRI_MSB =  6;
parameter DMAC_PCR_CH1_PRI_LSB =  4;
parameter DMAC_PCR_CH0_EN_BIT  =  3;
parameter DMAC_PCR_CH0_PRI_MSB =  2;
parameter DMAC_PCR_CH0_PRI_LSB =  0;

// Bit fields - DMAC_ICR
parameter DMAC_ICR_STATUS_BIT     = 31;
parameter DMAC_ICR_CH6_STATUS_BIT = 30;
parameter DMAC_ICR_CH5_STATUS_BIT = 29;
parameter DMAC_ICR_CH4_STATUS_BIT = 28;
parameter DMAC_ICR_CH3_STATUS_BIT = 27;
parameter DMAC_ICR_CH2_STATUS_BIT = 26;
parameter DMAC_ICR_CH1_STATUS_BIT = 25;
parameter DMAC_ICR_CH0_STATUS_BIT = 24;
parameter DMAC_ICR_EN_BIT         = 23;
parameter DMAC_ICR_CH6_EN_BIT     = 22;
parameter DMAC_ICR_CH5_EN_BIT     = 21;
parameter DMAC_ICR_CH4_EN_BIT     = 20;
parameter DMAC_ICR_CH3_EN_BIT     = 19;
parameter DMAC_ICR_CH2_EN_BIT     = 18;
parameter DMAC_ICR_CH1_EN_BIT     = 17;
parameter DMAC_ICR_CH0_EN_BIT     = 16;

// Bit fields - DMAC_CHCR
parameter DMAC_CHCR_TR_BIT   = 24;
parameter DMAC_CHCR_LI_BIT   = 10;
parameter DMAC_CHCR_CO_BIT   =  9;
parameter DMAC_CHCR_DR_BIT   =  0; // 1 = FROM mem, 0 = TO mem

// DMA Channel allocation
parameter DMAC_MDECIN_CH   = 0;
parameter DMAC_MDECOUT_CH  = 1;
parameter DMAC_GPU_CH      = 2;
parameter DMAC_CDROM_CH    = 3;
parameter DMAC_SPU_CH      = 4;
parameter DMAC_PIO_CH      = 5;
parameter DMAC_OT_CH       = 6;

   parameter DMAC6_OT_END        = 32'h00ff_ffff; // OT entry to terminate linked list
   parameter DMAC6_CHCR_EN       = 32'h1100_0002; // Magic number to activate DMA CH 6


   // DMA Registers are from 0x1f80_1080 

// 0x1f80_1080	0	MDECin
// 0x1f80_1090	1	MDECout
// 0x1f80_10a0	2	GPU IMAGE
// 0x1f80_10b0	3	CD-ROM
// 0x1f80_10c0	4	SPU
// 0x1f80_10d0	5	PIO
// 0x1f80_10e0	6	GPU OTC

// For each of the above registers:

// [3:2] = 0 => MADR
// [3:2] = 1 => BCR
// [3:2] = 2 => CHCR

parameter DMAC_CH_SEL_MSB = 6;
parameter DMAC_CH_SEL_LSB = 4;
parameter DMAC_REG_SEL_MSB = 3;
parameter DMAC_REG_SEL_LSB = 2;
parameter DMAC_REG_SEL_MADR = 2'b00; // Bottom nibble is 4'h0
parameter DMAC_REG_SEL_BCR  = 2'b01; // Bottom nibble is 4'h4
parameter DMAC_REG_SEL_CHCR = 2'b10; // Bottom nibble is 4'h8
		
// 0x1f80_10f0	Primary Control Register (PCR)	
// 0x1f80_10f4	Interrupt Control Register (ICR)




////////////////////////////////////////////////////////////////////////////////

// Root counters
parameter RCNT_REGS_BASE    = 32'h1f80_1100;
parameter CNT0_COUNT        = 32'h1f80_1100;
parameter CNT0_MODE         = 32'h1f80_1104;
parameter CNT0_TARGET       = 32'h1f80_1108;
parameter CNT1_COUNT        = 32'h1f80_1110;
parameter CNT1_MODE         = 32'h1f80_1114;
parameter CNT1_TARGET       = 32'h1f80_1118;
parameter CNT2_COUNT        = 32'h1f80_1120;
parameter CNT2_MODE         = 32'h1f80_1124;
parameter CNT2_TARGET       = 32'h1f80_1128;
parameter CNT3_COUNT        = 32'h1f80_1120;
parameter CNT3_MODE         = 32'h1f80_1124;
parameter CNT3_TARGET       = 32'h1f80_1128;

// CDROM registers
parameter CDROM_REGS_BASE   = 32'h1f80_1800;
parameter CDROM0            = 32'h1f80_1800;
parameter CDROM1            = 32'h1f80_1801;
parameter CDROM2            = 32'h1f80_1802;
parameter CDROM3            = 32'h1f80_1803;

// GPU registers
parameter GPU_REGS_BASE     = 32'h1f80_1810;
parameter GPU_DATA          = 32'h1f80_1810;
parameter GPU_CSR           = 32'h1f80_1814;

// MDEC registers
parameter MDEC_REGS_BASE    = 32'h1f80_1820;
parameter MDEC0             = 32'h1f80_1820;
parameter MDEC1             = 32'h1f80_1824;

// SPU registers
parameter SPU_REGS_BASE     = 32'h1f80_1c00;
parameter SPU_TOP           = 32'h1f80_1dff;


///////////////////////////////////////////////////////////////////////////////
// SIO bitfields


///////////////////////////////////////////////////////////////////////////////
// Interrupt controller (INTC) bitfields




///////////////////////////////////////////////////////////////////////////////
// Root Counters bitfields


///////////////////////////////////////////////////////////////////////////////
// CDROM registers bitfields

///////////////////////////////////////////////////////////////////////////////
// GPU registers bitfields



///////////////////////////////////////////////////////////////////////////////
// MDEC registers bitfields





   // Convert register base parameters to wires so bit selects can be used
   wire [31:0] BIOS_REGS_BASE_WIRE   = BIOS_REGS_BASE  ;
   wire [31:0] SIO_REGS_BASE_WIRE    = SIO_REGS_BASE   ;
   wire [31:0] INTC_REGS_BASE_WIRE   = INTC_REGS_BASE  ;
   wire [31:0] DMAC_REGS_BASE_WIRE   = DMAC_REGS_BASE  ;
   wire [31:0] RCNT_REGS_BASE_WIRE   = RCNT_REGS_BASE  ;
   wire [31:0] CDROM_REGS_BASE_WIRE  = CDROM_REGS_BASE ;
   wire [31:0] GPU_REGS_BASE_WIRE    = GPU_REGS_BASE   ;
   wire [31:0] MDEC_REGS_BASE_WIRE   = MDEC_REGS_BASE  ;
   wire [31:0] SPU_REGS_BASE_WIRE    = SPU_REGS_BASE   ;
  
