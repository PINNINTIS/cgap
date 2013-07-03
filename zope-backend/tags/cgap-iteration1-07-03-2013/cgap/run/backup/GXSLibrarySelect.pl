#!/usr/local/bin/perl

#############################################################################
# GXSLibrarySelect.pl
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

my ($org, $scope, $min_seqs, $sort,
    $title_a,  $title_b,
    $type_a,   $type_b,
    $tissue_a, $tissue_b,
    $hist_a,   $hist_b,
    $prot_a,   $prot_b,
    $comp_a,   $comp_b) = @ARGV;

Scan($org, $scope, $min_seqs, $sort,
     $title_a,  $title_b,
     $type_a,   $type_b,
     $tissue_a, $tissue_b,
     $hist_a,   $hist_b,
     $prot_a,   $prot_b,
     $comp_a,   $comp_b);

print GXSLibrarySelect_1($org, $scope, $min_seqs, $sort,
                         $title_a,  $title_b,
                         $type_a,   $type_b,
                         $tissue_a, $tissue_b,
                         $hist_a,   $hist_b,
                         $prot_a,   $prot_b,
                         $comp_a,   $comp_b);

exit GetStatus();
