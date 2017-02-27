// CPU Core defines


// Defines for instruction bit fields
parameter OPC_HI    = 31;
parameter OPC_LO    = 26;
parameter RS_HI     = 25;
parameter RS_LO     = 21;
parameter RT_HI     = 20;
parameter RT_LO     = 16;
parameter RD_HI     = 15;
parameter RD_LO     = 11;
parameter SA_HI     = 10;
parameter SA_LO     =  6;
parameter FUNCT_HI  =  5;
parameter FUNCT_LO  =  0;
parameter TARGET_HI = 25;
parameter TARGET_LO =  0;
parameter IMMED_HI  = 15;
parameter IMMED_LO  =  0;
parameter CP_SPECIFIC = 25;
parameter CP0_FN_HI =  4;
parameter CP0_FN_LO =  0;

// Opcodes (ordered by binary value)
// These use the opcode field [31:26] to encode the operation 
// or select SPECIAL / REGIMM subsets from below
parameter [5:0] OPC_SPECIAL  =   6'b000000;  // SPECIAL instruction class
parameter [5:0] OPC_REGIMM   =   6'b000001;  // REGIMM instruction class
parameter [5:0] OPC_J        =   6'b000010;  // Jump
parameter [5:0] OPC_JAL      =   6'b000011;  // Jump and link
parameter [5:0] OPC_BEQ      =   6'b000100;  // Branch on equal
parameter [5:0] OPC_BNE      =   6'b000101;  // Branch on not equal
parameter [5:0] OPC_BLEZ     =   6'b000110;  // Branch on less than or equal to zero
parameter [5:0] OPC_BGTZ     =   6'b000111;  // Branch on greater than zero
parameter [5:0] OPC_ADDI     =   6'b001000;  // Add immediate
parameter [5:0] OPC_ADDIU    =   6'b001001;  // Add immediate unsigned
parameter [5:0] OPC_SLTI     =   6'b001010;  // Set on less than immediate
parameter [5:0] OPC_SLTIU    =   6'b001011;  // Set on less than immediate unsigned
parameter [5:0] OPC_ANDI     =   6'b001100;  // Bitwise AND immediate
parameter [5:0] OPC_ORI      =   6'b001101;  // Bitwise OR immediate
parameter [5:0] OPC_XORI     =   6'b001110;  // Bitwise XOR immediate
parameter [5:0] OPC_LUI      =   6'b001111;  // Load upper immediate
parameter [5:0] OPC_COP0     =   6'b010000;  // Coprocessor 0 Operation   TODO
parameter [5:0] OPC_COP1     =   6'b010001;  // Coprocessor 1 Operation (optional)
parameter [5:0] OPC_COP2     =   6'b010010;  // Coprocessor 2 Operation (optional)
parameter [5:0] OPC_COP3     =   6'b010011;  // Coprocessor 3 Operation (optional)
parameter [5:0] OPC_LB       =   6'b100000;  // Load byte
parameter [5:0] OPC_LH       =   6'b100001;  // Load halfword
parameter [5:0] OPC_LWL      =   6'b100010;  // Load word left            TODO
parameter [5:0] OPC_LW       =   6'b100011;  // Load word
parameter [5:0] OPC_LBU      =   6'b100100;  // Load byte unsigned
parameter [5:0] OPC_LHU      =   6'b100101;  // Load halfword unsigned
parameter [5:0] OPC_LWR      =   6'b100110;  // Load word right           TODO
parameter [5:0] OPC_SB       =   6'b101000;  // Store byte
parameter [5:0] OPC_SH       =   6'b101001;  // Store halfword
parameter [5:0] OPC_SWL      =   6'b101010;  // Store word left           TODO
parameter [5:0] OPC_SW       =   6'b101011;  // Store word
parameter [5:0] OPC_SWR      =   6'b101110;  // Store word right          TODO
parameter [5:0] OPC_LWC0     =   6'b110000;  // Load word to Coprocessor 0 (optional)
parameter [5:0] OPC_LWC1     =   6'b110001;  // Load word to Coprocessor 1 (optional)
parameter [5:0] OPC_LWC2     =   6'b110010;  // Load word to Coprocessor 2 (optional)
parameter [5:0] OPC_LWC3     =   6'b110011;  // Load word to Coprocessor 3 (optional)
parameter [5:0] OPC_SWC0     =   6'b111000;  // Store word from Coprocessor 0 (optional)
parameter [5:0] OPC_SWC1     =   6'b111001;  // Store word from Coprocessor 1 (optional)
parameter [5:0] OPC_SWC2     =   6'b111010;  // Store word from Coprocessor 2 (optional)
parameter [5:0] OPC_SWC3     =   6'b111011;  // Store word from Coprocessor 3 (optional)

