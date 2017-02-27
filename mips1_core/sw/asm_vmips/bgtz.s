/*  should end with: R10=00000000 R11=00000000 R12=00000000 */
/*  tests instructions: bgtz */

	.text
	.globl __start
__start:
	li $10, 0         /* $10 = 0 */
	li $11, 0         /* $11 = 0 */
	li $12, 0         /* $12 = 0 */

test_neg:	
	li $4, -1              /* $4 = -1 */
	bgtz $4, false_neg     /* $4 > 0 ? NO */

test_zero:	
	li $4, 0               /* $4 = 0 */
	bgtz $4, false_zero    /* $4 > 0 ? NO */

test_pos:	
	li $4, 1
	bgtz $4, pass
	nop
	li $13, 1
	break
	
	
false_neg:                    /* Should never jump here */
	li $10, 1
	j test_zero
	
false_zero:                   /* Should never jump here */
	li $11, 1
	j test_pos

pass:
	li $12, 1             /* Should jump here at the end ($12 = 1) */
	nop
	break

	.org 0x180
	break

