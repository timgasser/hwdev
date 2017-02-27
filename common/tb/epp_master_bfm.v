// BFM for EPP interface (verified with Digilent EPP Slave)

module EPP_MASTER_BFM (

    // EPP-side ports
    inout        [ 7:0]  EPP_DATA_INOUT  ,
    output reg       	 EPP_WRITE_OUT   ,
    output reg       	 EPP_ASTB_OUT    ,
    output reg       	 EPP_DSTB_OUT    ,
    input            	 EPP_WAIT_IN     ,

    // These are unused
    input            	 EPP_INT_IN      , 
    output reg        	 EPP_RESET_OUT   

);
`include "epp_bus_bridge_defs.v"
   
   parameter EPP_MIN_DELAY = 100;
   parameter EPP_MAX_DELAY = 255;
   
   reg [7:0] EppData;
   reg       EppDataDriveEn;

   assign EPP_DATA_INOUT = EppDataDriveEn ? EppData : 8'hzz;
   

  // Zero outputs initially
   initial
      begin
	 EPP_RESET_OUT   = 1'b0;
	 
	 EPP_WRITE_OUT   = 1'b1; // All active low
	 EPP_ASTB_OUT    = 1'b1;
	 EPP_DSTB_OUT    = 1'b1;

	 EppDataDriveEn  = 1'b0;
	 EppData         = 8'h00;
      end

   // Always check to see if there is any contention on the bus
   always @*
   begin : DATA_CONTENTION_CHECK

      if (EPP_DATA_INOUT === 8'hX) 
	 begin
	    $display("[ERROR] EPP Data contention at time %t", $time);
	    $display("[FAIL ] Test FAILED at time %t", $time);
	    #100;
	    $finish();
	 end
   end

   // Todo ! Add a random delay here
      task automatic doEppDelay ();
	 #100ns;
      endtask // automatic


   //************************************************************************************************
   // BUS Access Tasks
   //************************************************************************************************
   task automatic doBusVerify(input [31:0] BusAddr, output bit passFail, input [1:0] BusSize = ERW_SIZE_WORD, input [31:0] Mask = 32'hffff_ffff);

      int writeData;
      int readData;
     
      writeData = $urandom();

      doBusWrite(BusAddr, writeData, BusSize);
      doBusRead(BusAddr, readData, BusSize);

       if ((writeData & Mask) === readData) 
      begin
	 $display("[INFO ] EPP Data readback of Address 0x%x verified at time %t", BusAddr, $time);
	 passFail = 1;
      end
      else
      begin
	 $display("[ERROR] EPP Data readback of Address 0x%x at time %t", BusAddr, $time);
	 passFail = 0;
      end

   endtask
   

   task automatic doBusWrite(input [31:0] BusAddr, input [31:0] BusWriteData, input [1:0] BusSize);

      $display("[INFO ] BUS Write, Address = 0x%x, Data = 0x%x, Size = %d at time %t", BusAddr, BusWriteData, BusSize, $time);
      
      // Write Address into EPP Regs
      doEppRegWrite(ERW_ADDR0, BusAddr[ 7: 0]);
      doEppRegWrite(ERW_ADDR1, BusAddr[15: 8]);
      doEppRegWrite(ERW_ADDR2, BusAddr[23:16]);
      doEppRegWrite(ERW_ADDR3, BusAddr[31:24]);

      // Write Data into EPP Data Regs. Align the data in little-endian according to size
      case (BusSize)
	ERW_SIZE_BYTE  :
	   begin
	      doEppRegWrite(ERW_DATA0, BusWriteData[ 7: 0]);
	   end
	
	ERW_SIZE_2BYTE :
	   begin
	      doEppRegWrite(ERW_DATA0, BusWriteData[ 7: 0]);
	      doEppRegWrite(ERW_DATA1, BusWriteData[15: 8]);
	   end
	
	ERW_SIZE_WORD  :
	   begin
	      doEppRegWrite(ERW_DATA0, BusWriteData[ 7: 0]);
	      doEppRegWrite(ERW_DATA1, BusWriteData[15: 8]);
	      doEppRegWrite(ERW_DATA2, BusWriteData[23:16]);
	      doEppRegWrite(ERW_DATA3, BusWriteData[31:24]);
	   end
      endcase
      
	
      // Trigger the write
      doEppRegWrite(ERW_TRANS, (8'h00 | 1'b0 << ERW_TRANS_RWB | BusSize << ERW_TRANS_SIZE_LSB));

   endtask 
   
   task automatic doBusRead(input [31:0] BusAddr, output [31:0] BusReadData, input [1:0] BusSize);
      
      // Write Address into EPP Regs
      doEppRegWrite(ERW_ADDR0, BusAddr[ 7: 0]);
      doEppRegWrite(ERW_ADDR1, BusAddr[15: 8]);
      doEppRegWrite(ERW_ADDR2, BusAddr[23:16]);
      doEppRegWrite(ERW_ADDR3, BusAddr[31:24]);

      // Trigger the read
      doEppRegWrite(ERW_TRANS, (8'h00 | 1'b1 << ERW_TRANS_RWB | BusSize << ERW_TRANS_SIZE_LSB));
      
      case (BusSize)
	ERW_SIZE_BYTE  :
	   begin
	      doEppRegRead(ERW_DATA0, BusReadData[ 7: 0]);
	      BusReadData[31: 8] = 24'd0;
	   end
	ERW_SIZE_2BYTE :
	   begin
 	      doEppRegRead(ERW_DATA0, BusReadData[ 7: 0]);
	      doEppRegRead(ERW_DATA1, BusReadData[15: 8]);
	      BusReadData[31:16] = 16'd0;
	   end
	ERW_SIZE_WORD  :
	   begin
	      doEppRegRead(ERW_DATA0, BusReadData[ 7: 0]);
	      doEppRegRead(ERW_DATA1, BusReadData[15: 8]);
	      doEppRegRead(ERW_DATA2, BusReadData[23:16]);
	      doEppRegRead(ERW_DATA3, BusReadData[31:24]);
	   end
      endcase
      
      $display("[INFO ] BUS Read, Address = 0x%x, Data = 0x%x, Size = %d at time %t", BusAddr, BusReadData, BusSize, $time);

   endtask 
   //************************************************************************************************


   //************************************************************************************************
   // EPP Register Tasks
   //************************************************************************************************
   // EPP Regs Write-Read-Verify
   task automatic doEppRegVerify(input bit [7:0] EppRegAddr, output bit passFail, input bit [7:0] Mask = 8'hff);

      byte writeData;
      byte readData;
      
      writeData = $urandom();

      doEppAddrWrite(EppRegAddr);
      
      doEppDataWrite(writeData);
      doEppDataRead(readData);

      if ((writeData & Mask) === readData) 
      begin
	 $display("[INFO ] EPP Data readback of Address 0x%x verified at time %t", EppRegAddr, $time);
	 passFail = 1;
      end
      else
      begin
	 $display("[ERROR] EPP Data readbackof Address 0x%x FAILED at time %t", EppRegAddr, $time);
 	 passFail = 0;
     end

   endtask // automatic
   
   // EPP Regs Data Write
   task automatic doEppRegWrite(input bit [7:0] RegAddr, input bit [7:0] RegWriteData);
      doEppAddrWrite(RegAddr);
      doEppDataWrite(RegWriteData);
   endtask // automatic
   
   // EPP Regs Data Read
   task automatic doEppRegRead(input  bit [7:0] RegAddr, output bit [7:0] RegReadData);
      doEppAddrWrite(RegAddr);
      doEppDataRead(RegReadData);
   endtask // automatic

   //************************************************************************************************

   //************************************************************************************************
   // EPP Address/Data Tasks
   //************************************************************************************************

   // EPP Address Write-Read-Verify
   task automatic doEppAddrVerify();
      byte writeData;
      byte readData;
      
      writeData = $urandom();

      doEppAddrWrite(writeData);
      doEppAddrRead(readData);

      	 if (writeData === readData) 
	 begin
	    $display("[INFO ] EPP Address readback verified at time %t", $time);
	 end
	 else
	 begin
	    $display("[ERROR] EPP Address readback FAILED at time %t", $time);
	 end

   endtask 

   // EPP Data Write-Read-Verify
   task automatic doEppDataVerify(input bit [7:0] EppAddr);

      byte writeData;
      byte readData;
      
      writeData = $urandom();

      doEppAddrWrite(EppAddr);
      
      doEppDataWrite(writeData);
      doEppDataRead(readData);

      if (writeData === readData) 
      begin
	 $display("[INFO ] EPP Data readback of Address 0x%x verified at time %t", EppAddr, $time);
      end
      else
      begin
	 $display("[ERROR] EPP Data readbackof Address 0x%x FAILED at time %t", EppAddr, $time);
      end

   endtask
      
   // EPP Data Write
   task automatic doEppDataWrite(input bit [7:0] EppWriteData);

      doEppDelay();
      EppData        = EppWriteData;
      EppDataDriveEn = 1'b1;
      EPP_WRITE_OUT  = 1'b0;
      
      doEppDelay();
      EPP_DSTB_OUT = 1'b0;

      @(posedge EPP_WAIT_IN);
      doEppDelay();
      EPP_WRITE_OUT  = 1'b1;
      EPP_DSTB_OUT   = 1'b1;
      EppDataDriveEn = 1'b0;

      @(negedge EPP_WAIT_IN);
      doEppDelay();
      
   endtask

   // EPP Address Write
   task automatic doEppAddrWrite(input bit [7:0] EppWriteAddr);

      doEppDelay();
      EppData        = EppWriteAddr;
      EppDataDriveEn = 1'b1;
      EPP_WRITE_OUT  = 1'b0;
      
      doEppDelay();
      EPP_ASTB_OUT = 1'b0;

      @(posedge EPP_WAIT_IN);
      doEppDelay();
      EPP_WRITE_OUT  = 1'b1;
      EPP_ASTB_OUT = 1'b1;
      EppDataDriveEn = 1'b0;

      @(negedge EPP_WAIT_IN);
      doEppDelay();
      
   endtask

   // EPP Data Read
   task automatic doEppDataRead(output bit [7:0] EppReadData);

      doEppDelay();
      EPP_WRITE_OUT  = 1'b1;
      
      doEppDelay();
      EPP_DSTB_OUT = 1'b0;

      @(posedge EPP_WAIT_IN);
      doEppDelay();
      EppReadData = EPP_DATA_INOUT; // Return data bus value
      EPP_DSTB_OUT = 1'b1;

      @(negedge EPP_WAIT_IN);
      doEppDelay();
      
   endtask

   // EPP Address Read
   task automatic doEppAddrRead(output bit [7:0] EppReadAddr);

      doEppDelay();
      EPP_WRITE_OUT  = 1'b1;
      
      doEppDelay();
      EPP_ASTB_OUT = 1'b0;

      @(posedge EPP_WAIT_IN);
      doEppDelay();
      EppReadAddr = EPP_DATA_INOUT; // Return data bus value
      EPP_ASTB_OUT = 1'b1;

      @(negedge EPP_WAIT_IN);
      doEppDelay();
      
   endtask

   //************************************************************************************************

endmodule // EPP_MASTER_BFM

