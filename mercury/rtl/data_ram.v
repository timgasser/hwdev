/* INSERT MODULE HEADER */


/*****************************************************************************/
module DATA_RAM
  #(parameter ADDR_WIDTH  = 10 )
   (
    input         CLK                   ,
    input         RST_SYNC              ,

     // Data Memory (Read and Write)
    input         RAM_CYC_IN      ,
    input         RAM_STB_IN      ,
    input  [31:0] RAM_ADR_IN      ,
    input  [ 3:0] RAM_SEL_IN      ,
    input         RAM_WE_IN       ,
    output        RAM_ACK_OUT     ,
    output [31:0] RAM_DAT_RD_OUT  ,
    input  [31:0] RAM_DAT_WR_IN    
    
    );

   parameter RAM_SIZE_BYTE = 2 ** ADDR_WIDTH;
   parameter RAM_SIZE_WD   = RAM_SIZE_BYTE >> 2;
   
   reg [31:0] 	  DatRd;
   reg [ 7:0] 	  DataRam3 [RAM_SIZE_WD-1:0]; 
   reg [ 7:0] 	  DataRam2 [RAM_SIZE_WD-1:0];
   reg [ 7:0] 	  DataRam1 [RAM_SIZE_WD-1:0];
   reg [ 7:0] 	  DataRam0 [RAM_SIZE_WD-1:0];  

   reg [7:0] 	  di [3:0];
   
   reg 		  CoreDataAckLocal   ; // RAM_ACK_OUT
//   reg [31:0] 	  CoreDatRdLocal ; // RAM_DAT_RD_OUT

   wire [3:0] 	  We = {4{RAM_WE_IN}} & RAM_SEL_IN;

   // Combinatorial assigns

   // Output assigns
   assign RAM_ACK_OUT    = CoreDataAckLocal   ;
   assign RAM_DAT_RD_OUT = DatRd;


   // Acknowledge data ram access in the next
   // clock cycle so the CORE can read the data
   always @(posedge CLK)
   begin : RAM_ACK
      if (RST_SYNC)
      begin
        CoreDataAckLocal <= 1'b0;
      end
      else if (RAM_CYC_IN && RAM_STB_IN && !CoreDataAckLocal)
      begin
         CoreDataAckLocal <= 1'b1;
      end
      else
      begin
         CoreDataAckLocal <= 1'b0;
      end
   end

// ISE needs to be helped with th BRAM instantiations, instance the 4
// byte-wide Read-first BRAMS here 

   // Byte 3
   always @(posedge CLK)
   begin : data_ram_b3
      if (RAM_CYC_IN && RAM_STB_IN)
      begin
	 if (We[3]) DataRam3[RAM_ADR_IN] <= RAM_DAT_WR_IN[31:24];
	 DatRd[31:24] <= DataRam3[RAM_ADR_IN];
      end
   end

   // Byte 2
   always @(posedge CLK)
   begin : data_ram_b2
      if (RAM_CYC_IN && RAM_STB_IN)
      begin
	 if (We[2]) DataRam2[RAM_ADR_IN] <= RAM_DAT_WR_IN[23:16];
	 DatRd[23:16] <= DataRam2[RAM_ADR_IN];
      end
   end

   // Byte 1
   always @(posedge CLK)
   begin : data_ram_b1
      if (RAM_CYC_IN && RAM_STB_IN)
      begin
	 if (We[1]) DataRam1[RAM_ADR_IN] <= RAM_DAT_WR_IN[15: 8];
	 DatRd[15: 8] <= DataRam1[RAM_ADR_IN];
      end
   end

   // Byte 0
   always @(posedge CLK)
   begin : data_ram_b0
      if (RAM_CYC_IN && RAM_STB_IN)
      begin
	 if (We[0]) DataRam0[RAM_ADR_IN] <= RAM_DAT_WR_IN[ 7: 0];
	 DatRd[ 7: 0] <= DataRam0[RAM_ADR_IN];
      end
   end

     
  
endmodule

   



   



   


   



   

