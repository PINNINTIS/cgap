#!/usr/local/bin/perl
 
use strict;
use GD;
 
print "Content-type: image/gif\n\n";

my $s;
my @data;
my $filename = "/cgap/schaefec/test_cgi/port.svg";
open(RIN, "$filename") or die "Can't open $filename.";
while (read RIN, $s, 16384) {
  push @data, $s;
}
close (RIN);
print join("", @data);

