#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <ctype.h>


/* ######################################################################
   # FisherExact.pm
   #
   # From Javascript: http://www.matforsk.no/ola/fisher.htm
   # The perl script was confirmed by SAS.
   #
   #              Set A       Set B
   #   -----------------------------     
   #   geneA+     n11         n12
   #
   #   geneA-     n21         n22
   #   -----------------------------
   #
   ######################################################################
*/

double sprob;
int  sn, sn11, sn1_, sn_1;

/* ###################################################################### */
long double lngamm (long double z) {
/*
# Reference: "Lanczos, C. 'A precision approximation 
# of the gamma function', J. SIAM Numer. Anal., B, 1, 86-96, 1964."
# Translation of  Alan Miller's FORTRAN-implementation
# See http://lib.stat.cmu.edu/apstat/245
*/
  long double x = 0;
  x += 0.1659470187408462e-06l/(z+7.0l);
  x += 0.9934937113930748e-05l/(z+6.0l);
  x += 12.50734324009056l     /(z+4.0l);
  x += 771.3234287757674l     /(z+2.0l);
  x += 676.5203681218835l     /(z);
  x += 0.9999999999995183l;
  x -= 0.1385710331296526l    /(z+5.0l);
  x -= 176.6150291498386l     /(z+3.0l);
  x -= 1259.139216722289l     /(z+1.0l);
  return(log(x)-5.58106146679532777l-z+(z-0.5l)*log(z+6.5));
}



/* ###################################################################### */
long double lnfact(int n) {
  if(n<=1){ 
    return(0);
  }
  return(lngamm(n+1));
}

/* ###################################################################### */
double lnbico (int n, int k) {
  return(lnfact(n)-lnfact(k)-lnfact(n-k));
}

/* ###################################################################### */
double hyper_323(int n11, int n1_, int n_1, int n) {
  return( exp(lnbico(n1_,n11)+lnbico(n-n1_,n_1-n11)-lnbico(n,n_1)));
}

/* ###################################################################### */
double hyper0 (int n11i, int n1_i, int n_1i, int ni) {
  if(! (n1_i|n_1i|ni)){
    if(!(n11i % 10 == 0)){
      if(n11i==sn11+1){
        sprob *= ((double)(sn1_-sn11)/((double)n11i))*((double)(sn_1-sn11)/((double)(n11i+sn-sn1_-sn_1)));
        sn11 = n11i;
        return sprob;
      }
      if(n11i==sn11-1){
        sprob *= (((double)sn11)/((double)(sn1_-n11i)))*(((double)(sn11+sn-sn1_-sn_1))/((double)(sn_1-n11i)));
        sn11 = n11i;
        return sprob;
      }
    }
    sn11 = n11i;
  } else {
    sn11 = n11i;
    sn1_ = n1_i;
    sn_1 = n_1i;
    sn   = ni;
  }
  sprob = hyper_323(sn11,sn1_,sn_1,sn);
  return sprob;
}

/* ###################################################################### */
double hyper(int n11) {
  return( hyper0(n11,0,0,0));
}

/* ###################################################################### */
double exact (int n11, int n1_, int n_1, int n) {

  double sleft, sright, twotail;
  double prob, p;
  int i, j;
  int max;
  int min;
  int count = 0;
  char tmpchar[500];
  max = n1_;
  if( n_1 < max) {
    max = n_1;
  }
  min = n1_ + n_1 - n;
  if(min < 0) {
    min = 0;
  }
  if(min == max){
    /* sright= 1;
       sleft = 1;
    */
    twotail = 1;  
    return twotail;
  }
  prob=hyper0(n11,n1_,n_1,n);
  sleft=0;
  p=hyper(min);
  for(i=min+1; p<0.99999999*prob; i++) 
  {
    count++; 
    sleft += p;
    p=hyper(i);
    if( count > 30000 ) {
/*
      sprintf (tmpchar,  "mail wuko@mail.nih.gov << END
               4.5.2002 version %d, %d, %d, %d, %f, %f, %f
               END
               \004", n11, n1_, n_1, n, prob, p, sleft );
      system( tmpchar );
*/
      break;
    }
  }
  if(p<1.00000001*prob){ 
      sleft += p;
  }
  sright=0;
  p=hyper(max);
  count = 0;
  for(j=max-1; p<0.99999999*prob; j--) {
    count++;
    sright += p;
    p=hyper(j);
    if( count > 30000 ) {
/*
      sprintf (tmpchar,  "mail wuko@mail.nih.gov << END 
               %d, %d, %d, %d, %f, %f, %f 
               END 
               \004", n11, n1_, n_1, n, prob, p, sright );
      system( tmpchar ); 
*/
      break; 
    } 
  }
  if(p<1.00000001*prob){
      sright += p;
  }

  twotail = sleft + sright;
  if (twotail > 1){
    twotail = 1;
  }

  return twotail;
}


/* ###################################################################### */
double FisherExact (int G_A, int G_B, int TotalA, int TotalB ){

  double prob, sleft, sright, twotail;
  int n11, n12, n21, n22, n1_, n_1, n;
  n11 = G_A;
  n12 = G_B;
  n21 = TotalA - G_A;
  n22 = TotalB - G_B;

  n1_  = n11 + n12;
  n_1 = TotalA;
  n   = TotalA + TotalB;
  twotail = exact(n11, n1_, n_1, n);
  return twotail;
}

/*
main (){
  int n11,n12,n21,n22;
  int i;
  n22 =  999999;
  n21 = 1000000;
  for (i=1; i<61; i++) {
    n11 = i;
    n12 = 2;
    printf ("%d,  %d,  %d,  %d: %f \n",
        n11, n21,
        n12, n22,
    FisherExact(n11, n12, n11+n21, n12+n22));
  }  

  n11 = 2;
  n12 = 62;
  n21 = 210143;
  n22 = 4380179;
  printf ("%d,  %d,  %d,  %d: %f \n",
        n11, n21,
        n12, n22,
        FisherExact(n11,n12,n21,n22));

}
*/
