// Define testbench variables here for easy porting of tests

`define REPORT_VGA_TIMING

`define TB          TB_TOP
`define RST        `TB.RstVga 
`define VGA_RAM    `TB.wb_slave_bfm.MemArray 
`define VGA_PIXELS `TB.vga_slave_monitor.pixelArray 

`define VGA_FIFO_RD_EMPTY  `TB.vga_top.vga_cdc.FifoReadEmpty
`define VGA_FIFO_RD_EN     `TB.vga_top.vga_cdc.VGA_DATA_REQ_IN

`define VGA_TEST_EN `TB.VgaTestEn
