	.text
	.globl __start

/* 0xbfc0_0000 is the reset value of the PC */	
	.org 0x0

/* 	li $10, 0			
 * 	addi $2, $0, -32768
 * 	addi $3, $0, -32768
 * 	nop
 */

	
 	li $10, 0			
 	li  $2, 0x80000000
 	li  $3, 0x80000000
	nop
	
 	add $2, $2, $3    /* Cause the CPU to take an overflow exception */
 	nop
	nop
	nop

	sw    $10, 0($0) /* Once the exception is serviced, store the amount of errors (detected by TB) */ 
	nop                 
	nop
	nop 
	

	.org 0x180

	mfc0     $26, $14           /* Save EPC to reg 26   */
	mfc0     $27, $13           /* Save Cause to reg 27 */


	/* Check the overflow register */
	
	beq   $2, $3, 1f
	nop
	addiu $10, $10, 1

	/* Check the EPC */
1:
	li       $6, 0xbfc00010     /* break instruction is at this address */
	beq      $26, $6, 1f        /* jump 1 forward if the addresses match */
	nop
	addiu    $10, $10, 1

	/* TODO ! Check the register isn't written in the overflow exception ! */
	
1:	andi     $27, $27, 0x007c   /* get exception code from Cause [6:2] */
	srl      $27, $27, 2	    /* shift it to the bottom of the register */
	li       $5, 12             /* 12 is the overflow code */ 
	beq      $5, $27, 2f	    /* check exception code */
	nop
	addiu    $10, $10, 1

2:	li       $2, -1		    /* set return code */
	li       $7, 0		    /* clear failure flag */
	addiu    $26,$26, 4	    /* set PC to insn after the syscall */
	rfe	 		    /* come back from exception */
	jr       $26		    /* return */

	
	
	
	
