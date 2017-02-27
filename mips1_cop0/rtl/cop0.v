// Insert module header  ..

module COP0
   (
    input         CLK                  ,
    input         RST_SYNC             ,

   // COP0 Instruction interface
    input         COP0_INST_EN_IN      ,
    input   [4:0] COP0_INST_IN         ,

    // COP0 Register read interface
    input         COP0_RD_EN_IN       ,
//    output        COP0_RD_ACK_OUT      ,
    input         COP0_RD_CTRL_SEL_IN  ,
    input   [4:0] COP0_RD_SEL_IN       ,
    output [31:0] COP0_RD_DATA_OUT     ,

    // COP0 Register write interface
    input         COP0_WR_EN_IN        ,
    input         COP0_WR_CTRL_SEL_IN  ,
    input   [4:0] COP0_WR_SEL_IN       ,
    input  [31:0] COP0_WR_DATA_IN      ,

    // Exceptions and IRQs
//    output  [1:0] SW_IRQ_OUT           ,
    input   [5:0] HW_IRQ_IN            ,
    output        COUNT_IRQ_OUT        , 

    output  [3:0] COP_USABLE_OUT       , // 

    output 	  COP0_INT_OUT         , //
    
    // Exception interface to the main core
    input         CORE_EXC_EN_IN       ,
    input   [1:0] CORE_EXC_CE_IN       ,
    input   [4:0] CORE_EXC_CODE_IN     ,
    input         CORE_EXC_BD_IN       ,
    input  [31:0] CORE_EXC_EPC_IN      ,
    input  [31:0] CORE_EXC_BADVA_IN    ,
    output [31:0] CORE_EXC_VECTOR_OUT  ,

    // Cache control lines
    output        CACHE_ISO_OUT        ,
    output        CACHE_SWAP_OUT       ,
    input         CACHE_MISS_IN       

    );


   // Includes
`include "cpu_defs.v"
`include "cop0_defs.v"
   
   // Wires / Regs
   reg 	[31:0] 	  BadVaReg;
   reg 	[23:0] 	  CountReg;
   reg 	[23:0] 	  CompareReg;
   reg 	[31:0] 	  StatusReg;
   reg 	[31:0] 	  CauseReg;
   reg 	[31:0] 	  EpcReg;      
   wire [31:0] 	  PridConst;

   // Define a test register, used for test checking..
   reg 	[31:0]	  TestRegGprReg;  
   reg  [31:0] 	  TestRegCtrlReg;  
   
   // Read enables (address decode)
   wire BadVaRdEn   	= COP0_RD_EN_IN & (COP0_BADVA   == COP0_RD_SEL_IN);
   wire CountRdEn   	= COP0_RD_EN_IN & (COP0_COUNT   == COP0_RD_SEL_IN);
   wire CompareRdEn 	= COP0_RD_EN_IN & (COP0_COMPARE == COP0_RD_SEL_IN);
   wire StatusRdEn  	= COP0_RD_EN_IN & (COP0_STATUS  == COP0_RD_SEL_IN);
   wire CauseRdEn   	= COP0_RD_EN_IN & (COP0_CAUSE   == COP0_RD_SEL_IN);
   wire EpcRdEn     	= COP0_RD_EN_IN & (COP0_EPC     == COP0_RD_SEL_IN);      
   wire PridRdEn    	= COP0_RD_EN_IN & (COP0_PRID    == COP0_RD_SEL_IN);      
   wire TestRegGprRdEn  = COP0_RD_EN_IN & (COP0_TEST    == COP0_RD_SEL_IN);
   wire TestRegCtrlRdEn = COP0_RD_EN_IN & (COP0_TEST    == COP0_RD_SEL_IN) & COP0_RD_CTRL_SEL_IN;

   // Write enables (address decode)
   wire BadVaWrEn   	= COP0_WR_EN_IN & (COP0_BADVA   == COP0_WR_SEL_IN);
   wire CountWrEn   	= COP0_WR_EN_IN & (COP0_COUNT   == COP0_WR_SEL_IN);
   wire CompareWrEn 	= COP0_WR_EN_IN & (COP0_COMPARE == COP0_WR_SEL_IN);
   wire StatusWrEn  	= COP0_WR_EN_IN & (COP0_STATUS  == COP0_WR_SEL_IN);
   wire CauseWrEn   	= COP0_WR_EN_IN & (COP0_CAUSE   == COP0_WR_SEL_IN);
   wire EpcWrEn     	= COP0_WR_EN_IN & (COP0_EPC     == COP0_WR_SEL_IN);      
   wire TestRegGprWrEn  = COP0_WR_EN_IN & (COP0_TEST    == COP0_WR_SEL_IN);
   wire TestRegCtrlWrEn = COP0_WR_EN_IN & (COP0_TEST    == COP0_WR_SEL_IN) & COP0_WR_CTRL_SEL_IN;

   // RFE Instruction decode
   wire Cop0RfeInst     = COP0_INST_EN_IN & (RFE == COP0_INST_IN);

   
   
   reg [31:0] 	  Cop0RdData;    
   reg [31:0] 	  Cop0RdDataReg; // COP0_RD_DATA_OUT

   reg 		  CountIntLocal; // COUNT_IRQ_OUT

   wire [1:0] 	  SwInt; 
   wire [5:0] 	  HwInt; 
   wire [1:0] 	  SwIntMask; 
   wire [5:0] 	  HwIntMask; 
   wire [1:0] 	  SwIntMasked; 
   wire [5:0] 	  HwIntMasked; 
   wire  	  IntMasked;
   wire  	  IntIecMasked;

