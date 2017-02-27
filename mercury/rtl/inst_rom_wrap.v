/* INSERT MODULE HEADER  - Wishbone wrapper around ROM instance */

module INST_ROM_WRAP 
    (
    input  CLK                   ,
    input  RST_SYNC              ,
    
     // Wishbone interface
    input             WB_CYC_IN      , // Master: High while whole transfer is in progress
    input             WB_STB_IN      , // Master: High while the current beat in burst is active
    input      [31:0] WB_ADR_IN      , // Master: Address of current transfer
    output            WB_ACK_OUT     , // Slave:  Acknowledge of transaction
    output     [31:0] WB_DAT_RD_OUT    // Slave:  Read data
    
    );

   reg 		      RomInstAck;

   assign WB_ACK_OUT = RomInstAck;
   
   // Generate an ACK back to the core a cycle after the read enable is asserted
   // All instruction reads are on teh negedge of the clock
   always @(posedge CLK)
   begin : core_inst_ack
      if (RST_SYNC)
      begin
	 RomInstAck <= 1'b0;
      end
      else
      begin
	 if (WB_CYC_IN && WB_STB_IN)
	 begin
	    RomInstAck <= 1'b1;
	 end
      end
   end
  
   INST_ROM inst_rom 
      (
       .clk   (CLK                      ), // 
       .en    (WB_CYC_IN && WB_STB_IN   ), // 
       .addr  (WB_ADR_IN[14:2]          ), // [12:0] (word-aligned)
       .data  (WB_DAT_RD_OUT            )  // [31:0]
       );
   
endmodule
