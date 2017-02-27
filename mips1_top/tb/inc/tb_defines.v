// Defines to allow testcases to be ported up and down the hierarchy

`define TB    TB_TOP 
`define RST   `TB.Rst 
`define CLK   `TB.Clk 
`define CPU   `TB.mips1_top.cpu_core 
`define COP0  `TB.mips1_top.cop0 
`define IBFM  `CPU.wb_master_bfm_inst
`define DBFM  `CPU.wb_master_bfm_data