//   reg 		  Cop0RdAckLocal; // COP0_RD_ACK_OUT
   
   // Internal assigns

   // Interrupt "masks" are actually enables
   assign HwInt = HW_IRQ_IN;
   assign SwInt = CauseReg[COP0_CAUSE_SW_MSB:COP0_CAUSE_SW_LSB];
 
   assign HwIntMask  = StatusReg[COP0_STATUS_IM_HW_MSB:COP0_STATUS_IM_HW_LSB];
   assign SwIntMask  = StatusReg[COP0_STATUS_IM_SW_MSB:COP0_STATUS_IM_SW_LSB];

   assign HwIntMasked  = HwInt & HwIntMask;
   assign SwIntMasked  = SwInt & SwIntMask;

   assign IntMasked    = ((| HwIntMasked) | (| SwIntMasked));
   assign IntIecMasked = IntMasked & StatusReg[COP0_STATUS_IEC];
   
   
   // decode write and read enables

   

   
   // Reserved register bits
//   assign StatusReg[27:26] = 2'd0;
//   assign StatusReg[24:23] = 2'd0;
//   assign StatusReg[ 7: 6] = 2'd0;
//
//   assign CauseReg [   30] = 1'd0;
//   assign CauseReg [27:16] = 12'd0;
//   assign CauseReg [    7] = 1'd0;
//   assign CauseReg [ 1: 0] = 2'd0;
   
   
   assign PridConst[31:16] = 16'h0000;
   assign PridConst[COP0_PRID_IMP_MSB:COP0_PRID_IMP_LSB] = COP0_IMP;
   assign PridConst[COP0_PRID_REV_MSB:COP0_PRID_REV_LSB] = COP0_REV;
  

   
   // Output assigns
   assign COUNT_IRQ_OUT    = CountIntLocal; 
   assign COP0_RD_DATA_OUT = Cop0RdDataReg;

   // Cache control assigns
   assign CACHE_ISO_OUT    = StatusReg[COP0_STATUS_ISC];
   assign CACHE_SWAP_OUT   = StatusReg[COP0_STATUS_SWC];

   // In Kernel mode, all the co-processors are usable..
   assign COP_USABLE_OUT   = StatusReg[COP0_STATUS_KUC_B] ? StatusReg[COP0_STATUS_CU_MSB:COP0_STATUS_CU_LSB] : 4'hf; 
   assign COP0_INT_OUT     = IntIecMasked; // todo may need pipelining

   assign CORE_EXC_VECTOR_OUT = StatusReg[COP0_STATUS_BEV] ? 32'hbfc0_0180 : 32'h8000_0080;

