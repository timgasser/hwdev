/* INSERT MODULE HEADER */


/*****************************************************************************/
module CPU_CORE
  #(parameter PC_RST_VALUE = 32'h0000_0000)
   (
    input         CLK                   ,
    input         RST_SYNC              ,

    // Instruction Memory (Read only)
    output [31:0] CORE_INST_ADR_OUT     , 
    output        CORE_INST_CYC_OUT     , 
    output        CORE_INST_STB_OUT     , 
    output        CORE_INST_WE_OUT      , 
    output [ 3:0] CORE_INST_SEL_OUT     , 
    output [ 2:0] CORE_INST_CTI_OUT     , 
    output [ 1:0] CORE_INST_BTE_OUT     , 
    input         CORE_INST_ACK_IN      , 
    input         CORE_INST_STALL_IN    , 
    input         CORE_INST_ERR_IN      , 
    input  [31:0] CORE_INST_DAT_RD_IN   , 
    output [31:0] CORE_INST_DAT_WR_OUT  , 
    
     // Data Memory (Read and Write)
    output [31:0] CORE_DATA_ADR_OUT     , 
    output        CORE_DATA_CYC_OUT     , 
    output        CORE_DATA_STB_OUT     , 
    output        CORE_DATA_WE_OUT      , 
    output [ 3:0] CORE_DATA_SEL_OUT     , 
    output [ 2:0] CORE_DATA_CTI_OUT     , 
    output [ 1:0] CORE_DATA_BTE_OUT     , 
    input         CORE_DATA_ACK_IN      , 
    input         CORE_DATA_STALL_IN    , 
    input         CORE_DATA_ERR_IN      , 
    input  [31:0] CORE_DATA_DAT_RD_IN   , 
    output [31:0] CORE_DATA_DAT_WR_OUT  , 

    // Co-processor 0 interface
    output        COP0_INST_EN_OUT      , // 
    output  [4:0] COP0_INST_OUT         , // 
    
    output        COP0_RD_EN_OUT      	, // 
//    input         COP0_RD_ACK_IN       	, // 
    output        COP0_RD_CTRL_SEL_OUT 	, // 
    output  [4:0] COP0_RD_SEL_OUT      	, // 
    input  [31:0] COP0_RD_DATA_IN      	, // 

    output        COP0_WR_EN_OUT       	, // 
    output        COP0_WR_CTRL_SEL_OUT 	, // 
    output  [4:0] COP0_WR_SEL_OUT      	, // 
    output [31:0] COP0_WR_DATA_OUT     	, // 

    input   [3:0] COP_USABLE_IN        	, // 

    input 	  COP0_INT_IN           , //
    
    output        CORE_EXC_EN_OUT      	, //
    output  [1:0] CORE_EXC_CE_OUT       , // Cause register Co-Processor Error
    output  [4:0] CORE_EXC_CODE_OUT    	, // 
    output        CORE_EXC_BD_OUT      	, // 
    output [31:0] CORE_EXC_EPC_OUT     	, // 
    output [31:0] CORE_EXC_BADVA_OUT   	, // 
    input  [31:0] CORE_EXC_VECTOR_IN      // 
    
    );

`include "wb_defs.v"
`include "cpu_defs.v"
`include "cop0_defs.v"

   `ifndef FPGA
