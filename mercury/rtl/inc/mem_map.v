// *** INSERT MODULE HEADER *** 

// Memory Base Addresses
parameter INST_ROM_BASE    = 32'hBFC0_0000;
parameter DATA_RAM_BASE    = 32'h0000_0000;
parameter UART_REGS_BASE   = 32'hA001_0000;
parameter NEXYS2_REGS_BASE = 32'hA002_0000;

// Memory Sizes
parameter RAM_ADDR_WIDTH = 13;
parameter RAM_SIZE_BYTE  = 2 ** RAM_ADDR_WIDTH;
parameter RAM_SIZE_WORD  = RAM_SIZE_BYTE >> 2;

parameter ROM_ADDR_WIDTH = 13;
parameter ROM_SIZE_BYTE  = 2 ** ROM_ADDR_WIDTH;
parameter ROM_SIZE_WORD  = ROM_SIZE_BYTE >> 2;

// UART Registers
parameter UART_R_RX_FIFO      = UART_REGS_BASE + 32'h0000_0000;
parameter UART_W_TX_FIFO      = UART_REGS_BASE + 32'h0000_0000;
parameter UART_RW_IRQ_EN      = UART_REGS_BASE + 32'h0000_0001;
parameter UART_R_IRQ_ID       = UART_REGS_BASE + 32'h0000_0002;
parameter UART_W_FIFO_CTL     = UART_REGS_BASE + 32'h0000_0002;
parameter UART_RW_LINE_CTL    = UART_REGS_BASE + 32'h0000_0003;
parameter UART_W_MODEM_CTL    = UART_REGS_BASE + 32'h0000_0004;
parameter UART_R_LINE_STATUS  = UART_REGS_BASE + 32'h0000_0005;
parameter UART_R_MODEM_STATUS = UART_REGS_BASE + 32'h0000_0006;
 
// Only accessable when bit 7 of UART_RW_LINE_CTL is set
parameter UART_RW_DIV_LSB     = UART_REGS_BASE + 32'h0000_0000;
parameter UART_RW_DIV_MSB     = UART_REGS_BASE + 32'h0000_0001;

// // UART Regs (address and byte sel separately)
// parameter UART_ADDR_R_RX_FIFO      = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_W_TX_FIFO      = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_RW_IRQ_EN      = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_R_IRQ_ID       = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_W_FIFO_CTL     = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_RW_LINE_CTL    = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_W_MODEM_CTL    = UART_REGS_BASE + 32'h0000_0004;
// parameter UART_ADDR_R_LINE_STATUS  = UART_REGS_BASE + 32'h0000_0004;
// parameter UART_ADDR_R_MODEM_STATUS = UART_REGS_BASE + 32'h0000_0004;
// 
// parameter UART_ADDR_RW_DIV_LSB     = UART_REGS_BASE + 32'h0000_0000;
// parameter UART_ADDR_RW_DIV_MSB     = UART_REGS_BASE + 32'h0000_0000;
// 
// parameter [3:0] UART_SEL_R_RX_FIFO      = 4'b0001;
// parameter [3:0] UART_SEL_W_TX_FIFO      = 4'b0001;
// parameter [3:0] UART_SEL_RW_IRQ_EN      = 4'b0010;
// parameter [3:0] UART_SEL_R_IRQ_ID       = 4'b0100;
// parameter [3:0] UART_SEL_W_FIFO_CTL     = 4'b0100;
// parameter [3:0] UART_SEL_RW_LINE_CTL    = 4'b1000;
// parameter [3:0] UART_SEL_W_MODEM_CTL    = 4'b0001;
// parameter [3:0] UART_SEL_R_LINE_STATUS  = 4'b0010;
// parameter [3:0] UART_SEL_R_MODEM_STATUS = 4'b0100;
// 
// parameter [3:0] UART_SEL_RW_DIV_LSB     = 4'b0001;
// parameter [3:0] UART_SEL_RW_DIV_MSB     = 4'b0010;
// 
// 