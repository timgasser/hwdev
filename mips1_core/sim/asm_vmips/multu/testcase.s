/*  ../vmips -o haltdumpcpu -o haltbreak mthi_lo.rom */
/*  should end with:  R09=7ffffffe R10=80000001  R12=ffffffff  R13=80000001 */
/*  tests instructions: mult multu */

	.text
	.globl __start
__start:
	li $8, 0xffffffff
	li $11, 0x7fffffff
	multu $8, $11
	mfhi $9
	mflo $10
	mult $8, $11
	mfhi $12
	mflo $13
	break
