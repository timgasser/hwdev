// Define any constants here for use in the mips1_top level

parameter USER_RAM_BASE        = 32'h0000_0000; // Physical address
parameter USER_RAM_KUSEG_BASE  = 32'h0000_0000; // Cached
parameter USER_RAM_KSEG0_BASE  = 32'h8000_0000; // Cached
parameter USER_RAM_KSEG1_BASE  = 32'hA000_0000; // Un-cached
parameter USER_RAM_SIZE        = 32'h0020_0000;
parameter USER_RAM_SIZE_P2     = 21;

parameter DATA_TCM_BASE        = 32'h1f80_0000; // Physical address. Data-only so no caching.
parameter DATA_TCM_SIZE        = 32'h0000_0400;

parameter BOOTROM_BASE         = 32'h1fc0_0000; // Physical address
parameter BOOTROM_KUSEG_BASE   = 32'h1fc0_0000; // Cached
parameter BOOTROM_KSEG0_BASE   = 32'h9fc0_0000; // Cached
parameter BOOTROM_KSEG1_BASE   = 32'hbfc0_0000; // Uncached
parameter BOOTROM_SIZE         = 32'h0008_0000;

parameter CPU_RST_VECTOR       = BOOTROM_KSEG1_BASE; // Reset vector has to be uncached for the bootrom