	.text
	.globl __start

/* 0xbfc0_0000 is the reset value of the PC */	
/* By default, the CPU is in Kernel mode, all coprocessors are usable */	
/* Then change into user mode (using RFE) and try and access each in turn */

/* Use an MTCz to register 0x10 (reserved in COP0) */
        
        .org 0x0

/* Initialise this register in core with the amount of times an execption should be taken */
        li $10, 4             /* Assume test fail initially (non-zero $10) */

/* Kernel mode section. No exceptions should be taken */
        
	li   $2, 0x00400008   /* Set BEV, KUp = 1 so after RFE we're in User mode */
	mtc0 $2, $12	      
	nop
	nop
	nop
	nop

/* In kernel mode, none of these MTCz's should cause any exceptions */
/* Use a reserved register address of 16 to avoid overwriting COP0 regs*/        
	mtc0 $2, $16         
	nop
	nop
	nop
	nop
	mtc1 $2, $16         
	nop
	nop
	nop
	nop
	mtc2 $2, $16         
	nop
	nop
	nop
	nop
	mtc3 $2, $16         
	nop
	nop
	nop
	nop

/* Switch into user mode using rfe */
        rfe
	nop
	nop
	nop
	nop

/* Now in user mode, and all co processors are unusable */
/* This should give an exception on every MTC write */
	mtc0 $2, $16         
	nop
	nop
	nop
	nop
	mtc1 $2, $16         
	nop
	nop
	nop
	nop
	mtc2 $2, $16         
	nop
	nop
	nop
	nop
	mtc3 $2, $16         
	nop
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
	li       $6, 0xbfc00014     /* break instruction is at this address */
	bne      $26, $6, 1f        /* jump 1 forward if the addresses match */
	nop
	addiu    $10, $10, -1

	/* Check the cause code */
1:	andi     $27, $27, 0x007c   /* get exception code from Cause [6:2] */
	srl      $27, $27, 2	    /* shift it to the bottom of the register */
	li       $5, 11             /* 5 is the co processor unusable code */ 
	bne      $5, $27, 2f	    /* check exception code */
	nop
	addiu    $10, $10, -1

2:	li       $2, -1		    /* set return code */
	li       $7, 0		    /* clear failure flag */
	addiu    $26,$26, 4	    /* set PC to insn after the syscall */
	rfe	 		    /* come back from exception */
	jr       $26		    /* return */

	
	
	
	
