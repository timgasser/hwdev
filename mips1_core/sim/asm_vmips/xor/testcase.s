	.text
	.globl __start
__start:
	addiu $10, $0, 0     /* $10 = 0          */
	li $4, 0xaaaaaaaa    /*  $4 = 0xAAAAAAAA */
	li $5, 0x55555555    /*  $5 = 0x55555555 */
	li $6, 0xffffffff    /*  $5 = 0xFFFFFFFF */
	li $8, 0xaaaaffff    /*  $8 = 0xAAAAFFFF */
	li $9, 0x5555aaaa    /*  $9 = 0x5555AAAA */
	xor $7, $4, $5       /*  $7 = 0xFFFFFFFF */
	beq $7, $6, j1       /*  Jump to 0 */
	addiu $10, $10, 1    /*  Should  */
j1:	xor $7, $5, $6	     /*   */
	beq $7, $4, j2	     /*   */
	addiu $10, $10, 1    /*   */
j2:	xor $7, $4, $4	     /*   */
	beq $7, $0, j3	     /*   */
	addiu $10, $10, 1    /*   */
j3:	xori $7, $4,0x5555   /*   */
	beq $7, $8, j4       /*   */
	addiu $10, $10, 1    /*   */
j4:	xori $7, $5,0xffff   /*   */
	beq $7, $9, j5	     /*   */
	addiu $10, $10, 1    /*   */
j5:	nop
	nop
	nop
	break		     /*   */
	.org 0x180	     /*   */
	break		     /*   */
