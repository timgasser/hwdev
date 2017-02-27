/* INSERT MODULE HEADER */


/*****************************************************************************/

module WB_SLAVE_TRACE
   #(parameter string FILE = "",
     parameter VERBOSE     =  0  // 0 = ERROR only, 1 = ERROR and INFO, 
     )                           // 2 = ERROR, INFO, DEBUG
   (
    input  CLK                   ,
    input  RST_SYNC              ,
   
    // Wishbone interface
    input      [31:0] WB_ADR_IN      ,
    input             WB_CYC_IN      ,
    input             WB_STB_IN      ,
    input             WB_WE_IN       ,
    input      [ 3:0] WB_SEL_IN      ,
    input      [ 2:0] WB_CTI_IN      ,
    input      [ 1:0] WB_BTE_IN      ,
    input             WB_STALL_IN    ,
    input             WB_ACK_IN      ,
    input             WB_ERR_IN      ,
    input      [31:0] WB_DAT_RD_IN   ,
    input      [31:0] WB_DAT_WR_IN    
   
    );

   // Include the definitions of BTE and CTI   
`include "wb_defs.v"
`include "cpu_defs.v"
   
   ////////////////////////////////////////////////////////////////////////////
   // Wires / regs

   int                inFile;
   int                lineNum;

   int                returnVal; 
   
   wire               WbReadAddrStb      ;
   wire               WbReadDataStb      ;
   wire               WbWriteAddrDataStb ;
   

   reg                WbWeReg;
   
   ////////////////////////////////////////////////////////////////////////////
   // Internal assigns

   // Generate Address and Data Phase strobes
   assign WbReadAddrStb       = WB_CYC_IN & WB_STB_IN & ~WB_WE_IN & ~WB_STALL_IN;
   assign WbReadDataStb       = WB_CYC_IN & WB_ACK_IN;
   assign WbWriteAddrDataStb  = WB_CYC_IN & WB_STB_IN &  WB_WE_IN & ~WB_STALL_IN;

   // Use 4-state variable to pick up any Xs
   logic [31:0]       DutAddressQ  [$];
   logic              DutWrRdbQ    [$];
   logic [31:0]       DutRdDataQ   [$]; 
   logic [31:0]       DutWrDataQ   [$]; 

   logic [31:0]       DutAddress ;
   logic              DutWrRdb   ;
   logic [31:0]       DutData    ; 
   
   logic [31:0]       RefAddress      ;
   logic [31:0]       RefData         ; 
   string             RefWrRdbString  ;
   logic              RefWrRdb        ;

   logic [31:0]       LastRefAddress  ;

   bit                CheckFail = 0;
   
   // Store the Address phase FIFO values
   always @(negedge CLK)
   begin : ADDR_PHASE_PUSH
      if ( (0 === RST_SYNC) && 
           (WbReadAddrStb || WbWriteAddrDataStb) )
      begin
         if (2 == VERBOSE) $display("[DEBUG] ADDR FIFO push. Addr = 0x%x, WrRdb = 0x%x, WrData = 0x%x at time %t",
                                    WB_ADR_IN, WB_WE_IN, WB_DAT_WR_IN, $time);
         DutAddressQ.push_front(WB_ADR_IN);
         DutWrRdbQ.push_front(WB_WE_IN);
         DutWrDataQ.push_front(WB_DAT_WR_IN);
      end
   end
   
   // Store the Data Phase values
   always @(negedge CLK)
   begin : DATA_PHASE_PUSH
      if (0 === RST_SYNC)
      begin
         if (WbReadDataStb)
         begin
            if (2 == VERBOSE) $display("[DEBUG] DATA FIFO push. RdData = 0x%x at time %t",
                                       WB_DAT_RD_IN, $time);
            DutRdDataQ.push_front(WB_DAT_RD_IN);
         end
      end
   end
   
   
      initial
         begin : TRACE
            
            // Wait until out of reset
            while (0 !== RST_SYNC)
               @(posedge CLK);
            
            // Open comparison file
            $display("[INFO ] Opening comparison file %s at time %t", FILE, $time);
            inFile = $fopen(FILE, "r");
            lineNum = 0;

            while (RST_SYNC)
               @(posedge CLK);

            RefAddress     = 0;
            LastRefAddress = 0;
            
            // todo ! Check the return value for the end of file
            forever
               begin : FILE_READ_LOOP

                  // Read in the reference values from the file. Some lines are duplicated
                  // (seems to be LW and delay slot), so keep reading until a new PC values is seen
                  // LW are duplicated twice for some reason in pcsx-r debugging log

                  returnVal = $fscanf(inFile, "%x %x %s ", RefAddress, RefData, RefWrRdbString);
                  lineNum++;
                  if (2 == VERBOSE) $display("[DEBUG] Read Line # %4d. Address = 0x%x, Data = 0x%x, R/W = %s at time %t",
                                             lineNum, RefAddress, RefData, RefWrRdbString, $time);

                  if ( (OPC_LB  === RefData[31:26]) || (OPC_LH  === RefData[31:26]) || // in the PCSX-R logfile
                       (OPC_LW  === RefData[31:26]) || (OPC_LBU === RefData[31:26]) || 
                       (OPC_LHU === RefData[31:26]) )
                  begin
                     returnVal = $fscanf(inFile, "%x %x %s ", RefAddress, RefData, RefWrRdbString);
                     lineNum++;
                     if (2 == VERBOSE) $display("[DEBUG] RefData = 0x%x => Reading second Load Line # %4d. Address = 0x%x, Data = 0x%x, R/W = %s at time %t",
                                                RefData[31:26], lineNum, RefAddress, RefData, RefWrRdbString, $time);
                  end
                  
                  // Convert "R" or "W" string into 1 bit logic type
                  if ("R" == RefWrRdbString)
                  begin
                     RefWrRdb = 1'b0;
                  end
                  else if ("W" == RefWrRdbString)
                  begin
                     RefWrRdb = 1'b1;
                  end
                  else
                  begin
                     $display("[ERROR] Rd/Wr not recognised. String = %s. Line = %5d, time = %t",
                              RefWrRdbString, lineNum, $time);
                     CheckFail = 1;
                  end
                    
                  // Print out values read in
                  if (2 == VERBOSE)
                  begin
                     $display("[DEBUG] Read line %5d. Addr = 0x%x, Data = 0x%x, WrRdb = 0x%x."
                              , lineNum, RefAddress, RefData, RefWrRdb);
                  end
                     
                  // Check for end of file, jump out if so.
                  if (!returnVal) 
                  begin
                     $display("[INFO ] EOF reached for %s at time %t", FILE, $time);
                     break;
   	             $fclose(inFile);
                  end               
                  
                  // Wait for there to be an entry in all FIFOs
                  while (!( (DutAddressQ.size() != 0) &&
                            (DutWrRdbQ.size()   != 0) &&
                            (DutRdDataQ.size()  != 0) &&
                            (DutWrDataQ.size()  != 0) 
                            ))
                     @(negedge CLK);

                  if (2 == VERBOSE) $display("[DEBUG] Popping Addr and Data FIFOs at time %t", $time);
                  
                  // Address phase. Store DUT values
                  DutAddress  = DutAddressQ.pop_back();
                  DutWrRdb    = DutWrRdbQ.pop_back();

                  // Check read/write match
                  if (RefWrRdb !== DutWrRdb)
                  begin
                     $display("[ERROR] Rd/Wr mismatch. Expected = 0x%x, Actual = 0x%x. Line = %5d, time = %t",
                              RefWrRdb, DutWrRdb, lineNum, $time);
                     CheckFail = 1;
                  end
                  else if (2 == VERBOSE)
                  begin
                     $display("[DEBUG] Rd/Wr match. Expected = 0x%x, Actual = 0x%x. Line = %5d, time = %t",
                              RefWrRdb, DutWrRdb, lineNum, $time);
                  end
                  
                  // Check Address match (Read and Write)
                  if (RefAddress !== DutAddress)
                  begin
                     $display("[ERROR] Addr mismatch. Expected = 0x%x, Actual = 0x%x. Line = %5d, time = %t",
                              RefAddress, DutAddress, lineNum, $time);
                     CheckFail = 1;
                  end
                  else if (2 == VERBOSE)
                  begin
                     $display("[DEBUG] Addr match. Expected = 0x%x, Actual = 0x%x. Line = %5d, time = %t",
                              RefAddress, DutAddress, lineNum, $time);
                  end

                  if (RefWrRdb)
                  begin
                     DutData = DutWrDataQ.pop_back();
                     DutRdDataQ.pop_back(); // discard read data for write
                  end
                  else
                  begin
                     DutWrDataQ.pop_back(); // discard write data in read
                     DutData = DutRdDataQ.pop_back();
                 end
                                   
                  // Check Data match (Read and Write)
                  if (RefData !== DutData)
                  begin
                     $display("[ERROR] Data mismatch. Expected = 0x%x, Actual = 0x%x. Line = %5d, time = %t",
                              RefData, DutData, lineNum, $time);
                     CheckFail = 1;
                  end  
                  else if (2 == VERBOSE)
                  begin
                     $display("[DEBUG] Data match. Expected = 0x%x, Actual = 0x%x. Line = %5d, time = %t",
                              RefData, DutData, lineNum, $time);
                  end

                  if (CheckFail)
                  begin
                     $display("[ERROR] Trace Comparison failed. Line = %5d, time = %t",
                              lineNum, $time);
                     repeat (64)
                        @(posedge CLK);
                     $display("[ERROR] Trace Comparison failed. Finishing sim at time %t", $time);
                     $finish();
                  end
                              
                  LastRefAddress = RefAddress;
                  
               end
            
         end
   

   
endmodule
