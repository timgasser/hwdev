#define MemoryRead(A) (*(volatile unsigned int*)(A))
#define MemoryWrite(A,V) *(volatile unsigned int*)(A)=(V)

#define DEBUG_ADDR 0xC0DEC0DE

int putchar(int value)
{
   MemoryWrite(DEBUG_ADDR, value);
   return 0;
}

int puts(const char *string)
{
   while(*string)
   {
      if(*string == '\n')
         putchar('\r');
      putchar(*string++);
   }
   return 0;
}


int main ()
{
  const char myStr[] = "Hello World\n";
  puts(&myStr);
}
