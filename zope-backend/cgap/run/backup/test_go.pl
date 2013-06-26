#!/usr/local/bin/perl
use strict;
use FisherExact;

######################################################################
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

use strict;

######################################################################
sub TestFisherExact {
  my $n22 =  999999;
  my $n21 = 1000000;
  my $n11;
  my $n12;
  ## foreach my $i (1..60){
  ##   $n11 = $i;
  ##   $n12 = 2;
  ##   printf "%2s %7s %2s %15s %f\n", 
  ##       $n11, $n21,
  ##       $n12, $n22,
    ## return the p value by Fish Exact Test
##   $n11 = 1;
##   $n12 = 10;
##   $n21 = 14;
##   $n22 = 17;
   $n11 = 1;
   $n12 = 1;
   $n21 = 1;
   $n22 = 18364;

   $n11 = 1;
   $n12 = 4135;
   $n21 = 1;
   $n22 = 18364;

  printf "8888: %f\n", 
    FisherExact::FisherExact(1, 5671, 1, 18364);
  ##  FisherExact($n11, $n12, $n11+$n21, $n12+$n22);
  ## }
}

TestFisherExact();


######################################################################
sub lngamm {
# Reference: "Lanczos, C. 'A precision approximation 
# of the gamma function', J. SIAM Numer. Anal., B, 1, 86-96, 1964."
# Translation of  Alan Miller's FORTRAN-implementation
# See http://lib.stat.cmu.edu/apstat/245
  my ($z) = @_;
  my $x = 0;
  $x += 0.1659470187408462e-06/($z+7);
  $x += 0.9934937113930748e-05/($z+6);
  $x -= 0.1385710331296526    /($z+5);
  $x += 12.50734324009056     /($z+4);
  $x -= 176.6150291498386     /($z+3);
  $x += 771.3234287757674     /($z+2);
  $x -= 1259.139216722289     /($z+1);
  $x += 676.5203681218835     /($z);
  $x += 0.9999999999995183;
  return(log($x)-5.58106146679532777-$z+($z-0.5)*log($z+6.5));
}



######################################################################
sub lnfact {
  my ($n) = @_;
  if($n<=1){ 
    return(0);
  }
  return(&lngamm($n+1));
}

######################################################################
sub lnbico {
  my ($n, $k) = @_;
  return(&lnfact($n)-lnfact($k)-lnfact($n-$k));
}

######################################################################
sub hyper_323 {
  my ($n11, $n1_, $n_1, $n) = @_;
  return( exp(&lnbico($n1_,$n11)+&lnbico($n-$n1_,$n_1-$n11)-&lnbico($n,$n_1)));
}


######################################################################
sub hyper {
  my ($n11) = @_;
  return( &hyper0($n11,0,0,0));
}

######################################################################
my ($sprob, $sn, $sn11, $sn1_, $sn_1);
######################################################################
sub hyper0 {
  my ($n11i, $n1_i, $n_1i, $ni) = @_;
  if(! ($n1_i|$n_1i|$ni)){
    if(!($n11i % 10 == 0)){
      if($n11i==$sn11+1){
        $sprob *= (($sn1_-$sn11)/($n11i))*(($sn_1-$sn11)/($n11i+$sn-$sn1_-$sn_1));
        $sn11 = $n11i;
        return $sprob;
      }
      if($n11i==$sn11-1){
        $sprob *= (($sn11)/($sn1_-$n11i))*(($sn11+$sn-$sn1_-$sn_1)/($sn_1-$n11i));
        $sn11 = $n11i;
        return $sprob;
      }
    }
    $sn11 = $n11i;
  } else {
    $sn11 = $n11i;
    $sn1_ = $n1_i;
    $sn_1 = $n_1i;
    $sn   = $ni;
  }
  $sprob = &hyper_323($sn11,$sn1_,$sn_1,$sn);
  return $sprob;
}


######################################################################
sub exact {
  my ($n11, $n1_, $n_1, $n) = @_;

  my ($prob, $sleft, $sright);
  my ($p, $i, $j);
  my $max = $n1_;
  if( $n_1 < $max) {
    $max = $n_1;
  }
  my $min = $n1_ + $n_1 - $n;
  if($min < 0) {
    $min = 0;
  }
  if($min == $max){
    $sright= 1;
    $sleft = 1;
    return (1, $sleft, $sright);
  }
  $prob=&hyper0($n11,$n1_,$n_1,$n);
  $sleft=0;
  $p=&hyper($min);
  for($i=$min+1; $p<0.99999999*$prob; $i++)
  {
    $sleft += $p;
    $p=&hyper($i);
  }
  if($p<1.00000001*$prob){ 
      $sleft += $p;
  }
  $sright=0;
  $p=&hyper($max);
  for($j=$max-1; $p<0.99999999*$prob; $j--) {
    $sright += $p;
    $p=&hyper($j);
  }
  if($p<1.00000001*$prob){
      $sright += $p;
  }
  return ($prob, $sleft, $sright);
}


######################################################################
sub FisherExact {
  my ($G_A, $G_B, $TotalA, $TotalB) = @_;

  my ($prob, $sleft, $sright);
  my ($twotail, $n11, $n12, $n21, $n22, $n1_, $n_1, $n);
  $n11 = $G_A;
  $n12 = $G_B;
  $n21 = $TotalA - $G_A;
  $n22 = $TotalB - $G_B;

  $n1_  = $n11 + $n12;
##  $n_1 = $n11 + $n21;
  $n_1 = $TotalA;
##  $n   = $n11 + $n12 + $n21 + $n22;
  $n   = $TotalA + $TotalB;

  ## $n11 = 1;
  ## $n1_ = 10;
  ## $n_1 = 14;
  ## $n = 17;

  ($prob, $sleft, $sright) = &exact($n11, $n1_, $n_1, $n);
  $twotail = $sleft + $sright;
  if ($twotail > 1){
    $twotail = 1;
  }
  return sprintf "%f", $twotail ;
}
