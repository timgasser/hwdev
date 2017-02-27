/*  ../vmips -o noinstdump -o haltdumpcpu -o haltbreak addi.rom */
/*  should end w/ pc=bfc00180, next_epc=bfc00180, and R04=00000001  */
/*  R05=00000003  R06=00000007  R07=00000006  R08=7fffffff */
/*  tests instructions: addi */

	.text
	.globl __start

__start:
	li $4, 0xA0010000    /* UART Base reg */
	la $5, msg
	li $8, 0
	li $9, 15 /* amount of characters */
	
#	 // 8 bits, 1 stop bit, no parity, enable divisor latches
#	 `dataBfm.wbWrite(UART_RW_LINE_CTL, 4'h1, 8'b1000_0011);
#
#	 // Program divider
#	 `dataBfm.wbWrite(UART_RW_DIV_MSB , 4'h1, 8'h00); // Div = 1 => 3.125MBaud
#	 `dataBfm.wbWrite(UART_RW_DIV_LSB , 4'h1, 8'h01);
#	 
#	 // Switch back to normal regs
#	 `dataBfm.wbWrite(UART_RW_LINE_CTL, 4'h1, 8'b0000_0011);
#
#	 // Enable the RX data Interrupt
#	 `dataBfm.wbWrite(UART_RW_IRQ_EN  , 4'h1, 8'b0000_0001);
#	 

	/* UART_RW_LINE_CTL */
	li $6, 0x00000083
	sb $6, 3($4)

	/* UART_RW_DIV_MSB */
	li $6, 0x00000000
	sb $6, 1($4)

	/* UART_RW_DIV_LSB */
	li $6, 163 /* 163 gives a baud of 25e6/(163 x 16) = 9585 baud */ 
	sb $6, 0($4)

	/* UART_RW_LINE_CTL */
	li $6, 0x00000003
	sb $6, 3($4)

	/* UART_RW_IRQ_EN */
	li $6, 0x00000001
	sb $6, 1($4)

	/* NOTE $4 has the TX FIFO address in it */
	la $7, msg

	/* Hex string .. 48 65 6c 6c 6f 20 63 68 69 63 6b 65 6e 20 21 */

	li $6, 0x48
	sb $6, 0 ($4)
	
	li $6, 0x65
	sb $6, 0 ($4)
	
	li $6, 0x6c
	sb $6, 0 ($4)
	
	li $6, 0x6c
	sb $6, 0 ($4)
	
	li $6, 0x6f
	sb $6, 0 ($4)
	
	li $6, 0x20
	sb $6, 0 ($4)
	
	li $6, 0x63
	sb $6, 0 ($4)
	
	li $6, 0x68
	sb $6, 0 ($4)
	
	li $6, 0x69
	sb $6, 0 ($4)
	
	li $6, 0x63
	sb $6, 0 ($4)
	
	li $6, 0x6b
	sb $6, 0 ($4)
	
	li $6, 0x65
	sb $6, 0 ($4)
	
	li $6, 0x6e
	sb $6, 0 ($4)
	
	li $6, 0x20
	sb $6, 0 ($4)
	
	li $6, 0x21
	sb $6, 0 ($4)
	
	li $6, 0x0a /* newline is 0x0a */
	sb $6, 0 ($4)
	
	/* The TX Fifo is loaded up, so poll until it has emptied */

	/* Poll bit 5 of LSR register. 1 = empty, 0 = data pending */
tx_lbl:	
	lb   $7, 5 ($4)
	andi $7, $7, 0x00000040
	bgtz $7, rx_lbl
	nop
	j    tx_lbl

	/* Loop until a character is received (bit 0 of LSR is 1) */
rx_lbl:
	lb   $7, 5 ($4)
	andi $7, $7, 0x0000001
	bgtz $7, rx_read
	nop
	j    tx_lbl
	nop

	/* Read a character from the RX fifo */
	/* Increment $8 for each character */
rx_read:
	lb   $7, 0 ($4)
	addi $8, $8, 1
	sub  $10, $9, $8 /* $10 = $9 - $8 */
	bgtz $10, rx_lbl
	
	nop
	nop
	nop
	
	break

	.org 0x200
	
msg:	.asciiz "Hello my Chicken .. \n" /* 22 characters = */
	
	.org 0x220
	
	break

