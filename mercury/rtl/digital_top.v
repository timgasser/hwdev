// *** INSERT MODULE HEADER *** 

// MERCURY digital_top has the following features:
// Mips1 core 
// - MIPS I ISA apart from signed MULT and (un)signed DIV
// - No COP0 (TLB, Exceptions)
// 8kB (variable) Instruction ROM (FPGA ROM LUT) virtual 0xBFC0_0000 = physical 0x1FC0_0000
// - 13 bit address (byte)
// - 11 bit address (word)
// 8kB Data RAM (FPGA BlockRAM) at            	 virtual 0x0000_0000 = physical 0x0000_1FFF
// - 13 bit address (byte)
// - 11 bit address (word)
// UART 16550 Opencores Core m/m regs at      	 virtual 0xA000_1000 = physical 0x0000_1000
// Nexys 2 Registers at                       	 virtual 0xA000_2000 = physical 0x0000_2000
// - 0FFSET 0x000 7-Segment LED Driver
// - 0FFSET 0x000 R/W LCD Driver
// - 0FFSET 0x004 R   Switch inputs (double-sync into CLK domain)
// - 0FFSET 0x008 R   Pushbutton inputs (double-sync into CLK domain)

// This is a template digital_top. all outputs are tied to 0, and inputs
// disregarded. Connect the host interfaces / LEDs from here as necessary

module DIGITAL_TOP
   (

    input     	      CLK                   ,
    input     	      RST_SYNC              ,

    // Push-buttons
    input      [ 3:0] BTN_IN                , // 

    // EPP interface to USB chip
    input             EPP_ASTB_IN           , // 
    input             EPP_DSTB_IN           , // 
    output            EPP_WAIT_OUT          , //

    // Flash signals
    output            FLASH_CS_OUT          , // 
    output            FLASH_RP_OUT          , // 
    input             FLASH_ST_STS_IN       , //

    // LEDs
    output     [ 7:0] LED_OUT               , // 

    // Memory address [23:1]
    output     [23:0] MEM_ADDR_OUT          , // Bit 0 isn't connected

    // Memory Data [15:0]
    inout      [15:0] MEM_DATA_INOUT        , // 

    // Memory Control
    output            MEM_OE_OUT            , // 
    output            MEM_WR_OUT            , //

    // PS2 Interface
    inout 	      PS2_CLK_INOUT         , // 
    inout 	      PS2_DATA_INOUT        , //

     // RAM control
    output 	      RAM_ADV_OUT           , // 
    output 	      RAM_CLK_OUT           , // 
    output 	      RAM_CRE_OUT           , // 
    output 	      RAM_CS_OUT            , // 
    output 	      RAM_LB_OUT            , // 
    output 	      RAM_UB_OUT            , // 
    input 	      RAM_WAIT_IN           , //

    // RS232 port
    input 	      RS232_RX_IN           , // 
    inout 	      RS232_TX_INOUT        , //

    // 7-Segment displays
    output      [3:0] SSEG_AN_OUT           , // 
    output      [7:0] SSEG_K_OUT            , // 

    // Slider switches
    input       [7:0] SW_IN                 , // 

    // USB control
    output      [1:0] USB_ADDR_OUT          , // 
    input             USB_CLK_IN            , // 
    inout       [7:0] USB_DATA_INOUT        , // 
    input      	      USB_DIR_IN            , // 
    input      	      USB_FLAG_IN           , // 
    input      	      USB_MODE_IN           , // 
    output     	      USB_OE_OUT            , // 
    output     	      USB_PKTEND_OUT        , // 
    output     	      USB_WR_OUT            , //

    // VGA Interface
    output     	[1:0] VGA_BLUE_OUT          , // 
    output     	[2:0] VGA_GREEN_OUT         , // 
    output     	      VGA_HSYNC_OUT         , // 
    output     	[2:0] VGA_RED_OUT           , // 
    output     	      VGA_VSYNC_OUT           // 

    );