event 		  EndOfSim;
   `endif
   
   // ** Wire definitions **
   // Order: feedthrough wires, new data wires, control wires

   // IF Stage wires
   reg  [31:0] PcValIf;    // 
   reg  [31:0] LastPcValIf;

   reg         CoreInstCycReg;
   reg         CoreInstStbReg;

   
   // Registers to store an instruction fetch if the pipeline is stalled
   wire        CoreInstRdWhileStall;
   reg         CoreInstRdWhileStallId;
   reg [31:0]  CoreInstRdDataWhileStallId;
   
   // ID Stage wires
   wire [31:0] InstrId;
   wire [5:0]  InstrOpcId    = InstrId[OPC_HI : OPC_LO];
   wire [4:0]  InstrRtId     = InstrId[RT_HI : RT_LO];
   wire [4:0]  InstrRdId     = InstrId[RD_HI : RD_LO];
   wire [4:0]  InstrRsId     = InstrId[RS_HI : RS_LO];
   wire [5:0]  InstrFunctId  = InstrId[FUNCT_HI:FUNCT_LO];
   wire [25:0] InstrTargetId = InstrId[TARGET_HI:TARGET_LO];
   wire [4:0]  InstrCopzFn   = InstrId[COPz_HI:COPz_LO];
   wire [4:0]  InstrCop0Fn   = InstrId[CP0_FN_HI:CP0_FN_LO];
   wire [31:0] InstrSignXId  = {{16{InstrId[IMMED_HI]}} , InstrId[IMMED_HI:IMMED_LO]};
   wire [31:0] InstrZeroXId  = {{16{1'b0}} , InstrId[IMMED_HI:IMMED_LO]};
   reg  [31:0] PcValId;
   wire [31:0] PcValIncId;

   reg         CoreInstCycId;
   wire        CoreInstStb;

   wire        FixupCycle;
   reg         FixupCycleId;
   
   // Data Path (32 bit registers)
   wire [31:0] RegRsValId;
   wire [31:0] RegRtValId;
   reg  [31:0] RegRsValFwdId; // Forwarded register values
   reg  [31:0] RegRtValFwdId; // Forwarded register values
   reg  [31:0] ImmedExtId;
   reg  [31:0] JumpBranchPcId;
   
   // Pipeline control signals (ID)
   // Forwarding is now in the ID stage
   reg [31:0] RegArray [31:0];
   
   reg [1:0]   RegRsFwdId    ; // Select which part of pipeline to take Reg 1 from (forwarding)
   reg [1:0]   RegRtFwdId    ; // Select which part of pipeline to take Reg 2 from (forwarding)
   reg         AluSrcId      ; // 1 = ALU B input from immediate (lw/sw operation), 0 = ALU B from REG 2
   reg         RegDstId      ; // 1 = Result stored in register RD, 0 = result stored in register RT
   reg         BranchId      ; // Active high branch instruction
   reg         JumpId        ; // Active high jump instruction
   reg         MemReadId     ; // Active high memory read signal
   reg         MemWriteId    ; // Active high memory write signal
   reg  [1:0]  MemSizeId     ; // Byte Enables define width of memory access
   
   reg         UnsignedId    ; // Active high unsigned operation signal
   reg         MemToRegId    ; // 0 = Register Write Data from data memory, 1 = from ALU
   reg         RegWriteId    ; // Active high register write signal
   reg  [2:0]  AluOpId       ; // decoded ALU operation 
   reg         AluOpOvfEnId  ; // Does the ALU operation support the overflow exception ?
   reg  [2:0]  BranchCheckId ; // What to check to take branch
   reg         LinkId        ; // Active high link instruction control
   reg         Link31Id      ; // Indicates when a link instruction writes to reg 31
   reg         MultId        ; // Instruction is a multi-cycle multiply
   reg         DivId         ; // Instruction is a multi-cycle divide
   reg         MfloId        ; // MFLO instruction
   reg         MfhiId        ; // MFHI instruction
   reg         MtloId        ; // MTLO instruction
   reg         MthiId        ; // MTHI instruction
   wire        Cop0InstId    ; // COP0 Instruction 
   wire        Cop1InstId    ; // COP1 Instruction 
   wire        Cop2InstId    ; // COP2 Instruction 
   wire        Cop3InstId    ; // COP3 Instruction 

   reg         Cop0FnId       ; // COP0 function (only RFE currently)
   reg         Cop0RegWriteId ; // A COP0 register will be written (from MTC0, CTC0, LWC0)
   reg         Cop0CtrlSelId  ; // The COP0 register read / written will be a control reg
   reg         Cop0RegReadRdSelId; // 1 = read COP0 register RD, 0 = read COP0 register RT
   wire [4:0]  Cop0RdSelId    ; // COP 0 read register index
   reg 	       Cop0RegToRegId ; // Cop0 read reg writing to cpu reg
   reg 	       Cop0RegToMemId ; // Cop0 read reg writing to memory
   reg 	       Cop0MemToRegId ; // Cop0 memory read going to cop0 reg
   reg 	       Cop0RdEnId; // Cop0 read enable

   
   // EX Stage wires
   reg  signed [31:0] RegRsValEx;    // Reg 1 Value straight from ID -> EX reg
   reg  signed [31:0] RegRtValEx;    // Reg 2 Value straight from ID -> EX reg
   wire signed [31:0] RegRtValCop0Ex;    // Above signal muxed with COP0 read data
   wire signed [31:0] RegRtValMuxEx; // Reg 2 Value after immediate mux
   reg  signed [31:0] ImmedExtEx;

   reg         [ 4:0] InstrRtEx;
   reg         [ 4:0] InstrRdEx;
   
   wire        [31:0] ImmedExtShiftId;
   wire         [4:0] RegWrEx;       // Rt or Rd register according to instruction
   wire         [4:0] RegWrLinkEx;   // Rt, Rd, or reg 31 (for link instructions)
   reg  signed [31:0] AluResultEx;   // ALU calculation output 
   wire        [31:0] AluResultLinkEx; // MUXed ALU output or PC + 8 for link instructions
   wire        [31:0] AluResultLinkCop0Ex; // As above, muxed with COP0 read data
   
   
   wire        [31:0] PcValIncIncEx;
   reg                TakeBranchEx ; // Is the current branch taken?
   wire               PcSrcEx      ; // 1 = PC from branch / jump, 0 = PC + 4 PcValIncIf

   reg  [31:0] JumpBranchPcEx;

   // Pipeline control signals (EX)
   reg [31:0]  PcValEx    ; // Reg'd PcValId
   reg         AluSrcEx   ; // Reg'd AluSrcId
   reg         RegDstEx   ; // Reg'd RegDstId
   reg         BranchEx   ; // Reg'd BranchId
   reg         JumpEx     ; // Reg'd JumpId
   reg         MemReadEx  ; // Reg'd MemReadId
   reg         MemWriteEx ; // Reg'd MemWriteId
   reg  [1:0]  MemSizeEx  ; // Reg'd MemSizeId
   reg         UnsignedEx ; // Reg'd UnsignedId
   reg         MemToRegEx ; // Reg'd MemToRegId
   reg         RegWriteEx ; // Reg'd RegWriteId
   wire        RegWriteOvfEx ; // Do'nt write to a register on overflow !
   reg  [2:0]  AluOpEx    ; // Reg'd AluOpId
   reg         AluOpOvfEnEx ;
   reg  [2:0]  BranchCheckEx; // Reg'd BranchCheckId
   reg         LinkEx     ; // Reg'd LinkId   
   reg         Link31Ex   ; // Reg'd Link31Id 
   reg 	       DivEx      ; // Reg'd DivId
   reg         DivReq     ; // one-shot divide request
   wire        DivAck     ; // ACK for the divider
   reg         MultEx     ; // Reg'd MultId
   reg         MultReq  ; // one-shot Mult request
   wire        MultAck  ; // Acknowledge for above request
   reg         MfloEx     ; // Reg'd MfloId
   reg         MfhiEx     ; // Reg'd MfhiId
   reg         MtloEx     ; // Reg'd MtloId 
   reg         MthiEx     ; // Reg'd MthiId 
   reg         Cop0FnEx       ; // COP0 function (only RFE currently)
   reg         Cop0RegWriteEx ; // A COP0 register will be written (from MTC0, CTC0, LWC0)
   reg         Cop0CtrlSelEx  ; // The COP0 register read / written will be a control reg
   reg 	       Cop0RegToRegEx ;
   reg 	       Cop0RegToMemEx ;
   reg 	       Cop0MemToRegEx ;
   
   // Decode the CoreDataSel and CoreDataDatWr in the EX phase, then register in MEM phase
   reg [3:0]   CoreDataSelEx  ;
   reg [31:0]  CoreDataDatWrEx;
   
   // Multiply wires
   reg  [31:0] LoVal ;
   reg  [31:0] HiVal ;
   wire [63:0] MultResult;

   // Divider wires
   wire [31:0] DivQuotient;
   wire [31:0] DivRemainder;
   
   // MEM Stage wires
   reg [31:0]  PcValMem    ;
   reg  [31:0] AluResultMem;
   reg  [31:0] RegRtValMem;
   reg  [ 4:0] RegWrMem;
   wire [31:0] DmDataMem;       // DM data in 
   reg  [31:0] DmDataFormatMem; // DM data after sign extension / alignment
   reg  [31:0] ReadDataMem; // Read data can be from DM or HI/LO regs
   wire [31:0] BypassMem;       // Value in MEM stage to be bypassed
   
    // Pipeline control signals (MEM)  
   reg         BranchMem   ; // Reg'd BranchEx
   reg         JumpMem     ; // Reg'd JumpEx
   reg         MemReadMem  ; // Reg'd MemReadEx  
   reg         MemWriteMem ; // Reg'd MemWriteEx
   reg   [1:0] MemSizeMem  ; // Reg'd MemSizeEx  
   reg         UnsignedMem ; // Reg'd UnsignedEx
   reg         MemToRegMem ; // Reg'd MemToRegEx 
   reg         RegWriteMem ; // Reg'd RegWriteEx 
   reg         MfloMem     ; // Reg'd MfloEx
   reg         MfhiMem     ; // Reg'd MfhiEx
   reg         MtloMem     ; // Reg'd MtloEx
   reg         MthiMem     ; // Reg'd MthiEx
//   reg [3:0]   CoreDataSelMem  ; // Need to manipulate byte selects according to address and MEM_SIZE
//   reg [31:0]  CoreDataDatWrMem; // Also need to shift the outgoing data according to address and access size
   reg         Cop0RegWriteMem ; // A COP0 register will be written (from MTC0, CTC0, LWC0)
   reg         Cop0CtrlSelMem  ; // The COP0 register read / written will be a control reg
   reg 	       Cop0MemToRegMem ; // A COP0 register will be written from a memory load (LWCz)

   // Wishbone registered outputs
    reg [31:0] CoreDataAdrMem     ; 
    reg        CoreDataCycMem     ; 
    reg        CoreDataStbMem     ; 
    reg        CoreDataWeMem      ; 
    reg [ 3:0] CoreDataSelMem     ; 
//    reg [ 2:0] CoreDataCti     ;  <- static outputs (no burst accesses)
//    reg [ 1:0] CoreDataBte     ; 
    reg [31:0] CoreDataDatWrMem   ; 

   // Registers to store a read result if the pipeline is stalled
   wire        CoreDataRdWhileStall;
   reg         CoreDataRdWhileStallMem;
   reg [31:0]  CoreDataRdDataWhileStallMem ;
   
   
   // WB Stage wires
   reg [31:0]  AluResultWb;
   reg [31:0]  ReadDataWb;
   reg [ 4:0]  RegWrWb;
   reg [31:0]  RegRtValWb; // Used for COP0 register writes
   
   wire [31:0] WriteDataWb;

   // Pipeline control signals (WB)  
   reg [31:0]  PcValWb;
   reg         BranchWb   ; // Reg'd BranchMem
   reg         JumpWb     ; // Reg'd JumpMem
   reg         MemToRegWb ; // MemToRegMem
   reg         RegWriteWb ; // RegWriteMem
   reg         Cop0RegWriteWb ; // A COP0 register will be written (from MTC0, CTC0, LWC0)
   reg         Cop0CtrlSelWb  ; // The COP0 register read / written will be a control reg
   reg 	       Cop0MemToRegWb ; // A COP0 register will be written from a memory load (LWCz)


   // Interlock wires
//   wire IlockIf     ;
   wire IlockITMId  ;
   wire IlockICBId  ;
   wire IlockLDIId  ;
   wire IlockId     ;
   wire IlockMCIEx  ;
//   wire IlockCPIEx  ; <- not used ?
   wire IlockEx     ;
   wire IlockDCBMem ;
   wire IlockCOpMem ;
   wire IlockDCMMem ;
   wire IlockMem    ;
   wire IlockCP0IWb ;
   wire IlockWb     ;



   // Exceptions and wires -----
   wire       ExcIbeIf       ; // Instruction bus error
   wire       ExcAdelIf      ; // Instruction address error (load)
   wire       ExcSysId       ; // Syscall instruction
   wire       ExcBpId        ; // Breakpoint instruction
   wire       ExcRiId        ; // Reserved Instruction
   wire       ExcCpuId       ; // Co-processor unusable
   reg  [1:0] ExcCpuCeId     ; // Co-processor unusable ID
   wire       ExcIntEx       ; // External interrupt (from COP0 either SW or HW)
   reg        ExcOvfEx       ; // Arithmetic overflow exception
   wire       ExcAdelMem     ; // Address Error (load)
   wire       ExcAdesMem     ; // Address error (store)
   wire       ExcDbeMem      ; // Data bus error

   wire       ExcIf       ; // IF-stage exception summary
   wire       ExcId       ; // ID-stage exception summary
   wire       ExcEx       ; // EX-stage exception summary
   wire       ExcMem      ; // MEM-stage exception summary

   wire       Exc = ExcIf | ExcId | ExcEx | ExcMem;

   wire       ExcRstIf    ; // Reset these stages based on exceptions
   wire       ExcRstId    ;
   wire       ExcRstEx    ;
   wire       ExcRstMem   ;

   wire       ExcRegEn    ; // Register current exception
   
   // Exception storage and control -----
   reg [4:0]  ExcCode   ;
   reg [4:0]  ExcStage  ;
   reg [1:0]  ExcCpu    ;
   reg 	      ExcBd     ;
   reg [31:0] ExcPc     ;
   reg [31:0] ExcBadva  ;
   reg [4:0]  ExcPipe   ;

   reg [4:0]  ExcCodeReg   ; // CORE_EXC_CODE_OUT
   reg [4:0]  ExcStageReg  ; // (only used locally)
   reg [1:0]  ExcCpuCeReg  ; // CORE_EXC_CE_OUT
   reg 	      ExcBdReg     ; // CORE_EXC_BD_OUT
   reg [31:0] ExcPcReg     ; // CORE_EXC_PC_OUT
   reg [31:0] ExcBadvaReg  ; // CORE_EXC_BADVA_OUT

   
   //--------------------------------------------------------------------------
   // Exceptions
   //--------------------------------------------------------------------------
   // New approach to interlocks / slips. If any stage is interlocked, stall the entire pipeline
   // until the interlock releases. No bubble-insertion (slips)
   assign IlockITMId = 1'b0 ; // Instruction TLB Miss

   // Stall when either the instruction data hasn't been returned.
   // Stall the pipeline while the WB can't return the next instruction. The PC
   // value being sent out won't be updated until this signal goes low.
   // Also if an instruction is read while the pipeline is stalled, it's held
   // in a 32-bit register until the other stall is resolved.
   assign IlockICBId = ~CoreInstCycReg | (CoreInstCycReg & CORE_INST_STALL_IN); // Instruction Cache Busy

   // todo: Sort the LDI interlock out - compiler inserts NOP so it should be ok ..
   assign IlockLDIId = 1'b0; // (MemReadEx && ((RegWrLinkEx == InstrId[RS_HI:RS_LO]) || (RegWrLinkEx == InstrRtId))) ; // Load Interlock 
   assign IlockId    = IlockITMId | IlockICBId | IlockLDIId;    
   
   // Multi-Cycle Interlock
   assign IlockMCIEx  = ((MultReq | DivReq) & (MfloEx | MfhiEx | MtloEx | MthiEx));
   assign IlockEx     = IlockMCIEx;

   // Need to only interlock while the CYC is high for a data access.
   // otherwise if the INST WB is reading and stalled at the same time as
   // a data access, the DATA ACK can be missed and the pipeline locks up.
   assign IlockDCBMem  = (MemReadMem | MemWriteMem) 
                       & CoreDataCycMem & ~(CORE_DATA_ACK_IN | CORE_DATA_ERR_IN); // Data Cache Busy
   assign IlockCOpMem  = 1'b0 ; // Cache Op 
   assign IlockDCMMem  = 1'b0 ; // Data Cache Miss
   assign IlockMem     = IlockDCBMem |  IlockCOpMem | IlockDCMMem;
   
   assign IlockCP0IWb = 1'b0 ; // CP0 Bypass Interlock
   assign IlockWb     = IlockCP0IWb;

   // Stall if any stage is interlocked
   assign Stall = IlockId | IlockEx | IlockMem | IlockWb;

   //--------------------------------------------------------------------------
   // Exceptions
   //--------------------------------------------------------------------------

   assign ExcIbeIf   = CORE_INST_ERR_IN         ; // Error signalled by Inst slave
   assign ExcAdelIf  = | CORE_INST_ADR_OUT[1:0] ; // Unaligned address (always 32 bit loads)
   assign ExcSysId   = (OPC_SPECIAL == InstrOpcId) & (FUNCT_SYSCALL == InstrFunctId);
   assign ExcBpId    = (OPC_SPECIAL == InstrOpcId) & (FUNCT_BREAK   == InstrFunctId);
   assign ExcRiId    = ( (  (InstrId[31:28] == 4'b0101   ) // 4 to the right of COPx
			 || (InstrId[31:29] == 3'b011    ) // row under COP instructions
			 || (InstrId[31:26] == 6'b100111 ) // right of LWx
			 || (InstrId[31:27] == 5'b10110  ) // two in middle of SW
			 || (InstrId[31:26] == 6'b101111 ) // one on right of SWR
//			 || (InstrId[31:26] == 6'b110000 ) // left of LWCx <- This is LWC0 !
			 || (InstrId[31:28] == 4'b1101   ) // right of LWCx
//			 || (InstrId[31:26] == 6'b111000 ) // left of SWCx <- This is SWC0 !
			 || (InstrId[31:28] == 4'b1111   ) // right of SWCx
                         )
			  
                       || ((OPC_SPECIAL == InstrOpcId) &&
			     (   (InstrFunctId[5:0] == 6'b000001 ) // in between SLL and SRL
			      || (InstrFunctId[5:0] == 6'b000101 ) // in between SLLV and SRLV
			      || (InstrFunctId[5:1] == 5'b00101  ) // in between JALR & SYSCALL
			      || (InstrFunctId[5:2] == 4'b0101   ) // right of mults
			      || (InstrFunctId[5:2] == 4'b0111   ) // right of divs
			      || (InstrFunctId[5:1] == 5'b10100  ) // left of slt
			      || (InstrFunctId[5:2] == 4'b1011   ) // right of slt
			      || (InstrFunctId[5:3] == 3'b110    ) // blank line
			      || (InstrFunctId[5:3] == 3'b111    ) // blank line
			  )  )
			);
   
   assign ExcCpuId   = (   (Cop0InstId & ~COP_USABLE_IN[0])
                        || (Cop1InstId & ~COP_USABLE_IN[1])
                        || (Cop2InstId & ~COP_USABLE_IN[2])
                        || (Cop3InstId & ~COP_USABLE_IN[3])
			   );
   // Level interrupt but only have exception active for 1 cycle
   assign ExcIntEx   = COP0_INT_IN & ~ExcStageReg[EXC_STAGE_EX] & ~(ExcCodeReg != 5'd0);
   
   assign ExcAdelMem = (      MemReadMem & 
		        (   ((MEM_SIZE_WORD == MemSizeMem) & (| AluResultMem[1:0])) 
			  | ((MEM_SIZE_HALF == MemSizeMem) & (AluResultMem[0])))
		       );
   assign ExcAdesMem = (      MemWriteMem & 
		        (   ((MEM_SIZE_WORD == MemSizeMem) & (| AluResultMem[1:0])) 
			  | ((MEM_SIZE_HALF == MemSizeMem) & (AluResultMem[0])))
		       );
   assign ExcDbeMem  = CORE_DATA_ERR_IN;

   // Summarise stage exceptions

   assign ExcIf    = ExcIbeIf 	| ExcAdelIf;
   assign ExcId    = ExcSysId 	| ExcBpId    | ExcRiId | ExcCpuId;
   assign ExcEx    = ExcIntEx 	| ExcOvfEx;
   assign ExcMem   = ExcAdelMem | ExcAdesMem | ExcDbeMem ;

   assign ExcRstIf  = ExcIf  | ExcStageReg[EXC_STAGE_IF ] ;
   assign ExcRstId  = ExcId  | ExcStageReg[EXC_STAGE_ID ] ;
   assign ExcRstEx  = ExcEx  | ExcStageReg[EXC_STAGE_EX ] ;
   assign ExcRstMem = ExcMem | ExcStageReg[EXC_STAGE_MEM] ;

   // Only register the exception values for one cycle when pipe is 0
   assign ExcRegEn = ExcIf | ExcId | ExcEx | ExcMem & (5'h00 == ExcPipe);

   //--------------------------------------------------------------------------
   // External port assigns
   //--------------------------------------------------------------------------
   // Instruction request interface over WB
   assign CORE_INST_ADR_OUT    = PcValIf & ~({32{RST_SYNC}});
   assign CORE_INST_CYC_OUT    = CoreInstCycReg;
   assign CORE_INST_STB_OUT    = CoreInstStb;

   // Static signals (used for burst, write, etc)
   assign CORE_INST_WE_OUT     = 1'b0             ; // read-only
   assign CORE_INST_SEL_OUT    = 4'b1111          ; // 32-bit only
   assign CORE_INST_CTI_OUT    = CTI_CLASSIC      ; // single accesses only
   assign CORE_INST_BTE_OUT    = BTE_LINEAR_BURST ;
   assign CORE_INST_DAT_WR_OUT = 32'h0000_0000    ;

   // Data read / write over Wishbone
   assign CORE_DATA_ADR_OUT    = CoreDataAdrMem   ;
   assign CORE_DATA_CYC_OUT    = CoreDataCycMem   ;
   assign CORE_DATA_STB_OUT    = CoreDataStbMem   ;
   assign CORE_DATA_WE_OUT     = CoreDataWeMem    ;
   assign CORE_DATA_SEL_OUT    = CoreDataSelMem   ;
   assign DmDataMem            = CoreDataRdWhileStallMem ? CoreDataRdDataWhileStallMem : CORE_DATA_DAT_RD_IN;
   assign CORE_DATA_DAT_WR_OUT = CoreDataDatWrMem ;

   // Data static signals (no burst)
   assign CORE_DATA_CTI_OUT    = CTI_CLASSIC; // single accesses only
   assign CORE_DATA_BTE_OUT    = BTE_LINEAR_BURST;

   // Exceptions
   assign CORE_EXC_EN_OUT     = ExcPipe[EXC_STAGE_WB] & ~Stall; // generate 1 cycle only
   assign CORE_EXC_CODE_OUT   = ExcCodeReg   ;
   assign CORE_EXC_CE_OUT     = ExcCpuCeReg  ;
   assign CORE_EXC_BD_OUT     = ExcBdReg     ;
   assign CORE_EXC_EPC_OUT    = ExcPcReg     ;
   assign CORE_EXC_BADVA_OUT  = ExcBadvaReg  ;

   // Co-processor 0
   assign COP0_INST_EN_OUT      = Cop0FnId       ;
   assign COP0_INST_OUT         = InstrCop0Fn    ;
   assign COP0_RD_EN_OUT        = Cop0RdEnId     ;
   assign COP0_RD_CTRL_SEL_OUT 	= Cop0CtrlSelId  ;
   assign COP0_RD_SEL_OUT      	= Cop0RdSelId    ;

   assign COP0_WR_EN_OUT       	= Cop0RegWriteWb & ~Stall; // Combine with stall for 1 cycle pulse
   assign COP0_WR_CTRL_SEL_OUT 	= Cop0CtrlSelWb  ;
   assign COP0_WR_SEL_OUT      	= RegWrWb        ;
   assign COP0_WR_DATA_OUT     	= Cop0MemToRegWb ? ReadDataWb : RegRtValWb     ;

  
   // -----------------------------------------------------------

   
   // Combinatorial assigns
   // **************************** IF Stage ****************************

   // Convert the instruction to a nop if an exception happens in decode.
   // Mux the incoming instruction from either the direct read data or 
   // a holding register which stores the value until the Stall de-asserts
   // and the pipeline is ready to use the instruction
   assign InstrId = ~{32{ExcStageReg[EXC_STAGE_ID]}} 
                    & (CoreInstRdWhileStallId ? CoreInstRdDataWhileStallId : 
                       CORE_INST_DAT_RD_IN);

   // A Fixup cycle is the cycle prior to the pipeline starting up. The Stall
   // will be high in this cycle (as the pipeline has no instruction data
   // ready to use), so check all the stall sources APART FROM the IlockId.
   // If those aren't asserted, the pipeline can re-start.
   assign FixupCycle = ~RST_SYNC & ~CoreInstCycReg & ~CORE_INST_STALL_IN
                       & ~(IlockEx | IlockMem | IlockWb);
      
   // CYC register
   always @(posedge CLK)      
   begin
      if (RST_SYNC) //  || (ExcRstIf && !Stall))
      begin
         CoreInstCycReg    <= 1'b0;
      end
      else
      begin

         // 1st priority is to assert the CYC for instructions on a fixup cycle.
         // FixupCycle is always asserted when Stall is high, so fixup cycle logic
         // checks all stall sources apart from the Ilock ICB
         if (FixupCycle)
         begin
            CoreInstCycReg    <= 1'b1;
         end
         
         // SET When Stall is low, and CYC is low
         else if (!Stall && !CoreInstCycReg)
         begin
            CoreInstCycReg    <= 1'b1;
         end
         
         // CLR When an ACK comes back, and another Stall source is active
         else if (Stall && CoreInstCycReg && (CORE_INST_ACK_IN || CORE_INST_ERR_IN))
         begin
            CoreInstCycReg    <= 1'b0;
         end
      end
   end

   // STB has to be combinatorial, and de-asserted in the same cycle the ACK
   // comes back if an internal Stall is asserted. It can only be high when
   // the CYC is high
   assign CoreInstStb = CoreInstCycReg & 
                        ~(CORE_INST_ACK_IN & (IlockEx | IlockMem | IlockWb));

   // The FixupCycle signal acts as a set for the CYC register. On the cycle
   // after the FixupCycle, CYC and STB will be asserted. Unless the pipeline
   // is re-started with an instruction held in the CoreInstRdDataWhileStall 
   // holding registers, the pipeline will be running for 1 cycle before any
   // instruction data comes back. In this case clear all the Id->Ex signals
   always @(posedge CLK)      
   begin
      if (RST_SYNC)
      begin
         FixupCycleId    <= 1'b0;
      end
      else
      begin
         FixupCycleId <= FixupCycle;
      end
   end

   // Select the next PC from either the branch value or the next instruction
   always @*
   begin : PC_VAL_SEL

      PcValIf = 32'h0000_0000;

      // If there's an exception, or exception in the pipe, keep sending the
      // same address out. 
      if (Exc || (| ExcPipe[3:0]))
      begin
	 PcValIf = PcValId;
      end

      // Otherwise select the incremented value of branch/jump target as appropriate
      else
      begin
	 // if not stalled and an exception has reached the WB stage jump to vector
	 if (ExcPipe[EXC_STAGE_WB])
	 begin
	    PcValIf = CORE_EXC_VECTOR_IN;
	 end
	 else
	 begin
	    if (PcSrcEx)
	    begin
	       PcValIf = JumpBranchPcEx;
	    end
	    else
	    begin
	       PcValIf = PcValIncId;
	    end
	 end
      end
   end

   
   // **************************** ID Stage ****************************
   //

   // Add 4 to the PC to get the incremented value
   assign PcValIncId    = PcValId + 32'd4;

   // Select Reg 1 (RS), and Reg 2 (RT)
   assign RegRsValId  = RegArray[InstrRsId];
   assign RegRtValId  = RegArray[InstrRtId];
   
   // Sign extend the immediate value in ID phase
   assign ImmedExtShiftId = {ImmedExtId[29:0], 2'b00};

   // Decode whether the current instruction is for COP0, 1, 2, 3
   assign Cop0InstId =  (OPC_COP0 == InstrOpcId); 
   assign Cop1InstId = ((OPC_COP1 == InstrOpcId) || (OPC_LWC1 == InstrOpcId));
   assign Cop2InstId = ((OPC_COP2 == InstrOpcId) || (OPC_LWC2 == InstrOpcId));
   assign Cop3InstId = ((OPC_COP3 == InstrOpcId) || (OPC_LWC3 == InstrOpcId));

   // Select whether to read reg rd or rt from COP0
   assign Cop0RdSelId  = Cop0RegReadRdSelId ? InstrRdId : InstrRtId;

   // Need to register the read data returned while the pipeline is stalled
   assign CoreInstRdWhileStall = CORE_INST_CYC_OUT & Stall
                                 & (CORE_INST_ACK_IN | CORE_INST_ERR_IN);
   
   // **************************** EX Stage ****************************
   //

   assign PcValIncIncEx = PcValEx + 32'd8;
   assign RegRtValMuxEx = AluSrcEx ? ImmedExtEx : RegRtValEx;
   assign RegWrEx     = RegDstEx ? InstrRdEx : InstrRtEx; // Select Rd / Rt dest. reg
   assign RegWrLinkEx = Link31Ex ? 5'd31 : RegWrEx; // Select reg 31 for link instructions    
   assign PcSrcEx = (BranchEx & TakeBranchEx) | JumpEx;
   assign AluResultLinkEx = LinkEx ? PcValIncIncEx : AluResultEx;

   // COP0 read data for memory store / register store operations
   assign AluResultLinkCop0Ex = Cop0RegToRegEx ? COP0_RD_DATA_IN : AluResultLinkEx;
   assign RegRtValCop0Ex = Cop0RegToMemEx ? COP0_RD_DATA_IN : RegRtValEx;

   assign RegWriteOvfEx = RegWriteEx & ~ExcOvfEx; // Don't write to register on overflow .. 

   
   // **************************** MEM Stage ****************************
   //
   assign BypassMem = MemToRegMem ? ReadDataMem : AluResultMem;
   
   // **************************** WB Stage ****************************
   //
   assign WriteDataWb = MemToRegWb ? ReadDataWb : AluResultWb;

   // Processes
   /**************************************************************************/
   // ** IF Stage **
   // - Register the PC value (from current PC + 4 or jump / branch in EX stage)
   //   on the NEG edge of the clock. This gives half a cycle for the branch
   //   compare combinatorial logic in the EX stage to complete.
   // - Also register request to instruction mem / cache while not interlocked
   //**************************************************************************

   //**************************************************************************
   // ** ID Stage **
   //**************************************************************************
   // Register IF-stage signals into ID-stage
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         PcValId    <= PC_RST_VALUE; // Make sure the Id value for PC doesn't match the IF value when coming out of reset ..
     end

      // Freeze the instruction address if there's a stall active, or if an 
      // exception is being flushed through the pipe
      else if ((!Stall) || (ExcRstId && !ExcPipe[4]))
      begin
         PcValId      <= PcValIf;
      end
   end
  
   
   // When other stall sources are asserted, the ACK for the instruction can
   // come back when the Stall is high. In this case, register the fact this
   // happens (and clear when Stall is de-asserted).
   // Also store the instruction that was read back, switch InstrId mux over
   // to this value until the Stall de-asserts
   // Capture whether the data was returned during the stall
   always @(posedge CLK)
   begin : CORE_INST_RD_WHILE_STALL_REG
      if (RST_SYNC || !Stall)
      begin
         CoreInstRdWhileStallId <= 1'b0;
      end
      else if (CoreInstRdWhileStall)
      begin
         CoreInstRdWhileStallId <= 1'b1;
      end
   end

   // Capture the read data itself during a stall
   always @(posedge CLK)
   begin : CORE_INST_RD_DATA_WHILE_STALL_REG
      if (RST_SYNC || !Stall)
      begin
         CoreInstRdDataWhileStallId <= 32'h0000_0000;
      end
      else if (CoreInstRdWhileStall)
      begin
         CoreInstRdDataWhileStallId <= CORE_INST_DAT_RD_IN;
      end
   end


   // Generate the registers (note reg 0 is always 0 and can't be written)
   // N.B. Registers are written on a NEGATIVE clock edge, this allows the
   // same register to be written and read in the same clock cycle

   genvar regLoop;
   
   generate for (regLoop = 0 ; regLoop < 32 ; regLoop = regLoop + 1)
   begin : REG_GEN

      always @(negedge CLK)
      begin 
         
         if (RST_SYNC)
         begin
	    RegArray[regLoop] <= 32'h0000_0000;
         end
         
         else
         begin
	    // Don't overwrite reset value of 0 in Reg 0
	    if (RegWriteWb && (regLoop == RegWrWb) && (32'd0 != RegWrWb))
	    begin
               RegArray[regLoop] <= WriteDataWb;
	    end
         end
      end
      
   end
   endgenerate


   // Decode ExcCpuCeId based on 0 - 3 priority
   always @*
   begin : exc_cpu_ce_decode

      ExcCpuCeId = 2'b00;

      if (Cop0InstId & ~COP_USABLE_IN[0])
      begin
	 ExcCpuCeId = 2'b00;
      end
      else if (Cop1InstId & ~COP_USABLE_IN[1])
      begin
	 ExcCpuCeId = 2'b01;
      end
      else if (Cop2InstId & ~COP_USABLE_IN[2])
      begin
	 ExcCpuCeId = 2'b10;
      end
      else if (Cop3InstId & ~COP_USABLE_IN[3])
      begin
	 ExcCpuCeId = 2'b11;
      end
   end
   
   // FORWARDING: Detect forwarding for Reg 1
   always @*
   begin : FWD_1_DECODE
      
      RegRsFwdId = FWD_NONE;

      // EX has a higher priority than the MEM stage.
      // IF the EX instruction writes to a register
      //  AND the EX target register is the same as the ID target reg
      //  AND the EX target register isn't 0
      // THEN forward 
      if (RegWriteOvfEx                  
          && (InstrRsId == RegWrLinkEx)
          && (5'h00 != RegWrLinkEx))
      begin
         RegRsFwdId = FWD_EX;
      end

      // Same as above but for MEM stage
      else if (RegWriteMem                  
               && (InstrRsId == RegWrMem)
               && (5'h00 != RegWrMem))
      begin
         RegRsFwdId = FWD_MEM;
      end
   end

   // FORWARDING: Forward appropriate Reg 1 data to ALU
   always @*
   begin : FWD_1_MUX_ID
      RegRsValFwdId = 32'h0000_0000;

      case (RegRsFwdId)
        FWD_NONE : RegRsValFwdId = RegRsValId;
        FWD_EX   : RegRsValFwdId = AluResultLinkEx;
        FWD_MEM  : RegRsValFwdId = BypassMem;
      endcase // case (RegRsFwdId)
      
   end
   
   // FORWARDING: Detect forwarding for Reg 2
   always @*
   begin : FWD_2_DECODE_ID
      
      RegRtFwdId = FWD_NONE;

      // EX has higher priority than MEM
      if (RegWriteOvfEx                  
          && (InstrRtId == RegWrLinkEx)
          && (5'h00 != RegWrLinkEx))
      begin
         RegRtFwdId = FWD_EX;
      end 

      // MEM forwarding if current reg writing back is used by ALU and not 0
      else if (RegWriteMem                  
               && (InstrRtId == RegWrMem)
               && (5'h00 != RegWrMem))
      begin
           RegRtFwdId = FWD_MEM;
      end
   end
   
   // FORWARDING: Forward appropriate Reg 2 data to ALU
   always @*
   begin : FWD_2_MUX
      RegRtValFwdId = 32'h0000_0000;

      case (RegRtFwdId)
        FWD_NONE : RegRtValFwdId = RegRtValId;
        FWD_EX   : RegRtValFwdId = AluResultLinkEx;
        FWD_MEM  : RegRtValFwdId = BypassMem;
      endcase // case (RegRtFwdId)
      
   end
   
   // Choose whether to sign extend or zero extend the immediate
   // Almost all the I-type instructions use sign extension, apart
   // from the logical-type ones 
   always @*
   begin : IMMED_EXT_ID_DECODE

      ImmedExtId = InstrSignXId;
      
      if (    (OPC_ANDI   == InstrOpcId)
           || (OPC_ORI    == InstrOpcId)
           || (OPC_XORI   == InstrOpcId)
              )
      begin
         ImmedExtId = InstrZeroXId;
      end
   end

   // Decode the jump / jump reg / branch pc value
   // Calculate the PC due to a branch / jump. 
   // Branch: ADD 18 bit (16-bit immediate shifted left twice) to incremented PC
   // Jump: 26-bit offset shifted left by 2, with top 4 bits from incremented PC
   // Jump Reg: Use register value directly (doesn't depend on PC)
   always @*
   begin : JUMP_BRANCH_PC_ID_DECODE
      JumpBranchPcId = 32'h0000_0000;

      if (BranchId)
      begin
         JumpBranchPcId = PcValIncId + ImmedExtShiftId;
      end
      
      else if (JumpId)
      begin
         // Must be reg jump, take PC directly from register (JR, JALR)
         if (OPC_SPECIAL == InstrOpcId)
         begin
            JumpBranchPcId = RegRsValFwdId;
         end

         // Normal jump, shift and concatenate target with incremented PC, (J, JAL)
         else
         begin
            JumpBranchPcId = {PcValIncId[31:28], InstrTargetId, 2'b00};
         end
      end
   end
   
   // Instruction decode into ID-stage control signals
   always @*
   begin : ALU_SRC_ID_DECODE
      // Default values
      AluSrcId = 1'b0;

      // AluSrc selects whether the second input to the ALU comes from Register
      // 2 (if an R-type instruction) or the sign-extended immediate
      // in the intruction itself (an I-type instruction).
      // so we want it to be 1 where the instruction is an I-type, and the ALU is 
      // required (so not on a branch instruction)
      
      if (    (OPC_ADDI   == InstrOpcId)
           || (OPC_ADDIU  == InstrOpcId)
           || (OPC_SLTI   == InstrOpcId)
           || (OPC_SLTIU  == InstrOpcId)
           || (OPC_ANDI   == InstrOpcId)
           || (OPC_ORI    == InstrOpcId)
           || (OPC_XORI   == InstrOpcId)
           || (OPC_LUI    == InstrOpcId)
           || (OPC_LB     == InstrOpcId)
           || (OPC_LH     == InstrOpcId)
           || (OPC_LWL    == InstrOpcId)
           || (OPC_LW     == InstrOpcId)
           || (OPC_LBU    == InstrOpcId)
           || (OPC_LHU    == InstrOpcId)
           || (OPC_LWR    == InstrOpcId)
           || (OPC_SB     == InstrOpcId)
           || (OPC_SH     == InstrOpcId)
           || (OPC_SWL    == InstrOpcId)
           || (OPC_SW     == InstrOpcId)
           || (OPC_SWR    == InstrOpcId)
             )
      begin
         AluSrcId = 1'b1;
      end

   end


   always @*
   begin : ALU_OP_DECODE

      // Default to add operation for branch, jump, and COPz instructions
      AluOpId = ALU_OP_ADD;

      begin
         case (InstrOpcId)
           OPC_SPECIAL  : AluOpId = ALU_OP_SPECIAL;
           OPC_ADDI     : AluOpId = ALU_OP_ADD;
           OPC_ADDIU    : AluOpId = ALU_OP_ADD;
           OPC_SLTI     : AluOpId = ALU_OP_SLT; 
           OPC_SLTIU    : AluOpId = ALU_OP_SLTU;
           OPC_ANDI     : AluOpId = ALU_OP_AND;
           OPC_ORI      : AluOpId = ALU_OP_OR ;
           OPC_XORI     : AluOpId = ALU_OP_XOR;
           OPC_LUI      : AluOpId = ALU_OP_LUI;
           OPC_LB       : AluOpId = ALU_OP_ADD;
           OPC_LH       : AluOpId = ALU_OP_ADD; 
           OPC_LWL      : AluOpId = ALU_OP_ADD; 
           OPC_LW       : AluOpId = ALU_OP_ADD; 
           OPC_LBU      : AluOpId = ALU_OP_ADD; 
           OPC_LHU      : AluOpId = ALU_OP_ADD; 
           OPC_LWR      : AluOpId = ALU_OP_ADD; 
           OPC_SB       : AluOpId = ALU_OP_ADD; 
           OPC_SH       : AluOpId = ALU_OP_ADD; 
           OPC_SWL      : AluOpId = ALU_OP_ADD; 
           OPC_SW       : AluOpId = ALU_OP_ADD; 
           OPC_SWR      : AluOpId = ALU_OP_ADD; 
           OPC_LWC1     : AluOpId = ALU_OP_ADD; 
           OPC_LWC2     : AluOpId = ALU_OP_ADD; 
           OPC_LWC3     : AluOpId = ALU_OP_ADD; 
           OPC_SWC1     : AluOpId = ALU_OP_ADD; 
           OPC_SWC2     : AluOpId = ALU_OP_ADD; 
           OPC_SWC3     : AluOpId = ALU_OP_ADD; 
         endcase // case (InstrOpcId)
      end
   end


   // Does the ALU operation support an overflow exception? 
   // check for ADD, ADDI, SUB. Don't store result on overflow..
   always @*
   begin : ALU_OP_OVF_DECODE

      AluOpOvfEnId = 1'b0;

      if ( (OPC_ADDI == InstrOpcId)
	   || ( (OPC_SPECIAL == InstrOpcId) && (FUNCT_ADD == InstrFunctId) )
	   || ( (OPC_SPECIAL == InstrOpcId) && (FUNCT_SUB == InstrFunctId) )
	 )
      begin
	 AluOpOvfEnId = 1'b1;
      end
   end
   
   
   always @*
   begin : BRANCH_CHECK_ID_DECODE
      // Default values
      BranchCheckId = 3'h0;

      // REGIMM encoding is in rt field
      if (OPC_REGIMM == InstrOpcId)
      begin
         case (InstrRtId)
           REGIMM_BLTZ    : BranchCheckId = BRANCH_RS_LTZ    ;
           REGIMM_BGEZ    : BranchCheckId = BRANCH_RS_GEZ    ;
           REGIMM_BLTZAL  : BranchCheckId = BRANCH_RS_LTZ    ;
           REGIMM_BGEZAL  : BranchCheckId = BRANCH_RS_GEZ    ;
         endcase
      end
      
      else 
      begin
         case (InstrOpcId)
           OPC_BEQ        : BranchCheckId = BRANCH_RS_EQ_RT  ;
           OPC_BNE        : BranchCheckId = BRANCH_RS_NEQ_RT ;
           OPC_BLEZ       : BranchCheckId = BRANCH_RS_LEZ    ;
           OPC_BGTZ       : BranchCheckId = BRANCH_RS_GTZ    ;
         endcase 
      end
   end

   always @*
   begin : REG_DST_ID_DECODE

      // Default values
      RegDstId = 1'b0;

      // RegDst controls which register the result of the instruction is written
      // back to. For Rtype instructions this is specified in the RD field,
      // and for I-type instructions it is in the RT field as bottom 16 bits
      // are the immediate value itself

      // So = 1 for R-format, = 0 for others
      if (OPC_SPECIAL == InstrOpcId)
      begin
         RegDstId = 1'b1;
      end

      // Also COP0 instructions MTCz and CTCz store in COP0's rd register. Note we can't use the 
      // Cop0RegWriteId signal directly because this is high for LWC which stores the data in COP0 register 'rt'
      else if ((OPC_COP0 == InstrOpcId) && ((COPz_MT == InstrCopzFn) || (COPz_CT == InstrCopzFn)))
      begin
         RegDstId = 1'b1;
      end
   end


   always @*
   begin : BRANCH_ID_DECODE

      // Default values
      BranchId = 1'b0;

      // This Branch check is used in the MEM stage to select a branch instruction
      if (    (OPC_BEQ    == InstrOpcId)
          ||  (OPC_BNE    == InstrOpcId)
          ||  (OPC_BLEZ   == InstrOpcId)
          ||  (OPC_BGTZ   == InstrOpcId)
          || ((OPC_REGIMM == InstrOpcId) && (REGIMM_BLTZ   == InstrRtId))
          || ((OPC_REGIMM == InstrOpcId) && (REGIMM_BGEZ   == InstrRtId))
          || ((OPC_REGIMM == InstrOpcId) && (REGIMM_BLTZAL == InstrRtId))
          || ((OPC_REGIMM == InstrOpcId) && (REGIMM_BGEZAL == InstrRtId))
          )
      begin
         BranchId = 1'b1;
      end
      
   end

   always @*
   begin : JUMP_ID_DECODE

      // Default values
      JumpId = 1'b0;

      // Set high if a jump instruction is used
      if (   (OPC_J        == InstrOpcId)
          || (OPC_JAL      == InstrOpcId)
          || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_JR   == InstrFunctId))
          || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_JALR == InstrFunctId))            
          )
      begin
         JumpId = 1'b1;
      end
      
   end

   // Decode LinkId when the instruction uses a link 
   always @*
   begin : LINK_ID_DECODE
      LinkId = 1'b0;
      if (       (OPC_JAL     == InstrOpcId)
             || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_JALR == InstrFunctId)) 
             || ((OPC_REGIMM  == InstrOpcId) && (REGIMM_BLTZAL == InstrRtId)) 
             || ((OPC_REGIMM  == InstrOpcId) && (REGIMM_BGEZAL == InstrRtId)) 
          )
      begin
         LinkId = 1'b1;
      end
   end
   
   // Decode Link31Id for link instr. which stores to reg 31
   always @*
   begin : LINK_31_ID_DECODE
      Link31Id = 1'b0;
      if (       (OPC_JAL     == InstrOpcId)
             || ((OPC_REGIMM  == InstrOpcId) && (REGIMM_BLTZAL == InstrRtId)) 
             || ((OPC_REGIMM  == InstrOpcId) && (REGIMM_BGEZAL == InstrRtId)) 
          )
      begin
         Link31Id = 1'b1;
      end
   end

   // Decode a divide instruction to the divider
   always @*
   begin : DIV_ID_DECODE
      DivId = 1'b0;

      if (    ((OPC_SPECIAL == InstrOpcId) && (FUNCT_DIV  == InstrFunctId))
           || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_DIVU == InstrFunctId))
           )
      begin
         DivId = 1'b1;
      end
   end

   // Decode whether current instruction is a multiply
   always @*
   begin : MULT_ID_DECODE
      MultId = 1'b0;

      if (    ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MULT  == InstrFunctId))
           || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MULTU == InstrFunctId))
           )
      begin
         MultId = 1'b1;
      end
   end

   // Set Mflo high for MFLO instruction
   always @*
   begin : MFLO_ID_DECODE
      MfloId = 1'b0;

      if ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MFLO  == InstrFunctId))
      begin
         MfloId = 1'b1;
      end
   end

   // Set Mfhi high for MFHI instruction
   always @*
   begin : MFHI_ID_DECODE
      MfhiId = 1'b0;

      if ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MFHI  == InstrFunctId))
      begin
         MfhiId = 1'b1;
      end
   end

   // Set Mtlo high for MTLO instruction
   always @*
   begin : MTLO_ID_DECODE
      MtloId = 1'b0;

      if ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MTLO  == InstrFunctId))
      begin
         MtloId = 1'b1;
      end
   end

   // Set MtHi high for MTHI instruction
   always @*
   begin : MTHI_ID_DECODE
      MthiId = 1'b0;

      if ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MTHI  == InstrFunctId))
      begin
         MthiId = 1'b1;
      end
   end

   always @*
   begin : MEM_READ_DECODE

      // Default values
      MemReadId = 1'b0;

      // This is passed to the MEM stage, and used to select whether a memory
      // read is required. Only the "LOAD" instructions read from memory..

      if (   (OPC_LB  == InstrOpcId)
          || (OPC_LH  == InstrOpcId)
          || (OPC_LWL == InstrOpcId)
          || (OPC_LW  == InstrOpcId)
          || (OPC_LBU == InstrOpcId)
          || (OPC_LHU == InstrOpcId)
          || (OPC_LWR == InstrOpcId)
	  // LWC also reads from memory
	  || (OPC_LWC0 == InstrOpcId)
            )
      begin
         MemReadId = 1'b1;
      end
      
   end

   always @*
   begin : MEM_WRITE_DECODE

      // Default values
      MemWriteId = 1'b0;

      // This is used by the MEM stage of the pipeline to write a value back
      // to memory. Only STORE operations need this .. 
      if (   ( OPC_SB    == InstrOpcId)
          || ( OPC_SH    == InstrOpcId)
          || ( OPC_SWL   == InstrOpcId)
          || ( OPC_SW    == InstrOpcId)
          || ( OPC_SWR   == InstrOpcId)
	  // Also store on a SWC opcode
	  || ( OPC_SWC0  == InstrOpcId) 
             )
      begin
         MemWriteId = 1'b1;
      end

   end


   always @*
   begin : MEM_SIZE_DECODE

      // Default values
      MemSizeId = MEM_SIZE_NONE;

      // Decode the byte enable signal from the width of the operand
      case (InstrOpcId)
        OPC_LB    : MemSizeId = MEM_SIZE_BYTE;
        OPC_LH    : MemSizeId = MEM_SIZE_HALF;
        OPC_LW    : MemSizeId = MEM_SIZE_WORD;
        OPC_LBU   : MemSizeId = MEM_SIZE_BYTE; // todo implement zero-extension
        OPC_LHU   : MemSizeId = MEM_SIZE_HALF; // need a sign bit for all instructions
        OPC_SB    : MemSizeId = MEM_SIZE_BYTE;
        OPC_SH    : MemSizeId = MEM_SIZE_HALF;
        OPC_SW    : MemSizeId = MEM_SIZE_WORD;
// Unaligned memory accesses not supported
//        OPC_LWL   : ; 
//        OPC_LWR   : ;
//        OPC_SWL   : ;
//        OPC_SWR   : ;
	// Co-processor operations load a full word
	OPC_LWC0  : MemSizeId = MEM_SIZE_WORD;
	OPC_SWC0  : MemSizeId = MEM_SIZE_WORD;
        default: MemSizeId = MEM_SIZE_NONE;
      endcase // case (InstrOpcId)
   end
 
   // Decode whether an operation is unsigned or not. Note that this
   // isn't done for SPECIAL instructions as they encode the sign
   // in their function fields (ADD vs ADDU)
   always @*
   begin : UNSIGNED_DECODE
      UnsignedId = 1'b0;

      // Set to 1 if its a non-SPECIAL unsigned instruction
      // Todo remove extra ALU_OP parameter for an unsigned SLT and use this
      // one instead
      if (    (OPC_ADDIU == InstrOpcId)
           || (OPC_SLTIU == InstrOpcId)
           || (OPC_LBU   == InstrOpcId)
           || (OPC_LHU   == InstrOpcId)
	   // Also use Unsigned for signed/unsigned div and mult
	   || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_MULTU == InstrFunctId))
	   || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_DIVU  == InstrFunctId))
           )
      begin
         UnsignedId = 1'b1;
      end
   end
   
   always @*
   begin : MEM_TO_REG_DECODE

      // Default values
      MemToRegId = 1'b0;

      // This selects whether the value to be written back comes from the ALU
      // output of from memory. It's 0 for R-type instructions, and 1 for load
      // instructions or MFHI/MFLO instructions
      if (   (OPC_SPECIAL == InstrOpcId) && (FUNCT_MFLO  == InstrFunctId)
          || (OPC_SPECIAL == InstrOpcId) && (FUNCT_MFHI  == InstrFunctId)
          || (OPC_LB  == InstrOpcId)
          || (OPC_LH  == InstrOpcId)
          || (OPC_LWL == InstrOpcId)
          || (OPC_LW  == InstrOpcId)
          || (OPC_LBU == InstrOpcId)
          || (OPC_LHU == InstrOpcId)
          || (OPC_LWR == InstrOpcId)
	  // LWCs are also treated as loads
	  || (OPC_LWC0 == InstrOpcId)   
             )
      begin
         MemToRegId = 1'b1;
      end

   end

   always @*
   begin : REG_WRITE_ID_DECODE
      
      // Default values
      RegWriteId = 1'b0;

      // This value when high writes the WB stage value back to a register value.
      // This is high for all the R-types, and I-types apart from SW and branches
      // Also all link instructions write back to either reg 31 or JALR specified reg
      if (   (OPC_SPECIAL == InstrOpcId)
          // I-type writing back to a reg   
          || (OPC_ADDI    == InstrOpcId)
          || (OPC_ADDIU   == InstrOpcId)
          || (OPC_SLTI    == InstrOpcId)
          || (OPC_SLTIU   == InstrOpcId)
          || (OPC_ANDI    == InstrOpcId)
          || (OPC_ORI     == InstrOpcId)
          || (OPC_XORI    == InstrOpcId)
          || (OPC_LUI     == InstrOpcId)
          // Memory loads
          || (OPC_LB      == InstrOpcId)
          || (OPC_LH      == InstrOpcId)
          || (OPC_LWL     == InstrOpcId)
          || (OPC_LW      == InstrOpcId)
          || (OPC_LBU     == InstrOpcId)
          || (OPC_LHU     == InstrOpcId)
          || (OPC_LWR     == InstrOpcId)
          // Link instructions  
          || (OPC_JAL     == InstrOpcId)
          || ((OPC_SPECIAL == InstrOpcId) && (FUNCT_JALR == InstrFunctId)) 
          || ((OPC_REGIMM  == InstrOpcId) && (REGIMM_BLTZAL == InstrRtId)) 
          || ((OPC_REGIMM  == InstrOpcId) && (REGIMM_BGEZAL == InstrRtId)) 
	  // COP0 instructions which modify CPU regs
	  || (OPC_SWC0 == InstrOpcId)
	  || ((OPC_COP0 == InstrOpcId) && ((COPz_MF == InstrCopzFn) || (COPz_CF == InstrCopzFn)))
            )
      begin
         RegWriteId = 1'b1;
      end
   end

   // Decode when it is a specific COP0 instruction
   always @*
   begin : cop_fn_0_decode

      Cop0FnId = 1'b0;

      if ( (OPC_COP0 == InstrOpcId) && (InstrId[CP_SPECIFIC]) && (COP0_RFE ==  InstrCop0Fn) )
      begin
	 Cop0FnId = 1'b1;
      end
   end

   // Decode whether a COP0 register will be written from the current instruction. Could be:
   // LWC0, MTC0, or CTC0
   always @*
   begin : cop_0_reg_write_decode

      Cop0RegWriteId = 1'b0;

      if ( (OPC_LWC0 == InstrOpcId) 
	   || ((OPC_COP0 == InstrOpcId) && ((COPz_MT == InstrCopzFn) || (COPz_CT == InstrCopzFn))))
      begin
	 Cop0RegWriteId = 1'b1;
      end
   end

   // Decode whether the current COP0 instruction is for a control register
   always @*
   begin : cop_0_ctrl_sel_decode

      Cop0CtrlSelId = 1'b0;

      if ((OPC_COP0 == InstrOpcId) && ((COPz_CT == InstrCopzFn) || (COPz_CF == InstrCopzFn)))
      begin
	 Cop0CtrlSelId = 1'b1;
      end
   end

   // Decode whether the COP0 read reg index is Rd (MFCz, CFCz) or Rt (SWCz)
   always @*
   begin : cop_0_reg_read_rd_sel_decode

      Cop0RegReadRdSelId = 1'b0;

      if ((OPC_COP0 == InstrOpcId) && ((COPz_MF == InstrCopzFn) || (COPz_CF == InstrCopzFn)))
      begin
	 Cop0RegReadRdSelId = 1'b1;
      end
   end

   // Decode whether the Cop0 read register value is going to a CPU register (MFCz, CFCz)
   always @*
   begin : cop_0_reg_to_reg_decode

      Cop0RegToRegId = 1'b0;

      if ((OPC_COP0 == InstrOpcId) && ((COPz_MF == InstrCopzFn) || (COPz_CF == InstrCopzFn)))
      begin
	 Cop0RegToRegId = 1'b1;
      end
   end

   // Decode whether the Cop0 read register value is going to memory (a store). SWCz only.
   always @*
   begin : cop_0_reg_to_mem_decode

      Cop0RegToMemId = 1'b0;

      if (OPC_SWC0 == InstrOpcId)
      begin
	 Cop0RegToMemId = 1'b1;
      end
   end

   // Decode whether the Cop0 register write value is coming from a Memory read. LWCz only.
   always @*
   begin : cop_0_mem_to_reg_decode

      Cop0MemToRegId = 1'b0;

      if (OPC_LWC0 == InstrOpcId)
      begin
	 Cop0MemToRegId = 1'b1;
      end
   end

   // Send an read pulse to COP0 if you're reading its register (rd or rt).
   // Can be MFCz, CFCz, SWCz 
   always @*
   begin : cop_0_rd_en_decode

      Cop0RdEnId = 1'b0;

      if (    (OPC_SWC0 == InstrOpcId)
	  || ((OPC_COP0 == InstrOpcId) && ((COPz_MF == InstrCopzFn) || (COPz_CF == InstrCopzFn)))
	 )
      begin
	 Cop0RdEnId = 1'b1;
      end
   end
   
   //**************************************************************************
   // ** EX Stage **
   //**************************************************************************
   // Register the ID -> EX signals
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         // Data
         RegRsValEx     <= 32'h0000_0000;
         RegRtValEx     <= 32'h0000_0000;
         ImmedExtEx     <= 32'h0000_0000;
         InstrRtEx      <= 5'h00;
         InstrRdEx      <= 5'h00;
         JumpBranchPcEx <= PC_RST_VALUE; // When coming out of reset, jump to reset vector
         PcValEx        <= 32'h0000_0000;
         
         // Control
         AluSrcEx       <= 1'b0;
         RegDstEx       <= 1'b0;
         BranchEx       <= 1'b0;
         JumpEx         <= 1'b1; // When coming out of reset, jump to reset vector
         MemReadEx      <= 1'b0;
         MemWriteEx     <= 1'b0;
         MemSizeEx      <= 1'b0;
         UnsignedEx     <= 1'b0;
         MemToRegEx     <= 1'b0;
         RegWriteEx     <= 1'b0;
         AluOpEx        <= 3'b000;
	 AluOpOvfEnEx   <= 1'b0;
         BranchCheckEx  <= 3'b000;
         LinkEx         <= 1'b0;
         Link31Ex       <= 1'b0;
         DivEx          <= 1'b0;
         MultEx         <= 1'b0;
         MfloEx         <= 1'b0;
         MfhiEx         <= 1'b0;
         MtloEx         <= 1'b0;
         MthiEx         <= 1'b0;

	 Cop0FnEx       <= 1'b0;
	 Cop0RegWriteEx <= 1'b0;
	 Cop0CtrlSelEx  <= 1'b0;
	 Cop0RegToRegEx <= 1'b0;
	 Cop0RegToMemEx <= 1'b0;
         Cop0MemToRegEx <= 1'b0;

      end

      // Similar to a reset, but don't set a jump to the reset value !
      // Also if it's a fixup cycle without a stall, 
      // instruction isn't valid
      // Unless !! The instruction read while the rest of the pipeline
      // was stalled is stored in a register
      else if (ExcRstEx  || (~Stall && FixupCycleId && !CoreInstRdWhileStallId))
      begin
         // Data
         RegRsValEx     <= 32'h0000_0000;
         RegRtValEx     <= 32'h0000_0000;
         ImmedExtEx     <= 32'h0000_0000;
         InstrRtEx      <= 5'h00;
         InstrRdEx      <= 5'h00;
         JumpBranchPcEx <= 32'h0000_0000;
         PcValEx        <= 32'h0000_0000;
         
         // Control
         AluSrcEx       <= 1'b0;
         RegDstEx       <= 1'b0;
         BranchEx       <= 1'b0;
         JumpEx         <= 1'b0;
         MemReadEx      <= 1'b0;
         MemWriteEx     <= 1'b0;
         MemSizeEx      <= 1'b0;
         UnsignedEx     <= 1'b0;
         MemToRegEx     <= 1'b0;
         RegWriteEx     <= 1'b0;
         AluOpEx        <= 3'b000;
	 AluOpOvfEnEx   <= 1'b0;
         BranchCheckEx  <= 3'b000;
         LinkEx         <= 1'b0;
         Link31Ex       <= 1'b0;
         DivEx          <= 1'b0;
         MultEx         <= 1'b0;
         MfloEx         <= 1'b0;
         MfhiEx         <= 1'b0;
         MtloEx         <= 1'b0;
         MthiEx         <= 1'b0;

	 Cop0FnEx       <= 1'b0;
	 Cop0RegWriteEx <= 1'b0;
	 Cop0CtrlSelEx  <= 1'b0;
	 Cop0RegToRegEx <= 1'b0;
	 Cop0RegToMemEx <= 1'b0;
         Cop0MemToRegEx <= 1'b0;
         
      end // if (ExcRstEx)
      
      else
	 
         // Freeze the pipeline in the case of a stall
         if (!Stall)
         begin
            RegRsValEx       <= RegRsValFwdId;
            RegRtValEx       <= RegRtValFwdId;
            ImmedExtEx       <= ImmedExtId;
            InstrRtEx        <= InstrRtId;
            InstrRdEx        <= InstrRdId;
            JumpBranchPcEx   <= JumpBranchPcId;

	    PcValEx       <= PcValId;
            AluSrcEx      <= AluSrcId;
            RegDstEx      <= RegDstId;
            BranchEx      <= BranchId;
            JumpEx        <= JumpId;            
            MemReadEx     <= MemReadId;
            MemWriteEx    <= MemWriteId;
            MemSizeEx     <= MemSizeId;
            UnsignedEx    <= UnsignedId;
            MemToRegEx    <= MemToRegId;
            RegWriteEx    <= RegWriteId;
            AluOpEx       <= AluOpId;
	    AluOpOvfEnEx  <= AluOpOvfEnId;
            BranchCheckEx <= BranchCheckId;
            LinkEx        <= LinkId;
            Link31Ex      <= Link31Id;
            DivEx         <= DivId;
            MultEx        <= MultId;
            MfloEx        <= MfloId;
            MfhiEx        <= MfhiId;
            MtloEx        <= MtloId;
            MthiEx        <= MthiId;

	    Cop0FnEx       <= Cop0FnId       ;
	    Cop0RegWriteEx <= Cop0RegWriteId ;
	    Cop0CtrlSelEx  <= Cop0CtrlSelId  ;
	    Cop0RegToRegEx <= Cop0RegToRegId ;
	    Cop0RegToMemEx <= Cop0RegToMemId ;
	    Cop0MemToRegEx <= Cop0MemToRegId ;

         end
      end

   // Want to trigger a new multiply operation every time there is a MultId high
   // but only do one multiply regardless of whether the pipeline is stalled. If
   // this isn't one-shot, multiple multiplies are requested while the pipeline
   // is stalled for more than the x cycles it takes for a multiply
   // Note no pipeline stage suffix as these are outside the main pipeline flow
   always @(posedge CLK)
   begin : MULT_REQ_REG
      if (RST_SYNC)
      begin
         MultReq <= 1'b0;
      end
      // Release request when ACK comes back
      else if (MultAck)
      begin
         MultReq <= 1'b0;
      end
      // Request a new multiply in parallel to the MultEx pipe signal
      else if (!Stall && MultId)
      begin
         MultReq <= 1'b1;
      end
   end
      
   // Want to trigger a new divide in the same way as multiplies above. 
   // Note no pipeline stage suffix as these are outside the main pipeline flow
   always @(posedge CLK)
   begin : DIV_REQ_REG
      if (RST_SYNC)
      begin
         DivReq <= 1'b0;
      end
      // Release request when ACK comes back
      else if (DivAck)
      begin
         DivReq <= 1'b0;
      end
      // Request a new divide in parallel to the DivEx pipe signal
      else if (!Stall && DivId)
      begin
         DivReq <= 1'b1;
      end
   end
      
   
   // Branch calculation (1/2 cycle)
   always @*
   begin : TAKE_BRANCH_EX_DECODE
      TakeBranchEx = 1'b0;

      case (BranchCheckEx)
        BRANCH_RS_EQ_RT  : if (RegRsValEx == RegRtValMuxEx) TakeBranchEx = 1'b1;
        BRANCH_RS_NEQ_RT : if (RegRsValEx != RegRtValMuxEx) TakeBranchEx = 1'b1;
        BRANCH_RS_LTZ    : if (RegRsValEx < 0 ) TakeBranchEx = 1'b1;  
        BRANCH_RS_LEZ    : if (RegRsValEx <= 0) TakeBranchEx = 1'b1;
        BRANCH_RS_GTZ    : if (RegRsValEx > 0 ) TakeBranchEx = 1'b1;
        BRANCH_RS_GEZ    : if (RegRsValEx >= 0) TakeBranchEx = 1'b1;
      endcase // case (BranchCheckEx)
   end

   // ALU Calculation (1-cycle)
   always @*
   begin : ALU_CALC

      // Default values
      AluResultEx = 33'h0_0000_0000;

      // ALU Opcodes contained in alu_defs.v

      if      (ALU_OP_ADD     == AluOpEx)  AluResultEx =  RegRsValEx  +  RegRtValMuxEx ;
      else if (ALU_OP_SLT     == AluOpEx)  AluResultEx = (RegRsValEx  <  RegRtValMuxEx) ? 1'b1 : 1'b0;
      else if (ALU_OP_SLTU    == AluOpEx)  AluResultEx = ($unsigned(RegRsValEx)  <  $unsigned(RegRtValMuxEx)) ? 1'b1 : 1'b0;
      else if (ALU_OP_AND     == AluOpEx)  AluResultEx =  RegRsValEx  &  RegRtValMuxEx ; 
      else if (ALU_OP_OR      == AluOpEx)  AluResultEx =  RegRsValEx  |  RegRtValMuxEx ;
      else if (ALU_OP_XOR     == AluOpEx)  AluResultEx =  RegRsValEx  ^  RegRtValMuxEx ;
      else if (ALU_OP_LUI     == AluOpEx)  AluResultEx =  {RegRtValMuxEx, 16'h0000} ; 
      else if (ALU_OP_SPECIAL == AluOpEx)
      begin

         case (ImmedExtEx[FUNCT_HI:FUNCT_LO])
           (FUNCT_SLL      ) : AluResultEx = RegRtValMuxEx <<  ImmedExtEx[SA_HI:SA_LO];
           (FUNCT_SRL      ) : AluResultEx = RegRtValMuxEx >>  ImmedExtEx[SA_HI:SA_LO];
           (FUNCT_SRA      ) : AluResultEx = RegRtValMuxEx >>> ImmedExtEx[SA_HI:SA_LO]; // >>> gives sign ext.
           (FUNCT_SLLV     ) : AluResultEx = RegRtValMuxEx <<  RegRsValEx[4:0]; // only shift using bottom 5 bits
           (FUNCT_SRLV     ) : AluResultEx = RegRtValMuxEx >>  RegRsValEx[4:0];
           (FUNCT_SRAV     ) : AluResultEx = RegRtValMuxEx >>> RegRsValEx[4:0]; // >>> gives sign ext. only shift using bottom 5 bits
//           (FUNCT_SYSCALL  ) :  Not implemented
//           (FUNCT_BREAK    ) :
           (FUNCT_MTHI     ) : AluResultEx = RegRsValEx; // For MTHI / LO just want register Rs value to pass through to be written
           (FUNCT_MTLO     ) : AluResultEx = RegRsValEx;
           (FUNCT_ADD      ) : AluResultEx = RegRtValMuxEx +  RegRsValEx;
           (FUNCT_ADDU     ) : AluResultEx = RegRtValMuxEx +  RegRsValEx;
           (FUNCT_SUB      ) : AluResultEx = RegRsValEx -  RegRtValMuxEx;
           (FUNCT_SUBU     ) : AluResultEx = RegRsValEx -  RegRtValMuxEx;
           (FUNCT_AND      ) : AluResultEx = RegRtValMuxEx &  RegRsValEx;
           (FUNCT_OR       ) : AluResultEx = RegRtValMuxEx |  RegRsValEx; 
           (FUNCT_XOR      ) : AluResultEx = RegRtValMuxEx ^  RegRsValEx;
           (FUNCT_NOR      ) : AluResultEx = ~(RegRtValMuxEx | RegRsValEx);
           (FUNCT_SLT      ) : AluResultEx = RegRsValEx < RegRtValMuxEx ? 1'b1 : 1'b0;
           (FUNCT_SLTU     ) : AluResultEx = $unsigned(RegRsValEx) < $unsigned(RegRtValMuxEx) ? 1'b1 : 1'b0;
           default:  AluResultEx = 32'h0000_0000;
         endcase
      end
   end // block: ALU_CALC

   // Signed overflow occurs when the result has a different sign to both operands
   // check for overflow exception (tricky to do in one-line concurrent statement)
   always @*
   begin : ovf_exc_check
      
      ExcOvfEx = 1'b0;

      if (AluOpOvfEnEx)
      begin
	 
	 if (RegRsValEx[31] == RegRtValMuxEx[31])
	 begin
	    if (AluResultEx[31] != RegRsValEx[31])
	    begin
	       ExcOvfEx = 1'b1;
	    end
	 end
      end 
      
   end
   
   // Use the bottom two bits of the address along with the MEM_SIZE_* to generate the
   // appropriate byte enables. This has to be done in the EX part of the pipeline so
   // it's ready to be registered out of the core
   always @*
   begin : CORE_DATA_SEL_DECODE_EX

      CoreDataSelEx   = 4'b0000;
      CoreDataDatWrEx = 32'h0000_0000;
      
      if (MEM_SIZE_WORD == MemSizeEx )
      begin
	 CoreDataSelEx = 4'b1111;
	 CoreDataDatWrEx = RegRtValCop0Ex; // can store COP0 values to MEM, not just RegRtValEx;
      end

      else if (MEM_SIZE_HALF == MemSizeEx)
      begin
	 case (AluResultEx[1])
	   1'b1 : // Load upper 16 bits
	      begin
		 CoreDataSelEx   = 4'b1100;
		 CoreDataDatWrEx = {RegRtValCop0Ex[15:0], 16'h0000};
	      end
	   
	   1'b0 : // Load lower 16 bits
	      begin
		 CoreDataSelEx = 4'b0011;
		 CoreDataDatWrEx = {16'h0000, RegRtValCop0Ex[15:0]};
	      end
	 endcase	 
      end
      
      else if (MEM_SIZE_BYTE == MemSizeEx)
      begin
	 case (AluResultEx[1:0])
	   2'b11 : 
	      begin
		 CoreDataSelEx = 4'b1000; 
		 CoreDataDatWrEx = {RegRtValCop0Ex[7:0], 24'h000000};
	      end
	   2'b10 : 
	      begin
		 CoreDataSelEx = 4'b0100; 
		 CoreDataDatWrEx = {8'h00, RegRtValCop0Ex[7:0], 16'h0000};
	      end
	   2'b01 : 
	      begin
		 CoreDataSelEx = 4'b0010; 
		 CoreDataDatWrEx = {16'h0000, RegRtValCop0Ex[7:0], 8'h00};
	      end
	   2'b00 : 
	      begin
		 CoreDataSelEx = 4'b0001; 
		 CoreDataDatWrEx = {24'h000000, RegRtValCop0Ex[7:0]};
	      end
	 endcase	 
      end
   end

   //**************************************************************************



   //**************************************************************************
   // ** MEM Stage **
   //**************************************************************************
   // Register EX -> MEM
   always @(posedge CLK)
   begin
      if (RST_SYNC || (ExcRstMem && !Stall))
      begin
         // Data
         AluResultMem <= 32'h0000_0000;
         RegRtValMem  <= 32'h0000_0000;
         RegWrMem     <= 5'h00;
	 PcValMem     <= 32'h0000_0000;
	 
         // Control
         MemReadMem   <= 1'b0;
         MemWriteMem  <= 1'b0;
         MemSizeMem   <= 1'b0;
         UnsignedMem  <= 1'b0;
         MemToRegMem  <= 1'b0;
         RegWriteMem  <= 1'b0;
         MfloMem      <= 1'b0;
         MfhiMem      <= 1'b0;
         MtloMem      <= 1'b0;
         MthiMem      <= 1'b0;
         BranchMem    <= 1'b0;
         JumpMem      <= 1'b0;
	 Cop0RegWriteMem  <= 1'b0;
	 Cop0CtrlSelMem   <= 1'b0;
         Cop0MemToRegMem  <= 1'b0;
       end

      else if (!Stall)
      begin
         AluResultMem <= AluResultLinkCop0Ex;
         RegRtValMem  <= RegRtValCop0Ex;
         RegWrMem     <= RegWrLinkEx;
	 PcValMem     <= PcValEx;

         MemReadMem   <= MemReadEx;
         MemWriteMem  <= MemWriteEx;
         MemSizeMem   <= MemSizeEx;
         UnsignedMem  <= UnsignedEx;
         MemToRegMem  <= MemToRegEx;
         RegWriteMem  <= RegWriteOvfEx;
         MfloMem      <= MfloEx;
         MfhiMem      <= MfhiEx;
         MtloMem      <= MtloEx;
         MthiMem      <= MthiEx;       
         BranchMem    <= BranchEx;
         JumpMem      <= JumpEx  ;

	 Cop0RegWriteMem  <= Cop0RegWriteEx ;
	 Cop0CtrlSelMem   <= Cop0CtrlSelEx  ;
         Cop0MemToRegMem  <= Cop0MemToRegEx ;  

       end
   end // always @ (posedge CLK)

   // Wishbone Master to Slave signals (uses EX-stage signals to register the signals
   // coming out, and Wishbone inputs to de-assert address phase signals

   // CYC register. This is de-asserted when the ACK comes back
   // Note you can't use Stall as a sync enable because the stall is active
   // while waiting for the ACK to come back..
   always @(posedge CLK)
   begin
      if (RST_SYNC || (ExcRstMem && !Stall))
      begin
         CoreDataCycMem    <= 1'b0;
      end
      else // if (!Stall)
      begin
         if (!Stall && (MemReadEx || MemWriteEx))
         begin
            CoreDataCycMem    <= 1'b1;
         end
         else if (CoreDataCycMem && (CORE_DATA_ACK_IN || CORE_DATA_ERR_IN))
         begin
            CoreDataCycMem    <= 1'b0;
         end
      end
   end

   // STB register. This is de-asserted synchronously when STALL is low.
   // Note you can't use Stall as a sync enable because the stall is active
   // while waiting for the ACK to come back..
   always @(posedge CLK)
   begin
      if (RST_SYNC || (ExcRstMem && !Stall))
      begin
         CoreDataStbMem    <= 1'b0;
      end
      else //  if (!Stall)
      begin
         if (!Stall && (MemReadEx || MemWriteEx))
         begin
            CoreDataStbMem    <= 1'b1;
         end
         else if (CoreDataStbMem && !CORE_DATA_STALL_IN)
         begin
            CoreDataStbMem    <= 1'b0;
         end
      end
   end

   // Bus Address-Phase registers. These are updated on a new transaction
   always @(posedge CLK)
   begin
      if (RST_SYNC || (ExcRstMem && !Stall))
      begin
         CoreDataAdrMem    <= 32'h0000_0000;
         CoreDataWeMem     <= 1'b0;
         CoreDataSelMem    <= 4'b000;
         CoreDataDatWrMem  <= 32'h0000_0000;
      end
      else if (!Stall)
      begin
         if (MemReadEx || MemWriteEx)
         begin
            CoreDataAdrMem    <= {AluResultEx[31:2], 2'b00};
            CoreDataWeMem     <= MemWriteEx;
            CoreDataSelMem    <= CoreDataSelEx;
            CoreDataDatWrMem  <= CoreDataDatWrEx;
         end
      end
   end

   // Extra couple of always blocks to hold the Read Data if the pipeline is
   // stalled when the ACK comes back for read data. In this case, the read
   // data can disappear before the Stall is de-asserted, and the wrong
   // read data is written into the destination register

   assign CoreDataRdWhileStall = Stall & MemReadMem & (CORE_DATA_ACK_IN | CORE_DATA_ERR_IN);

   // SR Flop to store whether an ACK happened while reading data back and
   // the pipeline was stalled.
   always @(posedge CLK)
   begin : CORE_DATA_ACK_WHILE_STALLED_REG
      if (RST_SYNC || !Stall)
      begin
         CoreDataRdWhileStallMem <= 1'b0;
      end
      else if (CoreDataRdWhileStall)
      begin
         CoreDataRdWhileStallMem <= 1'b1;
      end
   end

   // Register the read data if the pipeline is currently stalled
   always @(posedge CLK)
   begin : CORE_READ_DATA_REG_WHILE_STALLED_REG
      if (RST_SYNC || !Stall)
      begin
         CoreDataRdDataWhileStallMem <= 32'h0000_0000;
      end
      else if (CoreDataRdWhileStall)
      begin
         CoreDataRdDataWhileStallMem <= CORE_DATA_DAT_RD_IN;
      end
   end
   
   // Align and sign extend the data read from memory. Note this uses
   // little endian .. 
   always @*
   begin : CORE_DATA_FORMAT
      DmDataFormatMem = 32'h0000_0000;

      // No alignement / extension needed for a word transaction
      if (MEM_SIZE_WORD == MemSizeMem)   DmDataFormatMem = DmDataMem;
      
      // Zero-extend if less than a word and unsigned operation
      else if (UnsignedMem)
      begin
         if (MEM_SIZE_BYTE == MemSizeMem)      
	 begin
	    case (CoreDataSelMem)
	      4'b1000 : DmDataFormatMem = { {24{1'b0}} , DmDataMem[31:24]};
	      4'b0100 : DmDataFormatMem = { {24{1'b0}} , DmDataMem[23:16]};
	      4'b0010 : DmDataFormatMem = { {24{1'b0}} , DmDataMem[15: 8]};
	      4'b0001 : DmDataFormatMem = { {24{1'b0}} , DmDataMem[ 7: 0]};
	    endcase // case (CoreDataSel)
	 end
	 
         else if (MEM_SIZE_HALF == MemSizeMem) 
	 begin
	    case (CoreDataSelMem)
	      4'b1100 : DmDataFormatMem = { {16{1'b0}} , DmDataMem[31:16]};
	      4'b0011 : DmDataFormatMem = { {16{1'b0}} , DmDataMem[15: 0]};
	    endcase // case (CoreDataSel)
	 end
      end

      // Sign Extend these loads ..
      else
      begin
         if (MEM_SIZE_BYTE == MemSizeMem)      
	 begin
	    case (CoreDataSelMem)
	      4'b1000 : DmDataFormatMem = { {24{DmDataMem[31]}} , DmDataMem[31:24]};
	      4'b0100 : DmDataFormatMem = { {24{DmDataMem[23]}} , DmDataMem[23:16]};
	      4'b0010 : DmDataFormatMem = { {24{DmDataMem[15]}} , DmDataMem[15: 8]};
	      4'b0001 : DmDataFormatMem = { {24{DmDataMem[ 7]}} , DmDataMem[ 7: 0]};
	    endcase // case (CoreDataSel)
	 end
	 
         else if (MEM_SIZE_HALF == MemSizeMem) 
	 begin
	    case (CoreDataSelMem)
	      4'b1100 : DmDataFormatMem = { {16{DmDataMem[31]}} , DmDataMem[31:16]};
	      4'b0011 : DmDataFormatMem = { {16{DmDataMem[15]}} , DmDataMem[15: 0]};
	    endcase // case (CoreDataSel)
	 end
      end
   end
   
   // Select ReadDataMem depending on whether its a load, MFHI or MFLO.
   // Note MemToRegMem is high for MFLO, MFHI, and loads so prioritise MFLO and MFHI
   always @*
   begin : READ_DATA_MEM_SEL
      ReadDataMem = DmDataFormatMem; // ReadDataMem = 32'h0000_0000;

      if      (MfloMem)     ReadDataMem = LoVal;
      else if (MfhiMem)     ReadDataMem = HiVal;
//      else if (MemToRegMem) ReadDataMem = DmDataFormatMem; // load operation
   end   
   //**************************************************************************
   
   

   //**************************************************************************
   // ** WB Stage **
   //**************************************************************************
   // Register the MEM -> WB signals
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         // Data
         AluResultWb <= 32'h0000_0000; // Data memory still 32 bits despite 64 bit regs? todo
         ReadDataWb  <= 32'h0000_0000;
         RegWrWb     <= 32'h0000_0000;
	 PcValWb     <= 32'h0000_0000;
	 RegRtValWb  <= 32'h0000_0000;
         
         // Control
         MemToRegWb  <= 1'b0;
         RegWriteWb  <= 1'b0;
         BranchWb    <= 1'b0;
         JumpWb      <= 1'b0;
 
	 Cop0RegWriteWb  <= 1'b0;
	 Cop0CtrlSelWb   <= 1'b0;
         Cop0MemToRegWb  <= 1'b0;
     end

      else
      begin

	 // Freeze the pipeline
         if (!Stall)
         begin
	    // Data
            AluResultWb <= AluResultMem;
            ReadDataWb  <= ReadDataMem;
            RegWrWb     <= RegWrMem;
	    PcValWb     <= PcValMem;
	    RegRtValWb  <= RegRtValMem;
	    
            // Control
	    MemToRegWb  <= MemToRegMem;
            RegWriteWb  <= RegWriteMem;
            BranchWb    <= BranchMem;
            JumpWb      <= JumpMem;

	    Cop0RegWriteWb  <= Cop0RegWriteMem;
	    Cop0CtrlSelWb   <= Cop0CtrlSelMem;
            Cop0MemToRegWb  <= Cop0MemToRegMem;
            
         end
      end

      // No downstream pipe stages so it can't be stalled..
      
   end

  //**************************************************************************



   //**************************************************************************
   // ** Pipelined Multiplier & Divider **
   //**************************************************************************

   // Register to hold LO / HI values. 
   // These can be written by: MULT(U), DIV(U), MTHI, MTLO
   // These can be read by: MFLO, MFHI
   always @(posedge CLK)
   begin : LO_HI_REG
      if (RST_SYNC)
      begin
         LoVal = 32'h0000_0000;
         HiVal = 32'h0000_0000;
      end
      else
      begin
         // Multiplier has first priority over MTLO / MTHI
         if (MultReq & MultAck)
         begin
            LoVal = MultResult[31: 0];
            HiVal = MultResult[63:32];
         end
         else if (DivAck)
         begin
            LoVal = DivQuotient;
            HiVal = DivRemainder;
         end
         // todo: Note these HI/LO loads don't have any forwarding associated with them 
         // this is because the encoding used for MTHI/LO has the target register set to
         // 0 (and forwarding doesn't forward to 0 as there's no point).
         else if (MtloMem)
         begin
            LoVal = AluResultMem;
         end

         else if (MthiMem)
         begin
            HiVal = AluResultMem;
         end

      end
   end
   
 DIV div
   (
    .CLK                  (CLK             ),
    .RST_SYNC             (RST_SYNC        ),

    // Inputs
    .DIV_REQ_IN           (DivReq          ),
    .DIV_SIGNED_IN        (~UnsignedEx     ),
    
    .DIV_DIVIDEND_IN      (RegRsValEx      ),
    .DIV_DIVISOR_IN       (RegRtValMuxEx   ),

    .DIV_ACK_OUT          (DivAck          ),
    .DIV_QUOTIENT_OUT     (DivQuotient     ),   
    .DIV_REMAINDER_OUT    (DivRemainder    )     
    
    );

   MULT mult
   (
    .CLK                (CLK           ),
    .RST_SYNC           (RST_SYNC      ),

    .MULT_REQ_IN        (MultReq       ), // 2-phase REQ/ACK with REQ and RESULT_VALID_OUT
    .MULT_SIGNED_IN     (~UnsignedEx   ),
    
    .MULT_A_IN          (RegRsValEx    ),
    .MULT_B_IN          (RegRtValMuxEx ),

    .MULT_ACK_OUT       (MultAck       ),
    .MULT_RESULT_OUT    (MultResult    )
   
    );


   //**************************************************************************
   // ** Exceptions out to COP0 **
   //**************************************************************************

   // Exceptions in the latest stage of the pipeline have priority as follows:

   // AdEL Memory (Load instruction)  
   // AdES Memory (Store instruction)  
   // DBE Memory (Load or store)      
   // Int ALU                          
   // Ovf ALU                           
   // Sys RD (Instruction Decode)       
   // Bp RD (Instruction Decode)        
   // RI RD (Instruction Decode)      
   // CpU RD (Instruction Decode)
   // AdEL (Instruction Load)
   // IBE RD (end of I-Fetch)

   // ExcCode decode (can't use case as it's a priority encoder)
   always @*
   begin : exc_code_decode

      ExcCode = 5'h00;
      
      if      (ExcAdelMem)
      begin
	 ExcCode = EXC_CODE_ADEL;
      end
      else if (ExcAdesMem)
      begin
	 ExcCode = EXC_CODE_ADES;
      end
      else if (ExcDbeMem)
      begin
	 ExcCode = EXC_CODE_DBE;
      end
      else if (ExcOvfEx)
      begin
	 ExcCode = EXC_CODE_OVF;
      end
      else if (ExcIntEx)
      begin
	 ExcCode = EXC_CODE_INT;
      end
      else if (ExcSysId)
      begin
	 ExcCode = EXC_CODE_SYS;
      end
      else if (ExcBpId)
      begin
	 ExcCode = EXC_CODE_BP;
      end
      else if (ExcRiId)
      begin
	 ExcCode = EXC_CODE_RI;
      end
      else if (ExcCpuId)
      begin
	 ExcCode = EXC_CODE_CPU;
      end
      else if (ExcAdelIf)
      begin
	 ExcCode = EXC_CODE_ADEL;
      end
      else if (ExcIbeIf)
      begin
	 ExcCode = EXC_CODE_IBE;
      end      
   end
   
   // ExcStage decode (prioritise later stages)
   always @*
   begin : exc_stage_decode

      ExcStage = 5'h00;

      if      (ExcMem  ) ExcStage[EXC_STAGE_MEM] = 1'b1;
      else if (ExcEx   ) ExcStage[EXC_STAGE_EX ] = 1'b1;
      else if (ExcId   ) ExcStage[EXC_STAGE_ID ] = 1'b1;
      else if (ExcIf   ) ExcStage[EXC_STAGE_IF ] = 1'b1;
			           
   end

   // Branch Delay slot check. If the previous instruction was a jump
   // or branch then is must be .. 
   always @*
   begin : bd_bit_decode
      
      ExcBd = 1'b0;

      if      (ExcMem  ) ExcBd = (JumpWb  | BranchWb  );
      else if (ExcEx   ) ExcBd = (JumpMem | BranchMem );
      else if (ExcId   ) ExcBd = (JumpEx  | BranchEx  );
      else if (ExcIf   ) ExcBd = (JumpId  | BranchId  );
			           
   end

   // PC which caused the exception (store in COP0 register)
   always @*
   begin : exc_pc_decode

      
      ExcPc = 32'h0000_0000;

      if      (ExcMem  ) ExcPc = PcValMem ;
      else if (ExcEx   ) ExcPc = PcValEx  ;
      else if (ExcId   ) ExcPc = PcValId  ;
      else if (ExcIf   ) ExcPc = PcValIf  ;
			           
   end

   // PC which caused the exception (store in COP0 register)
   always @*
   begin : exc_badva_decode

      ExcBadva = 32'h0000_0000;

      if      (ExcMem  ) ExcBadva = AluResultMem;
      else if (ExcIf   ) ExcBadva = PcValIf;
			           
   end

   // ExcPipe pipeline
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
	 ExcPipe <= 5'h00;
      end
      // If an exception happens register which stage it's in.
      // ** Don't qualify with !Stall as this might happen on any cycle **
      // ** Qualify with pipe being 0 to load value in one cycle **
      else if (ExcRegEn)
      begin
	 ExcPipe <= 5'h00;
	 if      (ExcIf   ) ExcPipe[EXC_STAGE_IF ] <= 1'b1;
	 else if (ExcId   ) ExcPipe[EXC_STAGE_ID ] <= 1'b1;
	 else if (ExcEx   ) ExcPipe[EXC_STAGE_EX ] <= 1'b1;
	 else if (ExcMem  ) ExcPipe[EXC_STAGE_MEM] <= 1'b1;
      end
      // Clock the pipe to the WB stage (which causes the jump to CORE_EXC_VECTOR_IN)
      // ** Only advance a pipe stage when the flow isn't stalled **
      else if (!Stall)
      begin
	 ExcPipe[5:1] <= ExcPipe[4:0];
	 ExcPipe[0]   <= 1'b0;
      end
   end

   // Register the exception information in the cycle it happens
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
	 ExcCodeReg   <= 5'h00; 	// [4:0]  
	 ExcStageReg  <= 5'h00; 	// [4:0]  
	 ExcCpuCeReg  <= 2'b00; 	// [1:0]  
	 ExcBdReg     <= 1'b0;          // 	       
	 ExcPcReg     <= 32'h0000_0000; // [31:0] 
	 ExcBadvaReg  <= 32'h0000_0000; // [31:0] 
      end
      // Reset the values after it hits the WB stage
      // ** Only advance a pipe stage when the flow isn't stalled **
      else if (ExcPipe[4] && ~Stall)
      begin
	 ExcCodeReg   <= 5'h00; 	// [4:0]  
	 ExcStageReg  <= 5'h00; 	// [4:0]  
	 ExcCpuCeReg  <= 2'b00; 	// [1:0]  
	 ExcBdReg     <= 1'b0;          // 	       
	 ExcPcReg     <= 32'h0000_0000; // [31:0] 
	 ExcBadvaReg  <= 32'h0000_0000; // [31:0] 
      end
      // If an exception happens (and there isn't one in the pipe)
      // register which stage it's in. 
      // ** Don't qualify with !Stall as it can happen on any cycle where
      // pipeline isn't stalled **
      else if (ExcRegEn)
      begin
	 ExcCodeReg   <= ExcCode    ;
	 ExcStageReg  <= ExcStage   ;
	 ExcCpuCeReg  <= ExcCpuCeId ;
	 ExcBdReg     <= ExcBd      ; 
	 ExcPcReg     <= ExcPc      ;
	 ExcBadvaReg  <= ExcBadva   ;
      end
   end

   
endmodule
/*****************************************************************************/
