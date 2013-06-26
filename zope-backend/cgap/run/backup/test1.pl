#!/usr/local/bin/perl
use strict;
use cor;

sub test {
  my $result;
  my @a = (1,2,3,4,5);
  my @b = (1,2,3,4,5);
  ## my $n  = 5;
  my $n  = 4;
  my $n1 = 1;
  my $n2 = 1;

  my @a = (10,20,30,40);
  my @b = (50,70,60,200);
  my $ia = create_array(@a);  # Create C arrays
  my $ib = create_array(@b);

  my $a_p_double = \@a;
  my $b_p_double = \@b;
  ## $result = cor::cor( $n, @a, @b );
  $result = cor::cor( $n, $ia, $ib );
  ## $result = cor::cor( $n, $a_p_double, $b_p_double );
  ## for( my $i=0; $i<500; $i++) {
    ## $result = cor::cor( $n, $n1, $n2 );
  ##   $result = cor::cor( $n, $a, $b );
    ## $result = cor::cor( $n, \@a, \@b );
  ## }
  cor::double_destroy($ia);
  cor::double_destroy($ia);
  printf "result: $result \n";
}
 
sub create_array {
 my $len = scalar(@_);
 my $ia = cor::double_array($len);
 for (my $i = 0; $i < $len; $i++) {
    my $val = shift;
    cor::double_set($ia,$i,$val);
 }
 return $ia;
}
   
test();