//   assign COP0_RD_ACK_OUT = Cop0RdAckLocal; 


   
   // todo : Convert pulses to levels?
//
//   // Register the REQ in to show the ACK returns the data a cycle later
//   always @(posedge CLK)
//   begin
//      if (RST_SYNC)
//      begin
//         Cop0RdAckLocal <= 1'b0;
//      end
//      else 
//      begin
//         Cop0RdAckLocal <= COP0_RD_EN_IN;
//      end
//   end
//  

   // BadVaReg - register this every time an exception happens. It is only
   // used for the address error ADEL or ADES for load / store
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         BadVaReg    <= 32'h0000_0000;
      end
      else if (CORE_EXC_EN_IN)
      begin
         BadVaReg    <= CORE_EXC_BADVA_IN;
      end
   end
   
   // COUNT_IRQ level irq
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CountIntLocal <= 1'b0;
      end
      // 1st priority: Set count irq level when count = compare
      else if (CountReg == CompareReg)
      begin
         CountIntLocal <= 1'b1;
      end
      // 2nd priority: De-assert IRQ when the compare register written
      else if (COP0_WR_EN_IN && (COP0_COMPARE == COP0_WR_SEL_IN))
      begin
         CountIntLocal <= 1'b0;
      end
   end
   
   // CompareReg;
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CompareReg    <= 24'hff_ffff;
      end
      // 1st priority: 
      else if (CompareWrEn)
      begin
         CompareReg    <= COP0_WR_DATA_IN;
      end
   end

   // CountReg;
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         CountReg    <= 24'h00_0000;
      end
      // 1st priority: load the counter
      else if (CountWrEn)
      begin
         CountReg    <= COP0_WR_DATA_IN;
      end
      // 2nd priority: free running counter
      else 
      begin
         CountReg    <= CountReg + 32'd1; // free running
      end
   end

   // StatusReg - basic R/W bits (including constants)
   // All bits apart from TS are readable and writable. TS is read-only
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
	 // Reserved bits need to be set in process as they are part of a reg (no assigns allowed)
	 StatusReg[27:26] <= 2'd0;
	 StatusReg[24:23] <= 2'd0;
	 StatusReg[ 7: 6] <= 2'd0;
 
	 // Non-reserved bit reset values
         StatusReg[COP0_STATUS_CU_MSB:COP0_STATUS_CU_LSB]  <= 4'b0001; // R/W. COP0 usable by default
         StatusReg[COP0_STATUS_RE ]  <= 1'b0; // R/W
         StatusReg[COP0_STATUS_BEV]  <= 1'b1; // R/W
         StatusReg[COP0_STATUS_TS ]  <= 1'b1; // fixed 
         StatusReg[COP0_STATUS_PE ]  <= 1'b0; // R/W
         StatusReg[COP0_STATUS_CM ]  <= 1'b0; // Set when CACHE_MISS_IN = 1. R/W
         StatusReg[COP0_STATUS_PZ ]  <= 1'b0; // R/W
         StatusReg[COP0_STATUS_SWC]  <= 1'b0; // R/W
         StatusReg[COP0_STATUS_ISC]  <= 1'b0; // R/W
         StatusReg[COP0_STATUS_IM_HW_MSB:COP0_STATUS_IM_HW_LSB]  <= 6'd0; // R/W
         StatusReg[COP0_STATUS_IM_SW_MSB:COP0_STATUS_IM_SW_LSB]  <= 2'd0; // R/W
      end // if (RST_SYNC)

      // Always store if the cache misses, even if you're writing the status reg
      else if (CACHE_MISS_IN)
      begin
	 StatusReg[COP0_STATUS_CM ] <= 1'b1;
      end
      
      // Read/Writable bit fields. All fields apart from TS are writable
      else if (StatusWrEn) 
      begin
         StatusReg[COP0_STATUS_CU_MSB:COP0_STATUS_CU_LSB]        <= COP0_WR_DATA_IN[COP0_STATUS_CU_MSB:COP0_STATUS_CU_LSB];
         StatusReg[COP0_STATUS_RE ]   		    		 <= COP0_WR_DATA_IN[COP0_STATUS_RE ];
         StatusReg[COP0_STATUS_BEV]  				 <= COP0_WR_DATA_IN[COP0_STATUS_BEV];
         StatusReg[COP0_STATUS_PE ]  		    		 <= COP0_WR_DATA_IN[COP0_STATUS_PE ];
         StatusReg[COP0_STATUS_CM ]  		    		 <= COP0_WR_DATA_IN[COP0_STATUS_CM ];
         StatusReg[COP0_STATUS_PZ ]  		    		 <= COP0_WR_DATA_IN[COP0_STATUS_PZ ];
         StatusReg[COP0_STATUS_SWC]  				 <= COP0_WR_DATA_IN[COP0_STATUS_SWC];
         StatusReg[COP0_STATUS_ISC]  				 <= COP0_WR_DATA_IN[COP0_STATUS_ISC];
         StatusReg[COP0_STATUS_IM_HW_MSB:COP0_STATUS_IM_HW_LSB]  <= COP0_WR_DATA_IN[COP0_STATUS_IM_HW_MSB:COP0_STATUS_IM_HW_LSB];
         StatusReg[COP0_STATUS_IM_SW_MSB:COP0_STATUS_IM_SW_LSB]  <= COP0_WR_DATA_IN[COP0_STATUS_IM_SW_MSB:COP0_STATUS_IM_SW_LSB];
      end // if (StatusWrEn)

      
   end

   // StatusReg - Cache Miss bit set on CACHE_MISS_IN = 1, cleared on Status Read.
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         StatusReg[COP0_STATUS_CM ]  <= 1'b0;
      end

      else if (CACHE_MISS_IN)
      begin
	 StatusReg[COP0_STATUS_CM ]  <= 1'b1;
      end

      else if (StatusRdEn) 
      begin
         StatusReg[COP0_STATUS_CM ]  <= 1'b0;
      end
   end 

   // StatusReg - KU and IE push / pop
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         StatusReg[COP0_STATUS_KUO_B ]  <= 1'b0; 
         StatusReg[COP0_STATUS_IEO   ]  <= 1'b0;
         StatusReg[COP0_STATUS_KUP_B ]  <= 1'b0; 
         StatusReg[COP0_STATUS_IEP   ]  <= 1'b0;
         StatusReg[COP0_STATUS_KUC_B ]  <= 1'b0;
         StatusReg[COP0_STATUS_IEC   ]  <= 1'b0;
      end
      
      // On exception : {KU, IE}C = 0, P = C, O = P
      else if (CORE_EXC_EN_IN)
      begin
         StatusReg[COP0_STATUS_KUO_B ]  <= StatusReg[COP0_STATUS_KUP_B ]; 
         StatusReg[COP0_STATUS_IEO   ]  <= StatusReg[COP0_STATUS_IEP   ];
         StatusReg[COP0_STATUS_KUP_B ]  <= StatusReg[COP0_STATUS_KUC_B ];
         StatusReg[COP0_STATUS_IEP   ]  <= StatusReg[COP0_STATUS_IEC   ];
         StatusReg[COP0_STATUS_KUC_B ]  <= 1'b0;
         StatusReg[COP0_STATUS_IEC   ]  <= 1'b0;
      end
      
      // On RFE : {KU, IE}P = O, C = P
      else if (Cop0RfeInst)
      begin
         StatusReg[COP0_STATUS_KUP_B ]  <= StatusReg[COP0_STATUS_KUO_B ];
         StatusReg[COP0_STATUS_IEP   ]  <= StatusReg[COP0_STATUS_IEO   ];
         StatusReg[COP0_STATUS_KUC_B ]  <= StatusReg[COP0_STATUS_KUP_B ];
         StatusReg[COP0_STATUS_IEC   ]  <= StatusReg[COP0_STATUS_IEP   ];
      end

      // All KU and IE bits are read/writable
      else if (StatusWrEn)
      begin
	 StatusReg[COP0_STATUS_KUO_B:COP0_STATUS_IEC] <= COP0_WR_DATA_IN[COP0_STATUS_KUO_B:COP0_STATUS_IEC];
      end
      
   end
   
   
