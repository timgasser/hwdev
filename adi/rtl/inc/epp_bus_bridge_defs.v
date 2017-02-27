// EPP BUS Bridge Definitions. This file contains the addresses and bit definitions for the EPP_BUS_BRIDGE module.

// 32-bit address register split in little endian. All addresses byte aligned.
parameter [7:0] ERW_ADDR0    = 8'h00;
parameter [7:0] ERW_ADDR1    = 8'h01;
parameter [7:0] ERW_ADDR2    = 8'h02;
parameter [7:0] ERW_ADDR3    = 8'h03;

// 32-bit Data register split in little endian. All addresses byte aligned.
parameter [7:0] ERW_DATA0    = 8'h10;
parameter [7:0] ERW_DATA1    = 8'h11;
parameter [7:0] ERW_DATA2    = 8'h12;
parameter [7:0] ERW_DATA3    = 8'h13;

// 5-bit Transaction register.
parameter [7:0] ERW_TRANS    = 8'h20;
// Bitfield: SIZE in [1:0], RWB in [4]. Rest reserved.
parameter ERW_TRANS_SIZE_LSB = 0;
parameter ERW_TRANS_SIZE_MSB = 1;
parameter [1:0] ERW_SIZE_BYTE  = 2'd0;
parameter [1:0] ERW_SIZE_2BYTE = 2'd1;
parameter [1:0] ERW_SIZE_WORD  = 2'd2;
parameter       ERW_TRANS_RWB     = 4;

// 1-bit status register. Bit [0] is 1 = Busy, 0 = Idle.
parameter [7:0] ERW_STATUS      = 8'h30;
parameter       ERW_STATUS_BUSY = 0;

// 8-bit write-sensitive register. Byte status register. Bit [0] is 1 = Busy, 0 = Idle.
parameter [7:0] ERW_STREAM      = 8'h40;
