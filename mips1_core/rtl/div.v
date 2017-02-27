/* INSERT MODULE HEADER */


/*****************************************************************************/
module DIV
   (
    input  CLK                   ,
    input  RST_SYNC              ,

    // Inputs
    input         DIV_REQ_IN           ,
    input         DIV_SIGNED_IN        ,
    
    input  [31:0] DIV_DIVIDEND_IN      ,
    input  [31:0] DIV_DIVISOR_IN       ,

//    output        DIV_BUSY_OUT         ,
    output        DIV_ACK_OUT          ,
    output [31:0] DIV_QUOTIENT_OUT     ,   
    output [31:0] DIV_REMAINDER_OUT       
    
    );

   parameter [5:0] DIV_LATENCY = 6'd32;


// * Simplest way is to remember the signs
// * Convert the dividend and divisor to positive
//    -- Obtain the 2's complement if they are negative
// * Do the unsigned division
// * Compute the signs of the quotient and remainder
//   -- Quotient sign = Dividend sign XOR Divisor sign
//   -- Remainder sign = Dividend sign
// * Negate the quotient and remainder if their sign is negative
//   -- Obtain the 2's complement to convert them to negative
//

   
   // wires and regs
//   wire 	  DivRfd;
   reg 		  DivRequested;

   reg 		  DivSignedReg;
   reg [31:0] 	  DivDividendReg;
   reg [31:0] 	  DivDivisorReg;
   
   reg 		  DivInProgress;
   reg [5:0] 	  DivCounter;

   wire [31:0] 	  DividendAbs;
   wire [31:0] 	  DivisorAbs;

   wire [31:0] 	  QuotientAbs;
   wire [31:0] 	  RemainderAbs;
   
   wire [31:0] 	  Quotient;
   wire [31:0] 	  Remainder;
   
   reg  [31:0] 	  QuotientReg ; // DIV_QUOTIENT_OUT
   reg  [31:0] 	  RemainderReg; // DIV_REMAINDER_OUT


   reg  [63:0] 	  div_quot_r;   
   wire [31:0] 	  div_tmp;
//   reg   [5:0] 	  div_cntr;
   
//   reg  [31:0] 	  Quotient;  // DIV_QUOTIENT_OUT
//   reg  [31:0] 	  Remainder; // DIV_REMAINDER_OUT

   reg 		  DivReqReg;      // registered DIV_REQ_IN
   wire           DivReqRedge;    // Rising Edge of DIV_REQ_IN
   wire           DivInputRegEn;  // Rising edge of DIV_REQ_IN qualified with no ongoing division
   reg            DivCoreLd;      // 1 cycle after input operands registered, store in division core
   reg [63:0] 	  QuotRemReg;
 

   wire 	  DivResultRegEn;
   reg  	  DivResultValid;

   // Combinatorial logic
