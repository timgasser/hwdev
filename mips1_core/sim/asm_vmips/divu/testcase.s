/* tests instructions: div, divu */
.text
.globl __start
.set noreorder
__start:
	li $8, 0xffffa5a5 /* unsigned = 4,294,944,165, signed = -23131 */
	li $9, 0x000000de /* unsigned or signed = 222 */

	.set nomacro
	.set noreorder

	div $8, $9
	/* $10 <- signed quotient (0xffff_ff98 = -104 )*/
	mflo $10
	/* $11 <- signed remainder (0xffff_ffd5 = -43 ) */
	mfhi $11
	divu $8, $9
	/* $12 <- unsigned quotient (0x0127_350b = 19,346,699) */
	mflo $12
	/* $13 <- unsigned remainder (0x0000_000e = 14 ) */
	mfhi $13

	nop
	nop
	nop
	
	break