// CauseReg - Register values on an exception;
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
	 // Reserved bits have to be assigned inside process
	 CauseReg [   30] <= 1'd0;
	 CauseReg [27:16] <= 12'd0;
	 CauseReg [    7] <= 1'd0;
	 CauseReg [ 1: 0] <= 2'd0;
	 
         CauseReg[COP0_CAUSE_BD]    <= 1'b0;
	 CauseReg[COP0_CAUSE_CE_MSB:COP0_CAUSE_CE_LSB] <= 2'b00;
	 CauseReg[COP0_CAUSE_IP_MSB:COP0_CAUSE_IP_LSB] <= 6'h00;
	 CauseReg[COP0_CAUSE_SW_MSB:COP0_CAUSE_SW_LSB] <= 2'b00;
	 CauseReg[COP0_CAUSE_EXC_CODE_MSB:COP0_CAUSE_EXC_CODE_LSB] <= 5'h00;
      end

      // 1st priority - store the fields on an exception
      else if (CORE_EXC_EN_IN)
      begin
         CauseReg[COP0_CAUSE_BD]    <= CORE_EXC_BD_IN;
	 CauseReg[COP0_CAUSE_CE_MSB:COP0_CAUSE_CE_LSB] <= CORE_EXC_CE_IN;
	 CauseReg[COP0_CAUSE_IP_MSB:COP0_CAUSE_IP_LSB] <= HW_IRQ_IN;
	 CauseReg[COP0_CAUSE_EXC_CODE_MSB:COP0_CAUSE_EXC_CODE_LSB] <= CORE_EXC_CODE_IN;	 
      end

      // Only writable fields are the SW interrupts
      else if (CauseWrEn)
      begin
 	 CauseReg[COP0_CAUSE_SW_MSB:COP0_CAUSE_SW_LSB] <= COP0_WR_DATA_IN[COP0_CAUSE_SW_MSB:COP0_CAUSE_SW_LSB];
      end
   end


   // EpcReg;      
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         EpcReg    <= 32'h0000_0000;
      end
      else if (CORE_EXC_EN_IN)
      begin
	 if (CORE_EXC_BD_IN)
	 begin
            EpcReg    <= CORE_EXC_EPC_IN - 32'd4;
	 end
	 else
	 begin
            EpcReg    <= CORE_EXC_EPC_IN;
	 end
      end
   end



   // TestRegGprReg;
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         TestRegGprReg    <= 32'h0000_0000;
      end
      // 1st priority: 
      else if (TestRegGprWrEn)
      begin
         TestRegGprReg    <= COP0_WR_DATA_IN;
      end
   end

   // TestRegCtrlReg
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         TestRegCtrlReg    <= 32'h0000_0000;
      end
      // 1st priority: 
      else if (TestRegCtrlWrEn)
      begin
         TestRegCtrlReg    <= COP0_WR_DATA_IN;
      end
   end

   
   // MUX the read data out
   // todo pipeline these read accesses
   always @*
   begin : cop0_rd_data_out_mux

      Cop0RdData = 32'h0000_0000;

      case (1'b1)

	BadVaRdEn    	: Cop0RdData = BadVaReg    ;
	CountRdEn    	: Cop0RdData = {8'h00, CountReg}    ;
	CompareRdEn  	: Cop0RdData = {8'h00, CompareReg}  ;
	StatusRdEn   	: Cop0RdData = StatusReg   ;
	CauseRdEn    	: Cop0RdData = CauseReg    ;
	EpcRdEn      	: Cop0RdData = EpcReg      ;
	PridRdEn     	: Cop0RdData = PridConst   ;  
	TestRegGprRdEn  : Cop0RdData = TestRegGprReg  ;
	TestRegCtrlRdEn : Cop0RdData = TestRegCtrlReg ;
	 
      endcase // case (COP0_RD_SEL_IN)

   end
   
      // TestRegCtrlReg
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         Cop0RdDataReg    <= 32'h0000_0000;
      end
      // 1st priority: 
      else if (COP0_RD_EN_IN)
      begin
         Cop0RdDataReg    <= Cop0RdData;
      end
   end


   
   // Instances

endmodule // COP0
