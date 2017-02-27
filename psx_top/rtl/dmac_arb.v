// insert module header here
// The DMAC should have a programmable priority, but this has a fixed priority for now
module DMAC_ARB
   (
    // Clocks and resets
    input          CLK          ,
    input          EN           ,
    input          RST_SYNC     , 
    input          RST_ASYNC    , 

    // Configuration inputs (PCR register)
    input    [6:0] DMAC_PCR_CH_EN_IN    ,

// Programmable priorities not supported yet
//    input    [2:0] DMAC_PCR_CH0_PRI_IN  , // 0 is highest priority, 7 is lowest
//    input    [2:0] DMAC_PCR_CH1_PRI_IN  , 
//    input    [2:0] DMAC_PCR_CH2_PRI_IN  ,
//    input    [2:0] DMAC_PCR_CH3_PRI_IN  ,
//    input    [2:0] DMAC_PCR_CH4_PRI_IN  ,
//    input    [2:0] DMAC_PCR_CH5_PRI_IN  ,
//    input    [2:0] DMAC_PCR_CH6_PRI_IN  ,
    
    // Request and selects
    input    [6:0] DMAC_REQ_IN      ,
    input    [6:0] DMAC_ACK_IN      ,
    input          BUS_LAST_ACK_IN  ,

    // Output bus to select channel
    output   [6:0] DMAC_CH_SEL_OUT  
    
    );


   // Wires / regs
   wire [6:0]      DmacReqGated;
   
   
   reg  [6:0] 	   WbArbMask       ; // One-hot AND mask of requesters than can preempt current access
   reg  [6:0] 	   WbArbMaskReg    ; // One-hot AND mask of requesters than can preempt current access
   reg  [6:0] 	   WbArbMaskRegEn  ; 
   reg  [6:0] 	   WbArbGnt        ; // Current granted request (combinatorial)
   reg  [6:0] 	   WbArbGntReg     ; // Registered grant request
   reg   	   WbArbGntRegEn   ;

   // Combinatorial assigns
   assign DmacReqGated = DMAC_PCR_CH_EN_IN & DMAC_REQ_IN;


   // External Assigns
   assign DMAC_CH_SEL_OUT = WbArbGntReg;
   
   
   always @*
   begin : GNT_DECODE

      WbArbMask      = 7'b0000000;
      WbArbMaskRegEn = 1'b0;
      WbArbGnt       = 7'b0000000;
      WbArbGntRegEn  = 1'b0;

      // Decode if the DMA channel selected should change

      // If no channel is selected ..
      if (  (7'b0000000 == WbArbGntReg)   
      // OR if there is a higher priority requester and current requester has last BUS ACK back
        || ( (|(WbArbMaskReg & DmacReqGated)) && (|(WbArbGntReg & DmacReqGated & BUS_LAST_ACK_IN)))
            )
      begin

         // We're going to be registering a new requester
         WbArbMaskRegEn = 1'b1;
         WbArbGntRegEn  = 1'b1;

         // Priority encoder, working from 0 (highest) downwards
         if (DmacReqGated[0])
         begin
            WbArbMask      = 7'b000_0000;
            WbArbGnt       = 7'b000_0001;
         end
         else if (DmacReqGated[1])
         begin
            WbArbMask      = 7'b000_0001;
            WbArbGnt       = 7'b000_0010;
         end
         else if (DmacReqGated[2])
         begin
            WbArbMask      = 7'b000_0011;
            WbArbGnt       = 7'b000_0100;
         end
         else if (DmacReqGated[3])
         begin
            WbArbMask      = 7'b000_0111;
            WbArbGnt       = 7'b000_1000;
         end
         else if (DmacReqGated[4])
         begin
            WbArbMask      = 7'b000_1111;
            WbArbGnt       = 7'b001_0000;
         end
         else if (DmacReqGated[5])
         begin
            WbArbMask      = 7'b001_1111;
            WbArbGnt       = 7'b010_0000;
         end
         else if (DmacReqGated[6])
         begin
            WbArbMask      = 7'b011_1111;
            WbArbGnt       = 7'b100_0000;
         end
      end
   end
   

   // Register the new Grant
   always @(posedge CLK or posedge RST_ASYNC)
   begin : GNT_REG
      if (RST_ASYNC)
      begin
         WbArbGntReg  <= 7'b000_0000;
      end
      else if (RST_SYNC)
      begin
         WbArbGntReg  <= 7'b000_0000;
      end
      else if (EN && WbArbGntReg)
      begin
         WbArbGntReg  <= WbArbGnt;
      end
   end
   
   // Register the new Grant Mask for higher priority new requesters
   always @(posedge CLK or posedge RST_ASYNC)
   begin : GNT_MASK_REG
      if (RST_ASYNC)
      begin
         WbArbMaskReg <= 7'b000_0000;
      end
      else if (RST_SYNC)
      begin
         WbArbMaskReg <= 7'b000_0000;
      end
      else if (EN && WbArbMaskRegEn)
      begin
         WbArbMaskReg <= WbArbMask;
      end
   end
   
endmodule
