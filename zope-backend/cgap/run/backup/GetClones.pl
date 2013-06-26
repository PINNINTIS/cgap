#!/usr/local/bin/perl

#############################################################################
# GetClones.pl
#

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use CGAPGene;
use Blocks;
use Scan;

my ($org1, $items_ref, $items_in_memory, $filedata) = @ARGV;

Scan($org1, $items_ref, $items_in_memory, $filedata);
print GetClones_1($org1, $items_ref, $items_in_memory, $filedata);

exit GetStatus();
