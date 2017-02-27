// EPP Slave Interface
//
// This EPP Slave is intended to be connected to the EPP port on the
// Digilent USB port. It allows the Digilent Adept SW on the PC to
// access internal FPGA state.

// Note the EPP Data is a bi-directional, and the drive setting needs
// to be reset asynchronously to avoid any contention

// All input signals from the EPP interface are asynchronous to the FPGA
// core clock, and are double-flopped as they are single bit signals. They
// are converted to active high before the CDC.

// The WAIT signal is a bad name, as it indicates either the write has 
// completed, or that the read data has been driven onto the DATA bus (and
// is sampled on the rising edge of the STB which is currently asserted.

// The FSM just implements the 4-phase REQ/ACK handshake on the EPP side,
// and doesn't distinguish between address/data or read/write.

module EPP_SLAVE
   (
    input           CLK        ,
    input           EN         ,
    input           RST_SYNC   ,
    input           RST_ASYNC  ,

    // Internal Interface
    output 	   REGS_WRITE_REQ_OUT  ,
    output 	   REGS_READ_REQ_OUT   ,
    output 	   REGS_ADDR_SEL_OUT   ,
    output 	   REGS_DATA_SEL_OUT   ,

    input  	   REGS_READ_ACK_IN    ,
    input  	   REGS_WRITE_ACK_IN   ,

    input    [7:0] REGS_READ_DATA_IN   ,
    output   [7:0] REGS_WRITE_DATA_OUT ,
    
    // EPP-side ports
    inout   [ 7:0] EPP_DATA_INOUT , // Bi directional : Drive when reading, and WAIT output high
    input          EPP_WRITE_IN   , // Input  : Active low Write (RWB) signal
    input          EPP_ASTB_IN    , // Input  : Active low Address Strobe
    input          EPP_DSTB_IN    , // Input  : Active low Data Strobe
    output         EPP_WAIT_OUT   , // Output : Active low WAIT.1 = Write completed, or Read data driven onto Data Bus. 

    // These are unused
    output         EPP_INT_OUT    , 
    input          EPP_RESET_IN   

   );

  
   // typedefs
  
   // EPP 4-phase async handshake
   parameter EPPFSM_IDLE   = 2'h0;
   parameter EPPFSM_REQ    = 2'h1;
   parameter EPPFSM_ACK    = 2'h2;
   
   
   // Includes

   // Wire and Reg definitions

   // State machine current and next states
   reg [ 1:0] EppfsmStateCur;  
   reg [ 1:0] EppfsmStateNxt;

   // ----- State machine inputs -----
   reg        CRxDataVld;

    // USB-side. Note these are active high signals generated from the
    // mixture of high and low USB-side ports asynchronously, and they 
    // are then double-flopped.
   wire       EppAddrRd;
   wire       EppAddrWr;
   wire       EppDataRd;
   wire       EppDataWr;

   // ----- State machine outputs -----
   // Core-side
   reg        DataReqNxt;
   reg        DataReq;
   // Internal
