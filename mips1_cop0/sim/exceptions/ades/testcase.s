	.text
	.globl __start

/* 0xbfc0_0000 is the reset value of the PC */	
	.org 0x0

	li $10, 3			/* Assume all 3 checks fail */
	nop
	ori $5, 0x0011
	nop
	
	sw  $6, 0($5)    /* Cause the CPU to take an address error (data load) */
	nop
	nop
	nop

	sw    $10, 0($0) /* Once the exception is serviced, store the amount of errors (detected by TB) */ 
	nop                 
	nop
	nop 
	

	
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
	mfc0     $28, $8            /* Save BADVA to reg 28 */

	/* Check the EPC */
	li       $6, 0xbfc00010     /* break instruction is at this address */
	bne      $26, $6, 1f        /* jump 1 forward if the addresses match */
	nop
	addiu    $10, $10, -1

	/* Check the cause code */
1:	andi     $27, $27, 0x007c   /* get exception code from Cause [6:2] */
	srl      $27, $27, 2	    /* shift it to the bottom of the register */
	li       $5, 5              /* 5 is the ades code */ 
	bne      $5, $27, 2f	    /* check exception code */
	nop
	addiu    $10, $10, -1

	/* Check the badva reg (8)*/
2:	
	li       $5, 0x11           /* 1 is the offending address */
	bne      $5, $28, 3f	    /* check exception code */
	nop
	addiu    $10, $10, -1
	
3:	li       $2, -1		    /* set return code */
	li       $7, 0		    /* clear failure flag */
	addiu    $26,$26, 4	    /* set PC to insn after the syscall */
	rfe	 		    /* come back from exception */
	jr       $26		    /* return */

	
	
	
	
