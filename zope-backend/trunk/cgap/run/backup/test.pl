#!/usr/local/bin/perl

#############################################################################
# GetPartition.pl
#

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}
print "Content-type: text/plain\n\n";

print "8888";
