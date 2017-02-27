
	.text
	.globl __start

__start:
	li    $8, 0x1020003c  /* Need COP0 usable !! Set KU and IE bits old and previous (current is 0) */
	mtc0  $8, $12         /* Store the KU and IE bits in the Status register */
	nop                   /* Insert some nops so the value is stored */
	nop
	nop
	mfc0  $9, $12         /* Move Status register back, check it matches */
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	beq   $8, $9, pass_readback
	nop

fail_readback:
	addiu $10, $0, 0
	sw    $10, 0($0)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break
	
pass_readback:
	rfe                   /* Now do an RFE Insert some nops so the value is stored */
	nop                   /* Insert some nops */
	nop
	mfc0  $9, $12         /* Move Status register back */
	nop                   /* Insert some nops so the value is stored */
	nop
	nop
	li    $7, 0x0000003f  /* Store bottom 6 bits set in reg 7 */ 
	and   $6, $9, $7      /* AND-isolate the status bottom 6 bits, store in reg 6 */
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	beq   $7, $6, pass_comparison  /* If all 6 bits are set, pass ! */ 

fail_comparison:
	addiu $10, $0, 0
	sw    $10, 0($0)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break
	
pass_comparison:	
	addiu $10, $0, 1
	sw    $10, 0($0)
	nop                   /* Insert some nops so the value is stored */
	nop
	nop 
	break


