	.text
	.globl __start

/* 0xbfc0_0000 is the reset value of the PC */	
	.org 0x0

	li   $16, 0x104001ff  /* Unmask SW0 interrupt, enable interrupts, BEV = 1 */
	mtc0 $16, $12         /* Store to Status reg (COp0 reg 12) to enable interrupts */
	li   $15, 0x0100      /* Store the SW0 interrupt bit mask*/ 
	mtc0 $15, $13         /* 0x8 - trigger SW interrupt 0 by storing to Cause reg */
	nop
	nop  
	nop  
	nop
	nop
	nop
	
	
	li   $16, 0x104002ff  /* Unmask SW1 interrupt, enable interrupts, BEV = 1 */
	mtc0 $16, $12         /* Store to Status reg (COp0 reg 12) to enable interrupts */
	li   $15, 0x0200 /* Store the SW1 interrupt bit mask*/ 
	mtc0 $15, $13         /* 0x8 - trigger SW interrupt 0 by storing to Cause reg */
	nop
	nop  
	nop  
	nop
	nop
	nop

wait_loop:	
	nop
	nop
	nop
	beq $0, $0, wait_loop
	
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
	mfc0     $28, $12            /* Save Status to reg 28 */

	/* Check the cause code - increment the pass variable by 1 if it matches INT (0) */
1:	andi     $27, $27, 0x007c   /* get exception code from Cause [6:2] */
	srl      $27, $27, 2	    /* shift it to the bottom of the register */
	li       $5, 0              /* SW interrupt treated as INT (Cause = 0) */ 
	beq      $5, $27, 2f	    /* check exception code */
	nop
	addiu    $10, $10, 1

	/* Write the interrupt to address 0*/
2:	andi     $28, $28, 0xff00   /* Isolate top byte of bottom 16 bits */
	srl      $28, $28, 8	    /* shift it to the bottom of the register */
	sw       $28, 0x10($0)      /* Store the interrupt one hot mask word */ 

3:	/* Clear the Cause register */
	mtc0	 $0, $13            /* Clear the SW interrupt */

	
4:	addiu    $26,$26, 4	    /* set PC to insn after the syscall */
	rfe	 		    /* come back from exception */
	jr       $26		    /* return */

	
	
	
	
