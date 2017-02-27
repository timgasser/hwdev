/* INSERT MODULE HEADER */


/*****************************************************************************/
module CPU_CORE_MONITOR 
   (

    input  CLK                   ,
    input  RST_SYNC              ,

    // Instruction Memory (Read only)
    input         CORE_INST_CYC_IN      , // Master: High while whole transfer is in progress
    input         CORE_INST_STB_IN      , // Master: High while the current beat in burst is active
    input [31:0]  CORE_INST_ADR_IN      , // Master: Address of current transfer
    input         CORE_INST_ACK_IN      , // Slave:  Acknowledge of transaction
    input [31:0]  CORE_INST_DAT_RD_IN   , // Slave:  Read data
   
    // Data Memory (Read and Write)
    input         CORE_DATA_CYC_IN      , // Master: High while whole transfer is in progress
    input         CORE_DATA_STB_IN      , // Master: High while the current beat in burst is active
    input [31:0]  CORE_DATA_ADR_IN      , // Master: Address of current transfer
    input [ 3:0]  CORE_DATA_SEL_IN      , // Master: Byte enables of write (one-hot)
    input         CORE_DATA_WE_IN       , // Master: Write Enable (1), Read if 0
    input         CORE_DATA_ACK_IN      , // Slave:  Acknowledge of transaction
    input [31:0]  CORE_DATA_DAT_RD_IN   , // Slave:  Read data
    input [31:0]  CORE_DATA_DAT_WR_IN     // Master: Write data
   
    );


`define TESTSTR "code.hex"


`include "cpu_defs.v"


// Wire definitions
   wire [31:0] 	  Instr;
   wire [ 4:0] 	  InstrIndex;   // Index 32 instructions

   wire 	  DmCyc  ;
   wire 	  DmStb  ;
   wire [31:0] 	  DmAddr ;
   wire [ 3:0] 	  DmSel  ;
   wire 	  DmWe   ;

   wire [31:0] 	  DmWriteData  ;
   wire [31:0] 	  DmReadData   ;
   wire 	  DmReadEn     = DmCyc & DmStb & ~DmWe;
   wire 	  DmWriteEn    = DmCyc & DmStb &  DmWe;

   reg 		  TraceEnable;

   string 	  register_names [32] = '{ "$zero ",  "$at   ",  "$v0   ",  "$v1   ",
					   "$a0   ",  "$a1   ",  "$a2   ",  "$a3   ",
					   "$t0   ",  "$t1   ",  "$t2   ",  "$t3   ",   
					   "$t4   ",  "$t5   ",  "$t6   ",  "$t7   ",   
					   "$s0   ",  "$s1   ",  "$s2   ",  "$s3   ",   
					   "$s4   ",  "$s5   ",  "$s6   ",  "$s7   ",   
					   "$s8   ",  "$s9   ",  "$k0   ",  "$k1   ",   
					   "$gp   ",  "$sp   ",  "$fp   ",  "$ra   "
					   };

   integer 	  instrLog;
   integer 	  dataLog;	     
   integer 	  regsLog;	     

   integer 	  instrCount = 0;

   reg 		  CoreInstAck;
   wire 	  CoreInstCyc;
   wire 	  CoreInstStb;

// Testbench event queues
   typedef 	     enum {NEWPC, REGWRITE, MEMLOAD, MEMSTORE} T_CPU_ACTION_E;
   int 			  QDutPc[$]         ;
