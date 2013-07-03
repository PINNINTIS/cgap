#!/usr/local/bin/perl

#############################################################################
# SelectLibraryIDs.pl
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

my ($org, $scope, $title, $type, $tissue, $hist, $prot) = @ARGV;

Scan($org, $scope, $title, $type, $tissue, $hist, $prot);
print SelectLibraryIDs_1($org, $scope, $title, $type, $tissue, $hist, $prot);

exit GetStatus();
