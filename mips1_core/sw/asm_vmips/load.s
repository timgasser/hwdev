/* Load test, tests the following LB, LBU, LH, LHU, LW and SW */
/* Doesn't check LWL or LWR */
/* Need to use a value which can distinguish between unsigned and
 * signed loads (i.e. bit 7 and 15 must be set). 
 */

	.text
	.globl __start
	.ent __start
	__start:

	li $5, 0x00000010
	li $4, 0xCAFEA5A5
	sw $4, 0x00000010 ($5)

	/* 0xCAFEA5A5 now stored at address 0x00000020 */

	lb  $10, 0x00000010 ($5) 	/* $10 = 0xFFFFFFA5 */
	lbu $11, 0x00000010 ($5) 	/* $11 = 0x000000A5 */ 
	lh  $12, 0x00000010 ($5) 	/* $12 = 0xFFFFA5A5 */ 
	lhu $13, 0x00000010 ($5) 	/* $13 = 0x0000A5A5 */ 
	lw  $14, 0x00000010 ($5)	/* $14 = 0xCAFEA5A5 */ 

	nop
	nop
	break
.end __start
	