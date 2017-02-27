	.text
	.globl __start


/* The HW test needs quite a bit of communication with the TB as follows:
 *
 * - The assembly acts as the master, and request a HW interrupt to be sent by writing a 
 *   onehot value to address 0x10. This causes the testbench to force that HW line high.
 *
 * - The HW interrupt then causes the assembly to jump to the ISR. The ISR:
 *     -> Writes the Cause value to 0x04 (should be 0)
 *     -> Writes the onehot HW IP from the cause register to 0x00
 *
 * - Finally the ISR writes zero to 0x10, which causes the testbench to de-assert the irq.
/
	
/* 0xbfc0_0000 is the reset value of the PC */	
	.org 0x0

	li  $8, 0x0001         /* $8 is used to store the onehot HW interrupt*/
	li  $9, 0x0010         /* $9 holds the address used to communicate with the TB. */ 
	li $10, 0x104000ff     /* $9 holds the base Status reg (cop0 usable, BEV = 1, interrupts enabled) */ 
                               /* -> OR in the interrupt mask in bits 15:8 */

	/* $11 used as temporary reg */
	/* $12 is used as semaphore between normal and ISR code */
	/*     -> 1 = current interrupt waiting to be processed */
	/*     -> 0 = current interrupt ISR processed  */
main_loop:

	or   $11, $0, $8        /* Store $8 in $11 (onehot HW Mask field) */ 
	sll  $11, $11, 10       /* Shift interrupt mask into status HW IntMask field */
	or   $11, $11, $10      /* OR in rest of status register from constant $10 */
	mtc0 $11, $12           /* Store Status register contents */
	
	li   $12, 1             /* Set semaphore in reg 12 */ 
	sw   $8, 0($9)          /* Request a HW to be sent from the TB */
	nop                  
	nop
	nop
	nop

	/* Need to check the semaphore from the ISR to see if the current interrupt has been processed */ 
wait_loop:	
	nop
	nop
	nop
	bgtz $12, wait_loop
	nop
	beq  $0, $0, main_loop
	
/* 0xbfc0_0180 is the interrupt vector */
/* Need to check the following:
 *  
 * BADVA  (not set in this exception)
 * CAUSE  [6:2] = 9
 * EPC    = 0x0000_0010
 *
 */
	.org 0x180

	mfc0     $26, $14           /* Save EPC to reg 26   */
	mfc0     $27, $13           /* Save Cause to reg 27 */
	mfc0     $28, $13           /* Save Cause to reg 28 */

	/* Store the Cause code to address 0x04 (should always be 0) */
1:	andi     $27, $27, 0x007c   /* get exception code from Cause [6:2] */
	srl      $27, $27, 2	    /* shift it to the bottom of the register */
	sw       $27, 4($0)

	/* Store the Interrupt Pending 6 bit field to address 0x00 */
2:	andi     $28, $28, 0xfc00   /* get IP[5:0] from Cause [15:10] */
	srl      $28, $28, 10	    /* shift it to the bottom of the register */
	sw       $28, 0($0)         /* store the interrupt onehot value to address 0x00 */

	/* Get the TB to de-assert the interrupt, set up next interrupt onehot value */
	sw       $0, 0($9)          /* Clear Tb HW interrupt */
	sll      $8, $8, 1          /* Rotate interrupt to test one left */
	li       $12, 0             /* Clear semaphore in reg 12 */ 
	
4:	addiu    $26,$26, 4	    /* set PC to insn after the syscall */
	rfe	 		    /* come back from exception */
	jr       $26		    /* return */

	
	
	
	
