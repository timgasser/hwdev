// Wishbone Definitions (Revision: B.3, Released: September 7, 2002)

// BTE
parameter BTE_LINEAR_BURST  = 2'b00;
parameter BTE_4_BEAT_BURST  = 2'b01;
parameter BTE_8_BEAT_BURST  = 2'b10;
parameter BTE_16_BEAT_BURST = 2'b11;

// CTI
parameter CTI_CLASSIC    = 3'b000;
parameter CTI_CONST_ADDR = 3'b001;
parameter CTI_INCR_ADDR  = 3'b010;
parameter CTI_END_BURST  = 3'b111;

// Widths
parameter ADR_W = 32;
parameter CYC_W = 1;  
parameter STB_W = 1;
parameter WE_W  = 1;
parameter SEL_W = 4;
parameter CTI_W = 3;  
parameter BTE_W = 2;  

parameter ACK_W   = 1;  
parameter STL_W   = 1;  
parameter ERR_W   = 1;  

parameter DAT_W = 32;



