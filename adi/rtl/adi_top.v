// Top level block for the ADI interface. Includes:
// - EPP_SLAVE : Slave for the EPP interface from the USB chip (and host PC)
// - EPP_BUS_BRIDGE : Implements some EPP registers to combine into WB accesses
// - WB_MASTER : Converts EPP register accesses into WB accesses


module ADI_TOP
   (

    // Clocks and resets
    input          CLK            ,
    input          EN             , // Synchronous enable
    input          RST_SYNC       , // Sync reset 
    input          RST_ASYNC      , // Asynchronous reset

    // EPP-side ports
    inout   [ 7:0] EPP_DATA_INOUT , // Bi directional : Drive when reading, and WAIT output high
    input          EPP_WRITE_IN   , // Input  : Active low Write (RWB) signal
    input          EPP_ASTB_IN    , // Input  : Active low Address Strobe
    input          EPP_DSTB_IN    , // Input  : Active low Data Strobe
    output         EPP_WAIT_OUT   , // Output : Active low WAIT.1 = Write completed, or Read data driven onto Data Bus. 

    // These are unused
    output         EPP_INT_OUT    , 
    input          EPP_RESET_IN   ,

    // Wishbone ARBITER interface
    output         WB_ARB_REQ_OUT , // 4-phase REQ/GNT handshake
    input          WB_ARB_GNT_IN  ,
   
    // Wishbone MASTER interface
    output  [31:0] WB_ADR_OUT     ,
    output         WB_CYC_OUT     ,
    output         WB_STB_OUT     ,
    output         WB_WE_OUT      ,
    output  [ 3:0] WB_SEL_OUT     ,

    input          WB_STALL_IN    ,
    input          WB_ACK_IN      ,
    input          WB_ERR_IN      ,

    input   [31:0] WB_RD_DAT_IN   ,
    output  [31:0] WB_WR_DAT_OUT 

   
   
    );
   


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
   wire         BusReadAck    	;
   wire         BusWriteAck    	;
   wire         BusAck    	= BusWriteAck | BusReadAck;
   
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


   WB_MASTER wb_master
      (
       .CLK          	      (CLK             	),
       .EN                    (EN               ),
       .RST_SYNC              (1'b0             ),
       .RST_ASYNC   	      (RST_ASYNC    	), 

       .WB_ARB_REQ_OUT 	      (WB_ARB_REQ_OUT  	),
       .WB_ARB_GNT_IN  	      (WB_ARB_GNT_IN   	),
      
       .WB_ADR_OUT     	      (WB_ADR_OUT      	),
       .WB_CYC_OUT     	      (WB_CYC_OUT      	),
       .WB_STB_OUT     	      (WB_STB_OUT      	),
       .WB_WE_OUT      	      (WB_WE_OUT       	),
       .WB_SEL_OUT     	      (WB_SEL_OUT      	),

       .WB_STALL_IN    	      (WB_STALL_IN     	),
       .WB_ACK_IN      	      (WB_ACK_IN       	),
       .WB_ERR_IN      	      (WB_ERR_IN       	),

       .WB_RD_DAT_IN   	      (WB_RD_DAT_IN    	),
       .WB_WR_DAT_OUT 	      (WB_WR_DAT_OUT  	),

       .BUS_START_ADDR_IN     (BusAddr         	),
      
       .BUS_READ_REQ_IN       (BusReq & BusRwb  ),
       .BUS_READ_ACK_OUT      (BusReadAck       ),
       .BUS_WRITE_REQ_IN      (BusReq & ~BusRwb ),
       .BUS_WRITE_ACK_OUT     (BusWriteAck      ),

       .BUS_SIZE_IN           (BusSize         	),
       .BUS_LEN_IN            (5'd1            	), // No burst accesses
       .BUS_BURST_ADDR_INC_IN (1'b0            	),

       .BUS_READ_DATA_OUT     (BusReadData     	),
       .BUS_WRITE_DATA_IN     (BusWriteData    	)
      
       );

   
   EPP_BUS_BRIDGE epp_bus_bridge
      (
       .CLK          	      (CLK             	),
       .EN                    (EN               ),
       .RST_SYNC              (1'b0             ),
       .RST_ASYNC   	      (RST_ASYNC    	), 

       .REGS_WRITE_REQ_IN     (RegsWriteReq   ),
       .REGS_READ_REQ_IN      (RegsReadReq    ),
       .REGS_ADDR_SEL_IN      (RegsAddrSel    ),
       .REGS_DATA_SEL_IN      (RegsDataSel    ),

       .REGS_READ_ACK_OUT     (RegsReadAck    ),
       .REGS_WRITE_ACK_OUT    (RegsWriteAck   ),

       .REGS_READ_DATA_OUT    (RegsReadData   ),
       .REGS_WRITE_DATA_IN    (RegsWriteData  ),
      
       .BUS_ADDR_OUT	      (BusAddr        ),
       .BUS_REQ_OUT 	      (BusReq         ),
       .BUS_ACK_IN  	      (BusAck         ),
      
       .BUS_RWB_OUT 	      (BusRwb         ),
       .BUS_SIZE_OUT 	      (BusSize        ),
       .BUS_WRITE_DATA_OUT    (BusWriteData   ),
       .BUS_READ_DATA_IN      (BusReadData    )	  

       );

   
   EPP_SLAVE epp_slave
      (
       .CLK          	      (CLK             	),
       .EN                    (EN               ),
       .RST_SYNC              (1'b0             ),
       .RST_ASYNC   	      (RST_ASYNC    	), 
      
       .REGS_WRITE_REQ_OUT    (RegsWriteReq   ),
       .REGS_READ_REQ_OUT     (RegsReadReq    ),
       .REGS_ADDR_SEL_OUT     (RegsAddrSel    ),
       .REGS_DATA_SEL_OUT     (RegsDataSel    ),
      
       .REGS_READ_ACK_IN      (RegsReadAck    ),
       .REGS_WRITE_ACK_IN     (RegsWriteAck   ),
      
       .REGS_READ_DATA_IN     (RegsReadData   ),
       .REGS_WRITE_DATA_OUT   (RegsWriteData  ),
      
       .EPP_DATA_INOUT        (EPP_DATA_INOUT  ),
       .EPP_WRITE_IN          (EPP_WRITE_IN    ),
       .EPP_ASTB_IN           (EPP_ASTB_IN     ),
       .EPP_DSTB_IN           (EPP_DSTB_IN     ),
       .EPP_WAIT_OUT          (EPP_WAIT_OUT    ),
      
       .EPP_INT_OUT           (EPP_INT_OUT     ), 
       .EPP_RESET_IN          (EPP_RESET_IN    )      
      
       );


endmodule // TB_ADI
