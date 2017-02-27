
.text
.globl entry
.ent entry
entry:
	li $2, 0x00000010
	li $8, 0x12345678

	sw $0, 0($2)
	sw $0, 4($2)
	sw $0, 8($2)

	sw $8, 0($2)
	sh $8, 4($2)
	sb $8, 8($2)
	lw $8, 0($2)
	lw $9, 4($2)
	lw $10, 8($2)

	nop
	nop
	break
	
	
	
.end entry