//   assign DivResultValid = (DivCounter == 6'd0);

   // Detect a rising edge of the REQ_IN, and qualify it with a zero counter
   // (no ongoing division)
   assign DivReqRedge   = DIV_REQ_IN & ~DivReqReg;
   assign DivInputRegEn = DivReqRedge & (DivCounter == 6'd0); 
   
   assign DivResultRegEn = (DivCounter == 6'd0) & DivInProgress;

   assign DividendAbs = (DivSignedReg && DivDividendReg[31]) ? ~DivDividendReg + 32'd1 : DivDividendReg;
   assign DivisorAbs  = (DivSignedReg && DivDivisorReg [31]) ? ~DivDivisorReg  + 32'd1 : DivDivisorReg ;

   assign QuotientAbs  = QuotRemReg[31: 0];
   assign RemainderAbs = QuotRemReg[63:32];
   
   assign Quotient  = (DivSignedReg && (DivDividendReg[31] ^ DivDivisorReg [31])) ? 
		      ~QuotientAbs + 32'd1 : 
		       QuotientAbs;

   assign Remainder = (DivSignedReg && DivDividendReg[31]) ?
		      ~RemainderAbs + 32'd1:
		       RemainderAbs;

   // Output assigns
//   assign DIV_BUSY_OUT         = DivInProgress ;
   assign DIV_ACK_OUT = DivResultValid;

   assign DIV_QUOTIENT_OUT  =  QuotientReg ;  // DIV_QUOTIENT_OUT
   assign DIV_REMAINDER_OUT =  RemainderReg;  // DIV_REMAINDER_OUT


   // Register Request to detect a rising edge
   always @(posedge CLK)
   begin : div_req_reg
      if (RST_SYNC)
      begin
	 DivReqReg <= 1'b0;
      end
      else
      begin
	 DivReqReg <= DIV_REQ_IN;
      end
   end

   // Register the request a second time, to load division core once the input
   // operands are stored with the rising edge pulse
   always @(posedge CLK)
   begin : div_core_ld_reg
      if (RST_SYNC)
      begin
	 DivCoreLd <= 1'b0;
      end
      else
      begin
	 DivCoreLd <= DivReqRedge;
      end
   end

   // Send valid signal a cycle after calculation completes
   always @(posedge CLK)
   begin : div_result_valid_reg
      if (RST_SYNC)
      begin
	 DivResultValid <= 1'b0;
      end
      else
      begin
	 DivResultValid <= DivResultRegEn;
      end
   end


   // Store the original dividend and divisor
   // (before converting to absolute)
   always @(posedge CLK)
   begin : div_inputs_reg
      if (RST_SYNC)
      begin
	 DivDividendReg <= 32'h0000_0000;
	 DivDivisorReg  <= 32'h0000_0000;
      end
      else
      begin
         // Register the invert result flag
         if (DivInputRegEn)
         begin
	    DivDividendReg <= DIV_DIVIDEND_IN;
	    DivDivisorReg  <= DIV_DIVISOR_IN ;
         end
      end
   end

   // Register whether this is a signed division so 
   // the signs can be restored later
   always @(posedge CLK)
   begin : div_signed_reg
      if (RST_SYNC)
      begin
	 DivSignedReg <= 1'b0;
      end
      else
      begin
         // Register the invert result flag
         if (DivInputRegEn)
         begin
	    DivSignedReg <= DIV_SIGNED_IN;
         end
      end
   end

   // Keep track of when a division is running
   always @(posedge CLK)
   begin : div_in_progress_reg
      if (RST_SYNC)
      begin
         DivInProgress <= 1'b0;
      end
      else
      begin
         if (DivCoreLd)
         begin
	    DivInProgress <= 1'b1;
         end
 	 else if (DivCounter == 6'd0)
	 begin
	    DivInProgress <= 1'b0;
	 end
     end
   end
   
   // Need to count clock cycles while the division is running
   always @(posedge CLK)
   begin : div_counter
      if (RST_SYNC)
      begin
         DivCounter <= 6'd0;
      end
      else
      begin
         // Load the timer on the same cycle the input operands are registered.
         // The DivInProgress is set on the same cycle
         if (DivCoreLd)
         begin
	    DivCounter <= DIV_LATENCY;
         end
	 else if (DivInProgress && (| DivCounter ))
	 begin
	    DivCounter <= DivCounter - 6'd1;
	 end
      end
   end
   
   // Register the outputs one cycle before the valid goes out
   always @(posedge CLK)
   begin : div_outputs_reg
      if (RST_SYNC)
      begin
	 QuotientReg  <= 32'h0000_0000;
	 RemainderReg <= 32'h0000_0000;
      end
      else if (DivResultRegEn)
      begin
	 QuotientReg   <= Quotient;
	 RemainderReg  <= Remainder;
      end
   end

   
   // Divider taken from http://www.ece.lsu.edu/ee3755/2002/l07.html with some small changes for synthesis
   
   wire [33:0] 	 diff = QuotRemReg[63:31] - {1'b0, DivisorAbs};
   
  
   always @( posedge CLK ) 
   begin
      if (RST_SYNC)
      begin
	 QuotRemReg <= 64'h0000_0000_0000_0000;
      end
      else if (DivCoreLd) 
      begin
	 QuotRemReg <= {32'd0, DividendAbs};
      end
      else  if (| DivCounter)
      begin
         if( diff[33] )
	 begin
            QuotRemReg <= {QuotRemReg[62:0],1'd0};
	 end
         else
	 begin
            QuotRemReg <= {diff[32:0],QuotRemReg[30:0],1'd1};
         end
      end
   end
   
endmodule
/*****************************************************************************/
