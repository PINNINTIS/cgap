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

use CGAPLib;
use Blocks;
use Scan;

my ($org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1, $sort1) = @ARGV;

Scan($org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1, $sort1);
print GetPartition_1($org1, $scope1, $title1, $type1, $tissue1, $hist1, $prot1, $sort1);

exit GetStatus();
