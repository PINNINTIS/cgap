#!/usr/local/bin/perl

#############################################################################
# SearchAbnorm.pl
#

use strict;
use CGI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CytSearchServer;
use Scan;

my $query     = new CGI;

my @tmps;
open(IN, "/cgap/webcontent/LINUX/staging/CGAP/data/cache/SAGEGXS.430.BH_OUT") or return "Error: failed to open file SAGEGXS.430.BH_OUT contact help desk. Sorry for inconvenient\n";
while(<IN>) {
  chop;
  ## my @tmp = split " ", $_;
  my @tmp_1 = split "\]", $_;
  $tmp_1[1] =~ s/^\s+//;
  my @tmp = split /\s+/, $tmp_1[1];
  for( my $i=0; $i<@tmp; $i++ ) { 
    ## push @BH_P, $tmp[$i]; 
    print $tmp[$i] . "\n";
  }  
}
close IN;