//   reg        EppDriveEn;
   reg        EppDataRegEn;
   // USB-side
   reg        EppWaitNxt; // reg'd
   reg        EppWait;    


   // ----- Core-side wires -----
   // Resynchronisation Pipes for USB wires
   reg [1:0]  EppRwbPipe;
   reg [1:0]  EppAstbPipe;
   reg [1:0]  EppDstbPipe;

   

   // Internal assigns/wires
   wire       EppRwb     = EppRwbPipe[0]  ;
   wire       EppAddrStb = EppAstbPipe[0] ;
   wire       EppDstbStb = EppDstbPipe[0] ;

   wire       EppStb     = EppAddrStb | EppDstbStb;

   wire       DataAck    = REGS_READ_ACK_IN | REGS_WRITE_ACK_IN;
   
   wire       EppTxDataRegEn = DataReq & DataAck &  EppRwb  ;
   wire       EppRxDataRegEn = EppDataRegEn      & ~EppRwb  ;

   reg 	[7:0] EppTxDataReg;
   reg 	[7:0] EppRxDataReg;
   
   // External assigns/wires

   // Core-side ports
   assign REGS_WRITE_REQ_OUT = DataReq & ~EppRwb ;
   assign REGS_READ_REQ_OUT  = DataReq &  EppRwb ;
   assign REGS_ADDR_SEL_OUT  = EppAddrStb        ;
   assign REGS_DATA_SEL_OUT  = EppDstbStb        ;

   assign REGS_WRITE_DATA_OUT = EppRxDataReg;
   
   // USB-side ports
   assign EPP_DATA_INOUT = (EppWait & EppRwb & EppStb) ? EppTxDataReg : 8'hZZ;
   assign EPP_WAIT_OUT   = EppWait;
   assign EPP_INT_OUT    = 1'b0;

   





   //**************************************************************************
   //* Double-flop the inputs from the EPP port
   //**************************************************************************
   
   // Double-flop the EPP WRITE (RWB) signal
   always @(posedge CLK or posedge RST_ASYNC)
   begin : EPP_RWB_PIPE
      if (RST_ASYNC)
      begin
	 EppRwbPipe <= 2'b00;
      end
      else if (RST_SYNC)
      begin
	 EppRwbPipe <= 2'b00;
      end
      else if (EN) 
      begin
	 EppRwbPipe[1:0] <= {EPP_WRITE_IN, EppRwbPipe[1]};
      end
   end

   // Double-flop the EPP Active-low ASTB signal. Invert to Active high.
   always @(posedge CLK or posedge RST_ASYNC)
   begin : EPP_ASTB_PIPE
      if (RST_ASYNC)
      begin
	 EppAstbPipe <= 2'b00;
      end
      else if (RST_SYNC)
      begin
	 EppAstbPipe <= 2'b00;
      end
      else if (EN)
      begin
	 EppAstbPipe[1:0] <= {~EPP_ASTB_IN, EppAstbPipe[1]};
      end
   end

   // Double-flop the EPP Active-low ASTB signal. Invert to Active high
   always @(posedge CLK or posedge RST_ASYNC)
   begin : EPP_DSTB_PIPE
      if (RST_ASYNC)
      begin
	 EppDstbPipe <= 2'b00;
      end
      else if (RST_SYNC)
      begin
	 EppDstbPipe <= 2'b00;
      end
      else if (EN)
      begin
	 EppDstbPipe[1:0] <= {~EPP_DSTB_IN, EppDstbPipe[1]};
      end
   end

   //**************************************************************************



   //**************************************************************************
   //* Register the incoming and outgoing EPP data
   //**************************************************************************
   // Register incoming data according to FSM output
   always @(posedge CLK or posedge RST_ASYNC)
   begin : RX_DATA_REG
      if (RST_ASYNC)
      begin
	 EppRxDataReg <= 8'h00;
      end
      else if (RST_SYNC)
      begin
	 EppRxDataReg <= 8'h00;
      end
      else if (EN)
      begin
	 if (EppRxDataRegEn)
	 begin
	    EppRxDataReg <= EPP_DATA_INOUT;
	 end
      end
   end

    // Register outgoing data according to REQ/ACK on core-side
   always @(posedge CLK or posedge RST_ASYNC)
   begin : TX_DATA_REG
      if (RST_ASYNC)
      begin
	 EppTxDataReg <= 8'h00;
      end
      else if (RST_SYNC)
      begin
	 EppTxDataReg <= 8'h00;
      end
      else if (EN)
      begin
	 if (EppTxDataRegEn)
	 begin
	    EppTxDataReg <= REGS_READ_DATA_IN;
	 end
      end
   end
   //**************************************************************************



   //**************************************************************************
   //* 4-Phase state machine
   //**************************************************************************
   always @*
   begin : EPPFSM_ST

      // Default values - default next state
      EppfsmStateNxt = EppfsmStateCur;

      // Core-side
      DataReqNxt = 1'b0;
      // Internal
      EppDataRegEn = 1'b0;
      // USB-side
      EppWaitNxt  = 1'b0; // reg'd
      
      case (EppfsmStateCur)
	
	EPPFSM_IDLE                  :
          begin
             // Current state outputs - none

	     // Data Read (Data TX)
             if (EppStb)
             begin
	        // Next state outputs
		EppDataRegEn = 1'b1;
		DataReqNxt = 1'b1;
                // Next state
		EppfsmStateNxt = EPPFSM_REQ;
	     end
	  end     

	EPPFSM_REQ          :
          begin
             // Current state outputs
	     DataReqNxt = 1'b1;
	     // Next state 
             if (DataAck)
             begin
	        // Next state outputs
		DataReqNxt = 1'b0;
		EppWaitNxt = 1'b1;
                // Next state
	   	EppfsmStateNxt = EPPFSM_ACK;
	     end
	  end     

	EPPFSM_ACK           :
          begin
	     // Outputs
             EppWaitNxt = 1'b1;
	     // Next state
	     if (!EppStb)
	     begin
		// Outputs
		EppWaitNxt = 1'b0;
		// Next state
		EppfsmStateNxt = EPPFSM_IDLE;
	     end
	  end     

        default : EppfsmStateNxt = EPPFSM_IDLE;       
      endcase // case (EppfsmStateCur)
   end
   //**************************************************************************


   //**************************************************************************
   //* Clocked process : Clocked process for registered FSM and next state
   //**************************************************************************
   always @(posedge CLK or posedge RST_ASYNC)
   begin : EPPFSM_CP
      if (RST_ASYNC)
      begin
         EppfsmStateCur  <= EPPFSM_IDLE;
	 EppWait         <= 1'b0;
	 DataReq         <= 1'b0;
      end
      else if (RST_SYNC)
      begin
         EppfsmStateCur  <= EPPFSM_IDLE;
	 EppWait         <= 1'b0;
	 DataReq         <= 1'b0;
      end
      else if (EN)
      begin
         // Clocked assignments
         EppfsmStateCur  <= EppfsmStateNxt;
	 EppWait         <= EppWaitNxt;
   	 DataReq         <= DataReqNxt;
      end
   end
   //**************************************************************************

endmodule
