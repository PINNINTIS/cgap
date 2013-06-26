#!/usr/local/bin/perl

#############################################################################
# FormatGeneList.pl
#

use strict;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use GLServer;
use Blocks;
use Scan;

my ($base, $page, $row, $what, $org, $scope, $title, $type, $tissue,
    $hist, $prot, $sort, $partition) = @ARGV;

Scan($base, $page, $row, $what, $org, $scope, $title, 
     $type, $tissue, $hist, $prot, $sort, $partition);

print ListSummarizedGenes_1($base, $page, $row, $what, $org, $scope, $title, 
    $type, $tissue, $hist, $prot, $sort, $partition);

exit GetStatus();
