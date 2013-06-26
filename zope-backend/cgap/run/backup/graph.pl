#!/usr/local/bin/perl

use strict;
use GD;

print "Content-type: image/gif\n\n";

my $im = new GD::Image(100,100);
my $white = $im->colorAllocate(255, 255, 255);
my $black = $im->colorAllocate(0, 0, 0);
my $red = $im->colorAllocate(255, 0, 0);
my $blue = $im->colorAllocate(0, 0, 255);
$im->rectangle(0,0,99,99,$black);
$im->arc(50, 50, 95, 75, 0, 360, $red);
$im->fill(50, 50, $red);

my $filename = "/cgap/schaefec/test_cgi/GD.test";
if (open(OUT, ">$filename")) {
  if (GD->require_version() > 1.19) { 
    print OUT $im->png;
    close OUT;
    chmod 0666, $filename;
    ## print $im->png; 
  } else { 
    print OUT $im->gif;
    close OUT;
    chmod 0666, $filename;
    ## print $im->gif; 
  } 
}
else {
  print "Can not open file $filename\n";
}
print  "GD Test<br>";
print  "<image src=\"GetImage\" border=0 ><br>";
print  "GD Test is done<br>";

