# include <stdio.h>
# include <math.h>

/* There is no ** operator, so create power function */
long double power( long double base, int n )
{
  int i, j, Odd[2000];
  long double p;
  if( n == 0 ) {
    return 1;
  }
  else if ( n == 1 ) {
    return base;
  }

  for( i=0; i<=2000; i++ ) {
    Odd[i] = 0;
  }

  i = 0;
  while ( n != 0 ) {
    if( n%2 == 0 ) {
      i++;
      n = n/2;
      if ( n == 1 ) {
        n = 0;  /* stop */
      }  
    }  
    else {
      Odd[i] = 1;
      n = n - 1;
    }
  }  
  p = base;
  for(j=i; j>0; j--) {
    p = p * p;
    if( Odd[j-1] == 1 ) {
      p = p * base;
    }
  }  
  return p;
}

long double f(double x, int a, int b, double A, double B) 
       /* Definition of f(x) */
{
  long double function;
  if( A != B ) {
    function = ((power(x, (3+a)))*(power((1-x), (3+b))))/(power(1+(A/B-1)*x,(a+b)));
  }
  else {
    function = (power(x, (3+a)))*(power((1-x), (3+b)));
  }

  return(function);   /* What the function gives when it is called */
}

double func(double x, int a, int b, double A, double B)
       /* Definition of f(x) */
{
  double function;
  if( A != B ) {
    function = ((exp(log(x)*(3+a)))*(exp(log(1-x)*(3+b))))/exp(log(1+(A/B-1)*x)*(a+b));
  }
  else {
    function = (exp(log(x)*(3+a)))*(exp(log(1-x)*(3+b)));
  }

  return(function);   /* What the function gives when it is called */
}

double Bayesian(double factor, int a, int b, double A, double B)    
      /* using Simpson's Rule for integral f(x) over [a,b] */
{
  int n=300;                  /* Maximum number of steps (even) n */
  int n1;                     /* Maximum number of steps (even) n */
  int n2;                     /* Maximum number of steps (even) n */
  int c, k=1;                 /* Counters in the algorithm */
  int c1, j=1;                /* Counters in the algorithm */
  double x;
  double l;                   /* Lower limit x=l */
  double l1;                  /* Lower limit x=l */
  double u=1.0L;                  /* Upper limit x=u */
  long double h,SUM;
  long double SUM1;
 
  SUM = 0.0L;
  SUM1 = 0.0L;
  l = 0.0L;
  l1 = factor/(factor + 1.0L);
  n1 = l1 * n;
  if ( n1 % 2 == 1 ) {
    n1 = n1 + 1;
  }
  n2 = 302 - n1;
  c=2;
  c1=2;
  h=(double)(l1-l)/((double)(n1));            /* Step size h=(b-a)/n */
  k = 1;
  if( a > 440 || b > 440 ) {
    while (k <= n1-1)   /* Steps through the iteration */
    {
      c=6-c;       /* gives the 4,2,4,2,... */
      SUM = SUM + c*f(l+k*h, a, b, A, B);  /* Adds on the next area */
      k++;         /* Increases k value by +1 */
    }
    SUM = (SUM + f(l1, a, b, A, B))*h/3;
    c=2;
    h=(double)(u-l1)/((double)(n2));            /* Step size h=(b-a)/n */
    k = 1;
    SUM1=f(l1, a, b, A, B);                 /* Initial function value */
    while (k <= n2-1)   /* Steps through the iteration */
    {
      c=6-c;       /* gives the 4,2,4,2,... */
      SUM1 = SUM1 + c*f(l1+k*h, a, b, A, B);  /* Adds on the next area */
      k++;         /* Increases k value by +1 */
    }
  }
  else {
    while (k <= n1-1)   /* Steps through the iteration */
    {
      c=6-c;       /* gives the 4,2,4,2,... */
      SUM = SUM + c*func(l+k*h, a, b, A, B);  /* Adds on the next area */
      k++;         /* Increases k value by +1 */
    }
    SUM = (SUM + func(l1, a, b, A, B))*h/3;
    c=2;
    h=(double)(u-l1)/((double)(n2));            /* Step size h=(b-a)/n */
    k = 1;
    SUM1=func(l1, a, b, A, B);                 /* Initial function value */
    while (k <= n2-1)   /* Steps through the iteration */
    {
      c=6-c;       /* gives the 4,2,4,2,... */
      SUM1 = SUM1 + c*func(l1+k*h, a, b, A, B);  /* Adds on the next area */
      k++;         /* Increases k value by +1 */
    }
  }

  SUM1 = SUM1*h/3;
  return SUM1/(SUM + SUM1);
}                          /* End of program */

