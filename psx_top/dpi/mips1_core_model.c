/*-------------------------------------------------------------------
-- TITLE: Plasma CPU in software.  Executes MIPS(tm) opcodes.
-- AUTHOR: Steve Rhoads (rhoadss@yahoo.com)
-- DATE CREATED: 1/31/01
-- FILENAME: mlite.c
-- PROJECT: Plasma CPU core
-- COPYRIGHT: Software placed into the public domain by the author.
--    Software 'as is' without warranty.  Author liable for nothing.
-- DESCRIPTION:
--   Plasma CPU simulator in C code.  
--   This file served as the starting point for the VHDL code.
--   Assumes running on a little endian PC.
--------------------------------------------------------------------*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <assert.h>

#include "testcase.h"

#undef ENABLE_CACHE
#undef SIMPLE_CACHE

/* #define ENABLE_CACHE */
/* #define SIMPLE_CACHE */


#define ntohs(A) ( ((A)>>8) | (((A)&0xff)<<8) )
#define htons(A) ntohs(A)
#define ntohl(A) ( ((A)>>24) | (((A)&0xff0000)>>8) | (((A)&0xff00)<<8) | ((A)<<24) )
#define htonl(A) ntohl(A)

#define UART_WRITE        0x20000000
#define UART_READ         0x20000000
#define IRQ_MASK          0x20000010
#define IRQ_STATUS        0x20000020
#define CONFIG_REG        0x20000070
#define MMU_PROCESS_ID    0x20000080
#define MMU_FAULT_ADDR    0x20000090
#define MMU_TLB           0x200000a0

#define IRQ_UART_READ_AVAILABLE  0x001
#define IRQ_UART_WRITE_AVAILABLE 0x002
#define IRQ_COUNTER18_NOT        0x004
#define IRQ_COUNTER18            0x008
#define IRQ_MMU                  0x200

#define MMU_ENTRIES 4
#define MMU_MASK (1024*4-1)

typedef struct
{
   unsigned int virtualAddress;
   unsigned int physicalAddress;
} MmuEntry;

typedef struct {
   int r[32];
   int pc, pc_next, epc;
   unsigned int hi;
   unsigned int lo;
   int status;
   int userMode;
   int processId;
   int exceptionId;
   int faultAddr;
   int irqStatus;
   int skip;
   unsigned char *mem;
   int wakeup;
   int big_endian;
   MmuEntry mmuEntry[MMU_ENTRIES];
   int dlySlot;
   int dlyTarget;
} State;

static char *opcode_string[]={
   "SPECIAL","REGIMM","J","JAL","BEQ","BNE","BLEZ","BGTZ",
   "ADDI","ADDIU","SLTI","SLTIU","ANDI","ORI","XORI","LUI",
   "COP0","COP1","COP2","COP3","BEQL","BNEL","BLEZL","BGTZL",
   "?","?","?","?","?","?","?","?",
   "LB","LH","LWL","LW","LBU","LHU","LWR","?",
   "SB","SH","SWL","SW","?","?","SWR","CACHE",
   "LL","LWC1","LWC2","LWC3","?","LDC1","LDC2","LDC3"
   "SC","SWC1","SWC2","SWC3","?","SDC1","SDC2","SDC3"
};

static char *special_string[]={
   "SLL","?","SRL","SRA","SLLV","?","SRLV","SRAV",
   "JR","JALR","MOVZ","MOVN","SYSCALL","BREAK","?","SYNC",
   "MFHI","MTHI","MFLO","MTLO","?","?","?","?",
   "MULT","MULTU","DIV","DIVU","?","?","?","?",
   "ADD","ADDU","SUB","SUBU","AND","OR","XOR","NOR",
   "?","?","SLT","SLTU","?","DADDU","?","?",
   "TGE","TGEU","TLT","TLTU","TEQ","?","TNE","?",
   "?","?","?","?","?","?","?","?"
};

static char *regimm_string[]={
   "BLTZ","BGEZ","BLTZL","BGEZL","?","?","?","?",
   "TGEI","TGEIU","TLTI","TLTIU","TEQI","?","TNEI","?",
   "BLTZAL","BEQZAL","BLTZALL","BGEZALL","?","?","?","?",
   "?","?","?","?","?","?","?","?"
};

