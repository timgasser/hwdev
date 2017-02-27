

.text
.globl __start
.ent __start
__start:
	li $8, 0xa5000000
	li $9, 0
	srlv $11, $8, $9
	li $8, 0xa5000000
	li $9, 16
	srlv $12, $8, $9
	li $8, 0xa5000000
	li $9, 31
	srlv $13, $8, $9
	li $8, 0xa5000000
	li $9, 32
	srlv $14, $8, $9   /* should be same as shifting by 0, because only */
	break              /* bottom 5 bits are used.                       */
.end __start

