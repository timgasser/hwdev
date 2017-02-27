/*  ../vmips -o haltdumpcpu -o haltbreak bgezal.rom */
/*  should end with: R10=00000001 R11=00000001 R12=00000000 */
/*  tests instructions: bgezal */

	.text
	.globl __start
__start:
	li $10, 0         /* $10 = 0  */
	li $11, 0         /* $11 = 0  */
	li $12, 0         /* $12 = 0  */
	li $4, 1          /*  $4 = 1  */
	bgezal $4, foo    /*  $4 >= 0 ? YES -> branch to foo $31 = PC + 8  */
	li $4, 0          /* DLY: $4 = 0   */
	bgezal $4, bar    /*  $4 >= 0 ? YES -> branch to bar $31 = PC + 8  */
	li $4, -1         /* DLY: $4 = -1  */
	bgezal $4, baz    /*  $4 >= 0 ? NO  */
	break

foo: 
	addiu $10, $10, 1 /* $10 = 1  */
	jr $31            /* JUMP to $31 = <bgezal $4, bar>  */
bar: 
	addiu $11, $11, 1 /* $11 = 1  */
	jr $31            /* JUMP to $31 = <bgezal $4, baz>  */
baz: 
	addiu $12, $12, 1 /* $12 = 1  */
	jr $31            /* JUMP to inserted delay slot before break  */

	.org 0x180
	break