/* static unsigned int HWMemory[8]; */ 

void helloWorld()
{
  printf("[MLITE C] Hello world from mlite_dpi.c !!\n");
  return;
}


#ifdef ENABLE_CACHE
/************* Optional MMU and cache implementation *************/
/* TAG = VirtualAddress | ProcessId | WriteableBit */
unsigned int mmu_lookup(State *s, unsigned int processId, 
                         unsigned int address, int write)
{
   int i;
   unsigned int compare, tag;

   if(processId == 0 || s->userMode == 0)
      return address;
   //if(address < 0x30000000)
   //   return address;
   compare = (address & ~MMU_MASK) | (processId << 1);
   for(i = 0; i < MMU_ENTRIES; ++i)
   {
      tag = s->mmuEntry[i].virtualAddress;
      if((tag & ~1) == compare && (write == 0 || (tag & 1)))
         return s->mmuEntry[i].physicalAddress | (address & MMU_MASK);
   }
   //printf("\nMMUTlbMiss 0x%x PC=0x%x w=%d pid=%d user=%d\n", 
   //   address, s->pc, write, processId, s->userMode);
   //printf("m");
   s->exceptionId = 1;
   s->faultAddr = address & ~MMU_MASK;
   s->irqStatus |= IRQ_MMU;
   return address;
}


#define CACHE_SET_ASSOC_LN2   0
#define CACHE_SET_ASSOC       (1 << CACHE_SET_ASSOC_LN2)
#define CACHE_SIZE_LN2        (13 - CACHE_SET_ASSOC_LN2)  //8 KB
#define CACHE_SIZE            (1 << CACHE_SIZE_LN2)
#define CACHE_LINE_SIZE_LN2   2                           //4 bytes
#define CACHE_LINE_SIZE       (1 << CACHE_LINE_SIZE_LN2)

static int cacheData[CACHE_SET_ASSOC][CACHE_SIZE/sizeof(int)];
static int cacheAddr[CACHE_SET_ASSOC][CACHE_SIZE/CACHE_LINE_SIZE];
static int cacheSetNext;
static int cacheMiss, cacheWriteBack, cacheCount;

static void cache_init(void)
{
   int set, i;
   for(set = 0; set < CACHE_SET_ASSOC; ++set)
   {
      for(i = 0; i < CACHE_SIZE/CACHE_LINE_SIZE; ++i)
         cacheAddr[set][i] = 0xffff0000;
   }
}

/* Write-back cache memory tagged by virtual address and processId */
/* TAG = virtualAddress | processId | dirtyBit */
static int cache_load(State *s, unsigned int address, int write)
{
   int set, i, pid, miss, offsetAddr, offsetData, offsetMem;
   unsigned int addrTagMatch, addrPrevMatch=0;
   unsigned int addrPrev;
   unsigned int addressPhysical, tag;

   ++cacheCount;
   addrTagMatch = address & ~(CACHE_SIZE-1);
   offsetAddr = (address & (CACHE_SIZE-1)) >> CACHE_LINE_SIZE_LN2;

   /* Find match */
   miss = 1;
   for(set = 0; set < CACHE_SET_ASSOC; ++set)
   {
      addrPrevMatch = cacheAddr[set][offsetAddr] & ~(CACHE_SIZE-1);
      if(addrPrevMatch == addrTagMatch)
      {
         miss = 0;
         break;
      }
   }

   /* Cache miss? */
   if(miss)
   {
      ++cacheMiss;
      set = cacheSetNext;
      cacheSetNext = (cacheSetNext + 1) & (CACHE_SET_ASSOC-1);
   }
   //else if(write || (address >> 28) != 0x1)
   //{
   //   tag = cacheAddr[set][offsetAddr];
   //   pid = (tag & (CACHE_SIZE-1)) >> 1; 
   //   if(pid != s->processId)
   //      miss = 1;
   //}

   if(miss)
   {
      offsetData = address & (CACHE_SIZE-1) & ~(CACHE_LINE_SIZE-1);

      /* Cache line dirty? */
      if(cacheAddr[set][offsetAddr] & 1)
      {
         /* Write back cache line */
         tag = cacheAddr[set][offsetAddr];
         addrPrev = tag & ~(CACHE_SIZE-1);
         addrPrev |= address & (CACHE_SIZE-1);
         pid = (tag & (CACHE_SIZE-1)) >> 1; 
         addressPhysical = mmu_lookup(s, pid, addrPrev, 1);   //virtual->physical
         if(s->exceptionId)
            return 0;
         offsetMem = addressPhysical & ~(CACHE_LINE_SIZE-1);
         for(i = 0; i < CACHE_LINE_SIZE; i += 4)
            mem_write(s, 4, offsetMem + i, cacheData[set][(offsetData + i) >> 2]);
         ++cacheWriteBack;
      }

      /* Read cache line */
      addressPhysical = mmu_lookup(s, s->processId, address, write); //virtual->physical
      if(s->exceptionId)
         return 0;
      offsetMem = addressPhysical & ~(CACHE_LINE_SIZE-1);
      cacheAddr[set][offsetAddr] = addrTagMatch;
      for(i = 0; i < CACHE_LINE_SIZE; i += 4)
         cacheData[set][(offsetData + i) >> 2] = mem_read(s, 4, offsetMem + i);
   }
   cacheAddr[set][offsetAddr] |= write;
   return set;
}

