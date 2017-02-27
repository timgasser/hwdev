/*  ../vmips -o noinstdump -o haltdumpcpu -o haltbreak addi.rom */
/*  should end w/ pc=bfc00180, next_epc=bfc00180, and R04=00000001  */
/*  R05=00000003  R06=00000007  R07=00000006  R08=7fffffff */
/*  tests instructions: addi */

	.text
	.globl __start

__start:
	addi $4, $0, 1        /* $4 = 0x00000001 (1)  */
	addi $5, $4, 2        /* $5 = $4 (1) + 2 = 0x00000003 (3)  */
	addi $6, $5, 4        /* $6 = $5 (3) + 4 = 0x00000007 (7)  */
	addi $7, $6, 0xffff   /* $7 = $6 (7) - 1 = 0x00000006 (6)  */
	li $8, 0x7fffffff     /* $8 = 0x7FFFFFFF (-1)  */
/*	addi $8, $8, 0x7fff      $8 = 0x80007FFE   <=- Had to remove this as it caused overflow and wasn't written to the register */
	break

	.org 0x180
	break

