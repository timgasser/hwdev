// Defines to allow testcases to be ported up and down the hierarchy

`define TB    TB_TOP 
`define RST   `TB.Rst 
`define CLK   `TB.Clk 
`define CPU   `TB.psx_top.mips1_top.cpu_core 
`define COP0  `TB.psx_top.mips1_top.cop0 
`define IBFM  `CPU.wb_master_bfm_inst
`define DBFM  `CPU.wb_master_bfm_data

`define ROM                  `TB.wb_slave_bfm_rom
`define ROM_BYTE_ARRAY       `ROM.MemArray
`define DRAM                 `TB.wb_slave_bfm_dram
`define DRAM_BYTE_ARRAY      `DRAM.MemArray
`define GPU_RAM              `TB.wb_slave_bfm_gpu_local_ram
`define GPU_RAM_BYTE_ARRAY   `GPU_RAM.MemArray

