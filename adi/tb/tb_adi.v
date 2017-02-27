// Block level testbench for the Adept-Digilent Interface

`timescale 1ns / 1ps

module TB_ADI ();


   parameter CLK_HALF_PERIOD = 10;  // 100MHz clock
   parameter RST_SYNC_TIME   = 21; // reset asserted for this long
   reg            Clk       ;
   reg            RstSync   ;

   // Wishbone-side interface (Master)
   wire          WbCyc 		  ;
   wire          WbStb 		  ;    
   wire   [31:0] WbAdr 		  ;
   wire   [ 3:0] WbSel 	 	  ;
   wire          WbWe  	 	  ;
   wire          WbStall          ;
   wire          WbAck      	  ;  
   wire   [31:0] WbDatWr  	  ;
   wire   [31:0] WbDatRd          ;    

    // Bus interface 
   wire  [31:0] BusAddr   	;
   wire         BusReq    	;
   wire         BusAck    	;
   
   wire         BusRwb 	  	;     
   wire  [ 1:0] BusSize         ;
   wire  [31:0] BusWriteData    ;
   wire  [31:0] BusReadData     ;   
   
   // Internal Interface
   wire 	RegsWriteReq  ;
   wire 	RegsReadReq   ;
   wire 	RegsAddrSel   ;
   wire 	RegsDataSel   ;
   
   wire 	RegsReadAck   ;
   wire 	RegsWriteAck  ;
   
   wire   [7:0] RegsReadData  ;
   wire   [7:0] RegsWriteData ;
   
    // EPP-side ports
   wire     [ 7:0]  EppData   ;
   wire 	    EppWrite  ;
   wire 	    EppAstb   ;
   wire 	    EppDstb   ;
   wire 	    EppWait   ;
   
   // These Are Unused
   wire 	    EppInt    ; 
   wire 	    EppReset  ;

   wire 	    WbArbReq;
   reg 		    WbArbGnt;



   // **************************** Reset and Clock Gen *************************
   //
   initial
     begin
        Clk = 1'b0;
        RstSync = 1'b1;
        #RST_SYNC_TIME  RstSync = 1'b0;
     end

   always #CLK_HALF_PERIOD Clk = !Clk;
   
   // *************************************************************************

   // Fake the arbiter. If you just tie GNT high, the 4-phase REQ/GNT FSM in the
   // wb master will lock up.
   always @(posedge Clk)
   begin
      if (RstSync)
      begin
	 WbArbGnt <= 1'b0;
      end
      else
      begin
	 WbArbGnt <= WbArbReq;
      end
   end
   
   TESTCASE testcase();

   EPP_MASTER_BFM epp_master_bfm 
      (

       .EPP_DATA_INOUT  (EppData    ),
       .EPP_WRITE_OUT   (EppWrite   ),
       .EPP_ASTB_OUT    (EppAstb    ),
       .EPP_DSTB_OUT    (EppDstb    ),
       .EPP_WAIT_IN     (EppWait    ),

       .EPP_INT_IN      (EppInt     ), 
       .EPP_RESET_OUT   (EppReset   )

       );

 ADI_TOP adi_top
   (

    .CLK            (Clk       ),
    .EN             (1'b1      ),
    .RST_SYNC       (1'b0      ), 
    .RST_ASYNC      (RstSync   ), 

    .EPP_DATA_INOUT (EppData   ),
    .EPP_WRITE_IN   (EppWrite  ),
    .EPP_ASTB_IN    (EppAstb   ),
    .EPP_DSTB_IN    (EppDstb   ),
    .EPP_WAIT_OUT   (EppWait   ),

    .EPP_INT_OUT    (EppInt    ), 
    .EPP_RESET_IN   (EppReset  ),

    .WB_ARB_REQ_OUT (WbArbReq ), 
    .WB_ARB_GNT_IN  (WbArbGnt ),
   
    .WB_ADR_OUT     (WbAdr    ),
    .WB_CYC_OUT     (WbCyc    ),
    .WB_STB_OUT     (WbStb    ),
    .WB_WE_OUT      (WbWe     ),
    .WB_SEL_OUT     (WbSel    ),

    .WB_STALL_IN    (WbStall  ),
    .WB_ACK_IN      (WbAck    ),
    .WB_ERR_IN      (1'b0     ),

    .WB_RD_DAT_IN   (WbDatRd  ),
    .WB_WR_DAT_OUT  (WbDatWr  )
    );
   
   

   
   WB_SLAVE_BFM 
      #(.VERBOSE (0)) // Turn this on for more debugging info
      wb_slave_bfm
   (
    .CLK            (Clk        ),
    .RST_SYNC       (RstSync    ),
    
    .WB_CYC_IN      (WbCyc      ), 
    .WB_STB_IN      (WbStb      ), 
    .WB_ADR_IN      (WbAdr      ), 
    .WB_SEL_IN      (WbSel      ), 
    .WB_WE_IN       (WbWe       ), 
    .WB_STALL_OUT   (WbStall    ), 
    .WB_ACK_OUT     (WbAck      ), 
    .WB_DAT_RD_OUT  (WbDatRd    ), 
    .WB_DAT_WR_IN   (WbDatWr    )  
    
    );




   
// - These units are now wrapped in an adti_top.v
//    WB_MASTER wb_master
//    (
//
//     .BUS_ADDR_IN	  (BusAddr       ),
//     .BUS_REQ_IN 	  (BusReq        ),
//     .BUS_ACK_OUT  	  (BusAck        ),
// 			                 
//     .BUS_RWB_IN 	  (BusRwb        ),
//     .BUS_SIZE_IN 	  (BusSize       ),
//     .BUS_WRITE_DATA_IN	  (BusWriteData  ),
//     .BUS_READ_DATA_OUT	  (BusReadData   ),  
//
//     .WB_CYC_OUT		  (WbCyc         ),
//     .WB_STB_OUT		  (WbStb         ),    
//     .WB_ADR_OUT		  (WbAdr         ),
//     .WB_SEL_OUT	 	  (WbSel         ),
//     .WB_WE_OUT 	 	  (WbWe          ),
//     .WB_ACK_IN     	  (WbAck         ),
//     .WB_STALL_IN          (WbStall       ),
//     .WB_DAT_WR_OUT 	  (WbDatWr       ),
//     .WB_DAT_RD_IN         (WbDatRd       )
//     );
//
// EPP_BUS_BRIDGE epp_bus_bridge
//    (
//     .CLK                   (Clk            ),
//     .RST_ASYNC             (RstSync        ),
//
//     .REGS_WRITE_REQ_IN     (RegsWriteReq   ),
//     .REGS_READ_REQ_IN      (RegsReadReq    ),
//     .REGS_ADDR_SEL_IN      (RegsAddrSel    ),
//     .REGS_DATA_SEL_IN      (RegsDataSel    ),
//
//     .REGS_READ_ACK_OUT     (RegsReadAck    ),
//     .REGS_WRITE_ACK_OUT    (RegsWriteAck   ),
//
//     .REGS_READ_DATA_OUT    (RegsReadData   ),
//     .REGS_WRITE_DATA_IN    (RegsWriteData  ),
//     
//     .BUS_ADDR_OUT	  (BusAddr        ),
//     .BUS_REQ_OUT 	  (BusReq         ),
//     .BUS_ACK_IN  	  (BusAck         ),
// 			                  
//     .BUS_RWB_OUT 	  (BusRwb         ),
//     .BUS_SIZE_OUT 	  (BusSize        ),
//     .BUS_WRITE_DATA_OUT	  (BusWriteData   ),
//     .BUS_READ_DATA_IN	  (BusReadData    )	  
//
//    );
//
//    
//    EPP_SLAVE epp_slave
//       (
//        .CLK                   (Clk            ),
//        .RST_ASYNC             (RstSync        ),
//        
//        .REGS_WRITE_REQ_OUT    (RegsWriteReq   ),
//        .REGS_READ_REQ_OUT     (RegsReadReq    ),
//        .REGS_ADDR_SEL_OUT     (RegsAddrSel    ),
//        .REGS_DATA_SEL_OUT     (RegsDataSel    ),
//        
//        .REGS_READ_ACK_IN      (RegsReadAck    ),
//        .REGS_WRITE_ACK_IN     (RegsWriteAck   ),
//        
//        .REGS_READ_DATA_IN     (RegsReadData   ),
//        .REGS_WRITE_DATA_OUT   (RegsWriteData  ),
//        
//        .EPP_DATA_INOUT        (EppData        ),
//        .EPP_WRITE_IN          (EppWrite       ),
//        .EPP_ASTB_IN           (EppAstb        ),
//        .EPP_DSTB_IN           (EppDstb        ),
//        .EPP_WAIT_OUT          (EppWait        ),
//        
//        .EPP_INT_OUT           (EppInt         ), 
//        .EPP_RESET_IN          (EppReset       )      
//        
//        );
//  

   
endmodule // TB_ADI
