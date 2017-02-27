module TESTCASE ();

`include "mem_map.v"
`include "tb_defines.v"
   

   integer byteLoop;
   
   initial
      begin

	 $display("[INFO ] *************** Beginning UART Test ****************************");

 	 $display("[INFO ] Configuring UART Registers");
	 // 8 bits, 1 stop bit, no parity, enable divisor latches
	 `dataBfm.wbWriteByte(UART_RW_LINE_CTL, 8'b1000_0011);

	 // Program divider
	 `dataBfm.wbWriteByte(UART_RW_DIV_MSB, 8'h00); // Div = 1 => 3.125MBaud
	 `dataBfm.wbWriteByte(UART_RW_DIV_LSB, 8'h01);
	 
	 // Switch back to normal regs
	 `dataBfm.wbWriteByte(UART_RW_LINE_CTL, 8'b0000_0011);

	 // Enable the RX data Interrupt
	 `dataBfm.wbWriteByte(UART_RW_IRQ_EN, 8'b0000_0001);
	 
 	 $display("[INFO ] Writing incrementing values into TX fifo");
	 // Write a few bytes into the TX fifo register
	 for (byteLoop = 0 ; byteLoop < 4 ; byteLoop = byteLoop + 1)
	 begin
	    `dataBfm.wbWriteByte(UART_W_TX_FIFO, byteLoop+1);
	 end
	 

	 // wait a really long time for the uart to send data out..
	 // With a divisor of 1, the UART runs at 3.125MBaud, so for 8 bits you need 2.56us

	 for (byteLoop = 0 ; byteLoop < 4 ; byteLoop = byteLoop + 1)
	 begin
 	    $display("[INFO ] Waiting for the RX FIFO Irq from the UART");
	    wait (`uartTop.int_o == 1'b1);

 	    $display("[INFO ] Reading the RX Fifo back");
	    `dataBfm.wbReadCompareByte (UART_R_RX_FIFO, byteLoop + 1);
	 end
	 

	 
	 $display("[INFO ] **********************************************************");

	 $display("");
	 $display("");
	 
	 


	 
	 $finish();
	 
      end


endmodule // TESTCASE
