
	.text
	.globl __start

__start:
	li    $8, 0xcafef00d  /* Store something in CPU reg 8 */
	mtc0  $8, $20         /* Load contents of CPU reg 8 into COP0 reg 20 */
	nop                   /* Insert some nops so the value is stored */
	nop
	nop
	mfc0  $9, $20         /* Move COP0 reg 20 into CPU reg 9 */
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	beq   $8, $9, pass
	nop

fail:
	addiu $10, $0, 0
	sw    $10, 0($0)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break
	
pass:	
	addiu $10, $0, 1
	sw    $10, 0($0)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break


