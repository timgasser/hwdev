/* Insert module header here - based on plasma crt*/

#  Include the register names
#include "asm_regnames.h"

#   #Reserve 512 bytes for stack
#   .data
#   .comm InitStack, 512

   .global entry_main

	
   .text
   .align 2
   .global entry
   .ent	entry
entry:
   .set noreorder

#   #These four instructions should be the first instructions.
#   #convert.exe previously initialized $gp, .sbss_start, .bss_end, $sp
#   la    $gp, _gp             #initialize global pointer
#   la    $5, __bss_start      #$5 = .sbss_start
#   la    $4, _end             #$2 = .bss_end
#   la    $sp, InitStack+488   #initialize stack pointer
#

   #  Initialize Stack Pointer ($sp) to make the program fit into 1 KByte of memory space
   addi $29,$29,1024

   # store a value in gp
   addi $28,$28,128
   
	
   jal   main
   nop
   nop

   break
	


   .end entry




#	#  Initialize Stack Pointer ($sp) to make the program fit into 1 KByte of memory space
#	addi $29,$29,1024
#	addi sp,sp,1024
#
# 	# Initialize Return Address ($ra) to jump to the "end-of-test" special address
# 	lui $31,0xDEAD
# 	ori $31,0xBEEF
#
#	#  Jump and link to C
# 	jal main
#	nop
#	break

	