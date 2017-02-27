/*  should end with: R10=00000001 R11=00000001 R12=00000001 */
/*  tests instructions: blez */

	.text
	.globl __start
__start:
	li $10, 0         /* $10 = 0 */
	li $11, 0         /* $11 = 0 */
	li $12, 0         /* $12 = 0 */

test_neg:	
	li $4, -1             /* $4 = -1 */
	blez $4, true_neg     /* $4 > 0 ? NO */

test_zero:	
	li $4, 0               /* $4 = 0 */
	blez $4, true_zero    /* $4 >= 0 ? YES */

test_pos:	
	li $4, 1
	blez $4, false_pos
	nop
	li $12, 1
	break
	
	
true_neg:                    
	li $10, 1          /* Should jump here */
	j test_zero
	
true_zero:                   
	li $11, 1          /* Should jump here */
	j test_pos

false_pos:
	li $13, 1	
	nop		   /* Should NEVER jump here */
	break

	.org 0x180
	break