static int cache_read(State *s, int size, unsigned int address)
{
   int set, offset;
   int value;

   if((address & 0xfe000000) != 0x10000000)
      return mem_read(s, size, address);

   set = cache_load(s, address, 0);
   if(s->exceptionId)
      return 0;
   offset = (address & (CACHE_SIZE-1)) >> 2;
   value = cacheData[set][offset];
   if(s->big_endian)
      address ^= 3;
   switch(size) 
   {
      case 2: 
         value = (value >> ((address & 2) << 3)) & 0xffff;
         break;
      case 1:
         value = (value >> ((address & 3) << 3)) & 0xff;
         break;
   }
   return value;
}

static void cache_write(State *s, int size, int unsigned address, unsigned int value)
{
   int set, offset;
   unsigned int mask;

   if((address >> 28) != 0x1) // && (s->processId == 0 || s->userMode == 0))
   {
      mem_write(s, size, address, value);
      return;
   }

   set = cache_load(s, address, 1);
   if(s->exceptionId)
      return;
   offset = (address & (CACHE_SIZE-1)) >> 2;
   if(s->big_endian)
      address ^= 3;
   switch(size) 
   {
      case 2:
         value &= 0xffff;
         value |= value << 16;
         mask = 0xffff << ((address & 2) << 3);
         break;
      case 1:
         value &= 0xff;
         value |= (value << 8) | (value << 16) | (value << 24);
         mask = 0xff << ((address & 3) << 3);
         break;
      case 4:
      default:
         mask = 0xffffffff;
         break;
   }
   cacheData[set][offset] = (value & mask) | (cacheData[set][offset] & ~mask);
}

#define mem_read cache_read
#define mem_write cache_write

#else
static void cache_init(void) {}
#endif


#ifdef SIMPLE_CACHE

//Write through direct mapped 4KB cache
#define CACHE_MISS 0x1ff
static unsigned int cacheData[1024];
static unsigned int cacheAddr[1024]; //9-bit addresses
static int cacheTry, cacheMiss, cacheInit;

static int cache_read(State *s, int size, unsigned int address)
{
   int offset;
   unsigned int value, value2, address2=address;

   if(cacheInit == 0)
   {
      cacheInit = 1;
      for(offset = 0; offset < 1024; ++offset)
         cacheAddr[offset] = CACHE_MISS;
   }

   offset = address >> 20;
   if(offset != 0x100 && offset != 0x101)
      return mem_read(s, size, address);

   ++cacheTry;
   offset = (address >> 2) & 0x3ff;
   if(cacheAddr[offset] != (address >> 12) || cacheAddr[offset] == CACHE_MISS)
   {
      ++cacheMiss;
      cacheAddr[offset] = address >> 12;
      cacheData[offset] = mem_read(s, 4, address & ~3);
   }
   value = cacheData[offset];
   if(s->big_endian)
      address ^= 3;
   switch(size) 
   {
      case 2: 
         value = (value >> ((address & 2) << 3)) & 0xffff;
         break;
      case 1:
         value = (value >> ((address & 3) << 3)) & 0xff;
         break;
   }

   //Debug testing
   value2 = mem_read(s, size, address2);
   if(value != value2)
      printf("miss match\n");
   //if((cacheTry & 0xffff) == 0) printf("\n***cache(%d,%d)\n ", cacheMiss, cacheTry);
   return value;
}

