#!/usr/local/bin/perl

######################################################################
# SDGEDLibrarySelect.pl
#
# 
# 

use strict;
use DBI;

BEGIN {
  my @path_elems = split("/", $0);
  pop @path_elems;
  push @INC, join("/", @path_elems);
}

use SAGE;

my (
  $fn
) = @ARGV;

my (
  $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $org
);

open (INPF, $fn) or die "Cannot open $fn";

$seqs     = <INPF>; chop $seqs;
$sort     = <INPF>; chop $sort;
$title_a  = <INPF>; chop $title_a;
$tissue_a = <INPF>; chop $tissue_a;
$hist_a   = <INPF>; chop $hist_a;
$comp_a   = <INPF>; chop $comp_a;
$cell_a   = <INPF>; chop $cell_a;
$title_b  = <INPF>; chop $title_b;
$tissue_b = <INPF>; chop $tissue_b;
$hist_b   = <INPF>; chop $hist_b;
$comp_b   = <INPF>; chop $comp_b;
$cell_b   = <INPF>; chop $cell_b;
$org      = <INPF>; chop $org;

close INPF;
unlink $fn;

print SDGEDLibrarySelect_1 (
  $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $org
);

