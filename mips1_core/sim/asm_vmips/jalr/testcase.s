/* tests instructions: jalr */

.text
.globl __start
.ent __start
__start:
li $8, 0x00000040
li $4, 1
li $2, 0
jalr $8
nop
li $10, 1
nop
nop
nop
break
.end __start

.org 0x40
.globl proc
.ent proc
proc:
addi $2, $4, 1
jr $31
.end proc