`include "mem_map.v"
   

// Tie off all the outputs (template should be modified)
   

   // Button and switch double-syncs
   reg [1:0] 	      Button [3:0];
   reg [1:0] 	      Switch [7:0];

   // CPU Wires
   wire 	      CoreInstCyc      ; 
   wire 	      CoreInstStb      ; 
   wire [31:0] 	      CoreInstAdr      ; 
   wire  	      CoreInstAck      ;
   wire [31:0] 	      CoreInstDatRd    ; 
   
   wire 	      CoreDataCyc      ; 
   wire 	      CoreDataStb      ; 
   wire [31:0] 	      CoreDataAdr      ; 
   wire [ 3:0] 	      CoreDataSel      ; 
   wire 	      CoreDataWe       ; 
   wire 	      CoreDataAck      ; 
   wire [31:0] 	      CoreDataDatRd    ; 
   wire [31:0] 	      CoreDataDatWr    ; 

   wire 	      RomInstCyc      ; 
   wire 	      RomInstStb      ; 
   wire [31:0] 	      RomInstAdr      ; 
   wire  	      RomInstAck      ; 
   wire [31:0] 	      RomInstDatRd    ; 

   wire 	      RamDataCyc      ; 
   wire 	      RamDataStb      ; 
   wire [31:0] 	      RamDataAdr      ; 
   wire [ 3:0] 	      RamDataSel      ; 
   wire 	      RamDataWe       ; 
   wire  	      RamDataAck      ; 
   wire [31:0] 	      RamDataDatRd    ; 
   wire [31:0] 	      RamDataDatWr    ; 

   wire 	      UartRegsDataCyc      ; 
   wire 	      UartRegsDataStb      ; 
   reg  [ 2:0] 	      UartRegsDataAdr      ; 
   wire [ 3:0] 	      UartRegsDataSel      ; 
   wire 	      UartRegsDataWe       ; 
   wire 	      UartRegsDataAck      ; 
   wire [ 7:0] 	      UartRegsDataDatRd    ;
   reg  [31:0] 	      UartRegsDataDatRd32b ;   
   reg  [ 7:0] 	      UartRegsDataDatWr    ; 
   wire 	      UartIrq              ;

   
   wire 	      Nexys2RegsDataCyc      ; 
   wire 	      Nexys2RegsDataStb      ; 
   wire [31:0] 	      Nexys2RegsDataAdr      ; 
   wire [ 3:0] 	      Nexys2RegsDataSel      ; 
   wire 	      Nexys2RegsDataWe       ; 
   wire 	      Nexys2RegsDataAck      ; 
   wire [31:0] 	      Nexys2RegsDataDatRd    ; 
   wire [31:0] 	      Nexys2RegsDataDatWr    ; 

//   wire 	      RomAddrValid;
   wire 	      RamAddrValid;
   wire 	      UartRegsAddrValid;
   wire 	      Nexys2RegsAddrValid;

//   wire [31:0]	      RomAddrPhys;
//   wire [31:0]	      RamAddrPhys;
//   wire [31:0]	      UartRegsAddrPhys;
//   wire [31:0]	      Nexys2RegsAddrPhys;



   // Combinatorial assigns
//   assign RomAddrValid      	 = (CoreInstAdr[31:16] == INST_ROM_BASE[31:16]);
   assign RamAddrValid      	 = (CoreDataAdr[31:16] == DATA_RAM_BASE[31:16]);
   assign UartRegsAddrValid      = (CoreDataAdr[31:16] == UART_REGS_BASE[31:16]);
   assign Nexys2RegsAddrValid    = (CoreDataAdr[31:16] == NEXYS2_REGS_BASE[31:16]);


   // Instruction ROM
   assign RomInstEn          = CoreInstCyc & CoreInstStb;
   assign RomInstCyc         = CoreInstCyc;
   assign RomInstStb         = CoreInstStb;
   assign RomInstAdr         = /* {32{RomAddrValid}} & */ CoreInstAdr;

   // Data RAM
   assign RamDataCyc  	= RamAddrValid 	     & CoreDataCyc    ;
   assign RamDataStb  	= RamAddrValid 	     & CoreDataStb    ;
   assign RamDataAdr  	= {32{RamAddrValid}} & CoreDataAdr    ;
   assign RamDataSel  	= {4{RamAddrValid}}  & CoreDataSel    ;
   assign RamDataWe   	= RamAddrValid       & CoreDataWe     ; 
   assign RamDataDatWr	= {32{RamAddrValid}} & CoreDataDatWr  ;  
   
   // UART Registers
   assign UartRegsDataCyc    = UartRegsAddrValid       & CoreDataCyc      ; 
   assign UartRegsDataStb    = UartRegsAddrValid       & CoreDataStb      ; 
//   assign UartRegsDataAdr    = ({3{UartRegsAddrValid}} & CoreDataAdr)   ; // <- moved to separate always decode
   assign UartRegsDataSel    = {4{UartRegsAddrValid}}  & CoreDataSel      ; 
   assign UartRegsDataWe     = UartRegsAddrValid       & CoreDataWe       ; 
//   assign UartRegsDataDatWr  = {8{UartRegsAddrValid}} & CoreDataDatWr    ; 



   assign CoreInstAck   =  RomInstAck;
   
   assign CoreInstDatRd =  RomInstDatRd;

   assign CoreDataAck    = ( (RamAddrValid & RamDataAck)
			   | (UartRegsAddrValid & UartRegsDataAck)
			   | (Nexys2RegsAddrValid &  Nexys2RegsDataAck)
			   );

   assign CoreDataDatRd  = ( ({32{RamAddrValid}} & RamDataDatRd)
			   | ({32{UartRegsAddrValid}} & UartRegsDataDatRd32b)  // UART has 8 bit data
                           | ({32{Nexys2RegsAddrValid}} & Nexys2RegsDataDatRd)
			   );
   
   
   // Output assigns
    assign  EPP_WAIT_OUT          = 1'b0;  	   //        
    assign  FLASH_CS_OUT          = 1'b0;  	   //        
    assign  FLASH_RP_OUT          = 1'b0;  	   //        
    assign  LED_OUT               = 8'h00;
    assign  MEM_ADDR_OUT          = 24'h000000;  //  [23:0] <- Bit 0 isn't connected
    assign  MEM_DATA_INOUT        = 16'h0000;    //  [15:0]
    assign  MEM_OE_OUT            = 1'b0;   	   //        
    assign  MEM_WR_OUT            = 1'b0;   	   //        
    assign  PS2_CLK_INOUT         = 1'b0;   	   //        
    assign  PS2_DATA_INOUT        = 1'b0;   	   //        
    assign  RAM_ADV_OUT           = 1'b0;   	   //        
    assign  RAM_CLK_OUT           = 1'b0;   	   //        
    assign  RAM_CRE_OUT           = 1'b0;   	   //        
    assign  RAM_CS_OUT            = 1'b0;   	   //        
    assign  RAM_LB_OUT            = 1'b0;   	   //        
    assign  RAM_UB_OUT            = 1'b0;   	   //        
    assign  SSEG_AN_OUT           = 4'hF;          // Active low !
    assign  SSEG_K_OUT            = 8'hFF;         // 
    assign  USB_ADDR_OUT          = 2'b00;  	   //   [1:0]
    assign  USB_DATA_INOUT        = 8'h00;  	   //   [7:0]
    assign  USB_OE_OUT            = 1'b0;   	   //        
    assign  USB_PKTEND_OUT        = 1'b0;   	   //        
    assign  USB_WR_OUT            = 1'b0;   	   //        
    assign  VGA_BLUE_OUT          = 2'b00;  	   //   [1:0]
    assign  VGA_GREEN_OUT         = 3'b000; 	   //   [2:0]
    assign  VGA_HSYNC_OUT         = 1'b0;   	   //        
    assign  VGA_RED_OUT           = 3'b000; 	   //   [2:0]
    assign  VGA_VSYNC_OUT         = 1'b0;        //        



//
//   integer 	      i;
//
//   // Double-sync the Buttons
//   always @(posedge CLK)
//   begin : dblsync_buttons
//      if (RST_SYNC)
//      begin
//	 for (i = 0 ; i < 4 ; i = i + 1)
//	 begin
//	    Button[i] <= 2'b00;
//	 end
//      end
//      else
//      begin
//	 for (i = 0 ; i < 4 ; i = i + 1)
//	 begin
//	    Button[1] <= BTN_IN[i];
//	    Button[0] <= Button[1];
//	 end
//      end
//   end
//
//   // Double-sync the Switches
//   always @(posedge CLK)
//   begin : dblsync_switch
//      if (RST_SYNC)
//      begin
//	 for (i = 0 ; i < 8 ; i = i + 1)
//	 begin
//	    Switch[i] <= 2'b00;
//	 end
//      end
//      else
//      begin
//	 for (i = 0 ; i < 8 ; i = i + 1)
//	 begin
//	    Switch[1] <= SW_IN[i];
//	    Switch[0] <= Switch[1];
//	 end
//      end
//   end


   // todo ! Not sure if this is needed .. do I need to set the bottom two bits
   // of the address based on the SEL from the core, or just leave as
   // 2'b00 and let the SEL get decoded in the UART??
   always @*
   begin
//      UartRegsDataAdr = {CoreDataAdr[2], 2'b00};

      UartRegsDataAdr = 3'b000;
      
      if (UartRegsAddrValid)
      begin
	 UartRegsDataAdr[2] = CoreDataAdr[2];

	 case (UartRegsDataSel[3:0])
	   4'b0001 : UartRegsDataAdr[1:0] = 2'h0;
	   4'b0010 : UartRegsDataAdr[1:0] = 2'h1;
	   4'b0100 : UartRegsDataAdr[1:0] = 2'h2;
	   4'b1000 : UartRegsDataAdr[1:0] = 2'h3;
	 endcase
      end
   end
   
   // Select the write data based on the SEL
   always @*
   begin
      UartRegsDataDatWr = 8'h00;
      
	 case (UartRegsDataSel[3:0])
	   4'b0001 : UartRegsDataDatWr = CoreDataDatWr[ 7: 0];
	   4'b0010 : UartRegsDataDatWr = CoreDataDatWr[15: 8];
	   4'b0100 : UartRegsDataDatWr = CoreDataDatWr[23:16];
	   4'b1000 : UartRegsDataDatWr = CoreDataDatWr[31:24];
	 endcase 
   end
   

   // Put the read data in the correct lane based on SEL
   always @*
   begin
      UartRegsDataDatRd32b = 32'h0000_0000;
      
	 case (UartRegsDataSel[3:0])
	   4'b0001 : UartRegsDataDatRd32b = {24'h00_0000, UartRegsDataDatRd        };
	   4'b0010 : UartRegsDataDatRd32b = {16'h0000, UartRegsDataDatRd, 8'h00    };
	   4'b0100 : UartRegsDataDatRd32b = {8'h00, UartRegsDataDatRd, 16'h0000    };
	   4'b1000 : UartRegsDataDatRd32b = {UartRegsDataDatRd, 24'h00_0000        };
	 endcase 
   end
   

   
   // 13 bit address = 32kB max size
INST_ROM_WRAP inst_rom_wrap
    (
    .CLK            (CLK       ),
    .RST_SYNC       (RST_SYNC  ),
    
    .WB_CYC_IN      (RomInstCyc ),
    .WB_STB_IN      (RomInstStb ),
    .WB_ADR_IN      (RomInstAdr ),
    .WB_ACK_OUT     (RomInstAck ),
    .WB_DAT_RD_OUT  (RomInstDatRd ) 
    
    );

   
   DATA_RAM 
  #(.ADDR_WIDTH      (RAM_ADDR_WIDTH))
   data_ram
   (
    .CLK             (CLK       ),
    .RST_SYNC        (RST_SYNC  ),

    .RAM_CYC_IN      (RamDataCyc   ),
    .RAM_STB_IN      (RamDataStb   ),
    .RAM_ADR_IN      ({ {32 - RAM_ADDR_WIDTH{1'b0}} , RamDataAdr[RAM_ADDR_WIDTH-1+2:2] }),
    .RAM_SEL_IN      (RamDataSel   ),
    .RAM_WE_IN       (RamDataWe    ),
    .RAM_ACK_OUT     (RamDataAck   ),
    .RAM_DAT_RD_OUT  (RamDataDatRd ),
    .RAM_DAT_WR_IN   (RamDataDatWr )  
    
    );

`define DATA_BUS_WIDTH_8

   uart_top uart_top
      (
       .wb_clk_i      (CLK           ), 
       .wb_rst_i      (RST_SYNC      ), 

       .wb_adr_i      (UartRegsDataAdr   ), 
       .wb_dat_i      (UartRegsDataDatWr ), 
       .wb_dat_o      (UartRegsDataDatRd ), 
       .wb_we_i       (UartRegsDataWe    ), 
       .wb_stb_i      (UartRegsDataStb   ), 
       .wb_cyc_i      (UartRegsDataCyc   ), 
       .wb_ack_o      (UartRegsDataAck   ), 
       .wb_sel_i      (UartRegsDataSel   ),
       .int_o         (UartIrq           ),    
      
       .stx_pad_o     (RS232_TX_INOUT    ), 
       .srx_pad_i     (RS232_RX_IN       ),
      
       .rts_pad_o     ( ),
       .cts_pad_i     (1'b0 ), 
       .dtr_pad_o     ( ),
       .dsr_pad_i     (1'b0 ), 
       .ri_pad_i      (1'b0 ), 
       .dcd_pad_i     (1'b0 )
       );

      
   // MIPS CPU Core
   CPU_CORE
  #(.PC_RST_VALUE          (32'hBFC0_0000  ))
   cpu_core
   (
    .CLK                   (CLK            ),
    .RST_SYNC              (RST_SYNC       ),

    .CORE_INST_CYC_OUT     (CoreInstCyc    ),
    .CORE_INST_STB_OUT     (CoreInstStb    ),
    .CORE_INST_ADR_OUT     (CoreInstAdr    ),
    .CORE_INST_ACK_IN      (CoreInstAck    ),
    .CORE_INST_DAT_RD_IN   (CoreInstDatRd  ),
    
    .CORE_DATA_CYC_OUT     (CoreDataCyc    ),
    .CORE_DATA_STB_OUT     (CoreDataStb    ),
    .CORE_DATA_ADR_OUT     (CoreDataAdr    ),
    .CORE_DATA_SEL_OUT     (CoreDataSel    ),
    .CORE_DATA_WE_OUT      (CoreDataWe     ),
    .CORE_DATA_ACK_IN      (CoreDataAck    ),
    .CORE_DATA_DAT_RD_IN   (CoreDataDatRd  ),
    .CORE_DATA_DAT_WR_OUT  (CoreDataDatWr  ) 
    
    );




   
   
endmodule
