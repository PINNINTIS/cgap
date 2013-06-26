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
  $fn, $fn_user_b, $fn_user_a
) = @ARGV;

my (
  $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $lib_a,
  $stage_a,
  $comp_stage_a,
  $user_file_a,
  $user_data_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $lib_b,
  $stage_b,
  $comp_stage_b,
  $user_file_b,
  $user_data_b,
  $org,
  $method
);

open (INPF, $fn) or die "Cannot open $fn";

$seqs          = <INPF>; chop $seqs;
$sort          = <INPF>; chop $sort;
$title_a       = <INPF>; chop $title_a;
$tissue_a      = <INPF>; chop $tissue_a;
$hist_a        = <INPF>; chop $hist_a;
$comp_a        = <INPF>; chop $comp_a;
$cell_a        = <INPF>; chop $cell_a;
$lib_a         = <INPF>; chop $lib_a;
$stage_a       = <INPF>; chop $stage_a;
$comp_stage_a  = <INPF>; chop $comp_stage_a;
$user_file_a   = <INPF>; chop $user_file_a;
$title_b       = <INPF>; chop $title_b;
$tissue_b      = <INPF>; chop $tissue_b;
$hist_b        = <INPF>; chop $hist_b;
$comp_b        = <INPF>; chop $comp_b;
$cell_b        = <INPF>; chop $cell_b;
$lib_b         = <INPF>; chop $lib_b;
$stage_b       = <INPF>; chop $stage_b;
$comp_stage_b  = <INPF>; chop $comp_stage_b;
$user_file_b   = <INPF>; chop $user_file_b;
$org           = <INPF>; chop $org;
$method        = <INPF>; chop $method;

close INPF;
unlink $fn;

if ($fn_user_b) {
  my ($tag, $freq);
  my %tag2freq;
  open (INPF, $fn_user_b) or die "Cannot open $fn_user_b";
  while (<INPF>) {
    chop;
    ($tag, $freq) = split "\s";
    if( defined $tag2freq{$tag} ) { 
      $tag2freq{$tag} = $tag2freq{$tag} + $freq;
    }
    else {
      $tag2freq{$tag} = $freq;
    }
  }
  close INPF;
  for my $tag ( keys %tag2freq ) {
    $user_data_b .= "$tag\t$tag2freq{$tag}\n";
  }
  unlink $fn_user_b;
}

if ($fn_user_a) {
  my ($tag, $freq);
  my %tag2freq;
  open (INPF, $fn_user_a) or die "Cannot open $fn_user_a";
  while (<INPF>) {
    chop;
    ($tag, $freq) = split "\s";
    if( defined $tag2freq{$tag} ) { 
      $tag2freq{$tag} = $tag2freq{$tag} + $freq;
    }
    else {
      $tag2freq{$tag} = $freq;
    }
  }
  close INPF;
  for my $tag ( keys %tag2freq ) {
    $user_data_a .= "$tag\t$tag2freq{$tag}\n";
  }
  unlink $fn_user_a;
}

print SDGEDLibrarySelect_1 (
  $seqs,
  $sort,
  $title_a,
  $tissue_a,
  $hist_a,
  $comp_a,
  $cell_a,
  $lib_a,
  $stage_a,
  $comp_stage_a,
  $user_file_a,
  $user_data_a,
  $title_b,
  $tissue_b,
  $hist_b,
  $comp_b,
  $cell_b,
  $lib_b,
  $stage_b,
  $comp_stage_b,
  $user_file_b,
  $user_data_b,
  $org,
  $method
);

