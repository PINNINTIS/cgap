#!/usr/local/bin/perl
 
use strict;
use GD;
 
print "Content-type: text/plain\n\n";

my $s;
my @data;
my $filename = "/cgap/schaefec/test_cgi/SVG.test";
## my $filename = "/cgap/schaefec/test_cgi/MC.315";
## my $filename = "/cgap/schaefec/test_cgi/MC.457";
open(RIN, "$filename") or die "Can't open $filename.";
while (read RIN, $s, 16384) {
  push @data, $s;
}
close (RIN);
print join("", @data);

