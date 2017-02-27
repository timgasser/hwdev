// Co processor 0 defines

// Instruction fields

// CP0 fields. Decoded with Opcode = OPC_COP0
parameter CP0_HI    = 4;
parameter CP0_LO    = 0;

parameter TLBR  = 5'b00001;
parameter TLBWI = 5'b00010;
parameter TLBWR = 5'b00110;
parameter TLBP  = 5'b01000;
parameter RFE   = 5'b10000;

// Register numbering
parameter [4:0] COP0_BADVA   = 5'd8 ;
parameter [4:0] COP0_COUNT   = 5'd9 ;
parameter [4:0] COP0_COMPARE = 5'd11;
parameter [4:0] COP0_STATUS  = 5'd12;
parameter [4:0] COP0_CAUSE   = 5'd13;
parameter [4:0] COP0_EPC     = 5'd14;
parameter [4:0] COP0_PRID    = 5'd15;
parameter [4:0] COP0_TEST    = 5'd20;


// Register bitfields (may be a mixture of R/O and R/W)
// COP0_BADVA   <- full 32 bits used
// ----- COP0 Count Reg -----
parameter COP0_COUNT_MSB   = 23; parameter COP0_COUNT_LSB   =  0;

// ----- COP0 Compare Reg -----
parameter COP0_COMPARE_MSB = 23; parameter COP0_COMPARE_LSB =  0;

// ----- COP0 Status Reg -----
parameter COP0_STATUS_CU_MSB   	= 31; parameter COP0_STATUS_CU_LSB  = 28;
// [27:26] reserved
parameter COP0_STATUS_RE       	= 25;
// [24:23] reserved
parameter COP0_STATUS_BEV      	= 22;
parameter COP0_STATUS_TS       	= 21;
parameter COP0_STATUS_PE       	= 20;
parameter COP0_STATUS_CM       	= 19;
parameter COP0_STATUS_PZ       	= 18;
parameter COP0_STATUS_SWC      	= 17;
parameter COP0_STATUS_ISC      	= 16;
parameter COP0_STATUS_IM_HW_MSB = 15; parameter COP0_STATUS_IM_HW_LSB  = 10;
parameter COP0_STATUS_IM_SW_MSB =  9; parameter COP0_STATUS_IM_SW_LSB  =  8;
// [ 7: 6] reserved
parameter COP0_STATUS_KUO_B =  5; // Kernel mode bits are active low
parameter COP0_STATUS_IEO   =  4;
parameter COP0_STATUS_KUP_B =  3; // Kernel mode bits are active low
parameter COP0_STATUS_IEP   =  2;
parameter COP0_STATUS_KUC_B =  1; // Kernel mode bits are active low
parameter COP0_STATUS_IEC   =  0;

// COP0_CAUSE  
parameter COP0_CAUSE_BD  =  31;
// [30] reserved
parameter COP0_CAUSE_CE_MSB =  29; parameter COP0_CAUSE_CE_LSB  =  28;
// [27:16] reserved
parameter COP0_CAUSE_IP_MSB =  15; parameter COP0_CAUSE_IP_LSB  =  10;
parameter COP0_CAUSE_SW_MSB =   9; parameter COP0_CAUSE_SW_LSB  =   8;
// [7] reserved
parameter COP0_CAUSE_EXC_CODE_MSB =   7; parameter COP0_CAUSE_EXC_CODE_LSB  =   2;
//// ENUMS for COP0_CAUSE_SW_MSB
// [1:0] reserved

// COP0_EPC
parameter COP0_EPC_MSB =   31; parameter COP0_EPC_LSB  =   0;

// COP0_PRID   
parameter COP0_PRID_IMP_MSB =   15; parameter COP0_PRID_IMP_LSB  =   8;
parameter COP0_PRID_REV_MSB =    7; parameter COP0_PRID_REV_LSB  =   0;

parameter [7:0] COP0_IMP = 8'h02;
parameter [7:0] COP0_REV = 8'h30;

// EXC CODE enums - used in COP0_CAUSE (listed in priority order)
parameter [4:0] EXC_CODE_ADEL    = 5'd4 ; // could be instruction or data
parameter [4:0] EXC_CODE_ADES    = 5'd5 ;
parameter [4:0] EXC_CODE_DBE	 = 5'd7 ;
parameter [4:0] EXC_CODE_INT	 = 5'd0 ;
parameter [4:0] EXC_CODE_OVF	 = 5'd12;
parameter [4:0] EXC_CODE_SYS	 = 5'd8 ;
parameter [4:0] EXC_CODE_BP	 = 5'd9 ;
parameter [4:0] EXC_CODE_RI	 = 5'd10;
parameter [4:0] EXC_CODE_CPU	 = 5'd11;
parameter [4:0] EXC_CODE_IBE	 = 5'd6 ;

// Used for ExcStage
parameter EXC_STAGE_IF 	= 0;
parameter EXC_STAGE_ID 	= 1;
parameter EXC_STAGE_EX 	= 2;
parameter EXC_STAGE_MEM = 3;
parameter EXC_STAGE_WB  = 4;
