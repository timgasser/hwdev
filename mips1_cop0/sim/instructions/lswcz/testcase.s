
	.text
	.globl __start

__start:
	li    $5, 0x00        /* Pass (1) / Fail (0) address */
	li    $6, 0x10        /* Load address */
	li    $7, 0x20        /* Store address */
	li    $8, 0xcafef00d  /* Test data word */

	sw   $8, 0($6) /* Store the test word into memory using CPU */
	nop
	nop

	lwc0 $20, 0($6) /* Load test data into register 20 of COP0 */
	nop
	nop
	nop

	swc0 $20, 0($7) /* Store Cop0 register 20 into the address in reg $7) */
	nop
	nop
	
	lw   $9, 0($7) /* Load memory address stored by COP0 into $9 */
	nop
	nop

	beq   $8, $9, pass
	nop

fail:
	addiu $10, $0, 0
	sw    $10, 0($5)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break
	
pass:	
	addiu $10, $0, 1
	sw    $10, 0($5)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break


