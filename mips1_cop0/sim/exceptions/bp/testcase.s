	.text
	.globl __start

/* 0xbfc0_0000 is the reset value of the PC */	
	.org 0x0

	li $10, 2			/* Assume 2 errors */
	nop
	nop
	nop
	
	break    /* Cause the CPU to take a break exception */
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

	/* Check the EPC */
	li       $6, 0xbfc00010     /* break instruction is at this address */
	bne      $26, $6, 1f        /* jump 1 forward if the addresses match */
	nop
	addiu    $10, $10, -1

1:	andi     $27, $27, 0x007c   /* get exception code from Cause [6:2] */
	srl      $27, $27, 2	    /* shift it to the bottom of the register */
	li       $5, 9              /* 9 is the breakpoint code */ 
	bne      $5, $27, 2f	    /* check exception code */
	nop
	addiu    $10, $10, -1

2:	li       $2, -1		    /* set return code */
	li       $7, 0		    /* clear failure flag */
	addiu    $26,$26, 4	    /* set PC to insn after the syscall */
	rfe	 		    /* come back from exception */
	jr       $26		    /* return */

	
	
	
	
