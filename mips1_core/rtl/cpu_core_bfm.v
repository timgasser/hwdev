/* INSERT MODULE HEADER */


/*****************************************************************************/
module CPU_CORE_BFM
  #(parameter PC_RST_VALUE = 32'h0000_0000) // Unused in BFM
   (
    input  CLK                   ,
    input  RST_SYNC              ,

    // Instruction Memory (Read only)   
    output [31:0] CORE_INST_ADR_OUT     , // Master: Address of current transfer
    output        CORE_INST_CYC_OUT     , // Master: High while whole transfer is in progress
    output        CORE_INST_STB_OUT     , // Master: High while the current beat in burst is active
    output        CORE_INST_WE_OUT      , // Master: Write Enable (1), Read if 0
    output [ 3:0] CORE_INST_SEL_OUT     , // Master: Byte enables of write (one-hot)
    output [ 2:0] CORE_INST_CTI_OUT     , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    output [ 1:0] CORE_INST_BTE_OUT     , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap
    input         CORE_INST_ACK_IN      , // Slave:  Acknowledge of transaction
    input         CORE_INST_STALL_IN    , // Slave:  Not ready to accept a new address
    input         CORE_INST_ERR_IN      , // Slave:  Error occurred  
    input  [31:0] CORE_INST_DAT_RD_IN   , // Slave:  Read data
    output [31:0] CORE_INST_DAT_WR_OUT  , // Master: Write data
    
     // Data Memory (Read and Write)
    output [31:0] CORE_DATA_ADR_OUT     , // Master: Address of current transfer
    output        CORE_DATA_CYC_OUT     , // Master: High while whole transfer is in progress
    output        CORE_DATA_STB_OUT     , // Master: High while the current beat in burst is active
    output        CORE_DATA_WE_OUT      , // Master: Write Enable (1), Read if 0
    output [ 3:0] CORE_DATA_SEL_OUT     , // Master: Byte enables of write (one-hot)
    output [ 2:0] CORE_DATA_CTI_OUT     , // Master: Cycle Type - 3'h0 = classic, 3'h1 = const addr burst, 3'h2 = incr addr burst, 3'h7 = end of burst
    output [ 1:0] CORE_DATA_BTE_OUT     , // Master: Burst Type - 2'h0 = linear burst, 2'h1 = 4-beat wrap, 2'h2 = 8-beat wrap, 2'h3 = 16-beat wrap
    input         CORE_DATA_ACK_IN      , // Slave:  Acknowledge of transaction
    input         CORE_DATA_STALL_IN    , // Slave:  Not ready to accept a new address
    input         CORE_DATA_ERR_IN      , // Slave:  Error occurred  
    input  [31:0] CORE_DATA_DAT_RD_IN   , // Slave:  Read data
    output [31:0] CORE_DATA_DAT_WR_OUT  , // Master: Write data

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



   WB_MASTER_BFM wb_master_bfm_inst
   (
    .CLK            (CLK      ),
    .RST_SYNC       (RST_SYNC ),
    
    .WB_ADR_OUT     (CORE_INST_ADR_OUT     ), 
    .WB_CYC_OUT     (CORE_INST_CYC_OUT     ), 
    .WB_STB_OUT     (CORE_INST_STB_OUT     ), 
    .WB_WE_OUT      (CORE_INST_WE_OUT      ), 
    .WB_SEL_OUT     (CORE_INST_SEL_OUT     ),
    .WB_CTI_OUT     (CORE_INST_CTI_OUT     ), 
    .WB_BTE_OUT     (CORE_INST_BTE_OUT     ),
    .WB_ACK_IN      (CORE_INST_ACK_IN      ),
    .WB_STALL_IN    (CORE_INST_STALL_IN    ),
    .WB_ERR_IN      (CORE_INST_ERR_IN      ),
    .WB_DAT_RD_IN   (CORE_INST_DAT_RD_IN   ), 
    .WB_DAT_WR_OUT  (CORE_INST_DAT_WR_OUT  ) 
    );


   WB_MASTER_BFM wb_master_bfm_data
   (
    .CLK            (CLK      ),
    .RST_SYNC       (RST_SYNC ),
    
    .WB_ADR_OUT     (CORE_DATA_ADR_OUT     ), 
    .WB_CYC_OUT     (CORE_DATA_CYC_OUT     ), 
    .WB_STB_OUT     (CORE_DATA_STB_OUT     ), 
    .WB_WE_OUT      (CORE_DATA_WE_OUT      ), 
    .WB_SEL_OUT     (CORE_DATA_SEL_OUT     ), 
    .WB_CTI_OUT     (CORE_DATA_CTI_OUT     ), 
    .WB_BTE_OUT     (CORE_DATA_BTE_OUT     ),
    .WB_ACK_IN      (CORE_DATA_ACK_IN      ), 
    .WB_STALL_IN    (CORE_DATA_STALL_IN    ),
    .WB_ERR_IN      (CORE_DATA_ERR_IN      ),
    .WB_DAT_RD_IN   (CORE_DATA_DAT_RD_IN   ), 
    .WB_DAT_WR_OUT  (CORE_DATA_DAT_WR_OUT  ) 
    );

   
endmodule
/*****************************************************************************/
