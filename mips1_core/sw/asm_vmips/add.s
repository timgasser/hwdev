
/* This doesn't test overflow exceptions; exception.S does that. */
.text
.globl __start
.ent __start
__start:
li $2, -1        /* $2 = 0xFFFFFFFF (-1)  */
li $3, 1         /* $3 = 0x00000001 (1)  */
add $8, $3, $2   /* $8 = $3 (1) + $2 (-1) = 0x00000000 (0)  */
add $9, $3, $0   /* $9 = $3 (1)  */
add $10, $3, $3  /* $10 = $3 (1) + $3 (1) = 0x00000002 (2)  */
add $11, $2, $2  /* $11 = $2 (-1) + $2 (-1) = 0xFFFFFFFE (-2)  */
add $12, $2, $0  /* $12 = $2 (-1)  */
add $13, $0, $0  /* $13 = 0  */
break
.end __start

