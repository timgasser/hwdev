/* matrix multiplication */

//#include <stdio.h>
//#include <stdlib.h>

#define  N  50

static int randVal = 0;
int *ptrUart;

int a[N][N], b[N][N], c[N][N];

int rnum() {
  randVal += 17;
  return (randVal);
  //  return( ((random())%10)+1 );

}

show() {
  int i,j;

  for(i=0; i<N; i++)  {
    for(j=0; j<N; j++)

      *ptrUart = c[i][j];

      //      printf("%d ",c[i][j]);
      //    printf("\n");
  }
}

inita() {
  int i,j;

  for(i=0; i<N; i++)
    for(j=0; j<N; j++)
      a[i][j] = 2;
}

initb() {
  int i,j;

  for(i=0; i<N; i++)
    for(j=0; j<N; j++)
      b[i][j] = 3;
}

main() {
  inita();
  initb();
  matmul();
  //  show();
}

matmul() {
  int i,j,k;

  for(i=0; i<N; i++) {
    for(j=0; j<N; j++) {
      c[i][j] = 0;
      for(k=0; k<N; k++) {
	c[i][j] += a[i][k] * b[k][j];
      }
    }
  }
}