static void cache_write(State *s, int size, int unsigned address, unsigned int value)
{
   int offset;

   mem_write(s, size, address, value);

   offset = address >> 20;
   if(offset != 0x100 && offset != 0x101)
      return;

   offset = (address >> 2) & 0x3ff;
   if(size != 4)
   {
      cacheAddr[offset] = CACHE_MISS;
      return;
   }
   cacheAddr[offset] = address >> 12;
   cacheData[offset] = value;
}

#define mem_read cache_read
#define mem_write cache_write
#endif  /* SIMPLE_CACHE */

/************* End optional cache implementation *************/


void mult_big(unsigned int a, 
              unsigned int b,
              unsigned int *hi, 
              unsigned int *lo)
{
   unsigned int ahi, alo, bhi, blo;
   unsigned int c0, c1, c2;
   unsigned int c1_a, c1_b;

   ahi = a >> 16;
   alo = a & 0xffff;
   bhi = b >> 16;
   blo = b & 0xffff;

   c0 = alo * blo;
   c1_a = ahi * blo;
   c1_b = alo * bhi;
   c2 = ahi * bhi;

   c2 += (c1_a >> 16) + (c1_b >> 16);
   c1 = (c1_a & 0xffff) + (c1_b & 0xffff) + (c0 >> 16);
   c2 += (c1 >> 16);
   c0 = (c1 << 16) + (c0 & 0xffff);
   *hi = c2;
   *lo = c0;
}

void mult_big_signed(int a, 
                     int b,
                     unsigned int *hi, 
                     unsigned int *lo)
{
   unsigned int ahi, alo, bhi, blo;
   unsigned int c0, c1, c2;
   int c1_a, c1_b;

   ahi = a >> 16;
   alo = a & 0xffff;
   bhi = b >> 16;
   blo = b & 0xffff;

   c0 = alo * blo;
   c1_a = ahi * blo;
   c1_b = alo * bhi;
   c2 = ahi * bhi;

   c2 += (c1_a >> 16) + (c1_b >> 16);
   c1 = (c1_a & 0xffff) + (c1_b & 0xffff) + (c0 >> 16);
   c2 += (c1 >> 16);
   c0 = (c1 << 16) + (c0 & 0xffff);
   *hi = c2;
   *lo = c0;
}


/* Extra DPI global variable declarations */
static State cpuState;
static int instCount;

/* Initialise function  */
void cpuInit ()
{
   State *s=&cpuState;
   /* int bytes, index; */
   printf("[MLITE C ] Initialising Plasma Emulator\n");
   memset(s, 0, sizeof(cpuState));
   s->big_endian = 0;
   s->processId = 0;
   s->pc = 0xbfc00000; /* CPU reset vector */
   s->dlySlot = 0; /* Can't start on a delay slot */

   instCount = 0;
}

