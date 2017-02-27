/* INSERT MODULE HEADER */


/*****************************************************************************/
module MULT
   (
    input  CLK                   ,
    input  RST_SYNC              ,

    // Inputs
    input         MULT_REQ_IN        ,
    input         MULT_SIGNED_IN     ,
    
    input  [31:0] MULT_A_IN          ,
    input  [31:0] MULT_B_IN          ,

//    output        MULT_BUSY_OUT         ,
    output        MULT_ACK_OUT ,
    output [63:0] MULT_RESULT_OUT       
    
    );


   // Multiplier signals
   reg   [31:0]  MultAReg;
   reg   [31:0]  MultBReg;   
   wire  [31:0]  MultAAbs;
   wire  [31:0]  MultBAbs;   
   reg   [31:0]  HiVal;      // HI_VAL_OUT
   reg   [31:0]  LoVal;      // LO_VAL_OUT
   wire  [63:0]  MultResComb;
   reg   [63:0]  MultValPipe [2:0];
   reg   [ 2:0]  MultExPipe;
   wire          MultBusy = MULT_REQ_IN | (| MultExPipe);
   wire          MultReqGated;
   
   wire 	 InvertResult;
   reg 		 InvertResultReg;

   wire [63:0] 	 MultResult ;

   // Need to invert the result if one of the operands is negative and
   // we're doing a signed multiply
   assign MultAAbs = (MULT_SIGNED_IN && MULT_A_IN[31]) ? ~MULT_A_IN + 32'd1 : MULT_A_IN;
   assign MultBAbs = (MULT_SIGNED_IN && MULT_B_IN[31]) ? ~MULT_B_IN + 32'd1 : MULT_B_IN;

   assign InvertResult = MULT_SIGNED_IN ? (MULT_A_IN[31] ^ MULT_B_IN[31]) : 1'b0;

   assign MultResComb = MultAAbs * MultBAbs;

   assign MultResult = InvertResultReg ? ~MultValPipe[0] + 64'd1 : MultValPipe[0];

   // Only start a new multiply if there isn't one in the pipe
   assign MultReqGated = MULT_REQ_IN && (3'b000 == MultExPipe);
   
   // Output assigns
//   assign MULT_BUSY_OUT = MultBusy;
   assign MULT_ACK_OUT = MultExPipe[0];
   assign MULT_RESULT_OUT = MultResult;
   
   // Multiply pulse pipeline.
   // Shift Reg Down from MULT_REQ_IN
   always @(posedge CLK)
   begin : MULTIPLY_PULSE_PIPE
      if (RST_SYNC)
      begin
         MultExPipe <= 3'b000;
      end
      // Only kick a new multiply off if there's not one in the pipeline
      else if (MultReqGated)
      begin
         MultExPipe <= 3'b100;
      end
      else if (| MultExPipe)
      begin
         MultExPipe <= {1'b0, MultExPipe[2:1]};
      end 
    end
   
   // Register whether to invert the result after the multiply (signed mult)
   always @(posedge CLK)
   begin : inv_result_reg
      if (RST_SYNC)
      begin
         InvertResultReg <= 1'b0;
      end
      else
      begin
         // Register the invert result flag
         if (MultReqGated)
         begin
            InvertResultReg <= InvertResult;
         end
      end
   end

   // Register absolute values to be multiplied
   always @(posedge CLK)
   begin : MULTIPLY_OPERAND_REG
      if (RST_SYNC)
      begin
         MultAReg <= 32'h0000_0000;
         MultBReg <= 32'h0000_0000;
      end
      else
      begin
         // If the multiply instruction is in the Ex phase, register operands
         if (MultReqGated)
         begin
            MultAReg <= MultAAbs;
            MultBReg <= MultBAbs;
         end
      end
   end

   // Absolute Multiply Value pipeline (64 bits).
   always @(posedge CLK)
   begin
      if (RST_SYNC)
      begin
         MultValPipe[2] <= 64'h0000_0000_0000_0000;	    
         MultValPipe[1] <= 64'h0000_0000_0000_0000;	    
         MultValPipe[0] <= 64'h0000_0000_0000_0000;
      end
      else if (MultBusy)
      begin
         MultValPipe[2] <= MultResComb;
	 MultValPipe[1] <= MultValPipe[2];
	 MultValPipe[0] <= MultValPipe[1];
      end
   end
  
/*****************************************************************************/

   

endmodule
/*****************************************************************************/
