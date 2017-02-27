
/* make sure sltiu sign-extends its immediate argument to 32 bits first
 * before doing the unsigned comparison. */

	.text
.globl __start
.ent __start
__start:
	li $16, 0x80239000
	sltiu $3, $16, -999    /* compare it  - should get v1 = 1*/
	break
.end __start