/* step function  */
/* execute one cycle of a Plasma CPU */
void cpuCycle(int pc, int opcode, int rd_data, int show_mode)
{
  /* unsigned int opcode; */
   State *s=&cpuState;
   /*   int show_mode = 1; */
   unsigned int op, rs, rt, rd, re, func, imm, target;
   int imm_shift, branch=0, lbranch=2, skip2=0;
   int jump=0; /*, jumpTarget; <- don't need target, pc_next is used for this .. */
   int *r=s->r;
   unsigned int *u=(unsigned int*)s->r;
   unsigned int ptr, epc, rSave;

   /* opcode = mem_read(s, 4, s->pc); <- the opcode is passed from the verilog */

 /* Remove this check now there is a PC Queue in teh SV testbench  
  *  if (pc != s->pc_next)
  *   {
  *     printf("[DPI INFO] PC Error, Simulation = 0x%8.8x, C Model = 0x%8.8x\n", pc, s->pc_next);
  *   }
 */
   instCount++;

   op = (opcode >> 26) & 0x3f;
   rs = (opcode >> 21) & 0x1f;
   rt = (opcode >> 16) & 0x1f;
   rd = (opcode >> 11) & 0x1f;
   re = (opcode >> 6) & 0x1f;
   func = opcode & 0x3f;
   imm = opcode & 0xffff;
   imm_shift = (((int)(short)imm) << 2);
   target = (opcode & 0x03ffffff) << 2; /* shift up and down produced wrong target */
   ptr = (short)imm + r[rs];
   r[0] = 0;
   if(show_mode) 
   {
     printf("[C REF] INST #%4d : PC = %8.8x %8.8x ", instCount, pc, opcode);
      if(op == 0) 
         printf("%8s ", special_string[func]);
      else if(op == 1) 
         printf("%8s ", regimm_string[rt]);
      else 
         printf("%8s ", opcode_string[op]);
      printf("rs $%2.2d, rt $%2.2d, rd $%2.2d, re $%2.2d, ptr %8.8x ", rs, rt, rd, re, ptr);
      printf("%4.4x", imm);
      if(show_mode == 2)
         printf(" rs[%2.2d]=%8.8x rt[%2.2d]=%8.8x", rs, r[rs], rt, r[rt]);
      printf("\n");
   }
   if(show_mode > 5) 
      return;
   epc = s->pc + 4;
   if(s->pc_next != s->pc + 4)
     epc |= 2;  /* branch delay slot */

   s->pc = pc; /* s->pc_next <- set current pc to the value from the testbench */

   s->pc_next = s->pc + 4; /* set expected next PC to default of next work. Jump and branch PCs updated at bottom of function */
   if(s->skip) 
   {
      s->skip = 0;
      return;
   }
   rSave = r[rt];
   switch(op) 
   {
   case 0x00:/*SPECIAL*/
     switch(func) 
       {
       case 0x00:/*SLL*/  r[rd]=r[rt]<<re          	    	      ; refRegPush(rd,r[rd]); break;
       case 0x02:/*SRL*/  r[rd]=u[rt]>>re          	    	      ; refRegPush(rd,r[rd]); break;
       case 0x03:/*SRA*/  r[rd]=r[rt]>>re          	    	      ; refRegPush(rd,r[rd]); break;
       case 0x04:/*SLLV*/ r[rd]=r[rt]<<r[rs]       	    	      ; refRegPush(rd,r[rd]); break;
       case 0x06:/*SRLV*/ r[rd]=u[rt]>>r[rs]       	    	      ; refRegPush(rd,r[rd]); break;
       case 0x07:/*SRAV*/ r[rd]=r[rt]>>r[rs]       	    	      ; refRegPush(rd,r[rd]); break;    
       case 0x08:/*JR*/   s->pc_next=r[rs]                     	      ; refRegPush(0, 0); jump=1; break; /* target and delay slot PC set at end of function. The encoding of the instruction writes to reg 0  */
       case 0x09:/*JALR*/ r[rd]=s->pc_next+4; s->pc_next=r[rs]   	      ; refRegPush(rd,r[rd]); jump=1; break; /* target and delay slot PC set at end of function */
       case 0x0a:/*MOVZ*/ if(!r[rt]) r[rd]=r[rs]    	    	      ; break;  /*IV - not supported */ 
       case 0x0b:/*MOVN*/ if(r[rt]) r[rd]=r[rs]     	    	      ; break;  /*IV - not supported */
       case 0x0c:/*SYSCALL*/ epc|=1; s->exceptionId=1  	    	      ; break;  /*IV - not supported */
       case 0x0d:/*BREAK*/   epc|=1; s->exceptionId=1  	    	      ; break;  /*IV - not supported */
       case 0x0f:/*SYNC*/ s->wakeup=1               	    	      ; break;  /* not supported */
       case 0x10:/*MFHI*/ r[rd]=s->hi               	    	      ; refRegPush(rd,s->hi)  ; break;
       case 0x11:/*MTHI*/ s->hi=r[rs]               	    	      ; refRegPush(0,r[rs])  ; refLoHiPush(1, s->hi) ; break; /* The MTHI and MTLO instructions also write the same value to reg 0 (easier decode)*/
       case 0x12:/*MFLO*/ r[rd]=s->lo               	    	      ; refRegPush(rd,s->lo)  ; break;
       case 0x13:/*MTLO*/ s->lo=r[rs]               	    	      ; refRegPush(0,r[rs])  ; refLoHiPush(0, s->lo) ; break; /* The MTHI and MTLO instructions also write the same value to reg 0 (easier decode)*/    
       case 0x18:/*MULT*/ mult_big_signed(r[rs],r[rt],&s->hi,&s->lo)  ; refRegPush(0, 0); refLoHiPush(0, s->lo) ; refLoHiPush(1, s->hi); break; /* the mult instructions end up writing to register 0 due to the encoding .. */
       case 0x19:/*MULTU*/ mult_big(r[rs],r[rt],&s->hi,&s->lo)        ; refRegPush(0, 0); refLoHiPush(0, s->lo) ; refLoHiPush(1, s->hi); break; 
       case 0x1a:/*DIV*/  s->lo=r[rs]/r[rt]; s->hi=r[rs]%r[rt]        ; refRegPush(0, 0); refLoHiPush(0, s->lo) ; refLoHiPush(1, s->hi) ; break; /* the div instructions end up writing to register 0 due to the encoding .. */
       case 0x1b:/*DIVU*/ s->lo=u[rs]/u[rt]; s->hi=u[rs]%u[rt]        ; refRegPush(0, 0); refLoHiPush(0, s->lo) ; refLoHiPush(1, s->hi) ; break;
       case 0x20:/*ADD*/  r[rd]=r[rs]+r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x21:/*ADDU*/ r[rd]=r[rs]+r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x22:/*SUB*/  r[rd]=r[rs]-r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x23:/*SUBU*/ r[rd]=r[rs]-r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x24:/*AND*/  r[rd]=r[rs]&r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x25:/*OR*/   r[rd]=r[rs]|r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x26:/*XOR*/  r[rd]=r[rs]^r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x27:/*NOR*/  r[rd]=~(r[rs]|r[rt])                        ; refRegPush(rd,r[rd]) ; break;
       case 0x2a:/*SLT*/  r[rd]=r[rs]<r[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x2b:/*SLTU*/ r[rd]=u[rs]<u[rt]                           ; refRegPush(rd,r[rd]) ; break;
       case 0x2d:/*DADDU*/r[rd]=r[rs]+u[rt]                           ; refRegPush(rd,r[rd]) ; break; 
       case 0x31:/*TGEU*/ break;
       case 0x32:/*TLT*/  break;
       case 0x33:/*TLTU*/ break;
       case 0x34:/*TEQ*/  break;
       case 0x36:/*TNE*/  break;
       default: printf("ERROR0(*0x%x~0x%x)\n", s->pc, opcode);
	 s->wakeup=1;
										     }
         break;
      case 0x01:/*REGIMM*/
         switch(rt) {
            case 0x10:/*BLTZAL*/ r[31]=s->pc_next + 4  ; refRegPush(31,r[31]) ;
            case 0x00:/*BLTZ*/   branch=r[rs]<0    ;  break;
            case 0x11:/*BGEZAL*/ r[31]=s->pc_next + 4  ; refRegPush(31,r[31]) ;
            case 0x01:/*BGEZ*/   branch=r[rs]>=0   ;  break;
            case 0x12:/*BLTZALL*/r[31]=s->pc_next + 4  ; refRegPush(31,r[31]) ; 
            case 0x02:/*BLTZL*/  lbranch=r[rs]<0   ;  break;
            case 0x13:/*BGEZALL*/r[31]=s->pc_next + 4  ; refRegPush(31,r[31]) ; 
            case 0x03:/*BGEZL*/  lbranch=r[rs]>=0  ;  break;
            default: printf("ERROR1\n"); s->wakeup=1;
          }
         break;
      case 0x03:/*JAL*/    r[31]=s->pc_next + 4                 ; refRegPush(31,r[31]); jump=1;
      case 0x02:/*J*/      s->pc_next=(s->pc&0xf0000000)|target ; jump=1; break; /* todo ! check the pc queue gets updated */
      case 0x04:/*BEQ*/    branch=r[rs]==r[rt]                  ; break;  /* todo ! check the pc queue gets updated */
      case 0x05:/*BNE*/    branch=r[rs]!=r[rt]                  ; break;  /* todo ! check the pc queue gets updated */
      case 0x06:/*BLEZ*/   branch=r[rs]<=0                      ; break;  /* todo ! check the pc queue gets updated */
      case 0x07:/*BGTZ*/   branch=r[rs]>0                       ; break;  /* todo ! check the pc queue gets updated */
      case 0x08:/*ADDI*/   r[rt]=r[rs]+(short)imm               ; refRegPush(rt,r[rt]); break;
      case 0x09:/*ADDIU*/  u[rt]=u[rs]+(short)imm               ; refRegPush(rt,u[rt]); break; 
      case 0x0a:/*SLTI*/   r[rt]=r[rs]<(short)imm               ; refRegPush(rt,r[rt]); break;
      case 0x0b:/*SLTIU*/  u[rt]=u[rs]<(unsigned int)(short)imm ; refRegPush(rt,u[rt]); break;
      case 0x0c:/*ANDI*/   r[rt]=r[rs]&imm                      ; refRegPush(rt,r[rt]); break;
      case 0x0d:/*ORI*/    r[rt]=r[rs]|imm                      ; refRegPush(rt,r[rt]); break;
      case 0x0e:/*XORI*/   r[rt]=r[rs]^imm                      ; refRegPush(rt,r[rt]); break;
      case 0x0f:/*LUI*/    r[rt]=(imm<<16)                      ; refRegPush(rt,r[rt]); break;
      case 0x10:/*COP0*/
        switch(rs) { /* RS contains the type of COP0 command */
        case 0x00: /* MFC0 */ if (12 == rd) r[rt]=s->status | (1 << 21); refRegPush(rt,r[rt]); /* printf("[C REF] MFC0 cpu reg %2.2d, data = 0x%8.8x\n", rt, r[rt]); */ break;
        case 0x04: /* MTC0 */ if (12 == rd) s->status=r[rt]; /* printf("[C REF] MTC0 cop reg %2.2d, data = 0x%8.8x\n", rd, s->status); */ break;
          default: printf("[C REF] ERROR unrecognised COP opcode \n");
        }
       break;
      case 0x11:/*COP1*/ break;
      case 0x12:/*COP2*/ break;
      case 0x13:/*COP3*/ break;
      case 0x14:/*BEQL*/   lbranch=r[rs]==r[rt];    break; /* todo - check the pc is updated after this */
      case 0x15:/*BNEL*/   lbranch=r[rs]!=r[rt];    break; /* todo - check the pc is updated after this */
      case 0x16:/*BLEZL*/  lbranch=r[rs]<=0;        break; /* todo - check the pc is updated after this */
      case 0x17:/*BGTZL*/  lbranch=r[rs]>0;         break; /* todo - check the pc is updated after this */
      case 0x1c:/*MAD*/  break;   /*IV*/
      case 0x20:/*LB*/   r[rt]=rd_data  ; refDataM2SPush(1, 1, ptr, 0)     ; refRegPush(rt,r[rt]); break;
      case 0x21:/*LH*/   r[rt]=rd_data  ; refDataM2SPush(1, 2, ptr, 0)     ; refRegPush(rt,r[rt]); break;
      case 0x22:/*LWL*/  
	/* target=8*(ptr&3); */
	/* r[rt]=(r[rt]&~(0xffffffff<<target))| */
	/*       (mem_read(s,4,ptr&~3)<<target); break; */
      case 0x23:/*LW*/   r[rt]=rd_data                 ; refDataM2SPush(1, 4, ptr, 0)     ; refRegPush(rt,r[rt]); break; /* Stores push the data queue in the mem_write function */
      case 0x24:/*LBU*/  r[rt]=(unsigned char)rd_data  ; refDataM2SPush(1, 1, ptr, 0)     ; refRegPush(rt,r[rt]); break;
      case 0x25:/*LHU*/  r[rt]=(unsigned short)rd_data ; refDataM2SPush(1, 2, ptr, 0)     ; refRegPush(rt,r[rt]); break;
      case 0x26:/*LWR*/  
	/* target=32-8*(ptr&3); */
	/* r[rt]=(r[rt]&~((unsigned int)0xffffffff>>target))| */
	/* ((unsigned int)mem_read(s,4,ptr&~3)>>target);  */
                         break;
      case 0x28:/*SB*/   refDataM2SPush(0, 1, ptr, r[rt])        ; break; 
      case 0x29:/*SH*/   refDataM2SPush(0, 2, ptr, r[rt])        ; break;
      case 0x2a:/*SWL*/  
	/* mem_write(s,1,ptr,r[rt]>>24);   */
	/* mem_write(s,1,ptr+1,r[rt]>>16); */
	/* mem_write(s,1,ptr+2,r[rt]>>8); */
	/* mem_write(s,1,ptr+3,r[rt]); break; */
      case 0x2b:/*SW*/   refDataM2SPush(0, 4, ptr, r[rt])        ; break;
      case 0x2e:/*SWR*/  break; /* fixme */
      case 0x2f:/*CACHE*/break;
      case 0x30:/*LL*/   r[rt]=rd_data                           ; refRegPush(rt,r[rt]); break;
      case 0x31:/*LWC1*/ break;
      case 0x32:/*LWC2*/ break;
      case 0x33:/*LWC3*/ break;
      case 0x35:/*LDC1*/ break;
      case 0x36:/*LDC2*/ break;
      case 0x37:/*LDC3*/ break;
      case 0x38:/*SC*/   refDataM2SPush(0, 4, ptr, r[rt])        ; break;
      case 0x39:/*SWC1*/ break;
      case 0x3a:/*SWC2*/ break;
      case 0x3b:/*SWC3*/ break;
      case 0x3d:/*SDC1*/ break;
      case 0x3e:/*SDC2*/ break;
      case 0x3f:/*SDC3*/ break;
      default: printf("ERROR2 address=0x%x opcode=0x%x\n", s->pc, opcode); 
         s->wakeup=1;
   }

   s->pc_next += (branch || lbranch == 1) ? imm_shift : 0;
   s->pc_next &= ~3;
   s->skip = (lbranch == 0) | skip2;

   if(s->exceptionId)
   {
     /* Check BEV bit in Status register find next PC value */
     if ((s->status >> 22) & 1)
       {
         s->pc_next = 0x80000080;
       }
     else
       {
         s->pc_next = 0xbfc00180;
       }
      r[rt] = rSave;
      s->epc = epc; 
/*     s->pc_next = 0x3c; */
      s->skip = 1; 
      s->exceptionId = 0;
      s->userMode = 0;
      /* s->wakeup = 1; */

      refInstM2SPush(s->pc_next);

      return;
   }

   /* In a delay slot, don't push PC as it was pushed by the previous branch instruction when taken */
   if (s->dlySlot)
     {
       /* printf("[INFO ] C Model - PC = 0x08%x, Branch delay slot\n", s->pc); */
       s->dlySlot = 0;
      }
   /* If it's a branch instruction being taken, push the delay slot pc and target. Set dlySlot */
   else if (branch || lbranch == 1)
     {
       /* printf("[INFO ] C Model - PC = 0x08%x, Branch taken, dest PC = 0x08%x\n", s->pc, s->pc_next); */
       /* printf("[INFO ] C Model - imm = %8d, imm_shift = %8d\n", imm, imm_shift); */
       refInstM2SPush(s->pc + 4);   
       refInstM2SPush(s->pc_next);
       s->dlySlot = 1;
     }
   else if (jump)
     {
       /* printf("[INFO ] C Model - PC = 0x%x, Jump to PC = 0x%x\n", s->pc, s->pc_next); */
       refInstM2SPush(s->pc + 4);   
       refInstM2SPush(s->pc_next);
       s->dlySlot = 1;
     }
   /* Not in a branch or delay slot, just push the next PC*/
   else
     {
       refInstM2SPush(s->pc_next);
     }

}



/* Finish function  */
int cpuEnd ()
{
   State *s=&cpuState;
   int regLoop;

   printf("\n");
   printf("[DPI INFO ] Dumping processor state..\n");

   for (regLoop = 0 ; regLoop < 32 ; regLoop++)
     {
       printf("[DPI INFO ] Reg %d = 0x%8.8x \n", regLoop, s->r[regLoop]);
     }


   printf("\n");

   return(0);
}