// SPECIAL instruction class functions (ordered by binary value)
// These use the 'function' field to encode the operation [5:0]
parameter [5:0] FUNCT_SLL       =   6'b000000;  // Shift left logical
parameter [5:0] FUNCT_SRL       =   6'b000010;  // Shift right logical
parameter [5:0] FUNCT_SRA       =   6'b000011;  // Shift right arithmetic
parameter [5:0] FUNCT_SLLV      =   6'b000100;  // Shift left logical variable
parameter [5:0] FUNCT_SRLV      =   6'b000110;  // Shift right logical variable
parameter [5:0] FUNCT_SRAV      =   6'b000111;  // Shift right arithmetic variable
parameter [5:0] FUNCT_JR        =   6'b001000;  // Jump register
parameter [5:0] FUNCT_JALR      =   6'b001001;  // Jump and link register
parameter [5:0] FUNCT_SYSCALL   =   6'b001100;  // System call               
parameter [5:0] FUNCT_BREAK     =   6'b001101;  // Breakpoint                
parameter [5:0] FUNCT_MFHI      =   6'b010000;  // Move from HI register     
parameter [5:0] FUNCT_MTHI      =   6'b010001;  // Move to HI register       
parameter [5:0] FUNCT_MFLO      =   6'b010010;  // Move from LO register     
parameter [5:0] FUNCT_MTLO      =   6'b010011;  // Move to LO register       
parameter [5:0] FUNCT_MULT      =   6'b011000;  // Multiply                  
parameter [5:0] FUNCT_MULTU     =   6'b011001;  // Multiply unsigned         
parameter [5:0] FUNCT_DIV       =   6'b011010;  // Divide                    
parameter [5:0] FUNCT_DIVU      =   6'b011011;  // Divide unsigned           
parameter [5:0] FUNCT_ADD       =   6'b100000;  // Add
parameter [5:0] FUNCT_ADDU      =   6'b100001;  // Add unsigned
parameter [5:0] FUNCT_SUB       =   6'b100010;  // Subtract
parameter [5:0] FUNCT_SUBU      =   6'b100011;  // Subtract unsigned
parameter [5:0] FUNCT_AND       =   6'b100100;  // Bitwise AND
parameter [5:0] FUNCT_OR        =   6'b100101;  // Bitwise OR
parameter [5:0] FUNCT_XOR       =   6'b100110;  // Bitwise XOR
parameter [5:0] FUNCT_NOR       =   6'b100111;  // Bitwise NOR
parameter [5:0] FUNCT_SLT       =   6'b101010;  // Set on less than
parameter [5:0] FUNCT_SLTU      =   6'b101011;  // Set on less than unsigned

// REGIMM opcodes use the rt field [20:16] to encode the instruction
parameter [4:0] REGIMM_BLTZ     =   5'b00000;   // Branch on Less Than Zero
parameter [4:0] REGIMM_BGEZ     =   5'b00001;   // Branch on Greater than or Equal to Zero
parameter [4:0] REGIMM_BLTZAL   =   5'b10000;   // Branch on Less Than Zero and link               
parameter [4:0] REGIMM_BGEZAL   =   5'b10001;   // Branch on Greater than or Equal to Zero and link    

// COPz fields. Decoded when Opcode = OPC_COP{0, 1, 2, 3}
parameter COPz_HI    = 25;
parameter COPz_LO    = 21;

parameter [4:0] COPz_MF = 5'b00000;
parameter [4:0] COPz_CF = 5'b00010;
parameter [4:0] COPz_MT = 5'b00100;
parameter [4:0] COPz_CT = 5'b00110;
parameter [4:0] COPz_BC = 5'b01000;

parameter [4:0] COP0_RFE = 5'b10000;

// BCz fields. Decoded when Opcode = OPC_COP{0, 1, 2, 3} and COP = 
parameter BCz_HI    = 20;
parameter BCz_LO    = 16;

//parameter BCzF = 5'b00000;
//parameter BCzF = 5'b00001;

// AluOpId decodes. This is decoded in the ID phase, and passed onto the
// ALU in the EX phase. If the instruction is a SPECIAL then the bottom 6
// bits have the ALU operation. If not it is set by opcode.
// Note that the following instructions don't use the ALU:

// - All REGIMM / OPc branch instructions (branch destination calculated in ID phase), 
// - Jump / JAL instructions (PC specified in instruction directly).
// OPC_COPz Co-processor instructions
parameter [2:0] ALU_OP_ADD      = 3'h0; // rs + immediate
parameter [2:0] ALU_OP_SLT      = 3'h1; // rs < immediate
parameter [2:0] ALU_OP_SLTU     = 3'h2; // rs < immediate (unsigned)
parameter [2:0] ALU_OP_AND      = 3'h3; // rs | immediate
parameter [2:0] ALU_OP_OR       = 3'h4; // rs ^ immediate
parameter [2:0] ALU_OP_XOR      = 3'h5; // immediate << 16 | 16'h0000
parameter [2:0] ALU_OP_LUI      = 3'h6; // operation encoded in bottom 6 bits of instruction (funct)
parameter [2:0] ALU_OP_SPECIAL   = 3'h7; // ALU operation specified in bottom 6 bits

// These parameters set where the ALU inputs come from (which stage of
// the pipeline from forwarding)
parameter [1:0] FWD_NONE = 2'b00;
parameter [1:0] FWD_EX   = 2'b01;
parameter [1:0] FWD_MEM  = 2'b10;

// These parameters are used when the ID stage decodes what type of comparison to
// use for the branch. There is no 'no check' value as the branch PX value will
// only be used if the JumpEx or BranchEx bit is set (otherwise its ignored)
parameter [2:0] BRANCH_RS_EQ_RT  = 3'h0; // Take branch if rs = rt
parameter [2:0] BRANCH_RS_NEQ_RT = 3'h1; // Take branch if rs != rt
parameter [2:0] BRANCH_RS_LTZ    = 3'h2; // Take branch if rs < 0
parameter [2:0] BRANCH_RS_LEZ    = 3'h3; // Take branch if rs <= 0
parameter [2:0] BRANCH_RS_GTZ    = 3'h4; // Take branch if rs > 0
parameter [2:0] BRANCH_RS_GEZ    = 3'h5; // Take branch if rs >= 0


// parameter PC_RST_VALUE = 32'h0000_0000;

// These parameters specify the width of memory accesses
parameter [1:0] MEM_SIZE_WORD = 2'b11;
parameter [1:0] MEM_SIZE_HALF = 2'b10;
parameter [1:0] MEM_SIZE_BYTE = 2'b01;
parameter [1:0] MEM_SIZE_NONE = 2'b00;