T_CPU_ACTION_E    QDutAction[$]     ;
   int 			  QDutRegMemAddr[$] ;
   int 			  QDutDataVal[$]    ;

   reg signed [31:0]      RegArray [31:0];
   reg [31:0] 		  RegHi;
   reg [31:0] 		  RegLo;

   reg [63:0] 		  MultResult;
   reg [63:0] 		  DivResult;

   reg 			  DelaySlot;
   reg 			  LoadSlot;

   reg [5:0] 		  Opcode;
   reg [4:0] 		  Rs;
   reg [4:0] 		  Rt;
   reg [4:0] 		  Rd;
   reg [4:0] 		  Shamt;
   reg [5:0] 		  Funct;
   reg [15:0] 		  Immed;
   reg [31:0] 		  SignXImmed;
   reg [31:0] 		  ZeroXImmed;
   reg [25:0] 		  Target;

   reg [31:0] 		  currPc;
   reg [31:0] 		  nextPc;
   reg [31:0] 		  jumpPc;

   reg 			  dataCheck;
   reg [31:0] 		  nextDataAdr;
   reg [3:0] 		  nextDataSel;
   reg 			  nextDataWe;
   reg [31:0] 		  nextDataDatRd;
   reg [31:0] 		  nextDataDatWr;
   reg [4:0] 		  nextDataReg;

   reg [31:0] 		  Pc;
   reg [31:0] 		  PcReg;

   reg [31:0] 		  LastInstr;



   // **************************** Register tracing *************************
   // Registers are written on a negedge clock. 
   initial
      begin
	 regsLog = $fopen("core_regs_log.txt");
      end
   
   always @(negedge TB_CPU_CORE_BFM.cpu_core.CLK)
   begin


      if (TB_CPU_CORE_BFM.cpu_core.RegWriteWb && (32'd0 != TB_CPU_CORE_BFM.cpu_core.RegWrWb))
      begin

	 $fwrite(regsLog, "REG WR: Register %d = 0x%08x\n", TB_CPU_CORE_BFM.cpu_core.RegWrWb, TB_CPU_CORE_BFM.cpu_core.WriteDataWb);
      end

      
   end // if (CORE_DATA_CYC_IN && CORE_DATA_STB_IN && CORE_DATA_ACK_IN)
   // *************************************************************************


   
// **************************** Data memory tracing *************************
// Registers are written on a negedge clock. 
   initial
   begin
      dataLog = $fopen("core_data_log.txt");
   end
   
always @(posedge CLK)
begin


   if (CORE_DATA_CYC_IN && CORE_DATA_STB_IN && CORE_DATA_ACK_IN)
   begin

      // Write
      if (CORE_DATA_WE_IN)
      begin
	 $fwrite(dataLog, "DATA WR: Addr 0x%08x = Data 0x%08x, Byte Sel = 0x%1x\n", CORE_DATA_ADR_IN, CORE_DATA_DAT_WR_IN, CORE_DATA_SEL_IN);
      end

      // Read
      else
      begin
	 $fwrite(dataLog, "DATA RD: Addr 0x%08x = Data 0x%08x, Byte Sel = 0x%1x\n", CORE_DATA_ADR_IN, CORE_DATA_DAT_RD_IN, CORE_DATA_SEL_IN);
      end
            
   end // if (CORE_DATA_CYC_IN && CORE_DATA_STB_IN && CORE_DATA_ACK_IN)
end // always @ (posedge CLK)
// *************************************************************************





// **************************** Instruction tracing *************************
   initial
   begin
      instrLog = $fopen("core_instr_log.txt");
      
      TraceEnable = 1'b1;
   end

// Instruction reads are pipelined. This means the data comes back a cycle after
// the address is sent out..
   
always @(posedge CLK)
begin

   if (!RST_SYNC)
   begin

      if (CORE_INST_CYC_IN && CORE_INST_STB_IN)
      begin
	 PcReg = CORE_INST_ADR_IN;
      end
   end
end
   


always @(negedge CLK)
begin

   if (!RST_SYNC)
   begin

      // When new instruction read in .. 
      if (CORE_INST_CYC_IN && CORE_INST_STB_IN && CORE_INST_ACK_IN)
      begin

	 // Increment PC counter
	 instrCount = instrCount + 1;

	 $fwrite(instrLog, "INST CNT: %04d: ", instrCount);
	 
	 // decode the instruction fields (not all will be used)
	 Opcode = CORE_INST_DAT_RD_IN[OPC_HI:OPC_LO];
	 Rs     = CORE_INST_DAT_RD_IN[RS_HI:RS_LO];
	 Rt     = CORE_INST_DAT_RD_IN[RT_HI:RT_LO];
	 Rd     = CORE_INST_DAT_RD_IN[RD_HI:RD_LO];
	 Shamt  = CORE_INST_DAT_RD_IN[SA_HI:SA_LO];
	 Funct  = CORE_INST_DAT_RD_IN[FUNCT_HI:FUNCT_LO];
	 Immed  = CORE_INST_DAT_RD_IN[IMMED_HI:IMMED_LO];
	 SignXImmed = {{16{Immed[15]}}, Immed};
	 ZeroXImmed = {{16{1'b0}}, Immed};
	 Target = CORE_INST_DAT_RD_IN[TARGET_HI:TARGET_LO];

	 // update PCs, assume no jump / branch, etc
	 currPc = PcReg;
	 nextPc = PcReg + 32'd4;

	 LastInstr = CORE_INST_DAT_RD_IN;
	 
	 if (DelaySlot)
	 begin
	    $fwrite(instrLog, "DLY_SLOT: ");
	    nextPc = jumpPc;
	    DelaySlot = 1'b0;
	 end
	 
	 $fwrite(instrLog, "PC: 0x%08x, INST: 0x%08x : ", PcReg, CORE_INST_DAT_RD_IN);
	 
	 // SPECIAL instructions
	 if (Opcode == OPC_SPECIAL)
	 begin
	    
            // todo: can you replace this with a LUT made from an array of strings?
	    case (Funct)
	      FUNCT_SLL       : 
	      begin
		 RegArray[Rd] = RegArray[Rt] << Shamt; // { RegArray[Rt][31 - Shamt:0]  , {Shamt{1'b0}}};
		 $fwrite(instrLog, "FUNCT  = SLL    ,  REG[%2d] = REG[%2d] << %d", Rd, Rt, Shamt);
	      end
	      FUNCT_SRL       : 
	      begin
		 RegArray[Rd] = RegArray[Rt] >> Shamt; //{ {Shamt{1'b0}} , RegArray[Rt][31:Shamt]};
		 $fwrite(instrLog, "FUNCT  = SRL    ,  REG[%2d] = REG[%2d] >> %d", Rd, Rt, Shamt);
	      end 
	      FUNCT_SRA       : 
	      begin
		 RegArray[Rd] = RegArray[Rt] <<< Shamt; // { {Shamt{RegArray[Rt][31]}} , RegArray[Rt][31:Shamt]};
		 $fwrite(instrLog, "FUNCT  = SRA    ,  REG[%2d] = REG[%2d] <<< %d", Rd, Rt, Shamt);
	      end 
	      FUNCT_SLLV      : 
	      begin
		 RegArray[Rd] = RegArray[Rt] << RegArray[Rs]; // { RegArray[Rt][31 - Rs:0]  , {Rs{1'b0}}};
		 $fwrite(instrLog, "FUNCT  = SLLV   ,  REG[%2d] = REG[%2d] << REG[%2d]", Rd, Rt, Rs);
	      end 
	      FUNCT_SRLV      : 
	      begin
		 RegArray[Rd] = RegArray[Rt] >> RegArray[Rs]; // { {Rs{1'b0}} , RegArray[Rt][31:Rs]};
		 $fwrite(instrLog, "FUNCT  = SRLV   ,  REG[%2d] = REG[%2d] >> REG[%d]", Rd, Rt, Rs);
	      end 
	      FUNCT_SRAV      : 
	      begin
		 RegArray[Rd] = RegArray[Rt] >>> RegArray[Rs]; // { {Rs{RegArray[Rt][31]}} , RegArray[Rt][31:Rs]};
		 $fwrite(instrLog, "FUNCT  = SRAV   ,  REG[%2d] = REG[%2d] >>> REG[$2d]", Rd, Rt, Rs);
	      end 
	      FUNCT_JR        : 
	      begin
		 jumpPc = RegArray[Rs] ; 
		 DelaySlot = 1'b1;
		 $fwrite(instrLog, "FUNCT  = JR     ,  Delay PC = 0x%08x, Jump PC = REG[%2d]", nextPc, Rs);
	      end 
	      FUNCT_JALR      : 
	      begin
		 RegArray[Rd] = nextPc + 32'd4; 
		 jumpPc = RegArray[Rs] ;
		 DelaySlot = 1'b1;
		 $fwrite(instrLog, "FUNCT  = JALR   , Delay PC = 0x%08x, Jump PC = REG[%2d], REG[31] = 0x%08x", nextPc, Rd, nextPc + 32'd4);

	      end 
	      FUNCT_SYSCALL   : 
	      begin
		 $fwrite(instrLog, "FUNCT  = SYSCALL ");
	      end 
	      FUNCT_BREAK     : 
	      begin
		 $fwrite(instrLog, "FUNCT  = BREAK ");
	      end 
	      FUNCT_MFHI      : 
	      begin
		 RegArray[Rd] = RegHi;
		 $fwrite(instrLog, "FUNCT  = MFHI   ,  REG[%2d] = REGHI", Rd);
	      end 
	      FUNCT_MTHI      : 
	      begin
		 RegHi = RegArray[Rs];
		 $fwrite(instrLog, "FUNCT  = MTHI   ,  REGHI = REG[%2d]", Rs);
	      end 
	      FUNCT_MFLO      : 
	      begin
		 RegArray[Rd] = RegLo;
		 $fwrite(instrLog, "FUNCT  = MFLO   ,  REG[%2d] = REGHI", Rd);
	      end 
	      FUNCT_MTLO      : 
	      begin
		 RegLo = RegArray[Rs];
		 $fwrite(instrLog, "FUNCT  = MTLO   ,  REGLO = REG[%2d]", Rs);
	      end 
	      FUNCT_MULT      : 
	      begin
		 MultResult = RegArray[Rs] * RegArray[Rt]; 
		 RegLo = MultResult[31:0]; 
		 RegHi = MultResult[63:32];
		 $fwrite(instrLog, "FUNCT  = MULT   ,  REG{HI,LO} = REG[%2d] * REG [%2d]", Rs, Rt);		 
	      end 
	      FUNCT_MULTU     : 
	      begin
		 MultResult = RegArray[Rs] * RegArray[Rt]; 
		 RegLo = MultResult[31:0]; 
		 RegHi = MultResult[63:32];
		 $fwrite(instrLog, "FUNCT  = MULTU  ,  REG{HI,LO} = REG[%2d] * REG [%2d]", Rs, Rt);		 		 
	      end 
	      FUNCT_DIV       : 
	      begin
		 DivResult  = RegArray[Rs] / RegArray[Rt]; 
		 RegLo = DivResult[31:0]; 
		 RegHi = DivResult[63:32];
		 $fwrite(instrLog, "FUNCT  = DIV    ,  REG{HI,LO} = REG[%2d] / REG [%2d]", Rs, Rt);
	      end 
	      FUNCT_DIVU      : 
	      begin
		 DivResult  = RegArray[Rs] / RegArray[Rt]; 
		 RegLo = DivResult[31:0]; 
		 RegHi = DivResult[63:32];
		 $fwrite(instrLog, "FUNCT  = DIVU   ,  REG{HI,LO} = REG[%2d] / REG [%2d]", Rs, Rt);
	      end 
	      FUNCT_ADD       : 
	      begin
		 RegArray[Rd] = RegArray[Rs] + RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = ADD    ,  REG[%2d] = REG[%2d] + REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_ADDU      : 
	      begin
		 RegArray[Rd] = RegArray[Rs] + RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = ADDU   ,  REG[%2d] = REG[%2d] + REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_SUB       : 
	      begin
		 RegArray[Rd] = RegArray[Rs] - RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = SUB    ,  REG[%2d] = REG[%2d] - REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_SUBU      : 
	      begin
		 RegArray[Rd] = RegArray[Rs] - RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = SUBU   ,  REG[%2d] = REG[%2d] - REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_AND       : 
	      begin
		 RegArray[Rd] = RegArray[Rs] & RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = AND    ,  REG[%2d] = REG[%2d] AND REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_OR        : 
	      begin
		 RegArray[Rd] = RegArray[Rs] | RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = OR     ,  REG[%2d] = REG[%2d] OR REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_XOR       : 
	      begin
		 RegArray[Rd] = RegArray[Rs] ^ RegArray[Rt];
		 $fwrite(instrLog, "FUNCT  = XOR    ,  REG[%2d] = REG[%2d] XOR REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_NOR       : 
	      begin
		 RegArray[Rd] = ~(RegArray[Rs] | RegArray[Rt]);
		 $fwrite(instrLog, "FUNCT  = NOR    ,  REG[%2d] = REG[%2d] NOR REG[%2d]", Rd, Rs, Rt);
	      end 
	      FUNCT_SLT       : 
	      begin
		 RegArray[Rd] = (RegArray[Rs] < RegArray[Rt]);
		 $fwrite(instrLog, "FUNCT  = SLT    ,  REG[%2d] = (REG[%2d] < REG[%2d])", Rd, Rs, Rt);
	      end 
	      FUNCT_SLTU      : 
	      begin
		 RegArray[Rd] = (RegArray[Rs] < RegArray[Rt]);
		 $fwrite(instrLog, "FUNCT  = SLTU   ,  REG[%2d] = (REG[%2d] < REG[%2d])", Rd, Rs, Rt);
	      end 
	      default: 
	      begin
    		 $fwrite(instrLog, "UNRECOGNISED SPECIAL OPCODE");
		 $display("[ERROR] Unrecognized SPECIAL FUNCT");
	      end
	      
	    endcase // case (Instr[FUNCT_HI:SA_LO])

	 end
	 
	 else if (Opcode == OPC_REGIMM)
	 begin
            case (Rt)
              REGIMM_BLTZ   : 
	      begin

     		 jumpPc = nextPc + {Immed, 2'b00} ; 
		 $fwrite(instrLog, "REGIMM = BLTZ    , REG[%2d] < 0 ? to PC 0x%08x", Rs, jumpPc);
		 DelaySlot = 1'b1;
		 
//		 if (RegArray[Rs] < 0) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//      	 end
	      end
	      
              REGIMM_BGEZ   : 
 	      begin
     		 jumpPc = nextPc + {Immed, 2'b00} ; 
		 $fwrite(instrLog, "REGIMM = BGEZ    , REG[%2d] >= 0 ? to PC 0x%08x", Rs, jumpPc);
		 DelaySlot = 1'b1;
	 
//		 if (RegArray[Rs] >= 0) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
//      		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; 
//		    DelaySlot = 1'b1;		       
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
	      
              REGIMM_BLTZAL :
	      begin

     		 jumpPc = nextPc + {Immed, 2'b00} ; 
		 $fwrite(instrLog, "REGIMM = BLTZAL  , REG[%2d] < 0 ? to PC 0x%08x, REG[31] = 0x%08x", Rs, jumpPc, nextPc + 32'd4);
		 DelaySlot = 1'b1;
		 
//		 if (RegArray[Rs] < 0) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    RegArray[31] = nextPc + 32'd4;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x, REG[31] = 0x%08x", nextPc, jumpPc, RegArray[31]);
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; 
//		    DelaySlot = 1'b1;		       
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
	      
              REGIMM_BGEZAL :
 	      begin

     		 jumpPc = nextPc + {Immed, 2'b00} ; 
		 $fwrite(instrLog, "REGIMM = BGEZAL  , REG[%2d] >= 0 ? to PC 0x%08x, REG[31] = 0x%08x", Rs, jumpPc, nextPc + 32'd4);
		 DelaySlot = 1'b1;

//		 if (RegArray[Rs] >= 0) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    RegArray[31] = nextPc + 32'd4;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x, REG[31] = 0x%08x", nextPc, jumpPc, RegArray[31]);
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; DelaySlot = 1'b1;		       
//		    DelaySlot = 1'b1;		       
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
	      
              default: $display("[ERROR] Unrecognized REGIMM RT");
            endcase // case (Instr[FUNCT_HI:FUNCT_LO])

	 end 
	 
	 else
	 begin
	    case (Opcode)
	      OPC_J        : 
	      begin
		 jumpPc = nextPc + {Target, 2'b00} ; 
		 DelaySlot = 1'b1;
		 $fwrite(instrLog, "OPCODE = J      ,  Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
	      end
              OPC_JAL      : 
	      begin
		 jumpPc = nextPc + {Target, 2'b00} ; 
		 DelaySlot = 1'b1;
		 RegArray[31] = nextPc + 32'd4;
		 $fwrite(instrLog, "OPCODE = JAL    ,  Delay PC = 0x%08x, Jump PC = 0x%08x, REG[31] = 0x%08x", nextPc, jumpPc, nextPc + 32'd4);
	      end
              OPC_BEQ      : 
	      begin

		 jumpPc = nextPc + {Immed, 2'b00} ; 
		 $fwrite(instrLog, "OPCODE = BEQ    , REG[%2d] == REG [%2d] ? to PC 0x%08x", Rs, Rt, jumpPc);
		 DelaySlot = 1'b1;
//		 if (RegArray[Rs] == RegArray[Rt]) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; 
//		    DelaySlot = 1'b1;		       
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
              OPC_BNE      : 
	      begin
		 jumpPc = nextPc + {Immed, 2'b00} ; 		 
		 $fwrite(instrLog, "OPCODE = BNE    , REG[%2d] != REG [%2d] ? to PC 0x%08x", Rs, Rt, jumpPc);
		 DelaySlot = 1'b1;

//		 if (RegArray[Rs] != RegArray[Rt]) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; 
//		    DelaySlot = 1'b1;		       
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
              OPC_BLEZ     : 
	      begin
		 jumpPc = nextPc + {Immed, 2'b00} ; 
		 $fwrite(instrLog, "OPCODE = BLEZ   , REG[%2d] <= 0 ? to PC 0x%08x", Rs, jumpPc);
		 DelaySlot = 1'b1;
//		 if (RegArray[Rs] == 32'd0) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);		    
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; DelaySlot = 1'b1;		       
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
              OPC_BGTZ     : 
	      begin
		 jumpPc = nextPc + {Immed, 2'b00} ; 		 
		 $fwrite(instrLog, "OPCODE = BGTZ   , REG[%2d] > 0 ? to PC 0x%08x", Rs, jumpPc);
		 DelaySlot = 1'b1;
//		 if (RegArray[Rs] > 32'd0) 
//		 begin
//		    jumpPc = nextPc + {Immed, 2'b00} ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "TAKEN - Delay PC = 0x%08x, Jump PC = 0x%08x", nextPc, jumpPc);
//		 end
//		 else
//		 begin
//		    jumpPc = nextPc + 32'd4 ; 
//		    DelaySlot = 1'b1;
//		    $fwrite(instrLog, "NOT TAKEN - Delay PC = 0x%08x", nextPc);
//		 end
	      end
              OPC_ADDI     : 
	      begin
//		 RegArray[Rt] = RegArray[Rs] + SignXImmed;
		 $fwrite(instrLog, "OPCODE = ADDI   ,  REG[%2d] = REG[%2d] + 0x%08x", Rt, Rs, SignXImmed);
	      end
              OPC_ADDIU    : 
	      begin
//		 RegArray[Rt] = RegArray[Rs] + SignXImmed;
		 $fwrite(instrLog, "OPCODE = ADDIU  ,  REG[%2d] = REG[%2d] + 0x%08x", Rt, Rs, SignXImmed);
	      end
              OPC_SLTI     : 
	      begin
		 $fwrite(instrLog, "OPCODE = SLTI   , REG[%2d] < IMMED 0x%08x ?", Rs, SignXImmed);
//		 if (RegArray[Rs] < Immed)
//		 begin
//		    RegArray[Rt] = 5'd1;
//		    $fwrite(instrLog, "SET - REG[%2d] = 0x%08x", Rt, RegArray[Rt]);
//		 end
//		 else
//		 begin
//		    RegArray[Rt] = 5'd0;
//		    $fwrite(instrLog, "CLR - REG[%2d] = 0x%08x", Rt, RegArray[Rt]);
//		 end
	      end
              OPC_SLTIU    : 
	      begin
		 $fwrite(instrLog, "OPCODE = SLTIU  , REG[%2d] < IMMED 0x%08x ?", Rs, SignXImmed);
//		 if (RegArray[Rs] < Immed)
//		 begin
//		    RegArray[Rt] = 5'd1;
//		    $fwrite(instrLog, "SET - REG[%2d] = 0x%08x", Rt, RegArray[Rt]);
//		 end
//		 else
//		 begin
//		    RegArray[Rt] = 5'd0;
//		    $fwrite(instrLog, "CLR - REG[%2d] = 0x%08x", Rt, RegArray[Rt]);
//		 end
	      end
              OPC_ANDI     : 
	      begin
//		 RegArray[Rt] = RegArray[Rs] & ZeroXImmed;
		 $fwrite(instrLog, "OPCODE = ANDI   ,  REG[%2d] = REG[%2d] AND 0x%08x", Rt, Rs, ZeroXImmed);
	      end
              OPC_ORI      : 
	      begin
//		 RegArray[Rt] = RegArray[Rs] | ZeroXImmed;
		 $fwrite(instrLog, "OPCODE = ORI    ,  REG[%2d] = REG[%2d] OR 0x%08x", Rt, Rs, ZeroXImmed);
	      end
              OPC_XORI     : 
	      begin
//		 RegArray[Rt] = RegArray[Rs] ^ ZeroXImmed;
		 $fwrite(instrLog, "OPCODE = XOR    ,  REG[%2d] = REG[%2d] XOR 0x%08x", Rt, Rs, ZeroXImmed);
	      end
              OPC_LUI      : 
	      begin
		 RegArray[Rt] = {Immed, 16'h0000};
		 $fwrite(instrLog, "OPCODE = LUI    ,  REG[%2d] = 0x%04x0000", Rt, Immed);
	      end
              OPC_COP0     : 
	      begin
		 $fwrite(instrLog, "OPC_COP0     , ");
	      end
              OPC_COP1     : 
	      begin
		 $fwrite(instrLog, "OPC_COP1     , ");
	      end
              OPC_COP2     : 
	      begin
		 $fwrite(instrLog, "OPC_COP2     , ");
	      end
              OPC_COP3     : 
	      begin
		 $fwrite(instrLog, "OPC_COP3     , ");
	      end
              OPC_LB       : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b0001;
		 nextDataWe    = 1'b0;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = 32'hXXXXXXXX;
		 nextDataReg   = RegArray[Rt];
		 $fwrite(instrLog, "OPCODE = LB     ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
	      end
              OPC_LH       : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b0011;
		 nextDataWe    = 1'b0;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = 32'hXXXXXXXX;
		 nextDataReg   = RegArray[Rt];
		 $fwrite(instrLog, "OPCODE = LH     ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
	      end
              OPC_LWL      : 
	      begin
		 $fwrite(instrLog, "OPC_LWL      , ");
	      end
              OPC_LW       :
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b1111;
		 nextDataWe    = 1'b0;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = 32'hXXXXXXXX;
		 nextDataReg   = RegArray[Rt];
		 $fwrite(instrLog, "OPCODE = LW     ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
	      end
              OPC_LBU      : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b0001;
		 nextDataWe    = 1'b0;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = 32'hXXXXXXXX;
		 nextDataReg   = RegArray[Rt];
		 $fwrite(instrLog, "OPCODE = LBU    ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
	      end
              OPC_LHU      : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b0011;
		 nextDataWe    = 1'b0;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = 32'hXXXXXXXX;
		 nextDataReg   = RegArray[Rt];
		 $fwrite(instrLog, "OPCODE = LHU    ,  REG[%2d] = DATA[ REG[%2d] + Immed 0x%08x]", Rt, Rs, SignXImmed);
	      end
              OPC_LWR      : 
	      begin
		 $fwrite(instrLog, "OPC_LWR      , ");
	      end
              OPC_SB       : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b0001;
		 nextDataWe    = 1'b1;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = RegArray[Rt];
		 nextDataReg   = 5'd0;
		 $fwrite(instrLog, "OPCODE = SB     ,  DATA[ REG[%2d] + Immed 0x%08x] = REG[%2d]", Rs, SignXImmed, Rt);
	      end
              OPC_SH       : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b0011;
		 nextDataWe    = 1'b1;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = RegArray[Rt];
		 nextDataReg   = 5'd0;
		 $fwrite(instrLog, "OPCODE = SH     ,  DATA[ REG[%2d] + Immed 0x%08x] = REG[%2d]", Rs, SignXImmed, Rt);
	      end
              OPC_SWL      : 
	      begin
		 $fwrite(instrLog, "OPC_SWL      , ");
	      end
              OPC_SW       : 
	      begin
		 nextDataAdr   = RegArray[Rs] + SignXImmed;
		 nextDataSel   = 4'b1111;
		 nextDataWe    = 1'b1;
		 nextDataDatRd = 32'hXXXXXXXX;
		 nextDataDatWr = RegArray[Rt];
		 nextDataReg   = 5'd0;
		 $fwrite(instrLog, "OPCODE = SW     ,  DATA[ REG[%2d] + Immed 0x%08x] = REG[%2d]", Rs, SignXImmed, Rt);
	      end
              OPC_SWR      : 
	      begin
		 $fwrite(instrLog, "OPC_SWR      , ");
	      end
              OPC_LWC1     : 
	      begin
		 $fwrite(instrLog, "OPC_LWC1     , ");
	      end
              OPC_LWC2     : 
	      begin
		 $fwrite(instrLog, "OPC_LWC2     , ");
	      end
              OPC_LWC3     : 
	      begin
		 $fwrite(instrLog, "OPC_LWC3     , ");
	      end
              OPC_SWC1     : 
	      begin
		 $fwrite(instrLog, "OPC_SWC1     , ");
	      end
              OPC_SWC2     : 
	      begin
		 $fwrite(instrLog, "OPC_SWC2     , ");
	      end
              OPC_SWC3     : 
	      begin
		 $fwrite(instrLog, "OPC_SWC3     , ");
	      end

	    endcase // case (Opcode)
	    
	      
	 end // else: !if(Opcode == OPC_REGIMM)
	
	 $fwrite(instrLog, "\n");

      end // if (TraceEnable)
   end // if (!RST_SYNC)
end
// *************************************************************************




endmodule
/*****************************************************************************/
